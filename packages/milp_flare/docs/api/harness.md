# `harness`

## Base

```{eval-rst}
.. autoclass:: milp_flare.harness.base.Harness
   :exclude-members: name

.. autoclass:: milp_flare.harness.base.HarnessRunResult
   :no-members:

.. autodata:: milp_flare.harness.base.IMAGE
```

(agent-harnesses)=
## Agent Harnesses

```{eval-rst}
.. autoclass:: milp_flare.harness.claude_code.ClaudeCodeHarness
   :show-inheritance:
   :exclude-members: configure_wd, name
```

```{eval-rst}
.. autoclass:: milp_flare.harness.codex.CodexHarness
   :show-inheritance:
   :exclude-members: configure_wd, name
```

```{eval-rst}
.. autoclass:: milp_flare.harness.opencode.OpenCodeHarness
   :show-inheritance:
   :exclude-members: configure_wd, get_config_dict, name
```

## Pricing

```{eval-rst}
.. autodata:: milp_flare.harness.cost.COST_PER_MTOK
```
