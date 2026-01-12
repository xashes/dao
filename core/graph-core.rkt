#lang racket

;; graph-core.rkt
;;
;; 功能定位：
;;   - 定义“关系类型”的统一规范（relation-kind）。
;;   - 提供对关系类型的分类：动态 / 静态。
;;   - 提供通用图工具函数（如 ensure-vertex!）。
;;   - 不构造任何具体图，不持有全局 knowledge-graph。

(require racket/contract
         graph)

;; ------------------------------------------------------------
;; 1. 关系类型：relation-kind
;;
;; 设计原则：
;;   - 尽量少、尽量抽象。
;;   - 动态关系：'生 '克 '旺 '死
;;   - 理论区分关系：'河图 '先天 '后天
;;   - 静态对应（方位、季节等）不需 relation（用 #f 表示）。
;; ------------------------------------------------------------

(define relation-kind/c
  (or/c '生
        '克
        '旺
        '死
        '河图
        '先天
        '后天))

(define (relation-kind? x)
  (and (symbol? x)
       (relation-kind/c x)))

;; 动态关系？（需要用“有向边”表示的关系）
(define (dynamic-relation? r)
  (and (relation-kind? r)
       (memq r '(生 克 旺 死))))

;; 静态关系？（本身是某种“体系标记”，不表示能量流向）
;; 注意：这里仅指 '河图 / '先天 / '后天 这类；方位/季节那种对应，直接用 #f。
(define (static-relation? r)
  (and (relation-kind? r)
       (memq r '(河图 先天 后天))))

;; ------------------------------------------------------------
;; 2. source 推荐写法（不做强制约束）
;;
;;   建议使用的 symbol：
;;     '淮南子
;;     '邹衍
;;     '董仲舒
;;     '内经
;;     '月令
;;     '三合
;;     '河图
;;     '时则
;;   实际使用时不强制限制，保持扩展空间。
;; ------------------------------------------------------------

(define (source-symbol? x)
  (and (symbol? x)
       (member x '(淮南子 邹衍 董仲舒 内经 月令 三合 河图 时则 传统))
       #t))

;; ------------------------------------------------------------
;; 3. 通用工具：确保顶点存在
;;
;;   ensure-vertex! : graph? any/c -> graph?
;;   若 v 不在图 g 中，则添加之；始终返回 g 本身。
;; ------------------------------------------------------------

(define (ensure-vertex! g v)
  (unless (has-vertex? g v)
    (add-vertex! g v))
  g)

;; ------------------------------------------------------------
;; 4. 导出
;; ------------------------------------------------------------

(provide
 (contract-out
  [relation-kind/c   flat-contract?]
  [relation-kind?    (-> any/c boolean?)]
  [dynamic-relation? (-> any/c boolean?)]
  [static-relation?  (-> any/c boolean?)]
  [source-symbol?    (-> any/c boolean?)]
  [ensure-vertex!    (-> graph? any/c graph?)]))
