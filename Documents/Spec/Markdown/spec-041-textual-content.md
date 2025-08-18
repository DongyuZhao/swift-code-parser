## Textual content

Any characters not given an interpretation by the above rules will
be parsed as plain textual content.

```````````````````````````````` example
hello $.;'there
.
<p>hello $.;'there</p>
````````````````````````````````


```````````````````````````````` example
Foo χρῆν
.
<p>Foo χρῆν</p>
````````````````````````````````


Internal spaces are preserved verbatim:

```````````````````````````````` example
Multiple     spaces
.
<p>Multiple     spaces</p>
````````````````````````````````


<!-- END TESTS -->

# Appendix: A parsing strategy

In this appendix we describe some features of the parsing strategy
used in the CommonMark reference implementations.
