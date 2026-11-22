import pytest
from latex_eval.engine import Engine
from latex_eval.errors import AmbiguousVariableError


def test_differentiate_infers_variable():
    result = Engine().differentiate("x^2")
    assert result["result"] == r"\frac{d}{dx}\left(x^2\right) = 2 x"
    assert result["meta"]["variable"] == "x"
    assert result["meta"]["rhs"] == "2 x"


def test_differentiate_explicit_variable():
    result = Engine().differentiate("x*y", variable="x")
    assert result["display"] == r"\frac{d}{dx}\left(x*y\right) = y"
    assert result["meta"]["replace"] == "y"


def test_differentiate_ambiguous_variable():
    with pytest.raises(AmbiguousVariableError):
        Engine().differentiate("x*y")


def test_differentiate_uses_user_functions():
    result = Engine().differentiate(
        "f(x)",
        definitions={"functions": {"f": {"variables": ["x"], "expression": "x^3"}}},
    )
    assert result["result"] == "f'(x) = 3 x^{2}"
    assert result["meta"]["rhs"] == "3 x^{2}"


def test_differentiate_equation_form_uses_leibniz_notation():
    result = Engine().differentiate("y=3x")
    assert result["result"] == r"\frac{dy}{dx} = 3"
    assert result["meta"]["rhs"] == "3"
    assert result["meta"]["replace"] == "y = 3"


def test_differentiate_function_equation_uses_prime_notation():
    result = Engine().differentiate("f(x)=4x")
    assert result["result"] == "f'(x) = 4"
    assert result["meta"]["replace"] == "f(x) = 4"


def test_differentiate_second_order_uses_double_prime():
    result = Engine().differentiate("f(x)=4x", order=2)
    assert result["result"] == "f''(x) = 0"


def test_differentiate_second_order_leibniz():
    result = Engine().differentiate("y=3x", order=2)
    assert result["result"] == r"\frac{d^{2}y}{dx^{2}} = 0"


def test_differentiate_increments_existing_leibniz_notation():
    result = Engine().differentiate(r"\frac{dy}{dx}=3x")
    assert result["result"] == r"\frac{d^{2}y}{dx^{2}} = 3"
    assert result["meta"]["replace"] == result["display"]


def test_differentiate_increments_existing_second_derivative():
    result = Engine().differentiate(r"\frac{d^2y}{dx^2}=3x")
    assert result["result"] == r"\frac{d^{3}y}{dx^{3}} = 3"


def test_differentiate_increments_prime_notation():
    result = Engine().differentiate("f'(x)=3x")
    assert result["result"] == "f''(x) = 3"
    result = Engine().differentiate("f''(x)=3x")
    assert result["result"] == "f'''(x) = 3"


def test_differentiate_accepts_nonstandard_second_derivative_lhs():
    result = Engine().differentiate(r"\frac{dy^2}{dx^2}=3x")
    assert result["result"] == r"\frac{d^{3}y}{dx^{3}} = 3"
