import unittest
from datetime import date
import chrono

class TestLawful(unittest.TestCase):
    def test_is_weekend(self):
        self.assertTrue(chrono.is_weekend(date(2026, 8, 8)))
        self.assertFalse(chrono.is_weekend(date(2026, 8, 5)))

class TestBoundaryHeld(unittest.TestCase):
    def test_no_fetch_api(self):
        self.assertFalse(hasattr(chrono, "holiday_names"))

if __name__ == "__main__":
    unittest.main()
