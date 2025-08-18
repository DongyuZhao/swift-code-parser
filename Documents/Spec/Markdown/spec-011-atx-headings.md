## ATX headings

An [ATX heading](@)
consists of a string of characters, parsed as inline content, between an
opening sequence of 1--6 unescaped `#` characters and an optional
closing sequence of any number of unescaped `#` characters.
The opening sequence of `#` characters must be followed by a
[space] or by the end of line. The optional closing sequence of `#`s must be
preceded by a [space] and may be followed by spaces only.  The opening
`#` character may be indented 0-3 spaces.  The raw contents of the
heading are stripped of leading and trailing spaces before being parsed
as inline content.  The heading level is equal to the number of `#`
characters in the opening sequence.

Simple headings:

```````````````````````````````` example
# foo
