"""Build ReformulationVerifier instances from dict specs (loaded from YAML)."""

from typing import Any

from milp_flare import HARNESSES, RUNNERS, Harness, Runner

from src.llm_client import make_client
from src.verify.base import ReformulationVerifier
from src.verify.equivamap.equivamap import EquivaMapVerifier
from src.verify.execution.execution import ExecutionVerifier
from src.verify.flare import FLAREVerifier
from src.verify.llm.llm import LLMVerifier


def build_verifier(spec: dict[str, Any]) -> ReformulationVerifier:
    """Construct a verifier from a dict spec.

    Spec shape (by `type`):
      - {type: execution}
      - {type: equivamap, client: {<LLMConfig fields, optional provider>}}
      - {type: flare, harness: claude_code|codex|opencode,
         compute?: docker|modal,
         docker?: {image?: <str>},
         modal?: {cpu?: <float>, memory?: <int>, timeout?: <int>, ...},
         client: {model: <str>, effort?: <str>, provider?: <str>}}
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
        return FLAREVerifier(harness=harness)

    if vtype == "llm":
        client_spec = spec.pop("client")
        name = spec.pop("name")
        template = spec.pop("template", "flare_nl")
        include_implicit = spec.pop("include_implicit", True)
        return LLMVerifier(
            make_client(client_spec),
            name=name,
            template=template,
            include_implicit=include_implicit,
        )

    raise ValueError(f"unknown verifier type: {vtype!r}")


def _build_harness(spec: dict[str, Any]) -> Harness:
    htype = spec.pop("harness", "claude_code")
    cls = HARNESSES.get(htype)
    if cls is None:
        raise ValueError(f"unknown flare harness: {htype!r}")
    runner = _build_runner(spec)
    kwargs = dict(spec.pop("client"))
    if htype != "opencode":
        kwargs.pop("provider", None)
    return cls(**kwargs, runner=runner)


def _build_runner(spec: dict[str, Any]) -> Runner:
    # Select the compute backend (default docker; existing YAMLs unchanged).
    # The per-backend config block (e.g. `docker:`) is optional.
    compute = spec.pop("compute", "docker")
    cls = RUNNERS.get(compute)
    if cls is None:
        raise ValueError(f"unknown compute backend: {compute!r}")
    runner_cfg = spec.pop(compute, {})
    return cls(**runner_cfg)
