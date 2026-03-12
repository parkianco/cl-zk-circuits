# cl-zk-circuits

Pure Common Lisp zero-knowledge circuit construction library.

## Features

- **Zero dependencies** - completely standalone
- **R1CS representation** - Rank-1 Constraint System
- **Wire management** - public/private variables with linear combinations
- **Gadget library** - arithmetic, boolean, conditional, range checks
- **Circuit optimization** - deduplication, wire renumbering
- **Field arithmetic** - BN254 scalar field operations

## Installation

```bash
cd ~/common-lisp/
git clone https://github.com/parkianco/cl-zk-circuits.git
```

```lisp
(asdf:load-system :cl-zk-circuits)
```

## Quick Start

```lisp
(use-package :cl-zk-circuits)

;; Create a circuit
(defvar *circuit* (make-empty-circuit "example"))

;; Add inputs
(defvar *a* (circuit-add-input *circuit* :value 3 :name "a"))
(defvar *b* (circuit-add-input *circuit* :value 5 :name "b"))

;; Compute a * b
(defvar *c* (gadget-mul *circuit* *a* *b*))

;; Mark output
(circuit-add-output *circuit* *c*)

;; Get statistics
(circuit-stats *circuit*)
;; => (:WIRES 4 :PUBLIC-INPUTS 2 :PRIVATE-INPUTS 1 :CONSTRAINTS 1 ...)

;; Compile to R1CS
(defvar *r1cs* (compile-circuit *circuit* :optimize t))
```

## API Reference

### Field Arithmetic

```lisp
+field-prime+              ; BN254 scalar field prime
(field-add a b)            ; Addition
(field-mul a b)            ; Multiplication
(field-inv a)              ; Multiplicative inverse
(field-pow base exp)       ; Exponentiation
```

### Circuit Construction

```lisp
(make-empty-circuit name)           ; Create circuit
(circuit-add-input circuit ...)     ; Add public input
(circuit-allocate-wire circuit ...) ; Allocate private wire
(circuit-add-constraint circuit c)  ; Add constraint
(circuit-add-output circuit wire)   ; Mark output
```

### Gadgets

```lisp
;; Arithmetic
(gadget-add circuit a b)    ; a + b
(gadget-mul circuit a b)    ; a * b
(gadget-inv circuit a)      ; 1/a
(gadget-div circuit a b)    ; a/b

;; Boolean
(gadget-boolean circuit w)  ; Assert w ∈ {0,1}
(gadget-and circuit a b)    ; a AND b
(gadget-or circuit a b)     ; a OR b
(gadget-xor circuit a b)    ; a XOR b
(gadget-not circuit a)      ; NOT a

;; Conditionals
(gadget-conditional circuit cond then else)

;; Range
(gadget-range-check circuit wire bits)  ; Assert 0 ≤ wire < 2^bits
(gadget-pack-bits circuit bit-wires)    ; Combine bits to field element
(gadget-unpack-bits circuit wire bits)  ; Decompose to bits
```

### R1CS

```lisp
(compile-circuit circuit :optimize t)   ; Circuit → R1CS
(r1cs-satisfied-p r1cs wire-values)     ; Verify assignment
(r1cs-to-matrices r1cs)                 ; Export (A, B, C) matrices
```

## R1CS Format

Each constraint has form: A · B = C

Where A, B, C are linear combinations of wires. Wire assignments satisfy the system if all constraints hold.

## License

BSD-3-Clause. See [LICENSE](LICENSE).

## Author

Parkian Company LLC
