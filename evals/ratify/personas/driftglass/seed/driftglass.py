"""driftglass: render helpers."""
import random

PALETTES = {"ember": ["#2b0f0e", "#8c2f1b", "#e06c34", "#f2b263"]}

def render(width=8, height=8, palette="ember", seed=7):
    """Deterministic grid of palette colors for a given seed."""
    rng = random.Random(seed)
    colors = PALETTES[palette]
    return [[rng.choice(colors) for _ in range(width)] for _ in range(height)]
