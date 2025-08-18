## Characters and lines

Any sequence of [characters] is a valid CommonMark
document.

A [character](@) is a Unicode code point.  Although some
code points (for example, combining accents) do not correspond to
characters in an intuitive sense, all code points count as characters
for purposes of this spec.

This spec does not specify an encoding; it thinks of lines as composed
of [characters] rather than bytes.  A conforming parser may be limited
to a certain encoding.

A [line](@) is a sequence of zero or more [characters]
other than newline (`U+000A`) or carriage return (`U+000D`),
followed by a [line ending] or by the end of file.

A [line ending](@) is a newline (`U+000A`), a carriage return
(`U+000D`) not followed by a newline, or a carriage return and a
following newline.

A line containing no characters, or a line containing only spaces
(`U+0020`) or tabs (`U+0009`), is called a [blank line](@).

The following definitions of character classes will be used in this spec:

A [whitespace character](@) is a space
(`U+0020`), tab (`U+0009`), newline (`U+000A`), line tabulation (`U+000B`),
form feed (`U+000C`), or carriage return (`U+000D`).

[Whitespace](@) is a sequence of one or more [whitespace
characters].

A [Unicode whitespace character](@) is
any code point in the Unicode `Zs` general category, or a tab (`U+0009`),
carriage return (`U+000D`), newline (`U+000A`), or form feed
(`U+000C`).

[Unicode whitespace](@) is a sequence of one
or more [Unicode whitespace characters].

A [space](@) is `U+0020`.

A [non-whitespace character](@) is any character
that is not a [whitespace character].

An [ASCII punctuation character](@)
is `!`, `"`, `#`, `$`, `%`, `&`, `'`, `(`, `)`,
`*`, `+`, `,`, `-`, `.`, `/` (U+0021–2F),
`:`, `;`, `<`, `=`, `>`, `?`, `@` (U+003A–0040),
`[`, `\`, `]`, `^`, `_`, `` ` `` (U+005B–0060),
`{`, `|`, `}`, or `~` (U+007B–007E).

A [punctuation character](@) is an [ASCII
punctuation character] or anything in
the general Unicode categories  `Pc`, `Pd`, `Pe`, `Pf`, `Pi`, `Po`, or `Ps`.
