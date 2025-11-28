"""
mapping_types.py

L1.B2：插件式语义 Mapping 的通用类型定义。

设计目标
--------
1. 为「任意学派 / 任意语义」的映射文件提供统一外壳结构：
   - 元信息（MetaVersionInfo）
   - 作用域（domain）
   - 语义种类（kind）
   - 映射表（mapping: key -> 任意字段）

2. 不预先约束 mapping 里的字段名：
   - direction / element / family / ... 全部由数据文件自己定义
   - Python 里仅用 dict[str, Any] 承载，避免 schema 双写问题

典型 JSON 结构
--------------
{
  "_meta": { ... MetaVersionInfo ... },
  "domain": "trigram",
  "kind": "direction.xiantian",
  "mapping": {
    "trigram:0": { "direction": "N" },
    "trigram:1": { "direction": "NE" },
    ...
  }
}
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict

from .metadata_core_types import MetaVersionInfo


@dataclass
class MappingBundle:
    """
    一份插件式语义 mapping 文件在内存中的承载结构。

    字段说明
    --------
    meta : MetaVersionInfo
        文件的版本/学派/来源等信息。

    domain : str
        作用域，如 "trigram"、"hexagram"、"yao" 等。

    kind : str
        映射的语义种类，如 "direction.xiantian"、"wuxing.main" 等。
        建议采用「类别.子类」的形式，便于分类管理。

    mapping : Dict[str, Dict[str, Any]]
        具体映射表：
        - key: 统一格式 "domain:id"，例如 "trigram:0"、"hexagram:23"
        - value: 任意字段字典，由数据文件自行定义。
          例如：{ "direction": "N" } 或 { "element": "金", "extra": "xxx" }
    """

    meta: MetaVersionInfo
    domain: str
    kind: str
    mapping: Dict[str, Dict[str, Any]]

    def get(self, key: str) -> Dict[str, Any] | None:
        """按完整 key（如 'trigram:0'）获取映射数据。"""
        return self.mapping.get(key)

    def key_for(self, obj_id: int) -> str:
        """辅助方法：根据 id 构造标准 key，例如 'trigram:0'。"""
        return f"{self.domain}:{obj_id}"
