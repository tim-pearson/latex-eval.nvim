import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run_cli(*arguments, script="python/main.py"):
    return subprocess.run(
        [sys.executable, str(ROOT / script), *arguments],
        text=True,
        capture_output=True,
        cwd=ROOT,
        env=os.environ.copy(),
        check=False,
    )


def test_legacy_numeric_cli():
    process = run_cli("1+1")
    assert process.returncode == 0
    assert process.stdout == " = 2"


def test_legacy_symbolic_cli():
    process = run_cli("symbolic", r"\frac{x^2}{x}")
    assert process.returncode == 0
    assert process.stdout.strip() == "= x"


def test_legacy_solve_cli():
    process = run_cli("solve", "x+3", "0", "x")
    assert process.returncode == 0
    assert process.stdout.strip() == "x = -3"


def test_legacy_diff_cli():
    process = run_cli("diff", "x^2", "x", "x")
    assert process.returncode == 0
    assert process.stdout.strip() == r"\frac{d}{dx}\left(x^2\right) = 2 x"


def test_root_main_shim_legacy_cli():
    process = run_cli("1+1", script="main.py")
    assert process.returncode == 0
    assert process.stdout == " = 2"


def test_cli_reports_errors_on_stderr():
    process = run_cli(r"\frac{")
    assert process.returncode != 0
    assert process.stdout == ""
    assert "parse" in process.stderr.lower()
