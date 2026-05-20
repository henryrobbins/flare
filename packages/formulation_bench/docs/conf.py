import sys
from importlib.metadata import version as _pkg_version
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "_ext"))

project = "formulation_bench"
author = "Henry Robbins"
copyright = "2026, Henry Robbins"
release = _pkg_version("formulation-bench")

extensions = [
    "myst_parser",
    "sphinx.ext.autodoc",
    "sphinx.ext.viewcode",
    "sphinx.ext.intersphinx",
    "numpydoc",
    "gen_problem_pages",
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
html_title = "FormulationBench"

autodoc_default_options = {"members": True, "undoc-members": True}
autodoc_typehints = "none"
numpydoc_class_members_toctree = False
numpydoc_show_class_members = False
numpydoc_xref_param_type = True
numpydoc_xref_ignore = {"of", "or", "optional", "default"}
numpydoc_xref_aliases = {
    "Problem": "formulation_bench.problem.Problem",
    "Formulation": "formulation_bench.formulation.Formulation",
    "Parameter": "formulation_bench.models.Parameter",
    "ParameterType": "formulation_bench.models.ParameterType",
    "Variable": "formulation_bench.models.Variable",
    "VariableType": "formulation_bench.models.VariableType",
    "Definition": "formulation_bench.models.Definition",
    "Assumption": "formulation_bench.models.Assumption",
    "Constraint": "formulation_bench.models.Constraint",
    "Objective": "formulation_bench.models.Objective",
    "Solution": "formulation_bench.models.Solution",
    "Reformulation": "formulation_bench.reformulation.Reformulation",
    "download_dataset": "formulation_bench.download_dataset",
}
