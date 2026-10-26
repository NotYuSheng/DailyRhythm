"""Splits run-together pieces with an OpenAI-compatible LLM.

The model may only cut the text: its answer is accepted only if the items
are exact substrings that rebuild the piece in order. Answers are cached
by piece so re-running the pipeline is free and gives the same result.
"""

from __future__ import annotations

import json
import os
import re
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from .lines import AFTER_SLEEP, BEFORE_SLEEP

ZONE_DESCRIPTIONS = {
    BEFORE_SLEEP: "foods and drinks eaten that day (dishes, snacks, drinks, supplements)",
    AFTER_SLEEP: "exercises done that day, possibly followed by a short remark about the day",
}
DEFAULT_ZONE = "a mix of foods eaten and exercises done, possibly with a short remark about the day"


def load_env(path: Path) -> None:
    """Loads KEY=value lines into os.environ without overriding it."""
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())


def _squash(text: str) -> str:
    return re.sub(r"\s+", "", text)


def verify(piece: str, items: list[str]) -> bool:
    """Items must appear in order and together rebuild the piece."""
    if not items or not all(isinstance(i, str) and i.strip() for i in items):
        return False
    if _squash("".join(items)) != _squash(piece):
        return False
    position = 0
    for item in items:
        found = piece.find(item.strip(), position)
        if found < 0:
            return False
        position = found + len(item.strip())
    return True


def _prompt(piece: str, zone: str, hints: list[str]) -> str:
    known = f"\nThese names are already known and must stay whole if present: {json.dumps(hints)}" if hints else ""
    return (
        "Below is a fragment of a personal daily log written without separators. "
        f"It lists {ZONE_DESCRIPTIONS.get(zone, DEFAULT_ZONE)}.\n"
        "Split it into separate items.\n"
        "Rules:\n"
        "- Reply with only a JSON array of strings.\n"
        "- Copy every item exactly from the text: same spelling, capitalisation and punctuation.\n"
        "- Together the items must cover the whole text, in order, with nothing added or dropped.\n"
        "- Keep multi-word dish and exercise names together; one dish can name several ingredients.\n"
        "- A brand or shop name followed by its dish is one item (\"McDonald's prosperity burger\").\n"
        f"{known}\n\nText: {piece}"
    )


def _extract_array(content: str) -> list[str] | None:
    content = re.sub(r"<think>.*?</think>", "", content, flags=re.DOTALL)
    match = re.search(r"\[.*\]", content, flags=re.DOTALL)
    if not match:
        return None
    try:
        value = json.loads(match.group(0))
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, list) else None


class LlmSplitter:
    def __init__(self, cache_path: Path, base_url: str, api_key: str, model: str, workers: int = 4):
        self.cache_path = cache_path
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.model = model
        self.workers = workers
        cached = json.loads(cache_path.read_text()) if cache_path.exists() else {}
        # Re-check every cached answer so a damaged entry is asked again.
        self.cache: dict[str, list[str] | None] = {
            key: items for key, items in cached.items()
            if items is None or verify(key.split("|", 1)[1], items)
        }
        self.pending: dict[str, tuple[str, list[str]]] = {}

    @classmethod
    def from_env(cls, cache_path: Path) -> "LlmSplitter":
        missing = [k for k in ("LLM_BASE_URL", "LLM_API_KEY", "LLM_MODEL") if not os.environ.get(k)]
        if missing:
            raise SystemExit(f"Set {', '.join(missing)} in .env to use the LLM splitter")
        return cls(cache_path, os.environ["LLM_BASE_URL"], os.environ["LLM_API_KEY"], os.environ["LLM_MODEL"])

    @staticmethod
    def _key(piece: str, zone: str) -> str:
        return f"{zone}|{piece}"

    def __call__(self, piece: str, zone: str, hints: list[str]) -> list[str] | None:
        """Splitter used during parsing. Unknown pieces are queued for
        ``run_pending`` and return None for now."""
        key = self._key(piece, zone)
        if key in self.cache:
            items = self.cache[key]
            return None if items is None else list(items)
        self.pending[key] = (piece, hints)
        return None

    def _ask(self, piece: str, zone: str, hints: list[str]) -> list[str] | None:
        body = json.dumps({
            "model": self.model,
            "temperature": 0,
            "messages": [{"role": "user", "content": _prompt(piece, zone, hints)}],
        }).encode()
        for _attempt in range(2):
            request = urllib.request.Request(
                f"{self.base_url}/chat/completions",
                data=body,
                headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
            )
            with urllib.request.urlopen(request, timeout=240) as response:
                content = json.load(response)["choices"][0]["message"]["content"] or ""
            items = _extract_array(content)
            if items is not None and verify(piece, items):
                return [i.strip() for i in items]
        return None

    def run_pending(self, progress=print) -> int:
        """Asks the model about every queued piece and caches the answers."""
        jobs = list(self.pending.items())
        self.pending.clear()

        def work(job):
            key, (piece, hints) = job
            zone = key.split("|", 1)[0]
            try:
                return key, self._ask(piece, zone, hints)
            except Exception as error:  # network or server error: retry next run
                progress(f"  failed: {piece[:50]!r}: {error}")
                return key, "error"

        done = 0
        with ThreadPoolExecutor(self.workers) as pool:
            for key, items in pool.map(work, jobs):
                if items != "error":
                    self.cache[key] = items
                done += 1
                if done % 25 == 0:
                    progress(f"  {done}/{len(jobs)} pieces")
                    self.save()
        self.save()
        return len(jobs)

    def save(self) -> None:
        self.cache_path.parent.mkdir(parents=True, exist_ok=True)
        self.cache_path.write_text(json.dumps(self.cache, indent=1, ensure_ascii=False))
