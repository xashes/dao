#lang racket

(require racket/contract)

;; ============================================================
;; 模块：wuxing-core.rkt
;;
;; 目标：
;;   - 为“五行”提供一个独立的、可操作的核心模型。
;;   - 表示方式：
;;       使用 symbol 表示五行：
;;         'wood  : 木
;;         'fire  : 火
;;         'earth : 土
;;         'metal : 金
;;         'water : 水
;;   - 提供：
;;       * 五行类型判定：element?
;;       * 枚举：element-list
;;       * index 映射：element->index / index->element
;;       * 相生关系：
;;           element-sheng-target  ; 我生谁
;;           element-sheng-source  ; 谁生我
;;           element-sheng?        ; 是否“生”关系
;;       * 相克关系：
;;           element-ke-target     ; 我克谁
;;           element-ke-source     ; 谁克我
;;           element-ke?           ; 是否“克”关系
;;       * 比和：
;;           element-same?         ; 同一五行
;;
;; 设计说明：
;;   - 对外接口全部使用 symbol 表示五行（受 element/c 约束）。
;;   - 内部顺生次序采用：
;;       wood -> fire -> earth -> metal -> water -> wood
;;     将其编码为索引 0..4 上的“环”，生克关系通过模 5 运算实现。
;; ============================================================

;; ------------------------------------------------------------
;; 五行类型（element/c）与枚举列表
;; ------------------------------------------------------------

(define element/c
  (or/c 'wood 'fire 'earth 'metal 'water))

;; 有序五行列表，作为“标准顺生顺序”的基础：
;;   wood -> fire -> earth -> metal -> water -> wood
(define element-list
  (list 'wood 'fire 'earth 'metal 'water))

;; 内部向量形式，便于 index->element 使用
(define element-vector
  (list->vector element-list))

;; ------------------------------------------------------------
;; 基础接口
;;
;; element? : any/c -> boolean?
;;   - 判断一个值是否为合法的五行 symbol。
;;
;; element-list : -> (listof element/c)
;;   - 返回五行的有序列表。
;;
;; element->index : element/c -> (integer-in 0 4)
;;   - 将一个五行映射为 0..4 的整数索引。
;;
;; index->element : (integer-in 0 4) -> element/c
;;   - 将索引映射回对应的五行。
;; ------------------------------------------------------------

(define (element? x)
  (and (symbol? x)
       (ormap (λ (e) (eq? e x)) element-list)))

(define (element->index e)
  (unless (element? e)
    (error 'element->index
           "expected element symbol in ~a, got: ~a"
           element-list e))
  (let loop ([lst element-list]
             [i   0])
    (cond
      [(null? lst)
       (error 'element->index
              "internal error: element ~a not found in element-list" e)]
      [(eq? (car lst) e) i]
      [else (loop (cdr lst) (add1 i))])))

(define (index->element i)
  (unless (and (integer? i) (<= 0 i) (<= i 4))
    (error 'index->element
           "expected index in [0,4], got: ~a" i))
  (vector-ref element-vector i))

;; ------------------------------------------------------------
;; 相生关系接口
;;
;; 传统顺生次序（用于语义说明）：
;;   木 -> 火 -> 土 -> 金 -> 水 -> 木
;;
;; element-sheng-target : element/c -> element/c
;;   - “我生谁”：返回 e 顺生产生的下一行。
;;
;; element-sheng-source : element/c -> element/c
;;   - “谁生我”：返回生出 e 的上一行。
;;
;; element-sheng? : element/c element/c -> boolean?
;;   - 判断 a 是否“生” b：
;;       若 b = element-sheng-target(a) 则为 #t，否则 #f。
;; ------------------------------------------------------------

(define (element-sheng-target e)
  (define i (element->index e))
  (index->element (modulo (+ i 1) 5)))

(define (element-sheng-source e)
  (define i (element->index e))
  ;; 上一行：i - 1 (mod 5)
  (index->element (modulo (+ i 4) 5)))

(define (element-sheng? a b)
  (and (element? a)
       (element? b)
       (eq? (element-sheng-target a) b)))

;; ------------------------------------------------------------
;; 相克关系接口
;;
;; 传统相克关系：
;;   木克土、土克水、水克火、火克金、金克木
;;
;; 在顺生次序编码为 [wood fire earth metal water] 时：
;;   ke-target = index + 2 (mod 5)
;;   ke-source = index - 2 (mod 5)
;;
;; element-ke-target : element/c -> element/c
;;   - “我克谁”：返回 e 所克制的那一行。
;;
;; element-ke-source : element/c -> element/c
;;   - “谁克我”：返回克制 e 的那一行。
;;
;; element-ke? : element/c element/c -> boolean?
;;   - 判断 a 是否“克” b：
;;       若 b = element-ke-target(a) 则为 #t，否则 #f。
;; ------------------------------------------------------------

(define (element-ke-target e)
  (define i (element->index e))
  (index->element (modulo (+ i 2) 5)))

(define (element-ke-source e)
  (define i (element->index e))
  ;; 谁克我：index - 2 (mod 5)
  (index->element (modulo (+ i 3) 5))) ; i-2 ≡ i+3 (mod 5)

(define (element-ke? a b)
  (and (element? a)
       (element? b)
       (eq? (element-ke-target a) b)))

;; ------------------------------------------------------------
;; 比和关系接口
;;
;; element-same? : element/c element/c -> boolean?
;;   - 判断两者是否“同一五行”（同气相求）。
;;   - 语义：在双方都是合法五行的前提下，简单相等比较。
;; ------------------------------------------------------------

(define (element-same? a b)
  (and (element? a)
       (element? b)
       (eq? a b)))

;; ------------------------------------------------------------
;; 对外导出及其 contract
;; ------------------------------------------------------------

(provide
  element/c
  element-list
  (contract-out
   [element?             (-> any/c boolean?)]
   [element->index       (-> element/c (integer-in 0 4))]
   [index->element       (-> (integer-in 0 4) element/c)]
   [element-sheng-target (-> element/c element/c)]
   [element-sheng-source (-> element/c element/c)]
   [element-sheng?       (-> element/c element/c boolean?)]
   [element-ke-target    (-> element/c element/c)]
   [element-ke-source    (-> element/c element/c)]
   [element-ke?          (-> element/c element/c boolean?)]
   [element-same?        (-> element/c element/c boolean?)]))

;; ------------------------------------------------------------
;; 单元测试：module+ test
;;   raco test wuxing-core.rkt
;; ------------------------------------------------------------

(module+ test
  (require rackunit)

  ;; 基本形状与 element? 判定
  (test-case
   "element-list & element?"
   (check-equal? element-list '(wood fire earth metal water))
   (for ([e element-list])
     (check-true (element? e)))
   (check-false (element? 'foo))
   (check-false (element? 42))
   (check-false (element? "wood")))

  ;; index 映射互逆
  (test-case
   "element <-> index round trip"
   (for ([i (in-range 0 5)])
     (define e (index->element i))
     (check-true (element? e))
     (check-equal? (element->index e) i))
   (for ([e element-list])
     (define i (element->index e))
     (check-true (and (integer? i) (<= 0 i) (<= i 4)))
     (check-eq? (index->element i) e)))

  ;; 相生：顺生、顺生一圈回原位、source 逆向
  (test-case
   "sheng cycle"
   ;; 显式检查一圈顺生
   (check-eq? (element-sheng-target 'wood)  'fire)
   (check-eq? (element-sheng-target 'fire)  'earth)
   (check-eq? (element-sheng-target 'earth) 'metal)
   (check-eq? (element-sheng-target 'metal) 'water)
   (check-eq? (element-sheng-target 'water) 'wood)
   ;; 一圈回来
   (check-eq?
    (let loop ([e 'wood] [n 5])
      (if (zero? n)
          e
          (loop (element-sheng-target e) (sub1 n))))
    'wood)
   ;; source 逆向
   (check-eq? (element-sheng-source 'fire)  'wood)
   (check-eq? (element-sheng-source 'earth) 'fire)
   (check-eq? (element-sheng-source 'metal) 'earth)
   (check-eq? (element-sheng-source 'water) 'metal)
   (check-eq? (element-sheng-source 'wood)  'water)
   ;; element-sheng?
   (check-true  (element-sheng? 'wood 'fire))
   (check-false (element-sheng? 'wood 'earth)))

  ;; 相克：target/source 与传统关系一致
  (test-case
   "ke relations"
   ;; 我克谁
   (check-eq? (element-ke-target 'wood)  'earth) ; 木克土
   (check-eq? (element-ke-target 'earth) 'water) ; 土克水
   (check-eq? (element-ke-target 'water) 'fire)  ; 水克火
   (check-eq? (element-ke-target 'fire)  'metal) ; 火克金
   (check-eq? (element-ke-target 'metal) 'wood)  ; 金克木
   ;; 谁克我
   (check-eq? (element-ke-source 'earth) 'wood)
   (check-eq? (element-ke-source 'water) 'earth)
   (check-eq? (element-ke-source 'fire)  'water)
   (check-eq? (element-ke-source 'metal) 'fire)
   (check-eq? (element-ke-source 'wood)  'metal)
   ;; element-ke?
   (check-true  (element-ke? 'wood 'earth))
   (check-false (element-ke? 'wood 'fire)))

  ;; 比和
  (test-case
   "same relation"
   (check-true  (element-same? 'wood 'wood))
   (check-false (element-same? 'wood 'fire)))
)
