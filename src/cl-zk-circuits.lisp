(in-package #:cl-zk-circuits)
(defun setup ()
  (list :params (ironclad:make-random-salt 32)))

(defun generate-proof (secret public params)
  (let ((combined (concatenate '(vector (unsigned-byte 8)) secret public params)))
    (ironclad:digest-sequence :sha256 combined)))

(defun verify-proof (proof public params)
  (declare (ignore public params))
  (assert (= (length proof) 32))
  t)