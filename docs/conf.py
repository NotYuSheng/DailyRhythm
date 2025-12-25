# Configuration file for the Sphinx documentation builder.

# -- Project information -----------------------------------------------------
project = 'DailyRhythm'
copyright = '2025, DailyRhythm'
author = 'DailyRhythm Team'
release = '1.0.0'

# -- General configuration ---------------------------------------------------
extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.viewcode',
    'sphinx.ext.githubpages',
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# -- Options for HTML output -------------------------------------------------
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
html_theme_options = {
    'navigation_depth': 4,
    'collapse_navigation': False,
    'sticky_navigation': True,
    'includehidden': True,
    'titles_only': False,
}

# -- Custom styling ----------------------------------------------------------
html_css_files = [
    'custom.css',
]

html_context = {
    "display_github": True,
    "github_user": "NotYuSheng",
    "github_repo": "DailyRhythm",
    "github_version": "main",
    "conf_py_path": "/docs/",
}
