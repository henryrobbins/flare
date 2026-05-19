# Adding a new problem to the dataset

A problem is a self-contained optimization story plus the data needed
to instantiate one concrete example of it. Once a problem exists, you
can hang any number of formulations off of it
(see {doc}`add_formulation`).

Pick the next free identifier `pN` (e.g. `p57`) and create the
directory `dataset/problems/p57/` with four files.

## 1. `description.md`

A natural-language statement of the optimization problem. Self-contained
— a reader should be able to understand what is being optimized
without any other file. Keep it parameter-name-free if possible; the
formulations are responsible for binding parameter names.

```markdown
A theme park operates two types of ticket machines: cash-based and
card-only. Each cash machine processes people at a fixed rate per hour
and consumes a fixed number of paper rolls per hour; card-only
machines have their own rate and roll consumption. The park must
process at least a given minimum of people per hour without exceeding
a maximum supply of paper rolls per hour. The number of card-only
machines cannot exceed the number of cash-based ones. Determine how
many of each machine type minimize the total number of machines.
```

## 2. `problem.json`

The parameter *schema*: every parameter the problem refers to, with
its description, type, and shape. Shapes follow the notation in
{doc}`../schema` — `[]` for a scalar, `["n"]` for a vector,
etc. Include a `metadata.source` block recording where the problem
came from.

```json
{
    "name": "Amusement Park Ticket Machines",
    "parameters": {
        "CashMachineProcessingRate": {
            "description": "Processing rate of a cash-based machine in people per hour",
            "type": "continuous",
            "shape": []
        },
        "CardMachineProcessingRate": { "...": "..." }
    },
    "metadata": {
        "source": {"dataset": "EquivaFormulation", "instance_id": 47},
        "notes": ["Implicit non-negativity assumptions added for every parameter."]
    }
}
```

## 3. `data.json`

A single concrete instance: one value for every parameter listed in
`problem.json`. This instance is what every formulation will be solved
against; valid formulations must agree on the optimal objective for
this instance.

```json
{
    "CashMachineProcessingRate": 20,
    "CardMachineProcessingRate": 30,
    "CashMachinePaperRolls": 4,
    "CardMachinePaperRolls": 5,
    "MinPeopleProcessed": 500,
    "MaxPaperRolls": 90
}
```

Choose an instance that is *non-trivial*: the optimum should not be
degenerate (e.g. all zeros), so that two different formulations
disagreeing about the constraints will produce different objectives.

## 4. `solution.json`

A reference optimal solution for the instance in `data.json`. Include
variable values and the optimal objective. Variable names here are
informational only — formulations may rename them — but the
objective value is the source of truth that
`scripts/dataset/validate_solve.py` compares each formulation against.

```json
{
    "variables": {
        "NumCashMachines": 10.0,
        "NumCardMachines": 10.0
    },
    "objective": 20.0
}
```

## Wiring it in

You do **not** need to edit `dataset/dataset.json` until you also have
formulation pairs: `dataset.json` lists labelled reformulation pairs,
not problems. Problems are discovered by walking
`dataset/problems/*/`.

Next: add at least one formulation following {doc}`add_formulation`.
