NAME = "ping"


def run(request, engine):
    return {
        "result": "pong",
        "display": "pong",
        "kind": "ping",
        "meta": {},
    }
