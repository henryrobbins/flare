# Adding a new problem

Before adding a MILP formulation, you must create the optimization problem. This consists of writing a description, defining the necessary input data, and generating/solving a concrete instance of the problem. Afterward, you can add MILP formulations for the problem (see {doc}`add_formulation`).

First, pick the next free identifier `pN` (e.g. `p21`) and create the
directory `problems/p21/`. Next, populate this directory with all the files required by the dataset schema (see {ref}`problem-level-files`). The sections below walk through creating every necessary file. Lastly, append the problem identifier to the `problems` field in `dataset.json`.

## Description

The `description.md` file contains a natural-language description of the optimization problem. This description populates `problem_description` when rendering a formulation in Markdown (see {meth}`Formulation.render_markdown() <formulation_bench.formulation.Formulation.render_markdown>`). Problem descriptions vary in size.

### Examples

{doc}`/problems/p1`

:::{dropdown} `problems/p1/description.md`
:icon: code
:open:
```{literalinclude} ../../../../dataset/problems/p1/description.md
:language: markdown
:class: wrap
```
:::

{doc}`/problems/p12`

:::{dropdown} `problems/p12/description.md`
:icon: code
:open:
```{literalinclude} ../../../../dataset/problems/p12/description.md
:language: markdown
:class: wrap
```
:::

Find other problem descriptions in {doc}`/problems/index`.

## JSON File

The `problem.json` file defines the problem name, data parameters, and additional metadata. See {class}`Parameter <formulation_bench.models.Parameter>` for the parameters schema. The `metadata` field is freeform and typically includes `source` and `notes` fields which populate the source and notes blocks on the {doc}`/problems/index` pages.

### Examples

{doc}`/problems/p1`

:::{dropdown} `problems/p1/problem.json`
:icon: code
```{literalinclude} ../../../../dataset/problems/p1/problem.json
:language: json
```
:::

{doc}`/problems/p12`

:::{dropdown} `problems/p12/problem.json`
:icon: code
```{literalinclude} ../../../../dataset/problems/p12/problem.json
:language: json
```
:::

## Data & Solution

A single concrete instance must be defined in `data.json`. Its keys should match the parameter keys defined in `problem.json`.

Provide its optimal solution in `solution.json`. This dictionary has `variables` and `objective` keys. Note that variable values are specific to a *formulation*, not a problem. By convention, use the variable names of formulation `a` for the problem.

### Example

{doc}`/problems/p1`

:::{dropdown} `problems/p1/data.json`
:icon: code
:open:
```{literalinclude} ../../../../dataset/problems/p1/data.json
:language: json
```
:::

:::{dropdown} `problems/p1/solution.json`
:icon: code
:open:
```{literalinclude} ../../../../dataset/problems/p1/solution.json
:language: json
```
:::
