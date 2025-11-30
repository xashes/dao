#lang racket

(require racket/contract
         "gua-core.rkt"
         "gua-core-operations.rkt"
         "gua-trigram.rkt")

;; ============================================================
;; 模块：gua-hexagram.rkt
;;
;; 目标：
;;   - 在统一的 gua 结构基础上，为“六爻卦”提供一层结构运算视图。
;;   - 不引入新的 struct，仅通过 width = 6 的约束识别 hexagram。
;; ============================================================

;; ------------------------------------------------------------
;; make-hexagram-from-bits
;;
;;   make-hexagram-from-bits :
;;     (listof Bit) -> (and/c gua? hexagram?)
;;   其中 Bit = 0 或 1。
;;
;; 功能：
;;   - 从自下而上的 6 位 0/1 列表构造一个六爻卦。
;; ------------------------------------------------------------
(define (make-hexagram-from-bits bits-list)
  (unless (= (length bits-list) 6)
    (error 'make-hexagram-from-bits
           "hexagram must have exactly 6 bits, got length ~a (~a)"
           (length bits-list) bits-list))
  (define g (make-gua-from-bits bits-list))
  (unless (hexagram? g)
    (error 'make-hexagram-from-bits
           "constructed gua is not hexagram, width=~a"
           (gua-width g)))
  g)

;; ------------------------------------------------------------
;; make-hexagram-from-int
;;
;;   make-hexagram-from-int :
;;     exact-nonnegative-integer? -> (and/c gua? hexagram?)
;;
;; 功能：
;;   - 从一个整数编码构造六爻卦，约定 width = 6。
;; ------------------------------------------------------------
(define (make-hexagram-from-int bits-int)
  (define g (make-gua-from-int bits-int 6))
  (unless (hexagram? g)
    (error 'make-hexagram-from-int
           "constructed gua is not hexagram, width=~a"
           (gua-width g)))
  g)

;; ------------------------------------------------------------
;; ensure-hexagram
;;
;;   ensure-hexagram :
;;     gua? -> (and/c gua? hexagram?)
;;
;; 功能：
;;   - 若给定 gua 已是六爻卦（width=6），则原样返回；
;;   - 否则抛出错误。
;; ------------------------------------------------------------
(define (ensure-hexagram g)
  (unless (hexagram? g)
    (error 'ensure-hexagram
           "expected hexagram (width=6), got width=~a"
           (gua-width g)))
  g)

;; ------------------------------------------------------------
;; hexagram-split
;;
;;   hexagram-split :
;;     (and/c gua? hexagram?)
;;     -> (values (and/c gua? trigram?)
;;                (and/c gua? trigram?))
;;
;; 功能：
;;   - 将一个六爻卦拆分为“下卦”和“上卦”两个三爻卦。
;; ------------------------------------------------------------
(define (hexagram-split g-hex)
  (define g (ensure-hexagram g-hex))
  (define bits (gua-bits-list g))
  (define lower (make-trigram-from-bits (take bits 3)))
  (define upper (make-trigram-from-bits (drop bits 3)))
  (values lower upper))

;; ------------------------------------------------------------
;; hexagram-join
;;
;;   hexagram-join :
;;     (and/c gua? trigram?) × (and/c gua? trigram?)
;;     -> (and/c gua? hexagram?)
;;
;; 功能：
;;   - 由下卦和上卦两个 trigram 组合成一个六爻卦：
;;       bits = lower.bits ++ upper.bits
;; ------------------------------------------------------------
(define (hexagram-join lower upper)
  (define l (ensure-trigram lower))
  (define u (ensure-trigram upper))
  (define bits (append (gua-bits-list l) (gua-bits-list u)))
  (define g (make-hexagram-from-bits bits))
  g)

;; ------------------------------------------------------------
;; hexagram-mutual  （互卦）
;;
;;   hexagram-mutual :
;;     (and/c gua? hexagram?) -> (and/c gua? hexagram?)
;;
;; 结构规则（本实现约定）：
;;   - 若原 bits = '(b0 b1 b2 b3 b4 b5)，则：
;;       下互卦：'(b1 b2 b3)  ; 取 2~4 爻
;;       上互卦：'(b2 b3 b4)  ; 取 3~5 爻
;;   - 再把这两个 trigram 组合成新的 hexagram。
;; ------------------------------------------------------------
(define (hexagram-mutual g-hex)
  (define g (ensure-hexagram g-hex))
  (define bits (gua-bits-list g))
  (define lower (make-trigram-from-bits (list (list-ref bits 1)
                                              (list-ref bits 2)
                                              (list-ref bits 3))))
  (define upper (make-trigram-from-bits (list (list-ref bits 2)
                                              (list-ref bits 3)
                                              (list-ref bits 4))))
  (hexagram-join lower upper))

;; ------------------------------------------------------------
;; hexagram-changing  （变卦：按指定爻位翻转）
;;
;;   hexagram-changing :
;;     (and/c gua? hexagram?) × (listof exact-nonnegative-integer?)
;;     -> (and/c gua? hexagram?)
;;
;; 功能：
;;   - 将给定六爻卦中，指定位置的爻统统翻转（0->1 / 1->0），得到变卦。
;;
;; 说明：
;;   - 结构上是对六爻卦的 flip-yaos。
;;   - 之所以保留 hexagram-changing 这个名字，是为了对应传统“变卦”语义，
;;     但真正的位操作逻辑放在 gua-core-operations.rkt 的 flip-yaos 中。
;; ------------------------------------------------------------
(define (hexagram-changing g-hex changing-lines)
  (define g (ensure-hexagram g-hex))
  (define g2 (flip-yaos g changing-lines))
  (ensure-hexagram g2))

;; ------------------------------------------------------------
;; 对外导出及其 contract
;; ------------------------------------------------------------
(provide
  (contract-out
   [make-hexagram-from-bits
    (-> (listof (or/c 0 1)) (and/c gua? hexagram?))]
   [make-hexagram-from-int
    (-> exact-nonnegative-integer? (and/c gua? hexagram?))]
   [ensure-hexagram
    (-> gua? (and/c gua? hexagram?))]
   [hexagram-split
    (-> (and/c gua? hexagram?)
        (values (and/c gua? trigram?)
                (and/c gua? trigram?)))]
   [hexagram-join
    (-> (and/c gua? trigram?)
        (and/c gua? trigram?)
        (and/c gua? hexagram?))]
   [hexagram-mutual
    (-> (and/c gua? hexagram?) (and/c gua? hexagram?))]
   [hexagram-changing
    (-> (and/c gua? hexagram?)
        (listof exact-nonnegative-integer?)
        (and/c gua? hexagram?))]))

;; ============================================================
;; 测试：module+ test + rackunit
;;   raco test gua-hexagram.rkt
;; ============================================================

(module+ test
  (require rackunit)

  ;; 1. 从 bits 构造
  (test-case
   "hexagram: make from bits"
   (define h1 (make-hexagram-from-bits '(1 0 1 0 1 0)))
   (check-true (hexagram? h1))
   (check-equal? (gua-width h1) 6)
   (check-equal? (gua-bits-list h1) '(1 0 1 0 1 0)))

  ;; 2. 从 int 构造：1 + 4 + 16 = 21
  (test-case
   "hexagram: make from int"
   (define h2 (make-hexagram-from-int 21))
   (check-equal? (gua-bits-list h2) '(1 0 1 0 1 0)))

  ;; 3. ensure-hexagram 正常 & 错误情况
  (test-case
   "hexagram: ensure-hexagram ok and fail"
   (define h1 (make-hexagram-from-bits '(1 0 1 0 1 0)))
   (define h3 (ensure-hexagram h1))
   (check-eq? h1 h3)
   (define t (make-trigram-from-bits '(1 0 1)))
   (check-exn exn:fail? (λ () (ensure-hexagram t))))

  ;; 4. 拆分 & 组合
  (test-case
   "hexagram: split and join"
   (define h1 (make-hexagram-from-bits '(1 0 1 0 1 0)))
   (define-values (lower upper) (hexagram-split h1))
   (check-true (trigram? lower))
   (check-true (trigram? upper))
   (check-equal? (gua-bits-list lower) '(1 0 1))
   (check-equal? (gua-bits-list upper) '(0 1 0))
   (define h4 (hexagram-join lower upper))
   (check-equal? (gua-bits-list h4) (gua-bits-list h1)))

  ;; 5. 互卦
  (test-case
   "hexagram: mutual"
   (define h1 (make-hexagram-from-bits '(1 0 1 0 1 0)))
   ;; 原 bits = '(1 0 1 0 1 0)
   ;;   下互卦 = '(0 1 0)  ; b1 b2 b3
   ;;   上互卦 = '(1 0 1)  ; b2 b3 b4
   ;;   合成 = '(0 1 0 1 0 1)
   (define h-mut (hexagram-mutual h1))
   (check-equal? (gua-bits-list h-mut) '(0 1 0 1 0 1)))

  ;; 6. 变卦：指定动爻翻转（使用 hexagram-changing，内部用 flip-yaos）
  (test-case
   "hexagram: changing lines"
   (define h1 (make-hexagram-from-bits '(1 0 1 0 1 0)))
   ;; 动 0、2、5：
   ;;   0: 1 -> 0
   ;;   2: 1 -> 0
   ;;   5: 0 -> 1
   ;; 结果应 = '(0 0 0 0 1 1)
   (define h-chg (hexagram-changing h1 '(0 2 5)))
   (check-equal? (gua-bits-list h-chg) '(0 0 0 0 1 1))))
