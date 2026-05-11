"""Build ReformulationVerifier instances from dict specs (loaded from YAML)."""

from pathlib import Path

from src.llm_client import LLMConfig, make_client
from src.verify.base import ReformulationVerifier
from src.verify.equivamap.equivamap import EquivaMapVerifier
from src.verify.execution.execution import ExecutionVerifier
from src.verify.flare.flare import FLAREVerifier
from src.verify.flare.harness import HARNESSES, Harness
from src.verify.llm.llm import LLMVerifier


def build_verifier(spec: dict, *, repo_root: Path) -> ReformulationVerifier:
    """Construct a verifier from a dict spec.

    Spec shape (by `type`):
      - {type: execution}
      - {type: equivamap, client: {<LLMConfig fields, optional provider>}}
      - {type: flare, harness: claude_code|codex|opencode,
         image?: <docker image tag>,
         client: {<LLMConfig fields, optional provider>}}
      - {type: llm, name: <str>, client: {...}, template?: <str>,
         include_implicit?: <bool>}

    The `flare` spec accepts a legacy form without an explicit `harness` key,
    in which case it defaults to `claude_code`.
    """
    spec = dict(spec)
    vtype = spec.pop("type")

    if vtype == "execution":
        return ExecutionVerifier()

    if vtype == "equivamap":
        client_spec = spec.pop("client")
        return EquivaMapVerifier(make_client(client_spec))

    if vtype == "flare":
        harness = _build_harness(spec)
        return FLAREVerifier(repo_root=repo_root, harness=harness)

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


def _build_harness(spec: dict) -> Harness:
    htype = spec.pop("harness", "claude_code")
    cls = HARNESSES.get(htype)
    if cls is None:
        raise ValueError(f"unknown flare harness: {htype!r}")
    image = spec.pop("image", "flare-agent:latest")
    client_spec = dict(spec.pop("client"))
    provider = client_spec.pop("provider", None)
    config = LLMConfig.from_dict(client_spec)
    kwargs = {"provider": provider} if provider is not None else {}
    return cls(config=config, image=image, **kwargs)
