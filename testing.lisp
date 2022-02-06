(defun parse-type (decl)
  (if (member :signed decl)
      `(signed-byte ,(car decl))
      `(unsigned-byte ,(car decl))))

(defvar *op-info* (make-hash-table))

(defun parse-arglist (list)
  (loop for elem in list
        collecting (car elem) into names
        collecting (parse-type (cdr elem)) into types
        finally (return (values names types))))

(defun zip (&rest lists)
  (apply #'mapcar #'list lists))

(defmacro defop (name vars return &body body)  
  (multiple-value-bind (in-names in-types) (parse-arglist vars)
    (multiple-value-bind (out-names out-types) (parse-arglist return)
      (progn
        (setf (gethash name *op-info*)
              (list (zip in-names in-types) (zip out-names out-types)))
        `(progn
           (declaim (ftype (function ,in-types (values ,@out-types)) ,name))
           (defun ,name ,(mapcar (lambda (string) (intern (string-upcase string))) in-names) ,@body))))))

(defun edge-values (type)
  (ecase (first type)
    (unsigned-byte
     (delete-duplicates (list 0 1 (1- (ash 1 (second type))))))
    (signed-byte
     (delete-duplicates (list 0 1 -1 (1- (ash 1 (1- (second type)))) (- (ash 1 (1- (second type)))))))))

(defun product (lists)
  (if (null lists)
      '(())
      (loop for x in (car lists)
            nconc (loop for y in (product (cdr lists))
                        collecting (cons x y)))))

(defun type->bits (type)
  (ecase (first type)
    (unsigned-byte (second type))
    (signed-byte (second type))))

(defun random-in-range (type)
  (ecase (first type)
    (unsigned-byte (random (1- (ash 1 (second type)))))
    (signed-byte (- (random (1- (ash 1 (second type))))
                    (ash 1 (1- (second type)))))))

(defun generate-tests (name n)
  (destructuring-bind (ins outs) (gethash name *op-info*)
    (format t "# Generated test vector for ~s.~%" name)
    (format t "~{~a~^ ~}~%"
            (loop for (name type) in (append ins outs)
                  collecting (with-output-to-string (s)
                               (let ((bits (type->bits type)))
                                 (if (= 1 bits)
                                     (format s "~a" name)
                                     (format s "~a[~d]" name bits))))))
    (format t "# Edge cases.~%")
    (dolist (vals (product (mapcar (lambda (in) (edge-values (second in))) ins)))
      (format t "~{~d~^ ~}~%" (append vals (multiple-value-list (apply name vals)))))
    (format t "# Random tests (N=~d).~%" n)
    (dotimes (_ n)
      (let ((vals (loop for (name type) in ins
                        collecting (random-in-range type))))
        (format t "~{~d~^ ~}~%" (append vals (multiple-value-list (apply name vals)))))))))

(defun generate-test-file (name n filename)
  (with-open-file (stream filename :direction :output)
    (let ((*standard-output* stream))
      (generate-tests name n))))

(defop left-shift-32-bit (("B" 32) ("Sa" 5) ("Cin" 1)) (("C" 32))
  (logior (logand (1- (ash 1 32))
                  (ash b sa))
          (* cin (1- (ash 1 sa)))))

;;; kind of stupid that it is this complicated - could be wrong
(defop signed-add-32-bit (("A" 32 :signed) ("B" 32 :signed) ("Cin" 1)) (("C" 32 :signed) ("V" 1))
  (let ((sum (+ a b cin)))
    (cond
      ((>= sum (ash 1 31))
       (values (- (logand (1- (ash 1 31)) sum) (ash 1 31)) 1))
      ((< sum (- (ash 1 31)))
       (values (let ((x (- (ash 1 31) (logand (1- (ash 1 31)) (- sum)))))
                 (if (= x (ash 1 31))
                     0
                     x))
               1))
      (t (values sum 0)))))
