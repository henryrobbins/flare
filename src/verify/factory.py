"""Build ReformulationVerifier instances from dict specs (loaded from YAML)."""

from pathlib import Path

from src.llm_client import make_client
from src.verify.base import ReformulationVerifier
from src.verify.equivamap.equivamap import EquivaMapVerifier
from src.verify.execution.execution import ExecutionVerifier
from src.verify.flare.flare import FLAREVerifier
from src.verify.llm.llm import LLMVerifier


def build_verifier(spec: dict, *, repo_root: Path) -> ReformulationVerifier:
    """Construct a verifier from a dict spec.

    Spec shape (by `type`):
      - {type: execution}
      - {type: equivamap, client: {<LLMConfig fields, optional provider>}}
      - {type: flare, model: <str>}
      - {type: llm, name: <str>, client: {...}, template?: <str>,
         include_implicit?: <bool>}
    """
    spec = dict(spec)
    vtype = spec.pop("type")

    if vtype == "execution":
        return ExecutionVerifier()

    if vtype == "equivamap":
        client_spec = spec.pop("client")
        return EquivaMapVerifier(make_client(client_spec))

    if vtype == "flare":
        model = spec.pop("model")
        return FLAREVerifier(repo_root=repo_root, model=model)

    if vtype == "llm":
        client_spec = spec.pop("client")
        name = spec.pop("name")
        template = spec.pop("template", "reformulation.j2")
        include_implicit = spec.pop("include_implicit", True)
        return LLMVerifier(
            make_client(client_spec),
            name=name,
            template=template,
            include_implicit=include_implicit,
        )

    raise ValueError(f"unknown verifier type: {vtype!r}")
