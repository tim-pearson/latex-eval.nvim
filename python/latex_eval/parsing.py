import re

from latex2sympy2 import latex2sympy

from .errors import DefinitionError, ParseError

CALL_PATTERN = re.compile(
    r"(?<![\\A-Za-z0-9_])([A-Za-z][A-Za-z0-9_]*)\s*(?:\\left\s*)?\("
)
IDENTIFIER_PATTERN = re.compile(r"^\\?[A-Za-z][A-Za-z0-9_]*$")
FUNCTION_HEAD_PATTERN = re.compile(
    r"^(\\?[A-Za-z][A-Za-z0-9_]*)\s*\((.*)\)$", re.DOTALL
)


def strip_math_delimiters(text: str) -> str:
    value = (text or "").strip()
    if not value:
        return value

    if value.startswith("$$") and value.endswith("$$") and len(value) >= 4:
        return value[2:-2].strip()
    if value.startswith("$") and value.endswith("$") and len(value) >= 2:
        return value[1:-1].strip()
    if value.startswith(r"\[") and value.endswith(r"\]"):
        return value[2:-2].strip()
    if value.startswith(r"\(") and value.endswith(r"\)"):
        return value[2:-2].strip()

    environment = re.match(
        r"^\s*\\begin\{([A-Za-z]+\*?)\}(.*)\\end\{\1\}\s*$",
        value,
        re.DOTALL,
    )
    if environment:
        return environment.group(2).strip()

    return value


def _is_escaped(text: str, index: int) -> bool:
    backslashes = 0
    cursor = index - 1
    while cursor >= 0 and text[cursor] == "\\":
        backslashes += 1
        cursor -= 1
    return backslashes % 2 == 1


def find_matching_paren(text: str, open_index: int):
    if open_index >= len(text) or text[open_index] != "(":
        return None
    depth = 0
    for index in range(open_index, len(text)):
        char = text[index]
        if char == "\\":
            continue
        if _is_escaped(text, index):
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
    return None


def split_top_level(text: str, separator: str = ","):
    parts = []
    current = []
    depths = {"(": 0, "[": 0, "{": 0}
    closing = {")": "(", "]": "[", "}": "{"}
    for index, char in enumerate(text):
        if char == "\\":
            current.append(char)
            continue
        if char in depths:
            depths[char] += 1
        elif char in closing:
            opener = closing[char]
            depths[opener] = max(0, depths[opener] - 1)
        elif char == separator and all(depth == 0 for depth in depths.values()):
            parts.append("".join(current).strip())
            current = []
            continue
        current.append(char)
    parts.append("".join(current).strip())
    return parts


def split_equation(text: str):
    value = strip_math_delimiters(text)
    depths = {"(": 0, "[": 0, "{": 0}
    closing = {")": "(", "]": "[", "}": "{"}
    for index, char in enumerate(value):
        if char == "\\":
            continue
        if _is_escaped(value, index):
            continue
        if char in depths:
            depths[char] += 1
        elif char in closing:
            opener = closing[char]
            depths[opener] = max(0, depths[opener] - 1)
        elif char == "=" and all(depth == 0 for depth in depths.values()):
            return value[:index].strip(), value[index + 1 :].strip()
    return None


def parse_latex(text: str):
    value = strip_math_delimiters(text)
    if not value:
        raise ParseError("Expression is empty")
    try:
        return latex2sympy(value)
    except Exception as exc:
        raise ParseError(
            f"Could not parse LaTeX: {exc}",
            code="PARSE_ERROR",
            details={"expression": value},
        ) from exc


def substitute_parameter(body: str, name: str, argument: str) -> str:
    pattern = re.compile(r"(?<![\\A-Za-z0-9_])" + re.escape(name) + r"(?![A-Za-z0-9_])")
    wrapped = r"\left(" + argument + r"\right)"
    return pattern.sub(lambda _match: wrapped, body)


def expand_function_calls(
    text: str, functions, max_depth: int = 20, _depth: int = 0
) -> str:
    if not functions:
        return text
    if _depth > max_depth:
        raise DefinitionError(
            "Function definition expansion exceeded the recursion limit"
        )

    output = []
    position = 0
    while True:
        match = CALL_PATTERN.search(text, position)
        if not match:
            output.append(text[position:])
            break

        name = match.group(1)
        if name not in functions:
            output.append(text[position : match.start() + 1])
            position = match.start() + 1
            continue

        open_index = match.end() - 1
        close_index = find_matching_paren(text, open_index)
        if close_index is None:
            output.append(text[position:])
            break

        definition = functions[name]
        variables = definition.get("variables") or []
        expression = definition.get("expression") or ""
        arguments_text = text[open_index + 1 : close_index]
        arguments = split_top_level(arguments_text) if arguments_text.strip() else []

        if len(arguments) != len(variables):
            raise DefinitionError(
                f"Function '{name}' expects {len(variables)} argument(s), got {len(arguments)}",
                details={"function": name, "variables": variables},
            )

        body = expression
        for variable, argument in zip(variables, arguments):
            body = substitute_parameter(body, variable, argument)

        replacement = r"\left(" + body + r"\right)"
        replacement = expand_function_calls(
            replacement, functions, max_depth=max_depth, _depth=_depth + 1
        )

        output.append(text[position : match.start()])
        output.append(replacement)
        position = close_index + 1

    return "".join(output)


def normalize_identifier(name: str) -> str:
    value = name.strip().replace(r"\left", "").replace(r"\right", "")
    value = value.strip()
    if not IDENTIFIER_PATTERN.match(value):
        raise DefinitionError(f"Invalid definition name: {name}")
    return value.lstrip("\\")


def parse_definition(text: str):
    value = strip_math_delimiters(text)
    equation = split_equation(value)
    if not equation:
        raise DefinitionError(
            "A definition must be written as 'name = expression' or 'f(x) = expression'"
        )

    lhs, rhs = equation
    lhs = lhs.strip().replace(r"\left", "").replace(r"\right", "")
    rhs = rhs.strip()
    if not lhs or not rhs:
        raise DefinitionError("A definition must have both a left and right side")

    function_match = FUNCTION_HEAD_PATTERN.match(lhs)
    if function_match:
        name = normalize_identifier(function_match.group(1))
        parameters_text = function_match.group(2).strip()
        parameters = split_top_level(parameters_text) if parameters_text else []
        variables = [normalize_identifier(parameter) for parameter in parameters]
        if len(set(variables)) != len(variables):
            raise DefinitionError(
                f"Function '{name}' has duplicate parameters",
                details={"function": name, "variables": variables},
            )
        return {
            "kind": "function",
            "name": name,
            "variables": variables,
            "expression": rhs,
        }

    name = normalize_identifier(lhs)
    return {"kind": "value", "name": name, "expression": rhs}
