from odoo import http
from odoo.http import request
import os
import signal

class TestController(http.Controller):
        @http.route(['/kill'],auth="public")
        def kill(self, **post):
            os.kill(os.getpid(),signal.SIGINT)

        @http.route(['/pid'],auth="public")
        def pid(self, **post):
            return os.getpid()

