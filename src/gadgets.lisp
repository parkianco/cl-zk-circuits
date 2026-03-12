;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: BSD-3-Clause
;;;;
;;;; Circuit gadgets (reusable components)

(in-package #:cl-zk-circuits)

;;; ============================================================================
;;; Basic Arithmetic Gadgets
;;; ============================================================================

(defun gadget-add (circuit a b)
  "Create addition gadget: out = a + b.
   Returns output wire."
  (let* ((a-val (wire-value a))
         (b-val (wire-value b))
         (out-val (when (and a-val b-val)
                    (field-add a-val b-val)))
         (out (circuit-allocate-wire circuit :value out-val)))
    (circuit-add-constraint circuit (make-add-constraint a b out "add"))
    out))

(defun gadget-mul (circuit a b)
  "Create multiplication gadget: out = a * b.
   Returns output wire."
  (let* ((a-val (wire-value a))
         (b-val (wire-value b))
         (out-val (when (and a-val b-val)
                    (field-mul a-val b-val)))
         (out (circuit-allocate-wire circuit :value out-val)))
    (circuit-add-constraint circuit (make-mul-constraint a b out "mul"))
    out))

(defun gadget-inv (circuit a)
  "Create inversion gadget: out = 1/a.
   Returns output wire. Requires a != 0."
  (let* ((a-val (wire-value a))
         (out-val (when (and a-val (not (zerop a-val)))
                    (field-inv a-val)))
         (out (circuit-allocate-wire circuit :value out-val)))
    ;; Constraint: a * out = 1
    (circuit-add-constraint circuit
      (make-constraint
       :a (wire-to-lc a)
       :b (wire-to-lc out)
       :c (wire-to-lc +wire-one+)
       :name "inv"))
    out))

(defun gadget-div (circuit a b)
  "Create division gadget: out = a / b.
   Returns output wire."
  (let ((b-inv (gadget-inv circuit b)))
    (gadget-mul circuit a b-inv)))

;;; ============================================================================
;;; Boolean Gadgets
;;; ============================================================================

(defun gadget-boolean (circuit wire)
  "Assert wire is boolean (0 or 1)."
  (circuit-add-constraint circuit (make-boolean-constraint wire "boolean"))
  wire)

(defun gadget-assert-zero (circuit wire)
  "Assert wire = 0."
  (circuit-add-constraint circuit
    (make-constant-constraint wire 0 "assert-zero"))
  wire)

(defun gadget-assert-nonzero (circuit wire)
  "Assert wire != 0 by computing inverse."
  (gadget-inv circuit wire)
  wire)

(defun gadget-assert-equal (circuit a b)
  "Assert a = b."
  (let ((diff-lc (lc-sub (wire-to-lc a) (wire-to-lc b))))
    (circuit-add-constraint circuit
      (make-assert-zero-constraint diff-lc "assert-equal")))
  a)

;;; ============================================================================
;;; Boolean Logic Gadgets
;;; ============================================================================

(defun gadget-and (circuit a b)
  "Boolean AND: out = a AND b (both must be boolean).
   AND is just multiplication for booleans."
  (gadget-mul circuit a b))

(defun gadget-or (circuit a b)
  "Boolean OR: out = a OR b = a + b - a*b."
  (let* ((ab (gadget-mul circuit a b))
         (a-val (wire-value a))
         (b-val (wire-value b))
         (ab-val (wire-value ab))
         (out-val (when (and a-val b-val ab-val)
                    (field-sub (field-add a-val b-val) ab-val)))
         (out (circuit-allocate-wire circuit :value out-val)))
    ;; a + b - ab = out => (a + b - out) * 1 = ab
    (circuit-add-constraint circuit
      (make-constraint
       :a (lc-sub (lc-add (wire-to-lc a) (wire-to-lc b))
                  (wire-to-lc out))
       :b (wire-to-lc +wire-one+)
       :c (wire-to-lc ab)
       :name "or"))
    out))

(defun gadget-xor (circuit a b)
  "Boolean XOR: out = a XOR b = a + b - 2*a*b."
  (let* ((ab (gadget-mul circuit a b))
         (a-val (wire-value a))
         (b-val (wire-value b))
         (ab-val (wire-value ab))
         (out-val (when (and a-val b-val ab-val)
                    (field-sub (field-add a-val b-val)
                               (field-mul 2 ab-val))))
         (out (circuit-allocate-wire circuit :value out-val)))
    ;; Constraint: a + b - 2*ab = out
    (circuit-add-constraint circuit
      (make-constraint
       :a (lc-sub (lc-add (wire-to-lc a) (wire-to-lc b))
                  (wire-to-lc out))
       :b (wire-to-lc +wire-one+)
       :c (lc-scale (wire-to-lc ab) 2)
       :name "xor"))
    out))

(defun gadget-not (circuit a)
  "Boolean NOT: out = 1 - a."
  (let* ((a-val (wire-value a))
         (out-val (when a-val (field-sub 1 a-val)))
         (out (circuit-allocate-wire circuit :value out-val)))
    ;; (1 - a) * 1 = out
    (circuit-add-constraint circuit
      (make-constraint
       :a (lc-sub (wire-to-lc +wire-one+) (wire-to-lc a))
       :b (wire-to-lc +wire-one+)
       :c (wire-to-lc out)
       :name "not"))
    out))

;;; ============================================================================
;;; Conditional Gadget
;;; ============================================================================

(defun gadget-conditional (circuit cond then-wire else-wire)
  "Conditional select: out = cond ? then : else.
   out = cond * then + (1 - cond) * else."
  (let* ((cond-val (wire-value cond))
         (then-val (wire-value then-wire))
         (else-val (wire-value else-wire))
         (out-val (when (and cond-val then-val else-val)
                    (if (= cond-val 1) then-val else-val)))
         (out (circuit-allocate-wire circuit :value out-val)))
    ;; cond * (then - else) = out - else
    (circuit-add-constraint circuit
      (make-constraint
       :a (wire-to-lc cond)
       :b (lc-sub (wire-to-lc then-wire) (wire-to-lc else-wire))
       :c (lc-sub (wire-to-lc out) (wire-to-lc else-wire))
       :name "conditional"))
    out))

;;; ============================================================================
;;; Comparison Gadgets
;;; ============================================================================

(defun gadget-less-than (circuit a b num-bits)
  "Check if a < b for num-bits-sized integers.
   Returns boolean wire (1 if a < b, 0 otherwise)."
  (declare (ignore circuit a b num-bits))
  ;; Simplified: would need bit decomposition
  ;; Full implementation requires range proofs
  (error "gadget-less-than requires bit decomposition (not yet implemented)"))

(defun gadget-range-check (circuit wire num-bits)
  "Check that 0 <= wire < 2^num-bits.
   Decomposes wire into bits and constrains each bit."
  (let ((bits nil)
        (sum-lc (constant-lc 0))
        (power 1)
        (wire-val (wire-value wire)))
    ;; Allocate bit wires
    (dotimes (i num-bits)
      (let* ((bit-val (when wire-val
                        (if (logbitp i wire-val) 1 0)))
             (bit-wire (circuit-allocate-wire circuit :value bit-val)))
        ;; Constrain to boolean
        (gadget-boolean circuit bit-wire)
        ;; Add to sum
        (setf sum-lc (lc-add sum-lc (lc-scale (wire-to-lc bit-wire) power)))
        (setf power (field-mul power 2))
        (push bit-wire bits)))
    ;; Constraint: sum of bits*powers = wire
    (circuit-add-constraint circuit
      (make-constraint
       :a (lc-sub sum-lc (wire-to-lc wire))
       :b (wire-to-lc +wire-one+)
       :c (constant-lc 0)
       :name "range-check"))
    (nreverse bits)))

;;; ============================================================================
;;; Bit Packing/Unpacking
;;; ============================================================================

(defun gadget-pack-bits (circuit bit-wires)
  "Pack boolean wires into a single field element.
   Returns the packed wire."
  (let ((sum-lc (constant-lc 0))
        (power 1)
        (total 0))
    (dolist (bit bit-wires)
      (let ((bit-val (wire-value bit)))
        (when bit-val
          (setf total (+ total (* bit-val power)))))
      (setf sum-lc (lc-add sum-lc (lc-scale (wire-to-lc bit) power)))
      (setf power (field-mul power 2)))
    (let ((out (circuit-allocate-wire circuit :value total)))
      ;; sum = out
      (circuit-add-constraint circuit
        (make-constraint
         :a (lc-sub sum-lc (wire-to-lc out))
         :b (wire-to-lc +wire-one+)
         :c (constant-lc 0)
         :name "pack-bits"))
      out)))

(defun gadget-unpack-bits (circuit wire num-bits)
  "Unpack a wire into boolean wires.
   Same as range-check but returns the bit wires."
  (gadget-range-check circuit wire num-bits))
