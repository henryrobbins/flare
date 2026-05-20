# FormulationBench

FormulationBench is a collection of 20 optimization problems with 116 mixed-integer linear programming (MILP) formulations. Each formulation has a natural language description, LaTeX formulation, GurobiPy implementation, and Lean representation. Furthermore, there are 96 pairs of formulations consisting of 70 positive reformulation examples and 26 negative examples. Each positive example has a machine-checked Lean 4 reformulation proof. 

The best way to work with FormulationBench is through the `formulation-bench` Python package. See the [documentation](https://formulation-bench.henryrobbins.com) for installation instructions, dataset schema, problem/formulation descriptions, and usage guides.

## Citations

FormulationBench is comprised of problems and formulations from the following sources:

```bibtex
@article{yazdani2025,
  title = {{EvoCut}}: {{Strengthening Integer Programs}} via {{Evolution-Guided Language Models}},
  author = {Yazdani, Milad and Mostajabdaveh, Mahdi and Aref, Samin and Zhou, Zirui},
  journal = {arXiv preprint arXiv:2508.11850},
  year = 2025
}

@inproceedings{zhai2025a,
  title={\textup{EquivaMap}: Leveraging \textup{LLMs} for Automatic Equivalence Checking of Optimization Formulations},
  author={Haotian Zhai and Connor Lawless and Ellen Vitercik and Liu Leqi},
  booktitle={Forty-second International Conference on Machine Learning},
  year={2025}
}

@mastersthesis{ferchtandiker2025,
  title = {Generating {{Efficient Optimization Formulations Using Large Language Models}}},
  author = {Ferchtandiker, Nathan},
  year = 2025,
  month = jul,
  langid = {english},
  school = {Universiteit van Amsterdam}
}
```

## License

[MIT](LICENSE.md)
