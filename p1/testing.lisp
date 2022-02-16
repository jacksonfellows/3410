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
     (if (<= (second type) 4)
         (loop for n from 0 to (1- (ash 1 (second type))) collecting n)
         (delete-duplicates (list 0 1 (1- (ash 1 (second type)))))))
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
    (unsigned-byte (random (ash 1 (second type))))
    (signed-byte (- (random (ash 1 (second type)))
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
        (format t "~{~d~^ ~}~%" (append vals (multiple-value-list (apply name vals))))))))

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

(defun rev-bits (n n-bits)
  (dotimes (i (/ n-bits 2) n)
    (rotatef (ldb (byte 1 i) n) (ldb (byte 1 (- (1- n-bits) i)) n))))

(defop left-right-shift-32-bit (("B" 32) ("Sa" 5) ("left" 1) ("arith" 1)) (("C" 32))
  (if (= 1 left)
      (left-shift-32-bit b sa 0)
      (rev-bits
       (if (= 1 arith)
           (left-shift-32-bit (rev-bits b 32) sa (ash b -31))
           (left-shift-32-bit (rev-bits b 32) sa 0))
       32)))

(defop neg-32-bit (("B" 32 :signed)) (("C" 32 :signed) ("V" 1))
  (let ((res (- b)))
    (if (typep res '(signed-byte 32))
        (values res 0)
        (values (- res 1) 1))))

(defop add-sub-32-bit (("A" 32 :signed) ("B" 32 :signed) ("sub" 1)) (("C" 32) ("V" 1))
  (if (= sub 1)
      (multiple-value-bind (-b v) (neg-32-bit b)
        (signed-add-32-bit a -b v))
      (signed-add-32-bit a b 0)))

(defop cmp-32-bit (("A" 32 :signed) ("B" 32 :signed) ("eq_gt" 1) ("le_gt" 1)) (("C" 32))
  (if (if (= 1 eq_gt)
          (if (= 1 le_gt)
              ;; gt
              (> a 0)
              ;; eq
              (= a b)
              )
          (if (= 1 le_gt)
              ;; le
              (<= a 0)
              ;; ne
              (not (= a b))
              ))
      1
      0))

(defun to-signed (x)
  (if (= 1 (ldb (byte 1 31) x))
      (1- (- (logxor (1- (ash 1 32)) x)))
      x))

(defun from-signed (x)
  (if (< x 0)
      (1+ (logxor (1- (ash 1 32)) (- x)))
      x))

(defop alu-32-bit (("A" 32 :signed) ("B" 32 :signed) ("Op" 4) ("Sa" 5)) (("C" 32 :signed) ("V" 1))
  (let ((a_ (from-signed a))
        (b_ (from-signed b)))
    (ecase op
      (#b1001 (values (to-signed (logand a_ b_)) 0))
      (#b1000 (values (to-signed (logior a_ b_)) 0))
      ((#b1100 #b1101) (values (to-signed (left-right-shift-32-bit b_ sa 1 0)) 0))
      (#b0110 (values (to-signed (logxor a_ b_)) 0))
      (#b0111 (values (lognor a b) 0))
      (#b0000 (values (to-signed (left-right-shift-32-bit b_ sa 0 0)) 0))
      (#b0001 (values (to-signed (left-right-shift-32-bit b_ sa 0 1)) 0))
      (#b0100 (values (if (not (= a b)) 1 0) 0))
      (#b0101 (values (if (= a b) 1 0) 0))
      (#b0010 (values (if (<= a 0) 1 0) 0))
      (#b0011 (values (if (> a 0) 1 0) 0))
      ((#b1110 #b1111) (add-sub-32-bit a b 1))
      ((#b1010 #b1011) (add-sub-32-bit a b 0)))))
