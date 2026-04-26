"""Sphinx config for the Netie Open HBM documentation site."""

from __future__ import annotations

project   = "Netie Open HBM"
copyright = "2026, The Netie Open HBM Authors"
author    = "The Netie Open HBM Authors"
release   = "0.0.1"

extensions = [
    "myst_parser",
    "sphinx.ext.autodoc",
    "sphinx.ext.intersphinx",
    "sphinx.ext.viewcode",
]

source_suffix = {
    ".rst": "restructuredtext",
    ".md":  "markdown",
}

myst_enable_extensions = [
    "deflist",
    "tasklist",
    "fieldlist",
    "colon_fence",
]

html_theme        = "sphinx_rtd_theme"
html_title        = "Netie Open HBM"
html_static_path  = ["_static"]
templates_path    = ["_templates"]
exclude_patterns  = ["_build", "Thumbs.db", ".DS_Store"]

intersphinx_mapping = {
    "python": ("https://docs.python.org/3", None),
}
