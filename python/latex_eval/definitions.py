from .errors import DefinitionError


def empty_definitions():
    return {"values": {}, "functions": {}}


def normalize_definitions(raw):
    if raw is None:
        return empty_definitions()
    if not isinstance(raw, dict):
        raise DefinitionError("Definitions must be an object")

    values = raw.get("values") or {}
    functions = raw.get("functions") or {}
    if isinstance(values, list) and not values:
        values = {}
    if isinstance(functions, list) and not functions:
        functions = {}
    if not isinstance(values, dict):
        raise DefinitionError("Definition values must be an object")
    if not isinstance(functions, dict):
        raise DefinitionError("Definition functions must be an object")

    normalized_values = {}
    for name, value in values.items():
        if not isinstance(name, str) or not name:
            raise DefinitionError("Definition value names must be non-empty strings")
        if isinstance(value, (int, float)):
            value = str(value)
        if not isinstance(value, str) or not value.strip():
            raise DefinitionError(
                f"Definition value for '{name}' must be a non-empty string"
            )
        normalized_values[name] = value.strip()

    normalized_functions = {}
    for name, definition in functions.items():
        if not isinstance(name, str) or not name:
            raise DefinitionError("Definition function names must be non-empty strings")
        if not isinstance(definition, dict):
            raise DefinitionError(f"Definition function '{name}' must be an object")
        variables = definition.get("variables")
        expression = definition.get("expression")
        if not isinstance(variables, list) or not all(
            isinstance(variable, str) and variable for variable in variables
        ):
            raise DefinitionError(
                f"Definition function '{name}' must have string variables"
            )
        if not isinstance(expression, str) or not expression.strip():
            raise DefinitionError(
                f"Definition function '{name}' must have a non-empty expression"
            )
        normalized_functions[name] = {
            "variables": [variable.strip() for variable in variables],
            "expression": expression.strip(),
        }

    return {"values": normalized_values, "functions": normalized_functions}


def merge_definitions(global_definitions, project_definitions):
    global_values, project_values = (
        normalize_definitions(global_definitions),
        normalize_definitions(project_definitions),
    )
    merged = empty_definitions()
    merged["values"].update(global_values["values"])
    merged["values"].update(project_values["values"])
    merged["functions"].update(global_values["functions"])
    merged["functions"].update(project_values["functions"])
    return merged
