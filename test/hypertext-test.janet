(import "/src/hypertext" :prefix "")

(def- expected {:tag 'p
                :attrs {:class "abc"}
                :children ["Hello, "
                           {:tag 'em
                            :attrs {}
                            :children ["world!"]}]})

(def- expected-page {:doctype (doctype :html5)
                     :document {:tag 'html
                                :attrs {}
                                :children [{:tag 'head
                                            :attrs {}
                                            :children [{:tag 'title
                                                        :attrs {}
                                                        :children ["Hola!"]}]}]}})

(defn- assert-expected [x]
  (assert (deep= x expected)))

(defn- test-elem []
  (def element (elem 'p
                      {:class "abc"}
                      ["Hello, "
                       (elem 'em ["world!"])]))

  (assert-expected element))

(defn- test-from-data []
  (def element (from-data '(p {:class "abc"}
                              ["Hello, "
                               (em ["world!"])])))

  (assert-expected element))

(defn- test-from []
  (def element (from (p :class "abc"
                        "Hello, "
                        (em "world!"))))

  (assert-expected element))

(defn- test-html []
  (def element (markup (p :class "abc"
                          "Hello, "
                          (em "world!"))))
  (def expected (to-string expected))

  (assert (= element expected)))

(defn- test-from-data-interpolation []
  (def x 42)
  (def element (from-data ~(p {:class x} [42])))
  (comment (assert (= ((element :attrs) :class)
             "42")))
  (assert (= ((element :children) 0)
             "42")))

(defn- test-from-interpolation []
  (def x 42)
  (def element (from (p :class x [x])))
  (assert (= ((element :attrs) :class)
             "42"))
  (assert (= ((element :children) 0)
             "42")))

(defn- test-nesting []
  (def b (from (b "Holla!")))
  (def p (markup (p [b])))
  (def expected (markup (p (b "Holla!"))))
  (assert (deep= expected p)))

(defn- test-escaping []
  (def nefarious "<script>alert(0)</script>")
  (def element (markup (p [nefarious])))
  (def expected "<p>&lt;script&gt;alert(0)&lt;&#x2F;script&gt;</p>")

  (assert (= element expected)))

(defn- test-doctype-string []
  (def expected "<!DOCTYPE html>")

  (assert (= expected
             (doctype-to-string (doctype :html5)))))

(defn- test-html-page []
  (def element (from :html5
                      (html
                        (head
                          (title "Hola!")))))

  (def expected expected-page)

  (assert (deep= element expected)))

(defn- test-elem-marshal-and-formatting []
  (def marshalled "<p class=\"abc\">Hello, <em>world!</em></p>")
  (def expected-string (to-string expected :formatter minified))
  (assert (= marshalled
             expected-string))

  (with-dyns [default-formatter no-indents]
    (def marshalled "<p class=\"abc\">Hello, <em>world!</em>\n</p>")
    (def expected-string (to-string expected))

    (assert (= marshalled
               expected-string))))

(defn- test-page-marshal []
  (def marshalled ``
<!DOCTYPE html>
<html>
  <head>
    <title>Hola!</title>
  </head>
</html>
``)
  (def expected (to-string expected-page))
  (assert (= marshalled expected)))

(test-elem)
(test-from-data)
(test-from)
(test-html)
(test-from-data-interpolation)
(test-from-interpolation)
(test-nesting)
(test-escaping)
(test-doctype-string)
(test-html-page)
(test-elem-marshal-and-formatting)
(test-page-marshal)

