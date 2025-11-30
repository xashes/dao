# tests/test_wuxing_relations.py
from __future__ import annotations

import pytest

from dao.graph_types import Graph
from dao.wuxing_relations import (
    add_wuxing_relation_edges,
    get_wuxing_targets,
    infer_wuxing_relation_between_elements,
    infer_trigram_wuxing_relation,
)
from dao.graph_builder import (
    build_graph_from_trigrams_and_mappings,
)
# 复用上一个测试文件里定义的 demo 数据
from tests.test_graph_builder import (
    make_demo_trigram_core,
    make_demo_trigram_wuxing_mapping_bundle,
)


def _build_graph_with_wuxing_relations() -> Graph:
    g = Graph()
    add_wuxing_relation_edges(g, school="standard")
    return g


def test_wuxing_sheng_cycle():
    g = _build_graph_with_wuxing_relations()

    # 木生火
    targets = get_wuxing_targets(g, "wuxing:wood", relation="sheng", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:fire" in ids

    # 火生土
    targets = get_wuxing_targets(g, "wuxing:fire", relation="sheng", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:earth" in ids

    # 土生金
    targets = get_wuxing_targets(g, "wuxing:earth", relation="sheng", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:metal" in ids

    # 金生水
    targets = get_wuxing_targets(g, "wuxing:metal", relation="sheng", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:water" in ids

    # 水生木
    targets = get_wuxing_targets(g, "wuxing:water", relation="sheng", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:wood" in ids


def test_wuxing_ke_cycle():
    g = _build_graph_with_wuxing_relations()

    # 金克木
    targets = get_wuxing_targets(g, "wuxing:metal", relation="ke", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:wood" in ids

    # 木克土
    targets = get_wuxing_targets(g, "wuxing:wood", relation="ke", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:earth" in ids

    # 土克水
    targets = get_wuxing_targets(g, "wuxing:earth", relation="ke", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:water" in ids

    # 水克火
    targets = get_wuxing_targets(g, "wuxing:water", relation="ke", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:fire" in ids

    # 火克金
    targets = get_wuxing_targets(g, "wuxing:fire", relation="ke", school="standard")
    ids = {n.id for n in targets}
    assert "wuxing:metal" in ids


def test_infer_wuxing_relation_between_elements_basic():
    g = _build_graph_with_wuxing_relations()

    # 同行
    rel = infer_wuxing_relation_between_elements(
        g, "wuxing:wood", "wuxing:wood", school="standard"
    )
    assert rel == "same"

    # 木生火
    rel = infer_wuxing_relation_between_elements(
        g, "wuxing:wood", "wuxing:fire", school="standard"
    )
    assert rel == "sheng"

    # 火被水克（从火的视角）
    rel = infer_wuxing_relation_between_elements(
        g, "wuxing:fire", "wuxing:water", school="standard"
    )
    # 水克火 => 从火的视角是 "ke_by"
    assert rel == "ke_by"

    # 金克木
    rel = infer_wuxing_relation_between_elements(
        g, "wuxing:metal", "wuxing:wood", school="standard"
    )
    assert rel == "ke"

    # 金与水：金生水 => 金生水，水被金生
    rel = infer_wuxing_relation_between_elements(
        g, "wuxing:metal", "wuxing:water", school="standard"
    )
    assert rel == "sheng"


def test_infer_trigram_wuxing_relation():
    """
    结合上一轮的“八卦 -> 五行”映射，测试卦之间的五行关系推断。
    映射回顾：
        乾、兑：金
        离：火
        震、巽：木
        坎：水
        艮、坤：土
    """
    trigram_core = make_demo_trigram_core()
    wuxing_bundle = make_demo_trigram_wuxing_mapping_bundle()

    # 先构建：八卦 + 卦->五行
    from dao.graph_builder import build_graph_from_trigrams_and_mappings

    g = build_graph_from_trigrams_and_mappings(
        trigram_core=trigram_core,
        mapping_bundles=[wuxing_bundle],
    )
    # 再加五行生克关系
    add_wuxing_relation_edges(g, school="standard")

    # 震(木) vs 离(火) => 木生火
    rel = infer_trigram_wuxing_relation(g, trigram_a=3, trigram_b=2, school="example")
    assert rel == "sheng"

    # 乾(金) vs 震(木) => 金克木
    rel = infer_trigram_wuxing_relation(g, trigram_a=0, trigram_b=3, school="example")
    assert rel == "ke"

    # 坎(水) vs 离(火) => 水克火（从水的视角是 ke，从火的视角是 ke_by）
    rel = infer_trigram_wuxing_relation(g, trigram_a=5, trigram_b=2, school="example")
    assert rel == "ke"

    # 艮(土) vs 兑(金) => 土生金
    rel = infer_trigram_wuxing_relation(g, trigram_a=6, trigram_b=1, school="example")
    assert rel == "sheng"
