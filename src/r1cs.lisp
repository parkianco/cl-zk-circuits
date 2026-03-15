;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0
;;;;
;;;; R1CS (Rank-1 Constraint System) representation

(in-package #:cl-zk-circuits)

;;; ============================================================================
;;; R1CS Structure
;;; ============================================================================

(defstruct r1cs
  "Rank-1 Constraint System.
   Az ◦ Bz = Cz where z = (1, public_inputs, aux_inputs)."
  (constraints nil :type list)
  (num-inputs 0 :type integer)   ; Number of public inputs
  (num-aux 0 :type integer)      ; Number of auxiliary (private) wires
  (input-names nil :type list)   ; Names for public inputs
  (aux-names nil :type list))    ; Names for aux wires

(defun r1cs-num-constraints (r1cs)
  "Return number of constraints."
  (length (r1cs-constraints r1cs)))

(defun r1cs-add-constraint (r1cs constraint)
  "Add a constraint to the R1CS."
  (push constraint (r1cs-constraints r1cs))
  constraint)

;;; ============================================================================
;;; R1CS Verification
;;; ============================================================================

(defun r1cs-satisfied-p (r1cs wire-values)
  "Check if all constraints are satisfied."
  (dolist (constraint (r1cs-constraints r1cs) t)
    (unless (constraint-satisfied-p constraint wire-values)
      (return nil))))

(defun r1cs-check-with-errors (r1cs wire-values)
  "Check R1CS and return list of violated constraints."
  (let ((violations nil))
    (dolist (constraint (r1cs-constraints r1cs))
      (unless (constraint-satisfied-p constraint wire-values)
        (push constraint violations)))
    (nreverse violations)))

;;; ============================================================================
;;; R1CS to Matrix Form
;;; ============================================================================

(defun lc-to-sparse-row (lc num-wires)
  "Convert LC to sparse row representation.
   Returns list of (column . value) pairs."
  (declare (ignore num-wires))
  (let ((row nil))
    ;; Constant term goes to column 0 (wire one)
    (unless (zerop (lc-constant lc))
      (push (cons 0 (lc-constant lc)) row))
    ;; Variable terms
    (dolist (term (lc-terms lc))
      (push term row))
    (nreverse row)))

(defun r1cs-to-matrices (r1cs)
  "Convert R1CS to sparse matrix representation.
   Returns (A B C) where each is a list of sparse rows."
  (let* ((num-wires (+ 1 (r1cs-num-inputs r1cs) (r1cs-num-aux r1cs)))
         (a-matrix nil)
         (b-matrix nil)
         (c-matrix nil))
    (dolist (constraint (reverse (r1cs-constraints r1cs)))
      (push (lc-to-sparse-row (constraint-a constraint) num-wires) a-matrix)
      (push (lc-to-sparse-row (constraint-b constraint) num-wires) b-matrix)
      (push (lc-to-sparse-row (constraint-c constraint) num-wires) c-matrix))
    (values (nreverse a-matrix)
            (nreverse b-matrix)
            (nreverse c-matrix))))

;;; ============================================================================
;;; Circuit Structure
;;; ============================================================================

(defstruct circuit
  "High-level circuit representation."
  (wires nil :type (or null wire-set))
  (constraints nil :type list)
  (inputs nil :type list)      ; List of input wire IDs
  (outputs nil :type list)     ; List of output wire IDs
  (name nil :type (or null string)))

(defun make-empty-circuit (&optional name)
  "Create a new empty circuit."
  (let ((c (make-circuit :name name)))
    (setf (circuit-wires c) (make-wire-set))
    ;; Add the constant-one wire
    (wire-set-add (circuit-wires c) +wire-one+)
    c))

(defun circuit-add-input (circuit &key value name)
  "Add a public input to the circuit."
  (let ((wire (allocate-public-wire (circuit-wires circuit)
                                     :value value :name name)))
    (push (wire-id wire) (circuit-inputs circuit))
    wire))

(defun circuit-add-output (circuit wire)
  "Mark a wire as a circuit output."
  (push (wire-id wire) (circuit-outputs circuit))
  wire)

(defun circuit-add-constraint (circuit constraint)
  "Add a constraint to the circuit."
  (push constraint (circuit-constraints circuit))
  constraint)

(defun circuit-allocate-wire (circuit &key value name)
  "Allocate a private wire in the circuit."
  (allocate-wire (circuit-wires circuit) :value value :name name))

;;; ============================================================================
;;; Circuit to R1CS Conversion
;;; ============================================================================

(defun circuit-to-r1cs (circuit)
  "Convert circuit to R1CS representation."
  (let* ((wire-set (circuit-wires circuit))
         (num-public (wire-set-public-count wire-set))
         (num-total (wire-set-count wire-set))
         (num-aux (- num-total num-public 1)))  ; -1 for constant wire
    (make-r1cs
     :constraints (reverse (circuit-constraints circuit))
     :num-inputs num-public
     :num-aux num-aux)))
