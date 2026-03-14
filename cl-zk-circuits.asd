;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: BSD-3-Clause

(asdf:defsystem #:cl-zk-circuits
  :description "Pure Common Lisp zero-knowledge circuit construction"
  :author "Parkian Company LLC"
  :license "BSD-3-Clause"
  :version "0.1.0"
  :homepage "https://github.com/parkianco/cl-zk-circuits"
  :depends-on ()
  :serial t
  :components
  ((:file "package")
   (:module "src"
    :serial t
    :components
    ((:file "field")
     (:file "wire")
     (:file "constraint")
     (:file "r1cs")
     (:file "gadgets")
     (:file "compiler")))))

(asdf:defsystem #:cl-zk-circuits/test
  :description "Tests for cl-zk-circuits"
  :depends-on (#:cl-zk-circuits)
  :serial t
  :components ((:module "test"
                :components ((:file "test-zk-circuits"))))
  :perform (asdf:test-op (o c)
             (let ((result (uiop:symbol-call :cl-zk-circuits.test :run-tests)))
               (unless result
                 (error "Tests failed")))))
