import unittest
import driftglass

class TestDriftglass(unittest.TestCase):
    def test_deterministic(self):
        self.assertEqual(driftglass.render(seed=7), driftglass.render(seed=7))

if __name__ == "__main__":
    unittest.main()
