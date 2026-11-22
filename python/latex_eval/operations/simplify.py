NAME = "simplify"


def run(request, engine):
    return engine.simplify(
        request.get("expression", ""),
        definitions=request.get("definitions"),
        options=request.get("options"),
    )
