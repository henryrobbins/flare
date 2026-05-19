from importlib.metadata import version as _pkg_version

project = "milp_flare"
author = "Henry Robbins"
release = _pkg_version("milp-flare")

extensions = [
    "myst_parser",
    "sphinx.ext.autodoc",
    "sphinx.ext.viewcode",
    "sphinx.ext.intersphinx",
    "numpydoc",
]

myst_enable_extensions = [
    "colon_fence",
    "deflist",
    "fieldlist",
    "dollarmath",
    "amsmath",
]

intersphinx_mapping = {
    "python": ("https://docs.python.org/3", None),
}

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

html_theme = "furo"
html_title = "FLARE"

autodoc_default_options = {"members": True, "undoc-members": True}
autodoc_typehints = "none"
numpydoc_class_members_toctree = False
numpydoc_show_class_members = False
numpydoc_xref_param_type = True
numpydoc_xref_ignore = {"of", "or", "optional", "default"}
numpydoc_xref_aliases = {
    "FLARE": "milp_flare.flare.FLARE",
    "FLAREResult": "milp_flare.flare.FLAREResult",
    "FormulationInput": "milp_flare.flare.FormulationInput",
    "FLARENLPrompt": "milp_flare.flare_nl.FLARENLPrompt",
    "Harness": "milp_flare.harness.base.Harness",
    "HarnessRunResult": "milp_flare.harness.base.HarnessRunResult",
    "ClaudeCodeHarness": "milp_flare.harness.claude_code.ClaudeCodeHarness",
    "CodexHarness": "milp_flare.harness.codex.CodexHarness",
    "OpenCodeHarness": "milp_flare.harness.opencode.OpenCodeHarness",
}
