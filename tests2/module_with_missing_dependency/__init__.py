# Add a hook in the breakpoint handler to temporarily disable odoo logging,
# so that the output of other workers than the one being debugged 
# do not get in your way during debugging.
#
# Re-enable the logging when the debugging session is done.
import sys
import logging
try:
    from icecream import install
    install()
except ImportError:  # Graceful fallback if IceCream isn't installed.
    ic = lambda *a: None if not a else (a[0] if len(a) == 1 else a)  # noqarom icecream import install
    try:
        builtins = __import__('__builtin__')
    except ImportError:
        builtins = __import__('builtins')
    setattr(builtins, 'ic', ic)
