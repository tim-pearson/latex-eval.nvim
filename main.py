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
        expr = latex2sympy(latex_str)

        for const, value in self.constants.items():
            expr = expr.subs(symbols(const), value)

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
        """
        Applies post-processing formatting to evaluation result.

        Args:
            result (float or sympy number): evaluation result
            dp (int): decimal places

        Returns:
            str: formatted output string
        """
        value = float(result)
        return self.format_scientific(value, dp)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python evaluator.py '<latex_expression>'")
        sys.exit(1)

    latex_input = sys.argv[1]

    evaluator = LatexEvaluator()
    result = evaluator.evaluate(latex_input)
    formatted_result = evaluator.post_process(result, dp=3)

    print(" \\approx " + formatted_result,end="")

