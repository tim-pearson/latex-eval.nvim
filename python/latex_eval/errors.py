class LatexEvalError(Exception):
    code = "LATEX_EVAL_ERROR"

    def __init__(self, message, *, code=None, details=None):
        super().__init__(message)
        self.message = str(message)
        if code is not None:
            self.code = code
        self.details = details

    def to_dict(self):
        payload = {"code": self.code, "message": self.message}
        if self.details is not None:
            payload["details"] = self.details
        return payload


class RequestError(LatexEvalError):
    code = "INVALID_REQUEST"


class ParseError(LatexEvalError):
    code = "PARSE_ERROR"


class OperationError(LatexEvalError):
    code = "OPERATION_ERROR"


class DefinitionError(LatexEvalError):
    code = "DEFINITION_ERROR"


class AmbiguousVariableError(LatexEvalError):
    code = "AMBIGUOUS_VARIABLE"

    def __init__(self, candidates, message=None):
        self.candidates = sorted(str(candidate) for candidate in candidates)
        super().__init__(
            message
            or "Could not infer a unique variable. Choose one of: "
            + ", ".join(self.candidates),
            details={"candidates": self.candidates},
        )


class MissingVariableError(LatexEvalError):
    code = "MISSING_VARIABLE"
