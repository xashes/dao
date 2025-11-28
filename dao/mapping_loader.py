"""
mapping_loader.py

L1.B2：插件式 Mapping 文件加载器。

职责
----
- 从 JSON 文件中加载 MappingBundle：
  - 解析 _meta -> MetaVersionInfo
  - 解析 domain / kind
  - 解析 mapping，做基础校验：
      * key 前缀为 "{domain}:"
      * 若 domain 为 trigram/hexagram，则校验 id 范围

注意
----
- 不关心 mapping 内部字段具体含义，只保证结构合法。
- 语义解释（比如把 "direction" 映射为方位）由更高层处理。
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict

from .metadata_core_types import MetaVersionInfo
from .mapping_types import MappingBundle


def _load_json(path: Path) -> Dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"Mapping file not found: {path}")

    text = path.read_text(encoding="utf-8")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse JSON from {path}: {e}") from e

    if not isinstance(data, dict):
        raise ValueError(f"Top-level JSON must be an object in {path}")
    return data


def _parse_meta(meta_dict: Dict[str, Any]) -> MetaVersionInfo:
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


def _validate_key_for_domain(domain: str, key: str) -> None:
    """
    校验 mapping 的 key 与 domain 是否匹配，并在部分 domain 上做 id 范围检查。

    规则：
    - key 必须以 "{domain}:" 开头
    - 若 domain == "trigram":
        id 必须是 0..7 的整数
    - 若 domain == "hexagram":
        id 必须是 0..63 的整数
    """
    prefix = f"{domain}:"
    if not key.startswith(prefix):
        raise ValueError(f"mapping key {key!r} must start with {prefix!r}")

    suffix = key[len(prefix):]

    if domain == "trigram":
        try:
            v = int(suffix)
        except ValueError as e:
            raise ValueError(f"trigram mapping key must end with int id, got {key!r}") from e
        if not (0 <= v <= 7):
            raise ValueError(f"trigram id out of range in key {key!r}: {v}")

    elif domain == "hexagram":
        try:
            v = int(suffix)
        except ValueError as e:
            raise ValueError(f"hexagram mapping key must end with int id, got {key!r}") from e
        if not (0 <= v <= 63):
            raise ValueError(f"hexagram id out of range in key {key!r}: {v}")

    # 其他 domain 暂不做 id 范围检查


def load_mapping(path: str | Path) -> MappingBundle:
    """
    从 JSON 文件加载插件式语义 Mapping。

    参数
    ----
    path : str | Path
        映射文件路径。

    返回
    ----
    MappingBundle
    """
    p = Path(path)
    data = _load_json(p)

    # meta
    meta_dict = data.get("_meta")
    if not isinstance(meta_dict, dict):
        raise ValueError(f"Mapping file {p} must contain a '_meta' object")
    meta = _parse_meta(meta_dict)

    # domain
    domain = data.get("domain")
    if not isinstance(domain, str) or not domain:
        raise ValueError(f"'domain' must be a non-empty string in {p}")

    # kind
    kind = data.get("kind")
    if not isinstance(kind, str) or not kind:
        raise ValueError(f"'kind' must be a non-empty string in {p}")

    # mapping
    mapping_raw = data.get("mapping")
    if not isinstance(mapping_raw, dict):
        raise ValueError(f"'mapping' must be an object in {p}")

    mapping: Dict[str, Dict[str, Any]] = {}
    for key, value in mapping_raw.items():
        if not isinstance(key, str):
            raise ValueError(f"mapping key must be string, got {key!r}")
        if not isinstance(value, dict):
            raise ValueError(f"mapping[{key!r}] must be an object")

        _validate_key_for_domain(domain, key)
        mapping[key] = value

    return MappingBundle(
        meta=meta,
        domain=domain,
        kind=kind,
        mapping=mapping,
    )
