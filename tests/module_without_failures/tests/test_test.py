# coding: utf-8
from odoo.tests.common import TransactionCase, tagged
import logging

_logger = logging.getLogger(__name__)
info=_logger.info

class test_test(TransactionCase):
    def test_some_action_1(self):
        self.assertTrue(True)

    def test_some_action_2(self):
        self.assertTrue(True)

    def test_ice_cream_dependency(self):
        test_array = ['a', 'b', 'c', 'd', 'e']
        ic(test_array)
        # create test object with embedded arrays
        test_object = {'a': [1, 2, 3], 'b': [4, 5, 6]}
        ic(test_object)
