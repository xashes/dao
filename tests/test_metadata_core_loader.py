"""
tests/test_metadata_core_loader.py

测试 dao.metadata_core_loader.load_core_names 的基本行为：
- 能正确加载 _meta 信息
- 能正确加载 trigrams / hexagrams
- 能检测简单的数据一致性错误（例如 id 与 key 不一致）
"""

from pathlib import Path

import json
import pytest

from dao.metadata_core_loader import load_core_names


# 项目根目录 = 本文件所在目录的上上级
PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_CORE_DIR = PROJECT_ROOT / "data" / "core"


def test_load_core_trigrams_file():
    """
    使用 data/core/core_trigrams.v1.json 示例文件，验证：
    - meta 信息读取正常
    - trigrams 字典中包含预期 id
    """
    path = DATA_CORE_DIR / "core_trigrams.v1.json"
    bundle = load_core_names(path)

    # 元信息基本检查（具体值以你实际文件为准）
    assert bundle.meta.school == "core"
    assert bundle.meta.version == "1.0.0"

    # trigrams 应该非空，而 hexagrams 可以为空
    assert len(bundle.trigrams) >= 1
    # 示例中我们假设有 id=0 的八卦
    assert 0 in bundle.trigrams
    tri0 = bundle.trigrams[0]
    assert tri0.id == 0
    assert isinstance(tri0.name_zh, str)
    assert tri0.name_zh != ""


def test_load_core_hexagrams_file():
    """
    使用 data/core/core_hexagrams.v1.json 示例文件，验证：
    - meta 信息读取正常
    - hexagrams 字典中包含预期 id
    """
    path = DATA_CORE_DIR / "core_hexagrams.v1.json"
    bundle = load_core_names(path)

    assert bundle.meta.school == "core"
    assert bundle.meta.version == "1.0.0"

    assert len(bundle.hexagrams) >= 1
    # 示例中我们假设有 id=0 的卦
    assert 0 in bundle.hexagrams
    hex0 = bundle.hexagrams[0]
    assert hex0.id == 0
    assert isinstance(hex0.name_zh, str)
    assert hex0.name_zh != ""


def test_load_core_names_id_mismatch(tmp_path: Path):
    """
    构造一个临时 JSON 文件，其中 trigrams 的 key 与内部 id 不一致，
    期望 loader 抛出 ValueError。
    """
    bad_data = {
        "_meta": {
            "school": "core",
            "version": "1.0.0",
            "source": "test",
            "last_updated": "2025-11-28",
            "notes": None,
        },
        "trigrams": {
            "0": {
                "id": 1,  # 故意写错：key 是 "0"，id 却是 1
                "name_zh": "测试卦",
                "name_pinyin": "ceshi",
            }
        },
        "hexagrams": {},
    }

    bad_file = tmp_path / "bad_trigrams.json"
    bad_file.write_text(json.dumps(bad_data, ensure_ascii=False), encoding="utf-8")

    with pytest.raises(ValueError):
        load_core_names(bad_file)
