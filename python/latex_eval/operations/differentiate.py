NAME = "differentiate"


def run(request, engine):
    options = request.get("options") or {}
    variable = request.get("variable") or options.get("variable")
    return engine.differentiate(
        request.get("expression", ""),
        variable=variable,
        definitions=request.get("definitions"),
        options=options,
    )
