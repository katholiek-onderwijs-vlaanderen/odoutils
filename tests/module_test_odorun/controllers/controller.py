from odoo import http
from odoo.http import request
import os
import signal
from icecream import ic

class TestController(http.Controller):
        @http.route(['/kill'],auth="public")
        def kill(self, **post):
            os.kill(os.getpid(),signal.SIGINT)

        @http.route(['/pid'],auth="public")
        def pid(self, **post):
            # test array
            test_array = ['a', 'b', 'c', 'd', 'e']
            ic(test_array)
            return f"{os.getpid()}"

