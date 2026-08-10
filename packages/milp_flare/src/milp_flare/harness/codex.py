import json
import shutil
import tempfile
import threading
from pathlib import Path
from typing import Any

from milp_flare._assets import SCRIPTS_DIR, SKILLS_DIR
from milp_flare.harness.base import Harness
from milp_flare.harness.runner import AuthSpec, Runner

_TEMPLATE: str = (SCRIPTS_DIR / "codex_agent.sh").read_text()


class CodexHarness(Harness):
    """Codex agent harness for FLARE.

    Use the :codex:`Codex CLI </>` as an agent harness. Authentication is provided
    by running ``codex login`` on the host, which writes ``~/.codex/auth.json``;
    only that credential is staged into the container, read-write so Codex can
    refresh its access token. See :ref:`harness-codex` for setup instructions.

    Parameters
    ----------
    model : str
        OpenAI model identifier. Only supports models that are supported by the
        Codex CLI (e.g., ``"gpt-5.4"``, ``"gpt-5.5"``). See :codex:`/models` for
        up-to-date model information.
    effort : str, default ``"medium"``
        Reasoning effort level (``"none"``, ``"low"``, ``"medium"``,
        ``"high"``, ``"xhigh"``). See :codex:`/config-basic#reasoning-effort`
        for supported effort levels.

    Attributes
    ----------
    name : str
        Name of the agent harness: ``"codex"``.
    model : str
        Model identifier this harness is configured to use.
    effort : str
        Reasoning effort level this harness is configured to use.

    Examples
    --------
    Configure Codex agent harness with GPT-5.4 and high effort::

        >>> from milp_flare import FLARE
        >>> from milp_flare.harness import CodexHarness
        >>> harness = CodexHarness(model="gpt-5.4", effort="high")
        >>> print(json.dumps(harness.get_config_dict(), indent=2))
        {
          "harness": "codex",
          "compute": "docker",
          "image": "flare-agent:latest",
          "model": "gpt-5.4",
          "effort": "high"
        }
    """

    name = "codex"

    #: Holds the staged minimal ``.codex`` so it outlives :meth:`auth_spec` until the
    #: runner pushes/bind-mounts it; cleaned up when the harness is collected.
    _codex_home: tempfile.TemporaryDirectory[str] | None = None

    def __init__(
        self, model: str, effort: str = "medium", runner: Runner | None = None
    ) -> None:
        super().__init__(model, effort, runner)
        # Guards the lazy _codex_home init: one harness instance is shared across
        # pairs run concurrently, so the check-then-create must be atomic.
        self._codex_home_lock = threading.Lock()

    def configure_wd(self, wd: Path) -> None:
        super().configure_wd(wd)
        # MCP server configuration is handled in the agent command:
        #   milp_flare/assets/scripts/codex_agent.sh
        # Copy skills to .agents/skills
        # https://developers.openai.com/codex/skills#where-to-save-skills
        agents_skills = wd / ".agents" / "skills"
        agents_skills.parent.mkdir(exist_ok=True)
        shutil.copytree(SKILLS_DIR, agents_skills, dirs_exist_ok=True)

    def auth_spec(self) -> AuthSpec:
        # We use this authentication strategy instead of an API key to avoid the
        # higher API costs compared a ChatGPT subscription. The runner mounts the
        # dir rw because codex refreshes its access token mid-session.
        # https://developers.openai.com/codex/auth/ci-cd-auth
        #
        # Mount ONLY the auth credential, never the whole ~/.codex: the host's
        # config.toml registers personal MCP servers (e.g. a localhost Zotero
        # server) that don't exist in the sandbox, and codex aborts when one is
        # unreachable. The agent command supplies the lean-lsp MCP via -c
        # overrides, so no host config is needed.
        auth = Path.home() / ".codex" / "auth.json"
        if not auth.is_file():
            raise RuntimeError(
                "codex harness requires ~/.codex/auth.json from `codex login`"
            )
        # Lock the check-then-create: without it, two concurrent runs both see None,
        # the second's TemporaryDirectory overwrites the first, and the orphaned
        # one's finalizer deletes its dir out from under the run still staging it --
        # surfacing as a missing auth.json.
        with self._codex_home_lock:
            if self._codex_home is None:
                self._codex_home = tempfile.TemporaryDirectory(prefix="codex-home-")
                # copy2 preserves auth.json's 0600 mode, which codex requires.
                shutil.copy2(auth, Path(self._codex_home.name) / "auth.json")
        return AuthSpec(env=[], home_dirs=[(Path(self._codex_home.name), ".codex")])

    def _agent_command(self) -> str:
        # Pass model and effort to the agent command template
        return _TEMPLATE.replace("<<MODEL>>", self.model).replace(
            "<<EFFORT>>", self.effort
        )

    def _parse_lines(self, lines: list[str]) -> dict[str, Any]:
        """Parse `codex exec --json` output."""
        input_tokens = 0
        output_tokens = 0
        cached_input_tokens = 0
        stop_reason: str | None = None

        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") != "turn.completed":
                continue
            usage = event.get("usage") or {}
            it = (
                usage.get("input_tokens")
                or usage.get("inputTokens")
                or usage.get("prompt_tokens")
                or 0
            )
            ot = (
                usage.get("output_tokens")
                or usage.get("outputTokens")
                or usage.get("completion_tokens")
                or 0
            )
            # `cached_input_tokens` is the cache-hit subset of `input_tokens`,
            # not an addend; it bills at the model's discounted cached rate.
            ct = usage.get("cached_input_tokens") or usage.get("cachedInputTokens") or 0
            if isinstance(it, int):
                input_tokens += it
            if isinstance(ct, int):
                cached_input_tokens += ct
            if isinstance(ot, int):
                output_tokens += ot
            sr = event.get("stop_reason") or event.get("finish_reason")
            if isinstance(sr, str):
                stop_reason = sr

        return {
            "stop_reason": stop_reason,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "cached_input_tokens": cached_input_tokens,
            "cost_usd": None,
        }
