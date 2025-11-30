# dao/wuxing_relations.py
from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional, Literal

from .graph_types import Graph, Edge, Node
from .graph_builder import (
    ensure_wuxing_nodes,
    get_trigram_wuxing,
)

# 五行元素的固定 id
WUXING_IDS = [
    "wuxing:wood",
    "wuxing:fire",
    "wuxing:earth",
    "wuxing:metal",
    "wuxing:water",
]

# 五行相生：木生火，火生土，土生金，金生水，水生木
WUXING_SHENG_PAIRS = [
    ("wuxing:wood", "wuxing:fire"),
    ("wuxing:fire", "wuxing:earth"),
    ("wuxing:earth", "wuxing:metal"),
    ("wuxing:metal", "wuxing:water"),
    ("wuxing:water", "wuxing:wood"),
]

# 五行相克：金克木，木克土，土克水，水克火，火克金
WUXING_KE_PAIRS = [
    ("wuxing:metal", "wuxing:wood"),
    ("wuxing:wood", "wuxing:earth"),
    ("wuxing:earth", "wuxing:water"),
    ("wuxing:water", "wuxing:fire"),
    ("wuxing:fire", "wuxing:metal"),
]


def _make_edge_id(src: str, dst: str, type_: str, school: str) -> str:
    return f"{src}--{type_}--{dst}--{school}"


def add_wuxing_relation_edges(
    graph: Graph,
    school: str = "standard",
    overwrite: bool = False,
) -> None:
    """
    在图中加入五行相生 / 相克关系边。

    - school: 给五行关系本身也打上一个“学派”，默认 "standard"。
      将来如果你想测试其他生克体系，可以再建别的 school。
    """
    ensure_wuxing_nodes(graph)

    # 相生
    rel_type_sheng = "rel:wuxing:sheng"
    for src, dst in WUXING_SHENG_PAIRS:
        edge_id = _make_edge_id(src, dst, rel_type_sheng, school)
        edge = Edge(
            id=edge_id,
            src=src,
            dst=dst,
            type=rel_type_sheng,
            school=school,
        )
        graph.add_edge(edge, overwrite=overwrite)

    # 相克
    rel_type_ke = "rel:wuxing:ke"
    for src, dst in WUXING_KE_PAIRS:
        edge_id = _make_edge_id(src, dst, rel_type_ke, school)
        edge = Edge(
            id=edge_id,
            src=src,
            dst=dst,
            type=rel_type_ke,
            school=school,
        )
        graph.add_edge(edge, overwrite=overwrite)


def get_wuxing_targets(
    graph: Graph,
    element_id: str,
    relation: Literal["sheng", "ke"],
    school: Optional[str] = None,
) -> List[Node]:
    """
    查询：某个五行“生 / 克”谁。

    - relation="sheng": element_id 生 出去的对象
    - relation="ke":    element_id 克 谁
    """
    edge_type = f"rel:wuxing:{relation}"
    return graph.neighbors(
        src_id=element_id,
        type=edge_type,
        school=school,
    )


RelationLabel = Literal[
    "same",     # 同行
    "sheng",    # A 生 B
    "ke",       # A 克 B
    "sheng_by", # A 被 B 生
    "ke_by",    # A 被 B 克
    "none",     # 无直接生克关系
]


def infer_wuxing_relation_between_elements(
    graph: Graph,
    a_id: str,
    b_id: str,
    school: Optional[str] = None,
) -> RelationLabel:
    """
    推断五行元素 a 和 b 之间的简单关系（只看一跳生克）：

    - a == b              -> "same"
    - a 生 b              -> "sheng"
    - a 克 b              -> "ke"
    - b 生 a              -> "sheng_by"
    - b 克 a              -> "ke_by"
    - 以上都不是         -> "none"
    """
    if a_id == b_id:
        return "same"

    # a 生 / 克 b ?
    for node in get_wuxing_targets(graph, a_id, "sheng", school):
        if node.id == b_id:
            return "sheng"
    for node in get_wuxing_targets(graph, a_id, "ke", school):
        if node.id == b_id:
            return "ke"

    # 反向：b 生 / 克 a ?
    for node in get_wuxing_targets(graph, b_id, "sheng", school):
        if node.id == a_id:
            return "sheng_by"
    for node in get_wuxing_targets(graph, b_id, "ke", school):
        if node.id == a_id:
            return "ke_by"

    return "none"


def infer_trigram_wuxing_relation(
    graph: Graph,
    trigram_a: int,
    trigram_b: int,
    school: Optional[str] = None,
) -> RelationLabel:
    """
    推断：卦 A 与 卦 B 在五行上的关系。

    当前策略（简单版）：
    - 取某学派下，各自对应的第一个五行（假定一卦对应唯一五行）
    - 然后用 infer_wuxing_relation_between_elements 得出关系

    以后如果有“一卦多五行”的情况，再扩展为“返回所有组合”即可。
    """
    wuxings_a = get_trigram_wuxing(graph, trigram_a, school=school)
    wuxings_b = get_trigram_wuxing(graph, trigram_b, school=school)

    if not wuxings_a or not wuxings_b:
        return "none"

    # 简化：只取第一个
    a_id = wuxings_a[0].id
    b_id = wuxings_b[0].id

    return infer_wuxing_relation_between_elements(
        graph=graph,
        a_id=a_id,
        b_id=b_id,
        school=school,
    )
