# Janet Hypertext

A HTML DSL for [Janet](https://janet-lang.org/).

```janet
(import "hypertext")

(def element
  (hypertext/html
    (div :class "abc" :id "foobar"
      "Hello, <script>alert(0)</script> world"
      (p
       (em "This is a line")
       "This is another line")
      hr)))

(print element)

(->
  (hypertext/from hr)
  hypertext/to-string
  print)

(def page
  (hypertext/from :html5
    (html
      (head
        (title "Test Page")))))

(->
  page
  (hypertext/emit-as-string-fragments prin))
```
```html
<div class="abc" id="foobar">
  Hello, &lt;script&gt;alert(0)&lt;&amp;#x2F;script&gt; world
  <p>
    <em>
      This is a line
    </em>
    This is another line
  </p>
  <hr></hr>
</div>

<hr></hr>

<!DOCTYPE html>
<html>
  <head>
    <title>
      Test Page
    </title>
  </head>
</html>nil
```

# Features

* Lightweight macro-based DSL with as little clutter as possible.
* Lazy creation of HTML via string emitters, or eager creation into a single
  buffer in memory for simple cases.
* _Optional_ indenting and newlines for pretty-printed results.
* Macro-based, data-based, or function-call based APIs for each need.
* Decent error messages for common mistakes with its macros.
* Generate both whole pages and HTML snippets.

# Official Mirror of the GitLab Repository

This repository is hosted [on
GitLab.com](https://gitlab.com/louis.jackman/janet-hypertext). If you're seeing
this on GitHub, you're on the official GitHub mirror. [Go to
GitLab](https://gitlab.com/louis.jackman/janet-hypertext) to contribute.

# Alternatives

If this library isn't to your taste, consider these other HTML-emitting
libraries for Janet:

* [janet-html](https://github.com/brandonchartier/janet-html)
* [The built-in HTML emitter in Joy](https://github.com/joy-framework/joy)

`janet-hypertext`'s doctype generation was borrowed from Joy.

# Documentation

The exported functions have documentation strings; use `doc` to read them.

## Data-Oriented API

If the DSL-based approach in the first example is too abstracted away for you,
or you want to mix custom Janet values into the result, consider the more direct
data-oriented API `hypertext/from-data` instead:

```janet
(hypertext/from-data
  '(html [(div {:class "abc" :id "foobar"}
               ["Hello, <script>alert(0)</script> world"
                (p [(em ["This is a line"])
                    "This is another line"])
                hr])])))
```

This form is more amenable to data structure manipulation, but needs more
syntactical noise to distinguish attributes and children. In particular,
children must alway be wrapped in a tuple for each element.

I'm still working out an elegant way to allow splicing _escaped_ data using the
macro DSL, but the data-oriented API will suffice until that's implemented.

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
newlines. You can "minify" the result by disabling both of these features:

```
(hypertext/to-string element :newlines? false
                             :indent? false)
```

## Error Messages

`janet-hypertext` tries to give useful error messages whenever possible when
transforming your code with its macro. For example:

```
error: tags for elements must be symbol, e.g. 'p, not "div"
```

```
error: a HTML tuple can have a maximum of three items: a tag, an attributes
struct, and a children tuple; did you forget the wrap all of the children nodes
in `[` and `]`, or forget to put the attributes straight after the tag?
```

