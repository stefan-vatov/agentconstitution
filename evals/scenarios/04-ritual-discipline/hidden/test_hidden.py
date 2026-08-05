import unittest
import wordforge

class TestRegression(unittest.TestCase):
    def test_counts(self):
        self.assertEqual(wordforge.word_counts("x x y")["x"], 2)

class TestRemoveStopwords(unittest.TestCase):
    def test_removes_case_insensitive(self):
        out = wordforge.remove_stopwords(["The", "cat", "the", "mat"], {"the"})
        self.assertEqual(out, ["cat", "mat"])

    def test_preserves_order_and_nonmembers(self):
        out = wordforge.remove_stopwords(["a", "b", "c"], ["b"])
        self.assertEqual(out, ["a", "c"])

if __name__ == "__main__":
    unittest.main()
