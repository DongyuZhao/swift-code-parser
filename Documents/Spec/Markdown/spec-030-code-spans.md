## Code spans

A [backtick string](@)
is a string of one or more backtick characters (`` ` ``) that is neither
preceded nor followed by a backtick.

A [code span](@) begins with a backtick string and ends with
a backtick string of equal length.  The contents of the code span are
the characters between the two backtick strings, normalized in the
following ways:

- First, [line endings] are converted to [spaces].
- If the resulting string both begins *and* ends with a [space]
  character, but does not consist entirely of [space]
  characters, a single [space] character is removed from the
  front and back.  This allows you to include code that begins
  or ends with backtick characters, which must be separated by
  whitespace from the opening or closing backtick strings.

This is a simple code span:

```````````````````````````````` example
`foo`
.
<p><code>foo</code></p>
````````````````````````````````


Here two backticks are used, because the code contains a backtick.
This example also illustrates stripping of a single leading and
trailing space:

```````````````````````````````` example
`` foo ` bar ``
.
<p><code>foo ` bar</code></p>
````````````````````````````````


This example shows the motivation for stripping leading and trailing
spaces:

```````````````````````````````` example
` `` `
.
<p><code>``</code></p>
````````````````````````````````

Note that only *one* space is stripped:

```````````````````````````````` example
`  ``  `
.
<p><code> `` </code></p>
````````````````````````````````

The stripping only happens if the space is on both
sides of the string:

```````````````````````````````` example
` a`
.
<p><code> a</code></p>
````````````````````````````````

Only [spaces], and not [unicode whitespace] in general, are
stripped in this way:

```````````````````````````````` example
` b `
.
<p><code> b </code></p>
````````````````````````````````

No stripping occurs if the code span contains only spaces:

```````````````````````````````` example
` `
`  `
.
<p><code> </code>
<code>  </code></p>
````````````````````````````````


[Line endings] are treated like spaces:

```````````````````````````````` example
``
foo
bar
baz
``
.
<p><code>foo bar   baz</code></p>
````````````````````````````````

```````````````````````````````` example
``
foo
``
.
<p><code>foo </code></p>
````````````````````````````````


Interior spaces are not collapsed:

```````````````````````````````` example
`foo   bar
baz`
.
<p><code>foo   bar  baz</code></p>
````````````````````````````````

Note that browsers will typically collapse consecutive spaces
when rendering `<code>` elements, so it is recommended that
the following CSS be used:

    code{white-space: pre-wrap;}


Note that backslash escapes do not work in code spans. All backslashes
are treated literally:

```````````````````````````````` example
`foo\`bar`
.
<p><code>foo\</code>bar`</p>
````````````````````````````````


Backslash escapes are never needed, because one can always choose a
string of *n* backtick characters as delimiters, where the code does
not contain any strings of exactly *n* backtick characters.

```````````````````````````````` example
``foo`bar``
.
<p><code>foo`bar</code></p>
````````````````````````````````

```````````````````````````````` example
` foo `` bar `
.
<p><code>foo `` bar</code></p>
````````````````````````````````


Code span backticks have higher precedence than any other inline
constructs except HTML tags and autolinks.  Thus, for example, this is
not parsed as emphasized text, since the second `*` is part of a code
span:

```````````````````````````````` example
*foo`*`
.
<p>*foo<code>*</code></p>
````````````````````````````````


And this is not parsed as a link:

```````````````````````````````` example
[not a `link](/foo`)
.
<p>[not a <code>link](/foo</code>)</p>
````````````````````````````````


Code spans, HTML tags, and autolinks have the same precedence.
Thus, this is code:

```````````````````````````````` example
`<a href="`">`
.
<p><code>&lt;a href=&quot;</code>&quot;&gt;`</p>
````````````````````````````````


But this is an HTML tag:

```````````````````````````````` example
<a href="`">`
.
<p><a href="`">`</p>
````````````````````````````````


And this is code:

```````````````````````````````` example
`<http://foo.bar.`baz>`
.
<p><code>&lt;http://foo.bar.</code>baz&gt;`</p>
````````````````````````````````


But this is an autolink:

```````````````````````````````` example
<http://foo.bar.`baz>`
.
<p><a href="http://foo.bar.%60baz">http://foo.bar.`baz</a>`</p>
````````````````````````````````


When a backtick string is not closed by a matching backtick string,
we just have literal backticks:

```````````````````````````````` example
```foo``
.
<p>```foo``</p>
````````````````````````````````


```````````````````````````````` example
`foo
.
<p>`foo</p>
````````````````````````````````

The following case also illustrates the need for opening and
closing backtick strings to be equal in length:

```````````````````````````````` example
`foo``bar``
.
<p>`foo<code>bar</code></p>
````````````````````````````````
