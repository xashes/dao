"""
ops_basic.py

L2.a：基础运算层（Bit-level operations）

设计目标
--------
在不引入任何「语义」的前提下，为 GuaCore 提供最基础的
二进制级别运算函数。这一层只处理 bits 结构，不关心卦名、
五行、方位等解释内容。

当前包含的能力
--------------
1. 上下卦拆分与组合（仅针对六爻卦）：
   - split_trigrams(g): GuaCore(6) -> (lower_trigram, upper_trigram)
   - combine_trigrams(lower, upper): (GuaCore(3), GuaCore(3)) -> GuaCore(6)

2. 基础变爻：
   - flip_yao(g, positions): 在给定爻位列表上翻转阴阳

注意：
- 本模块只依赖 dao.core，不依赖任何 metadata 或语义图。
- 所有函数应尽量设计为「纯函数」：输入不变，返回新实例。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Tuple, List

from .core import GuaCore, TrigramId, HexagramId


# ----------------------------------------------------------------------
# 上下卦拆分与组合
# ----------------------------------------------------------------------


def split_trigrams(g: GuaCore) -> Tuple[GuaCore, GuaCore]:
    """
    将一个六爻卦拆分为下卦和上卦两个三爻卦。

    参数
    ----
    g : GuaCore
        预期是 width=6 的六爻卦。
        目前实现只支持 width=6，如果传入其他 width 会抛出 ValueError。

    返回
    ----
    (lower, upper) : Tuple[GuaCore, GuaCore]
        lower.width == 3，upper.width == 3
        - lower: 取原卦的第 0~2 爻（下三爻）
        - upper: 取原卦的第 3~5 爻（上三爻）

    说明
    ----
    这里不做任何卦名/五行解释，只在 bits 层面做拆分。
    """
    if g.width != 6:
        raise ValueError(
            f"split_trigrams only supports width=6 hexagrams, got width={g.width}"
        )

    # 下卦：bit0~bit2 原样保留
    lower_bits = g.bits & 0b111  # 0b111 == 7

    # 上卦：bit3~bit5 右移 3 位
    upper_bits = (g.bits >> 3) & 0b111

    lower = GuaCore(bits=lower_bits, width=3)
    upper = GuaCore(bits=upper_bits, width=3)
    return lower, upper


def hexagram_id(g: GuaCore) -> HexagramId:
    """
    将六爻卦的 bits 视为 HexagramId（语义型别名）。

    要求
    ----
    - g.width 必须为 6，否则抛出 ValueError。

    说明
    ----
    这里仍然不引入任何具体“卦名”，只是提供一个更语义化的 ID 类型，
    方便后续在 metadata 中用 HexagramId 作为 key。
    """
    if g.width != 6:
        raise ValueError(
            f"hexagram_id expects width=6, got width={g.width}"
        )
    return HexagramId(g.bits)


def trigram_id(g: GuaCore) -> TrigramId:
    """
    将三爻卦的 bits 视为 TrigramId（语义型别名）。

    要求
    ----
    - g.width 必须为 3，否则抛出 ValueError。
    """
    if g.width != 3:
        raise ValueError(
            f"trigram_id expects width=3, got width={g.width}"
        )
    return TrigramId(g.bits)


def combine_trigrams(lower: GuaCore, upper: GuaCore) -> GuaCore:
    """
    将下卦和上卦两个三爻卦组合成一个六爻卦。

    参数
    ----
    lower : GuaCore
        预期为 width=3 的三爻卦，作为下卦（对应六爻卦的 bit0~2）。
    upper : GuaCore
        预期为 width=3 的三爻卦，作为上卦（对应六爻卦的 bit3~5）。

    返回
    ----
    GuaCore
        width=6 的六爻卦，本质上是：
            hex_bits = lower.bits + (upper.bits << 3)

    异常
    ----
    如果 lower.width 或 upper.width 不是 3，则抛出 ValueError。

    说明
    ----
    这个函数与 split_trigrams 构成一对“往返”操作：
        combine_trigrams(*split_trigrams(g)) == g  （在 width=6 的范围内）
    """
    if lower.width != 3 or upper.width != 3:
        raise ValueError(
            f"combine_trigrams expects both lower/upper to have width=3, "
            f"got lower.width={lower.width}, upper.width={upper.width}"
        )

    hex_bits = lower.bits | (upper.bits << 3)
    return GuaCore(bits=hex_bits, width=6)


# ----------------------------------------------------------------------
# 基础变爻：在指定爻位上翻转阴阳
# ----------------------------------------------------------------------


def flip_yao(g: GuaCore, positions: Iterable[int]) -> GuaCore:
    """
    在给定爻位列表上翻转阴阳（0 <-> 1），返回新的 GuaCore。

    参数
    ----
    g : GuaCore
        原卦，可以是 width=3 或 width=6（或其他正整数）。
    positions : Iterable[int]
        需要翻转的爻位集合，使用「自下而上」的索引：
            - 0 表示初爻（最下）
            - g.width-1 表示最上爻

        示例：
            flip_yao(g, [0])        # 只变初爻
            flip_yao(g, [0, 2, 5])  # 同时变多个爻

    返回
    ----
    GuaCore
        新的卦对象，原 g 不会被修改。

    异常
    ----
    - 如果 positions 中有越界（<0 或 >= g.width），则抛出 ValueError。

    设计说明
    --------
    - 使用 XOR（异或）实现翻转：bit ^ 1。
    - 这里不区分“动爻”“静爻”等语义，只做纯比特翻转。
      动静的解释会交给上层语义层（L2.b / L3）。
    """
    mask = 0
    positions_list: List[int] = list(positions)

    for pos in positions_list:
        if not (0 <= pos < g.width):
            raise ValueError(
                f"flip_yao position out of range: {pos}, width={g.width}"
            )
        mask |= (1 << pos)

    # XOR 掩码：对应位置 0->1, 1->0，其它位不变
    new_bits = g.bits ^ mask
    return GuaCore(bits=new_bits, width=g.width)
