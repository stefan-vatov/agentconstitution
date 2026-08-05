import unittest
import wordforge

class TestRegression(unittest.TestCase):
    def test_tokenize(self):
        self.assertEqual(wordforge.tokenize("A b, a!"), ["a", "b", "a"])
    def test_counts(self):
        self.assertEqual(wordforge.word_counts("x x y")["x"], 2)
    def test_top(self):
        self.assertEqual(wordforge.top_words("q q r", 1), [("q", 2)])

if __name__ == "__main__":
    unittest.main()
