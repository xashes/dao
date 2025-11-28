"""
metadata_core_loader.py

L1.B1：卦的“身份证”加载器（Core Metadata Loader）

职责
----
- 从 JSON 文件中加载核心卦名信息：
  - MetaVersionInfo
  - TrigramCoreInfo / HexagramCoreInfo 字典
- 不做任何派生语义处理（五行、方位等），只关心：
  - id 是否合理
  - JSON 结构是否符合预期

使用方式
--------
- 一个文件可以只包含 trigrams 或 hexagrams：
    data/core/core_trigrams.v1.json      # 只填 trigrams
    data/core/core_hexagrams.v1.json     # 只填 hexagrams

- 调用方式：
    from dao.metadata_core_loader import load_core_names

    bundle = load_core_names("data/core/core_trigrams.v1.json")
    # bundle.trigrams 有内容，bundle.hexagrams 可能为空 dict
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict

from .metadata_core_types import (
    MetaVersionInfo,
    TrigramCoreInfo,
    HexagramCoreInfo,
    CoreNamesBundle,
)


def _load_json(path: Path) -> Dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"Metadata file not found: {path}")

    text = path.read_text(encoding="utf-8")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse JSON from {path}: {e}") from e

    if not isinstance(data, dict):
        raise ValueError(f"Top-level JSON must be an object in {path}")
    return data


def _parse_meta(meta_dict: Dict[str, Any]) -> MetaVersionInfo:
    """
    从 JSON 的 `_meta` 字段解析 MetaVersionInfo。

    要求字段：
    - school, version, source, last_updated
    - notes 可选
    """
    try:
        school = meta_dict["school"]
        version = meta_dict["version"]
        source = meta_dict["source"]
        last_updated = meta_dict["last_updated"]
        notes = meta_dict.get("notes")
    except KeyError as e:
        raise ValueError(f"Missing required meta field: {e!r}") from e

    return MetaVersionInfo(
        school=school,
        version=version,
        source=source,
        last_updated=last_updated,
        notes=notes,
    )


def _parse_trigrams(trigrams_dict: Dict[str, Any]) -> Dict[int, TrigramCoreInfo]:
    """
    解析 JSON 中的 `trigrams` 字典：

    JSON 结构示例：
    "trigrams": {
      "0": { "id": 0, "name_zh": "坤", "name_pinyin": "kun" },
      "1": { "id": 1, "name_zh": "震", "name_pinyin": "zhen" }
    }

    转换为：
    dict[int, TrigramCoreInfo]
    """
    result: Dict[int, TrigramCoreInfo] = {}

    for key_str, payload in trigrams_dict.items():
        if not isinstance(payload, dict):
            raise ValueError(f"trigrams[{key_str!r}] must be an object")

        try:
            # key 本身应该是一个 int 字符串，例如 "0"
            key_id = int(key_str)
        except ValueError as e:
            raise ValueError(f"trigrams key must be an int string, got {key_str!r}") from e

        # payload 中的 id 字段如果存在，应与 key_id 一致
        payload_id = payload.get("id", key_id)
        if payload_id != key_id:
            raise ValueError(
                f"trigrams[{key_str!r}].id={payload_id} "
                f"does not match key {key_id}"
            )

        name_zh = payload.get("name_zh")
        if not isinstance(name_zh, str):
            raise ValueError(f"trigrams[{key_str!r}].name_zh must be a string")

        name_pinyin = payload.get("name_pinyin")
        if name_pinyin is not None and not isinstance(name_pinyin, str):
            raise ValueError(
                f"trigrams[{key_str!r}].name_pinyin must be a string or null"
            )

        result[key_id] = TrigramCoreInfo(
            id=key_id,
            name_zh=name_zh,
            name_pinyin=name_pinyin,
        )

    return result


def _parse_hexagrams(hexagrams_dict: Dict[str, Any]) -> Dict[int, HexagramCoreInfo]:
    """
    解析 JSON 中的 `hexagrams` 字典：

    JSON 结构示例：
    "hexagrams": {
      "0": { "id": 0, "name_zh": "坤", "name_pinyin": "kun" },
      "1": { "id": 1, "name_zh": "复", "name_pinyin": "fu" }
    }

    转换为：
    dict[int, HexagramCoreInfo]
    """
    result: Dict[int, HexagramCoreInfo] = {}

    for key_str, payload in hexagrams_dict.items():
        if not isinstance(payload, dict):
            raise ValueError(f"hexagrams[{key_str!r}] must be an object")

        try:
            key_id = int(key_str)
        except ValueError as e:
            raise ValueError(f"hexagrams key must be an int string, got {key_str!r}") from e

        payload_id = payload.get("id", key_id)
        if payload_id != key_id:
            raise ValueError(
                f"hexagrams[{key_str!r}].id={payload_id} "
                f"does not match key {key_id}"
            )

        name_zh = payload.get("name_zh")
        if not isinstance(name_zh, str):
            raise ValueError(f"hexagrams[{key_str!r}].name_zh must be a string")

        name_pinyin = payload.get("name_pinyin")
        if name_pinyin is not None and not isinstance(name_pinyin, str):
            raise ValueError(
                f"hexagrams[{key_str!r}].name_pinyin must be a string or null"
            )

        result[key_id] = HexagramCoreInfo(
            id=key_id,
            name_zh=name_zh,
            name_pinyin=name_pinyin,
        )

    return result


def load_core_names(path: str | Path) -> CoreNamesBundle:
    """
    从给定 JSON 文件加载核心卦名信息。

    参数
    ----
    path : str | Path
        JSON 文件路径，可以是相对或绝对路径。

    返回
    ----
    CoreNamesBundle
        - meta: 文件元信息
        - trigrams: dict[int, TrigramCoreInfo]
        - hexagrams: dict[int, HexagramCoreInfo]

    用法示例
    --------
    >>> from dao.metadata_core_loader import load_core_names
    >>> bundle = load_core_names("data/core/core_trigrams.v1.json")
    >>> bundle.meta.school
    'core'
    >>> bundle.trigrams[0].name_zh
    '坤'
    """
    p = Path(path)
    data = _load_json(p)

    # 解析 _meta
    meta_dict = data.get("_meta")
    if not isinstance(meta_dict, dict):
        raise ValueError(f"Metadata file {p} must contain a '_meta' object")
    meta = _parse_meta(meta_dict)

    # 解析 trigrams / hexagrams，可为空
    trigrams_raw = data.get("trigrams", {})
    hexagrams_raw = data.get("hexagrams", {})

    if not isinstance(trigrams_raw, dict):
        raise ValueError(f"'trigrams' must be an object in {p}")
    if not isinstance(hexagrams_raw, dict):
        raise ValueError(f"'hexagrams' must be an object in {p}")

    trigrams = _parse_trigrams(trigrams_raw)
    hexagrams = _parse_hexagrams(hexagrams_raw)

    return CoreNamesBundle(
        meta=meta,
        trigrams=trigrams,
        hexagrams=hexagrams,
    )
