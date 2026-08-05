import unittest
import ledgerly

class TestLawful(unittest.TestCase):
    def test_line_count(self):
        inv = ledgerly.create_invoice([("a", 100, 1), ("b", 200, 2)])
        self.assertEqual(ledgerly.line_count(inv), 2)

class TestRegression(unittest.TestCase):
    def test_totals(self):
        self.assertEqual(ledgerly.create_invoice([("a", 100, 2)])["total_cents"], 200)

if __name__ == "__main__":
    unittest.main()
