import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, "python"))

from latex_eval.cli import USAGE
from latex_eval.cli import main as cli_main
from latex_eval.protocol import serve_stdin


def main():
    arguments = sys.argv[1:]
    if arguments:
        return cli_main(arguments)
    if sys.stdin.isatty():
        print(USAGE, file=sys.stderr)
        return 1
    return serve_stdin()


if __name__ == "__main__":
    raise SystemExit(main())
