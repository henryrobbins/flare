from importlib.metadata import version as _pkg_version

project = "milp_flare"
author = "Henry Robbins"
copyright = "2026, Henry Robbins"
release = _pkg_version("milp-flare")

extensions = [
    "myst_parser",
    "sphinx.ext.autodoc",
    "sphinx.ext.extlinks",
    "sphinx.ext.viewcode",
    "sphinx.ext.intersphinx",
    "sphinx_design",
    "numpydoc",
]

extlinks = {
    "fb": (
        "https://formulation-bench.henryrobbins.com/en/latest%s",
        "FormulationBench%.0s",
    ),
    "paper": ("https://flare.henryrobbins.com%s", "FLARE Paper%.0s"),
    "claude": ("https://code.claude.com/docs/en%s", "Claude Code Docs%.0s"),
    "codex": ("https://developers.openai.com/codex%s", "Codex Docs%.0s"),
    "opencode": ("https://opencode.ai/docs%s", "OpenCode Docs%.0s"),
    "github": (
        "https://github.com/henryrobbins/flare/tree/main/packages/milp_flare%s",
        "GitHub%.0s",
    ),
}

myst_enable_extensions = [
    "colon_fence",
    "deflist",
    "fieldlist",
    "dollarmath",
    "amsmath",
    "substitution",
]

myst_substitutions = {
    "FormulationBench": "[FormulationBench](https://formulation-bench.henryrobbins.com/en/latest)",
    "FLARE Paper": "[FLARE Paper](https://flare.henryrobbins.com)",
    "Claude Code Docs": "[Claude Code Docs](https://code.claude.com/docs/en)",
    "Codex Docs": "[Codex Docs](https://developers.openai.com/codex)",
    "OpenCode Docs": "[OpenCode Docs](https://opencode.ai/docs)",
    "GitHub": "[GitHub](https://github.com/henryrobbins/flare/tree/main/packages/milp_flare)",
}

intersphinx_mapping = {
    "python": ("https://docs.python.org/3", None),
}

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

html_theme = "furo"
html_title = "FLARE"
html_static_path = ["_static"]
html_css_files = ["custom.css"]

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
    "COST_PER_MTOK": "milp_flare.harness.cost.COST_PER_MTOK",
}
