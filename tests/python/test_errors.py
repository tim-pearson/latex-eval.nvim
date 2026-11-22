import json

from latex_eval.engine import Engine
from latex_eval.errors import ParseError
from latex_eval.protocol import handle_request


def test_invalid_latex_raises_parse_error():
    try:
        Engine().evaluate(r"\frac{")
    except ParseError as error:
        assert error.code == "PARSE_ERROR"
    else:
        raise AssertionError("Expected ParseError")


def test_malformed_json_returns_structured_error():
    response = handle_request("{not json")
    assert response["ok"] is False
    assert response["error"]["code"] == "BAD_JSON"


def test_missing_expression_returns_structured_error():
    response = handle_request({"operation": "evaluate"})
    assert response["ok"] is False
    assert response["error"]["code"] == "INVALID_REQUEST"


def test_unknown_operation_returns_structured_error():
    response = handle_request({"operation": "unknown", "expression": "x"})
    assert response["ok"] is False
    assert response["error"]["code"] == "UNKNOWN_OPERATION"
    assert "available" in response["error"]["details"]


def test_operation_errors_are_structured():
    response = handle_request({"operation": "evaluate", "expression": r"\frac{"})
    assert response["ok"] is False
    assert response["error"]["code"] == "PARSE_ERROR"


def test_ambiguous_variable_response_contains_candidates():
    response = handle_request({"operation": "solve", "expression": "x+y=0"})
    assert response["ok"] is False
    assert response["error"]["code"] == "AMBIGUOUS_VARIABLE"
    assert response["error"]["details"]["candidates"] == ["x", "y"]


def test_invalid_definitions_type_is_rejected():
    response = handle_request(
        {
            "operation": "evaluate",
            "expression": "x",
            "definitions": [],
        }
    )
    assert response["ok"] is False
    assert response["error"]["code"] == "INVALID_REQUEST"


def test_response_is_json_serializable():
    response = handle_request({"operation": "evaluate", "expression": "1+1"})
    assert json.loads(json.dumps(response))["ok"] is True


def test_ping_operation():
    response = handle_request({"operation": "ping"})
    assert response == {
        "ok": True,
        "operation": "ping",
        "result": "pong",
        "display": "pong",
        "kind": "ping",
        "meta": {},
    }
