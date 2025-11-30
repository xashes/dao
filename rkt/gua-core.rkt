#lang racket

(require racket/contract)

;; ============================================================
;; 模块：gua-core.rkt（list 版本）
;;
;; 功能定位：
;;   - 提供“卦”的最底层二进制结构表示，不涉及卦名、五行、爻辞等解释。
;;   - 每一卦由一个 *不可变列表* 表示，其元素为 0 或 1：
;;       0 = 阴爻
;;       1 = 阳爻
;;     列表第 0 个元素为“初爻”（最下），最后一个元素为“上爻”（最上）。
;;   - 整数编码是一种派生表示：
;;       bit0 = 初爻，bit1 = 二爻，...，bit(width-1) = 上爻。
;;
;; 设计原则：
;;   - 这一层只关心“有几爻、每一爻的阴阳”，不关心任何易学解释。
;;   - 所有外部可见函数都附带 contract，保证最基本的类型约束。
;;   - 列表长度必须 > 0，元素必须为 0 或 1；由构造函数负责强制检查。
;; ============================================================

;; ------------------------------------------------------------
;; 数据结构：gua
;;
;; 字段：
;;   bits : (listof 0/1)
;;          bits 的第 0 个元素表示“初爻”（最下），
;;          第 1 个元素表示“二爻”，
;;          ...
;;          最后一个元素表示“上爻”（最上）。
;;
;; 说明：
;;   - 结构体为透明结构体，方便调试和 REPL 观察。
;;   - 对外推荐通过 make-gua-from-bits / make-gua-from-int 来构造，
;;     以保证 bits 非空、元素只为 0/1 等不变量。
;; ------------------------------------------------------------
(struct gua (bits)
  #:transparent)

;; ------------------------------------------------------------
;; 内部辅助：判断一个值是否为合法的 bit（0 或 1）
;;
;; 仅在本模块内部调用，不导出。
;; ------------------------------------------------------------
(define (valid-bit? b)
  (and (integer? b)
       (or (= b 0) (= b 1))))

;; ------------------------------------------------------------
;; 接口函数：gua-width
;;
;; 签名（通过 contract-out 声明）：
;;   gua-width : gua? -> exact-positive-integer?
;;
;; 功能：
;;   - 返回给定 Gua 的爻数（width），即 bits 列表的长度。
;;
;; 语义约束：
;;   - 合法 Gua 的 bits 列表在构造时保证为非空，因此返回值必为正整数。
;; ------------------------------------------------------------
(define (gua-width g)
  (length (gua-bits g)))

;; ------------------------------------------------------------
;; 构造函数：make-gua-from-bits
;;
;; 签名：
;;   make-gua-from-bits :
;;     (and/c (listof (or/c 0 1)) (not/c empty?)) -> gua?
;;
;; 输入：
;;   bits-list : 自下而上的 bit 列表（非空），每个元素必须是 0 或 1。
;;
;; 输出：
;;   一个 gua 值，其 bits 字段即为该列表（作为值对象使用）。
;;
;; 行为：
;;   - 若 bits-list 不是非空列表，抛出错误。
;;   - 若 bits-list 中存在不是 0/1 的元素，抛出错误。
;;
;; 使用场景：
;;   - 在 Racket 内部用列表描述卦（例如算法中间状态），
;;     最终希望统一成 Gua 值时使用。
;; ------------------------------------------------------------
(define (make-gua-from-bits bits-list)
  (unless (and (list? bits-list) (pair? bits-list))
    (error 'make-gua-from-bits
           "bits-list must be a non-empty list, got ~a" bits-list))
  (for ([b bits-list]
        [i (in-naturals)])
    (unless (valid-bit? b)
      (error 'make-gua-from-bits
             "bits-list[~a] must be 0 or 1, got ~a" i b)))
  ;; Racket 的普通列表本身是不可变的（除非使用 mcons），
  ;; 可以直接作为不可变值存入结构体。
  (gua bits-list))

;; ------------------------------------------------------------
;; 构造函数：make-gua-from-int
;;
;; 签名：
;;   make-gua-from-int :
;;     exact-nonnegative-integer? exact-positive-integer? -> gua?
;;
;; 输入：
;;   bits-int : 非负整数，表示卦的二进制编码：
;;                bit0 = 初爻，bit1 = 二爻，...，bit(width-1) = 上爻。
;;   width    : 正整数，表示爻数（通常为 3 或 6，但此处允许任意 >0）。
;;
;; 输出：
;;   一个 gua 值，其 bits 列表长度为 width，元素由 bits-int 拆解而来。
;;
;; 语义约束：
;;   - 必须满足 0 <= bits-int <= 2^width - 1，否则抛出错误。
;;
;; 使用场景：
;;   - 当你已有统一的整数编码（例如来自 Python/数据库/网络），
;;     需要在 Racket 中恢复为 Gua 值时使用。
;; ------------------------------------------------------------
(define (make-gua-from-int bits-int width)
  (unless (and (integer? width) (> width 0))
    (error 'make-gua-from-int
           "width must be a positive integer, got ~a" width))
  (unless (and (integer? bits-int) (>= bits-int 0))
    (error 'make-gua-from-int
           "bits-int must be a non-negative integer, got ~a" bits-int))
  (define max-bits (sub1 (arithmetic-shift 1 width)))
  (unless (<= bits-int max-bits)
    (error 'make-gua-from-int
           "bits-int must be in [0, ~a] for width=~a, got ~a"
           max-bits width bits-int))
  ;; 拆解整数为自下而上的 bit 列表
  (define bits-list
    (for/list ([i (in-range width)])
      (if (zero? (bitwise-and bits-int (arithmetic-shift 1 i)))
          0
          1)))
  (gua bits-list))

;; ------------------------------------------------------------
;; 接口函数：gua-yao
;;
;; 签名：
;;   gua-yao :
;;     gua? exact-nonnegative-integer? -> (or/c 0 1)
;;
;; 输入：
;;   g              : 一个 Gua 值。
;;   pos-from-bottom: 自下而上的爻位置，从 0 开始：
;;                      0 = 初爻（最下）
;;                      1 = 二爻
;;                      ...
;;                      (width-1) = 上爻（最上）
;;
;; 输出：
;;   对应位置上的 bit 值：0（阴）或 1（阳）。
;;
;; 语义约束：
;;   - 若 pos-from-bottom 不在 [0, width-1] 之内，则抛出错误。
;;
;; 使用场景：
;;   - 在实现变卦、互卦、错综等运算时，按位置访问某一爻的阴阳。
;; ------------------------------------------------------------
(define (gua-yao g pos-from-bottom)
  (define w (gua-width g))
  (unless (and (integer? pos-from-bottom)
               (<= 0 pos-from-bottom)
               (< pos-from-bottom w))
    (error 'gua-yao
           "yao position out of range: ~a, width=~a"
           pos-from-bottom w))
  (list-ref (gua-bits g) pos-from-bottom))

;; ------------------------------------------------------------
;; 接口函数：gua-bits-list
;;
;; 签名：
;;   gua-bits-list : gua? -> (listof (or/c 0 1))
;;
;; 功能：
;;   - 返回 Gua 对应的 bit 列表。
;;   - 列表元素自下而上排列：
;;       (list 初爻 二爻 三爻 ... 上爻)
;;
;; 说明：
;;   - 返回的列表可以直接用于 Racket 的各类 list 操作（map/filter/fold 等），
;;     非常方便实现各种卦象变换。
;; ------------------------------------------------------------
(define (gua-bits-list g)
  (gua-bits g))

;; ------------------------------------------------------------
;; 接口函数：gua->int
;;
;; 签名：
;;   gua->int : gua? -> exact-nonnegative-integer?
;;
;; 功能：
;;   - 将 Gua 的 bits 列表编码为一个整数：
;;       bit0 = 初爻
;;       bit1 = 二爻
;;       ...
;;       bit(width-1) = 上爻
;;   - 返回值一定在 [0, 2^width - 1] 之内。
;;
;; 使用场景：
;;   - 将卦象进行序列化/存储/跨语言传输时使用。
;; ------------------------------------------------------------
(define (gua->int g)
  (for/fold ([acc 0])
            ([b (in-list (gua-bits g))]
             [i (in-naturals)])
    (if (zero? b)
        acc
        (bitwise-ior acc (arithmetic-shift 1 i)))))

;; ------------------------------------------------------------
;; 接口函数：gua-trigram?
;;
;; 签名：
;;   gua-trigram? : gua? -> boolean?
;;
;; 功能：
;;   - 判断给定 Gua 是否为三爻卦（宽度 = 3）。
;;   - 只关心爻数，不涉及具体卦名。
;; ------------------------------------------------------------
(define (gua-trigram? g)
  (= (gua-width g) 3))

;; ------------------------------------------------------------
;; 接口函数：gua-hexagram?
;;
;; 签名：
;;   gua-hexagram? : gua? -> boolean?
;;
;; 功能：
;;   - 判断给定 Gua 是否为六爻卦（宽度 = 6）。
;;   - 只关心爻数，不涉及具体卦名或卦序。
;; ------------------------------------------------------------
(define (gua-hexagram? g)
  (= (gua-width g) 6))

;; ------------------------------------------------------------
;; 自检函数：self-test
;;
;; 签名：
;;   self-test : -> void?
;;
;; 功能：
;;   - 对本模块的核心行为做一次简易回归测试：
;;       1. 检查底爻/上爻与 bit 位的对应关系。
;;       2. 检查 bits-list <-> int 的 round-trip 是否保持一致。
;;       3. 检查三爻卦/六爻卦的判定逻辑。
;;   - 若任何断言失败，将抛出错误。
;;   - 若全部通过，将打印 “gua-core (list) self-test passed.”。
;; ------------------------------------------------------------
(define (self-test)
  ;; 1. 底爻是 bit0：初爻为阳，其余为阴
  (define g1 (make-gua-from-bits '(1 0 0 0 0 0)))
  (unless (= (gua->int g1) 1)
    (error 'self-test "g1 integer encoding should be 1, got ~a" (gua->int g1)))
  (unless (= (gua-yao g1 0) 1)
    (error 'self-test "g1: yao 0 should be 1"))
  (unless (= (gua-yao g1 5) 0)
    (error 'self-test "g1: yao 5 should be 0"))

  ;; 2. 只有上爻为阳：对应最高位为 1
  (define g2 (make-gua-from-bits '(0 0 0 0 0 1)))
  (define expected2 (arithmetic-shift 1 5))
  (unless (= (gua->int g2) expected2)
    (error 'self-test
           "g2 integer encoding should be ~a, got ~a"
           expected2 (gua->int g2)))
  (unless (= (gua-yao g2 5) 1)
    (error 'self-test "g2: yao 5 should be 1"))
  (unless (= (gua-yao g2 0) 0)
    (error 'self-test "g2: yao 0 should be 0"))

  ;; 3. 列表 round-trip：bits -> gua -> bits
  (define bits3 '(1 1 0 1 0 0))
  (define g3 (make-gua-from-bits bits3))
  (unless (equal? (gua-bits-list g3) bits3)
    (error 'self-test
           "g3 bits round-trip failed: expected ~a, got ~a"
           bits3 (gua-bits-list g3)))

  ;; 4. 三爻卦示例
  (define g4 (make-gua-from-bits '(1 0 1)))
  (unless (and (gua-trigram? g4) (not (gua-hexagram? g4)))
    (error 'self-test "g4 should be trigram but not hexagram"))
  (unless (= (gua->int g4) #b101)
    (error 'self-test "g4 integer encoding should be 0b101, got ~a" (gua->int g4)))

  (displayln "gua-core (list) self-test passed."))

;; ------------------------------------------------------------
;; 直接运行本文件时，自动执行自检
;; ------------------------------------------------------------
(module+ main
  (self-test))

;; ------------------------------------------------------------
;; 对外提供的接口及其 contract
;;
;; 说明：
;;   - 通过 contract-out 为所有导出符号附加类型约束。
;;   - struct gua 的 bits 字段被约束为 (listof (or/c 0 1))，
;;     表示自下而上的 0/1 列表。
;; ------------------------------------------------------------
(provide
  (contract-out
   [struct gua
     ([bits (listof (or/c 0 1))])]
   [gua-width        (-> gua? exact-positive-integer?)]
   [make-gua-from-bits
    (-> (and/c (listof (or/c 0 1)) (not/c empty?)) gua?)]
   [make-gua-from-int
    (-> exact-nonnegative-integer? exact-positive-integer? gua?)]
   [gua-yao          (-> gua? exact-nonnegative-integer? (or/c 0 1))]
   [gua-bits-list    (-> gua? (listof (or/c 0 1)))]
   [gua->int         (-> gua? exact-nonnegative-integer?)]
   [gua-trigram?     (-> gua? boolean?)]
   [gua-hexagram?    (-> gua? boolean?)]
   [self-test        (-> void?)]))
