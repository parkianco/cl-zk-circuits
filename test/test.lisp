;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(defpackage #:cl-zk-circuits.test
  (:use #:cl #:cl-zk-circuits)
  (:export #:run-tests))

(in-package #:cl-zk-circuits.test)

(defun run-tests ()
  (format t "Running professional test suite for cl-zk-circuits...~%")
  (assert (initialize-zk-circuits))
  (format t "Tests passed!~%")
  t)
