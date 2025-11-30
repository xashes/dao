#lang racket

(require racket/contract
         "gua-core.rkt")

;; ============================================================
;; 模块：gua-core-operations.rkt
;;
;; 目标：
;;   - 在 gua 的基础上，提供一组“纯结构”的通用操作：
;;       flip-yao / flip-yaos / cuo-gua / zong-gua / sub-gua /
;;       concat-gua / map-yao
;;   - 不区分 trigram / hexagram，这里只关心“0/1 序列”的结构变化。
;; ============================================================

;; ------------------------------------------------------------
;; flip-yao
;;
;;   flip-yao : gua? × exact-nonnegative-integer? -> gua?
;;
;; 功能：
;;   - 将指定爻“反转”：
;;       0 -> 1
;;       1 -> 0
;;   - 其它爻保持不变。
;; ------------------------------------------------------------
(define (flip-yao g pos-from-bottom)
  (define w (gua-width g))
  (unless (and (integer? pos-from-bottom)
               (<= 0 pos-from-bottom)
               (< pos-from-bottom w))
    (error 'flip-yao
           "yao position out of range: ~a, width=~a"
           pos-from-bottom w))
  (define bits (gua-bits g))
  (define new-bits
    (for/list ([b (in-list bits)]
               [i (in-naturals)])
      (if (= i pos-from-bottom)
          (if (zero? b) 1 0)
          b)))
  (gua new-bits))

;; ------------------------------------------------------------
;; flip-yaos  （按多条爻翻转）
;;
;;   flip-yaos :
;;     gua? × (listof exact-nonnegative-integer?) -> gua?
;;
;; 功能：
;;   - 将给定卦中，若干指定位置的爻统统翻转（0->1 / 1->0）。
;;   - 对任意 width 的 gua 都适用（三爻、六爻或其他扩展）。
;;
;; 行为：
;;   - 对列表中的每个 index：
;;       - 要求 0 <= index < gua-width(g)，否则抛出错误；
;;       - 按顺序依次翻转（重复出现的 index 会被翻转多次）。
;; ------------------------------------------------------------
(define (flip-yaos g indices)
  (define w (gua-width g))
  (for/fold ([curr g])
            ([idx (in-list indices)])
    (unless (and (integer? idx)
                 (<= 0 idx)
                 (< idx w))
      (error 'flip-yaos
             "yao index out of range: ~a (width=~a)" idx w))
    (flip-yao curr idx)))

;; ------------------------------------------------------------
;; cuo-gua  （错卦：全卦阴阳互换）
;;
;;   cuo-gua : gua? -> gua?
;;
;; 功能：
;;   - 将整卦所有爻全部反转：
;;       0 -> 1
;;       1 -> 0
;; ------------------------------------------------------------
(define (cuo-gua g)
  (define bits (gua-bits g))
  (define new-bits
    (for/list ([b (in-list bits)])
      (if (zero? b) 1 0)))
  (gua new-bits))

;; ------------------------------------------------------------
;; zong-gua  （综卦：上下倒置）
;;
;;   zong-gua : gua? -> gua?
;;
;; 功能：
;;   - 将整卦的爻顺序“反转”：自下而上的次序完全倒过来。
;; ------------------------------------------------------------
(define (zong-gua g)
  (define bits (gua-bits g))
  (gua (reverse bits)))

;; ------------------------------------------------------------
;; sub-gua  （从整卦中抽取一段连续爻）
;;
;;   sub-gua :
;;     gua? × exact-nonnegative-integer? × exact-positive-integer? -> gua?
;;
;; 功能：
;;   - 从给定卦 g 中，按“自下而上”的顺序抽取一段连续爻，构造一个新的 gua。
;; ------------------------------------------------------------
(define (sub-gua g start-pos length)
  (define w (gua-width g))
  (unless (and (integer? start-pos)
               (integer? length)
               (<= 0 start-pos)
               (> length 0)
               (<= (+ start-pos length) w))
    (error 'sub-gua
           "invalid range: start-pos=~a, length=~a, width=~a"
           start-pos length w))
  (define bits (gua-bits g))
  (define new-bits
    (take (drop bits start-pos) length))
  (gua new-bits))

;; ------------------------------------------------------------
;; concat-gua  （拼接两个卦：下接上）
;;
;;   concat-gua : gua? × gua? -> gua?
;;
;; 功能：
;;   - 以 g1 作为下部、g2 作为上部，将两卦的爻序列拼接成一个新 gua：
;;       bits = g1.bits ++ g2.bits
;; ------------------------------------------------------------
(define (concat-gua g1 g2)
  (define bits1 (gua-bits g1))
  (define bits2 (gua-bits g2))
  (gua (append bits1 bits2)))

;; ------------------------------------------------------------
;; map-yao  （对每一爻应用一个变换）
;;
;;   map-yao :
;;     ((Bit -> Bit) × gua?) -> gua?
;;   其中 Bit = 0 或 1。
;;
;; 功能：
;;   - 用高阶函数方式描述“对整卦每一爻做一个局部变换”。
;; ------------------------------------------------------------
(define (map-yao f g)
  (define bits (gua-bits g))
  (define new-bits
    (for/list ([b (in-list bits)])
      (f b)))
  (gua new-bits))

;; ------------------------------------------------------------
;; 对外提供的接口及其 contract
;; ------------------------------------------------------------
(provide
  (contract-out
   [flip-yao   (-> gua? exact-nonnegative-integer? gua?)]
   [flip-yaos  (-> gua? (listof exact-nonnegative-integer?) gua?)]
   [cuo-gua    (-> gua? gua?)]
   [zong-gua   (-> gua? gua?)]
   [sub-gua    (-> gua? exact-nonnegative-integer? exact-positive-integer? gua?)]
   [concat-gua (-> gua? gua? gua?)]
   [map-yao    (-> (-> (or/c 0 1) (or/c 0 1)) gua? gua?)]))

;; ============================================================
;; 测试：module+ test + rackunit
;;   raco test gua-core-operations.rkt
;; ============================================================

(module+ test
  (require rackunit)

  (define g (make-gua-from-bits '(1 0 1 0 1 0)))

  ;; 1. flip-yao：只反转指定位置
  (test-case
   "flip-yao flips only specified yao"
   (define g-flip-2 (flip-yao g 2)) ; 反转第三爻
   (check-equal? (gua-bits-list g-flip-2) '(1 0 0 0 1 0)))

  ;; 2. flip-yaos：多个位置翻转
  (test-case
   "flip-yaos flips multiple yaos"
   ;; 在 g = '(1 0 1 0 1 0) 上，动 0、2、5：
   ;;   0: 1 -> 0
   ;;   2: 1 -> 0
   ;;   5: 0 -> 1
   ;; 结果应 = '(0 0 0 0 1 1)
   (define g-multi (flip-yaos g '(0 2 5)))
   (check-equal? (gua-bits-list g-multi) '(0 0 0 0 1 1)))

  ;; 3. cuo-gua：全部取反
  (test-case
   "cuo-gua flips all yaos"
   (define g-cuo (cuo-gua g))
   (check-equal? (gua-bits-list g-cuo) '(0 1 0 1 0 1)))

  ;; 4. zong-gua：顺序倒置
  (test-case
   "zong-gua reverses yao order"
   (define g-zong (zong-gua g))
   (check-equal? (gua-bits-list g-zong) '(0 1 0 1 0 1)))

  ;; 5. sub-gua：取连续三爻
  (test-case
   "sub-gua extracts contiguous slice"
   (define g-sub (sub-gua g 1 3)) ; 取二、三、四爻
   (check-equal? (gua-bits-list g-sub) '(0 1 0)))

  ;; 6. concat-gua：下接上
  (test-case
   "concat-gua concatenates bottom and top"
   (define g-top (make-gua-from-bits '(0 0 1)))
   (define g-bot (make-gua-from-bits '(1 1 0)))
   (define g-cat (concat-gua g-bot g-top))
   (check-equal? (gua-bits-list g-cat) '(1 1 0 0 0 1)))

  ;; 7. map-yao：将所有爻强制变成阴（0）
  (test-case
   "map-yao applies transformation to each yao"
   (define g-all-yin (map-yao (λ (b) 0) g))
   (check-equal? (gua-bits-list g-all-yin) '(0 0 0 0 0 0)))

  ;; 8. flip-yaos 在三爻卦上的使用示例
  (test-case
   "flip-yaos also works on trigram"
   (define t (make-gua-from-bits '(1 1 0)))
   ;; 动 1：1 -> 0，结果 = '(1 0 0)
   (define t2 (flip-yaos t '(1)))
   (check-equal? (gua-bits-list t2) '(1 0 0))))
