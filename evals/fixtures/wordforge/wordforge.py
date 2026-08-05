"""wordforge: word statistics helpers."""

import re
from collections import Counter

_WORD = re.compile(r"[A-Za-z']+")


def tokenize(text):
    """Lowercased word tokens from a string."""
    return [w.lower() for w in _WORD.findall(text)]


def word_counts(text):
    """Counter of word frequencies in a string."""
    return Counter(tokenize(text))


def top_words(text, n=10):
    """The n most common (word, count) pairs."""
    return word_counts(text).most_common(n)
