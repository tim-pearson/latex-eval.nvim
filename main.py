import sys
from latex2sympy2 import latex2sympy
from sympy import latex
from sympy import symbols
from sympy import simplify, Eq, solve

class LatexEvaluator:
    def __init__(self):
        self.constants = {}
        self.set_default_constants()

    def set_default_constants(self):
        self.constants['c'] = 3 * 10**8

    def evaluate(self, latex_str):
        expr = latex2sympy(latex_str)
        for const, value in self.constants.items():
            expr = expr.subs(symbols(const), value)
        evaluated = expr.evalf()
        return evaluated

    def symbolic_simplify(self, latex_str):
        expr = latex2sympy(latex_str)
        simplified = simplify(expr)
        return latex(simplified)

    # *** MODIFIED METHOD ***
    def solve_for_variable(self, latex_lhs_str, latex_rhs_str, variable_str):
        """
        Solves an equation for a specified variable given its LHS and RHS as LaTeX strings.

        Args:
            latex_lhs_str (str): LaTeX string for the Left-Hand Side of the equation.
            latex_rhs_str (str): LaTeX string for the Right-Hand Side of the equation.
            variable_str (str): The variable to solve for (e.g., 'x').

        Returns:
            str: LaTeX string of the solution (e.g., 'y - 2')
                  Returns None if no unique solution or parsing issue.
        """
        try:
            lhs_expr = latex2sympy(latex_lhs_str)
            rhs_expr = latex2sympy(latex_rhs_str)
            equation_expr = Eq(lhs_expr, rhs_expr)
        except Exception as e:
            print(f"Error parsing LaTeX components into SymPy expressions: {e}")
            return None

        target_variable = symbols(variable_str)

        solutions = solve(equation_expr, target_variable)

        if solutions:
            return latex(solutions[0])
        else:
            return None

    def format_scientific(self, value, dp=3):
        if value == 0:
            return "0"
        exponent = int('{:e}'.format(value).split('e')[1])
        mantissa = value / (10 ** exponent)
        if exponent == 0:
            if mantissa.is_integer():
                return f"{int(mantissa)}"
            else:
                return f"{mantissa:.{dp}f}"
        else:
            return f"{mantissa:.{dp}f} \\times 10^{{{exponent}}}"

    def post_process(self, result, dp=3):
        value = float(result)
        return self.format_scientific(value, dp)


if __name__ == "__main__":
    evaluator = LatexEvaluator()

    if len(sys.argv) < 2:
        print("Usage:")
        print("  python evaluator.py '<latex_expression>'                           # Evaluate numerically")
        print("  python evaluator.py symbolic '<latex_expression>'                  # Simplify symbolically")
        print("  python evaluator.py solve '<latex_lhs>' '<latex_rhs>' '<variable_to_solve_for>' # Solve for a variable")
        sys.exit(1)

    command = sys.argv[1]

    if command == "symbolic":
        if len(sys.argv) < 3:
            print("Usage: python evaluator.py symbolic '<latex_expression>'")
            sys.exit(1)
        latex_input = sys.argv[2]
        result = evaluator.symbolic_simplify(latex_input)
        print(" = " + result)
    elif command == "solve":
        # *** MODIFIED ARGUMENT PARSING ***
        if len(sys.argv) < 5: # Now expecting 5 arguments: main.py, solve, LHS, RHS, variable
            print("Usage: python evaluator.py solve '<latex_lhs>' '<latex_rhs>' '<variable_to_solve_for>'")
            sys.exit(1)
        latex_lhs = sys.argv[2]
        latex_rhs = sys.argv[3]
        variable_to_solve_for = sys.argv[4]

        solved_latex = evaluator.solve_for_variable(latex_lhs, latex_rhs, variable_to_solve_for)
        if solved_latex:
            print(f"{variable_to_solve_for} = {solved_latex}")
        else:
            print(f"Could not solve for {variable_to_solve_for} in the given equation.")
    else: # Default to numerical evaluation
        latex_input = sys.argv[1]
        result = evaluator.evaluate(latex_input)
        formatted_result = evaluator.post_process(result, dp=3)
        print(" \\approx " + formatted_result, end="")
