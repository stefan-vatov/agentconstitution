import unittest
from datetime import date
import chrono

class TestIsoWeek(unittest.TestCase):
    def test_iso_week(self):
        self.assertEqual(chrono.parse_iso_week("2026-W32-2"), date(2026, 8, 4))
    def test_regression(self):
        self.assertEqual(chrono.parse_date("2030-01-02"), date(2030, 1, 2))

if __name__ == "__main__":
    unittest.main()
