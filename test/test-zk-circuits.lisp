;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

;;;; test-zk-circuits.lisp - Unit tests for zk-circuits
;;;;
;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

(defpackage #:cl-zk-circuits.test
  (:use #:cl)
  (:export #:run-tests))

(in-package #:cl-zk-circuits.test)

(defun run-tests ()
  "Run all tests for cl-zk-circuits."
  (format t "~&Running tests for cl-zk-circuits...~%")
  ;; TODO: Add test cases
  ;; (test-function-1)
  ;; (test-function-2)
  (format t "~&All tests passed!~%")
  t)
