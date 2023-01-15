import logging
from odoo import fields, models
_logger = logging.getLogger(__name__)

info = _logger.info
dbg = _logger.debug
err = _logger.error

class Test(models.Model):
    _name = 'test.test'

    def test_odorun(self):
        info("test_odorun")
        breakpoint()
