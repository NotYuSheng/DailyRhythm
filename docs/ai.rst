AI assistant (optional)
=======================

DailyRhythm works fully without AI. If you want, you can connect an AI model
of your choosing in **Settings → AI assistant**. Today it powers **Estimate
with AI** on a meal: it sends only the food's name and fills in the calories
for one serving, saved as an estimate you can change.

Nothing is sent until you turn it on and tap a button. Your journal, moods and
health data are never sent.

Choosing a model
----------------

Any service that speaks the OpenAI-compatible chat API works. Pick a preset
or **Custom**, then fill in:

* **Address**: the base URL, ending in ``/v1`` for most providers.
* **Model**: the model's name at that provider.
* **API key**: from the provider's console. It stays on your phone, is never
  exported or put in backups, and is left out of Android's cloud backup.

Tap **Test connection** before saving.

.. list-table::
   :header-rows: 1

   * - Provider
     - Address
   * - OpenAI
     - ``https://api.openai.com/v1``
   * - Anthropic
     - ``https://api.anthropic.com/v1``
   * - Google Gemini
     - ``https://generativelanguage.googleapis.com/v1beta/openai``
   * - OpenRouter
     - ``https://openrouter.ai/api/v1``
   * - Ollama (your own)
     - ``http://<your-computer>:11434/v1``
   * - LM Studio (your own)
     - ``http://<your-computer>:1234/v1``

A cloud provider's own terms and prices apply to what you send it.

Running a model at home with Tailscale
--------------------------------------

To keep everything on your own devices, run a model on a computer at home and
reach it from your phone over `Tailscale <https://tailscale.com>`_, a private
network between your devices. Setting this up is up to you; DailyRhythm only
needs the address.

1. **Install a model server** on the computer, for example
   `Ollama <https://ollama.com>`_, then pull a small model
   (``ollama pull llama3.2``).
2. **Let it listen beyond the computer itself.** For Ollama, set
   ``OLLAMA_HOST=0.0.0.0`` before starting it. Keep a firewall so only your
   tailnet can reach it.
3. **Install Tailscale** on the computer and on your phone, signed in to the
   same account. Turn on **MagicDNS** in the Tailscale admin console.
4. **Find the computer's name**: it looks like
   ``my-pc.your-tailnet.ts.net``.
5. In DailyRhythm, choose **Ollama (your own)** and set the address to
   ``http://my-pc.your-tailnet.ts.net:11434/v1``, the model to the one you
   pulled, and leave the key empty. Tap **Test connection**.

For HTTPS, run ``tailscale serve --bg 11434`` on the computer and use
``https://my-pc.your-tailnet.ts.net/v1`` instead.

.. note::
   Android only allows plain ``http://`` to private names: ``localhost``,
   ``*.ts.net`` (Tailscale) and ``*.local``. A bare IP address such as
   ``http://100.64.0.2`` is blocked; use the MagicDNS name or HTTPS.

Troubleshooting
---------------

* **Couldn't reach …**: the phone can't connect. Check Tailscale is on, the
  server is running and listening beyond the computer, and the port is right.
* **The provider refused the API key**: copy the key again; check the account
  has credit.
* **Not found**: the address or the model name is wrong. Most addresses end in
  ``/v1``; the model must exist at that provider (``ollama list``).
