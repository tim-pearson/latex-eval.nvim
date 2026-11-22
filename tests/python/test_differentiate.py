import pytest
from latex_eval.engine import Engine
from latex_eval.errors import AmbiguousVariableError


def test_differentiate_infers_variable():
    result = Engine().differentiate("x^2")
    assert result["result"] == "2 x"
    assert result["meta"]["variable"] == "x"


def test_differentiate_explicit_variable():
    assert Engine().differentiate("x*y", variable="x")["result"] == "y"


def test_differentiate_ambiguous_variable():
    with pytest.raises(AmbiguousVariableError):
        Engine().differentiate("x*y")


def test_differentiate_equation_variable_dropdown_candidates():
    with pytest.raises(AmbiguousVariableError) as error:
        Engine().differentiate("y=3x")
    assert error.value.candidates == ["x", "y"]


def test_differentiate_uses_user_functions():
    result = Engine().differentiate(
        "f(x)",
        definitions={"functions": {"f": {"variables": ["x"], "expression": "x^3"}}},
    )
    assert result["result"] == "3 x^{2}"


def test_differentiate_equation_preserves_left_hand_side():
    result = Engine().differentiate("y=x^2", variable="x")
    assert result["result"] == "y = 2 x"


def test_differentiate_equation_without_explicit_variable_can_use_dropdown():
    result = Engine().differentiate("y=x^2", variable="x")
    assert result["display"] == "y = 2 x"
