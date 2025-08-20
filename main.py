import sys
from latex2sympy2 import latex2sympy
from sympy import latex, symbols, simplify, Eq, solve, diff
import math
import sympy


def strip_trailing_zeros(s: str) -> str:
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    return s


class LatexEvaluator:
    def __init__(self):
        self.constants = {}
        self.set_default_constants()

    def set_default_constants(self):
        self.constants["c"] = 3 * 10**8  # Speed of light constant

    def evaluate(self, latex_str):
        expr = latex2sympy(latex_str)
        for const, value in self.constants.items():
            expr = expr.subs(symbols(const), value)
        return expr.evalf()

    def symbolic_simplify(self, latex_str):
        expr = latex2sympy(latex_str)
        simplified = simplify(expr)
        return latex(simplified)

    def solve_for_variable(self, latex_lhs_str, latex_rhs_str, variable_str):
        try:
            lhs_expr = latex2sympy(latex_lhs_str)
            rhs_expr = latex2sympy(latex_rhs_str)
            equation_expr = Eq(lhs_expr, rhs_expr)
        except Exception as e:
            print(f"Error parsing LaTeX: {e}")
            return None

        target_var = symbols(variable_str)
        solutions = solve(equation_expr, target_var)
        if solutions:
            return latex(solutions[0])
        return None

    def differentiate(self, latex_str, symbols_list, variable_str):
        # Define symbols dynamically
        syms = sympy.symbols(" ".join(symbols_list))
        
        # Parse the LaTeX string into a sympy expression
        expr = latex2sympy(latex_str)

        # Replace 'e' with Euler's number
        expr = expr.subs(sympy.Symbol("e"), sympy.E)

        # Pick the variable to differentiate with respect to
        var = sympy.Symbol(variable_str)

        # Differentiate
        derivative = sympy.diff(expr, var)

        # Return the raw sympy string (same style as manual code)
        return str(derivative)


    def format_scientific(self, value: float, dp=3):
        if value == 0:
            return "0", True
        exponent = int(f"{value:e}".split("e")[1])
        mantissa = value / (10**exponent)

        if abs(exponent) > 3:
            mantissa_str = f"{mantissa:.{dp}f}".rstrip("0").rstrip(".")
            return f"{mantissa_str} \\times 10^{{{exponent}}}", False
        else:
            if abs(value - round(value)) < 10 ** (-dp):
                return str(int(round(value))), True
            else:
                normal_str = f"{value:.{dp}f}"
                normal_str = strip_trailing_zeros(normal_str)
                return normal_str, True

    def post_process(self, result, dp=3):
        value = float(result)
        formatted, is_exact = self.format_scientific(value, dp)
        return is_exact, formatted


if __name__ == "__main__":
    evaluator = LatexEvaluator()

    if len(sys.argv) < 2:
        print("Usage:")
        print(
            "  python main.py '<latex_expression>'                              # Evaluate numerically"
        )
        print(
            "  python main.py symbolic '<latex_expression>'                     # Simplify symbolically"
        )
        print(
            "  python main.py solve '<latex_lhs>' '<latex_rhs>' '<variable>'    # Solve for variable"
        )
        print(
            "  python main.py diff '<latex_expression>' '<variable>'            # Differentiate expression"
        )
        sys.exit(1)

    command = sys.argv[1]

    if command == "symbolic":
        if len(sys.argv) < 3:
            print("Usage: python main.py symbolic '<latex_expression>'")
            sys.exit(1)
        latex_input = sys.argv[2]
        result = evaluator.symbolic_simplify(latex_input)
        print(" = " + result)

    elif command == "solve":
        if len(sys.argv) < 5:
            print(
                "Usage: python main.py solve '<latex_lhs>' '<latex_rhs>' '<variable>'"
            )
            sys.exit(1)
        latex_lhs = sys.argv[2]
        latex_rhs = sys.argv[3]
        variable_to_solve = sys.argv[4]
        solution = evaluator.solve_for_variable(
            latex_lhs, latex_rhs, variable_to_solve
        )
        if solution:
            print(f"{variable_to_solve} = {solution}")
        else:
            print(f"Could not solve for {variable_to_solve}.")

    elif command == "diff":
        if len(sys.argv) < 5:
            print(
                "Usage: python main.py diff '<latex_expression>' '<symbols_comma_separated>' '<variable>'"
            )
            sys.exit(1)

        latex_input = sys.argv[2]

        symbols_list = [s.strip() for s in sys.argv[3].split(" ")]

        # Variable to differentiate with respect to
        variable = sys.argv[4]

        # Call the updated differentiate function
        derivative = evaluator.differentiate(
            latex_input, symbols_list, variable
        )

        print(derivative)

    else:
        # Numerical evaluation
        latex_input = sys.argv[1]
        result = evaluator.evaluate(latex_input)
        is_exact, formatted_result = evaluator.post_process(result, dp=3)
        prefix = " =" if is_exact else " \\approx"
        print(f"{prefix} {formatted_result}", end="")
