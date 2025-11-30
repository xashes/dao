#lang racket

(require racket/contract
         "gua-core.rkt"
         "gua-trigram.rkt"
         "wuxing-core.rkt")  ; <<< 新增：引入五行核心模型

;; ============================================================
;; 模块：gua-trigram-data.rkt
;;
;; 目标：
;;   - 为八个三爻卦（乾、兑、离、震、巽、坎、艮、坤）提供“结构化信息表”。
;;   - 字段只包含结构性 / 可计算的属性：
;;       * 卦 id（与 gua-id 对齐）
;;       * 卦本体（gua）
;;       * 名称（中/拼/英）
;;       * 五行（使用 wuxing-core 中的 element/c）
;;       * 体象、家人
;;       * 先天 / 后天方位
;;       * 先天 / 后天数字
;;   - 不存任何长文本解释（卦辞、爻辞等）。
;; ============================================================

;; ------------------------------------------------------------
;; 枚举类型的合约（先用 symbol，后续可升级为独立类型模块）
;;
;; 说明：
;;   - 五行 element/c 现在完全由 wuxing-core.rkt 提供，
;;     不再在此模块重复定义，以保持单一来源。
;; ------------------------------------------------------------

;; element/c 来自 wuxing-core.rkt
;; (element/c : wood/fire/earth/metal/water)

(define direction/c
  (or/c 'north 'south 'east 'west
        'ne 'nw 'se 'sw
        'center))

(define family/c
  (or/c 'father 'mother
        'eldest-son 'middle-son 'youngest-son
        'eldest-daughter 'middle-daughter 'youngest-daughter))

(define image/c
  (or/c 'heaven 'earth 'thunder 'wind
        'water 'fire 'mountain 'lake))

;; 先天八卦数字：乾1兑2离3震4巽5坎6艮7坤8
(define xiantian-number/c  (integer-in 1 8))

;; 后天数字：洛书九宫：坎1坤2震3巽4中5乾6兑7艮8离9
(define houtian-number/c   (integer-in 1 9))

;; ------------------------------------------------------------
;; TrigramInfo 结构
;; ------------------------------------------------------------

(struct trigram-info
  (id
   gua
   name-zh
   name-py
   name-en
   element
   image
   family
   direction-xiantian
   direction-houtian
   number-xiantian
   number-houtian)
  #:transparent)

;; ------------------------------------------------------------
;; 八卦本体（结构对应约定）
;; ------------------------------------------------------------

(define trigram-kun   (make-trigram-from-bits '(0 0 0))) ; ☷
(define trigram-gen   (make-trigram-from-bits '(0 0 1))) ; ☶
(define trigram-kan   (make-trigram-from-bits '(0 1 0))) ; ☵
(define trigram-xun   (make-trigram-from-bits '(0 1 1))) ; ☴
(define trigram-zhen  (make-trigram-from-bits '(1 0 0))) ; ☳
(define trigram-li    (make-trigram-from-bits '(1 0 1))) ; ☲
(define trigram-dui   (make-trigram-from-bits '(1 1 0))) ; ☱
(define trigram-qian  (make-trigram-from-bits '(1 1 1))) ; ☰

;; ------------------------------------------------------------
;; “序列映射式”数据构建
;; ------------------------------------------------------------

;; 1. 八卦按顺序排出的本体
(define base-guas
  (list trigram-qian
        trigram-dui
        trigram-li
        trigram-zhen
        trigram-xun
        trigram-kan
        trigram-gen
        trigram-kun))

;; 2. 对应的名字（中文 / 拼音 / 英文）
(define names-zh
  '(乾 兑 离 震 巽 坎 艮 坤))

(define names-py
  '("qian" "dui" "li" "zhen" "xun" "kan" "gen" "kun"))

(define names-en
  '("Heaven" "Lake" "Fire" "Thunder" "Wind" "Water" "Mountain" "Earth"))

;; 3. 五行对应：乾兑金，震巽木，坎水，离火，艮坤土
;;   使用来自 wuxing-core 的 element/c 约束：
;;     'metal 'wood 'water 'fire 'earth
(define elements
  '(metal metal fire wood wood water earth earth))

;; 4. 体象对应
(define images
  '(heaven lake fire thunder wind water mountain earth))

;; 5. 家人对应
(define families
  '(father           ; 乾
    youngest-daughter ; 兑
    middle-daughter   ; 离
    eldest-son        ; 震
    eldest-daughter   ; 巽
    middle-son        ; 坎
    youngest-son      ; 艮
    mother))          ; 坤

;; 6. 先天方位
(define directions-xiantian
  '(south   ; 乾南
    se      ; 兑东南
    east    ; 离东
    ne      ; 震东北
    sw      ; 巽西南
    west    ; 坎西
    nw      ; 艮西北
    north)) ; 坤北

;; 7. 后天方位
(define directions-houtian
  '(nw      ; 乾西北
    west    ; 兑西
    south   ; 离南
    east    ; 震东
    se      ; 巽东南
    north   ; 坎北
    ne      ; 艮东北
    sw))    ; 坤西南

;; 8. 先天数字
(define numbers-xiantian
  '(1 2 3 4 5 6 7 8))

;; 9. 后天数字
(define numbers-houtian
  '(6 7 9 3 4 1 8 2))

;; ------------------------------------------------------------
;; all-trigram-info-list
;; ------------------------------------------------------------

(define all-trigram-info-list
  (for/list ([g      (in-list base-guas)]
             [name-zh (in-list names-zh)]
             [name-py (in-list names-py)]
             [name-en (in-list names-en)]
             [elem   (in-list elements)]
             [img    (in-list images)]
             [fam    (in-list families)]
             [dx     (in-list directions-xiantian)]
             [dh     (in-list directions-houtian)]
             [nx     (in-list numbers-xiantian)]
             [nh     (in-list numbers-houtian)])
    (trigram-info
     (gua-id g)
     g
     name-zh
     name-py
     name-en
     elem
     img
     fam
     dx
     dh
     nx
     nh)))

;; ------------------------------------------------------------
;; 索引表（内部使用）
;; ------------------------------------------------------------

(define trigram-by-id
  (for/hash ([info (in-list all-trigram-info-list)])
    (values (trigram-info-id info) info)))

(define trigram-by-gua-id
  (for/hash ([info (in-list all-trigram-info-list)])
    (values (gua-id (trigram-info-gua info)) info)))

(define trigram-by-name-zh
  (for/hash ([info (in-list all-trigram-info-list)])
    (values (trigram-info-name-zh info) info)))

;; ------------------------------------------------------------
;; 查询 API + 小工具
;; ------------------------------------------------------------

(define (all-trigram-infos)
  all-trigram-info-list)

(define (lookup-trigram-by-id id)
  (hash-ref trigram-by-id id
            (λ ()
              (error 'lookup-trigram-by-id
                     "unknown trigram id: ~a" id))))

(define (lookup-trigram-by-gua g)
  (unless (trigram? g)
    (error 'lookup-trigram-by-gua
           "expected trigram, got width=~a" (gua-width g)))
  (define tid (gua-id g))
  (lookup-trigram-by-id tid))

(define (lookup-trigram-by-name-zh name)
  (hash-ref trigram-by-name-zh name
            (λ ()
              (error 'lookup-trigram-by-name-zh
                     "unknown trigram name: ~a" name))))

;; 小工具：直接从 trigram 拿五行
(define (trigram-element g)
  (trigram-info-element (lookup-trigram-by-gua g)))

;; ------------------------------------------------------------
;; 对外导出及其 contract
;; ------------------------------------------------------------

(provide
  (contract-out
   [struct trigram-info
     ([id                 exact-nonnegative-integer?]
      [gua                (and/c gua? trigram?)]
      [name-zh            symbol?]
      [name-py            string?]
      [name-en            string?]
      [element            element/c]        ; <<< 来自 wuxing-core
      [image              image/c]
      [family             family/c]
      [direction-xiantian direction/c]
      [direction-houtian  direction/c]
      [number-xiantian    xiantian-number/c]
      [number-houtian     houtian-number/c])]
   [all-trigram-infos
    (-> (listof trigram-info?))]
   [lookup-trigram-by-id
    (-> exact-nonnegative-integer? trigram-info?)]
   [lookup-trigram-by-gua
    (-> (and/c gua? trigram?) trigram-info?)]
   [lookup-trigram-by-name-zh
    (-> symbol? trigram-info?)]
   [trigram-element
    (-> (and/c gua? trigram?) element/c)]))

;; ============================================================
;; 测试：module+ test + rackunit
;; ============================================================

(module+ test
  (require rackunit)

  ;; 1. 基本数量与唯一性 + 各属性列表长度一致性
  (test-case
   "there are 8 unique trigram infos and aligned attribute lists"
   (define infos (all-trigram-infos))
   (check-equal? (length infos) 8)
   (check-equal?
    (length (remove-duplicates (map trigram-info-id infos)))
    8)
   (check-equal?
    (length (remove-duplicates (map trigram-info-name-zh infos)))
    8)
   ;; 验证各属性列表长度都 == 8
   (check-equal? (length base-guas) 8)
   (check-equal? (length names-zh) 8)
   (check-equal? (length names-py) 8)
   (check-equal? (length names-en) 8)
   (check-equal? (length elements) 8)
   (check-equal? (length images) 8)
   (check-equal? (length families) 8)
   (check-equal? (length directions-xiantian) 8)
   (check-equal? (length directions-houtian) 8)
   (check-equal? (length numbers-xiantian) 8)
   (check-equal? (length numbers-houtian) 8))

  ;; 2. 乾卦检查
  (test-case
   "qian info basic checks"
   (define qi (lookup-trigram-by-name-zh '乾))
   (check-true (trigram? (trigram-info-gua qi)))
   (check-equal? (gua-bits-list (trigram-info-gua qi)) '(1 1 1))
   (check-equal? (trigram-info-name-py qi) "qian")
   (check-true  (element? (trigram-info-element qi))) ; 确保是合法五行
   (check-equal? (trigram-info-element qi) 'metal)
   (check-equal? (trigram-info-image qi) 'heaven)
   (check-equal? (trigram-info-family qi) 'father)
   (check-equal? (trigram-info-direction-xiantian qi) 'south)
   (check-equal? (trigram-info-direction-houtian qi) 'nw)
   (check-equal? (trigram-info-number-xiantian qi) 1)
   (check-equal? (trigram-info-number-houtian qi) 6))

  ;; 3. 通过 gua 查找：坎卦
  (test-case
   "lookup by gua: kan"
   (define g-kan (make-trigram-from-bits '(0 1 0)))
   (define ki (lookup-trigram-by-gua g-kan))
   (check-equal? (trigram-info-name-zh ki) '坎)
   (check-equal? (trigram-info-element ki) 'water)
   (check-true   (element? (trigram-element g-kan)))
   (check-equal? (trigram-element g-kan) 'water)
   (check-equal? (trigram-info-direction-houtian ki) 'north)
   (check-equal? (trigram-info-number-houtian ki) 1))

  ;; 4. id 与 gua-id 一致性简单检查（以离卦为例）
  (test-case
   "id equals gua-id for li"
   (define g-li (make-trigram-from-bits '(1 0 1)))
   (define li-info (lookup-trigram-by-gua g-li))
   (check-equal? (trigram-info-id li-info)
                 (gua-id (trigram-info-gua li-info)))))
