"""
tests/test_mapping_loader.py

测试 dao.mapping_loader.load_mapping 的行为：

1. 能成功加载示例的 trigram 方位 / 五行 mapping 文件。
2. 确认：
   - meta 信息正确读取
   - domain / kind 正确
   - mapping 包含 8 个 key（trigram:0..7）
3. 构造错误示例，校验：
   - key 前缀错误时报错
   - trigram id 越界时报错
"""

from pathlib import Path
import json

import pytest

from dao.mapping_loader import load_mapping


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_MAPPINGS_DIR = PROJECT_ROOT / "data" / "mappings"


def test_load_trigram_direction_mapping():
    """
    使用 data/mappings/trigram_direction_xiantian.v1.json 示例文件。

    检查：
    - meta.school / version
    - domain == 'trigram'
    - kind == 'direction.example'
    - mapping 至少包含 trigram:0..7 这 8 个 key
    """
    path = DATA_MAPPINGS_DIR / "trigram_direction_xiantian.v1.json"
    bundle = load_mapping(path)

    assert bundle.meta.school == "example"
    assert bundle.meta.version == "1.0.0"
    assert bundle.domain == "trigram"
    assert bundle.kind == "direction.example"

    # 映射应包含 8 个 trigram:*
    assert len(bundle.mapping) == 8
    for i in range(8):
        key = f"trigram:{i}"
        assert key in bundle.mapping
        assert "direction" in bundle.mapping[key]


def test_load_trigram_wuxing_mapping():
    """
    使用 data/mappings/trigram_wuxing_main.v1.json 示例文件。

    检查：
    - kind == 'wuxing.main'
    - 每个条目都有 'element' 字段
    """
    path = DATA_MAPPINGS_DIR / "trigram_wuxing_main.v1.json"
    bundle = load_mapping(path)

    assert bundle.domain == "trigram"
    assert bundle.kind == "wuxing.main"

    assert len(bundle.mapping) == 8
    for i in range(8):
        key = f"trigram:{i}"
        assert key in bundle.mapping
        assert "element" in bundle.mapping[key]


def test_mapping_key_prefix_must_match_domain(tmp_path: Path):
    """
    构造一个临时 mapping 文件，其中 domain='trigram'，
    但 mapping key 使用了 'hexagram:0' 前缀，期望抛出 ValueError。
    """
    bad_data = {
        "_meta": {
            "school": "example",
            "version": "1.0.0",
            "source": "test",
            "last_updated": "2025-11-28",
            "notes": None
        },
        "domain": "trigram",
        "kind": "direction.example",
        "mapping": {
            "hexagram:0": { "direction": "N" }
        }
    }

    bad_file = tmp_path / "bad_mapping_prefix.json"
    bad_file.write_text(json.dumps(bad_data, ensure_ascii=False), encoding="utf-8")

    with pytest.raises(ValueError):
        load_mapping(bad_file)


def test_trigram_id_out_of_range_raises(tmp_path: Path):
    """
    构造一个 trigram mapping，但 id 超出 0..7 范围，应抛出 ValueError。
    """
    bad_data = {
        "_meta": {
            "school": "example",
            "version": "1.0.0",
            "source": "test",
            "last_updated": "2025-11-28",
            "notes": None
        },
        "domain": "trigram",
        "kind": "direction.example",
        "mapping": {
            "trigram:8": { "direction": "N" }  # 越界
        }
    }

    bad_file = tmp_path / "bad_mapping_id.json"
    bad_file.write_text(json.dumps(bad_data, ensure_ascii=False), encoding="utf-8")

    with pytest.raises(ValueError):
        load_mapping(bad_file)
