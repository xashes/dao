class Gua:
    def __init__(self, name, xiang, detail, yao):
        self.name = name
        self.xiang = xiang
        self.detail = detail
        self.yao = yao

    def __repr__(self):
        return f"Gua(name={self.name}, xiang={self.xiang})"
