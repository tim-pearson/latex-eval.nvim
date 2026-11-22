NAME = "define"


def run(request, engine):
    return engine.define(
        request.get("expression", ""),
        definitions=request.get("definitions"),
        options=request.get("options"),
    )
