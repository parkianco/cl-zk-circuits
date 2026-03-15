;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0
;;;;
;;;; Circuit compiler and optimizer

(in-package #:cl-zk-circuits)

;;; ============================================================================
;;; Circuit Statistics
;;; ============================================================================

(defun circuit-stats (circuit)
  "Return statistics about the circuit."
  (let* ((wire-set (circuit-wires circuit))
         (constraints (circuit-constraints circuit))
         (num-wires (wire-set-count wire-set))
         (num-public (wire-set-public-count wire-set))
         (num-constraints (length constraints))
         (num-inputs (length (circuit-inputs circuit)))
         (num-outputs (length (circuit-outputs circuit))))
    (list :wires num-wires
          :public-inputs num-public
          :private-inputs (- num-wires num-public 1)  ; -1 for constant
          :constraints num-constraints
          :inputs num-inputs
          :outputs num-outputs)))

;;; ============================================================================
;;; Constraint Deduplication
;;; ============================================================================

(defun lc-signature (lc)
  "Create a signature for LC (for deduplication)."
  (let ((terms (sort (copy-list (lc-terms lc)) #'< :key #'car)))
    (list (lc-constant lc) terms)))

(defun constraint-signature (constraint)
  "Create a signature for constraint deduplication."
  (list (lc-signature (constraint-a constraint))
        (lc-signature (constraint-b constraint))
        (lc-signature (constraint-c constraint))))

(defun deduplicate-constraints (constraints)
  "Remove duplicate constraints."
  (let ((seen (make-hash-table :test 'equal))
        (result nil))
    (dolist (c constraints)
      (let ((sig (constraint-signature c)))
        (unless (gethash sig seen)
          (setf (gethash sig seen) t)
          (push c result))))
    (nreverse result)))

;;; ============================================================================
;;; Wire Renumbering
;;; ============================================================================

(defun collect-used-wires (constraints)
  "Collect all wire IDs used in constraints."
  (let ((used (make-hash-table)))
    ;; Wire 0 is always used (constant one)
    (setf (gethash 0 used) t)
    (dolist (c constraints)
      (dolist (lc (list (constraint-a c) (constraint-b c) (constraint-c c)))
        (dolist (term (lc-terms lc))
          (setf (gethash (car term) used) t))))
    used))

(defun build-wire-map (used-wires public-wires)
  "Build mapping from old wire IDs to new consecutive IDs.
   Wire 0 stays 0, public wires come next, then private."
  (let ((wire-map (make-hash-table))
        (next-public 1)
        (private-wires nil))
    ;; Wire 0 maps to 0
    (setf (gethash 0 wire-map) 0)
    ;; Map public wires first
    (dolist (w public-wires)
      (when (gethash w used-wires)
        (setf (gethash w wire-map) next-public)
        (incf next-public)))
    ;; Collect private wires
    (maphash (lambda (w v)
               (declare (ignore v))
               (unless (or (= w 0) (member w public-wires))
                 (push w private-wires)))
             used-wires)
    ;; Map private wires
    (let ((next-private next-public))
      (dolist (w (sort private-wires #'<))
        (setf (gethash w wire-map) next-private)
        (incf next-private)))
    wire-map))

(defun remap-lc (lc wire-map)
  "Remap wire IDs in a linear combination."
  (make-lc
   :terms (mapcar (lambda (term)
                    (cons (gethash (car term) wire-map (car term))
                          (cdr term)))
                  (lc-terms lc))
   :constant (lc-constant lc)))

(defun remap-constraint (constraint wire-map)
  "Remap wire IDs in a constraint."
  (make-constraint
   :a (remap-lc (constraint-a constraint) wire-map)
   :b (remap-lc (constraint-b constraint) wire-map)
   :c (remap-lc (constraint-c constraint) wire-map)
   :name (constraint-name constraint)))

;;; ============================================================================
;;; Circuit Optimization
;;; ============================================================================

(defun optimize-circuit (circuit)
  "Optimize circuit by removing duplicates and renumbering wires.
   Returns new circuit."
  (let* ((constraints (circuit-constraints circuit))
         ;; Remove duplicates
         (deduped (deduplicate-constraints constraints))
         ;; Find used wires
         (used (collect-used-wires deduped))
         ;; Build wire map
         (wire-map (build-wire-map used (circuit-inputs circuit)))
         ;; Remap constraints
         (remapped (mapcar (lambda (c) (remap-constraint c wire-map))
                           deduped)))
    ;; Build new circuit
    (let ((new-circuit (make-circuit :name (circuit-name circuit))))
      (setf (circuit-wires new-circuit) (circuit-wires circuit))
      (setf (circuit-constraints new-circuit) remapped)
      (setf (circuit-inputs new-circuit)
            (mapcar (lambda (w) (gethash w wire-map w))
                    (circuit-inputs circuit)))
      (setf (circuit-outputs new-circuit)
            (mapcar (lambda (w) (gethash w wire-map w))
                    (circuit-outputs circuit)))
      new-circuit)))

;;; ============================================================================
;;; Circuit Compilation
;;; ============================================================================

(defun compile-circuit (circuit &key optimize)
  "Compile circuit to R1CS.
   If optimize is true, performs optimization passes first."
  (let ((c (if optimize (optimize-circuit circuit) circuit)))
    (circuit-to-r1cs c)))

;;; ============================================================================
;;; Circuit Validation
;;; ============================================================================

(defun validate-circuit (circuit)
  "Validate circuit structure. Returns list of issues or NIL if valid."
  (let ((issues nil))
    ;; Check for empty circuit
    (when (null (circuit-constraints circuit))
      (push "Circuit has no constraints" issues))
    ;; Check for no inputs
    (when (null (circuit-inputs circuit))
      (push "Circuit has no inputs" issues))
    ;; Check for undefined wires in constraints
    (let ((defined (make-hash-table)))
      (setf (gethash 0 defined) t)  ; Constant wire
      (maphash (lambda (id wire)
                 (declare (ignore wire))
                 (setf (gethash id defined) t))
               (wire-set-wires (circuit-wires circuit)))
      (dolist (c (circuit-constraints circuit))
        (dolist (lc (list (constraint-a c) (constraint-b c) (constraint-c c)))
          (dolist (term (lc-terms lc))
            (unless (gethash (car term) defined)
              (push (format nil "Undefined wire ~a in constraint ~a"
                            (car term) (constraint-name c))
                    issues))))))
    (nreverse issues)))
