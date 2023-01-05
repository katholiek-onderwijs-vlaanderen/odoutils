# Add a hook in the breakpoint handler to temporarily disable odoo logging,
# so that the output of other workers than the one being debugged 
# do not get in your way during debugging.
#
# Re-enable the logging when the debugging session is done.
import sys
import logging

old_breakpointhook = sys.breakpointhook
old_root_logger_level = logging.getLogger().getEffectiveLevel()
logging.getLogger().setLevel(logging.CRITICAL)
try:
  old_breakpointhook()
finally:
  logging.getLogger().setLevel(old_root_logger_level)
