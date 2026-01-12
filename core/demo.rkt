#lang racket

;; 演示五行动态图 / 静态图的基本用法
;; - 查询节点、边
;; - 查询某个节点的关系（relation / source）
;; - 导出为 Graphviz DOT 文件

(require graph
         "graph-core.rkt"
         "wuxing-graph.rkt")

;;----------------------------------------
;; 一些小工具：友好打印
;;----------------------------------------

(define (show-vertices g name)
  (printf "=== ~a：所有节点 ===~n" name)
  (for ([v (in-list (sort (get-vertices g) symbol<?))])
    (printf "  ~a~n" v))
  (newline))

(define (show-edges g name)
  (printf "=== ~a：所有边 ===~n" name)
  (for ([e (in-list (get-edges g))])
    (match e
      [(list u v)
       (printf "  ~a -> ~a  relation=~s  source=~s~n"
               u v
               (relation u v #:default #f)
               (source   u v #:default #f))]))
  (newline))

;;----------------------------------------
;; 针对单个节点的查询示例
;;----------------------------------------

(define (show-node-relations g name v)
  (printf "=== 在 ~a 中考察节点：~a ===~n" name v)

  ;; 出邻居（对有向图来说是出边；对无向图就是普通邻居）
  (define neighbors (get-neighbors g v))
  (printf "  邻居节点：~a~n" neighbors)

  (for ([to (in-list neighbors)])
    (printf "  ~a -> ~a : relation=~s  source=~s~n"
            v to
            (relation v to #:default #f)
            (source   v to #:default #f)))

  (newline))

;;----------------------------------------
;; 导出 Graphviz DOT
;;----------------------------------------
;; 这里演示：
;; - 用 relation 作为边的 label
;; - 用 source 作为边的 tooltip（鼠标悬停时可见，如果你用 GUI 查看）
;; - 顶点 label 就是节点本身（转成字符串）

(define (write-dot-file g filename)
  (call-with-output-file filename
    (lambda (out)
      (graphviz g
                #:output out
                #:edge-attributes
                (list
                 ;; 边上的文字：关系名（生/克/旺/耗/泄/合/冲/刑/害/...）
                 (list 'label
                       (lambda (u v)
                         (define rel (relation u v #:default #f))
                         (if rel
                             (format "~a" rel)
                             "")))
                 ;; 提示：来源，如 “淮南子 河图”、“三命通会 三合”
                 (list 'tooltip
                       (lambda (u v)
                         (define src (source u v #:default #f))
                         (if src
                             (format "~a" src)
                             ""))))
                #:vertex-attributes
                (list
                 ;; 顶点 label：直接用节点的字符串形式
                 (list 'label
                       (lambda (v)
                         (format "~a" v))))))
    #:exists 'truncate/replace)
  (printf "已写出 DOT 文件：~a~n" filename))

;;----------------------------------------
;; 主演示函数
;;----------------------------------------

(define (demo)
  ;; 1. 打印两个图的节点 & 边
  (show-vertices wuxing-graph-dynamic "五行动态图（有向：生/克/旺/耗/泄 等）")
  (show-edges    wuxing-graph-dynamic "五行动态图")

  (show-vertices wuxing-graph-static "五行静态图（无向：对应方位/季节/藏干/星曜 等）")
  (show-edges    wuxing-graph-static "五行静态图")

  ;; 2. 针对 “木” 做一个局部检查
  (show-node-relations wuxing-graph-dynamic "五行动态图" '木)
  (show-node-relations wuxing-graph-static "五行静态图" '木)

  ;; 3. 导出 Graphviz DOT 文件
  ;;    你也可以把文件名改成 "temp.dot" 来测试
  (write-dot-file wuxing-graph-dynamic "wuxing-dynamic.dot")
  (write-dot-file wuxing-graph-static "wuxing-static.dot")

  (printf "~n你可以用 dot 命令渲染，例如：~n")
  (printf "  dot -Tpng wuxing-dynamic.dot -o wuxing-dynamic.png~n")
  (printf "  dot -Tpng wuxing-static.dot  -o wuxing-static.png~n"))

;; 直接运行本文件时执行 demo
(module+ main
  (demo))
