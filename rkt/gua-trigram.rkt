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
;;
;; 约定：
;;   - Trigram = { g : gua | (trigram? g) }。
;;   - 本模块的构造函数和 ensure 函数，都保证返回满足 trigram? 的 gua。
;; ============================================================

;; ------------------------------------------------------------
;; make-trigram-from-bits
;;
;; 签名：
;;   make-trigram-from-bits :
;;     (listof Bit) -> (and/c gua? trigram?)
;;   其中 Bit = 0 或 1。
;;
;; 功能：
;;   - 从自下而上的 3 位 0/1 列表构造一个三爻卦。
;;
;; 行为：
;;   - 若 bits-list 长度不是 3，则抛出错误。
;;   - 若元素中存在非 0/1 的值，将由 make-gua-from-bits 抛错。
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
;; 签名：
;;   make-trigram-from-int :
;;     exact-nonnegative-integer? -> (and/c gua? trigram?)
;;
;; 功能：
;;   - 从一个整数编码构造三爻卦，约定 width = 3。
;;
;; 行为：
;;   - 若 bits-int 超出 [0, 2^3 - 1] 区间，则由 make-gua-from-int 抛错。
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
;; 签名：
;;   ensure-trigram :
;;     gua? -> (and/c gua? trigram?)
;;
;; 功能：
;;   - 若给定 gua 已经是 width=3 的三爻卦，则原样返回；
;;   - 否则抛出错误。
;;
;; 用途：
;;   - 在通用代码中，当你逻辑上“期望”某个 gua 是 trigram 时，
;;     可用此函数将错误提前暴露。
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
;; 签名：
;;   trigram-duplicate->hexagram :
;;     (and/c gua? trigram?) -> (and/c gua? hexagram?)
;;
;; 功能：
;;   - 将一个三爻卦“复制一份”堆叠在上方，得到一个宽度为 6 的 gua。
;;   - 即：
;;       bits = lower.bits ++ lower.bits
;;     其中 lower 即输入的 trigram。
;;
;; 说明：
;;   - 返回值在结构上是 width=6 的 gua，因此满足 hexagram?。
;;   - 这里不关心卦名，只关心纯结构。
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
;; 自检：self-test
;;
;; 签名：
;;   self-test : -> void?
;;
;; 功能：
;;   - 对本模块的基本功能做快速验证：
;;       1. 三爻卦的构造（bits 和 int）。
;;       2. ensure-trigram 对正确/错误输入的行为。
;;       3. trigram-duplicate->hexagram 生成的六爻结构。
;; ------------------------------------------------------------
(define (self-test)
  ;; 1. 从 bits 构造：'(1 0 1)
  (define t1 (make-trigram-from-bits '(1 0 1)))
  (unless (and (trigram? t1)
               (= (gua-width t1) 3)
               (equal? (gua-bits-list t1) '(1 0 1)))
    (error 'self-test "make-trigram-from-bits failed"))

  ;; 2. 从 int 构造：0b101 = 5
  (define t2 (make-trigram-from-int 5))
  (unless (and (trigram? t2)
               (equal? (gua-bits-list t2) '(1 0 1)))
    (error 'self-test "make-trigram-from-int failed"))

  ;; 3. ensure-trigram 正常情况
  (define t3 (ensure-trigram t1))
  (unless (eq? t1 t3)
    (error 'self-test "ensure-trigram should return the same object for trigram"))

  ;; 4. ensure-trigram 错误情况（用六爻卦）
  (define h (make-gua-from-bits '(1 0 1 0 1 0)))
  (when (trigram? h)
    (error 'self-test "six-line gua should not be trigram"))
  (when (with-handlers ([exn:fail? (lambda (e) #f)])
          (ensure-trigram h))
    (error 'self-test "ensure-trigram should fail on hexagram"))

  ;; 5. trigram-duplicate->hexagram
  (define h2 (trigram-duplicate->hexagram t1))
  (unless (and (hexagram? h2)
               (= (gua-width h2) 6)
               (equal? (gua-bits-list h2) '(1 0 1 1 0 1)))
    (error 'self-test
           "trigram-duplicate->hexagram failed, got bits ~a"
           (gua-bits-list h2)))

  (displayln "gua-trigram self-test passed."))

;; ------------------------------------------------------------
;; 直接运行文件时，自动执行自测
;; ------------------------------------------------------------
(module+ main
  (self-test))

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
