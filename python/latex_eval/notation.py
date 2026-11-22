import re

from .parsing import split_top_level, strip_math_delimiters

IDENTIFIER = re.compile(r"^\\?[A-Za-z][A-Za-z0-9_]*$")
FUNCTION_CALL = re.compile(r"^(\\?[A-Za-z][A-Za-z0-9_]*)\s*\((.*)\)$", re.DOTALL)


def _is_escaped(text, index):
    backslashes = 0
    cursor = index - 1
    while cursor >= 0 and text[cursor] == "\\":
        backslashes += 1
        cursor -= 1
    return backslashes % 2 == 1


def _find_matching_brace(text, open_index):
    if open_index >= len(text) or text[open_index] != "{":
        return None
    depth = 0
    for index in range(open_index, len(text)):
        if _is_escaped(text, index):
            continue
        character = text[index]
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return index
    return None


def _clean(text):
    value = (
        strip_math_delimiters(text or "").replace(r"\left", "").replace(r"\right", "")
    )
    value = value.replace(r"^{\prime}", "'").replace(r"^\prime", "'")
    return re.sub(r"\s+", "", value)


def _normalize_name(value):
    return (value or "").strip().lstrip("\\")


def _parse_fraction_notation(lhs):
    match = re.match(r"^\\(?:d|t)?frac\{", lhs)
    if not match:
        return None

    open_numerator = match.end() - 1
    close_numerator = _find_matching_brace(lhs, open_numerator)
    if close_numerator is None:
        return None
    if close_numerator + 1 >= len(lhs) or lhs[close_numerator + 1] != "{":
        return None

    open_denominator = close_numerator + 1
    close_denominator = _find_matching_brace(lhs, open_denominator)
    if close_denominator is None:
        return None

    numerator = lhs[open_numerator + 1 : close_numerator]
    denominator = lhs[open_denominator + 1 : close_denominator]
    suffix = lhs[close_denominator + 1 :]
    if suffix:
        return None

    numerator_match = re.match(r"^d(?:\^\{?(\d+)\}?)?(.*)$", numerator)
    denominator_match = re.match(r"^d(?:\^\{?(\d+)\}?)?(.*)$", denominator)
    if not numerator_match or not denominator_match:
        return None

    numerator_order = int(numerator_match.group(1) or 0)
    denominator_order = int(denominator_match.group(1) or 0)
    dependent = None
    independent = None
    dependent_order = 0
    independent_order = 0

    numerator_rest = numerator_match.group(2)
    if numerator_rest:
        dependent_match = re.match(
            r"^(\\?[A-Za-z]+)(?:\^\{?(\d+)\}?)?$", numerator_rest
        )
        if not dependent_match:
            return None
        dependent = dependent_match.group(1)
        dependent_order = int(dependent_match.group(2) or 0)

    denominator_rest = denominator_match.group(2)
    if denominator_rest:
        independent_match = re.match(
            r"^(\\?[A-Za-z]+)(?:\^\{?(\d+)\}?)?$", denominator_rest
        )
        if not independent_match:
            return None
        independent = independent_match.group(1)
        independent_order = int(independent_match.group(2) or 0)

    order = max(
        1,
        numerator_order,
        denominator_order,
        dependent_order,
        independent_order,
    )
    return {
        "kind": "leibniz",
        "order": order,
        "dependent": dependent,
        "independent": independent,
    }


def _parse_prime_notation(lhs):
    prime_match = re.match(r"^(\\?[A-Za-z][A-Za-z0-9_]*)((?:'|′)+)(?:\((.*)\))?$", lhs)
    if prime_match:
        primes = prime_match.group(2)
        args = prime_match.group(3)
        argument = _single_argument(args)
        return {
            "kind": "prime",
            "order": len(primes),
            "base": prime_match.group(1),
            "args": args,
            "independent": argument,
        }

    exponent_match = re.match(
        r"^(\\?[A-Za-z][A-Za-z0-9_]*)\^\{?\(?(\d+)\)?\}?(?:\((.*)\))?$",
        lhs,
    )
    if exponent_match and exponent_match.group(3) is not None:
        args = exponent_match.group(3)
        argument = _single_argument(args)
        return {
            "kind": "prime",
            "order": int(exponent_match.group(2)),
            "base": exponent_match.group(1),
            "args": args,
            "independent": argument,
        }

    return None


def parse_derivative_lhs(lhs):
    value = _clean(lhs)
    if not value:
        return None
    fraction = _parse_fraction_notation(value)
    if fraction:
        return fraction
    return _parse_prime_notation(value)


def _leibniz(dependent, independent, order):
    independent = independent or "x"
    if order == 1:
        denominator = "d" + independent
        numerator = "d" + dependent if dependent else "d"
    else:
        denominator = f"d{independent}^{{{order}}}"
        numerator = f"d^{{{order}}}{dependent or ''}"
    return f"\\frac{{{numerator}}}{{{denominator}}}"


def _prime(base, args, order):
    if order <= 3:
        marker = "'" * order
    else:
        marker = f"^{{({order})}}"
    if args is not None:
        return f"{base}{marker}({args})"
    return f"{base}{marker}"


def _generic(source, variable, order):
    variable = variable or "x"
    if order == 1:
        operator = f"\\frac{{d}}{{d{variable}}}"
    else:
        operator = f"\\frac{{d^{{{order}}}}}{{d{variable}^{{{order}}}}}"
    return f"{operator}\\left({source}\\right)"


def _single_argument(args):
    if args is None:
        return None
    variables = split_top_level(args)
    if len(variables) != 1:
        return None
    return variables[0].strip()


def build_lhs_notation(lhs_source, variable, add_order):
    parsed = parse_derivative_lhs(lhs_source)
    if parsed:
        new_order = parsed["order"] + add_order
        if parsed["kind"] == "leibniz":
            independent = variable or parsed.get("independent") or "x"
            return {
                "display": _leibniz(parsed.get("dependent"), independent, new_order),
                "kind": "leibniz",
                "order": new_order,
                "replaces_lhs": True,
            }
        if parsed["kind"] == "prime":
            args = parsed.get("args")
            argument = _single_argument(args)
            if (
                variable
                and argument
                and _normalize_name(argument) != _normalize_name(variable)
            ):
                return {
                    "display": _generic(_clean(lhs_source), variable, new_order),
                    "kind": "generic",
                    "order": new_order,
                    "replaces_lhs": True,
                }
            return {
                "display": _prime(parsed["base"], args, new_order),
                "kind": "prime",
                "order": new_order,
                "replaces_lhs": True,
            }

    clean_lhs = _clean(lhs_source)
    function_match = FUNCTION_CALL.match(clean_lhs)
    if function_match:
        base = function_match.group(1)
        args = function_match.group(2)
        argument = _single_argument(args)
        if not variable or (
            argument and _normalize_name(argument) == _normalize_name(variable)
        ):
            return {
                "display": _prime(base, args, add_order),
                "kind": "prime",
                "order": add_order,
                "replaces_lhs": False,
            }
        return {
            "display": _generic(clean_lhs, variable, add_order),
            "kind": "generic",
            "order": add_order,
            "replaces_lhs": False,
        }

    if IDENTIFIER.match(clean_lhs):
        return {
            "display": _leibniz(clean_lhs, variable, add_order),
            "kind": "leibniz",
            "order": add_order,
            "replaces_lhs": False,
        }

    return {
        "display": _generic(clean_lhs, variable, add_order),
        "kind": "generic",
        "order": add_order,
        "replaces_lhs": False,
    }


def build_expression_notation(expression, variable, order):
    return build_lhs_notation(expression, variable, order)
