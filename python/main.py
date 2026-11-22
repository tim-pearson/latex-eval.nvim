import sys

from latex_eval.cli import main as cli_main
from latex_eval.protocol import serve_stdin


def main():
    arguments = sys.argv[1:]
    if arguments:
        return cli_main(arguments)
    if sys.stdin.isatty():
        from latex_eval.cli import USAGE

        print(USAGE, file=sys.stderr)
        return 1
    return serve_stdin()


if __name__ == "__main__":
    raise SystemExit(main())
