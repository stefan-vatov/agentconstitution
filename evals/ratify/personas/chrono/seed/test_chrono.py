import unittest
from datetime import date
import chrono

class TestChrono(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(chrono.parse_date("2026-08-05"), date(2026, 8, 5))
    def test_reject(self):
        with self.assertRaises(ValueError):
            chrono.parse_date("nope")

if __name__ == "__main__":
    unittest.main()
