## Insecure characters

For security reasons, the Unicode character `U+0000` must be replaced
with the REPLACEMENT CHARACTER (`U+FFFD`).

# Blocks and inlines

We can think of a document as a sequence of
[blocks](@)---structural elements like paragraphs, block
quotations, lists, headings, rules, and code blocks.  Some blocks (like
block quotes and list items) contain other blocks; others (like
headings and paragraphs) contain [inline](@) content---text,
links, emphasized text, images, code spans, and so on.
