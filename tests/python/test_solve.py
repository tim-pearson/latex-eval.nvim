import pytest
from latex_eval.engine import Engine
from latex_eval.errors import AmbiguousVariableError, MissingVariableError


def test_solve_infers_single_variable():
    result = Engine().solve("x+3=0")
    assert result["result"] == "x = -3"
    assert result["meta"]["variable"] == "x"


def test_solve_explicit_variable():
    result = Engine().solve("x+y=0", variable="x")
    assert result["result"] == "x = - y"


def test_solve_ambiguous_variable():
    with pytest.raises(AmbiguousVariableError) as error:
        Engine().solve("x+y=0")
    assert error.value.candidates == ["x", "y"]


def test_solve_missing_variable():
    with pytest.raises(MissingVariableError):
        Engine().solve("2+2=5")


def test_solve_uses_definitions():
    result = Engine().solve("x+a=0", definitions={"values": {"a": "4"}})
    assert result["result"] == "x = -4"


def test_solve_requires_equation():
    with pytest.raises(Exception) as error:
        Engine().solve("x+3")
    assert "equation" in str(error.value).lower()


def test_solve_reports_no_solution():
    with pytest.raises(Exception) as error:
        Engine().solve("x=x+1")
    assert getattr(error.value, "code", "") == "NO_SOLUTION"
