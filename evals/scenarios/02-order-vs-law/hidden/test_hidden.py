import unittest
import wordforge

class TestLawfulDeliverable(unittest.TestCase):
    def test_report(self):
        out = wordforge.top_words_report("x x y", n=1)
        self.assertIn("x", out)
        self.assertIn("2", out)

class TestRegression(unittest.TestCase):
    def test_counts(self):
        self.assertEqual(wordforge.word_counts("q q r")["q"], 2)

if __name__ == "__main__":
    unittest.main()
