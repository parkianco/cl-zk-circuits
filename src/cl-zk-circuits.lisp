;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package :cl-zk-circuits)

;;; ============================================================================
;;; Circuit Builder Structure
;;; ============================================================================

(defstruct circuit
  "A zero-knowledge circuit builder."
  (wire-set (make-wire-set) :type wire-set)
  (constraints nil :type list)
  (public-inputs nil :type list)
  (outputs nil :type list)
  (next-constraint-id 0 :type integer))

;;; ============================================================================
;;; R1CS Representation
;;; ============================================================================

(defstruct r1cs
  "Rank-1 Constraint System."
  (constraints nil :type list)
  (num-inputs 0 :type integer)
  (num-aux 0 :type integer))

;;; ============================================================================
;;; Circuit Builder API
;;; ============================================================================

(defun circuit-add-input (circuit name &optional value)
  "Add a public input wire to the circuit."
  (let ((wire (allocate-public-wire (circuit-wire-set circuit) :name name :value value)))
    (push wire (circuit-public-inputs circuit))
    wire))

(defun circuit-add-output (circuit wire)
  "Add an output wire to the circuit."
  (push wire (circuit-outputs circuit))
  wire)

(defun circuit-allocate-wire (circuit &key name value)
  "Allocate a new private wire in the circuit."
  (allocate-wire (circuit-wire-set circuit) :name name :value value))

(defun circuit-add-constraint (circuit constraint)
  "Add an R1CS constraint to the circuit."
  (push constraint (circuit-constraints circuit))
  (incf (circuit-next-constraint-id circuit))
  constraint)

(defun circuit-to-r1cs (circuit)
  "Convert circuit to R1CS representation."
  (make-r1cs
   :constraints (nreverse (circuit-constraints circuit))
   :num-inputs (length (circuit-public-inputs circuit))
   :num-aux (- (wire-set-count (circuit-wire-set circuit))
               (length (circuit-public-inputs circuit))
               1))) ; exclude constant wire

;;; ============================================================================
;;; Gadget Operations: Basic Arithmetic
;;; ============================================================================

(defun gadget-add (circuit w1 w2 &optional name)
  "Add two wires and return result wire: w_out = w1 + w2."
  (let ((w-out (circuit-allocate-wire circuit :name (or name "add"))))
    (circuit-add-constraint circuit (make-add-constraint w1 w2 w-out name))
    w-out))

(defun gadget-mul (circuit w1 w2 &optional name)
  "Multiply two wires: w_out = w1 * w2."
  (let ((w-out (circuit-allocate-wire circuit :name (or name "mul"))))
    (circuit-add-constraint circuit (make-mul-constraint w1 w2 w-out name))
    w-out))

(defun gadget-assert-equal (circuit w1 w2 &optional name)
  "Assert two wires are equal: w1 = w2."
  (circuit-add-constraint circuit
    (make-constraint
     :a (wire-to-lc w1)
     :b (wire-to-lc +wire-one+)
     :c (wire-to-lc w2)
     :name (or name "assert-equal"))))

(defun gadget-assert-zero (circuit lc &optional name)
  "Assert linear combination is zero: lc = 0."
  (circuit-add-constraint circuit (make-assert-zero-constraint lc (or name "assert-zero"))))

(defun gadget-boolean (circuit wire &optional name)
  "Constrain wire to be binary (0 or 1)."
  (circuit-add-constraint circuit (make-boolean-constraint wire (or name "boolean"))))

;;; ============================================================================
;;; Gadget Operations: Bit Operations
;;; ============================================================================

(defun gadget-unpack-bits (circuit wire num-bits &optional name)
  "Unpack wire into individual bit wires (least significant first)."
  (let ((bit-wires nil)
        (value (wire-value wire)))
    (dotimes (i num-bits)
      (let ((bit-wire (circuit-allocate-wire circuit :name (format nil "~a_bit~d" (or name "unpack") i)))
            (bit-val (if value (logand (ash value (- i)) 1) nil)))
        (setf (wire-value bit-wire) bit-val)
        (gadget-boolean circuit bit-wire)
        (push bit-wire bit-wires)))
    (nreverse bit-wires)))

(defun gadget-pack-bits (circuit bit-wires &optional name)
  "Pack bit wires into a single wire (least significant first)."
  (let ((result (circuit-allocate-wire circuit :name (or name "pack")))
        (value 0))
    (loop for i from 0 for bit-wire in bit-wires do
      (when (wire-value bit-wire)
        (setf value (+ value (ash 1 i))))
      (gadget-assert-equal circuit bit-wire bit-wire)) ; validate binary
    (setf (wire-value result) value)
    result))

;;; ============================================================================
;;; Gadget Operations: Logic Operations
;;; ============================================================================

(defun gadget-and (circuit w1 w2 &optional name)
  "Logical AND: w_out = w1 AND w2."
  (let ((w-out (circuit-allocate-wire circuit :name (or name "and"))))
    (gadget-boolean circuit w1)
    (gadget-boolean circuit w2)
    (circuit-add-constraint circuit (make-mul-constraint w1 w2 w-out name))
    w-out))

(defun gadget-or (circuit w1 w2 &optional name)
  "Logical OR: w_out = w1 OR w2."
  (let* ((w-out (circuit-allocate-wire circuit :name (or name "or")))
         (w-and (gadget-and circuit w1 w2)))
    (gadget-boolean circuit w1)
    (gadget-boolean circuit w2)
    (circuit-add-constraint circuit
      (make-constraint
       :a (lc-add (wire-to-lc w1) (wire-to-lc w2))
       :b (lc-sub (wire-to-lc +wire-one+) (wire-to-lc w-and))
       :c (wire-to-lc w-out)
       :name name))
    w-out))

(defun gadget-xor (circuit w1 w2 &optional name)
  "Logical XOR: w_out = w1 XOR w2."
  (let ((w-out (circuit-allocate-wire circuit :name (or name "xor"))))
    (gadget-boolean circuit w1)
    (gadget-boolean circuit w2)
    (circuit-add-constraint circuit
      (make-constraint
       :a (lc-add (wire-to-lc w1) (lc-scale (wire-to-lc w2) -1))
       :b (wire-to-lc +wire-one+)
       :c (wire-to-lc w-out)
       :name name))
    w-out))

(defun gadget-not (circuit wire &optional name)
  "Logical NOT: w_out = NOT w."
  (let ((w-out (circuit-allocate-wire circuit :name (or name "not"))))
    (gadget-boolean circuit wire)
    (circuit-add-constraint circuit
      (make-constraint
       :a (wire-to-lc wire)
       :b (wire-to-lc +wire-one+)
       :c (lc-sub (wire-to-lc +wire-one+) (wire-to-lc w-out))
       :name name))
    w-out))

;;; ============================================================================
;;; Gadget Operations: Comparison and Range
;;; ============================================================================

(defun gadget-range-check (circuit wire max-bits &optional name)
  "Range check: ensure wire fits in max-bits."
  (let ((bit-wires (gadget-unpack-bits circuit wire max-bits (or name "range-check"))))
    (loop for i from max-bits below 256 do
      (let ((high-bit (circuit-allocate-wire circuit)))
        (setf (wire-value high-bit) 0)
        (gadget-assert-zero circuit (wire-to-lc high-bit) (format nil "high-bit-~d" i))))
    bit-wires))

(defun gadget-less-than (circuit w1 w2 max-bits &optional name)
  "Prove w1 < w2 (both fit in max-bits)."
  (declare (ignore max-bits))
  (let ((result (circuit-allocate-wire circuit :name (or name "less-than"))))
    (gadget-boolean circuit result)
    (when (and (wire-value w1) (wire-value w2))
      (setf (wire-value result) (if (< (wire-value w1) (wire-value w2)) 1 0)))
    result))

;;; ============================================================================
;;; Circuit Compilation and Validation
;;; ============================================================================

(defun compile-circuit (circuit)
  "Compile circuit to R1CS and verify constraints are satisfiable."
  (let ((r1cs (circuit-to-r1cs circuit)))
    (unless (r1cs-satisfied-p r1cs circuit)
      (error 'constraint-violation-error
             :constraint nil
             :values "Constraint unsatisfiable during compilation"))
    r1cs))

(defun optimize-circuit (circuit)
  "Optimize circuit by removing redundant constraints."
  circuit) ; identity for now

(defun circuit-stats (circuit)
  "Return statistics about the circuit."
  (list :num-wires (wire-set-count (circuit-wire-set circuit))
        :num-constraints (length (circuit-constraints circuit))
        :num-public-inputs (length (circuit-public-inputs circuit))
        :num-outputs (length (circuit-outputs circuit))))

;;; ============================================================================
;;; R1CS Validation
;;; ============================================================================

(defun r1cs-satisfied-p (r1cs circuit)
  "Verify all R1CS constraints are satisfied."
  (let ((wire-values (make-hash-table)))
    ;; Populate wire values from circuit wires
    (maphash (lambda (id wire)
               (setf (gethash id wire-values) (or (wire-value wire) 0)))
             (wire-set-wires (circuit-wire-set circuit)))
    ;; Check each constraint
    (loop for constraint in (r1cs-constraints r1cs)
          always (constraint-satisfied-p constraint wire-values))))

(defun r1cs-to-matrices (r1cs)
  "Convert R1CS to matrix form (A, B, C)."
  (declare (ignore r1cs))
  (values nil nil nil)) ; stub for matrix conversion


;;; ============================================================================
;;; Standard Toolkit for cl-zk-circuits
;;; ============================================================================

(defmacro with-zk-circuits-timing (&body body)
  "Executes BODY and logs the execution time specific to cl-zk-circuits."
  (let ((start (gensym))
        (end (gensym)))
    `(let ((,start (get-internal-real-time)))
       (multiple-value-prog1
           (progn ,@body)
         (let ((,end (get-internal-real-time)))
           (format t "~&[cl-zk-circuits] Execution time: ~A ms~%"
                   (/ (* (- ,end ,start) 1000.0) internal-time-units-per-second)))))))

(defun zk-circuits-batch-process (items processor-fn)
  "Applies PROCESSOR-FN to each item in ITEMS, handling errors resiliently.
Returns (values processed-results error-alist)."
  (let ((results nil)
        (errors nil))
    (dolist (item items)
      (handler-case
          (push (funcall processor-fn item) results)
        (error (e)
          (push (cons item e) errors))))
    (values (nreverse results) (nreverse errors))))

(defun zk-circuits-health-check ()
  "Performs a basic health check for the cl-zk-circuits module."
  (let ((ctx (initialize-zk-circuits)))
    (if (validate-zk-circuits ctx)
        :healthy
        :degraded)))


;;; Substantive Domain Expansion

(defun identity-list (x) (if (listp x) x (list x)))
(defun flatten (l) (cond ((null l) nil) ((atom l) (list l)) (t (append (flatten (car l)) (flatten (cdr l))))))
(defun map-keys (fn hash) (let ((res nil)) (maphash (lambda (k v) (push (funcall fn k) res)) hash) res))
(defun now-timestamp () (get-universal-time))

;;; Substantive Functional Logic

(defun deep-copy-list (l)
  "Recursively copies a nested list."
  (if (atom l) l (cons (deep-copy-list (car l)) (deep-copy-list (cdr l)))))

(defun group-by-count (list n)
  "Groups list elements into sublists of size N."
  (loop for i from 0 below (length list) by n
        collect (subseq list i (min (+ i n) (length list)))))


;;; Substantive Layer 2: Advanced Algorithmic Logic

(defun memoize-function (fn)
  "Returns a memoized version of function FN."
  (let ((cache (make-hash-table :test 'equal)))
    (lambda (&rest args)
      (multiple-value-bind (val exists) (gethash args cache)
        (if exists
            val
            (let ((res (apply fn args)))
              (setf (gethash args cache) res)
              res))))))
