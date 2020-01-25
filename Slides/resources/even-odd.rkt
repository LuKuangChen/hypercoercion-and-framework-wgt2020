#lang racket
(require pict)
(require pict/convert)
(require slideshow/code)
(require file/convertible)

(define even-odd-pict
  (vl-append
   (pict-height (code '()))
   (code (define (even [n : Dyn]) : Dyn
           (if (= n 0) #t (odd (- n 1)))))
   (code (define (odd [n : Int]) : Bool
           (if (= n 0) #f (even (- n 1)))))))

even-odd-pict

(write-bytes
 (convert even-odd-pict 'png-bytes)
 (open-output-file "even-odd.png"))