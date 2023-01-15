# Add a hook in the breakpoint handler to temporarily disable odoo logging,
# so that the output of other workers than the one being debugged 
# do not get in your way during debugging.
#
# Re-enable the logging when the debugging session is done.
import sys
import logging

from . import models
from . import controllers
