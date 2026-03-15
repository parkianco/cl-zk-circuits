# cl-zk-circuits

Pure Common Lisp implementation of Zk Circuits

## Overview
This library provides a robust, zero-dependency implementation of Zk Circuits for the Common Lisp ecosystem. It is designed to be highly portable, performant, and easy to integrate into any SBCL/CCL/ECL environment.

## Getting Started

Load the system using ASDF:

```lisp
(asdf:load-system #:cl-zk-circuits)
```

## Usage Example

```lisp
;; Initialize the environment
(let ((ctx (cl-zk-circuits:initialize-zk-circuits :initial-id 42)))
  ;; Perform batch processing using the built-in standard toolkit
  (multiple-value-bind (results errors)
      (cl-zk-circuits:zk-circuits-batch-process '(1 2 3) #'identity)
    (format t "Processed ~A items with ~A errors.~%" (length results) (length errors))))
```

## License
Apache-2.0
