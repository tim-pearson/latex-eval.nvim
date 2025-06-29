import sys
from latex2sympy2 import latex2sympy
from sympy import symbols

class LatexEvaluator:
    def __init__(self):
        # Initialize with constants dictionary
        self.constants = {}
        self.set_default_constants()

    def set_default_constants(self):
        """
        Sets default constants such as c = 3 x 10^8 m/s.
        Extend this for other constants as needed.
        """
        self.constants['c'] = 3 * 10**8

    def evaluate(self, latex_str):
        """
        Parses a LaTeX math expression string, substitutes constants, and evaluates numerically.

        Args:
            latex_str (str): LaTeX math expression

        Returns:
            evaluated (float): numerical result
        """
        # Parse LaTeX to SymPy expression
        expr = latex2sympy(latex_str)

        # Substitute constants
        for const, value in self.constants.items():
            expr = expr.subs(symbols(const), value)

        # Evaluate numerically
        evaluated = expr.evalf()

        return evaluated

    def format_scientific(self, value, dp=3):
        """
        Formats value in scientific notation with ×10^{n} format and specified decimal places.

        Args:
            value (float): numerical value
            dp (int): decimal places

        Returns:
            str: formatted string
        """
        if value == 0:
            return f"0.{'0'*dp}"

        exponent = int('{:e}'.format(value).split('e')[1])
        mantissa = value / (10 ** exponent)
        formatted = f"{mantissa:.{dp}f} \\times 10^{{{exponent}}}"
        return formatted

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python evaluator.py '<latex_expression>'")
        sys.exit(1)

    latex_input = sys.argv[1]

    evaluator = LatexEvaluator()
    result = evaluator.evaluate(latex_input)
    formatted_result = evaluator.format_scientific(result, dp=3)

    print("Input LaTeX:", latex_input)
    print("Evaluated result (rounded to 3 dp, scientific):", formatted_result)

