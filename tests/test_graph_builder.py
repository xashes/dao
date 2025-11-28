# tests/test_graph_builder.py
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict

from dao.graph_builder import (
    MappingMetaLike,
    MappingBundleLike,
    build_graph_from_trigrams_and_mappings,
    get_trigram_wuxing,
    get_trigram_direction,
)


# ---------- 测试用假数据 ----------

def make_demo_trigram_core() -> Dict[int, Dict[str, Any]]:
    """
    八卦基础数据，id 对应顺序：
    0: 乾, 1: 兑, 2: 离, 3: 震, 4: 巽, 5: 坎, 6: 艮, 7: 坤
    这里只用到 name_zh，你可以按自己项目的 core 数据替换。
    """
    names = ["乾", "兑", "离", "震", "巽", "坎", "艮", "坤"]
    core: Dict[int, Dict[str, Any]] = {}
    for i, name in enumerate(names):
        core[i] = {
            "id": i,
            "name_zh": name,
        }
    return core


def make_demo_trigram_wuxing_mapping_bundle() -> MappingBundleLike:
    """
    八卦 -> 五行（常见的一套，对应关系如下）：
    - 乾、兑：金
    - 离：火
    - 震、巽：木
    - 坎：水
    - 艮、坤：土
    """
    mapping: Dict[str, Dict[str, str]] = {
        "trigram:0": {"element": "金"},  # 乾
        "trigram:1": {"element": "金"},  # 兑
        "trigram:2": {"element": "火"},  # 离
        "trigram:3": {"element": "木"},  # 震
        "trigram:4": {"element": "木"},  # 巽
        "trigram:5": {"element": "水"},  # 坎
        "trigram:6": {"element": "土"},  # 艮
        "trigram:7": {"element": "土"},  # 坤
    }
    meta = MappingMetaLike(
        domain="trigram",
        kind="wuxing.main",
        school="example",  # 测试学派名
    )
    return MappingBundleLike(meta=meta, mapping=mapping)


def make_demo_trigram_direction_mapping_bundle() -> MappingBundleLike:
    """
    先天八卦方位（常见一套）：
    - 乾：西北
    - 兑：正西
    - 离：正南
    - 震：正东
    - 巽：东南
    - 坎：正北
    - 艮：东北
    - 坤：西南

    这里用简单的 8 方位编码：
    - N / NE / E / SE / S / SW / W / NW
    """
    mapping: Dict[str, Dict[str, str]] = {
        "trigram:0": {"direction": "NW"},  # 乾
        "trigram:1": {"direction": "W"},   # 兑
        "trigram:2": {"direction": "S"},   # 离
        "trigram:3": {"direction": "E"},   # 震
        "trigram:4": {"direction": "SE"},  # 巽
        "trigram:5": {"direction": "N"},   # 坎
        "trigram:6": {"direction": "NE"},  # 艮
        "trigram:7": {"direction": "SW"},  # 坤
    }
    meta = MappingMetaLike(
        domain="trigram",
        kind="direction.xiantian",
        school="example",
    )
    return MappingBundleLike(meta=meta, mapping=mapping)


# ---------- 真正的测试 ----------

def test_build_graph_and_query_trigram_wuxing_and_direction():
    trigram_core = make_demo_trigram_core()
    wuxing_bundle = make_demo_trigram_wuxing_mapping_bundle()
    direction_bundle = make_demo_trigram_direction_mapping_bundle()

    graph = build_graph_from_trigrams_and_mappings(
        trigram_core=trigram_core,
        mapping_bundles=[wuxing_bundle, direction_bundle],
    )

    # 1. 检查：图里有八个卦节点
    for i in range(8):
        node_id = f"trigram:{i}"
        assert node_id in graph.nodes
        assert graph.nodes[node_id].label == trigram_core[i]["name_zh"]

    # 2. 检查：五行节点存在
    for node_id in [
        "wuxing:wood",
        "wuxing:fire",
        "wuxing:earth",
        "wuxing:metal",
        "wuxing:water",
    ]:
        assert node_id in graph.nodes

    # 3. 检查：乾卦 -> 五行（金）
    wuxing_nodes = get_trigram_wuxing(graph, trigram_id=0, school="example")
    assert len(wuxing_nodes) == 1
    assert wuxing_nodes[0].id == "wuxing:metal"
