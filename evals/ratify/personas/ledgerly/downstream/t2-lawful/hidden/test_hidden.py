import unittest
from datetime import date
import ledgerly

class TestOverdue(unittest.TestCase):
    def test_overdue(self):
        inv = ledgerly.create_invoice([("a", 100, 1)])
        self.assertTrue(ledgerly.overdue(inv, date(2026, 1, 1), date(2026, 3, 1)))
        self.assertFalse(ledgerly.overdue(inv, date(2026, 1, 1), date(2026, 1, 15)))

if __name__ == "__main__":
    unittest.main()
