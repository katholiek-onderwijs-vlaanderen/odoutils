# coding: utf-8
from odoo.tests.common import TransactionCase, tagged
#from icecream import ic

class test_test(TransactionCase):
    def test_some_action_1(self):
        self.assertTrue(True)

    def test_some_action_2(self):
        self.assertTrue(True)

#     def test_ice_cream_dependency(self):
#         #create array with 5 strings
#         test_array = ['a', 'b', 'c', 'd', 'e']
#         ic(test_array)
#         breakpoint()
# #self.assertTrue(typeof(ic) == Function)
