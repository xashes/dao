"""
metadata_core_types.py

L1.B1：卦的“身份证”类型定义（Core Metadata）

设计目标
--------
1. 只描述「卦本身最基础、最稳定」的信息：
   - 哪个 bits 对应哪一卦（id）
   - 卦的中文名 / 拼音名
2. 不包含任何派生语义：
   - 不写：五行、方位、家人、卦辞、象义……
   - 不写：卦序关系（文王序等）
3. 为后续「插件式语义文件」提供挂载基础：
   - 其他文件只需要用统一 ID（例如 "hexagram:0"）就能对接到这里。

说明
----
- 本模块只定义数据结构，不做文件 IO。
- JSON 的存储形式会在 data/core/*.json 中体现，
  Loader 会在单独的模块中实现（例如 metadata_core_loader.py）。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Dict


# ----------------------------------------------------------------------
# 通用元信息：MetaVersionInfo
# ----------------------------------------------------------------------


@dataclass
class MetaVersionInfo:
    """
    元数据版本信息（针对一整个 metadata 文件）。

    示例用途：
    - 标记此文件属于哪个学派/用途（school）
    - 使用哪个版本（version），便于迭代与兼容处理
    - 记录数据整理来源（source）
    - 记录最后更新日期与备注（last_updated / notes）
    """

    school: str           # 学派/体系/用途名，例如 "core", "main", "wenwang"
    version: str          # 版本号，例如 "1.0.0"
    source: str           # 数据来源说明，例如 "周易 64 卦名"
    last_updated: str     # "YYYY-MM-DD" 格式的日期字符串
    notes: Optional[str]  # 备注，可空


# ----------------------------------------------------------------------
# 八卦 / 六十四卦的核心信息（只管“叫什么”）
# ----------------------------------------------------------------------


@dataclass
class TrigramCoreInfo:
    """
    三爻卦（八卦）的核心信息：只包含最基础的“身份”字段。

    字段说明
    --------
    id : int
        TrigramId，对应 width=3 的 bits（0..7）。
        注意：具体 "0..7 映射到哪一卦" 的方案需要由你在数据文件中明确。
              这里仅假设 id 是一个稳定、一致的标识。

    name_zh : str
        卦名（中文），例如 "乾"、"坎"、"震" 等。

    name_pinyin : Optional[str]
        卦名的拼音，例如 "qian"、"kan"、"zhen"。
        可选字段，方便在英文环境中展示。
    """

    id: int
    name_zh: str
    name_pinyin: Optional[str]


@dataclass
class HexagramCoreInfo:
    """
    六爻卦（六十四卦）的核心信息：只包含“ID + 名字”。

    字段说明
    --------
    id : int
        HexagramId，对应 width=6 的 bits（0..63）。
        同样，具体 bits 与传统卦序/卦名之间的对应关系，
        需要在数据整理阶段谨慎设计，本结构只负责承载。

    name_zh : str
        卦名（中文），例如 "坤"、"复" 等。

    name_pinyin : Optional[str]
        卦名的拼音，例如 "kun"、"fu"。
    """

    id: int
    name_zh: str
    name_pinyin: Optional[str]


# ----------------------------------------------------------------------
# 整体打包结构：一份“核心卦名”文件在内存中的样子
# ----------------------------------------------------------------------


@dataclass
class CoreNamesBundle:
    """
    一整套「卦的核心名字信息」在内存中的承载结构。

    典型 JSON 结构（示意）
    ---------------------
    {
      "_meta": { ... MetaVersionInfo 对应字段 ... },
      "trigrams": {
        "0": { "id": 0, "name_zh": "坤", "name_pinyin": "kun" },
        "1": { "id": 1, "name_zh": "震", "name_pinyin": "zhen" }
        ...
      },
      "hexagrams": {
        "0": { "id": 0, "name_zh": "坤", "name_pinyin": "kun" },
        "1": { "id": 1, "name_zh": "复", "name_pinyin": "fu" }
        ...
      }
    }

    读取策略
    --------
    - JSON 中使用字符串 key（"0", "1", ...），Loader 会将其转换为 int。
    - trigrams / hexagrams 在内存中用 dict[int, TrigramCoreInfo/HexagramCoreInfo] 表示。
    """

    meta: MetaVersionInfo
    trigrams: Dict[int, TrigramCoreInfo]
    hexagrams: Dict[int, HexagramCoreInfo]
