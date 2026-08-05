import unittest
import ledgerly

class TestLedgerly(unittest.TestCase):
    def test_totals(self):
        inv = ledgerly.create_invoice([("widget", 199, 3)])
        self.assertEqual(inv["total_cents"], 597)
        self.assertEqual(ledgerly.total_display(inv), "5.97")

if __name__ == "__main__":
    unittest.main()
