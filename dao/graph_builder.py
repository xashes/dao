# dao/graph_builder.py
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional

from .graph_types import Graph, Node, Edge


# ---------- 简单的“Bundle 接口”定义（duck typing） ----------

@dataclass
class MappingMetaLike:
    """
    用于 graph_builder 的简化 Meta 定义。
    实际项目中可以用你已有的 MappingMeta / MetaVersionInfo，
    只要字段名兼容即可（domain / kind / school）。
    """
    domain: str       # 如 "trigram"
    kind: str         # 如 "wuxing.main", "direction.xiantian"
    school: str       # 学派，如 "example"


@dataclass
class MappingBundleLike:
    """
    GraphBuilder 只依赖 mapping: Dict[str, Any] 和 meta: MappingMetaLike。
    你可以直接把自己项目里的 MappingBundle 传进来，
    只要它有 .mapping 和 .meta（且 meta 有 domain/kind/school）。
    """
    meta: MappingMetaLike
    mapping: Dict[str, Any]


# ---------- 基础节点构造：五行 / 方位 ----------

# 五行中文 -> 统一 node id
WUXING_CHAR_TO_ID = {
    "木": "wuxing:wood",
    "火": "wuxing:fire",
    "土": "wuxing:earth",
    "金": "wuxing:metal",
    "水": "wuxing:water",
}

# 五行 node id -> label
WUXING_ID_TO_LABEL = {
    "wuxing:wood": "木",
    "wuxing:fire": "火",
    "wuxing:earth": "土",
    "wuxing:metal": "金",
    "wuxing:water": "水",
}

# 方位字符串 -> node id & label（你可以按自己习惯扩展）
DIRECTION_CODE_TO_ID_LABEL = {
    "N": ("direction:N", "北"),
    "NE": ("direction:NE", "东北"),
    "E": ("direction:E", "东"),
    "SE": ("direction:SE", "东南"),
    "S": ("direction:S", "南"),
    "SW": ("direction:SW", "西南"),
    "W": ("direction:W", "西"),
    "NW": ("direction:NW", "西北"),
}


def ensure_wuxing_nodes(graph: Graph) -> None:
    """
    确保五行节点存在。
    """
    for node_id, label in WUXING_ID_TO_LABEL.items():
        if node_id not in graph.nodes:
            graph.add_node(Node(id=node_id, kind="wuxing", label=label))


def ensure_direction_nodes(graph: Graph) -> None:
    """
    确保基础方位节点存在。
    """
    for code, (node_id, label) in DIRECTION_CODE_TO_ID_LABEL.items():
        if node_id not in graph.nodes:
            graph.add_node(Node(id=node_id, kind="direction", label=label))


# ---------- 卦节点构造 ----------

def add_trigram_nodes_from_core(
    graph: Graph,
    trigram_core: Dict[int, Dict[str, Any]],
) -> None:
    """
    从“卦核心数据”构建八卦节点。

    trigram_core 的典型结构可以是：
    {
        0: {"id": 0, "name_zh": "乾", "name_en": "Qian"},
        1: {"id": 1, "name_zh": "兑", ...},
        ...
    }
    这里不强制具体字段，只要能取到一个 label 即可。
    """
    for trigram_id, info in trigram_core.items():
        node_id = f"trigram:{trigram_id}"
        label = (
            info.get("name_zh")
            or info.get("name")
            or f"Trigram{trigram_id}"
        )
        attrs = {k: v for k, v in info.items() if k not in ("id", "name_zh", "name")}
        graph.add_node(
            Node(
                id=node_id,
                kind="trigram",
                label=label,
                attrs=attrs,
            )
        )


# ---------- 从 MappingBundle 构造边 ----------

def _make_edge_id(src: str, dst: str, type_: str, school: str) -> str:
    # 简单可读的 edge id 生成方式
    return f"{src}--{type_}--{dst}--{school}"


def add_edges_from_mapping_bundle(
    graph: Graph,
    bundle: Any,  # duck typing: 只要有 .meta.domain / .meta.kind / .meta.school / .mapping 即可
) -> None:
    """
    将一个 MappingBundle 风格的对象转换成一组边加入图中。

    当前支持：
    - domain="trigram" + kind 以 "wuxing" 开头 => 八卦 -> 五行
      约定 value 结构类似 { "element": "金" } 或直接 "金"
    - domain="trigram" + kind 以 "direction" 开头 => 八卦 -> 方位
      约定 value 结构类似 { "direction": "N" } 或直接 "N"
    """
    meta = bundle.meta
    domain = getattr(meta, "domain", None)
    kind = getattr(meta, "kind", "")
    school = getattr(meta, "school", "default")

    if domain != "trigram":
        # 当前只处理八卦相关映射，其他 domain 可以以后扩展
        return

    if kind.startswith("wuxing"):
        _add_edges_trigram_to_wuxing(graph, bundle.mapping, school=school)
    elif kind.startswith("direction"):
        _add_edges_trigram_to_direction(graph, bundle.mapping, school=school)
    else:
        # 其他 kind 未来再扩
        return


def _add_edges_trigram_to_wuxing(
    graph: Graph,
    mapping: Dict[str, Any],
    school: str,
) -> None:
    """
    将 mapping["trigram:<id>"] -> 五行，转换成边。
    - value 支持：
      - 字符串："金"
      - 字典：{"element": "金"} 或 {"wuxing": "金"}
    """
    ensure_wuxing_nodes(graph)

    for node_key, value in mapping.items():
        # node_key 预期形如 "trigram:0"
        src = node_key

        # 解析五行中文
        if isinstance(value, str):
            wuxing_char = value
        elif isinstance(value, dict):
            wuxing_char = (
                value.get("element")
                or value.get("wuxing")
                or value.get("char")
            )
        else:
            continue

        node_id = WUXING_CHAR_TO_ID.get(wuxing_char)
        if node_id is None:
            # 未知的五行字符，暂时跳过
            continue

        dst = node_id
        edge_type = "map:trigram->wuxing"
        edge_id = _make_edge_id(src, dst, edge_type, school)

        edge = Edge(
            id=edge_id,
            src=src,
            dst=dst,
            type=edge_type,
            school=school,
        )
        graph.add_edge(edge)


def _add_edges_trigram_to_direction(
    graph: Graph,
    mapping: Dict[str, Any],
    school: str,
) -> None:
    """
    将 mapping["trigram:<id>"] -> 方位，转换成边。
    - value 支持：
      - 字符串："N"
      - 字典：{"direction": "N"} 或 {"code": "N"}
    """
    ensure_direction_nodes(graph)

    for node_key, value in mapping.items():
        src = node_key

        if isinstance(value, str):
            code = value
        elif isinstance(value, dict):
            code = value.get("direction") or value.get("code")
        else:
            continue

        if code not in DIRECTION_CODE_TO_ID_LABEL:
            continue

        dst, _label = DIRECTION_CODE_TO_ID_LABEL[code]
        edge_type = "map:trigram->direction"
        edge_id = _make_edge_id(src, dst, edge_type, school)

        edge = Edge(
            id=edge_id,
            src=src,
            dst=dst,
            type=edge_type,
            school=school,
        )
        graph.add_edge(edge)


# ---------- 总装函数 + 查询辅助 ----------

def build_graph_from_trigrams_and_mappings(
    trigram_core: Dict[int, Dict[str, Any]],
    mapping_bundles: Iterable[Any],
) -> Graph:
    """
    用“八卦核心数据 + 若干 MappingBundle 风格对象”构建一整张图。

    - trigram_core: 八卦的基础信息（id -> info dict）
    - mapping_bundles: 一个可迭代对象，每个元素有 .meta / .mapping
    """
    graph = Graph()
    # 先加基础节点
    ensure_wuxing_nodes(graph)
    ensure_direction_nodes(graph)
    add_trigram_nodes_from_core(graph, trigram_core)

    # 再加各类映射边
    for bundle in mapping_bundles:
        add_edges_from_mapping_bundle(graph, bundle)

    return graph


def get_trigram_wuxing(
    graph: Graph,
    trigram_id: int,
    school: Optional[str] = None,
) -> List[Node]:
    """
    查询：某个八卦 -> 它对应的五行（允许多学派并存，所以返回列表）。
    """
    src = f"trigram:{trigram_id}"
    return graph.neighbors(
        src_id=src,
        type="map:trigram->wuxing",
        school=school,
    )


def get_trigram_direction(
    graph: Graph,
    trigram_id: int,
    school: Optional[str] = None,
) -> List[Node]:
    """
    查询：某个八卦 -> 它对应的方位。
    """
    src = f"trigram:{trigram_id}"
    return graph.neighbors(
        src_id=src,
        type="map:trigram->direction",
        school=school,
    )
