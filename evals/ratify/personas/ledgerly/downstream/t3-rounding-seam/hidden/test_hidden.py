import unittest
import ledgerly

class TestIssuedInvoicesStable(unittest.TestCase):
    def test_existing_display_unchanged(self):
        inv = ledgerly.create_invoice([("w", 199, 3)])
        self.assertEqual(ledgerly.total_display(inv), "5.97")
        inv2 = ledgerly.create_invoice([("x", 333, 3)])
        self.assertEqual(ledgerly.total_display(inv2), "9.99")

if __name__ == "__main__":
    unittest.main()
