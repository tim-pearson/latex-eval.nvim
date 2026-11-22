from latex_eval.engine import Engine


def test_evaluate_exact_rational():
    result = Engine().evaluate(r"\frac{1}{2}")
    assert result["result"] == "0.5"
    assert result["kind"] == "exact"


def test_evaluate_symbolic_expression():
    result = Engine().evaluate("x+1")
    assert result["result"] == "x + 1"
    assert result["kind"] == "symbolic"


def test_evaluate_scientific_result():
    result = Engine().evaluate(r"\frac{1}{2} \cdot 9.11 \times 10^{-31} \cdot c^2")
    assert result["kind"] == "approx"
    assert "10^{-14}" in result["result"]


def test_evaluate_speed_of_light_constant():
    result = Engine().evaluate("c")
    assert result["result"] == r"3 \times 10^{8}"
    assert result["kind"] == "approx"


def test_evaluate_eulers_identity():
    result = Engine().evaluate(r"e^{i\pi}")
    assert result["result"] == "-1"
    assert result["kind"] == "exact"


def test_evaluate_with_stored_value():
    result = Engine().evaluate("x+1", definitions={"values": {"x": "4"}})
    assert result["result"] == "5"
    assert result["kind"] == "exact"


def test_evaluate_with_chained_values():
    result = Engine().evaluate("y+1", definitions={"values": {"x": "4", "y": "x+1"}})
    assert result["result"] == "6"


def test_evaluate_user_function():
    definitions = {"functions": {"f": {"variables": ["x"], "expression": "x^2"}}}
    result = Engine().evaluate("f(3)", definitions=definitions)
    assert result["result"] == "9"


def test_evaluate_user_function_symbolically():
    definitions = {"functions": {"f": {"variables": ["x"], "expression": "x^2"}}}
    result = Engine().evaluate("f(y)", definitions=definitions)
    assert result["result"] == "y^{2}"
    assert result["kind"] == "symbolic"


def test_evaluate_nested_user_functions():
    definitions = {
        "functions": {
            "f": {"variables": ["x"], "expression": "x^2"},
            "g": {"variables": ["x"], "expression": "x+1"},
        }
    }
    assert Engine().evaluate("f(g(2))", definitions=definitions)["result"] == "9"


def test_evaluate_multi_argument_user_function():
    definitions = {"functions": {"f": {"variables": ["x", "y"], "expression": "x*y"}}}
    assert Engine().evaluate("f(2,3)", definitions=definitions)["result"] == "6"


def test_evaluate_decimal_places_option():
    result = Engine().evaluate(r"\pi", options={"decimal_places": 5})
    assert result["result"] == "3.14159"


def test_evaluate_hbar_output():
    assert Engine().evaluate(r"\bar{h}")["result"] == r"\hbar"
