"""
tests/test_ops_basic.py

对 dao.ops_basic 中的基础运算函数进行单元测试与用法展示。

覆盖内容
--------
1. 上下卦拆分：
   - split_trigrams 对典型六爻卦的拆分是否正确
   - 非 width=6 的输入是否正确抛异常

2. 上下卦组合：
   - combine_trigrams 是否与 split_trigrams 构成往返
   - 非 width=3 的下卦/上卦是否抛异常

3. ID 型别名辅助：
   - hexagram_id / trigram_id 的基本用法

4. 基础变爻：
   - 单一爻位翻转
   - 多个爻位翻转
   - 越界爻位是否抛异常

测试目的
--------
- 确认 L2.a 的基础接口在 bits 层面是自洽的。
- 为后续 L1.B/L1.C 的 schema 设计提供真实使用感受。
"""

import pytest

from dao.core import GuaCore
from dao.ops_basic import (
    split_trigrams,
    combine_trigrams,
    flip_yao,
    hexagram_id,
    trigram_id,
)


# ----------------------------------------------------------------------
# 上下卦拆分与组合
# ----------------------------------------------------------------------


def test_split_trigrams_from_hexagram():
    """
    测试从一个六爻卦中拆出上下卦（各三爻）。

    示例卦：
        bits_list = [1, 0, 1, 0, 1, 0]
        对应自下而上：
            初爻: 1
            二爻: 0
            三爻: 1
            四爻: 0
            五爻: 1
            上爻: 0

        下卦 (0~2): [1, 0, 1]
        上卦 (3~5): [0, 1, 0]
    """
    g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])
    lower, upper = split_trigrams(g)

    # 下卦、上卦都应该是 width=3 的三爻卦
    assert lower.width == 3
    assert upper.width == 3

    assert lower.to_bits_list() == [1, 0, 1]
    assert upper.to_bits_list() == [0, 1, 0]


def test_split_trigrams_requires_width_6():
    """
    split_trigrams 只接受 width=6 的卦。
    其他 width 的输入应该抛出 ValueError。
    """
    # 三爻卦
    g3 = GuaCore.from_bits_list([1, 0, 1])
    with pytest.raises(ValueError):
        split_trigrams(g3)

    # width=4 之类的奇怪情况也不支持
    g4 = GuaCore(bits=0b1010, width=4)
    with pytest.raises(ValueError):
        split_trigrams(g4)


def test_combine_trigrams_roundtrip():
    """
    combine_trigrams 与 split_trigrams 应该构成往返。

    即：
        g2 = combine_trigrams(*split_trigrams(g1))
        则 g2 应与 g1 在 bits 与 width 上完全相同。
    """
    original = GuaCore.from_bits_list([1, 1, 0, 1, 0, 0])
    lower, upper = split_trigrams(original)

    combined = combine_trigrams(lower, upper)

    assert combined.width == original.width
    assert combined.bits == original.bits
    assert combined.to_bits_list() == original.to_bits_list()


def test_combine_trigrams_requires_width_3():
    """
    combine_trigrams 要求 lower/upper 都是 width=3 的三爻卦。
    否则抛出 ValueError。
    """
    lower = GuaCore.from_bits_list([1, 0, 1])  # width=3
    upper = GuaCore.from_bits_list([0, 1, 0])  # width=3

    # 正常情况不抛异常
    _ = combine_trigrams(lower, upper)

    # upper 换成六爻卦，应抛异常
    bad_upper = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])
    with pytest.raises(ValueError):
        combine_trigrams(lower, bad_upper)


# ----------------------------------------------------------------------
# HexagramId / TrigramId 用法示例
# ----------------------------------------------------------------------


def test_hexagram_and_trigram_id_usage():
    """
    展示 hexagram_id / trigram_id 的基本用法：
    它们只是更语义化的 int 别名，不改变 bits 的值。
    """
    hex_g = GuaCore.from_bits_list([1, 1, 1, 1, 1, 1])  # 六阳
    tri_g = GuaCore.from_bits_list([0, 1, 0])           # 阴阳阴

    h_id = hexagram_id(hex_g)
    t_id = trigram_id(tri_g)

    assert int(h_id) == hex_g.bits
    assert int(t_id) == tri_g.bits

    # 类型上看，仍然是 int 的子类（NewType 的运行时效果如此）
    assert isinstance(h_id, int)
    assert isinstance(t_id, int)

def test_hexagram_id_requires_width_6():
    """
    hexagram_id 只接受 width=6 的 GuaCore。
    """
    tri_g = GuaCore.from_bits_list([1, 0, 1])  # width=3
    with pytest.raises(ValueError):
        hexagram_id(tri_g)


def test_trigram_id_requires_width_3():
    """
    trigram_id 只接受 width=3 的 GuaCore。
    """
    hex_g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])  # width=6
    with pytest.raises(ValueError):
        trigram_id(hex_g)


# ----------------------------------------------------------------------
# 基础变爻：flip_yao
# ----------------------------------------------------------------------


def test_flip_single_yao():
    """
    测试翻转单个爻位。

    示例：
        原卦：bits_list = [1, 0, 0, 0, 0, 0]
        只翻转初爻(0位)：
        新卦应为：[0, 0, 0, 0, 0, 0]
    """
    g = GuaCore.from_bits_list([1, 0, 0, 0, 0, 0])
    g2 = flip_yao(g, [0])

    assert g.to_bits_list() == [1, 0, 0, 0, 0, 0]  # 原卦不变
    assert g2.to_bits_list() == [0, 0, 0, 0, 0, 0]


def test_flip_multiple_yaos():
    """
    测试同时翻转多个爻位。

    示例：
        原卦：bits_list = [1, 0, 1, 0, 1, 0]
        翻转爻位 [0, 2, 4]（全部是阳）：
        新卦应为：[0, 0, 0, 0, 0, 0]
    """
    g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])
    g2 = flip_yao(g, [0, 2, 4])

    assert g2.to_bits_list() == [0, 0, 0, 0, 0, 0]


def test_flip_yao_out_of_range_raises():
    """
    当 positions 中包含越界爻位时，应抛出 ValueError。
    """
    g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])  # width=6

    with pytest.raises(ValueError):
        flip_yao(g, [-1])

    with pytest.raises(ValueError):
        flip_yao(g, [6])  # 最大有效索引为 5


def test_flip_yao_usage_scenario():
    """
    模拟一个正常使用场景：

    - 给定一个六爻卦
    - 用户选择某几个爻作为“变爻”
    - 内部仅用 flip_yao 在 bit 层面实现翻转，
      至于如何解释这些变爻，将由后续语义层决定。
    """
    # 原卦：下三阳，上三阴
    g = GuaCore.from_bits_list([1, 1, 1, 0, 0, 0])

    # 用户指定变爻为 [2, 3]（第三爻和第四爻）
    g_changed = flip_yao(g, [2, 3])

    # 手工推导期望结果：
    # 原 bits_list: [1,1,1,0,0,0]
    # 位置 2: 1 -> 0
    # 位置 3: 0 -> 1
    # 结果：       [1,1,0,1,0,0]
    assert g_changed.to_bits_list() == [1, 1, 0, 1, 0, 0]
