import sys

from .engine import Engine
from .errors import LatexEvalError

USAGE = """Usage:
  latex-eval '<latex_expression>'
  latex-eval symbolic '<latex_expression>'
  latex-eval solve '<latex_lhs>' '<latex_rhs>' '<variable>'
  latex-eval diff '<latex_expression>' '<symbols>' '<variable>'
"""


def _require(arguments, count, message):
    if len(arguments) < count:
        print(message, file=sys.stderr)
        return False
    return True


def main(argv=None):
    arguments = list(sys.argv[1:] if argv is None else argv)
    if not arguments:
        print(USAGE, file=sys.stderr)
        return 1

    engine = Engine()
    command = arguments[0]

    try:
        if command == "symbolic":
            if not _require(arguments, 2, USAGE):
                return 1
            result = engine.simplify(arguments[1])
            print(result["display"])
            return 0

        if command == "solve":
            if not _require(arguments, 4, USAGE):
                return 1
            result = engine.solve(
                f"{arguments[1]}={arguments[2]}", variable=arguments[3]
            )
            print(result["display"])
            return 0

        if command == "diff":
            if not _require(arguments, 4, USAGE):
                return 1
            result = engine.differentiate(arguments[1], variable=arguments[3])
            print(result["display"])
            return 0

        result = engine.evaluate(command)
        sys.stdout.write(result["display"])
        return 0
    except LatexEvalError as exc:
        print(exc.message, file=sys.stderr)
        return 1
