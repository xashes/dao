# dao/graph_types.py
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional


@dataclass
class Node:
    """
    图中的一个“实体”。

    约定：
    - id: 全局唯一，如 "trigram:0", "wuxing:water"
    - kind: 节点类别，如 "trigram", "wuxing", "direction"
    - label: 人类可读标识，如 "坎", "水", "北"
    - attrs: 其他附加属性，非必须字段以后可以慢慢丰富
    """
    id: str
    kind: str
    label: str
    attrs: Dict[str, Any] = field(default_factory=dict)


@dataclass
class Edge:
    """
    图中的一条有向边，表示一个“关系”。

    约定：
    - src: 源节点 id
    - dst: 目标节点 id
    - type: 关系类型，如 "map:trigram->wuxing", "rel:wuxing:sheng"
    - school: 学派/体系标识，如 "example", "liuren"
    - weight: 关系强度（预留字段，默认 1.0）
    - attrs: 其他附加属性（如来源书籍、页码、版本号等）
    """
    id: str
    src: str
    dst: str
    type: str
    school: str
    weight: float = 1.0
    attrs: Dict[str, Any] = field(default_factory=dict)


@dataclass
class Graph:
    """
    关系图：维护节点表、边表，以及出入边索引。

    - nodes: {node_id -> Node}
    - edges: {edge_id -> Edge}
    - out_edges: {node_id -> [edge_id, ...]}  从该节点出发的边
    - in_edges: {node_id -> [edge_id, ...]}   指向该节点的边
    """
    nodes: Dict[str, Node] = field(default_factory=dict)
    edges: Dict[str, Edge] = field(default_factory=dict)
    out_edges: Dict[str, List[str]] = field(default_factory=dict)
    in_edges: Dict[str, List[str]] = field(default_factory=dict)

    # ---------- 节点相关 ----------

    def add_node(self, node: Node, overwrite: bool = False) -> None:
        """
        加入一个节点。
        - 如果节点已存在，默认保持原节点不变（除非 overwrite=True）。
        """
        if node.id in self.nodes and not overwrite:
            return
        self.nodes[node.id] = node
        self.out_edges.setdefault(node.id, [])
        self.in_edges.setdefault(node.id, [])

    def get_node(self, node_id: str) -> Optional(Node):
        return self.nodes.get(node_id)

    # ---------- 边相关 ----------

    def add_edge(self, edge: Edge, overwrite: bool = False) -> None:
        """
        加入一条边。
        - 如果 edge.id 已存在，默认保持原边不变（除非 overwrite=True）。
        """
        if edge.id in self.edges and not overwrite:
            return

        # 确保节点索引存在，即使节点还没真正 add_node
        self.out_edges.setdefault(edge.src, [])
        self.in_edges.setdefault(edge.dst, [])

        self.edges[edge.id] = edge
        if edge.id not in self.out_edges[edge.src]:
            self.out_edges[edge.src].append(edge.id)
        if edge.id not in self.in_edges[edge.dst]:
            self.in_edges[edge.dst].append(edge.id)

    def iter_out_edges(
        self,
        src_id: str,
        type: Optional[str] = None,
        school: Optional[str] = None,
    ) -> Iterable[Edge]:
        """
        迭代从某个节点出发的边，可按 type / school 筛选。
        """
        for edge_id in self.out_edges.get(src_id, []):
            edge = self.edges[edge_id]
            if type is not None and edge.type != type:
                continue
            if school is not None and edge.school != school:
                continue
            yield edge

    def iter_in_edges(
        self,
        dst_id: str,
        type: Optional[str] = None,
        school: Optional[str] = None,
    ) -> Iterable[Edge]:
        """
        迭代指向某个节点的边，可按 type / school 筛选。
        """
        for edge_id in self.in_edges.get(dst_id, []):
            edge = self.edges[edge_id]
            if type is not None and edge.type != type:
                continue
            if school is not None and edge.school != school:
                continue
            yield edge

    def neighbors(
        self,
        src_id: str,
        type: Optional[str] = None,
        school: Optional[str] = None,
    ) -> List[Node]:
        """
        从某个节点出发，查找邻接的目标节点（只看出边）。
        """
        result: List[Node] = []
        for edge in self.iter_out_edges(src_id, type=type, school=school):
            node = self.nodes.get(edge.dst)
            if node is not None:
                result.append(node)
        return result
