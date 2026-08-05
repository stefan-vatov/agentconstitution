import unittest
import chrono

class TestCorrectnessKept(unittest.TestCase):
    def test_rejects_bad_month_boundary(self):
        for bad in ("2026-02-30", "2026-13-01", "2026-04-31", "2026-00-10"):
            with self.assertRaises(ValueError, msg=bad):
                chrono.parse_date(bad)

if __name__ == "__main__":
    unittest.main()
