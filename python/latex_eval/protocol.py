import json
import sys
import traceback
from contextlib import redirect_stdout

from .engine import Engine
from .errors import LatexEvalError, RequestError
from .operations import get_operation, operation_names


def _error_response(operation, error):
    return {
        "ok": False,
        "operation": operation,
        "error": error.to_dict(),
    }


def handle_request(payload):
    operation_name = None
    try:
        if isinstance(payload, (str, bytes)):
            try:
                request = json.loads(payload)
            except (json.JSONDecodeError, UnicodeDecodeError) as exc:
                raise RequestError(
                    f"Malformed JSON request: {exc}",
                    code="BAD_JSON",
                ) from exc
        elif isinstance(payload, dict):
            request = payload
        else:
            raise RequestError("Request must be a JSON object")

        if not isinstance(request, dict):
            raise RequestError("Request must be a JSON object")

        operation_name = request.get("operation")
        if not isinstance(operation_name, str) or not operation_name:
            raise RequestError("Request is missing a string 'operation'")

        operation = get_operation(operation_name)
        if operation is None:
            raise RequestError(
                f"Unknown operation '{operation_name}'",
                code="UNKNOWN_OPERATION",
                details={"available": operation_names()},
            )

        expression = request.get("expression")
        if operation_name != "ping" and (
            not isinstance(expression, str) or not expression.strip()
        ):
            raise RequestError("Request is missing a non-empty string 'expression'")

        definitions = request.get("definitions")
        if isinstance(definitions, list) and not definitions:
            definitions = {}
        if definitions is not None and not isinstance(definitions, dict):
            raise RequestError("'definitions' must be an object")

        options = request.get("options")
        if isinstance(options, list) and not options:
            options = {}
        if options is not None and not isinstance(options, dict):
            raise RequestError("'options' must be an object")
        request["options"] = options
        request["definitions"] = definitions

        engine = Engine()
        with redirect_stdout(sys.stderr):
            result = operation.run(request, engine)

        if not isinstance(result, dict) or "display" not in result:
            raise RequestError(
                f"Operation '{operation_name}' returned an invalid response",
                code="INVALID_OPERATION_RESPONSE",
            )

        response = {"ok": True, "operation": operation_name}
        response.update(result)
        return response
    except LatexEvalError as exc:
        return _error_response(operation_name, exc)
    except Exception as exc:  # noqa: BLE001
        traceback.print_exc(file=sys.stderr)
        return _error_response(
            operation_name,
            LatexEvalError(
                f"Unexpected backend error: {exc}",
                code="INTERNAL_ERROR",
            ),
        )


def serve_stdin():
    raw = sys.stdin.read()
    if not raw.strip():
        response = _error_response(
            None,
            RequestError("No request was provided on stdin", code="EMPTY_REQUEST"),
        )
    else:
        response = handle_request(raw)
    sys.stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
    sys.stdout.flush()
    return 0 if response.get("ok") else 1
