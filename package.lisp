;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: BSD-3-Clause
;;;;
;;;; Package definition for cl-zk-circuits

(defpackage #:cl-zk-circuits
  (:use #:cl)
  (:nicknames #:zk-circuits)
  (:export
   ;; Field arithmetic
   #:+field-prime+
   #:field-add
   #:field-sub
   #:field-mul
   #:field-inv
   #:field-div
   #:field-neg
   #:field-pow
   #:field-sqrt

   ;; Wires
   #:wire
   #:make-wire
   #:wire-id
   #:wire-value
   #:wire-public-p
   #:wire-name
   #:+wire-one+
   #:wire-equal

   ;; Wire sets
   #:wire-set
   #:make-wire-set
   #:wire-set-add
   #:wire-set-get
   #:wire-set-count
   #:wire-set-wires
   #:allocate-wire
   #:allocate-public-wire

   ;; Linear combinations
   #:lc
   #:make-lc
   #:lc-terms
   #:lc-constant
   #:lc-add
   #:lc-sub
   #:lc-scale
   #:lc-evaluate
   #:wire-to-lc
   #:constant-lc

   ;; Constraints
   #:constraint
   #:make-constraint
   #:constraint-a
   #:constraint-b
   #:constraint-c
   #:constraint-name
   #:constraint-satisfied-p

   ;; R1CS
   #:r1cs
   #:make-r1cs
   #:r1cs-constraints
   #:r1cs-num-inputs
   #:r1cs-num-aux
   #:r1cs-num-constraints
   #:r1cs-add-constraint
   #:r1cs-satisfied-p
   #:r1cs-to-matrices

   ;; Circuit builder
   #:circuit
   #:make-circuit
   #:circuit-wires
   #:circuit-constraints
   #:circuit-inputs
   #:circuit-outputs
   #:circuit-add-input
   #:circuit-add-output
   #:circuit-add-constraint
   #:circuit-allocate-wire
   #:circuit-to-r1cs

   ;; Gadgets
   #:gadget-add
   #:gadget-mul
   #:gadget-inv
   #:gadget-div
   #:gadget-boolean
   #:gadget-assert-zero
   #:gadget-assert-nonzero
   #:gadget-assert-equal
   #:gadget-conditional
   #:gadget-and
   #:gadget-or
   #:gadget-xor
   #:gadget-not
   #:gadget-less-than
   #:gadget-range-check
   #:gadget-pack-bits
   #:gadget-unpack-bits

   ;; Compiler
   #:compile-circuit
   #:optimize-circuit
   #:circuit-stats

   ;; Errors
   #:circuit-error
   #:constraint-violation-error
   #:wire-not-found-error))
