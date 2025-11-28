# tests/conftest.py
import os
import sys

# 项目根目录 = 当前文件的上一级目录的上一级目录
PROJECT_ROOT = os.path.dirname(os.path.dirname(__file__))

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)
