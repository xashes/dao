#lang racket

(require racket/contract
         "gua-core.rkt")

;; ============================================================
;; 模块：gua-core-operations.rkt
;;
;; 目标：
;;   - 在不引入新结构类型的前提下，为 gua 定义一组“通用结构操作”。
;;   - 这些操作全部只关心“0/1 序列”这一结构，不关心 trigram/hexagram 区分。
;;   - 其中“错卦 / 综卦”的命名直接在这里使用，以避免在 trigram/hexagram
;;     模块中重复包装同样的功能。
;;
;; 约定：
;;   - 仍然使用 gua-core.rkt 中定义的 gua 作为唯一底层类型。
;;   - 函数均为纯函数：不修改原 gua，而是返回新的 gua。
;; ============================================================

;; ------------------------------------------------------------
;; flip-yao
;;
;; 签名：
;;   flip-yao : gua? × exact-nonnegative-integer? -> gua?
;;
;; 功能：
;;   - 将指定爻“反转”：
;;       0 -> 1
;;       1 -> 0
;;   - 其它爻保持不变。
;;
;; 参数：
;;   g               : 任意宽度的 gua。
;;   pos-from-bottom : 自下而上的爻位置，从 0 开始。
;;
;; 行为：
;;   - 若 pos-from-bottom 超出 [0, gua-width(g) - 1] 范围，则抛出错误。
;;   - 否则返回一个新的 gua，表示反转后的结果。
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
;; cuo-gua  （错卦：全卦阴阳互换）
;;
;; 签名：
;;   cuo-gua : gua? -> gua?
;;
;; 功能（结构定义）：
;;   - 将整卦所有爻全部反转：
;;       0 -> 1
;;       1 -> 0
;;
;; 说明：
;;   - 在六爻卦语境中，这就是传统意义上的“错卦”。
;;   - 在三爻卦（甚至任意宽度实验性卦）中，同样可以视作“逐爻取反”的操作。
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
;; 签名：
;;   zong-gua : gua? -> gua?
;;
;; 功能（结构定义）：
;;   - 将整卦的爻顺序“反转”：自下而上的次序完全倒过来。
;;   - 若原 bits = (b0 b1 ... b(n-1))，则新 bits = (b(n-1) ... b1 b0)。
;;
;; 说明：
;;   - 在六爻卦语境下，对应传统“综卦”结构操作。
;;   - 在三爻卦或其他宽度下，同样可理解为“上下颠倒”的抽象。
;; ------------------------------------------------------------
(define (zong-gua g)
  (define bits (gua-bits g))
  (gua (reverse bits)))

;; ------------------------------------------------------------
;; sub-gua  （从整卦中抽取一段连续爻）
;;
;; 签名：
;;   sub-gua :
;;     gua? × exact-nonnegative-integer? × exact-positive-integer? -> gua?
;;
;; 功能：
;;   - 从给定卦 g 中，按“自下而上”的顺序抽取一段连续爻，构造一个新的 gua。
;;
;; 参数：
;;   g          : 原始 gua。
;;   start-pos  : 起始位置（自下而上，从 0 开始）。
;;   length     : 抽取的爻数（> 0）。
;;
;; 行为：
;;   - 要求 0 <= start-pos 且 start-pos + length <= gua-width(g)，否则抛错。
;;   - 返回一个新的 gua，包含这段连续爻。
;;
;; 示例语义（仅示意）：
;;   - 若 g 的 bits = '(1 0 1 0 1 0)，则
;;       sub-gua g 1 3  -> bits = '(0 1 0)    ; 取 2~4 爻
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
;; 签名：
;;   concat-gua : gua? × gua? -> gua?
;;
;; 功能：
;;   - 以 g1 作为下部、g2 作为上部，将两卦的爻序列拼接成一个新 gua。
;;   - 新 bits = g1.bits ++ g2.bits。
;;
;; 用途：
;;   - 在六爻卦语境中：
;;       - 下 trigram + 上 trigram -> hexagram。
;;   - 在通用宽度场景中，也可理解为“上下堆叠”。
;; ------------------------------------------------------------
(define (concat-gua g1 g2)
  (define bits1 (gua-bits g1))
  (define bits2 (gua-bits g2))
  (gua (append bits1 bits2)))

;; ------------------------------------------------------------
;; map-yao  （对每一爻应用一个变换）
;;
;; 签名：
;;   map-yao :
;;     ((Bit -> Bit) × gua?) -> gua?
;;   其中 Bit = 0 或 1。
;;
;; 功能：
;;   - 用更高阶的方式描述“对整卦每一爻做一个局部变换”。
;;   - 例如：
;;       - cuo-gua 可以视作 map-yao 与 (lambda (b) (if (zero? b) 1 0)) 的组合。
;;       - 将所有阳爻改为阴爻、保留阴爻不变等，都可以用 map-yao 表达。
;;
;; 约束：
;;   - f 必须将 0/1 映射到 0/1（由 contract 保证）。
;; ------------------------------------------------------------
(define (map-yao f g)
  (define bits (gua-bits g))
  (define new-bits
    (for/list ([b (in-list bits)])
      (f b)))
  (gua new-bits))

;; ------------------------------------------------------------
;; 自检函数：self-test
;;
;; 签名：
;;   self-test : -> void?
;;
;; 功能：
;;   - 对本模块提供的通用结构操作做一次简单回归测试：
;;       1. flip-yao 是否只反转指定爻。
;;       2. cuo-gua 是否对所有爻取反。
;;       3. zong-gua 是否将爻顺序完全倒置。
;;       4. sub-gua 是否按指定范围截取。
;;       5. concat-gua 是否按“下接上”的顺序拼接。
;;       6. map-yao 是否按位应用给定函数。
;; ------------------------------------------------------------
(define (self-test)
  ;; 用一个六爻卦做基础：bits = '(1 0 1 0 1 0)
  (define g (make-gua-from-bits '(1 0 1 0 1 0)))

  ;; 1. flip-yao：只反转指定位置
  (define g-flip-2 (flip-yao g 2)) ; 反转第三爻
  (unless (equal? (gua-bits-list g-flip-2) '(1 0 0 0 1 0))
    (error 'self-test "flip-yao failed: expected '(1 0 0 0 1 0), got ~a"
           (gua-bits-list g-flip-2)))

  ;; 2. cuo-gua：全部取反
  (define g-cuo (cuo-gua g))
  (unless (equal? (gua-bits-list g-cuo) '(0 1 0 1 0 1))
    (error 'self-test "cuo-gua failed: expected '(0 1 0 1 0 1), got ~a"
           (gua-bits-list g-cuo)))

  ;; 3. zong-gua：顺序倒置
  (define g-zong (zong-gua g))
  (unless (equal? (gua-bits-list g-zong) '(0 1 0 1 0 1))
    (error 'self-test "zong-gua failed: expected '(0 1 0 1 0 1), got ~a"
           (gua-bits-list g-zong)))

  ;; 4. sub-gua：取连续三爻
  (define g-sub (sub-gua g 1 3)) ; 取二、三、四爻
  (unless (equal? (gua-bits-list g-sub) '(0 1 0))
    (error 'self-test "sub-gua failed: expected '(0 1 0), got ~a"
           (gua-bits-list g-sub)))

  ;; 5. concat-gua：下接上
  (define g-top (make-gua-from-bits '(0 0 1)))
  (define g-bot (make-gua-from-bits '(1 1 0)))
  (define g-cat (concat-gua g-bot g-top))
  (unless (equal? (gua-bits-list g-cat) '(1 1 0 0 0 1))
    (error 'self-test "concat-gua failed: expected '(1 1 0 0 0 1), got ~a"
           (gua-bits-list g-cat)))

  ;; 6. map-yao：将所有爻强制变成阴（0）
  (define g-all-yin (map-yao (lambda (b) 0) g))
  (unless (equal? (gua-bits-list g-all-yin) '(0 0 0 0 0 0))
    (error 'self-test "map-yao failed: expected all 0, got ~a"
           (gua-bits-list g-all-yin)))

  (displayln "gua-core-operations self-test passed."))

;; ------------------------------------------------------------
;; 直接运行本文件时，自动执行自测
;; ------------------------------------------------------------
(module+ main
  (self-test))

;; ------------------------------------------------------------
;; 对外提供的接口及其 contract
;; ------------------------------------------------------------
(provide
  (contract-out
   [flip-yao   (-> gua? exact-nonnegative-integer? gua?)]
   [cuo-gua    (-> gua? gua?)]
   [zong-gua   (-> gua? gua?)]
   [sub-gua    (-> gua? exact-nonnegative-integer? exact-positive-integer? gua?)]
   [concat-gua (-> gua? gua? gua?)]
   [map-yao    (-> (-> (or/c 0 1) (or/c 0 1)) gua? gua?)]))
