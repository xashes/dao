#lang racket

(require racket/contract
         "gua-core.rkt"
         "gua-core-operations.rkt")

;; ============================================================
;; 模块：gua-trigram.rkt
;;
;; 目标：
;;   - 在 gua 的统一结构之上，为“三爻卦”提供一层语义包装。
;;   - 不引入新的 struct 类型，仍然使用 gua；
;;     只是通过 width = 3 的约束，把一部分 gua 看作 trigram。
;; ============================================================

;; ------------------------------------------------------------
;; make-trigram-from-bits
;;
;;   make-trigram-from-bits :
;;     (listof Bit) -> (and/c gua? trigram?)
;;   其中 Bit = 0 或 1。
;;
;; 功能：
;;   - 从自下而上的 3 位 0/1 列表构造一个三爻卦。
;; ------------------------------------------------------------
(define (make-trigram-from-bits bits-list)
  (unless (= (length bits-list) 3)
    (error 'make-trigram-from-bits
           "trigram must have exactly 3 bits, got length ~a (~a)"
           (length bits-list) bits-list))
  (define g (make-gua-from-bits bits-list))
  (unless (trigram? g)
    (error 'make-trigram-from-bits
           "constructed gua is not trigram, width=~a"
           (gua-width g)))
  g)

;; ------------------------------------------------------------
;; make-trigram-from-int
;;
;;   make-trigram-from-int :
;;     exact-nonnegative-integer? -> (and/c gua? trigram?)
;;
;; 功能：
;;   - 从一个整数编码构造三爻卦，约定 width = 3。
;; ------------------------------------------------------------
(define (make-trigram-from-int bits-int)
  (define g (make-gua-from-int bits-int 3))
  (unless (trigram? g)
    (error 'make-trigram-from-int
           "constructed gua is not trigram, width=~a"
           (gua-width g)))
  g)

;; ------------------------------------------------------------
;; ensure-trigram
;;
;;   ensure-trigram :
;;     gua? -> (and/c gua? trigram?)
;;
;; 功能：
;;   - 若给定 gua 已经是 width=3 的三爻卦，则原样返回；
;;   - 否则抛出错误。
;; ------------------------------------------------------------
(define (ensure-trigram g)
  (unless (trigram? g)
    (error 'ensure-trigram
           "expected trigram (width=3), got width=~a"
           (gua-width g)))
  g)

;; ------------------------------------------------------------
;; trigram-duplicate->hexagram
;;
;;   trigram-duplicate->hexagram :
;;     (and/c gua? trigram?) -> (and/c gua? hexagram?)
;;
;; 功能：
;;   - 将一个三爻卦“复制一份”堆叠在上方，得到一个宽度为 6 的 gua：
;;       bits = lower.bits ++ lower.bits
;; ------------------------------------------------------------
(define (trigram-duplicate->hexagram g-tri)
  (define g (ensure-trigram g-tri))
  (define bits (gua-bits-list g))
  (define new-g (make-gua-from-bits (append bits bits)))
  (unless (hexagram? new-g)
    (error 'trigram-duplicate->hexagram
           "resulting gua is not hexagram, width=~a"
           (gua-width new-g)))
  new-g)

;; ------------------------------------------------------------
;; 对外导出及其 contract
;; ------------------------------------------------------------
(provide
  (contract-out
   [make-trigram-from-bits
    (-> (listof (or/c 0 1)) (and/c gua? trigram?))]
   [make-trigram-from-int
    (-> exact-nonnegative-integer? (and/c gua? trigram?))]
   [ensure-trigram
    (-> gua? (and/c gua? trigram?))]
   [trigram-duplicate->hexagram
    (-> (and/c gua? trigram?) (and/c gua? hexagram?))]))

;; ============================================================
;; 测试：module+ test + rackunit
;;   raco test gua-trigram.rkt
;; ============================================================

(module+ test
  (require rackunit)

  ;; 1. 从 bits 构造：'(1 0 1)
  (test-case
   "trigram: make from bits"
   (define t1 (make-trigram-from-bits '(1 0 1)))
   (check-true (trigram? t1))
   (check-equal? (gua-width t1) 3)
   (check-equal? (gua-bits-list t1) '(1 0 1)))

  ;; 2. 从 int 构造：0b101 = 5
  (test-case
   "trigram: make from int"
   (define t2 (make-trigram-from-int 5))
   (check-true (trigram? t2))
   (check-equal? (gua-bits-list t2) '(1 0 1)))

  ;; 3. ensure-trigram 正常情况
  (test-case
   "trigram: ensure-trigram on trigram"
   (define t1 (make-trigram-from-bits '(1 0 1)))
   (define t3 (ensure-trigram t1))
   (check-eq? t1 t3))

  ;; 4. ensure-trigram 错误情况（用六爻卦）
  (test-case
   "trigram: ensure-trigram fails on hexagram"
   (define h (make-gua-from-bits '(1 0 1 0 1 0)))
   (check-false (trigram? h))
   (check-exn exn:fail?
     (λ () (ensure-trigram h))))

  ;; 5. trigram-duplicate->hexagram
  (test-case
   "trigram: duplicate -> hexagram"
   (define t1 (make-trigram-from-bits '(1 0 1)))
   (define h2 (trigram-duplicate->hexagram t1))
   (check-true (hexagram? h2))
   (check-equal? (gua-width h2) 6)
   (check-equal? (gua-bits-list h2) '(1 0 1 1 0 1))))
