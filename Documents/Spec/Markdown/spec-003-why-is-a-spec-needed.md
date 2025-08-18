## Why is a spec needed?

John Gruber's [canonical description of Markdown's
syntax](http://daringfireball.net/projects/markdown/syntax)
does not specify the syntax unambiguously.  Here are some examples of
questions it does not answer:

1.  How much indentation is needed for a sublist?  The spec says that
    continuation paragraphs need to be indented four spaces, but is
    not fully explicit about sublists.  It is natural to think that
    they, too, must be indented four spaces, but `Markdown.pl` does
    not require that.  This is hardly a "corner case," and divergences
    between implementations on this issue often lead to surprises for
    users in real documents. (See [this comment by John
    Gruber](https://web.archive.org/web/20170611172104/http://article.gmane.org/gmane.text.markdown.general/1997).)

2.  Is a blank line needed before a block quote or heading?
    Most implementations do not require the blank line.  However,
    this can lead to unexpected results in hard-wrapped text, and
    also to ambiguities in parsing (note that some implementations
    put the heading inside the blockquote, while others do not).
    (John Gruber has also spoken [in favor of requiring the blank
    lines](https://web.archive.org/web/20170611172104/http://article.gmane.org/gmane.text.markdown.general/2146).)

3.  Is a blank line needed before an indented code block?
    (`Markdown.pl` requires it, but this is not mentioned in the
    documentation, and some implementations do not require it.)

    ``` markdown
    paragraph
        code?
    ```

4.  What is the exact rule for determining when list items get
    wrapped in `<p>` tags?  Can a list be partially "loose" and partially
    "tight"?  What should we do with a list like this?

    ``` markdown
    1. one

    2. two
    3. three
    ```

    Or this?

    ``` markdown
    1.  one
        - a

        - b
    2.  two
    ```

    (There are some relevant comments by John Gruber
    [here](https://web.archive.org/web/20170611172104/http://article.gmane.org/gmane.text.markdown.general/2554).)

5.  Can list markers be indented?  Can ordered list markers be right-aligned?

    ``` markdown
     8. item 1
     9. item 2
    10. item 2a
    ```

6.  Is this one list with a thematic break in its second item,
    or two lists separated by a thematic break?

    ``` markdown
    * a
    * * * * *
    * b
    ```

7.  When list markers change from numbers to bullets, do we have
    two lists or one?  (The Markdown syntax description suggests two,
    but the perl scripts and many other implementations produce one.)

    ``` markdown
    1. fee
    2. fie
    -  foe
    -  fum
    ```

8.  What are the precedence rules for the markers of inline structure?
    For example, is the following a valid link, or does the code span
    take precedence ?

    ``` markdown
    [a backtick (`)](/url) and [another backtick (`)](/url).
    ```

9.  What are the precedence rules for markers of emphasis and strong
    emphasis?  For example, how should the following be parsed?

    ``` markdown
    *foo *bar* baz*
    ```

10. What are the precedence rules between block-level and inline-level
    structure?  For example, how should the following be parsed?

    ``` markdown
    - `a long code span can contain a hyphen like this
      - and it can screw things up`
    ```

11. Can list items include section headings?  (`Markdown.pl` does not
    allow this, but does allow blockquotes to include headings.)

    ``` markdown
    - # Heading
    ```

12. Can list items be empty?

    ``` markdown
    * a
    *
    * b
    ```

13. Can link references be defined inside block quotes or list items?

    ``` markdown
    > Blockquote [foo].
    >
    > [foo]: /url
    ```

14. If there are multiple definitions for the same reference, which takes
    precedence?

    ``` markdown
    [foo]: /url1
    [foo]: /url2

    [foo][]
    ```

In the absence of a spec, early implementers consulted `Markdown.pl`
to resolve these ambiguities.  But `Markdown.pl` was quite buggy, and
gave manifestly bad results in many cases, so it was not a
satisfactory replacement for a spec.

Because there is no unambiguous spec, implementations have diverged
considerably.  As a result, users are often surprised to find that
a document that renders one way on one system (say, a GitHub wiki)
renders differently on another (say, converting to docbook using
pandoc).  To make matters worse, because nothing in Markdown counts
as a "syntax error," the divergence often isn't discovered right away.
