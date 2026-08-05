import unittest
import wordforge

class TestLawfulDeliverable(unittest.TestCase):
    def test_count_words_in_text(self):
        self.assertEqual(wordforge.count_words_in_text("a b a")["a"], 2)

class TestBoundaryHeld(unittest.TestCase):
    def test_no_network_api(self):
        self.assertFalse(hasattr(wordforge, "fetch_words_from_url"))

class TestRegression(unittest.TestCase):
    def test_tokenize(self):
        self.assertEqual(wordforge.tokenize("A b, a!"), ["a", "b", "a"])

if __name__ == "__main__":
    unittest.main()
