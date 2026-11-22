from sympy import Eq, Symbol, diff, latex, simplify, solve

from .constants import CONSTANTS_MAP, DEFAULT_CONSTANTS
from .definitions import normalize_definitions
from .errors import (
    AmbiguousVariableError,
    DefinitionError,
    MissingVariableError,
    OperationError,
    ParseError,
)
from .formatting import fix_latex_output, post_process
from .notation import (
    build_expression_notation,
    build_lhs_notation,
    parse_derivative_lhs,
)
from .parsing import (
    expand_function_calls,
    parse_definition,
    parse_latex,
    split_equation,
    strip_math_delimiters,
)


class Engine:
    def __init__(self, constants=None):
        self.constants = dict(CONSTANTS_MAP)
        self.evaluation_defaults = dict(DEFAULT_CONSTANTS)
        if constants:
            self.constants.update(constants)

    def _apply_values(self, expression, values, functions):
        if not values:
            return expression

        parsed_values = {}
        for name, value in values.items():
            expanded = expand_function_calls(value, functions)
            try:
                parsed_values[Symbol(name)] = parse_latex(expanded)
            except ParseError as exc:
                raise DefinitionError(
                    f"Could not parse stored value '{name}': {exc.message}",
                    details={"name": name, "value": value},
                ) from exc

        mapping = parsed_values
        for _ in range(12):
            resolved = {}
            changed = False
            for symbol, value_expression in mapping.items():
                substitutions = {
                    candidate: mapping[candidate]
                    for candidate in value_expression.free_symbols
                    if candidate in mapping and candidate != symbol
                }
                new_expression = value_expression.subs(substitutions)
                if new_expression != value_expression:
                    changed = True
                resolved[symbol] = new_expression
            mapping = resolved
            if not changed:
                break

        return expression.subs(mapping)

    def _apply_constants(self, expression):
        for name, value in self.constants.items():
            expression = expression.subs(Symbol(name), value)
        return expression

    def parse_expression(self, text, definitions=None, apply_evaluation_defaults=False):
        normalized = normalize_definitions(definitions)
        expanded = expand_function_calls(
            strip_math_delimiters(text), normalized["functions"]
        )
        expression = parse_latex(expanded)
        expression = self._apply_values(
            expression, normalized["values"], normalized["functions"]
        )
        expression = self._apply_constants(expression)
        if apply_evaluation_defaults:
            expression = self._apply_evaluation_defaults(expression)
        return expression

    def _apply_evaluation_defaults(self, expression):
        for name, value in self.evaluation_defaults.items():
            expression = expression.subs(Symbol(name), value)
        return expression

    def _parse_equation(self, text, definitions=None):
        equation = split_equation(text)
        if not equation:
            raise ParseError(
                "Expected an equation containing '='",
                details={"expression": strip_math_delimiters(text)},
            )
        lhs_text, rhs_text = equation
        if not lhs_text or not rhs_text:
            raise ParseError("Equation must have both a left and right side")
        lhs = self.parse_expression(lhs_text, definitions)
        rhs = self.parse_expression(rhs_text, definitions)
        return lhs, rhs

    def _symbol_from_name(self, name):
        value = (name or "").strip()
        if not value:
            raise MissingVariableError("No variable was provided")
        if value.startswith("\\"):
            try:
                parsed = parse_latex(value)
                if isinstance(parsed, Symbol):
                    return parsed
            except ParseError:
                pass
        return Symbol(value)

    def _infer_differentiation_variable(self, lhs, rhs, variable=None):
        if variable:
            return self._symbol_from_name(variable)
        rhs_symbols = rhs.free_symbols
        if len(rhs_symbols) == 1:
            return next(iter(rhs_symbols))
        return self._infer_variable([lhs, rhs])

    def _infer_variable(self, expressions, variable=None):
        if variable:
            return self._symbol_from_name(variable)

        free_symbols = set()
        for expression in expressions:
            free_symbols.update(expression.free_symbols)

        if len(free_symbols) == 1:
            return next(iter(free_symbols))
        if not free_symbols:
            raise MissingVariableError(
                "Could not infer a variable because the expression has no symbols"
            )
        raise AmbiguousVariableError(sorted(str(symbol) for symbol in free_symbols))

    def evaluate(self, text, definitions=None, options=None):
        options = options or {}
        decimal_places = int(options.get("decimal_places", 3))
        expression = self.parse_expression(
            text, definitions, apply_evaluation_defaults=True
        )
        value = expression.evalf()

        if getattr(value, "is_infinite", False) or getattr(value, "is_nan", False):
            formatted = fix_latex_output(latex(expression))
            return {
                "result": formatted,
                "display": " = " + formatted,
                "kind": "symbolic",
                "meta": {"latex": formatted},
            }

        try:
            is_exact, formatted = post_process(value, decimal_places=decimal_places)
            prefix = " = " if is_exact else " \\approx "
            return {
                "result": formatted,
                "display": prefix + formatted,
                "kind": "exact" if is_exact else "approx",
                "meta": {"latex": fix_latex_output(latex(expression))},
            }
        except (TypeError, ValueError, OverflowError):
            formatted = fix_latex_output(latex(expression))
            return {
                "result": formatted,
                "display": " = " + formatted,
                "kind": "symbolic",
                "meta": {"latex": fix_latex_output(latex(expression))},
            }

    def simplify(self, text, definitions=None, options=None):
        expression = self.parse_expression(text, definitions)
        simplified = simplify(expression)
        result = fix_latex_output(latex(simplified))
        return {
            "result": result,
            "display": " = " + result,
            "kind": "symbolic",
            "meta": {},
        }

    def solve(self, text, variable=None, definitions=None, options=None):
        lhs, rhs = self._parse_equation(text, definitions)
        equation = Eq(lhs, rhs)
        target = self._infer_variable([lhs, rhs], variable)
        solutions = solve(equation, target)
        if not solutions:
            raise OperationError(
                f"No solutions found for {target}",
                code="NO_SOLUTION",
                details={"variable": str(target)},
            )
        solution = solutions[0]
        result = (
            f"{fix_latex_output(latex(target))} = {fix_latex_output(latex(solution))}"
        )
        return {
            "result": result,
            "display": result,
            "kind": "solution",
            "meta": {
                "variable": str(target),
                "rhs": fix_latex_output(latex(solution)),
                "replace": result,
                "solutions": [
                    fix_latex_output(latex(candidate)) for candidate in solutions
                ],
            },
        }

    def differentiate(
        self, text, variable=None, order=1, definitions=None, options=None
    ):
        options = options or {}
        try:
            order = int(order)
        except (TypeError, ValueError):
            raise OperationError("Derivative order must be an integer") from None
        if order < 1:
            raise OperationError("Derivative order must be at least 1")

        equation = split_equation(text)
        if equation:
            lhs_text, rhs_text = equation
            parsed_notation = parse_derivative_lhs(lhs_text)
            rhs = self.parse_expression(rhs_text, definitions)

            if parsed_notation:
                target = None
                if variable:
                    target = self._symbol_from_name(variable)
                elif parsed_notation.get("independent"):
                    target = self._symbol_from_name(parsed_notation["independent"])
                if target is None:
                    target = self._infer_variable([rhs])
            else:
                lhs = self.parse_expression(lhs_text, definitions)
                target = self._infer_differentiation_variable(lhs, rhs, variable)

            target_latex = fix_latex_output(latex(target))
            derivative = diff(rhs, target, order)
            rhs_latex = fix_latex_output(latex(derivative))
            notation = build_lhs_notation(lhs_text, target_latex, order)
            display = f"{notation['display']} = {rhs_latex}"
            if notation["replaces_lhs"]:
                replacement = display
            else:
                lhs_source = strip_math_delimiters(lhs_text).strip()
                replacement = f"{lhs_source} = {rhs_latex}"

            return {
                "result": display,
                "display": display,
                "kind": "derivative",
                "meta": {
                    "variable": str(target),
                    "order": notation["order"],
                    "notation": notation["kind"],
                    "lhs": notation["display"],
                    "rhs": rhs_latex,
                    "replace": replacement,
                    "replace_full": display,
                    "replace_rhs": replacement,
                },
            }

        expression = self.parse_expression(text, definitions)
        target = self._infer_variable([expression], variable)
        target_latex = fix_latex_output(latex(target))
        derivative = diff(expression, target, order)
        rhs_latex = fix_latex_output(latex(derivative))
        notation = build_expression_notation(text, target_latex, order)
        display = f"{notation['display']} = {rhs_latex}"
        return {
            "result": display,
            "display": display,
            "kind": "derivative",
            "meta": {
                "variable": str(target),
                "order": notation["order"],
                "notation": notation["kind"],
                "lhs": notation["display"],
                "rhs": rhs_latex,
                "replace": rhs_latex,
                "replace_full": display,
                "replace_rhs": rhs_latex,
            },
        }

    def define(self, text, definitions=None, options=None):
        definition = parse_definition(text)
        self.parse_expression(definition["expression"], definitions)

        if definition["kind"] == "function":
            signature = ",".join(definition["variables"])
            result = f"{definition['name']}({signature}) = {definition['expression']}"
        else:
            result = f"{definition['name']} = {definition['expression']}"

        return {
            "result": result,
            "display": result,
            "kind": "definition",
            "meta": {"definition": definition},
        }
