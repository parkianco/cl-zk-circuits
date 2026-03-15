;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-zk-circuits)

;;; Core types for cl-zk-circuits
(deftype cl-zk-circuits-id () '(unsigned-byte 64))
(deftype cl-zk-circuits-status () '(member :ready :active :error :shutdown))
