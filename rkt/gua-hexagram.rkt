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
;;
;; 约定：
;;   - Hexagram = { g : gua | (hexagram? g) }。
;;   - 本模块的构造/运算函数都保证输入输出满足 hexagram?（除非说明）。
;;   - 所有操作都是“结构上的”，不包含任何卦名/象义解释。
;; ============================================================

;; ------------------------------------------------------------
;; make-hexagram-from-bits
;;
;; 签名：
;;   make-hexagram-from-bits :
;;     (listof Bit) -> (and/c gua? hexagram?)
;;   其中 Bit = 0 或 1。
;;
;; 功能：
;;   - 从自下而上的 6 位 0/1 列表构造一个六爻卦。
;;
;; 行为：
;;   - 若 bits-list 长度不是 6，则抛出错误。
;;   - 若元素中存在非 0/1 的值，将由 make-gua-from-bits 抛错。
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
;; 签名：
;;   make-hexagram-from-int :
;;     exact-nonnegative-integer? -> (and/c gua? hexagram?)
;;
;; 功能：
;;   - 从一个整数编码构造六爻卦，约定 width = 6。
;;
;; 行为：
;;   - 若 bits-int 超出 [0, 2^6 - 1] 区间，则由 make-gua-from-int 抛错。
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
;; 签名：
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
;; 签名：
;;   hexagram-split :
;;     (and/c gua? hexagram?)
;;     -> (values (and/c gua? trigram?)
;;                (and/c gua? trigram?))
;;
;; 功能：
;;   - 将一个六爻卦拆分为“下卦”和“上卦”两个三爻卦。
;;   - 若 bits = '(b0 b1 b2 b3 b4 b5)：
;;       下卦：'(b0 b1 b2)
;;       上卦：'(b3 b4 b5)
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
;; 签名：
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
;; hexagram-contrary  （错卦）
;;
;; 签名：
;;   hexagram-contrary :
;;     (and/c gua? hexagram?) -> (and/c gua? hexagram?)
;;
;; 功能（结构定义）：
;;   - 将整卦所有爻全部取反（0->1, 1->0）。
;;   - 在六爻卦语境中，对应传统“错卦”。
;; ------------------------------------------------------------
(define (hexagram-contrary g-hex)
  (define g (ensure-hexagram g-hex))
  (define g2 (cuo-gua g))
  (ensure-hexagram g2))

;; ------------------------------------------------------------
;; hexagram-reversed  （综卦）
;;
;; 签名：
;;   hexagram-reversed :
;;     (and/c gua? hexagram?) -> (and/c gua? hexagram?)
;;
;; 功能（结构定义）：
;;   - 将整卦的爻顺序上下颠倒。
;;   - 在六爻卦语境中，对应传统“综卦”。
;; ------------------------------------------------------------
(define (hexagram-reversed g-hex)
  (define g (ensure-hexagram g-hex))
  (define g2 (zong-gua g))
  (ensure-hexagram g2))

;; ------------------------------------------------------------
;; hexagram-mutual  （互卦）
;;
;; 签名：
;;   hexagram-mutual :
;;     (and/c gua? hexagram?) -> (and/c gua? hexagram?)
;;
;; 一种常见结构定义（可视为固定规则）：
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
;; 签名：
;;   hexagram-changing :
;;     (and/c gua? hexagram?) × (listof exact-nonnegative-integer?)
;;     -> (and/c gua? hexagram?)
;;
;; 功能：
;;   - 将给定六爻卦中，指定位置的爻统统翻转（0->1 / 1->0），得到变卦。
;;
;; 参数：
;;   g-hex          : 原始六爻卦。
;;   changing-lines : 需要“动爻”的位置列表（自下而上，从 0 开始）。
;;
;; 行为：
;;   - 对 changing-lines 中的每个 index：
;;       - 若 index 不在 [0,5] 范围，抛出错误；
;;       - 否则调用 flip-yao 翻转该爻。
;;   - 若列表中有重复 index，则同一位置会被翻转多次（奇数次翻转 = 取反）。
;; ------------------------------------------------------------
(define (hexagram-changing g-hex changing-lines)
  (define g0 (ensure-hexagram g-hex))
  (for/fold ([g g0])
            ([idx (in-list changing-lines)])
    (unless (and (integer? idx) (<= 0 idx) (< idx 6))
      (error 'hexagram-changing
             "line index out of range for hexagram: ~a" idx))
    (ensure-hexagram (flip-yao g idx))))

;; ------------------------------------------------------------
;; 自检：self-test
;;
;; 签名：
;;   self-test : -> void?
;;
;; 功能：
;;   - 对本模块的各个 API 做快速验证：
;;       1. 构造函数（bits / int）。
;;       2. ensure-hexagram。
;;       3. 拆分 & 组合。
;;       4. 错卦 / 综卦。
;;       5. 互卦。
;;       6. 变卦。
;; ------------------------------------------------------------
(define (self-test)
  ;; 1. 从 bits 构造
  (define h1 (make-hexagram-from-bits '(1 0 1 0 1 0)))
  (unless (and (hexagram? h1)
               (= (gua-width h1) 6)
               (equal? (gua-bits-list h1) '(1 0 1 0 1 0)))
    (error 'self-test "make-hexagram-from-bits failed"))

  ;; 2. 从 int 构造：1 + 4 + 16 = 21
  (define h2 (make-hexagram-from-int 21))
  (unless (equal? (gua-bits-list h2) '(1 0 1 0 1 0))
    (error 'self-test "make-hexagram-from-int failed"))

  ;; 3. ensure-hexagram 正常 & 错误情况
  (define h3 (ensure-hexagram h1))
  (unless (eq? h1 h3)
    (error 'self-test "ensure-hexagram should return the same object"))
  (define t (make-trigram-from-bits '(1 0 1)))
  (when (with-handlers ([exn:fail? (lambda (e) #f)])
          (ensure-hexagram t))
    (error 'self-test "ensure-hexagram should fail on trigram"))

  ;; 4. 拆分 & 组合
  (define-values (lower upper) (hexagram-split h1))
  (unless (and (trigram? lower)
               (trigram? upper)
               (equal? (gua-bits-list lower) '(1 0 1))
               (equal? (gua-bits-list upper) '(0 1 0)))
    (error 'self-test "hexagram-split failed"))
  (define h4 (hexagram-join lower upper))
  (unless (equal? (gua-bits-list h4) (gua-bits-list h1))
    (error 'self-test "hexagram-join failed"))

  ;; 5. 错卦：全部取反
  (define h-cuo (hexagram-contrary h1))
  (unless (equal? (gua-bits-list h-cuo) '(0 1 0 1 0 1))
    (error 'self-test "hexagram-contrary failed"))

  ;; 6. 综卦：上下倒置
  (define h-zong (hexagram-reversed h1))
  (unless (equal? (gua-bits-list h-zong) '(0 1 0 1 0 1))
    (error 'self-test "hexagram-reversed failed"))

  ;; 7. 互卦：按我们约定的结构规则
  ;; 原 bits = '(1 0 1 0 1 0)
  ;;   下互卦 = '(0 1 0)  ; b1 b2 b3
  ;;   上互卦 = '(1 0 1)  ; b2 b3 b4
  ;;   合成 = '(0 1 0 1 0 1)
  (define h-mut (hexagram-mutual h1))
  (unless (equal? (gua-bits-list h-mut) '(0 1 0 1 0 1))
    (error 'self-test
           "hexagram-mutual failed, got bits ~a"
           (gua-bits-list h-mut)))

  ;; 8. 变卦：指定动爻翻转
  ;; 原 bits = '(1 0 1 0 1 0)
  ;; 动 0、2、5：
  ;;   0: 1 -> 0
  ;;   2: 1 -> 0
  ;;   5: 0 -> 1
  ;; 结果应 = '(0 0 0 0 1 1)
  (define h-chg (hexagram-changing h1 '(0 2 5)))
  (unless (equal? (gua-bits-list h-chg) '(0 0 0 0 1 1))
    (error 'self-test
           "hexagram-changing failed, got bits ~a"
           (gua-bits-list h-chg)))

  (displayln "gua-hexagram self-test passed."))

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
   [hexagram-contrary
    (-> (and/c gua? hexagram?) (and/c gua? hexagram?))]
   [hexagram-reversed
    (-> (and/c gua? hexagram?) (and/c gua? hexagram?))]
   [hexagram-mutual
    (-> (and/c gua? hexagram?) (and/c gua? hexagram?))]
   [hexagram-changing
    (-> (and/c gua? hexagram?)
        (listof exact-nonnegative-integer?)
        (and/c gua? hexagram?))]))
