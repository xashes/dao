#lang racket

(require racket/contract)

;; ============================================================
;; 通用 slot 系统数据结构（纯数据，无查询函数）
;;
;; 用于表示：
;;   - 一套理论系统内部的一组 slot（位置）
;;   - 以及在这些 slot 上挂载的多个“层”（layer）：
;;       比如 trigram / direction / number / element ...
;; ============================================================

;; layer-key：用 symbol 标识一个“层”
;;   例如：'trigram, 'direction, 'number, 'element, 'jieqi ...
(define layer-key/c symbol?)

;; slot-system 结构：
;;   name   : symbol，系统名字，如 'xiantian-bagua, 'houtian-bagua ...
;;   slots  : (vectorof any/c)，每个元素是一个 slot-id（可以是整数/符号）
;;   layers : hash-table，键为 layer-key，值为“与 slots 对齐的向量”
;;
;;   约束：
;;     - 对于任一 layer，其 vector 长度必须等于 slots 的长度。
;;     - 同一系统下，所有 layer 都共享同一组 slots（只是贴的东西不一样）。
(struct slot-system (name slots layers)
  #:transparent)

;; slot-system? 已自动生成

;; ------------------------------------------------------------
;; 构造函数：make-slot-system
;;
;;   name        : symbol，系统名
;;   slots-list  : (listof any/c)，slot 序列
;;   layer-alist : (listof (cons layer-key vector-of-values))
;;
;;   返回：
;;     slot-system，内部会将 slots-list 变成 vector，
;;     并检查每个 layer 的 vector 长度是否与 slots 一致。
;; ------------------------------------------------------------

(define (make-slot-system name slots-list layer-alist)
  (define slots-vec (list->vector slots-list))
  (define n (vector-length slots-vec))
  ;; 检查每个 layer 的长度
  (for ([kv layer-alist])
    (define key (car kv))
    (define vec (cdr kv))
    (unless (= (vector-length vec) n)
      (error 'make-slot-system
             "layer ~a length ~a does not match slots length ~a"
             key (vector-length vec) n)))
  ;; 构造 layers hash
  (define layers-hash
    (for/hash ([kv layer-alist])
      (values (car kv) (cdr kv))))
  (slot-system name slots-vec layers-hash))

;; ------------------------------------------------------------
;; 一点点合约导出（以后可以放进一个独立模块）
;; ------------------------------------------------------------

(provide
  layer-key/c
  slot-system?
  (contract-out
   [make-slot-system
    (-> symbol?
        (listof any/c)
        (listof (cons/c layer-key/c vector?))
        slot-system?)]))
