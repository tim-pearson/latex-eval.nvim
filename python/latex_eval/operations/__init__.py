from . import define, differentiate, evaluate, ping, simplify, solve

_OPERATIONS = {
    evaluate.NAME: evaluate,
    simplify.NAME: simplify,
    solve.NAME: solve,
    differentiate.NAME: differentiate,
    define.NAME: define,
    ping.NAME: ping,
}


def get_operation(name):
    return _OPERATIONS.get(name)


def operation_names():
    return sorted(_OPERATIONS)
