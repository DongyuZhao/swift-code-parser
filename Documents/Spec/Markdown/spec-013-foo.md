## foo ##
  ###   bar    ###
.
<h2>foo</h2>
<h3>bar</h3>
````````````````````````````````


It need not be the same length as the opening sequence:

```````````````````````````````` example
# foo ##################################
##### foo ##
.
<h1>foo</h1>
<h5>foo</h5>
````````````````````````````````


Spaces are allowed after the closing sequence:

```````````````````````````````` example
### foo ###
.
<h3>foo</h3>
````````````````````````````````


A sequence of `#` characters with anything but [spaces] following it
is not a closing sequence, but counts as part of the contents of the
heading:

```````````````````````````````` example
### foo ### b
.
<h3>foo ### b</h3>
````````````````````````````````


The closing sequence must be preceded by a space:

```````````````````````````````` example
# foo#
.
<h1>foo#</h1>
````````````````````````````````


Backslash-escaped `#` characters do not count as part
of the closing sequence:

```````````````````````````````` example
### foo \###
