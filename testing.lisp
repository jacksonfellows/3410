(defun bits->type (n-bits)
  `(unsigned-byte ,n-bits))

(defvar *op-info* (make-hash-table))

(defmacro defop (name vars return &body body)
  (multiple-value-bind (names types)
      (loop for (name bits) in vars
            collecting name into names
            collecting (bits->type bits) into types
            finally (return (values names types)))
    (destructuring-bind (return-name return-bits) return
      (progn
        (setf (gethash name *op-info*)
              (list vars return))
        `(progn
           (declaim (ftype (function ,types ,(bits->type return-bits)) ,name))
           (defun ,name ,(mapcar (lambda (string) (intern (string-upcase string))) names) ,@body))))))

(defun edge-values (n-bits)
  (delete-duplicates (list 0 1 (1- (expt 2 n-bits)))))

(defun product (lists)
  (if (null lists)
      '(())
      (loop for x in (car lists)
            nconc (loop for y in (product (cdr lists))
                        collecting (cons x y)))))

(defun generate-tests (name n)
  (destructuring-bind (vars return) (gethash name *op-info*)
    (format t "# Generated test vector for ~s.~%" name)
    (format t "~{~a~^ ~}~%"
            (loop for (name bits) in (append vars (list return))
                  collecting (with-output-to-string (s)
                               (if (= 1 bits)
                                   (format s "~a" name)
                                   (format s "~a[~d]" name bits)))))
    (format t "# Edge cases.~%")
    (dolist (vals (product (mapcar (lambda (var) (edge-values (second var))) vars)))
      (let ((expected (apply name vals)))
        (format t "~{0x~x~^ ~} 0x~x~%" vals expected)))
    (format t "# Random tests (N=~d).~%" n)
    (dotimes (_ n)
      (let* ((vals (loop for (name bits) in vars
                         collecting (random (expt 2 bits))))
             (expected (apply name vals)))
        (format t "~{0x~x~^ ~} 0x~x~%" vals expected)))))

(defun generate-test-file (name n filename)
  (with-open-file (stream filename :direction :output)
    (let ((*standard-output* stream))
      (generate-tests name n))))

(defop left-shift-32-bit (("B" 32) ("Sa" 5) ("Cin" 1)) ("C" 32)
  (logior (logand (1- (expt 2 32))
                  (ash b sa))
          (* cin (1- (expt 2 sa)))))
