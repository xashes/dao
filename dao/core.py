"""
core.py

L1.Core：卦的二进制本体层（Binary Core）

设计目标
--------
1. 提供一个「唯一、稳定、可跨语言」的卦编码方式。
2. 只关心「阴阳爻的比特表示」和「爻位顺序」这种纯结构问题。
3. 不包含任何「解释性语义」：
   - 不出现：卦名、卦序、五行、方位、卦辞、象义……
   - 不出现：错卦、综卦、互卦、变爻等运算。
4. 保证构造安全（范围校验），避免后续出现“幽灵错误”。

核心公理（必须全局统一）
------------------------
- 阴阳编码：
    阴 = 0
    阳 = 1

- 爻位顺序：
    pos = 0 ：初爻（最下）
    pos = width - 1 ：最上爻

- 编码方式（bits 字段）：
    bits = Σ (yao_i * 2^i)，i 从 0 到 width-1，
    其中 i = 0 对应最下爻，i 递增向上。

- 常用 width：
    width = 3 ：三爻卦（八卦），0..7
    width = 6 ：六爻卦（六十四卦），0..63

注意：本模块只定义「本体和安全构造」，不做任何卦变换。
      卦变换、查询等属于 L2（运算层）。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, List, NewType

# 阴阳比特：用 Literal 明确只有两种值
Bit = Literal[0, 1]

# 语义型别名：只是为了代码语义更清晰，不引入任何额外含义。
# - TrigramId：三爻卦 ID（通常对应 width=3 的 bits）
# - HexagramId：六爻卦 ID（通常对应 width=6 的 bits）
TrigramId = NewType("TrigramId", int)
HexagramId = NewType("HexagramId", int)


@dataclass(frozen=True)
class GuaCore:
    """
    卦的二进制本体（Canonical Hexagram/Trigram Core）。

    字段说明
    --------
    bits : int
        卦的二进制编码。
        约束：0 <= bits <= (1 << width) - 1
        解释：按位表示自下而上的爻，bit0 是最下爻。

    width : int
        爻数（bit 宽度），必须 > 0。
        常用：
          - width = 3 : 三爻卦（八卦）
          - width = 6 : 六爻卦（六十四卦）

    不可变性
    --------
    使用 @dataclass(frozen=True)，一旦创建不可修改。
    这样可以安全地把 GuaCore 当成「值类型」到处传递，
    不用担心中途被谁改掉内部 bits。

    重要设计原则
    ------------
    - GuaCore 只关心「结构」，不关心任何「语义」。
      比如它不知道自己是“乾卦”还是“坤卦”，也不知道五行是什么。
    - 所有语义都在外部通过「映射表 / 图结构」来挂载。
    """

    bits: int
    width: int = 6

    def __post_init__(self) -> None:
        """
        构造后检查：
        - width 必须 > 0
        - bits 必须落在合法范围 [0, 2^width - 1]

        这样可以保证：
        - 任意一个 GuaCore 实例都是自洽的
        - 上层不用再到处检查「bits 是否越界」
        """
        if self.width <= 0:
            raise ValueError("width must be positive (got {self.width})")

        max_bits = (1 << self.width) - 1
        if not (0 <= self.bits <= max_bits):
            raise ValueError(
                f"bits must be in [0, {max_bits}] for width={self.width}, got {self.bits}"
            )

    # ------------------------------------------------------------------
    # 基础读取接口（不涉及任何运算，只是读结构）
    # ------------------------------------------------------------------

    def yao(self, pos_from_bottom: int) -> Bit:
        """
        读取指定爻位的阴阳值。

        参数
        ----
        pos_from_bottom : int
            爻位，从 0 开始：
            - 0 表示初爻（最下）
            - width - 1 表示最上爻

        返回
        ----
        Bit (0 or 1)
            0 = 阴爻
            1 = 阳爻
        """
        if not (0 <= pos_from_bottom < self.width):
            raise IndexError(
                f"yao position out of range: {pos_from_bottom}, width={self.width}"
            )

        # 右移 pos_from_bottom 位，再取最低位
        return (self.bits >> pos_from_bottom) & 1  # type: ignore[return-value]

    def to_bits_list(self) -> List[Bit]:
        """
        把当前卦展开为「自下而上」的 bit 列表。

        返回
        ----
        List[Bit]
            [bit0, bit1, ..., bit(width-1)]
            其中：
            - index=0 是初爻（最下）
            - index=width-1 是最上爻
        """
        return [self.yao(i) for i in range(self.width)]

    # ------------------------------------------------------------------
    # 构造辅助方法（仍然视为 Core 职责：从列表构造本体）
    # ------------------------------------------------------------------

    @staticmethod
    def from_bits_list(bits_list: List[Bit]) -> "GuaCore":
        """
        通过 bit 列表（自下而上）构造一个 GuaCore。

        参数
        ----
        bits_list : List[Bit]
            自下而上的阴阳列表：
                bits_list[0] = 初爻
                bits_list[-1] = 最上爻
            每个元素必须是 0 或 1。

        返回
        ----
        GuaCore
            对应的本体对象。

        说明
        ----
        这是构造 GuaCore 的推荐方式之一，
        另外一种是直接用 bits 和 width 构造，例如：
            GuaCore(bits=0b010101, width=6)
        """
        if not bits_list:
            raise ValueError("bits_list must not be empty")

        width = len(bits_list)
        bits = 0

        for i, b in enumerate(bits_list):
            # 显式转换为 int，避免出现 True/False 等其他类型混入
            if b not in (0, 1):
                raise ValueError(f"bits_list[{i}] must be 0 or 1, got {b!r}")
            bits |= (int(b) << i)

        return GuaCore(bits=bits, width=width)

    # ------------------------------------------------------------------
    # 一些轻量的语义辅助（不涉及解释，只是根据 width 分类）
    # ------------------------------------------------------------------

    @property
    def is_trigram(self) -> bool:
        """是否为三爻卦（仅根据 width 判断，不做任何语义假设）。"""
        return self.width == 3

    @property
    def is_hexagram(self) -> bool:
        """是否为六爻卦（仅根据 width 判断，不做任何语义假设）。"""
        return self.width == 6


# ----------------------------------------------------------------------
# 简单自检（非正式单元测试）
# 可以在命令行运行： python core.py 观察是否抛异常
# ----------------------------------------------------------------------

def _self_test() -> None:
    # 1. 底爻是 bit0：初爻为阳，其余为阴
    g1 = GuaCore.from_bits_list([1, 0, 0, 0, 0, 0])
    assert g1.bits == 1
    assert g1.yao(0) == 1
    assert g1.yao(5) == 0

    # 2. 上爻是最高位：仅最上爻为阳
    g2 = GuaCore.from_bits_list([0, 0, 0, 0, 0, 1])
    assert g2.bits == 1 << 5  # 32
    assert g2.yao(5) == 1
    assert g2.yao(0) == 0

    # 3. round-trip：列表 -> GuaCore -> 列表
    bits_list = [1, 1, 0, 1, 0, 0]
    g3 = GuaCore.from_bits_list(bits_list)
    assert g3.to_bits_list() == bits_list

    # 4. 三爻卦示例：101（下阳、中阴、上阳）
    g4 = GuaCore.from_bits_list([1, 0, 1])
    assert g4.is_trigram and not g4.is_hexagram
    assert g4.bits == 0b101

    print("GuaCore self-test passed.")


if __name__ == "__main__":
    _self_test()
