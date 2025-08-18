## Entity and numeric character references

Valid HTML entity references and numeric character references
can be used in place of the corresponding Unicode character,
with the following exceptions:

- Entity and character references are not recognized in code
  blocks and code spans.

- Entity and character references cannot stand in place of
  special characters that define structural elements in
  CommonMark.  For example, although `&#42;` can be used
  in place of a literal `*` character, `&#42;` cannot replace
  `*` in emphasis delimiters, bullet list markers, or thematic
  breaks.

Conforming CommonMark parsers need not store information about
whether a particular character was represented in the source
using a Unicode character or an entity reference.

[Entity references](@) consist of `&` + any of the valid
HTML5 entity names + `;`. The
document <https://html.spec.whatwg.org/multipage/entities.json>
is used as an authoritative source for the valid entity
references and their corresponding code points.

```````````````````````````````` example
&nbsp; &amp; &copy; &AElig; &Dcaron;
&frac34; &HilbertSpace; &DifferentialD;
&ClockwiseContourIntegral; &ngE;
.
<p>  &amp; © Æ Ď
¾ ℋ ⅆ
∲ ≧̸</p>
````````````````````````````````


[Decimal numeric character
references](@)
consist of `&#` + a string of 1--7 arabic digits + `;`. A
numeric character reference is parsed as the corresponding
Unicode character. Invalid Unicode code points will be replaced by
the REPLACEMENT CHARACTER (`U+FFFD`).  For security reasons,
the code point `U+0000` will also be replaced by `U+FFFD`.

```````````````````````````````` example
&#35; &#1234; &#992; &#0;
.
<p># Ӓ Ϡ �</p>
````````````````````````````````


[Hexadecimal numeric character
references](@) consist of `&#` +
either `X` or `x` + a string of 1-6 hexadecimal digits + `;`.
They too are parsed as the corresponding Unicode character (this
time specified with a hexadecimal numeral instead of decimal).

```````````````````````````````` example
&#X22; &#XD06; &#xcab;
.
<p>&quot; ആ ಫ</p>
````````````````````````````````


Here are some nonentities:

```````````````````````````````` example
&nbsp &x; &#; &#x;
&#987654321;
&#abcdef0;
&ThisIsNotDefined; &hi?;
.
<p>&amp;nbsp &amp;x; &amp;#; &amp;#x;
&amp;#987654321;
&amp;#abcdef0;
&amp;ThisIsNotDefined; &amp;hi?;</p>
````````````````````````````````


Although HTML5 does accept some entity references
without a trailing semicolon (such as `&copy`), these are not
recognized here, because it makes the grammar too ambiguous:

```````````````````````````````` example
&copy
.
<p>&amp;copy</p>
````````````````````````````````


Strings that are not on the list of HTML5 named entities are not
recognized as entity references either:

```````````````````````````````` example
&MadeUpEntity;
.
<p>&amp;MadeUpEntity;</p>
````````````````````````````````


Entity and numeric character references are recognized in any
context besides code spans or code blocks, including
URLs, [link titles], and [fenced code block][] [info strings]:

```````````````````````````````` example
<a href="&ouml;&ouml;.html">
.
<a href="&ouml;&ouml;.html">
````````````````````````````````


```````````````````````````````` example
[foo](/f&ouml;&ouml; "f&ouml;&ouml;")
.
<p><a href="/f%C3%B6%C3%B6" title="föö">foo</a></p>
````````````````````````````````


```````````````````````````````` example
[foo]

[foo]: /f&ouml;&ouml; "f&ouml;&ouml;"
.
<p><a href="/f%C3%B6%C3%B6" title="föö">foo</a></p>
````````````````````````````````


```````````````````````````````` example
``` f&ouml;&ouml;
foo
```
.
<pre><code class="language-föö">foo
</code></pre>
````````````````````````````````


Entity and numeric character references are treated as literal
text in code spans and code blocks:

```````````````````````````````` example
`f&ouml;&ouml;`
.
<p><code>f&amp;ouml;&amp;ouml;</code></p>
````````````````````````````````


```````````````````````````````` example
    f&ouml;f&ouml;
.
<pre><code>f&amp;ouml;f&amp;ouml;
</code></pre>
````````````````````````````````


Entity and numeric character references cannot be used
in place of symbols indicating structure in CommonMark
documents.

```````````````````````````````` example
&#42;foo&#42;
*foo*
.
<p>*foo*
<em>foo</em></p>
````````````````````````````````

```````````````````````````````` example
&#42; foo

* foo
.
<p>* foo</p>
<ul>
<li>foo</li>
</ul>
````````````````````````````````

```````````````````````````````` example
foo&#10;&#10;bar
.
<p>foo

bar</p>
````````````````````````````````

```````````````````````````````` example
&#9;foo
.
<p>→foo</p>
````````````````````````````````


```````````````````````````````` example
[a](url &quot;tit&quot;)
.
<p>[a](url &quot;tit&quot;)</p>
````````````````````````````````
