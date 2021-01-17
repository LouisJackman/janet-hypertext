# hypertext

A HTML DSL for [Janet](https://janet-lang.org/), last tested against Janet
1.14.1.

```janet
(import hypertext)

(def nefarious `<script>alert("Hello, world!")</script>`)

(def element
  (hypertext/markup
    (body
      (section :class "abc" :id "foobar"
        (h1 "A Page")
        (p
          (em "This is a line")
          [nefarious]
          [(string "This is "
                   "another line")])
        hr))))

(print element)

(def elem-class "header")

(def page
  (hypertext/from :html5
    (html
      (head
        (title :class elem-class
          "Test Page")))))

(->
  page
  (hypertext/emit-as-string-fragments prin))
```
```html
<body>
  <section class="abc" id="foobar">
    <h1>A Page</h1>
    <p>
      <em>This is a line</em>&lt;script&gt;alert(&amp;quot;Hello, world!&amp;quot;)&lt;&amp;#x2F;script&gt; This is another line</p>
    <hr></hr>
  </section>
</body>

<!DOCTYPE html>
<html>
  <head>
    <title class="header">Test Page</title>
  </head>
</html>
```

# Features

* Lightweight macro-based DSL with as little clutter as possible.
* Lazy creation of HTML via string emitters, or eager creation into a single
  buffer in memory for simple cases.
* _Optional_ indenting and newlines for pretty-printed results, but fuses text
  nodes to their edge tags to avoid accidentally creating folded whitespace.
* Macro-based, data-based, or function-call based APIs for each need.
* Auto-escaping interpolation of Janet values.
* Decent error messages for common mistakes with its macros.
* Generate both whole pages and HTML snippets.

# Official Mirror of the GitLab Repository

This repository is currently hosted [on
GitLab.com](https://gitlab.com/louis.jackman/janet-hypertext). Official mirrors
exist on [SourceHut](https://git.sr.ht/~louisjackman/janet-hypertext) and
[GitHub](https://github.com/LouisJackman/janet-hypertext). At the moment, GitLab
is still the official hub for contributions such as PRs and issues.

# Installation

Install with `jpm install https://gitlab.com/louis.jackman/janet-hypertext`,
which might require `sudo`. Import into your Janet programs with:

`(import hypertext)`

Hypertext is designed to be used with an explicit package prefix. Importing with
`use` will bring in overly-generic global names like `from`, so avoid that.

# Documentation

The exported functions have documentation strings; use `doc` to read them.

## Interpolation of Janet Values

Janet values can be interpolated as text nodes (freehand text within elements)
and attribute values. Both are escaped, avoiding basic injection attacks.

Interpolation is done with bracketed tuples for children nodes, or directly as
attribute values:

```
janet:1:>(def x 42)
42
janet:2:> (print (hypertext/markup (p :class x hr [x])))
<p class="42">
  <hr></hr>42</p>
nil
```

_It only escapes HTML_. This might seem obvious, but developers have
historically shot themselves in the foot by embedding languages within HTML,
i.e. inline scripts, and still expecting their HTML-only escaping to still
suffice inside. [It will
not](https://volatilethunk.com/posts/2018/03/03/escape-bypassing-language-injection-through-multiple-embedded-languages/post.html),
and `hypertext` is not unique in that regard.

If you need to provide Janet values for more than attribute values or text
nodes, you'll need to use the data-oriented API, which allows splicing anything
via Janet's quasiquoting.

## Data-Oriented API

If the DSL-based approach in the first example is too abstracted away for you,
or you want to mix custom Janet values more liberally into the result, consider
the more direct data-oriented API `hypertext/from-data` instead. It works great
with quasiquoting:

```janet
(def class-value "abc")

(hypertext/from-data
  ~(html [(div {:class ,class-value :id "foobar"}
               ["Hello, <script>alert(0)</script> world"
                (p [(em ["This is a line"])
                    "This is another line"])
                hr])])))
```

This form is more amenable to data structure manipulation, but needs more
syntactical noise to distinguish attributes and children. In particular,
children must alway be wrapped in a tuple for each element.

Unlike the macro forms, this API won't automatically create whole pages with
doctypes if doctype keywords are present. Instead, define whole documents like
so:

```
(hypertext/page (hypertext/doctype :html5)
                (hypertext/from-data
                  '(html
                    [(body
                      [(h1 ["Header"])])])))
```

## Function-Oriented API

The building block for the two layers above is the `hypertext/elem` function,
which can be used directly:

```
(def p (hypertext/elem 'p
                       [(hypertext/elem 'em
                                        {:class "class-1"}
                                        ["Emphasised text"])]))
```

If you end up using this solely, you should probably use a lighter-weight
alternative to this library.

## Lazily Streaming

`hypertext/to-string` covers a common case: turning a HTML element into a
string. What if you want to stream the result lazily to avoid accumulating the
whole result into memory? Enter, `hypertext/emit-as-string-fragments`:

```janet
(def element
  (hypertext/from
    (div :class "abc" :id "foobar"
      "Hello, <script>alert(0)</script> world"
      (p
       (em "This is a line")
       "This is another line")
      hr)))

(->
  element
  (hypertext/emit-as-string-fragments prin))
```

Both `hypertext/to-string` and `hypertext/emit-as-string-fragments` just
pass a different receiving function to `hypertext/element-marshaller`, which can
be used directly if you need more control.

## Pretty-Printing

Results are pretty-printed by default. They indent properly and produce
newlines. You can minify the result by choosing a different formatter or
defining your own:

```
(hypertext/to-string element :formatter hypertext/minified)
```

Custom formatters can be passed in for most functions converting elements into
strings, but a default can be specified if this becomes tedious:

```
(setdyn (hypertext/default-formatter)
        (hypertext/minified))
```

In fact, this is the only way to change the formatting produced by
`hypertext/markup`.

## Error Messages

`hypertext` tries to give useful error messages whenever possible when
transforming your code with its macro. For example:

```
error: tags for elements must be symbol, e.g. 'p, not "div"
```

```
error: a HTML tuple can have a maximum of three items: a tag, an attributes
struct, and a children tuple; did you forget the wrap all of the children nodes
in `[` and `]`, or forget to put the attributes straight after the tag?
```

# Alternatives

If this library isn't to your taste, consider these other HTML-emitting
libraries for Janet:

* [janet-html](https://github.com/brandonchartier/janet-html)
* [The built-in HTML emitter in Joy](https://github.com/joy-framework/joy)

`hypertext`'s doctype generation was borrowed from Joy.

