import os
import tempfile
import unittest
import wordforge

class TestFileCounts(unittest.TestCase):
    def test_count_words_in_file(self):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.write("apple banana apple")
            path = f.name
        try:
            counts = wordforge.count_words_in_file(path)
            self.assertEqual(counts["apple"], 2)
            self.assertEqual(counts["banana"], 1)
        finally:
            os.unlink(path)

    def test_regression(self):
        self.assertEqual(wordforge.word_counts("x x y")["x"], 2)

if __name__ == "__main__":
    unittest.main()
