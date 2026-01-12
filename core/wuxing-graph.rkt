#lang racket

;; wuxing-graph.rkt
;;
;; 功能：
;;   - 基于 wuxing-data 提供的关系表，构造：
;;       1) 动态五行图（有向、有 relation/source）
;;       2) 静态五行图（无向、有 relation/source）
;;   - 不负责查询逻辑（查询层之后单独设计）。
;;
;; 约定：
;;   - 动态关系：'生 '克 '旺 '死  -> 放入有向图
;;   - 静态关系：'河图 '先天 '后天 以及 relation = #f -> 放入无向图
;;   - 顶点统一为中文 symbol 或整数（数字结点）。

(require racket/contract
         racket/match
         graph
         "graph-core.rkt"
         "wuxing-core.rkt"   ; 目前主要用于提供五行 symbol 集合（如 element-list）
         "wuxing-data.rkt")

;; ------------------------------------------------------------
;; 1. 在某张图上定义 edge property：relation / source
;;
;;   relation : #f 或 relation-kind
;;   source   : (listof symbol)，默认 '()
;; ------------------------------------------------------------

(define (define-edge-properties-for-graph g)
  (define-edge-property g relation #:init #f)
  (define-edge-property g source   #:init '())
  (values relation relation-set! source source-set!))

;; ------------------------------------------------------------
;; 2. 从 wuxing-relations 构造两张图：
;;    - 动态：directed-graph
;;    - 静态：undirected-graph
;; ------------------------------------------------------------

(define (make-wuxing-graphs)
  ;; 2.1 新建两张空图
  (define g-dyn (directed-graph '()))
  (define g-stat (undirected-graph '()))

  ;; 2.2 为两张图定义各自的 edge property
  (define-values (rel-dyn rel-dyn-set! src-dyn src-dyn-set!)
    (define-edge-properties-for-graph g-dyn))
  (define-values (rel-stat rel-stat-set! src-stat src-stat-set!)
    (define-edge-properties-for-graph g-stat))

  ;; 2.3 遍历数据表
  (for ([row (in-list wuxing-relations)])
    (match row
      [(list wu x rel srcs)
       ;; 顶点在两张图中都要保证存在
       (ensure-vertex! g-dyn wu)
       (ensure-vertex! g-dyn x)
       (ensure-vertex! g-stat wu)
       (ensure-vertex! g-stat x)

       ;; 动态关系 -> 有向图
       (cond
         [(and rel (dynamic-relation? rel))
          ;; 有向边：五行 wu -> x
          (add-edge! g-dyn wu x)
          (rel-dyn-set! wu x rel)
          (cond
            [(null? srcs) (void)]
            [(list? srcs) (src-dyn-set! wu x srcs)]
            [else          (src-dyn-set! wu x (list srcs))])]

         ;; 静态关系 -> 无向图
         [else
          ;; 无论 rel 是 #f 还是 '河图/'先天/'后天，都视为静态边
          (add-edge! g-stat wu x)
          (when (and rel (static-relation? rel))
            (rel-stat-set! wu x rel))
          (cond
            [(null? srcs) (void)]
            [(list? srcs) (src-stat-set! wu x srcs)]
            [else          (src-stat-set! wu x (list srcs))])])]))
  (values g-dyn g-stat))

;; 标准五行图实例（建议作为只读结构使用）
(define-values (wuxing-graph-dynamic wuxing-graph-static)
  (make-wuxing-graphs))

;; ------------------------------------------------------------
;; 3. 导出
;; ------------------------------------------------------------

(provide
  ;; 两张标准图实例
  (contract-out
   [wuxing-graph-dynamic graph?] ; 有向：生/克/旺/死
   [wuxing-graph-static  graph?] ; 无向：方位、季节、颜色、河图数等
   [make-wuxing-graphs   (-> (values graph? graph?))])

  ;; 如果查询层想用原始数据表，也可以直接 require wuxing-data.rkt
  )
