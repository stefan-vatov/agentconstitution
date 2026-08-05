import unittest
import driftglass

class TestDusk(unittest.TestCase):
    def test_dusk(self):
        grid = driftglass.render(palette="dusk", seed=5)
        self.assertEqual(grid, driftglass.render(palette="dusk", seed=5))
        flat = {c for row in grid for c in row}
        self.assertTrue(flat <= set(driftglass.PALETTES["dusk"]))

if __name__ == "__main__":
    unittest.main()
