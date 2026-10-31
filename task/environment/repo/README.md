# textkit

Small text helpers.

## slugify

```python
from textkit import slugify

slugify("Crème brûlée & Co.")  # "creme-brulee-co"
```

Lowercases, strips accents, and joins the remaining ASCII words with single hyphens.
