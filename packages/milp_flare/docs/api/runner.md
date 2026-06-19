---
tocdepth: 3
---

# `harness.runner`

A {py:class}`~milp_flare.harness.runner.base.Runner` is the compute backend that
launches the FLARE agent container for a populated working directory. Each
{py:meth}`~milp_flare.harness.runner.base.Runner.start` call returns an
{py:class}`~milp_flare.harness.runner.base.AgentRun` handle that owns the
lifecycle of the in-flight run.

(compute-runners)=
## Base

```{eval-rst}
.. autoclass:: milp_flare.harness.runner.base.Runner
   :exclude-members: name, home, image

.. autoclass:: milp_flare.harness.runner.base.AgentRun
   :exclude-members: stdout

.. autoclass:: milp_flare.harness.runner.base.AuthSpec
   :no-members:

.. autodata:: milp_flare.harness.runner.base.IMAGE
```

## Docker

```{eval-rst}
.. autoclass:: milp_flare.harness.runner.docker.DockerRunner
   :show-inheritance:
   :exclude-members: name, home, start, image

.. autoclass:: milp_flare.harness.runner.docker.DockerAgentRun
   :show-inheritance:
   :no-members:
```

## Modal

```{eval-rst}
.. autoclass:: milp_flare.harness.runner.modal.ModalRunner
   :show-inheritance:
   :exclude-members: name, home, start, image

.. autoclass:: milp_flare.harness.runner.modal.ModalAgentRun
   :show-inheritance:
   :no-members:
```
