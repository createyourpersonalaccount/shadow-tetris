;;; A macro module with useful macros.

(fn var* [name docstring ...]
  "Define a mutable local variable named NAME with DOCSTRING and an
optional VALUE defaulting to 'nil'."
  (match (values (select :# ...) ...)
    (0) `(var ,name nil)
    (_ value) `(var ,name ,value)))

(fn local* [name docstring ...]
  "Define an immutable local variable named NAME with DOCSTRING and an
optional VALUE defaulting to 'nil'."
  (match (values (select :# ...) ...)
    (0) `(local ,name nil)
    (_ value) `(local ,name ,value)))

{: var* : local*}
