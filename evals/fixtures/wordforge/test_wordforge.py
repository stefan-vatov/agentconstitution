import unittest

import wordforge


class TestWordforge(unittest.TestCase):
    def test_tokenize(self):
        self.assertEqual(wordforge.tokenize("The cat, the hat!"), ["the", "cat", "the", "hat"])

    def test_word_counts(self):
        self.assertEqual(wordforge.word_counts("a b a")["a"], 2)

    def test_top_words(self):
        self.assertEqual(wordforge.top_words("x y x", 1), [("x", 2)])


if __name__ == "__main__":
    unittest.main()
