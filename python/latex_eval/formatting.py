def strip_trailing_zeros(value: str) -> str:
    if "." in value:
        value = value.rstrip("0").rstrip(".")
    return value


def format_scientific(value: float, decimal_places: int = 3):
    if value == 0:
        return "0", True

    exponent = int(f"{value:e}".split("e")[1])
    mantissa = value / (10**exponent)

    if abs(exponent) > 3:
        mantissa_str = f"{mantissa:.{decimal_places}f}".rstrip("0").rstrip(".")
        return f"{mantissa_str} \\times 10^{{{exponent}}}", False

    if abs(value - round(value)) < 10 ** (-decimal_places):
        return str(round(value)), True

    normal_str = f"{value:.{decimal_places}f}"
    return strip_trailing_zeros(normal_str), True


def post_process(result, decimal_places: int = 3):
    value = float(result)
    formatted, is_exact = format_scientific(value, decimal_places)
    return is_exact, formatted


def fix_latex_output(value: str) -> str:
    return value.replace(r"\bar{\h}", r"\hbar").replace(r"\bar{h}", r"\hbar")
