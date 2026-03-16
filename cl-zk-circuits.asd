(asdf:defsystem #:cl-zk-circuits
  :depends-on (#:ironclad #:nibbles)
  :components ((:module "src"
                :components ((:file "package")
                             (:file "cl-zk-circuits" :depends-on ("package"))))))