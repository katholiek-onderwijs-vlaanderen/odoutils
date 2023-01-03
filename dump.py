def dmp(x):
    """Inspect the ocject x.

    Examples:

    # Inspect local variables
    inspect(locals())

    # Inspect self
    inspect(self)

    # Inspect global variables
    inspect(globals())
    """

    for k, v in x.items():
        if k[0] != '_':
            print(f"{k} -> [{v}]")
