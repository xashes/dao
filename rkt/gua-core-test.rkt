#lang racket

;; 单元测试 & 用法示例：配合 gua-core.rkt 使用
;;
;; 用法：
;;   1. 确保 gua-core.rkt 和本文件在同一目录下
;;   2. 在该目录执行：
;;        racket gua-core-test.rkt
;;      或在 DrRacket 里点击 Run

(require rackunit          ; 断言库
         rackunit/text-ui  ; 控制台运行测试
         "gua-core.rkt")   ; 被测模块

;; 定义一个总测试套件，包含多组测试用例
(define gua-core-tests
  (test-suite
   "gua-core full API tests (list version, renamed functions)"

   ;; ------------------------------------------------------------
   ;; 1. 从 bit 列表构造六爻卦：
   ;;    演示 make-gua-from-bits / gua? / gua-width /
   ;;    gua-bits-list / gua->int / yao-ref 的基础用法
   ;; ------------------------------------------------------------
   (test-case
    "construct hexagram from bits list"
    ;; 构造一个六爻卦，自下而上为：阳 阴 阳 阴 阳 阴
    (define g (make-gua-from-bits '(1 0 1 0 1 0)))

    ;; gua? 用于判断一个值是不是 gua-core 定义的 Gua 值
    (check-true (gua? g))

    ;; 宽度应该是 6（六爻卦）
    (check-equal? (gua-width g) 6)

    ;; 自下而上的 bit 列表应该与构造时一致
    (check-equal? (gua-bits-list g) '(1 0 1 0 1 0))

    ;; 整数编码：bit0 = 1, bit2 = 1, bit4 = 1 → 1 + 4 + 16 = 21
    (check-equal? (gua->int g) 21)

    ;; yao-ref：按位置从下往上访问单爻
    (check-equal? (yao-ref g 0) 1) ; 初爻：阳
    (check-equal? (yao-ref g 1) 0) ; 二爻：阴
    (check-equal? (yao-ref g 2) 1) ; 三爻：阳
    (check-equal? (yao-ref g 3) 0) ; 四爻：阴
    (check-equal? (yao-ref g 4) 1) ; 五爻：阳
    (check-equal? (yao-ref g 5) 0)) ; 上爻：阴

   ;; ------------------------------------------------------------
   ;; 2. 从整数 + 宽度构造六爻卦：
   ;;    演示 make-gua-from-int 与 make-gua-from-bits 的 round-trip 关系
   ;; ------------------------------------------------------------
   (test-case
    "construct hexagram from int and width"
    ;; bits-int = 21（二进制 010101，自下而上 1 0 1 0 1 0），宽度 6
    (define g (make-gua-from-int 21 6))

    ;; 依然是一个合法的 Gua
    (check-true (gua? g))

    ;; 宽度 6
    (check-equal? (gua-width g) 6)

    ;; 还原成列表，与预期一致
    (check-equal? (gua-bits-list g) '(1 0 1 0 1 0))

    ;; 再次转回整数，应仍为 21
    (check-equal? (gua->int g) 21))

   ;; ------------------------------------------------------------
   ;; 3. 三爻卦示例：演示 trigram? / hexagram? 的用法
   ;; ------------------------------------------------------------
   (test-case
    "trigram vs hexagram predicates"
    ;; 自下而上：阳 阳 阴
    (define g3 (make-gua-from-bits '(1 1 0)))

    ;; 宽度为 3
    (check-equal? (gua-width g3) 3)

    ;; 是三爻卦，但不是六爻卦
    (check-true  (trigram? g3))
    (check-false (hexagram? g3))

    ;; 整数编码：bit0 = 1, bit1 = 1, bit2 = 0 → 1 + 2 = 3
    (check-equal? (gua->int g3) 3)

    ;; 访问单爻
    (check-equal? (yao-ref g3 0) 1) ; 初爻：阳
    (check-equal? (yao-ref g3 1) 1) ; 二爻：阳
    (check-equal? (yao-ref g3 2) 0)) ; 上爻：阴

   ;; ------------------------------------------------------------
   ;; 4. gua? 判别：既要对 Gua 返回 #t，对非 Gua 返回 #f
   ;; ------------------------------------------------------------
   (test-case
    "gua? predicate behavior"
    (define g (make-gua-from-bits '(1 0 1 0 1 0)))
    (check-true  (gua? g))
    (check-false (gua? 42))
    (check-false (gua? '(1 0 1)))
    (check-false (gua? "not-a-gua")))

   ;; ------------------------------------------------------------
   ;; 5. yao-ref 越界访问：应抛出异常
   ;; ------------------------------------------------------------
   (test-case
    "yao-ref out of range"
    (define g (make-gua-from-bits '(1 0 1 0 1 0)))
    ;; 位置为 -1：非法
    (check-exn exn:fail?
      (lambda () (yao-ref g -1)))
    ;; 位置等于 width：非法（最大合法 index = width - 1）
    (check-exn exn:fail?
      (lambda () (yao-ref g (gua-width g))))
    ;; 大于 width 的位置同样非法
    (check-exn exn:fail?
      (lambda () (yao-ref g (+ 10 (gua-width g))))))

   ;; ------------------------------------------------------------
   ;; 6. make-gua-from-bits 的非法输入：空列表 / 列表元素非 0/1
   ;; ------------------------------------------------------------
   (test-case
    "make-gua-from-bits invalid inputs"
    ;; 空列表：不允许
    (check-exn exn:fail?
      (lambda () (make-gua-from-bits '())))
    ;; 元素不是 0 或 1：不允许
    (check-exn exn:fail?
      (lambda () (make-gua-from-bits '(1 2 0))))
    (check-exn exn:fail?
      (lambda () (make-gua-from-bits '(1 -1 0))))
    (check-exn exn:fail?
      (lambda () (make-gua-from-bits '(1 "x" 0)))))

   ;; ------------------------------------------------------------
   ;; 7. make-gua-from-int 的非法输入：
   ;;    - width 非正
   ;;    - bits-int 为负
   ;;    - bits-int 超出 [0, 2^width - 1]
   ;; ------------------------------------------------------------
   (test-case
    "make-gua-from-int invalid inputs"
    ;; width 必须是正整数
    (check-exn exn:fail?
      (lambda () (make-gua-from-int 0 0)))
    (check-exn exn:fail?
      (lambda () (make-gua-from-int 0 -1)))
    ;; bits-int 必须是非负整数
    (check-exn exn:fail?
      (lambda () (make-gua-from-int -1 6)))
    ;; bits-int 不能超过允许范围
    (let* ([width 6]
           [max-bits (sub1 (arithmetic-shift 1 width))]
           [too-big  (+ max-bits 1)])
      (check-exn exn:fail?
        (lambda () (make-gua-from-int too-big width)))))

   ;; ------------------------------------------------------------
   ;; 8. 整数与列表的 round-trip：
   ;;    演示“跨语言整数编码”的典型使用方式
   ;; ------------------------------------------------------------
   (test-case
    "int <-> bits-list round trip"
    ;; 任意一个 bit 列表
    (define bits '(1 1 0 1 0 0))
    (define g   (make-gua-from-bits bits))
    (define n   (gua->int g))
    ;; 从整数 & 宽度再构造回来
    (define g2  (make-gua-from-int n (gua-width g)))
    ;; 结果的 bit 列表应与最初相同
    (check-equal? (gua-bits-list g2) bits))

   ;; ------------------------------------------------------------
   ;; 9. 调用模块自带的 self-test：作为集成测试
   ;; ------------------------------------------------------------
   (test-case
    "call self-test from gua-core"
    ;; 如果 self-test 内部有任何断言不通过，会抛异常，导致本测试失败
    (self-test))))

;; 在命令行运行本文件时，执行所有测试并打印结果
(run-tests gua-core-tests)
