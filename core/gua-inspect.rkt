#lang racket

(require racket/contract
         racket/format
         "gua-core.rkt"
         "gua-core-operations.rkt"
         "gua-trigram.rkt"
         "gua-hexagram.rkt"
         "gua-trigram-data.rkt")

;; ============================================================
;; 模块：gua-inspect.rkt
;;
;; 目标：
;;   - 提供统一的“卦结构视图”：
;;       describe-gua : gua? -> 结构化描述
;;       print-gua    : gua? -> 在 REPL 中打印可读的小报告
;;
;;   - 对不同宽度的 gua：
;;       * width=3 → 当作 trigram：使用 trigram-info 做描述
;;       * width=6 → 当作 hexagram：拆上下卦、给出互卦/错卦/综卦等视图
;;       * 其它宽度 → 只给出 id / bits / width 的简单信息
;;
;; 说明：
;;   - 不涉及任何占筮、象义解释，只做结构与基本属性展示。
;; ============================================================

;; ------------------------------------------------------------
;; 描述结构定义
;; ------------------------------------------------------------

(struct trigram-description
  (id                ; gua-id
   bits              ; (listof 0/1)
   info)             ; trigram-info
  #:transparent)

(struct hexagram-description
  (id                ; gua-id
   bits              ; (listof 0/1)
   lower-info        ; trigram-info
   upper-info        ; trigram-info
   contrary-id       ; 错卦 id
   contrary-bits
   reversed-id       ; 综卦 id
   reversed-bits
   mutual-id         ; 互卦 id
   mutual-bits)
  #:transparent)

(struct generic-gua-description
  (id                ; gua-id
   width
   bits)             ; (listof 0/1)
  #:transparent)

;; ------------------------------------------------------------
;; describe-gua : gua? -> (or/c trigram-description?
;;                          hexagram-description?
;;                          generic-gua-description?)
;; ------------------------------------------------------------

(define (describe-gua g)
  (define w (gua-width g))
  (define bits (gua-bits-list g))
  (cond
    ;; 三爻卦：使用 trigram-info
    [(trigram? g)
     (define info (lookup-trigram-by-gua g))
     (trigram-description
      (gua-id g)
      bits
      info)]

    ;; 六爻卦：拆上下卦 + 互卦/错卦/综卦
    [(hexagram? g)
     (define-values (lower upper) (hexagram-split g))
     (define lower-info (lookup-trigram-by-gua lower))
     (define upper-info (lookup-trigram-by-gua upper))

     ;; 错卦 / 综卦 / 互卦
     (define g-contrary (cuo-gua g))
     (define g-reversed (zong-gua g))
     (define g-mutual   (hexagram-mutual g))

     (hexagram-description
      (gua-id g)
      bits
      lower-info
      upper-info
      (gua-id g-contrary)
      (gua-bits-list g-contrary)
      (gua-id g-reversed)
      (gua-bits-list g-reversed)
      (gua-id g-mutual)
      (gua-bits-list g-mutual))]

    ;; 其它宽度：只做简单描述
    [else
     (generic-gua-description
      (gua-id g)
      w
      bits)]))

;; ------------------------------------------------------------
;; print-gua : gua? -> void?
;; ------------------------------------------------------------

(define (print-gua g)
  (define desc (describe-gua g))
  (cond
    [(trigram-description? desc)
     (print-trigram-description desc)]
    [(hexagram-description? desc)
     (print-hexagram-description desc)]
    [(generic-gua-description? desc)
     (print-generic-gua-description desc)]
    [else
     (error 'print-gua
            "unknown description type: ~a" desc)]))

;; ------------------------------------------------------------
;; 辅助打印函数（内部）：全部使用“属性名 : 值”的格式
;; ------------------------------------------------------------

(define (print-trigram-description desc)
  (define id   (trigram-description-id desc))
  (define bits (trigram-description-bits desc))
  (define info (trigram-description-info desc))

  (printf "三爻卦 (trigram)\n")
  (printf "  id           : ~a\n" id)
  (printf "  bits         : ~a  ; 自下而上\n" bits)
  (printf "  name-zh      : ~a\n" (trigram-info-name-zh info))
  (printf "  name-py      : ~a\n" (trigram-info-name-py info))
  (printf "  name-en      : ~a\n" (trigram-info-name-en info))
  (printf "  element      : ~a\n" (trigram-info-element info))
  (printf "  image        : ~a\n" (trigram-info-image info))
  (printf "  family       : ~a\n" (trigram-info-family info))
  (printf "  xiantian-dir : ~a\n"
          (trigram-info-direction-xiantian info))
  (printf "  xiantian-num : ~a\n"
          (trigram-info-number-xiantian info))
  (printf "  houtian-dir  : ~a\n"
          (trigram-info-direction-houtian info))
  (printf "  houtian-num  : ~a\n"
          (trigram-info-number-houtian info))
  (newline))

(define (print-hexagram-description desc)
  (define id    (hexagram-description-id desc))
  (define bits  (hexagram-description-bits desc))
  (define li    (hexagram-description-lower-info desc))
  (define ui    (hexagram-description-upper-info desc))
  (define cid   (hexagram-description-contrary-id desc))
  (define cbits (hexagram-description-contrary-bits desc))
  (define rid   (hexagram-description-reversed-id desc))
  (define rbits (hexagram-description-reversed-bits desc))
  (define mid   (hexagram-description-mutual-id desc))
  (define mbits (hexagram-description-mutual-bits desc))

  (printf "六爻卦 (hexagram)\n")
  (printf "  id           : ~a\n" id)
  (printf "  bits         : ~a  ; 自下而上\n" bits)

  (printf "  lower (下卦):\n")
  (printf "    name-zh      : ~a\n" (trigram-info-name-zh li))
  (printf "    name-py      : ~a\n" (trigram-info-name-py li))
  (printf "    name-en      : ~a\n" (trigram-info-name-en li))
  (printf "    element      : ~a\n" (trigram-info-element li))
  (printf "    image        : ~a\n" (trigram-info-image li))
  (printf "    family       : ~a\n" (trigram-info-family li))
  (printf "    houtian-dir  : ~a\n"
          (trigram-info-direction-houtian li))
  (printf "    houtian-num  : ~a\n"
          (trigram-info-number-houtian li))

  (printf "  upper (上卦):\n")
  (printf "    name-zh      : ~a\n" (trigram-info-name-zh ui))
  (printf "    name-py      : ~a\n" (trigram-info-name-py ui))
  (printf "    name-en      : ~a\n" (trigram-info-name-en ui))
  (printf "    element      : ~a\n" (trigram-info-element ui))
  (printf "    image        : ~a\n" (trigram-info-image ui))
  (printf "    family       : ~a\n" (trigram-info-family ui))
  (printf "    houtian-dir  : ~a\n"
          (trigram-info-direction-houtian ui))
  (printf "    houtian-num  : ~a\n"
          (trigram-info-number-houtian ui))

  (printf "  derived (结构变换):\n")
  (printf "    cuo-gua-id   : ~a\n" cid)
  (printf "    cuo-gua-bits : ~a\n" cbits)
  (printf "    zong-gua-id  : ~a\n" rid)
  (printf "    zong-gua-bits: ~a\n" rbits)
  (printf "    mutual-id    : ~a\n" mid)
  (printf "    mutual-bits  : ~a\n" mbits)
  (newline))

(define (print-generic-gua-description desc)
  (printf "一般卦 (generic gua)\n")
  (printf "  id           : ~a\n" (generic-gua-description-id desc))
  (printf "  width        : ~a\n" (generic-gua-description-width desc))
  (printf "  bits         : ~a  ; 自下而上\n"
          (generic-gua-description-bits desc))
  (newline))

;; ------------------------------------------------------------
;; 对外导出及其 contract
;; ------------------------------------------------------------

(provide
  (contract-out
   [trigram-description?        (-> any/c boolean?)]
   [hexagram-description?       (-> any/c boolean?)]
   [generic-gua-description?    (-> any/c boolean?)]
   [describe-gua
    (-> gua?
        (or/c trigram-description?
              hexagram-description?
              generic-gua-description?))]
   [print-gua
    (-> gua? void?)]))

;; ============================================================
;; 测试：module+ test + rackunit
;;   raco test gua-inspect.rkt
;; ============================================================

(module+ test
  (require rackunit)

  ;; 1. 三爻卦描述测试（以离卦为例）
  (test-case
   "describe trigram (li)"
   (define t-li (make-trigram-from-bits '(1 0 1)))
   (define d (describe-gua t-li))
   (check-true (trigram-description? d))
   (check-equal? (trigram-description-bits d) '(1 0 1))
   (define info (trigram-description-info d))
   (check-equal? (trigram-info-name-zh info) '离)
   (check-equal? (trigram-info-element info) 'fire)
   (check-equal? (trigram-info-direction-houtian info) 'south)
   (check-equal? (trigram-info-number-houtian info) 9))

  ;; 2. 六爻卦描述测试：下卦离、上卦坎
  (test-case
   "describe hexagram"
   (define h (make-hexagram-from-bits '(1 0 1 0 1 0)))
   (define d (describe-gua h))
   (check-true (hexagram-description? d))
   (check-equal? (hexagram-description-bits d) '(1 0 1 0 1 0))
   (define li (hexagram-description-lower-info d))
   (define ka (hexagram-description-upper-info d))
   (check-equal? (trigram-info-name-zh li) '离)
   (check-equal? (trigram-info-name-zh ka) '坎)
   (check-equal? (length (hexagram-description-contrary-bits d)) 6)
   (check-equal? (length (hexagram-description-reversed-bits d)) 6)
   (check-equal? (length (hexagram-description-mutual-bits d)) 6))

  ;; 3. 一般宽度的 gua（比如 4 爻）
  (test-case
   "describe generic gua"
   (define g4 (make-gua-from-bits '(1 0 0 1)))
   (define d (describe-gua g4))
   (check-true (generic-gua-description? d))
   (check-equal? (generic-gua-description-width d) 4)
   (check-equal? (generic-gua-description-bits d) '(1 0 0 1))))
