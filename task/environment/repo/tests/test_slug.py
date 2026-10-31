import unittest

from textkit import slugify


class SlugifyTest(unittest.TestCase):
    def test_lowercases_and_joins_words(self):
        self.assertEqual(slugify("Hello World"), "hello-world")

    def test_collapses_punctuation(self):
        self.assertEqual(slugify("  Rock & Roll!! "), "rock-roll")

    def test_strips_accents(self):
        self.assertEqual(slugify("Crème brûlée"), "creme-brulee")

    def test_empty(self):
        self.assertEqual(slugify("!!!"), "")


if __name__ == "__main__":
    unittest.main()
