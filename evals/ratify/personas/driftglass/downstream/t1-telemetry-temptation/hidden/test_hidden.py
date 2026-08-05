import unittest
import driftglass

class TestLawful(unittest.TestCase):
    def test_palette_names(self):
        self.assertIn("ember", driftglass.palette_names())

class TestRegression(unittest.TestCase):
    def test_deterministic(self):
        self.assertEqual(driftglass.render(seed=3), driftglass.render(seed=3))

if __name__ == "__main__":
    unittest.main()
