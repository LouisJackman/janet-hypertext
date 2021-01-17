#
# janet-hypertext
#

(defn- nop [])

(defmacro- flip [x]
  ~(set ,x (not ,x)))

(defn- pretty-format []
  (dyn :pretty-format "%q"))

(defn- map-pairs [f xs &keys {:output output}]
  (default output struct)

  (def mapped
    (->> xs
         pairs
         (map (fn [[k v]]
                (f k v)))))

  (output ;(array/concat @[] ;mapped)))

#
# Element Types
#

(def- tag string)
(def- text-node string)

#
# Elements
#

(defn elem
  "Produces a HTML element, where the first argument is a struct of attributes
  and the seconds is a tuple of child elements (which can be strings for text
  nodes). Drop arguments for sane defaults, except for the mandatory `tag`."
  [tag &opt arg rest]
  (unless (symbol? tag)
    (errorf (string "tags for elements must be symbols, e.g. 'p, not "
                    (pretty-format))
            tag))
  (def [attrs children]
    (case (type arg)
      :tuple [{} arg]
      :nil [{} []]
      :struct [arg (if (nil? rest)
                     []
                     rest)]
      (errorf (string "after the tag, the next item must be either a struct of attributes or a tuple of children, not "
                      (pretty-format))
              arg)))
  {:tag tag
   :attrs attrs
   :children children})

#
# Doctypes
#

# Credit to Joy, from which this function was adapted:
# https://github.com/joy-framework/joy/blob/master/src/joy/html.janet
(defn- doctype-string [version &opt style]
  (let [key [version (or style "")]
        doctypes {[:html5 ""] "html"
                  [:html4 :strict] `HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd"`
                  [:html4 :transitional] `HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"`
                  [:html4 :frameset] `HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd"`
                  [:xhtml1.0 :strict] `html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"`
                  [:xhtml1.0 :transitional] `html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"`
                  [:xhtml1.0 :frameset] `html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd"`
                  [:xhtml1.1 ""] `html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"`
                  [:xhtml1.1 :basic] `html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd"`}
        doctype (doctypes key)]
    (when (nil? doctype)
      (errorf (string "unknown doctype for "
                      (dyn :pretty-format "%q")
                      "; try :html5")
              key))
    doctype))

(defn doctype
  "Produce a doctype with a version such as `:html5` and an _optional_ style
  like `:frameset`"
  [version &opt style]
  {:version version
   :style style})

(defn doctype-to-string [{:version version :style style}]
  (string "<!DOCTYPE " (doctype-string version style) ">"))

#
# Pages: a Doctype and a Root Document Element
#

(defn page
  "Produces a page with a provided doctype and a document root element. If the
  doctype is omitted, HTML5 is assumed."
  [arg1 &opt document]
  (if (nil? document)
    {:doctype (doctype :html5)
     :document arg1}
    (if (struct? arg1)
      {:doctype arg1
       :document document}
      (errorf "expecting a doctype struct; did you type `:html5` where you meant `(hypertext/doctype :html5)`?"))))

(defn- resembles-page [x]
  (def missing (gensym))
  (def finding (get x :doctype missing))
  (not= finding missing))

#
# Escaping
#

(defn- escapes [codes]
  (pairs (map-pairs (fn [char code]
                      [char (string "&" code ";")])
                    codes)))

# Each replacement is done in sequence, so ampersand is singled out and done
# beforehand because it's the only one which might also appear in escaped
# replacements.
(def- text-node-escape-ampersand "amp")

(defn- escaper [escapes]
  (fn [s]
    (def without-ampersands (string/replace-all "&"
                                                text-node-escape-ampersand
                                                s))

    (reduce (fn [result [char replacement]]
              (string/replace-all char replacement result))
            without-ampersands
            escapes)))

(def- text-node-escapes-sans-ampersand
  (escapes {"<" "lt"
            ">" "gt"
            "\"" "quot"
            "/" "#x2F"
            "'" "#x27"
            "%" "#37"}))

(def- attr-name-escapes text-node-escapes-sans-ampersand)

(def- attr-value-escapes (escapes {"\"" "quot"}))

(def- escape-text-node (escaper text-node-escapes-sans-ampersand))
(def- escape-attr-name (escaper attr-name-escapes))
(def- escape-attr-value (escaper attr-value-escapes))

#
# Marshalling Formatters
#
# Marshalling formatters consist of two actions: indent and newline. They
# implement these according to their overall formatting strategy and take an
# emitter on construction.
#

(defn pretty
  "Format with indents and newlines."
  [emit]
  {:newline (fn (_)
              (emit "\n"))
   :indent (fn (_ indent-level)
             (for _ 0 indent-level
               (emit "  ")))})

(defn no-indents
  "Indent without indents but with newlines."
  [emit]
  {:newline (fn (_)
              (emit "\n"))
   :indent (fn (_ _))})

(defn minified
  "Neither indent nor add newlines."
  [_]
  {:newline (fn (_))
   :indent (fn (_ _))})

(def default-formatter
  "The symbol of the dynamic variable representing the default formatter to use.
  It is used if one is not explicitly passed in to a function."
  (gensym))

(setdyn default-formatter pretty)

#
# Element Marshalling
#

(defn element-marshaller
  "Creates an element marshaller, a function that emits HTML string fragments for an
  element, each string fragment going out via `emit`. No guarantee is made about
  the content or size of the fragments; they are only guaranteed to be a valid
  HTML document if all combined together."
  [emit &keys {:formatter formatter}]
  (default formatter (dyn default-formatter pretty))

  (def formatter (formatter emit))

  (defn quote-attr-value [s]
    (emit "\"")
    (emit (escape-attr-value s))
    (emit "\""))

  (defn attrs-to-str [attrs]
    (loop [[name value] :pairs attrs]
      (emit " ")
      (emit (escape-attr-name name))
      (emit "=")
      (quote-attr-value value)))

  (var elem-to-string nil)

  (defn children-to-str [children indent-level]
    (for i 0 (length children)
      (def child (children i))
      (def previous-child (get children (dec i)))
      (def sequenced-text (and (string? child)
                               (string? previous-child)))
      (def fold-whitespace (or (string? child)
                               (string? previous-child)))

      (when sequenced-text
        (emit " "))

      (unless fold-whitespace
        (:newline formatter)
        (:indent formatter indent-level))

      (case (type child)
        :string (emit (escape-text-node child))
        :struct (elem-to-string child indent-level)
        (errorf (string "expecting either a text node (string) or a child element (struct), but received a "
                        (pretty-format))
                child))))

  (set elem-to-string (fn [elem indent-level &opt top-level]
                        (default top-level false)
                        (emit "<")
                        (emit (elem :tag))
                        (when (elem :attrs)
                          (attrs-to-str (elem :attrs)))
                        (emit ">")
                        (unless (empty? (elem :children))
                          (children-to-str (elem :children) (inc indent-level))
                          (unless (string? (last (elem :children)))
                           (:newline formatter)
                           (:indent formatter indent-level)))
                        (emit "</")
                        (emit (elem :tag))
                        (emit ">")))

  (defn to-string [x]
    (if (string? x)
      x
      (if (resembles-page x)
        (do
          (emit (doctype-to-string (x :doctype)))
          (:newline formatter)
          (elem-to-string (x :document) 0 true))
        (elem-to-string x 0 true))))

  to-string)

#
# Marshalling Producers
#
# Constructors of tables with at least an `:emit` member function. They are used
# to accumulate resulting HTML strings.
#

(defn in-memory-producer
  "Emits string fragments into an in-memory buffer, which can later be
  \"collected\" into a string."
  [&opt buffer]
  (default buffer @"")

  {:emit (fn [_ s]
           (buffer/push-string buffer s))
   :collect (fn [_]
              (string buffer))})

(defn streaming-producer
  "Streams string fragments into the provided function."
  [f]
  {:emit (fn [_ s] (f s))})

(defn to-string
  "Converts an element into a HTML string eagerly in memory, returning a
  string."
  [elem &keys {:formatter formatter}]
  (let [producer (in-memory-producer)
        emit (fn [s]
               (:emit producer s))
        marshal-element (element-marshaller emit
                                            :formatter formatter)]
    (marshal-element elem)
    (:collect producer)))

(defn emit-as-string-fragments
  "Converts an element into a HTML string lazily, streaming the string fragments
  out via the provided function."
  [elem emit &keys {:formatter formatter}]
  (let [producer (streaming-producer emit)
        emit (fn [s]
               (:emit producer s))
        marshal-element (element-marshaller emit
                                            :formatter formatter)]
    (marshal-element elem)))

#
# DSL Constructors
#
# Using `elem` is a bit raw. Provide a data-oriented wrapper around it,
# and provide a macro wrapper around that. Each one trades off more flexibility
# for succinctness.
#

(var from-data
  "Turns a data representation of elements into an in-memory element. See
  `README.md` for an example of the data's structure."
  nil)

(defn- html-from-tuple [t]
  (when (empty? t)
    (error "an empty tuple isn't enough to describe a HTML element; either use a standalone symbol, or a tuple with at least two elements for one including attributes and/or children"))
  (when (= 1 (length t))
    (error "for elements without attributes and children, just use them standalone outside of a tuple"))
  (if (< 3 (length t))
    (error "a HTML tuple can have a maximum of three items: a tag, an attributes struct, and a children tuple; did you forget the wrap all of the children nodes in `[` and `]`, or forget to put the attributes straight after the tag?"))

  (def [tag arg rest] t)
  (def [attrs children]
    (case (type arg)
      :tuple [{} arg]
      :struct [arg (if (nil? rest)
                     []
                     rest)]
      [{} (tuple/slice t 1)]))
  (def converted-attrs @{})

  # Autoconvert attribute names into keywords.
  (eachp [name value] attrs
    (set (converted-attrs (keyword name))
         (string value)))

  (elem tag
        (table/to-struct converted-attrs)
        (tuple/slice (map from-data children))))

(set from-data (fn [data]
                 (case (type data)
                   :symbol (elem data)
                   :tuple (html-from-tuple data)
                   :struct data

                   # Autoconvert Janet values into strings for text nodes.
                   (string data))))

(defn- html-attrs [args]
  (def result @{})
  (var on-key true)
  (var pending-key nil)
  (var rest [])
  (for i 0 (length args)
    (def arg (args i))
    (if on-key
      (if (keyword? arg)
        (set pending-key arg)
        (do
          (set rest (tuple/slice args i))
          (break)))
      (set (result pending-key)
           (if (symbol? arg)
             ['unquote arg]
             arg)))
    (flip on-key))
  (def attrs (table/to-struct result))
  [attrs rest])

(defn- html-body [body]
  (if (tuple? body)
    (if (= (tuple/type body) :brackets)
      (do
        (unless (= (length body)
                   1)
          (errorf (string "escaped Janet values wrapped in `[` and `]` within hypertext templates can only contain one value, not "
                          (dyn :pretty-format "%q"))
                  body))
        ['unquote (body 0)])
      (let [[tag arg] body
            rest (tuple/slice body 1)
            [attrs children] (if (keyword? arg)
                               (html-attrs rest)
                               [{} rest])
            transformed-children (tuple/slice (map html-body children))]
        [tag attrs transformed-children]))
    body))

(defn- from-gen [body]

  (if (< 3 (length body))
    (error "up to 3 elements can be provided: a doctype, a doctype variant, and a document, and only the document element is mandatory"))

  (if (and (< 1 (length body))
           (not (keyword? (body 0))))
    (error "only a single root element can be passed to `hypertext/markup`; if you want to specify doctypes, ensure keywords are being used and that they come before the root document element"))

  (let [[first second rest] body]
    (if (keyword? first)
      (let [[version style document] (if (keyword? second)
                                       [first
                                        second
                                        rest]
                                       [first
                                        nil
                                        second])]
        (def data (html-body document))
        {:doctype (doctype version style)
         :document ~(,from-data (,'quasiquote ,data))})
      (do
        (def data (html-body first))
        ~(,from-data (,'quasiquote ,data))))))

(defmacro from
  "Produces a HTML element or a whole page from a lightweight representation
  based on Janet syntax. Whether it's an element or a whole page depends on
  whether it starts with doctype-related keywords. See README.md for an
  example."
  [& body]
  (from-gen body))

(defmacro markup
  "Produces a HTML string or a whole page string from a lightweight
  representation based on Janet syntax. Whether it's an element or a whole page
  depends on whether it starts with doctype-related keywords. See README.md for
  an example. There is no formatter argument; formatting can only be changed by
  setting `hypertext/default-formatter`."
  [& body]

  ~(,to-string ,(from-gen body)))

