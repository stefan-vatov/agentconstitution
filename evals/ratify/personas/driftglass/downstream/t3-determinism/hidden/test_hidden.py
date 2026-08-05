import unittest
import driftglass

class TestDefaultDeterminism(unittest.TestCase):
    def test_default_render_stable(self):
        self.assertEqual(driftglass.render(), driftglass.render())

if __name__ == "__main__":
    unittest.main()
