## foo
### foo
#### foo
##### foo
###### foo
.
<h1>foo</h1>
<h2>foo</h2>
<h3>foo</h3>
<h4>foo</h4>
<h5>foo</h5>
<h6>foo</h6>
````````````````````````````````


More than six `#` characters is not a heading:

```````````````````````````````` example
####### foo
.
<p>####### foo</p>
````````````````````````````````


At least one space is required between the `#` characters and the
heading's contents, unless the heading is empty.  Note that many
implementations currently do not require the space.  However, the
space was required by the
[original ATX implementation](http://www.aaronsw.com/2002/atx/atx.py),
and it helps prevent things like the following from being parsed as
headings:

```````````````````````````````` example
#5 bolt

#hashtag
.
<p>#5 bolt</p>
<p>#hashtag</p>
````````````````````````````````


This is not a heading, because the first `#` is escaped:

```````````````````````````````` example
\## foo
.
<p>## foo</p>
````````````````````````````````


Contents are parsed as inlines:

```````````````````````````````` example
# foo *bar* \*baz\*
.
<h1>foo <em>bar</em> *baz*</h1>
````````````````````````````````


Leading and trailing [whitespace] is ignored in parsing inline content:

```````````````````````````````` example
#                  foo
.
<h1>foo</h1>
````````````````````````````````


One to three spaces indentation are allowed:

```````````````````````````````` example
 ### foo
  ## foo
   # foo
.
<h3>foo</h3>
<h2>foo</h2>
<h1>foo</h1>
````````````````````````````````


Four spaces are too much:

```````````````````````````````` example
    # foo
.
<pre><code># foo
</code></pre>
````````````````````````````````


```````````````````````````````` example
foo
    # bar
.
<p>foo
# bar</p>
````````````````````````````````


A closing sequence of `#` characters is optional:

```````````````````````````````` example
