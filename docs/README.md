# DailyRhythm Documentation

This directory contains the Sphinx documentation for DailyRhythm.

## Building Locally

### Prerequisites

```bash
# Create virtual environment
python3 -m venv .venv

# Activate virtual environment
source .venv/bin/activate  # On Linux/Mac
# or
.venv\Scripts\activate  # On Windows

# Install dependencies
pip install sphinx sphinx-rtd-theme
```

### Build Documentation

```bash
cd docs
make html
```

The built documentation will be in `docs/_build/html/`.

To view it locally:

```bash
# From the docs directory
python -m http.server --directory _build/html 8000
```

Then open http://localhost:8000 in your browser.

## GitHub Pages Deployment

The documentation is automatically built and deployed to GitHub Pages when changes are pushed to the `main` branch.

### Setup GitHub Pages (One-time)

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Pages**
3. Under **Source**, select **GitHub Actions**
4. The workflow will automatically deploy on the next push to `main`

## File Structure

```
docs/
├── conf.py              # Sphinx configuration
├── index.rst            # Main documentation page
├── deletion-policy.rst  # Data deletion policy
├── Makefile            # Build commands
├── _static/            # Static files (CSS, images)
│   └── custom.css      # Custom styling
└── _build/             # Generated HTML (ignored by git)
```

## Adding New Pages

1. Create a new `.rst` file in the `docs/` directory
2. Add the page to the `toctree` in `index.rst`
3. Build and test locally
4. Commit and push to trigger automatic deployment
