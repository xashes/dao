from src.data_loader import load_data
from src.models import Gua


def main():
    data = load_data('data/gua64.json')
    gua_list = [
        Gua(g['gua-name'], g['gua-xiang'], g['gua-detail'], g['yao-detail'])
        for g in data['gua']
    ]

    # 这里可以添加更多的程序逻辑
    for gua in gua_list[:2]:  # 示例：打印前两个卦
        print(gua)


if __name__ == "__main__":
    main()
