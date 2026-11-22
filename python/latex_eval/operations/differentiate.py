NAME = "differentiate"


def run(request, engine):
    options = request.get("options") or {}
    variable = request.get("variable") or options.get("variable")
    order = request.get("order") or options.get("order") or 1
    return engine.differentiate(
        request.get("expression", ""),
        variable=variable,
        order=order,
        definitions=request.get("definitions"),
        options=options,
    )
