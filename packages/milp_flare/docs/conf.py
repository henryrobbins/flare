from importlib.metadata import version as _pkg_version

from docutils import nodes
from sphinx.application import Sphinx
from sphinx.environment import BuildEnvironment

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
    # Compute runners
    "Runner": "milp_flare.harness.runner.base.Runner",
    "AgentRun": "milp_flare.harness.runner.base.AgentRun",
    "AuthSpec": "milp_flare.harness.runner.base.AuthSpec",
    "DockerRunner": "milp_flare.harness.runner.docker.DockerRunner",
    "ModalRunner": "milp_flare.harness.runner.modal.ModalRunner",
    # Modal SDK types used in the ModalRunner docstrings. These resolve to the
    # Modal docs via the ``missing-reference`` handler in ``setup`` below.
    "Sandbox": "modal.Sandbox",
    "Image": "modal.Image",
    "App": "modal.App",
    "Secret": "modal.Secret",
    "ContainerProcess": "modal.container_process.ContainerProcess",
}

# Modal publishes no Sphinx ``objects.inv``, so intersphinx cannot resolve its
# types. Map the Modal symbols referenced in our docstrings to their pages in
# the Modal Python SDK reference instead. Keys are the (numpydoc-aliased) xref
# targets; values are paths under ``_MODAL_SDK_BASE``.
_MODAL_SDK_BASE = "https://modal.com/docs/sdk/py/latest/"
_MODAL_OBJECTS = {
    "modal.Sandbox": "modal.Sandbox",
    "modal.Image": "modal.Image",
    "modal.App": "modal.App",
    "modal.Secret": "modal.Secret",
    "modal.container_process.ContainerProcess": (
        "modal.container_process#modalcontainer_processcontainerprocess"
    ),
}


def _resolve_modal_xref(
    app: Sphinx,
    env: BuildEnvironment,
    node: nodes.Element,
    contnode: nodes.Element,
) -> nodes.reference | None:
    """Resolve unresolved Modal xrefs to the Modal Python SDK reference."""
    path = _MODAL_OBJECTS.get(node.get("reftarget", ""))
    if path is None:
        return None
    ref = nodes.reference("", "", internal=False, refuri=_MODAL_SDK_BASE + path)
    ref.append(contnode)
    return ref


def setup(app: Sphinx) -> None:
    app.connect("missing-reference", _resolve_modal_xref)
