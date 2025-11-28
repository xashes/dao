"""
tests/test_core.py

对 yijing.core.GuaCore 进行单元测试与用法示例。

测试目标
--------
1. 确认 Core 公理是否被正确实现：
   - 阴 = 0，阳 = 1
   - bit0 对应初爻（最下），bit(width-1) 对应最上爻
   - bits 的编码/解码正确

2. 覆盖常见用法：
   - 直接用 bits + 默认 width=6 构造六爻卦
   - 用 bits_list 构造三爻/六爻卦
   - 读取单个爻（yao）
   - 展开为 bits_list（to_bits_list）
   - is_trigram / is_hexagram 的判断

3. 覆盖常见错误场景：
   - width 非正
   - bits 超出合法范围
   - bits_list 为空
   - bits_list 中有非法元素（非 0/1）
   - 访问越界爻位
"""

import pytest

from dao.core import (
    GuaCore,
    Bit,
    TrigramId,
    HexagramId,
)


# ----------------------------------------------------------------------
# 基础构造与属性测试
# ----------------------------------------------------------------------


def test_default_width_is_hexagram():
    """
    不传 width 时，默认应该是 6（六爻卦）。
    """
    g = GuaCore(bits=0b010101)
    assert g.width == 6
    assert g.bits == 0b010101
    assert g.is_hexagram
    assert not g.is_trigram


def test_explicit_trigram_width_3():
    """
    显式指定 width=3，用于三爻卦（八卦）。
    比如：101 表示 下阳、中阴、上阳。
    """
    g = GuaCore(bits=0b101, width=3)
    assert g.width == 3
    assert g.bits == 0b101
    assert g.is_trigram
    assert not g.is_hexagram

    # 检查自下而上爻值
    assert g.yao(0) == 1  # 初爻 阳
    assert g.yao(1) == 0  # 二爻 阴
    assert g.yao(2) == 1  # 三爻 阳


def test_construct_from_bits_list_hexagram():
    """
    使用 from_bits_list 从自下而上的 bit 列表构造六爻卦。
    示例： [1, 0, 1, 0, 1, 0] 表示
        初爻: 阳
        二爻: 阴
        三爻: 阳
        四爻: 阴
        五爻: 阳
        上爻: 阴
    """
    bits_list: list[Bit] = [1, 0, 1, 0, 1, 0]
    g = GuaCore.from_bits_list(bits_list)

    # width 应与列表长度一致
    assert g.width == 6

    # round-trip：再展开，应该和原来一样
    assert g.to_bits_list() == bits_list


def test_construct_from_bits_list_trigram():
    """
    使用 from_bits_list 构造三爻卦。
    示例： [0, 0, 0] = 三条阴爻。
    """
    bits_list: list[Bit] = [0, 0, 0]
    g = GuaCore.from_bits_list(bits_list)
    assert g.width == 3
    assert g.bits == 0  # 全阴 -> bits=0
    assert g.is_trigram
    assert g.to_bits_list() == bits_list


# ----------------------------------------------------------------------
# 公理验证：编码顺序与取值
# ----------------------------------------------------------------------


def test_bottom_is_bit0_and_top_is_highest_bit():
    """
    核心公理验证：
    - bit0 是初爻（最下）
    - 最高位 bit 是最上爻
    """
    # 初爻为阳，其余为阴
    g1 = GuaCore.from_bits_list([1, 0, 0, 0, 0, 0])
    assert g1.bits == 1
    assert g1.yao(0) == 1  # 初爻
    assert g1.yao(5) == 0  # 上爻

    # 仅最上爻为阳，其余为阴
    g2 = GuaCore.from_bits_list([0, 0, 0, 0, 0, 1])
    assert g2.bits == (1 << 5)  # 32
    assert g2.yao(0) == 0
    assert g2.yao(5) == 1


def test_roundtrip_bits_list_and_bits_value():
    """
    列表 → GuaCore → bits → GuaCore → 列表 的往返测试。
    确保编码和解码都是双向一致的。
    """
    bits_list: list[Bit] = [1, 1, 0, 1, 0, 0]
    g = GuaCore.from_bits_list(bits_list)

    # 再用 bits 和 width 重建一个
    g2 = GuaCore(bits=g.bits, width=g.width)

    assert g2.to_bits_list() == bits_list
    assert g2.bits == g.bits
    assert g2.width == g.width


# ----------------------------------------------------------------------
# 类型别名（TrigramId / HexagramId）的简单用法展示
# ----------------------------------------------------------------------


def test_trigram_and_hexagram_id_usage_example():
    """
    TrigramId / HexagramId 是语义上的类型别名，不改变底层 int 的含义，
    只是让代码在阅读时更容易区分「三爻卦 ID」和「六爻卦 ID」。
    """
    # 比如：0b111 三爻卦 可以作为一个 TrigramId
    trigram_id = TrigramId(0b111)
    assert int(trigram_id) == 0b111

    # 0b111111 六爻卦 ID
    hexagram_id = HexagramId(0b111111)
    assert int(hexagram_id) == 0b111111

    # 你可以在后续的 metadata/graph 中用这些别名标注字段类型，
    # 提高可读性，但本质仍是 int。
    assert isinstance(trigram_id, int)
    assert isinstance(hexagram_id, int)


# ----------------------------------------------------------------------
# 错误场景与异常测试
# ----------------------------------------------------------------------


def test_invalid_width_raises():
    """
    width 必须为正数。width <= 0 应该抛出 ValueError。
    """
    with pytest.raises(ValueError):
        GuaCore(bits=0, width=0)

    with pytest.raises(ValueError):
        GuaCore(bits=0, width=-3)


def test_bits_out_of_range_raises():
    """
    bits 的合法范围为 [0, 2^width - 1]。
    超出这个范围应抛出 ValueError。
    """
    # width=3 时，最大 bits = 0b111 = 7
    with pytest.raises(ValueError):
        GuaCore(bits=8, width=3)  # 超出范围

    # width=6 时，最大 bits = 0b111111 = 63
    with pytest.raises(ValueError):
        GuaCore(bits=64, width=6)  # 超出范围

    # 负数也不允许
    with pytest.raises(ValueError):
        GuaCore(bits=-1, width=6)


def test_empty_bits_list_raises():
    """
    from_bits_list 不允许空列表。
    否则 width=0，没有意义。
    """
    with pytest.raises(ValueError):
        GuaCore.from_bits_list([])


def test_bits_list_with_invalid_values_raises():
    """
    bits_list 中的元素必须是 0 或 1。
    如果传入其他值（包括 True/False 以外的内容），应该抛出 ValueError。
    """
    with pytest.raises(ValueError):
        GuaCore.from_bits_list([0, 2, 1])  # 包含 2

    with pytest.raises(ValueError):
        GuaCore.from_bits_list([0, -1, 1])  # 包含 -1

    with pytest.raises(ValueError):
        GuaCore.from_bits_list([0, 0.5, 1])  # 浮点数


def test_yao_out_of_range_raises():
    """
    访问超出 [0, width-1] 的爻位时，应抛出 IndexError。
    """
    g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])

    with pytest.raises(IndexError):
        _ = g.yao(-1)

    with pytest.raises(IndexError):
        _ = g.yao(6)


# ----------------------------------------------------------------------
# 展示：如何在测试里模拟“正常使用场景”
# ----------------------------------------------------------------------


def test_usage_scenario_example():
    """
    模拟一个正常使用场景，展示 Core 如何被上层调用。

    场景：
    - 已知某卦的爻为：下三爻全阳，上三爻全阴。
    - 使用 from_bits_list 构造本体。
    - 上层（未来的 L2/L3）只依赖 GuaCore 提供的接口，而不关心内部实现细节。
    """
    # 下阳阳阳，上阴阴阴
    bits_list: list[Bit] = [1, 1, 1, 0, 0, 0]
    g = GuaCore.from_bits_list(bits_list)

    # 上层关心的是：能可靠地取到某一爻的值
    assert g.yao(0) == 1  # 初爻 阳
    assert g.yao(1) == 1  # 二爻 阳
    assert g.yao(2) == 1  # 三爻 阳
    assert g.yao(3) == 0  # 四爻 阴
    assert g.yao(4) == 0  # 五爻 阴
    assert g.yao(5) == 0  # 上爻 阴

    # 以及：可以随时展开为列表，用于可视化或传给前端
    assert g.to_bits_list() == bits_list
