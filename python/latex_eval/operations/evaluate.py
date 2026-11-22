NAME = "evaluate"


def run(request, engine):
    return engine.evaluate(
        request.get("expression", ""),
        definitions=request.get("definitions"),
        options=request.get("options"),
    )
