import pytest
from latex_eval.definitions import merge_definitions, normalize_definitions
from latex_eval.engine import Engine
from latex_eval.errors import DefinitionError
from latex_eval.parsing import parse_definition


def test_parse_value_definition():
    assert parse_definition("x=4") == {
        "kind": "value",
        "name": "x",
        "expression": "4",
    }


def test_parse_function_definition():
    assert parse_definition("f(x)=x^2") == {
        "kind": "function",
        "name": "f",
        "variables": ["x"],
        "expression": "x^2",
    }


def test_parse_multi_argument_function_definition():
    assert parse_definition("g(x,y)=x+y") == {
        "kind": "function",
        "name": "g",
        "variables": ["x", "y"],
        "expression": "x+y",
    }


def test_parse_definition_strips_math_delimiters():
    definition = parse_definition(r"$f(x)=x^2$")
    assert definition["name"] == "f"


def test_parse_definition_requires_equation():
    with pytest.raises(DefinitionError):
        parse_definition("x")


def test_parse_definition_rejects_complex_lhs():
    with pytest.raises(DefinitionError):
        parse_definition("x+1=2")


def test_parse_definition_rejects_duplicate_parameters():
    with pytest.raises(DefinitionError):
        parse_definition("f(x,x)=x")


def test_normalize_rejects_non_object():
    with pytest.raises(DefinitionError):
        normalize_definitions([])


def test_normalize_rejects_invalid_function():
    with pytest.raises(DefinitionError):
        normalize_definitions({"functions": {"f": {"expression": "x"}}})


def test_project_definitions_override_global():
    merged = merge_definitions(
        {
            "values": {"x": "1", "a": "2"},
            "functions": {"f": {"variables": ["x"], "expression": "x"}},
        },
        {
            "values": {"x": "9"},
            "functions": {"f": {"variables": ["x"], "expression": "x^2"}},
        },
    )
    assert merged["values"] == {"x": "9", "a": "2"}
    assert merged["functions"]["f"]["expression"] == "x^2"


def test_define_operation_returns_structured_definition():
    result = Engine().define("f(x)=x^2")
    assert result["kind"] == "definition"
    assert result["meta"]["definition"]["name"] == "f"


def test_user_function_argument_count_is_validated():
    with pytest.raises(DefinitionError):
        Engine().evaluate(
            "f(1,2)",
            definitions={"functions": {"f": {"variables": ["x"], "expression": "x^2"}}},
        )


def test_stored_definitions_are_not_executed_as_python():
    with pytest.raises(DefinitionError):
        Engine().evaluate(
            "x",
            definitions={"values": {"x": "__import__('os').system('false')"}},
        )


def test_value_definition_with_fraction():
    result = Engine().evaluate(
        "x+a", definitions={"values": {"x": "1", "a": r"\frac{1}{2}"}}
    )
    assert result["result"] == "1.5"


def test_fixture_definitions_are_valid():
    import json
    from pathlib import Path

    fixture = Path(__file__).resolve().parents[1] / "fixtures" / "definitions.json"
    definitions = json.loads(fixture.read_text())
    assert Engine().evaluate("f(x)+a", definitions=definitions)["result"] == "16.5"


def test_normalize_accepts_empty_list_maps():
    definitions = normalize_definitions({"values": [], "functions": []})
    assert definitions == {"values": {}, "functions": {}}
