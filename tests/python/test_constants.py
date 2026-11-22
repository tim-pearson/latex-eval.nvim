from latex_eval.engine import Engine


def test_pi_constant():
    result = Engine().evaluate(r"\pi")
    assert result["result"] == "3.142"


def test_speed_of_light_is_evaluation_only():
    engine = Engine()
    assert engine.simplify("c")["result"] == "c"
    assert engine.evaluate("c")["kind"] == "approx"


def test_user_value_overrides_default_constant():
    result = Engine().evaluate("c", definitions={"values": {"c": "1"}})
    assert result["result"] == "1"


def test_user_value_is_available_to_simplify():
    result = Engine().simplify("c", definitions={"values": {"c": "1"}})
    assert result["result"] == "1"


def test_infinity_constant():
    assert Engine().evaluate(r"\infty")["result"] == r"\infty"


def test_golden_ratio_constant():
    result = Engine().evaluate(r"\phi")
    assert result["kind"] in {"approx", "exact"}
    assert result["result"] not in {"", r"\phi"}
