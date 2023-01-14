# coding: utf-8
from odoo.tests.common import TransactionCase, tagged
import logging
#from icecream import ic

_logger = logging.getLogger(__name__)
info=_logger.info

class test_test(TransactionCase):
    def test_some_action_1(self):
        self.assertTrue(True)

    def test_some_action_2(self):
        self.assertTrue(True)

 #    def test_ice_cream_dependency(self):
 #        #create array with 5 strings
 #        test_array = ['a', 'b', 'c', 'd', 'e']
 #        ic(test_array)
 #        # log type of ic
 #        info(type(ic))
 #        breakpoint()
 # #self.assertTrue(typeof(ic) == Function)
