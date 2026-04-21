from milp_eq_tools import Dataset, Formulation, Problem


def test_imports() -> None:
    assert Dataset is not None
    assert Problem is not None
    assert Formulation is not None
