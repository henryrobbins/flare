from formulation_bench import Dataset
from formulation_bench.models import Dimension, DimensionType, Shape


def test_parse_fixed() -> None:
    d = Dimension.parse("n")
    assert d.type is DimensionType.fixed
    assert d.dim_str == "n"
    assert d.array is None
    assert d.indexed_by is None
    assert d.set_name is None


def test_parse_expression() -> None:
    for dim_str in ("K+N", "T-1"):
        d = Dimension.parse(dim_str)
        assert d.type is DimensionType.expression
        assert d.dim_str == dim_str


def test_parse_ragged() -> None:
    d = Dimension.parse("n_S[n_G]")
    assert d.type is DimensionType.ragged
    assert d.array == "n_S"
    assert d.indexed_by == "n_G"
    assert d.set_name is None


def test_parse_cardinality() -> None:
    d = Dimension.parse("|I|")
    assert d.type is DimensionType.cardinality
    assert d.set_name == "I"
    assert d.array is None
    assert d.indexed_by is None


def test_dimension_str_is_dim_str() -> None:
    assert str(Dimension.parse("n_S[n_G]")) == "n_S[n_G]"


def test_shape_scalar() -> None:
    shape = Shape.parse([])
    assert shape.is_scalar
    assert not shape.is_ragged
    assert not shape.has_cardinality
    assert len(shape) == 0


def test_shape_sequence_protocol() -> None:
    shape = Shape.parse(["n", "n"])
    assert not shape.is_scalar
    assert len(shape) == 2
    assert [d.dim_str for d in shape] == ["n", "n"]
    assert shape[0].type is DimensionType.fixed


def test_shape_is_ragged() -> None:
    shape = Shape.parse(["n_G", "n_S[n_G]", "T"])
    assert shape.is_ragged
    assert not shape.has_cardinality


def test_shape_has_cardinality() -> None:
    shape = Shape.parse(["N", "|I|"])
    assert shape.has_cardinality
    assert not shape.is_ragged


def test_shape_resolve_ragged() -> None:
    shape = Shape.parse(["n_G", "n_S[n_G]"])
    resolved = shape.resolve(shape[1])
    assert resolved is not None
    assert resolved.dim_str == "n_G"
    assert resolved is shape[0]


def test_shape_resolve_non_ragged_is_none() -> None:
    shape = Shape.parse(["n_G", "n_S[n_G]"])
    assert shape.resolve(shape[0]) is None


def test_shape_resolve_dangling_index_is_none() -> None:
    shape = Shape.parse(["n_S[missing]"])
    assert shape.resolve(shape[0]) is None


def test_shape_repr_and_str() -> None:
    shape = Shape.parse(["n_G", "n_S[n_G]"])
    assert repr(shape) == "Shape(['n_G', 'n_S[n_G]'])"
    assert str(shape) == "['n_G', 'n_S[n_G]']"
    assert str(Shape.parse([])) == "[]"


def test_shape_equality() -> None:
    assert Shape.parse(["n", "m"]) == Shape.parse(["n", "m"])
    assert Shape.parse(["n"]) != Shape.parse(["m"])


def test_dataset_cardinality_variables_have_indices(dataset: Dataset) -> None:
    """Every variable with a cardinality dimension provides `indices`."""
    seen = False
    for problem in dataset.problems.values():
        for f in problem.formulations.values():
            for v in f.variables.values():
                if v.shape.has_cardinality:
                    seen = True
                    assert v.indices is not None
    assert seen, "expected at least one cardinality variable in the dataset"
