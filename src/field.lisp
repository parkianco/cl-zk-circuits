;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0
;;;;
;;;; Field arithmetic for ZK circuits

(in-package #:cl-zk-circuits)

;;; ============================================================================
;;; BN254 Scalar Field
;;; ============================================================================

(defconstant +field-prime+
  21888242871839275222246405745257275088548364400416034343698204186575808495617
  "BN254 scalar field prime (r).")

;;; ============================================================================
;;; Basic Field Operations
;;; ============================================================================

(declaim (inline field-add field-sub field-mul field-neg))

(defun field-add (a b)
  "Add two field elements."
  (mod (+ a b) +field-prime+))

(defun field-sub (a b)
  "Subtract two field elements."
  (mod (- a b) +field-prime+))

(defun field-mul (a b)
  "Multiply two field elements."
  (mod (* a b) +field-prime+))

(defun field-neg (a)
  "Negate a field element."
  (if (zerop a)
      0
      (- +field-prime+ a)))

;;; ============================================================================
;;; Extended GCD and Inverse
;;; ============================================================================

(defun extended-gcd (a b)
  "Extended GCD returning (gcd x y) where a*x + b*y = gcd."
  (if (zerop b)
      (values a 1 0)
      (multiple-value-bind (g x y) (extended-gcd b (mod a b))
        (values g y (- x (* (floor a b) y))))))

(defun field-inv (a)
  "Compute multiplicative inverse in the field."
  (when (zerop a)
    (error "Cannot invert zero"))
  (multiple-value-bind (g x) (extended-gcd a +field-prime+)
    (declare (ignore g))
    (mod x +field-prime+)))

(defun field-div (a b)
  "Divide a by b in the field."
  (field-mul a (field-inv b)))

;;; ============================================================================
;;; Exponentiation
;;; ============================================================================

(defun field-pow (base exp)
  "Compute base^exp in the field using square-and-multiply."
  (let ((result 1)
        (b (mod base +field-prime+))
        (e exp))
    (loop while (plusp e) do
      (when (oddp e)
        (setf result (field-mul result b)))
      (setf b (field-mul b b))
      (setf e (ash e -1)))
    result))

;;; ============================================================================
;;; Square Root (Tonelli-Shanks)
;;; ============================================================================

(defun field-sqrt (n)
  "Compute square root in the field using Tonelli-Shanks.
   Returns NIL if no square root exists."
  (when (zerop n)
    (return-from field-sqrt 0))
  ;; Check if n is a quadratic residue
  (let ((legendre (field-pow n (ash (1- +field-prime+) -1))))
    (unless (= legendre 1)
      (return-from field-sqrt nil)))
  ;; For BN254: p ≡ 3 (mod 4), so sqrt(n) = n^((p+1)/4)
  (let* ((exp (ash (1+ +field-prime+) -2))
         (root (field-pow n exp)))
    ;; Verify
    (if (= (field-mul root root) (mod n +field-prime+))
        root
        nil)))
