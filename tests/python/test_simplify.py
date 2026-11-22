from latex_eval.engine import Engine


def test_simplify_keeps_speed_of_light_symbolic():
    result = Engine().simplify(r"\frac{e^{\ln(c^2)}}{c}")
    assert result["result"] == "c"


def test_simplify_cancels_expression():
    assert Engine().simplify(r"\frac{x^2}{x}")["result"] == "x"


def test_simplify_uses_stored_values():
    result = Engine().simplify("x+1", definitions={"values": {"x": "4"}})
    assert result["result"] == "5"


def test_simplify_uses_user_functions():
    result = Engine().simplify(
        "f(x)",
        definitions={"functions": {"f": {"variables": ["x"], "expression": "x^2"}}},
    )
    assert result["result"] == "x^{2}"
