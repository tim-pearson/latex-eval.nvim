import sympy

CONSTANTS_MAP = {
    "e": sympy.E,
    "pi": sympy.pi,
    "π": sympy.pi,
    "i": sympy.I,
    "j": sympy.I,
    "oo": sympy.oo,
    "∞": sympy.oo,
    "gamma": sympy.EulerGamma,
    "φ": sympy.GoldenRatio,
    "phi": sympy.GoldenRatio,
}

DEFAULT_CONSTANTS = {
    "c": sympy.Integer(3) * 10**8,
}

KNOWN_CONSTANT_NAMES = tuple(CONSTANTS_MAP) + tuple(DEFAULT_CONSTANTS)
