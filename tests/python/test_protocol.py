import json
import os
import subprocess
import sys
from pathlib import Path

from latex_eval.protocol import handle_request

ROOT = Path(__file__).resolve().parents[2]


def run_backend(payload, script="python/main.py"):
    process = subprocess.run(
        [sys.executable, str(ROOT / script)],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        cwd=ROOT,
        env=os.environ.copy(),
        check=False,
    )
    return process


def test_stdin_protocol_round_trip():
    process = run_backend({"operation": "evaluate", "expression": "1+1"})
    assert process.returncode == 0
    response = json.loads(process.stdout)
    assert response["ok"] is True
    assert response["result"] == "2"
    assert process.stderr == ""


def test_stdin_protocol_keeps_stdout_clean_on_error():
    process = run_backend({"operation": "evaluate", "expression": r"\frac{"})
    assert process.returncode != 0
    response = json.loads(process.stdout)
    assert response["ok"] is False
    assert response["error"]["code"] == "PARSE_ERROR"


def test_protocol_supports_definitions():
    response = handle_request(
        {
            "operation": "evaluate",
            "expression": "f(3)",
            "definitions": {
                "functions": {"f": {"variables": ["x"], "expression": "x^2"}}
            },
        }
    )
    assert response["ok"] is True
    assert response["result"] == "9"


def test_protocol_empty_stdin_returns_error():
    process = subprocess.run(
        [sys.executable, str(ROOT / "python/main.py")],
        input="",
        text=True,
        capture_output=True,
        cwd=ROOT,
        env=os.environ.copy(),
        check=False,
    )
    response = json.loads(process.stdout)
    assert response["ok"] is False
    assert response["error"]["code"] == "EMPTY_REQUEST"
