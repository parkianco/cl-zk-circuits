;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: BSD-3-Clause
;;;;
;;;; Constraint representation for circuits

(in-package #:cl-zk-circuits)

;;; ============================================================================
;;; R1CS Constraint: A * B = C
;;; ============================================================================

(defstruct constraint
  "R1CS constraint: A * B = C where A, B, C are linear combinations."
  (a nil :type (or null lc))
  (b nil :type (or null lc))
  (c nil :type (or null lc))
  (name nil :type (or null string)))

(defun constraint-satisfied-p (constraint wire-values)
  "Check if constraint is satisfied for given wire values."
  (let* ((a-val (lc-evaluate (constraint-a constraint) wire-values))
         (b-val (lc-evaluate (constraint-b constraint) wire-values))
         (c-val (lc-evaluate (constraint-c constraint) wire-values))
         (ab (field-mul a-val b-val)))
    (= ab c-val)))

;;; ============================================================================
;;; Error Conditions
;;; ============================================================================

(define-condition circuit-error (error)
  ((message :initarg :message :reader circuit-error-message))
  (:report (lambda (c s)
             (format s "Circuit error: ~a" (circuit-error-message c)))))

(define-condition constraint-violation-error (circuit-error)
  ((constraint :initarg :constraint :reader constraint-violation-constraint)
   (values :initarg :values :reader constraint-violation-values))
  (:report (lambda (c s)
             (format s "Constraint violation: ~a = ~a"
                     (constraint-name (constraint-violation-constraint c))
                     (constraint-violation-values c)))))

(define-condition wire-not-found-error (circuit-error)
  ((wire-id :initarg :wire-id :reader wire-not-found-id))
  (:report (lambda (c s)
             (format s "Wire not found: ~a" (wire-not-found-id c)))))

;;; ============================================================================
;;; Constraint Construction Helpers
;;; ============================================================================

(defun make-mul-constraint (w1 w2 w-out &optional name)
  "Create constraint: w1 * w2 = w-out."
  (make-constraint
   :a (wire-to-lc w1)
   :b (wire-to-lc w2)
   :c (wire-to-lc w-out)
   :name name))

(defun make-add-constraint (w1 w2 w-out &optional name)
  "Create constraint: w1 + w2 = w-out (as (w1 + w2) * 1 = w-out)."
  (make-constraint
   :a (lc-add (wire-to-lc w1) (wire-to-lc w2))
   :b (wire-to-lc +wire-one+)
   :c (wire-to-lc w-out)
   :name name))

(defun make-constant-constraint (wire value &optional name)
  "Create constraint: wire = constant."
  (make-constraint
   :a (wire-to-lc wire)
   :b (wire-to-lc +wire-one+)
   :c (constant-lc value)
   :name name))

(defun make-assert-zero-constraint (lc &optional name)
  "Create constraint: lc = 0."
  (make-constraint
   :a lc
   :b (wire-to-lc +wire-one+)
   :c (constant-lc 0)
   :name name))

(defun make-boolean-constraint (wire &optional name)
  "Create constraint: wire * (1 - wire) = 0 (ensures wire is 0 or 1)."
  (make-constraint
   :a (wire-to-lc wire)
   :b (lc-sub (wire-to-lc +wire-one+) (wire-to-lc wire))
   :c (constant-lc 0)
   :name name))
