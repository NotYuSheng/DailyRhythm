"""Frames the raw screenshots for the Play Store: a caption above each screen.

    python3 tool/store_listing/frame.py

Reads tool/store_listing/raw/*.png (from screenshots_test.dart) and writes
1080 x 1920 PNGs to assets/google-play/screenshots/ with headless Chromium
(CHROME, or Playwright's headless shell).
"""
import glob
import os
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, 'tool', 'store_listing', 'raw')
OUT = os.path.join(ROOT, 'assets', 'google-play', 'screenshots')
FONT = os.path.join(ROOT, 'assets', 'fonts', 'Nunito-Variable.ttf')

FRAMES = [
    ('1_today', 'Every day grows a plant', 'Pick what today was mostly about', '#EAF6EE'),
    ('2_your_day', 'Your day at a glance', 'Sleep, meals, exercise and what you did', '#FCEFD9'),
    ('3_garden', 'A garden of your days', 'Tap any day to look back', '#DFF2E6'),
    ('4_metrics', 'Your month, in season', 'A seasonal garden, moments and patterns', '#F8E6DA'),
    ('5_fun_facts', 'Fun facts about you', 'Habits, favourites and records', '#E7E9FB'),
    ('6_year', 'Your year in one view', 'Private, on your phone', '#F7ECE2'),
]


def chrome():
    if os.environ.get('CHROME'):
        return os.environ['CHROME']
    found = glob.glob(os.path.expanduser('~/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell'))
    if not found:
        raise SystemExit('Set CHROME to a Chromium binary')
    return sorted(found)[-1]


def page(shot, title, sub, bg):
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: Nunito; src: url(file://{FONT}); font-weight: 200 1000; }}
body {{ margin: 0; }}
</style></head><body>
<div style="width: 1080px; height: 1920px; background: {bg}; font-family: Nunito, sans-serif; color: #1E3328; display: flex; flex-direction: column; align-items: center; overflow: hidden">
  <div style="margin-top: 110px; font-size: 76px; font-weight: 900; text-align: center; line-height: 1.1">{title}</div>
  <div style="margin-top: 22px; font-size: 40px; font-weight: 700; color: #4D6B5B; text-align: center">{sub}</div>
  <img src="file://{shot}" style="margin-top: 80px; width: 720px; border-radius: 56px; box-shadow: 0 30px 80px rgba(30,51,40,0.25); border: 14px solid #FFFFFF">
</div></body></html>'''


def main():
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, title, sub, bg in FRAMES:
            shot = os.path.join(RAW, f'{name}.png')
            html = os.path.join(tmp, f'{name}.html')
            with open(html, 'w') as f:
                f.write(page(shot, title, sub, bg))
            out = os.path.join(OUT, f'{name}.png')
            subprocess.run([chrome(), '--no-sandbox', '--headless', '--hide-scrollbars', '--allow-file-access-from-files',
                            '--virtual-time-budget=2000', '--window-size=1080,1920', f'--screenshot={out}', f'file://{html}'],
                           check=True, capture_output=True)
            print(out)


if __name__ == '__main__':
    main()
