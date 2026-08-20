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
    "sphinx.ext.doctest",
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

# The ``{testcode}`` example blocks construct real objects so imports, class
# names, and keyword arguments are typo-checked by ``sphinx-build -b doctest``.
# They must not run an actual verification, though — that needs Docker, agent
# credentials, and a multi-minute model call — so stub the one entry point that
# starts an agent. The Lean-level checks it skips are covered by the test suite.
doctest_global_setup = """
from unittest import mock
from milp_flare import FLARE, FLAREResult
FLARE.verify = mock.MagicMock(
    return_value=FLAREResult(is_reformulation=True, duration_s=322.4, cost_usd=1.49)
)
"""

intersphinx_mapping = {
    "python": ("https://docs.python.org/3", None),
    "fb": ("https://formulation-bench.henryrobbins.com/en/latest", None),
}

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

html_theme = "furo"
html_title = "FLARE"
html_static_path = ["_static"]
html_css_files = ["custom.css"]

html_theme_options = {
    "navigation_with_keys": True,
    "source_repository": "https://github.com/henryrobbins/flare/",
    "source_branch": "main",
    "source_directory": "packages/milp_flare/docs",
    "footer_icons": [
        {
            "name": "GitHub",
            "url": "https://github.com/henryrobbins/flare",
            # Furo ships no icon font, so the mark is inlined as SVG.
            "html": """
                <svg stroke="currentColor" fill="currentColor" stroke-width="0"
                     viewBox="0 0 16 16">
                  <path fill-rule="evenodd" d="M 8 0 C 3.58 0 0 3.58 0 8 c 0
                      3.54 2.29 6.53 5.47 7.59 .4 .07 .55 -.17 .55 -.38 0
                      -.19 -.01 -.82 -.01 -1.49 -2.01 .37 -2.53 -.49 -2.69
                      -.94 -.09 -.23 -.48 -.94 -.82 -1.13 -.28 -.15 -.68 -.52
                      -.01 -.53 .63 -.01 1.08 .58 1.23 .82 .72 1.21 1.87 .87
                      2.33 .66 .07 -.52 .28 -.87 .51 -1.07 -1.78 -.2 -3.64
                      -.89 -3.64 -3.95 0 -.87 .31 -1.59 .82 -2.15 -.08 -.2
                      -.36 -1.02 .08 -2.12 0 0 .67 -.21 2.2 .82 .64 -.18 1.32
                      -.27 2 -.27 s 1.36 .09 2 .27 c 1.53 -1.04 2.2 -.82 2.2
                      -.82 .44 1.1 .16 1.92 .08 2.12 .51 .56 .82 1.27 .82
                      2.15 0 3.07 -1.87 3.75 -3.65 3.95 .29 .25 .54 .73 .54
                      1.48 0 1.07 -.01 1.93 -.01 2.2 0 .21 .15 .46 .55 .38 A
                      8.012 8.012 0 0 0 16 8 c 0 -4.42 -3.58 -8 -8 -8 z"></path>
                </svg>
            """,
            "class": "",
        },
    ],
}

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
    "ParameterMapInput": "milp_flare.flare.ParameterMapInput",
    "FLARENLPrompt": "milp_flare.flare_nl.FLARENLPrompt",
    "Harness": "milp_flare.harness.base.Harness",
    "HarnessRunResult": "milp_flare.harness.base.HarnessRunResult",
    "ClaudeCodeHarness": "milp_flare.harness.claude_code.ClaudeCodeHarness",
    "CodexHarness": "milp_flare.harness.codex.CodexHarness",
    "OpenCodeHarness": "milp_flare.harness.opencode.OpenCodeHarness",
    "COST_PER_MTOK": "milp_flare.harness.cost.COST_PER_MTOK",
    "ModelPrice": "milp_flare.harness.cost.ModelPrice",
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
