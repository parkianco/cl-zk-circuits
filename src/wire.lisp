;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0
;;;;
;;;; Wire (variable) representation for circuits

(in-package #:cl-zk-circuits)

;;; ============================================================================
;;; Wire Structure
;;; ============================================================================

(defstruct wire
  "A wire (variable) in a circuit."
  (id 0 :type integer)
  (value nil :type (or null integer))
  (public-p nil :type boolean)
  (name nil :type (or null string)))

(defvar +wire-one+
  (make-wire :id 0 :value 1 :public-p t :name "one")
  "The constant wire with value 1 (always wire 0).")

(defun wire-equal (w1 w2)
  "Check if two wires are the same."
  (= (wire-id w1) (wire-id w2)))

;;; ============================================================================
;;; Wire Set
;;; ============================================================================

(defstruct wire-set
  "Collection of wires in a circuit."
  (wires (make-hash-table) :type hash-table)
  (next-id 1 :type integer)
  (public-count 0 :type integer))

(defun wire-set-add (set wire)
  "Add a wire to the set."
  (setf (gethash (wire-id wire) (wire-set-wires set)) wire)
  wire)

(defun wire-set-get (set id)
  "Get wire by ID."
  (gethash id (wire-set-wires set)))

(defun wire-set-count (set)
  "Total number of wires."
  (hash-table-count (wire-set-wires set)))

(defun allocate-wire (set &key value name)
  "Allocate a new private wire."
  (let* ((id (wire-set-next-id set))
         (wire (make-wire :id id :value value :name name)))
    (incf (wire-set-next-id set))
    (wire-set-add set wire)
    wire))

(defun allocate-public-wire (set &key value name)
  "Allocate a new public input wire."
  (let* ((id (wire-set-next-id set))
         (wire (make-wire :id id :value value :public-p t :name name)))
    (incf (wire-set-next-id set))
    (incf (wire-set-public-count set))
    (wire-set-add set wire)
    wire))

;;; ============================================================================
;;; Linear Combinations
;;; ============================================================================

(defstruct lc
  "Linear combination of wires: sum(coeff_i * wire_i) + constant."
  (terms nil :type list)  ; alist of (wire-id . coefficient)
  (constant 0 :type integer))

(defun wire-to-lc (wire &optional (coeff 1))
  "Create LC from a single wire with coefficient."
  (make-lc :terms (list (cons (wire-id wire) coeff))))

(defun constant-lc (value)
  "Create LC with just a constant."
  (make-lc :constant (mod value +field-prime+)))

(defun lc-add (lc1 lc2)
  "Add two linear combinations."
  (let ((new-terms nil)
        (terms-ht (make-hash-table)))
    ;; Accumulate terms from both LCs
    (dolist (term (lc-terms lc1))
      (incf (gethash (car term) terms-ht 0) (cdr term)))
    (dolist (term (lc-terms lc2))
      (incf (gethash (car term) terms-ht 0) (cdr term)))
    ;; Convert back to alist, removing zeros
    (maphash (lambda (wire-id coeff)
               (let ((c (mod coeff +field-prime+)))
                 (unless (zerop c)
                   (push (cons wire-id c) new-terms))))
             terms-ht)
    (make-lc :terms new-terms
             :constant (field-add (lc-constant lc1) (lc-constant lc2)))))

(defun lc-sub (lc1 lc2)
  "Subtract lc2 from lc1."
  (lc-add lc1 (lc-scale lc2 (field-neg 1))))

(defun lc-scale (lc scalar)
  "Scale all terms and constant by scalar."
  (let ((s (mod scalar +field-prime+)))
    (make-lc
     :terms (mapcar (lambda (term)
                      (cons (car term) (field-mul (cdr term) s)))
                    (lc-terms lc))
     :constant (field-mul (lc-constant lc) s))))

(defun lc-evaluate (lc wire-values)
  "Evaluate LC given wire values (hash-table: wire-id -> value)."
  (let ((result (lc-constant lc)))
    (dolist (term (lc-terms lc))
      (let* ((wire-id (car term))
             (coeff (cdr term))
             (value (gethash wire-id wire-values 0)))
        (setf result (field-add result (field-mul coeff value)))))
    result))
