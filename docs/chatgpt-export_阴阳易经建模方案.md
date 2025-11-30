# 阴阳易经建模方案

> 我想对阴阳、易经卦象进行建模编码，因为阴阳本身就贴合二进制，可以用0和1表示。
> 进而，爻也可以用0和1表示。
> 而卦象就是0和1组成的列表。
> 之后，我还想把五行、方位、节气等等都关联进来。
> 对此，你有什么方案？
> 尤其是数据结构，你认为什么形式较好？
> 后续的建模、演示、交互，采用什么技术栈更为方便、美观？

下面给你一个相对“工程化、可扩展、可演化”的方案，把 **阴阳→爻→卦→更大知识体系（五行/方位/节气/天干地支/纳甲等）** 从底层表示到上层关联都考虑进去。会分成：核心建模思想、数据结构建议、关联知识的组织方式、以及后续演示/交互的技术栈。

---

## 1. 核心建模思想：两层表示 + 一层语义

### 1.1 两层表示（便于计算/便于展示）
- **计算层（Binary layer）**
  一切归到 bit / int / bitset。
  - 阴=0，阳=1
  - 爻=bit
  - 卦=bits 列表（或一个整数）
- **展示层（Line / Symbol layer）**
  面向 UI/绘图/排版：
  - 爻画成阴（— —）阳（——）
  - 卦画成从下到上 6 条线
  - 变爻、互卦、综卦、错卦等操作在这里也能可视化

### 1.2 一层语义（Semantic layer）
- 五行、方位、八卦象义、节气、纳甲、六亲、六神……
  这些不是“计算本体”，而是 **附着在卦/爻/时间/空间节点上的语义与关系**。
- 最好抽象成 **“知识图谱/关系网络”**：
  计算层只负责生成卦与变换；语义层负责解释与映射。

---

## 2. 计算层数据结构：位串为王

### 2.1 爻（Yao）
最小原子就是 bit。

```ts
type Bit = 0 | 1;     // 阴阳
```

### 2.2 卦（Gua）：建议用 **整数 + 位宽** 双表示
- 6 爻卦可以存成一个 0~63 的整数（下爻为最低位）
- 优点：
  - 空间极小
  - 变爻/错卦/综卦/互卦可用位运算快速实现
  - 任何语言都有位操作

```ts
interface Gua6 {
  bits: number;     // 0..63
  width: 6;         // 固定位宽，便于泛化到3爻/6爻/更多
}
```

辅助函数（下爻是 bit0）：

```ts
function getYao(g: Gua6, posFromBottom: 0|1|2|3|4|5): Bit {
  return ((g.bits >> posFromBottom) & 1) as Bit;
}

function setYao(g: Gua6, pos: 0|1|2|3|4|5, b: Bit): Gua6 {
  const mask = 1 << pos;
  const nb = b ? (g.bits | mask) : (g.bits & ~mask);
  return { bits: nb, width: 6 };
}
```

### 2.3 卦的变换（强烈建议全部用位运算）
- **变卦**：翻转指定爻（XOR）
- **错卦**：全翻（NOT within width）
- **综卦**：倒序（bit reverse）
- **互卦**：取中间 2-4 爻重组上下卦

```ts
// 变某几爻
function transform(g: Gua6, changingPositions: number[]): Gua6 {
  let x = g.bits;
  for (const p of changingPositions) x ^= (1 << p);
  return { bits: x, width: 6 };
}

// 错卦：全翻
function cuo(g: Gua6): Gua6 {
  const mask = (1 << g.width) - 1;
  return { bits: (~g.bits) & mask, width: 6 };
}
```

### 2.4 八卦（Trigram）与六十四卦映射
- 三爻卦：0~7
- 六爻卦：上卦(高3位) + 下卦(低3位)

```ts
function lowerTrigram(g: Gua6) { return g.bits & 0b111; }
function upperTrigram(g: Gua6) { return (g.bits >> 3) & 0b111; }
```

这样你可以非常自然地组合/拆分任何卦。

---

## 3. 语义层数据结构：建议“字典/表 + 关系图”混合

你后面要挂载很多传统体系，**不要硬塞进 Gua 的结构里**，否则会越来越臃肿。
正确姿势是：**Gua 是 id；语义在外部通过映射/关系关联。**

### 3.1 基础语义：用 JSON/表（可版本化）
每个 trigram/hexagram 都对应一份 metadata：

```json
{
  "hexagrams": {
    "0":  { "name": "坤", "upper": 0, "lower": 0, "element": "土", "direction": "西南", "keywords": ["顺", "承载"] },
    "1":  { "name": "复", "upper": 0, "lower": 1, "element": "土木", "direction": "北", "keywords": ["归来"] }
  },
  "trigrams": {
    "0": { "name": "坤", "element": "土", "direction": "西南", "family": "母", "symbol": "地" },
    "1": { "name": "震", "element": "木", "direction": "东", "family": "长男", "symbol": "雷" }
  }
}
```

> 这里 key 用 `"hexagram id"`（0~63）自然挂载。

### 3.2 复杂语义：用知识图谱（Graph）
当你开始关联：
- 五行生克
- 后天八卦方位
- 24 节气
- 天干地支、纳甲、六亲六神
- 卦气、卦序、卦变链
这些是“多对多 + 时间/空间条件 + 互相引用”的网络结构。

**图模型最舒服：**
- 节点 Node：`Hexagram` `Trigram` `Yao` `Element` `Direction` `SolarTerm` `StemBranch` …
- 边 Edge：`corresponds_to` `generates` `overcomes` `located_in` `governs_time` `maps_to_najia` …

你可以用两种实现路线：
1) **轻量图（代码内 adjacency list）**
2) **真正图数据库（Neo4j / ArangoDB）**

轻量图例子（TypeScript）：

```ts
type NodeId = string;
type EdgeType = "CORRESPOND" | "GENERATE" | "OVERCOME" | "LOCATE" | "TIME_GOVERN";

interface Edge { from: NodeId; to: NodeId; type: EdgeType; props?: any; }

interface Graph {
  nodes: Record<NodeId, any>;
  edges: Edge[];
  out: Record<NodeId, Edge[]>;
}
```

> 优点：未来你想加任何传统派别的规则（梅花、文王、京房、火珠林……）都只是加节点和边，不破坏底层。

---

## 4. “数据结构形式”怎么选更好？

### 推荐组合：**位串（计算） + JSON（表征） + Graph（关系）**
- **卦本体**：一个 `int bits`
- **静态属性**（卦名、象、方位、五行、卦序等）：JSON/表
- **动态/多体系关系**（生克、卦气、节气时间映射等）：Graph

这样好处是：
1. **计算层极简稳定**（永不变）
2. **语义层可扩展**（加新学派不动旧代码）
3. **数据可版本化**（不同派别不同 JSON/Graph）

---

## 5. 后续建模、演示、交互：技术栈建议

你目标里有三个关键词：**方便、美观、可交互**。
我给两套栈：快速原型 & 可长期维护。

### 5.1 快速原型（1-2 周内出可玩 Demo）
- **Python + Jupyter / Streamlit**
  - Python 负责建模、位运算、图关系推演
  - Streamlit 快速做 UI：点爻→变卦→显示互综错→显示五行/方位/节气解释
- **可视化**：Plotly / pyecharts
  画卦、画关系网络、画节气时间轴都很快。

适合：你还在探索规则与表达方式的时候。

### 5.2 长期产品化（Web 端漂亮互动）
- **后端**：FastAPI（Python）或 Node.js（NestJS）
  - 提供卦运算 API、查询语义/图谱 API
- **前端**：React + TypeScript
  - 组件化表现卦（每爻可点击/高亮/变爻）
  - 状态管理（Zustand/Redux）保存当前卦、变爻列表、视图模式
- **可视化/交互**：
  - **D3.js**：画卦变链、知识图谱网络
  - **Framer Motion**：卦翻转、变爻动画，做得很“玄妙但不土”
  - **TailwindCSS / shadcn-ui**：整体 UI 现代、干净

适合：你想做一个长期可增长的“易学可视化/推演系统”。

### 5.3 如果你想做 3D/沉浸式
- **Three.js / React Three Fiber**
  - 例如把六十四卦排成“卦阵空间”
  - 节气/时间用环形天象来映射
这套很炫，但建议二期再上。

---

## 6. 一个“最小可行模型（MVP）”路线图

1) **实现 3/6 爻卦计算内核**
   位表示 + 变错综互 + 卦序/上下卦拆分
2) **整理一份静态语义 JSON**
   八卦/六十四卦：名称、卦辞、象、五行、方位、先后天序
3) **做交互 Demo**
   - 点选 6 个爻（toggle 0/1）
   - 自动显示卦名、上下卦、变卦、互卦、综卦、错卦
   - 侧边栏展示五行/方位/关键词
4) **引入图模型**
   把五行生克、节气时间、纳甲等加成 edges
5) **逐步加入派别规则**
   每个派别一份 ruleset（JSON/DSL/代码），可切换。

---

## 7. 额外建议：规则最好“可配置/可切换”

易学体系有版本分歧是常态。
所以你最好从一开始就准备：

```ts
interface RuleSet {
  id: string;              // "wenwang", "meihua", "jingfang"...
  description: string;
  apply(gua: Gua6, context?: any): Interpretation;
}
```

**把“同一卦在不同派别的解释”当成插件。**
未来你会感谢现在的自己。

---

如果你愿意，我可以下一步直接给你：
1) 一份更完整的 **六十四卦 JSON 模板**（含上下卦、五行、方位、卦序字段）
2) 一个 **React Demo 组件骨架**（六爻可点、自动算变错综互、漂亮排版）
3) 以及一个简单的 **Graph 语义层示例**（五行+方位+节气的节点边怎么连）

你想先从哪个部分开干？

-----

> 你分析的很好，我有一些想法，想请你给出建议。
> 我认为这个项目分几个层——
> 一、底层的数据，这是后面几层的基础，只要这部分设计好，后面的操作、查询和可视化，都可以根据需要变更。
> 二、对数据的查询、操作（如错卦、互卦、变爻等），这部分都完成了，后面想选用哪种方式可视化都可以
> 三、针对第二层的操作及其生成的数据，进行相应的可视化。
> 这三层分开，最重要的是设计好底层的数据形式，这是一切的基础。

完全同意你“三层拆分”的思路，而且你抓到关键了：**第一层的数据形式一旦稳固，后面所有玩法都只是“对它做函数+做视图”。**
我给你一套更“底座友好”的设计建议，核心目标是：**稳定、可扩展、可多流派共存、计算高效、可视化无痛。**

---

## 0. 你这三层其实对应一种很成熟的架构

- **L1：本体 + 数据库（Ontology / Data）**
  “世界是什么”
- **L2：运算/查询（Algebra / API）**
  “世界怎么变、怎么问”
- **L3：可视化/交互（View / UI）**
  “给人怎么展示”

只要 L1 设计成“**最小本体 + 外挂语义 + 可版本化**”，你这个工程非常能长大。

---

## 1. L1 底层数据怎么设计最稳？——“三分法底座”

我建议底层不是一个单一结构，而是三块互补：

### A. **卦本体（Binary Core）**
只放**不可争议、纯计算**的东西：阴阳爻序、卦的二进制表示。

**原则**：
> L1 本体里不要放“五行/方位/卦辞/象义”等任何解释性内容。
那些是“语义外挂”，会因流派/版本而变。

推荐结构（语言无关）：

```ts
type Bit = 0|1;  // 阴阳
type GuaBits = number; // 0..63 for 6-yao

interface GuaCore {
  bits: GuaBits;   // canonical encoding: bit0 is bottom yao
  width: 6;
}
```

**为什么 bits 是黄金底座？**
- **闭包性强**：所有卦变换都是 bits → bits
- **可序列化极简**：一个 int 永久可存可传
- **跨语言无损**：前端后端、Python/JS/Go 都一致
- **性能无压力**：位运算天生快

> 你以后想扩展到 3 爻、8 爻、乃至“变长卦”，只改 `width`，不重构模型。

---

### B. **静态语义表（Static Metadata Tables）**
把“多数人一致同意”但又不属于计算本体的内容放成表：
如 **卦名、卦序、上下卦、先天/后天位置、五行归属（主流版）**。

结构建议：
- **key 永远用 bits（或它的 hexagramId）**
- **value 是静态字段**
- **允许多版本并存**

例（JSON / DB 表）：

```json
{
  "hexagrams_v1": {
    "0": {
      "name": "坤",
      "upper": 0, "lower": 0,
      "kingwen_index": 2,
      "binary_order_index": 0
    },
    "1": { "name": "复", "upper": 0, "lower": 1 }
  }
}
```

**注意：**
- 五行、方位你可以放静态表，但一定加 `version` / `school` 字段
  因为不同体系会不一样。

---

### C. **关系语义图（Semantic Graph / Knowledge Layer）**
凡是出现任意一种情况，就不要塞表里，而要进图层：

- 多对多关系
- 有条件/上下文（时间、节气、爻位、动静）
- 不同流派差异大
- 你未来可能继续加新关系

比如：
- 五行生克
- 八卦方位（先天/后天两版）
- 节气 ↔ 卦气
- 纳甲 / 天干地支映射
- 六亲六神按日辰变化
这些天生就是“网络”。

底层图结构可以轻量化先做：

```ts
interface Node { id: string; type: string; props: any }
interface Edge { from: string; to: string; type: string; props?: any }

interface SemanticGraph {
  nodes: Record<string, Node>;
  edges: Edge[];
}
```

**Graph 的妙处：**
- 你加一个新体系 = 加节点/边
- 旧体系完全不动
- 查询时你可以写“路径规则”：
  `卦 → 上下卦 → 五行 → 生克 → 方位 → 节气`
  这就是你想要的“关联进来”。

---

## 2. L1 的几个关键“工程级”设计点

### 2.1 **标准化（Canonical encoding）**
必须一开始定死两件事：
1. **爻位顺序**：下爻=bit0，上爻=bit5
2. **阴阳编码**：阴=0，阳=1

后面所有文件、API、UI 都围绕这个标准走。
不要让“同一个卦在不同地方 bit 顺序不一致”。

### 2.2 **版本与流派（Versioning / Schooling）**
你很快会遇到这种需求：
- “按照京房体系算”
- “按梅花体系解释”
- “后天八卦用文王位”
- “五行取主流 vs 取某书”

所以底层数据建议这样组织：

```
core/                # 永远不变的 bits 本体
metadata/
  hexagrams.main.v1.json
  hexagrams.main.v2.json
  trigrams.main.v1.json
graphs/
  wenwang.graph.json
  jingfang.graph.json
  meihua.graph.json
rules/
  wenwang.rules.json
  meihua.rules.json
```

**意思是：**
- core 不带派别
- metadata/graphs/rules 都带派别
- 运行时可切换“解释引擎”

### 2.3 **可逆性**
底层所有数据最好可做到：
- bits → 语义
- 语义（如“乾上坤下”）→ bits
这样 UI/查询层都舒服。

### 2.4 **自描述（Self-describing）**
每份表/图/规则都带 metadata：

```json
{
  "_meta": {
    "school": "wenwang",
    "version": "1.0.0",
    "source": "xxx古籍/整理者",
    "last_updated": "2025-11-27"
  },
  "data": { ... }
}
```

以后你不会忘“这一版到底按啥”。

---

## 3. L2（查询/操作层）如何让 L3 永久自由？

你的第二层最好做到：
- **所有操作都是纯函数**
- **输入输出只用 core bits 或 core+context**
- **不要在 L2 里混解释文本**

范式：

```ts
type Op = (g: GuaCore, ctx?: Context) => GuaCore | GuaCore[];

const cuo: Op = (g) => ...
const zong: Op = (g) => ...
const hu: Op = (g) => ...
const bian: Op = (g, ctx={changing:[...]}) => ...
```

这样 L3 想怎么画都行，因为 L2 返回的是干净、统一的 core 结构。

---

## 4. L3 的自由来自 L1/L2 的“稳定接口”

当你底层是 bits + 语义外挂时，L3 可以随便换：
- 传统线条卦象
- 现代抽象图标
- 动画变爻
- 知识图谱网络
- 节气时间轴

**UI 永远依赖 L2 的输出，L2 永远依赖 L1 的 bits。**
这就是你要的“怎么可视化都行”。

---

## 5. 你要的“底层数据形式”一句话结论

> **用 bits/int 作为唯一卦 ID 的计算本体；
> 静态属性放版本化 JSON/表；
> 复杂关联放可版本化知识图谱。**

这套底座：
- 现在就够用
- 未来扩展不崩
- 多流派可共存
- 计算和展示天然解耦

---

## 6. 额外送你一个“防后悔 checklist”

你在实现 L1 之前，确认下面都“写进 README 里”：

1. bit0 是否为下爻？（是）
2. 阴阳编码是否唯一？（阴0阳1）
3. 6 爻卦是否统一用 0..63？
4. 八卦（0..7）映射是否固定？
5. metadata/graph/rules 是否必须带 `school+version`？
6. L2 是否禁止写解释性字符串？
7. 所有 API 是否都只传 bits，不传“卦名”？

这 7 条守住，你这个系统后面怎么长都不会乱。

---

如果你愿意，我可以直接给你一个 **“L1 目录+文件模板”**（core/metadata/graphs/rules 的 JSON 骨架），以及一份 **统一的八卦/六十四卦 bits 编码对照表**，你就能马上开工把底座落地。

-----

> 非常好，比我想的更为深入和全面。在开始之前，我想先讨论一下语言问题，针对当前讨论的方案，你认为Racket和Python哪个更为合适？
> 还有，关于后面的图结构，我认为相关数据量并不庞大，所以没有必要用图数据库，手动实现相关的功能，或者直接用Python的networkX一类的库？你认为怎么做更好？

先给结论：**如果目标是“尽快把底座+操作层做出来，并顺滑走向可视化/交互”，Python 更合适；如果目标是“把易学运算抽象成一套极其纯粹、可证明、可推导的代数/DSL”，Racket 更迷人。**
你这个项目两种语言都能做，但侧重点不同。我按你当前的三层方案来对比。

---

## 1. Racket vs Python：按三层架构逐层比较

### L1（bits 本体 + metadata + graph 语义）
**Python 优势明显**
- **数据处理生态成熟**：JSON/YAML/CSV/SQLite 读写、版本管理、校验都顺手。
- **位运算/二进制支持直接且可读**。
- 做“同一份 core + 多版本 metadata/graph”时，Python 的文件组织、加载、热切换会非常顺。

**Racket 的优势在“表达力”**
- Racket 的 **list/bitstring 递归结构天然贴合爻/卦**。
- 你可以把 L1 的语义层做成一种 *可扩展的语言*（比如 `#lang yijing`），非常优雅。
- 如果你特别在意“形式化、可证明”的底座，Racket 是天选。

**但现实点说**：
L1 需要大量“工程脏活儿”（整理数据、读写、校验、版本化），Python 省时间。

---

### L2（错综互变 / 查询与推演）
这里 Racket 和 Python 各有千秋：

**Racket 更“理论优雅”**
- 你可以把卦变换写成非常像代数推导的组合子（combinators）。
- 模式匹配 / 递归 / 宏，让你能写出“规则即语言”的效果。

**Python 更“工程落地”**
- 位运算 + 函数式写法足够干净。
- 未来如果要做概率推演、随机起卦、统计、搜索路径，Python 的库（numpy/scipy）是加速器。

如果你要写“规则 DSL”，Racket 会很爽；
如果你更快想做完 L2 去做 L3，Python 会更省心。

---

### L3（可视化/交互）
**Python 强在“原型速度”，Racket 强在“语言一体化但生态弱”。**

- Python：Streamlit / Jupyter / Plotly
  你可以一周内就做一套可玩的 UI。
- Racket：也能画（pict、gui），但要做到现代 Web 的“美观+复杂交互”就比较吃力。

你已经明确要“建模、演示、交互方便美观”，
那 L3 这层基本是 Python / Web 的主场。

---

## 2. 结合你的目标，我的推荐

### 推荐主线：**Python as Main**
理由就是一句话：
> 你的项目“语义多、可视化强、要快速迭代”，Python 的端到端路径最短。

**你会得到：**
- L1/L2 快速稳定落地
- L3 选择面巨大（原型→产品）
- 未来做 AI 辅助解释/检索/生成也无缝（LLM、向量库等）

### 什么时候选 Racket？
如果你心里有这个愿景：
> “我不仅要建模易经，我要做一个可扩展、可证明的易学计算语言。”

那 Racket 很可能让你写得更“道法自然”。
你甚至可以：
- 用 Racket 把 L2 做成一个小语言 / 规则引擎
- Python 负责 L1 数据与 L3 展示
- 两者通过 JSON/CLI/FFI 对接

但这个路线 **更像二期/强化版**。

---

## 3. 图结构：你判断得对——没必要上图数据库

你的语义关系规模很可能只是：
- 节点：几百（卦/爻/五行/方位/节气/干支/六亲六神…）
- 边：几千以内

这种规模 **图数据库是“杀鸡用牛刀”**，还会引入部署/查询语言/维护成本。

---

## 4. 图层实现三种方案的取舍

### 方案 A：手写轻量图（我建议的默认方案）
**结构**
- Node 字典
- Edge 列表
- Out adjacency map

**优点**
- 最轻、可控、可版本化
- 规则查询可以完全按你自己的语义来写
- 以后想换 NetworkX、换图数据库也不痛（因为底层数据你已经有了）

**适用**：
你想“严格按易学语义设计查询”，而不是被库的范式牵着走。

---

### 方案 B：Python + NetworkX（很好的“工程加速器”）
**优点**
- 写最短路径 / 子图搜索 / 关系遍历 超快
- 自带大量算法：连通性、社区、层级布局
- 配合 Plotly/D3 输出图视图也方便

**缺点**
- NetworkX 的一些算法/属性命名是“通用图论语义”，
  你需要适配到“易学语义”上（不难，但有一层翻译）。
- 性能对大图一般，但你规模小，完全无所谓。

**适用**：
你希望快速实现“卦→五行→生克→方位→节气”这种路径查询，
或者想快速画图。

> 以你的目标和数据规模：NetworkX 是“很舒服的选择”。

---

### 方案 C：Racket 的图/关系库（不推荐做主线）
你可以做，但生态和文档会比 Python 少很多，
而且后续 L3 你大概率还是要走 Web/Python。
除非你坚持全 Racket 生态，否则不值得。

---

## 5. 我给你的最佳实践组合

**最稳、最快、后悔率最低：**

1. **底层图数据仍然以 JSON（nodes/edges）保存**
   - 版本化、可读、可迁移
2. **运行时用 NetworkX 加载出来**
   - 享受算法与查询便利
3. **核心关键查询（易学语义特化）自己写一层 wrapper**
   - 例如：`query_element_flow(gua, context)`
   - NetworkX 只做底层走图，不暴露给上层

这样你既不被库绑定，又能省超多时间。

---

## 6. 最终建议（直球）

- **语言**：现在就用 **Python** 开干。
  如果未来你想做“规则 DSL / 形式化推演”，再把 L2 抽出来用 Racket 重写或补强都来得及。
- **图层**：**JSON 存图 + NetworkX 运行时**。
  轻便、强大、可视化友好，完美匹配你说的“数据量不大但关系复杂”。

---

如果你想继续，我可以直接给你：
1) 一个 **Graph JSON 模板（nodes/edges/meta）**
2) 一份 **NetworkX 加载 + 易学语义查询 wrapper 的骨架代码**
3) 再配一个小例子：
   “某卦 → 上下卦五行 → 生克链 → 对应方位/节气的查询与可视化输出”

你只要说一声“从图层开始”，我就把模板和代码一次给你。

-----

> 很好，听你的，我们选用Python作为主语言。不过不要着急，不要一次性完成大量内容，我们要一小块一小块推进项目，每部分都讨论充分，防止引入不必要的误解和错误。我们回到你给出的分层方案，从L1开始，我们先完成最基础的Core部分，这部分应该放哪些内容？我们应该怎么做？

好，我们就按“小块推进、充分讨论”的节奏来。现在只聚焦 **L1.Core（Binary Core / 本体）**，把“地基里的钢筋”先定死：**什么必须放、什么坚决不放、以及怎么做**。

---

## 1. L1.Core 应该放哪些内容？（只放“不可争议 + 纯计算本体”）

### 必须放（Core 的最小闭包）
1. **阴阳的编码约定**
   - 阴 = 0
   - 阳 = 1
   这是所有编码的原点，必须写进 core。

2. **爻位顺序的约定（Canonical ordering）**
   - **下爻是第 0 位（最低位）**
   - **上爻是第 5 位（最高位）**
   - 卦的绘制/阅读是“自下而上”，但存储/运算要有唯一标准。

3. **卦的二进制表示**
   - 6 爻卦用 `0..63` 的整数表示（bits）
   - 三爻卦（八卦）用 `0..7` 表示
   - 只要这套规则固定，你后面所有东西都不会乱。

4. **Core 数据结构（语言层面的类型）**
   - bit / yao / gua 的最小类型
   - 在 Python 里用 `dataclass(frozen=True)` 表达不可变本体

5. **Core 的“安全约束 / 校验”**
   - bits 必须落在范围内
   - width 必须匹配（3 或 6，先只做 6 也行）
   这是避免后面产生“幽灵 bug”的关键。

---

### 坚决不放（现在放进 Core 会害你）
这些全都 **不属于 Core**：

- 卦名、卦序、卦辞、象义
- 五行、方位、节气、纳甲、六亲六神
- 任何“解释性/流派相关/可变的语义”
- 任何“运算逻辑”（错卦/综卦/互卦/变爻）——这些是 L2

**原因一句话：**
> Core 目标是“成为唯一 ID 与计算基元”，不是解释器。

---

## 2. Core 我建议你按“最小可用+严格不扩张”的方式做

我们先把 Core 做成一个小模块（比如 `core.py`），内容控制在 **20~40 行**，只提供：
- 数据类型
- 编码规范
- 极少的辅助转换（不属于卦变换）

### 2.1 Python 的 Core 草案（供讨论）
先给一个“刚好够用，但不越界”的样子：

```python
# core.py
from dataclasses import dataclass
from typing import Literal, List

Bit = Literal[0, 1]

@dataclass(frozen=True)
class GuaCore:
    """
    Canonical hexagram core.
    bits: int in [0, 2^width - 1], where bit0 is bottom yao.
    width: currently fixed to 6 for hexagrams.
    """
    bits: int
    width: int = 6

    def __post_init__(self):
        if self.width <= 0:
            raise ValueError("width must be positive")
        max_bits = (1 << self.width) - 1
        if not (0 <= self.bits <= max_bits):
            raise ValueError(f"bits must be in [0, {max_bits}] for width={self.width}")

    def yao(self, pos_from_bottom: int) -> Bit:
        """Get yao at position 0..width-1 (0 is bottom)."""
        if not (0 <= pos_from_bottom < self.width):
            raise IndexError("yao position out of range")
        return Bit((self.bits >> pos_from_bottom) & 1)

    def to_bits_list(self) -> List[Bit]:
        """Return [bit0, bit1, ..., bit(width-1)] (bottom -> top)."""
        return [self.yao(i) for i in range(self.width)]

    @staticmethod
    def from_bits_list(bits_list: List[Bit]) -> "GuaCore":
        """Create core from [bottom..top] list."""
        width = len(bits_list)
        bits = 0
        for i, b in enumerate(bits_list):
            bits |= (int(b) << i)
        return GuaCore(bits=bits, width=width)
```

**你会注意到：**
- 这里没有任何卦变换函数
- `yao()` 和 `to_bits_list()` 只是“读结构”
- `from_bits_list()` 只是“建结构”
这仍然属于 Core 的职责范围（序列化/反序列化）。

> 你如果觉得 `from_bits_list` 都想放到 L2，也可以；
> 但一般它属于 core 的“构造器”，放这里很干净。

---

## 3. Core 需要先定下的“项目级常量/公理”

我们把下面这些写进 `README` 或 `core.py` 顶部注释里：

1. **Bit 定义**：阴 0，阳 1
2. **爻位定义**：pos=0 是初爻（最下），pos=5 是上爻
3. **Hexagram 编码**：
   `bits = Σ (yao_i * 2^i), i 从下到上`
4. **Trigram 编码（如果你想 Core 预留）**：
   同理 `width=3`
5. **Core 不包含语义、不包含卦变换**

这些“公理”不写清楚，后面会出现“同一个卦不同模块表示反了”的灾难。

---

## 4. 我们第一小块要完成什么？（最小里程碑）

为了确保“没有误解”，我们 L1.Core 的第一块里程碑就是：

✅ **Core v0.1**
- `Bit` 类型
- `GuaCore` 不可变数据类
- 校验范围
- `yao(pos)`
- `to_bits_list()`
- `from_bits_list()`
- 以及一份 10 行以内的说明文档

到这里就停，先不碰 L2。

---

## 5. 为了防错：Core 立刻配 3 个单元测试

先写最简单的，确保两件事：
- 编码顺序不会反
- 阴阳不会乱

```python
def test_bottom_is_bit0():
    g = GuaCore.from_bits_list([1,0,0,0,0,0])  # 初爻为阳
    assert g.bits == 1
    assert g.yao(0) == 1
    assert g.yao(5) == 0

def test_top_is_bit5():
    g = GuaCore.from_bits_list([0,0,0,0,0,1])  # 上爻为阳
    assert g.bits == 32
    assert g.yao(5) == 1

def test_roundtrip():
    bits_list = [1,1,0,1,0,0]
    g = GuaCore.from_bits_list(bits_list)
    assert g.to_bits_list() == bits_list
```

这三条过了，Core 的“方向感”就锁死了。

---

## 6. 你现在可以挑的讨论点（我们下一步就围绕它们）

为了让你“完全认可地基”，你可以看看下面这些是否要调整：

1. **Core 是否一开始就支持 width=3？**
   - 我倾向于支持（因为免费且自然）
   - 你也可以先固定 6，后面再放开

2. **`from_bits_list` 是否放 Core？**
   - 放：构造方便
   - 不放：Core 更“极简主义”

3. **是否要定义一个 `HexagramId` 类型别名？**
   - 纯语义糖，不影响本体
   - 你若想极简，也可以不加

---

你先看看这版 **Core 应放内容/不放内容** 和这个 `core.py` 草案是否符合你的直觉。
只要你点头，我们就把 **Core v0.1** 定稿，然后再进 L2（错综互变等运算层）。

-----

> 很好，你提出的公理论非常有道理。可以定稿。你提出的讨论点，我的看法如下：
> 支持 width=3
> from_bits_list 放入 Core
> 是否定义类型别名，我暂时没考虑好，请你评估并决定是否定义。
> 那现在我们就依讨论好的方案定稿吧，代码中要加上足够详细的注释，比如代码的设计思路、原因、用途、目标等。

那我们就把 L1.Core 正式“浇好地基”。下面这份是一个可以直接放进项目里的 `core.py`，已经按照我们讨论的公理和目标来设计，并加上比较详细的注释。

---

## 设计小结（先用人话再上代码）

- **目标**：只负责“卦的二进制本体”和“安全构造/读取”，不掺杂任何语义（五行、卦名等）和运算（错、综、互、变）。
- **核心约定**（写死在代码和注释里）：
  1. 阴 = 0，阳 = 1
  2. 第 0 位（bit0）是 **初爻（最底下那一爻）**
  3. `bits` 的编码是：
     $$
bits = Σ (yao_i * 2^i)，i 从下到上
$$
  4. 支持任意 `width > 0`，但常用的是：
     - `width=3`：三爻卦（八卦）
     - `width=6`：六爻卦（六十四卦）
- **放入 Core 的内容**：
  - 类型：`Bit`、`GuaCore`
  - 构造：`from_bits_list`
  - 读取：`yao()`、`to_bits_list()`
  - 一点点语义型别名：`TrigramId` / `HexagramId`（只是 `int` 的语义包装，不带任何解释逻辑）

---

## `core.py` 定稿版本（带详细注释）

```python
"""
core.py

L1.Core：卦的二进制本体层（Binary Core）

设计目标
--------
1. 提供一个「唯一、稳定、可跨语言」的卦编码方式。
2. 只关心「阴阳爻的比特表示」和「爻位顺序」这种纯结构问题。
3. 不包含任何「解释性语义」：
   - 不出现：卦名、卦序、五行、方位、卦辞、象义……
   - 不出现：错卦、综卦、互卦、变爻等运算。
4. 保证构造安全（范围校验），避免后续出现“幽灵错误”。

核心公理（必须全局统一）
------------------------
- 阴阳编码：
    阴 = 0
    阳 = 1

- 爻位顺序：
    pos = 0 ：初爻（最下）
    pos = width - 1 ：最上爻

- 编码方式（bits 字段）：
    bits = Σ (yao_i * 2^i)，i 从 0 到 width-1，
    其中 i = 0 对应最下爻，i 递增向上。

- 常用 width：
    width = 3 ：三爻卦（八卦），0..7
    width = 6 ：六爻卦（六十四卦），0..63

注意：本模块只定义「本体和安全构造」，不做任何卦变换。
      卦变换、查询等属于 L2（运算层）。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, List, NewType

# 阴阳比特：用 Literal 明确只有两种值
Bit = Literal[0, 1]

# 语义型别名：只是为了代码语义更清晰，不引入任何额外含义。
# - TrigramId：三爻卦 ID（通常对应 width=3 的 bits）
# - HexagramId：六爻卦 ID（通常对应 width=6 的 bits）
TrigramId = NewType("TrigramId", int)
HexagramId = NewType("HexagramId", int)


@dataclass(frozen=True)
class GuaCore:
    """
    卦的二进制本体（Canonical Hexagram/Trigram Core）。

    字段说明
    --------
    bits : int
        卦的二进制编码。
        约束：0 <= bits <= (1 << width) - 1
        解释：按位表示自下而上的爻，bit0 是最下爻。

    width : int
        爻数（bit 宽度），必须 > 0。
        常用：
          - width = 3 : 三爻卦（八卦）
          - width = 6 : 六爻卦（六十四卦）

    不可变性
    --------
    使用 @dataclass(frozen=True)，一旦创建不可修改。
    这样可以安全地把 GuaCore 当成「值类型」到处传递，
    不用担心中途被谁改掉内部 bits。

    重要设计原则
    ------------
    - GuaCore 只关心「结构」，不关心任何「语义」。
      比如它不知道自己是“乾卦”还是“坤卦”，也不知道五行是什么。
    - 所有语义都在外部通过「映射表 / 图结构」来挂载。
    """

    bits: int
    width: int = 6

    def __post_init__(self) -> None:
        """
        构造后检查：
        - width 必须 > 0
        - bits 必须落在合法范围 [0, 2^width - 1]

        这样可以保证：
        - 任意一个 GuaCore 实例都是自洽的
        - 上层不用再到处检查「bits 是否越界」
        """
        if self.width <= 0:
            raise ValueError("width must be positive (got {self.width})")

        max_bits = (1 << self.width) - 1
        if not (0 <= self.bits <= max_bits):
            raise ValueError(
                f"bits must be in [0, {max_bits}] for width={self.width}, got {self.bits}"
            )

    # ------------------------------------------------------------------
    # 基础读取接口（不涉及任何运算，只是读结构）
    # ------------------------------------------------------------------

    def yao(self, pos_from_bottom: int) -> Bit:
        """
        读取指定爻位的阴阳值。

        参数
        ----
        pos_from_bottom : int
            爻位，从 0 开始：
            - 0 表示初爻（最下）
            - width - 1 表示最上爻

        返回
        ----
        Bit (0 or 1)
            0 = 阴爻
            1 = 阳爻
        """
        if not (0 <= pos_from_bottom < self.width):
            raise IndexError(
                f"yao position out of range: {pos_from_bottom}, width={self.width}"
            )

        # 右移 pos_from_bottom 位，再取最低位
        return (self.bits >> pos_from_bottom) & 1  # type: ignore[return-value]

    def to_bits_list(self) -> List[Bit]:
        """
        把当前卦展开为「自下而上」的 bit 列表。

        返回
        ----
        List[Bit]
            [bit0, bit1, ..., bit(width-1)]
            其中：
            - index=0 是初爻（最下）
            - index=width-1 是最上爻
        """
        return [self.yao(i) for i in range(self.width)]

    # ------------------------------------------------------------------
    # 构造辅助方法（仍然视为 Core 职责：从列表构造本体）
    # ------------------------------------------------------------------

    @staticmethod
    def from_bits_list(bits_list: List[Bit]) -> "GuaCore":
        """
        通过 bit 列表（自下而上）构造一个 GuaCore。

        参数
        ----
        bits_list : List[Bit]
            自下而上的阴阳列表：
                bits_list[0] = 初爻
                bits_list[-1] = 最上爻
            每个元素必须是 0 或 1。

        返回
        ----
        GuaCore
            对应的本体对象。

        说明
        ----
        这是构造 GuaCore 的推荐方式之一，
        另外一种是直接用 bits 和 width 构造，例如：
            GuaCore(bits=0b010101, width=6)
        """
        if not bits_list:
            raise ValueError("bits_list must not be empty")

        width = len(bits_list)
        bits = 0

        for i, b in enumerate(bits_list):
            # 显式转换为 int，避免出现 True/False 等其他类型混入
            if b not in (0, 1):
                raise ValueError(f"bits_list[{i}] must be 0 or 1, got {b!r}")
            bits |= (int(b) << i)

        return GuaCore(bits=bits, width=width)

    # ------------------------------------------------------------------
    # 一些轻量的语义辅助（不涉及解释，只是根据 width 分类）
    # ------------------------------------------------------------------

    @property
    def is_trigram(self) -> bool:
        """是否为三爻卦（仅根据 width 判断，不做任何语义假设）。"""
        return self.width == 3

    @property
    def is_hexagram(self) -> bool:
        """是否为六爻卦（仅根据 width 判断，不做任何语义假设）。"""
        return self.width == 6


# ----------------------------------------------------------------------
# 简单自检（非正式单元测试）
# 可以在命令行运行： python core.py 观察是否抛异常
# ----------------------------------------------------------------------

def _self_test() -> None:
    # 1. 底爻是 bit0：初爻为阳，其余为阴
    g1 = GuaCore.from_bits_list([1, 0, 0, 0, 0, 0])
    assert g1.bits == 1
    assert g1.yao(0) == 1
    assert g1.yao(5) == 0

    # 2. 上爻是最高位：仅最上爻为阳
    g2 = GuaCore.from_bits_list([0, 0, 0, 0, 0, 1])
    assert g2.bits == 1 << 5  # 32
    assert g2.yao(5) == 1
    assert g2.yao(0) == 0

    # 3. round-trip：列表 -> GuaCore -> 列表
    bits_list = [1, 1, 0, 1, 0, 0]
    g3 = GuaCore.from_bits_list(bits_list)
    assert g3.to_bits_list() == bits_list

    # 4. 三爻卦示例：101（下阳、中阴、上阳）
    g4 = GuaCore.from_bits_list([1, 0, 1])
    assert g4.is_trigram and not g4.is_hexagram
    assert g4.bits == 0b101

    print("GuaCore self-test passed.")


if __name__ == "__main__":
    _self_test()
```

---

如果你对这份 Core 没有异议，我们接下来就可以把它当成**固定地基**，后面所有 L2（错、综、互、变等运算）都只依赖这个 `GuaCore`，不再动这里。

下一步你可以告诉我你更想先做哪块 L2：

- A. 三爻/六爻卦的拆分与组合（上卦/下卦、TrigramId/HexagramId 映射）
- B. 基本变换：变爻、错卦、综卦
- C. 互卦的计算规则实现

我们就继续按“小块推进，一块讲透再写代码”的节奏往上搭。

-----

> width: int = 6，这行的意思是默认width = 6吗？
> 非常好，不过在进入下一步之前，请写一个正式的单元测试——全面测试功能，且对各种用法进行展示（测试中也要有注释）。
> 另外，core.py和测试文件分别要放到哪里？

对，`width: int = 6` 的意思是：
- `width` 这个参数的**类型标注**是 `int`
- 如果你在创建 `GuaCore` 时**不传 `width`**，就会使用**默认值 6**

也就是说：

```python
GuaCore(bits=0b010101)         # 等价于 GuaCore(bits=0b010101, width=6)
GuaCore(bits=0b101, width=3)   # 明确指定为三爻卦
```

---

## 一、项目结构：core.py 和测试文件放哪里？

推荐一个简单、清晰、后续可扩展的结构（使用 `pytest` 做测试）：

```text
your_project/
├─ yijing/
│  ├─ __init__.py
│  └─ core.py          # 我们刚写的 GuaCore 放这里
└─ tests/
   └─ test_core.py     # 正式单元测试，覆盖 core.py
```

说明：

- `yijing/` 目录是你的“包”，后面 L2、L3 也可以放进去（比如 `ops.py`, `graph.py` 等）。
- `__init__.py` 可以先是一个空文件，表示这是一个 Python 包。
- `tests/` 目录专门放测试文件，pytest 会自动识别 `test_*.py`。

在项目根目录执行：

```bash
pytest
```

就会自动发现并运行 `tests/test_core.py`。

---

## 二、正式单元测试：`tests/test_core.py`

下面是一份比较“正式”的测试文件，既**全面测试功能**，又在测试中**展示各种用法**，而且有足够注释讲清楚“用法+预期行为”。

使用框架：`pytest`（简单好用）。
如果你更习惯 `unittest`，以后也可以再写一版类式测试。

```python
"""
tests/test_core.py

对 yijing.core.GuaCore 进行单元测试与用法示例。

测试目标
--------
1. 确认 Core 公理是否被正确实现：
   - 阴 = 0，阳 = 1
   - bit0 对应初爻（最下），bit(width-1) 对应最上爻
   - bits 的编码/解码正确

2. 覆盖常见用法：
   - 直接用 bits + 默认 width=6 构造六爻卦
   - 用 bits_list 构造三爻/六爻卦
   - 读取单个爻（yao）
   - 展开为 bits_list（to_bits_list）
   - is_trigram / is_hexagram 的判断

3. 覆盖常见错误场景：
   - width 非正
   - bits 超出合法范围
   - bits_list 为空
   - bits_list 中有非法元素（非 0/1）
   - 访问越界爻位
"""

import pytest

from yijing.core import (
    GuaCore,
    Bit,
    TrigramId,
    HexagramId,
)


# ----------------------------------------------------------------------
# 基础构造与属性测试
# ----------------------------------------------------------------------


def test_default_width_is_hexagram():
    """
    不传 width 时，默认应该是 6（六爻卦）。
    """
    g = GuaCore(bits=0b010101)
    assert g.width == 6
    assert g.bits == 0b010101
    assert g.is_hexagram
    assert not g.is_trigram


def test_explicit_trigram_width_3():
    """
    显式指定 width=3，用于三爻卦（八卦）。
    比如：101 表示 下阳、中阴、上阳。
    """
    g = GuaCore(bits=0b101, width=3)
    assert g.width == 3
    assert g.bits == 0b101
    assert g.is_trigram
    assert not g.is_hexagram

    # 检查自下而上爻值
    assert g.yao(0) == 1  # 初爻 阳
    assert g.yao(1) == 0  # 二爻 阴
    assert g.yao(2) == 1  # 三爻 阳


def test_construct_from_bits_list_hexagram():
    """
    使用 from_bits_list 从自下而上的 bit 列表构造六爻卦。
    示例： [1, 0, 1, 0, 1, 0] 表示
        初爻: 阳
        二爻: 阴
        三爻: 阳
        四爻: 阴
        五爻: 阳
        上爻: 阴
    """
    bits_list: list[Bit] = [1, 0, 1, 0, 1, 0]
    g = GuaCore.from_bits_list(bits_list)

    # width 应与列表长度一致
    assert g.width == 6

    # round-trip：再展开，应该和原来一样
    assert g.to_bits_list() == bits_list


def test_construct_from_bits_list_trigram():
    """
    使用 from_bits_list 构造三爻卦。
    示例： [0, 0, 0] = 三条阴爻。
    """
    bits_list: list[Bit] = [0, 0, 0]
    g = GuaCore.from_bits_list(bits_list)
    assert g.width == 3
    assert g.bits == 0  # 全阴 -> bits=0
    assert g.is_trigram
    assert g.to_bits_list() == bits_list


# ----------------------------------------------------------------------
# 公理验证：编码顺序与取值
# ----------------------------------------------------------------------


def test_bottom_is_bit0_and_top_is_highest_bit():
    """
    核心公理验证：
    - bit0 是初爻（最下）
    - 最高位 bit 是最上爻
    """
    # 初爻为阳，其余为阴
    g1 = GuaCore.from_bits_list([1, 0, 0, 0, 0, 0])
    assert g1.bits == 1
    assert g1.yao(0) == 1  # 初爻
    assert g1.yao(5) == 0  # 上爻

    # 仅最上爻为阳，其余为阴
    g2 = GuaCore.from_bits_list([0, 0, 0, 0, 0, 1])
    assert g2.bits == (1 << 5)  # 32
    assert g2.yao(0) == 0
    assert g2.yao(5) == 1


def test_roundtrip_bits_list_and_bits_value():
    """
    列表 → GuaCore → bits → GuaCore → 列表 的往返测试。
    确保编码和解码都是双向一致的。
    """
    bits_list: list[Bit] = [1, 1, 0, 1, 0, 0]
    g = GuaCore.from_bits_list(bits_list)

    # 再用 bits 和 width 重建一个
    g2 = GuaCore(bits=g.bits, width=g.width)

    assert g2.to_bits_list() == bits_list
    assert g2.bits == g.bits
    assert g2.width == g.width


# ----------------------------------------------------------------------
# 类型别名（TrigramId / HexagramId）的简单用法展示
# ----------------------------------------------------------------------


def test_trigram_and_hexagram_id_usage_example():
    """
    TrigramId / HexagramId 是语义上的类型别名，不改变底层 int 的含义，
    只是让代码在阅读时更容易区分「三爻卦 ID」和「六爻卦 ID」。
    """
    # 比如：0b111 三爻卦 可以作为一个 TrigramId
    trigram_id = TrigramId(0b111)
    assert int(trigram_id) == 0b111

    # 0b111111 六爻卦 ID
    hexagram_id = HexagramId(0b111111)
    assert int(hexagram_id) == 0b111111

    # 你可以在后续的 metadata/graph 中用这些别名标注字段类型，
    # 提高可读性，但本质仍是 int。
    assert isinstance(trigram_id, int)
    assert isinstance(hexagram_id, int)


# ----------------------------------------------------------------------
# 错误场景与异常测试
# ----------------------------------------------------------------------


def test_invalid_width_raises():
    """
    width 必须为正数。width <= 0 应该抛出 ValueError。
    """
    with pytest.raises(ValueError):
        GuaCore(bits=0, width=0)

    with pytest.raises(ValueError):
        GuaCore(bits=0, width=-3)


def test_bits_out_of_range_raises():
    """
    bits 的合法范围为 [0, 2^width - 1]。
    超出这个范围应抛出 ValueError。
    """
    # width=3 时，最大 bits = 0b111 = 7
    with pytest.raises(ValueError):
        GuaCore(bits=8, width=3)  # 超出范围

    # width=6 时，最大 bits = 0b111111 = 63
    with pytest.raises(ValueError):
        GuaCore(bits=64, width=6)  # 超出范围

    # 负数也不允许
    with pytest.raises(ValueError):
        GuaCore(bits=-1, width=6)


def test_empty_bits_list_raises():
    """
    from_bits_list 不允许空列表。
    否则 width=0，没有意义。
    """
    with pytest.raises(ValueError):
        GuaCore.from_bits_list([])


def test_bits_list_with_invalid_values_raises():
    """
    bits_list 中的元素必须是 0 或 1。
    如果传入其他值（包括 True/False 以外的内容），应该抛出 ValueError。
    """
    with pytest.raises(ValueError):
        GuaCore.from_bits_list([0, 2, 1])  # 包含 2

    with pytest.raises(ValueError):
        GuaCore.from_bits_list([0, -1, 1])  # 包含 -1

    with pytest.raises(ValueError):
        GuaCore.from_bits_list([0, 0.5, 1])  # 浮点数


def test_yao_out_of_range_raises():
    """
    访问超出 [0, width-1] 的爻位时，应抛出 IndexError。
    """
    g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])

    with pytest.raises(IndexError):
        _ = g.yao(-1)

    with pytest.raises(IndexError):
        _ = g.yao(6)


# ----------------------------------------------------------------------
# 展示：如何在测试里模拟“正常使用场景”
# ----------------------------------------------------------------------


def test_usage_scenario_example():
    """
    模拟一个正常使用场景，展示 Core 如何被上层调用。

    场景：
    - 已知某卦的爻为：下三爻全阳，上三爻全阴。
    - 使用 from_bits_list 构造本体。
    - 上层（未来的 L2/L3）只依赖 GuaCore 提供的接口，而不关心内部实现细节。
    """
    # 下阳阳阳，上阴阴阴
    bits_list: list[Bit] = [1, 1, 1, 0, 0, 0]
    g = GuaCore.from_bits_list(bits_list)

    # 上层关心的是：能可靠地取到某一爻的值
    assert g.yao(0) == 1  # 初爻 阳
    assert g.yao(1) == 1  # 二爻 阳
    assert g.yao(2) == 1  # 三爻 阳
    assert g.yao(3) == 0  # 四爻 阴
    assert g.yao(4) == 0  # 五爻 阴
    assert g.yao(5) == 0  # 上爻 阴

    # 以及：可以随时展开为列表，用于可视化或传给前端
    assert g.to_bits_list() == bits_list
```

---

## 三、下一步你可以做的事

1. 在项目根目录创建结构：

   ```bash
   mkdir -p yijing tests
   touch yijing/__init__.py
   ```

2. 把之前的 `core.py` 放到 `yijing/core.py`。
3. 把刚才的 `test_core.py` 放到 `tests/test_core.py`。
4. 安装 pytest（如果还没装）：

   ```bash
   pip install pytest
   ```

5. 在项目根目录运行：

   ```bash
   pytest
   ```

看到所有测试通过，就说明 L1.Core 这块地基是稳的了 ✅

---

如果你愿意，下一步我们可以在这个 Core 基础上，**用一个非常小的 L2 步子**，比如：

- 只实现 “上下卦拆分 / 组合”（trigram ↔ hexagram 的映射），
先不碰变卦、错卦，这样节奏也比较平稳。

-----

> 很好，有个pytest测试时的常见问题，你认为用什么方式解决最为方便？——rootdir: /home/xashes/projects/dao
> plugins: anyio-4.8.0
> collected 0 items / 1 error
>
> ==================================== ERRORS =====================================______________________ ERROR collecting tests/test_core.py ______________________ImportError while importing test module '/home/xashes/projects/dao/tests/test_core.py'.
> Hint: make sure your test modules/packages have valid Python names.
> Traceback:
> ../../anaconda3/lib/python3.11/importlib/__init__.py:126: in import_module
>     return _bootstrap._gcd_import(name[level:], package, level)
>            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
> tests/test_core.py:30: in <module>
>     from yijing.core import (
> E   ModuleNotFoundError: No module named 'yijing'
> ============================ short test summary info ============================ERROR tests/test_core.py
> !!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!!=============================== 1 error in 0.09s ================================
> 另外，还有个小问题，子文件夹命名为yijing似乎不是很贴切，易经虽然是源头，但以后涉及的很多内容并不是易经的内容，而是玄学或道家学派的内容，请问是否改名为dao或其他什么更好？或者一般这个文件夹叫什么？src？请帮我设计个更贴切的名称

这个报错非常典型，我们一步一步来解决，然后顺便把命名问题一起定下来。

---

## 一、为什么会出现 `ModuleNotFoundError: No module named 'yijing'`？

pytest 的关键信息：

```text
rootdir: /home/xashes/projects/dao
...
ModuleNotFoundError: No module named 'yijing'
```

说明两件事：

1. pytest 把 **项目根目录** 认成了：`/home/xashes/projects/dao`
2. 运行 `from yijing.core import ...` 时，Python 在 `sys.path` 里找不到名为 `yijing` 的包

最常见原因就三个：

- 根目录下 **没有 `yijing/` 这个文件夹**，或者路径不对
- 有 `yijing/` 文件夹，但里面 **没有 `__init__.py`**，Python 不把它当包
- pytest 不是从项目根目录跑的（比如在 `tests` 目录里执行 `pytest`）

---

## 二、在说命名之前：最方便的“当前错误”解决方式

你现在已经准备把包名改掉了（不想叫 `yijing`），那我们可以直接用“改名+结构整理”一把搞定错误。

我建议你采用一个比较标准又简单的结构：

```text
/home/xashes/projects/dao
├─ src/
│  └─ dao/            # 包名：dao（道家整体体系，更通用）
│     ├─ __init__.py
│     └─ core.py      # 我们的 GuaCore 放这里
└─ tests/
   └─ test_core.py
```

### 1. 具体操作步骤

在项目根目录 `/home/xashes/projects/dao` 下：

```bash
mkdir -p src/dao
mv yijing/core.py src/dao/core.py  # 如果之前 core.py 在 yijing 目录下
rm -r yijing  # 如果原来有 yijing，可以删掉（确保没别的东西）
touch src/dao/__init__.py
```

然后修改 `tests/test_core.py` 里的导入：

```python
from dao.core import (
    GuaCore,
    Bit,
    TrigramId,
    HexagramId,
)
```

接下来让 Python 知道 `src` 这个目录是可以找包的（有两个方式，选你觉得方便的）：

### 方式 A：临时简单方式（开发阶段很好用）

在项目根目录执行：

```bash
export PYTHONPATH=$PWD/src:$PYTHONPATH
pytest
```

这样 `src` 会加进 `PYTHONPATH`，Python 能找到 `dao` 包，`from dao.core import ...` 就不会再报错了。

> 每次新开终端都要重新 `export` 一次，或者把这行加进你的 `~/.bashrc` / `~/.zshrc`。

### 方式 B：以后想规范一点（装成可编辑包）

这个可以以后再弄，现在知道有这么条路就好：

- 写一个简单的 `pyproject.toml` / `setup.cfg`
- 在根目录执行：`pip install -e .`
- 之后不再手动管 `PYTHONPATH`

先别急，我们可以等项目稍微成型再搞。

---

## 三、关于包名：为什么我建议叫 `dao` 而不是 `yijing`

你说得很对：
> 易经虽然是源头，但以后涉及的很多内容并不是易经的内容，而是玄学或道家学派的内容

所以：

- `yijing` 太具体了，会让人误解“只做易经”
- `src` 只是一个技术性目录名，一般用来放源代码，**不是业务含义**

业务上更贴切的包名候选：

- `dao`：简洁、有主题，能涵盖易、术、命、相等整套“道家体系”
- `daocore`：强调“基础库”
- `daometa` / `daostack` 等等

在你当前这个项目里，我觉得 **直接叫 `dao` 很自然**：

- 仓库名已经是 `dao`
- 包名也叫 `dao`，语义很统一：`dao.core`, `dao.ops`, `dao.graph`… 一看就知道这是“道家体系项目”。

唯一需要注意的小点：

- 如果你将来要发到 PyPI，再查一下有没有同名包
- 如果冲突，再改叫 `dao-core` 或 `daostack` 也很容易迁移

---

## 四、小结：最方便的解决方案

**一步到位的建议：**

1. 按下面这样整理目录：

   ```text
   dao/
   ├─ src/
   │  └─ dao/
   │     ├─ __init__.py
   │     └─ core.py
   └─ tests/
      └─ test_core.py
   ```

2. 把测试里的导入统一改成：

   ```python
   from dao.core import GuaCore, Bit, TrigramId, HexagramId
   ```

3. 在项目根目录运行：

   ```bash
   export PYTHONPATH=$PWD/src:$PYTHONPATH
   pytest
   ```

这样：

- `ModuleNotFoundError` 能立刻解决
- 包名从一开始就是更宽泛的 `dao`，以后扩展到命理、风水、内丹、象数都不违和
- Core 这块我们已经用测试锁死行为，后面可以安心往 L2 走了

---

如果你愿意，下一步我可以在这个新结构下，**给你一个很小的 L2 模块骨架**（例如 `dao/ops_basic.py`），只做一件事：
> 把一个六爻卦拆成「上卦 trigram」和「下卦 trigram」，以及反向组合。
我们继续保持“小步走，每一步都有测试”的节奏。

-----

> 既然叫dao了，为什么还要放进一个src的子文件夹呢？这有什么设计意图呢

好问题，你一下就问到 Python 项目结构里一个“宗教战争”级别的话题 😂——**要不要用 `src` layout**。

我先直接回答你的问题，然后再说“要不要用”。

---

## 1. 为什么很多项目喜欢 `src/dao` 这种结构？

这个结构常见是这样：

```text
dao/                  # 仓库根目录（也是 git 根）
├─ src/
│  └─ dao/            # 真正的 Python 包
│     ├─ __init__.py
│     └─ core.py
└─ tests/
   └─ test_core.py
```

**设计意图主要有两个：**

### （1）防止“本地跑得好，一装就炸”的经典坑

如果没有 `src/`，而是：

```text
dao/
├─ dao/          # 包
└─ tests/
```

你在仓库根目录跑 `pytest` 时，Python 的 `sys.path` 通常会自动把当前目录加进去，于是：

- `import dao` 会导入 **当前目录下的 `dao/` 文件夹**（一切正常）
- 但当你以后把这个包 `pip install` 装到环境里时，
  运行环境里就不一定有“当前目录”，导入逻辑会有差异

最终效果就是：
> 在项目目录里跑一切正常，一打包/一部署就各种 `ModuleNotFoundError`。

而 `src/dao` 的用意就是：
> **让测试时代码的导入方式尽量接近“安装后”的样子**。

因为你必须显式把 `src` 加进 `PYTHONPATH` 或通过 `pip install -e .` 安装，
**和将来真实使用时的搜索路径更一致**，不容易踩那种“本机好好的，服务器挂了”的坑。

---

### （2）把“库代码”和“项目根杂物”分隔开

以后你的仓库里可能会有很多东西：

```text
dao/
├─ src/dao/           # 纯粹的库代码
├─ tests/             # 测试
├─ scripts/           # 一些脚本、工具
├─ docs/              # 文档
├─ examples/          # 示例
├─ pyproject.toml
└─ README.md
```

`src/dao` 这种 layout 有一个简单的理念：

- **只有 `src/dao` 里的东西是“对外提供的库”**
- 根目录其他都是“工程配套”：脚本、配置、文档、CI 等

对以后打包、发版、做文档时会清晰很多。

---

## 2. 那你这个项目，“必须用 src 吗？”

**完全不是必须。**

你现在是个人/小团队项目，又不是一上来就要发 PyPI、搞多环境部署，
**不用 `src` 也完全没问题**，甚至更简单直观。

如果你更喜欢“干净一点”的结构，我反而建议你现在可以就这样：

```text
/home/xashes/projects/dao
├─ dao/              # 直接作为包
│  ├─ __init__.py
│  └─ core.py
└─ tests/
   └─ test_core.py
```

然后：

- `test_core.py` 里导入：

  ```python
  from dao.core import GuaCore, Bit, TrigramId, HexagramId
  ```

- 确保你在 **项目根目录**（`/home/xashes/projects/dao`）里跑：

  ```bash
  pytest            # 或 python -m pytest
  ```

- 如果还是遇到 `ModuleNotFoundError: No module named 'dao'`，
  就手动加一行环境变量（只在开发机上用即可）：

  ```bash
  export PYTHONPATH=$PWD:$PYTHONPATH
  pytest
  ```

这样：

- 你不需要 `src/` 这种“多一层”的结构
- 包名就叫 `dao`，目录名也叫 `dao`，非常直观
- 以后如果要更规范，再引入 `src` layout 也完全来得及（目录挪一下而已）

---

## 3. 那要不要现在就用 `src`？我给你一个“人话判断标准”

用不用 `src/dao`，你可以按这个简单标准来想：

- **你现在更在意：**
  - ✅ 开发体验简单直观
  - ✅ 先把“道家系统的模型”一点点搭起来
  - ⏳ 打包、部署、发版是以后才考虑的事

👉 那现在就用 **根目录直接放 `dao/` 包** 最舒服。

- 等到哪一天：
  - 你准备做成“别的项目也要 `pip install dao` 来用”的公共库
  - 或者开始考虑 CI 多环境测试、发 PyPI 等
  👉 再迁到 `src/dao`，也很容易。

---

## 4. 实操建议（基于你现在的问题）

结合你现在的项目情况，我建议你：

### 方案：不用 `src`，直接简化

1. 目录改成：

   ```text
   /home/xashes/projects/dao
   ├─ dao/
   │  ├─ __init__.py
   │  └─ core.py
   └─ tests/
      └─ test_core.py
   ```

2. 确保 `dao/__init__.py` 至少存在（可以先空着）。

3. 测试文件里导入：

   ```python
   from dao.core import GuaCore, Bit, TrigramId, HexagramId
   ```

4. 在项目根目录运行：

   ```bash
   cd /home/xashes/projects/dao
   pytest
   ```

5. 如果还提示找不到 `dao`，再补一刀：

   ```bash
   export PYTHONPATH=$PWD:$PYTHONPATH
   pytest
   ```

基本就稳了。

---

## 5. 总结一句话

- `src/dao` 是一种**更偏“库发布/工程规范”的布局习惯**，
  主要是为了解决“本地跑得好，安装后挂掉”的问题；
- 你的项目现在重点是：**一步步建好“道”的模型与运算”，而不是马上发库**；
- 所以：**直接用根目录下的 `dao/` 作为包就很好**，简单、清晰，也更符合你现在的节奏。

如果你愿意，下一步你可以把你现在实际的目录结构贴一下（缩成几行就行），我可以帮你 1:1 对照给出“准确到命令行”的调整方案，保证 `pytest` 一次跑通，然后我们就可以开始写第一个 L2 模块了。

-----

> 现有的目录结构
> xashes@nuc11 ~/p/dao (main)> tree                                         (base) .
> ├── dao
> │   ├── core.py
> │   └── __init__.py
> ├── LICENSE
> └── tests
>     ├── __pycache__
>     │   └── test_core.cpython-311-pytest-8.4.2.pyc
>     └── test_core.py
>
> 4 directories, 5 files

这个目录长这样，其实已经是非常标准、干净的一套了：

```text
/home/xashes/projects/dao
├── dao
│   ├── core.py
│   └── __init__.py
├── LICENSE
└── tests
    ├── __pycache__
    └── test_core.py
```

所以现在只剩下两类常见坑会导致 `ModuleNotFoundError`：

1. **测试里导入的包名不对**
2. **pytest 运行的位置 / sys.path 不对**

咱们一个个排。

---

## 1. 确认导入语句

请先打开 `tests/test_core.py`，看顶部的导入是不是已经改成这样：

```python
from dao.core import (
    GuaCore,
    Bit,
    TrigramId,
    HexagramId,
)
```

如果还是 `from yijing.core import ...`，那肯定会找不到。

---

## 2. 最方便的解决方式：在项目根目录用 `python -m pytest`

你现在的项目根目录是：

```text
/home/xashes/projects/dao
```

以后跑测试，**尽量都在这个目录下**跑，而不是 cd 到 `tests/` 里面。

推荐命令：

```bash
cd /home/xashes/projects/dao
python -m pytest
```

为什么这样最方便？

- `python -m pytest` 会用当前目录当成一个“顶层包搜索路径”（加入 `sys.path`）
- 你的 `dao/` 包刚好就在当前目录里，所以 `import dao` 能直接找到
- 不需要额外写 `PYTHONPATH`、不需要 `src`、不需要安装包，开发体验最简单

> 很多 `ModuleNotFoundError`，其实都是在 `tests/` 目录里直接跑了 `pytest`，
> 结果 rootdir 变成 `.../dao/tests`，它的“同级目录”里没有 `dao/`，自然就导入不了。

你可以试两步来验证：

```bash
cd /home/xashes/projects/dao
python -q      # 进入 Python 交互
>>> import dao
>>> from dao.core import GuaCore
>>> GuaCore(bits=0b010101)
```

这三行都正常的话，`python -m pytest` 基本就稳了。

---

## 3. 如果你非要写死一个“最保险”的办法

假设有一天你真的不小心在 `tests/` 目录里跑了 `pytest`，
可以在 `tests/conftest.py` 里手动把项目根目录塞进 `sys.path`（这也是常见做法）：

在 `tests/` 里新建一个 `conftest.py`：

```python
# tests/conftest.py
import os
import sys

# 项目根目录 = 当前文件的上一级目录的上一级目录
PROJECT_ROOT = os.path.dirname(os.path.dirname(__file__))

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)
```

这样就算你在 `tests/` 里执行 `pytest`，Python 也会把项目根目录加进路径里，
`from dao.core import ...` 依然能成功。

不过就你现在的情况，我更推荐“简单路线”：

> **习惯在项目根目录，用 `python -m pytest` 跑测试**
> 这样路径问题基本绝迹。

---

### 小结一下

- 你的目录结构已经很好，不需要 `src/` 这一层。
- 修改测试导入为 `from dao.core import ...`。
- 在项目根目录执行：

  ```bash
  cd /home/xashes/projects/dao
  python -m pytest
  ```

如果运行后还有报错，你可以把新的报错贴出来，我们再看下一步；
一旦这一关通过，我们就可以开始在 `dao/` 下面加第一个 L2 模块了。

-----

> 非常好，测试完全通过。
> 在开始L2之前，我记得你之前提到L1还有余下的几步——
> B. 静态语义表（Static Metadata Tables）
> 把“多数人一致同意”但又不属于计算本体的内容放成表：
> 如 卦名、卦序、上下卦、先天/后天位置、五行归属（主流版）。
> C. 关系语义图（Semantic Graph / Knowledge Layer）
> 凡是出现任意一种情况，就不要塞表里，而要进图层：
>
> 多对多关系
>
> 有条件/上下文（时间、节气、爻位、动静）
>
> 不同流派差异大
>
> 你未来可能继续加新关系
>
> 我们是应该在完成L1的一个部分之后，就继续完成这部分对应的L2？还是继续完成L1的其他部分？
> 在继续之前，请完善一下开发方案，给出你的意见，然后我们讨论一下如何？

现在这个进度非常舒服：Core 已经定死、测试通过，我们可以把后面的路规划得清楚一点再动手。

我先回答你那个关键问题：

> 是先把 L1 的 B/C 做完，还是先上 L2？

我的意见是：
**现在先继续做 L1（静态语义表 + 关系图）的“数据形式设计”，暂时不急着写复杂 L2，只在需要的时候加一点点最基础的运算。**
理由是你一开始就强调的——“底层的数据形式是一切的基础”。

下面我按“开发路线图”的方式讲清楚，每一步我们都可以单独讨论、单独写代码。

---

## 1. 我们现在的状态：L1.Core = v1.0

当前已经完成的：

- 包结构：`dao/`（包） + `tests/`（测试）
- `dao.core.GuaCore`：
  - 阴 0 / 阳 1
  - bit0 = 初爻（最下），bit(width-1) = 最上
  - 支持 width=3 / 6
  - from_bits_list / to_bits_list / yao() 等
- 正式 pytest 单元测试，锁死了这些行为

**结论**：
> “卦的二进制本体”已经是一个稳定基石，不需要再改了。

---

## 2. L1 的后两块到底要做什么？

### B. 静态语义表（Static Metadata）

这是“**多数人一致同意、但不属于计算本体**”的内容：

- 卦名（乾、坤、屯……）
- 上卦 / 下卦（作为 trigram id）
- 卦序（如文王序号）
- 常用五行归属（例如主流版）
- 先天 / 后天位置（可以有版本）

**注意**：这里我们关注的是 **“数据结构（schema）+ 存储形式”**，
不是一下子把 64 卦所有资料都录完。

也就是说，这一步要解决的问题是：

> “一条卦的静态信息，用 JSON/YAML 怎么表达？
> 在 Python 里用什么 dataclass 来承接？
> 怎么给不同‘学派版本’留出口子？”

---

### C. 关系语义图（Semantic Graph）

这是“**多对多 + 有条件 + 会随派别扩展**”的部分：

- 五行之间的生克关系
- 卦 ↔ 五行 ↔ 方位 ↔ 节气 之间的链接
- 天干地支 ↔ 纳甲 ↔ 卦爻
- 六亲、六神随日辰变动的规则

这里我们同样先关注：

- **节点 Node 的数据结构**：id、type、props
- **边 Edge 的数据结构**：from、to、type、props
- 文件格式（JSON/node+edges）
- 版本与“学派”的区分方式

也是先解决：

> “图怎么存？怎么加载？怎么区分不同流派？”
> 而不是马上把所有古籍都录进去。

---

## 3. L2 究竟要干什么（方便我们划分界线）

我把 L2 拆两层，你会更清晰：

### L2.a「纯运算层」（Bit-level ops，贴着 Core）

只依赖 `GuaCore`，不依赖任何语义：

- 拆分上下卦：`hexagram -> (upper_trigram, lower_trigram)`
- 组合上下卦：`(upper_trigram, lower_trigram) -> hexagram`
- 变爻：翻转某些 bit
- 错卦：全翻
- 综卦：bit 反序
- 互卦：按固定规则从 6 爻抽 4 爻重组上下卦

它们的输入输出可以设计成：

```python
def split_trigrams(g: GuaCore) -> tuple[GuaCore, GuaCore]: ...
def combine_trigrams(lower: GuaCore, upper: GuaCore) -> GuaCore: ...
def flip_yao(g: GuaCore, positions: list[int]) -> GuaCore: ...
# 等等
```

**这类函数不需要知道“五行”“卦名”，纯粹在 bit 上玩。**

---

### L2.b「语义运算层」（Semantic Ops）

这部分会同时用到：

- Core（`GuaCore`）
- 静态表（卦名/五行/方位等）
- 图（节点和边）

比如：

- 查“这卦的五行、生克关系、方位、对应节气”
- 某一爻动后，结合纳甲 / 六亲给出解释
- 从“时间 + 方位 +卦”组合中推演某种模式

所以 **L2.b 必须建立在 L1.B/C 已经设计好的前提上。**

---

## 4. 两种推进策略的对比

### 策略 1：先把 L1 全部设计完，再上 L2

顺序大概是：

1. L1.Core（已经完成）
2. 设计 L1.B 的表结构 + 样例 JSON + loader
3. 设计 L1.C 的图结构 + 样例 JSON + loader
4. 再做 L2.a / L2.b

**优点：**

- 完全符合你“先数据后操作”的思想
- 所有运算一上来就有比较完整的数据背景可用

**缺点：**

- 在设计 L1.B/C 的 schema 时，缺少了一些“真实运算需求的反馈”
  容易出现：schema 设计得很学术，但写 L2 时发现不太好用，需要再回改。

---

### 策略 2：Core 完成后，先做一点点 L2.a，再做 L1.B/C

顺序大概是：

1. ✅ L1.Core（done）
2. 🔜 L2.a 基础运算（只做极小子集，如上下卦拆/合）
3. 设计 L1.B schema + 样例文件
4. 设计 L1.C schema + 样例文件
5. 扩展 L2.a（变、错、综、互）
6. 再做 L2.b（语义运算）

**优点：**

- 在设计 L1.B/C 时，已经有一小部分真实运算函数可以“试 schema 好不好用”
- 可以保证 metadata/schema 设计不会脱离后续实际使用场景
- 你一开始看到的 L2 也是干净的 bit-level 运算，不会引入语义混乱

**缺点：**

- 看起来“顺序上有点跳”（从 L1 跳到小块 L2 再回 L1），不过实质上没问题

---

## 5. 我的建议：现在走“策略 2”的轻量版

考虑到你非常重视**避免误解、避免以后返工**，我建议的路线是：

> **先在 Core 上加一层非常薄的 L2.a 基础运算（几乎全是位操作），
> 然后再来定义 L1.B/L1.C 的 schema。**

具体到我们接下来要做的几步，可以明确成这样：

### ✅ 步骤 0：Core 已完成（当前状态）

- `dao.core.GuaCore` + 测试

---

### 🔜 步骤 1：L2.a 基础运算（very small）

新建 `dao/ops_basic.py`，只做三类最小功能：

1. 上下卦拆分 + 组合

   ```python
   def split_trigrams(g: GuaCore) -> tuple[GuaCore, GuaCore]: ...
   def combine_trigrams(lower: GuaCore, upper: GuaCore) -> GuaCore: ...
   ```

2. 一个最基础的变爻函数（给定爻位 list，翻转）

   ```python
   def flip_yao(g: GuaCore, positions: list[int]) -> GuaCore: ...
   ```

3. 对应的 pytest 测试文件 `tests/test_ops_basic.py`，展示用法（不掺语义）

这一步的作用就是：
> “确认我们在 bit 层面上玩上下卦/变爻时，接口长什么样、什么感觉好用。”

---

### 🧩 步骤 2：设计 L1.B 静态表的 **schema**（不是数据全集）

目标是只解决问题：

- Hexagram / Trigram 的 metadata 一条记录长什么样？
- 怎么表述“这个 metadata 属于哪个学派/版本”？（例如 `school`, `version` 字段）
- JSON 文件整体的结构如何组织？
- 用什么 dataclass 来接住？

可能会形成一个模块：`dao/meta_types.py` 或 `dao/metadata.py`，包含：

```python
@dataclass
class MetaVersionInfo: ...
@dataclass
class TrigramMeta: ...
@dataclass
class HexagramMeta: ...
```

再配一个很小的 JSON 样例（比如只录 2 个 trigram + 2 个 hexagram），配上 loader 和测试。

---

### 🧠 步骤 3：设计 L1.C 关系图的 **schema**

类似地，我们先决定：

- Node 的结构：`id`, `type`, `props`
- Edge 的结构：`from`, `to`, `type`, `props`
- Graph 的整体组织方式
- 学派/版本的区分方式

对应模块可以是 `dao/graph_types.py` 或 `dao/semantic_graph.py`
再附一个小 JSON 样例 + loader + pytest。

---

### ⚙️ 步骤 4：再回来扩展 L2.a / 新建 L2.b

- 把错卦、综卦、互卦等完整做掉
- 开始写用 metadata/graph 的查询函数（L2.b）

---

## 6. 总结一下我的意见

一句话版本：

> **现在别急着上复杂 L2 和可视化，
> 先在 Core 上加一层很薄的基础运算（L2.a 初版），
> 然后设计好静态表和关系图的 schema，再扩建 L2。**

这样可以同时满足你两个核心诉求：

1. **“底层数据形式设计好”**：
   Core + metadata schema + graph schema 都是 L1 层的设计成果。
2. **“每一步都验证好用性，避免误解”**：
   通过小块 L2.a 的实际使用感，反向检验 schema 是否顺手。

---

如果你觉得这个路线 OK，
我建议我们就从 **“步骤 1：dao/ops_basic.py + test_ops_basic.py”** 开始：
只做上下卦拆/合 + 基础变爻，把接口和测试先写小而清楚。
你只要一句“可以”，我就按这个思路给出 `ops_basic.py` 的草案和对应测试，我们继续保持现在这种“小步+注释+测试”的节奏往前走。

-----

> 可以

好，那我们按计划来，先把 **L2.a 的最小一块：上下卦拆/合 + 变爻** 做出来，而且保持和 Core 一样：
- 设计目标写清楚
- 接口简单、纯计算
- 有 pytest 单测

下面分两部分给你：

- `dao/ops_basic.py`
- `tests/test_ops_basic.py`

你可以直接拷进去，再跑一次 `python -m pytest`。

---

## 一、`dao/ops_basic.py`——基础运算层（最小版）

```python
"""
ops_basic.py

L2.a：基础运算层（Bit-level operations）

设计目标
--------
在不引入任何「语义」的前提下，为 GuaCore 提供最基础的
二进制级别运算函数。这一层只处理 bits 结构，不关心卦名、
五行、方位等解释内容。

当前包含的能力
--------------
1. 上下卦拆分与组合（仅针对六爻卦）：
   - split_trigrams(g): GuaCore(6) -> (lower_trigram, upper_trigram)
   - combine_trigrams(lower, upper): (GuaCore(3), GuaCore(3)) -> GuaCore(6)

2. 基础变爻：
   - flip_yao(g, positions): 在给定爻位列表上翻转阴阳

注意：
- 本模块只依赖 dao.core，不依赖任何 metadata 或语义图。
- 所有函数应尽量设计为「纯函数」：输入不变，返回新实例。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Tuple, List

from .core import GuaCore, TrigramId, HexagramId


# ----------------------------------------------------------------------
# 上下卦拆分与组合
# ----------------------------------------------------------------------


def split_trigrams(g: GuaCore) -> Tuple[GuaCore, GuaCore]:
    """
    将一个六爻卦拆分为下卦和上卦两个三爻卦。

    参数
    ----
    g : GuaCore
        预期是 width=6 的六爻卦。
        目前实现只支持 width=6，如果传入其他 width 会抛出 ValueError。

    返回
    ----
    (lower, upper) : Tuple[GuaCore, GuaCore]
        lower.width == 3，upper.width == 3
        - lower: 取原卦的第 0~2 爻（下三爻）
        - upper: 取原卦的第 3~5 爻（上三爻）

    说明
    ----
    这里不做任何卦名/五行解释，只在 bits 层面做拆分。
    """
    if g.width != 6:
        raise ValueError(
            f"split_trigrams only supports width=6 hexagrams, got width={g.width}"
        )

    # 下卦：bit0~bit2 原样保留
    lower_bits = g.bits & 0b111  # 0b111 == 7

    # 上卦：bit3~bit5 右移 3 位
    upper_bits = (g.bits >> 3) & 0b111

    lower = GuaCore(bits=lower_bits, width=3)
    upper = GuaCore(bits=upper_bits, width=3)
    return lower, upper


def hexagram_id(g: GuaCore) -> HexagramId:
    """
    将六爻卦的 bits 视为 HexagramId（语义型别名）。

    要求
    ----
    - g.width 必须为 6，否则抛出 ValueError。

    说明
    ----
    这里仍然不引入任何具体“卦名”，只是提供一个更语义化的 ID 类型，
    方便后续在 metadata 中用 HexagramId 作为 key。
    """
    if g.width != 6:
        raise ValueError(
            f"hexagram_id expects width=6, got width={g.width}"
        )
    return HexagramId(g.bits)


def trigram_id(g: GuaCore) -> TrigramId:
    """
    将三爻卦的 bits 视为 TrigramId（语义型别名）。

    要求
    ----
    - g.width 必须为 3，否则抛出 ValueError。
    """
    if g.width != 3:
        raise ValueError(
            f"trigram_id expects width=3, got width={g.width}"
        )
    return TrigramId(g.bits)


def combine_trigrams(lower: GuaCore, upper: GuaCore) -> GuaCore:
    """
    将下卦和上卦两个三爻卦组合成一个六爻卦。

    参数
    ----
    lower : GuaCore
        预期为 width=3 的三爻卦，作为下卦（对应六爻卦的 bit0~2）。
    upper : GuaCore
        预期为 width=3 的三爻卦，作为上卦（对应六爻卦的 bit3~5）。

    返回
    ----
    GuaCore
        width=6 的六爻卦，本质上是：
            hex_bits = lower.bits + (upper.bits << 3)

    异常
    ----
    如果 lower.width 或 upper.width 不是 3，则抛出 ValueError。

    说明
    ----
    这个函数与 split_trigrams 构成一对“往返”操作：
        combine_trigrams(*split_trigrams(g)) == g  （在 width=6 的范围内）
    """
    if lower.width != 3 or upper.width != 3:
        raise ValueError(
            f"combine_trigrams expects both lower/upper to have width=3, "
            f"got lower.width={lower.width}, upper.width={upper.width}"
        )

    hex_bits = lower.bits | (upper.bits << 3)
    return GuaCore(bits=hex_bits, width=6)


# ----------------------------------------------------------------------
# 基础变爻：在指定爻位上翻转阴阳
# ----------------------------------------------------------------------


def flip_yao(g: GuaCore, positions: Iterable[int]) -> GuaCore:
    """
    在给定爻位列表上翻转阴阳（0 <-> 1），返回新的 GuaCore。

    参数
    ----
    g : GuaCore
        原卦，可以是 width=3 或 width=6（或其他正整数）。
    positions : Iterable[int]
        需要翻转的爻位集合，使用「自下而上」的索引：
            - 0 表示初爻（最下）
            - g.width-1 表示最上爻

        示例：
            flip_yao(g, [0])        # 只变初爻
            flip_yao(g, [0, 2, 5])  # 同时变多个爻

    返回
    ----
    GuaCore
        新的卦对象，原 g 不会被修改。

    异常
    ----
    - 如果 positions 中有越界（<0 或 >= g.width），则抛出 ValueError。

    设计说明
    --------
    - 使用 XOR（异或）实现翻转：bit ^ 1。
    - 这里不区分“动爻”“静爻”等语义，只做纯比特翻转。
      动静的解释会交给上层语义层（L2.b / L3）。
    """
    mask = 0
    positions_list: List[int] = list(positions)

    for pos in positions_list:
        if not (0 <= pos < g.width):
            raise ValueError(
                f"flip_yao position out of range: {pos}, width={g.width}"
            )
        mask |= (1 << pos)

    # XOR 掩码：对应位置 0->1, 1->0，其它位不变
    new_bits = g.bits ^ mask
    return GuaCore(bits=new_bits, width=g.width)
```

---

## 二、`tests/test_ops_basic.py`——基础运算的测试与用法展示

```python
"""
tests/test_ops_basic.py

对 dao.ops_basic 中的基础运算函数进行单元测试与用法展示。

覆盖内容
--------
1. 上下卦拆分：
   - split_trigrams 对典型六爻卦的拆分是否正确
   - 非 width=6 的输入是否正确抛异常

2. 上下卦组合：
   - combine_trigrams 是否与 split_trigrams 构成往返
   - 非 width=3 的下卦/上卦是否抛异常

3. ID 型别名辅助：
   - hexagram_id / trigram_id 的基本用法

4. 基础变爻：
   - 单一爻位翻转
   - 多个爻位翻转
   - 越界爻位是否抛异常

测试目的
--------
- 确认 L2.a 的基础接口在 bits 层面是自洽的。
- 为后续 L1.B/L1.C 的 schema 设计提供真实使用感受。
"""

import pytest

from dao.core import GuaCore
from dao.ops_basic import (
    split_trigrams,
    combine_trigrams,
    flip_yao,
    hexagram_id,
    trigram_id,
)


# ----------------------------------------------------------------------
# 上下卦拆分与组合
# ----------------------------------------------------------------------


def test_split_trigrams_from_hexagram():
    """
    测试从一个六爻卦中拆出上下卦（各三爻）。

    示例卦：
        bits_list = [1, 0, 1, 0, 1, 0]
        对应自下而上：
            初爻: 1
            二爻: 0
            三爻: 1
            四爻: 0
            五爻: 1
            上爻: 0

        下卦 (0~2): [1, 0, 1]
        上卦 (3~5): [0, 1, 0]
    """
    g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])
    lower, upper = split_trigrams(g)

    # 下卦、上卦都应该是 width=3 的三爻卦
    assert lower.width == 3
    assert upper.width == 3

    assert lower.to_bits_list() == [1, 0, 1]
    assert upper.to_bits_list() == [0, 1, 0]


def test_split_trigrams_requires_width_6():
    """
    split_trigrams 只接受 width=6 的卦。
    其他 width 的输入应该抛出 ValueError。
    """
    # 三爻卦
    g3 = GuaCore.from_bits_list([1, 0, 1])
    with pytest.raises(ValueError):
        split_trigrams(g3)

    # width=4 之类的奇怪情况也不支持
    g4 = GuaCore(bits=0b1010, width=4)
    with pytest.raises(ValueError):
        split_trigrams(g4)


def test_combine_trigrams_roundtrip():
    """
    combine_trigrams 与 split_trigrams 应该构成往返。

    即：
        g2 = combine_trigrams(*split_trigrams(g1))
        则 g2 应与 g1 在 bits 与 width 上完全相同。
    """
    original = GuaCore.from_bits_list([1, 1, 0, 1, 0, 0])
    lower, upper = split_trigrams(original)

    combined = combine_trigrams(lower, upper)

    assert combined.width == original.width
    assert combined.bits == original.bits
    assert combined.to_bits_list() == original.to_bits_list()


def test_combine_trigrams_requires_width_3():
    """
    combine_trigrams 要求 lower/upper 都是 width=3 的三爻卦。
    否则抛出 ValueError。
    """
    lower = GuaCore.from_bits_list([1, 0, 1])  # width=3
    upper = GuaCore.from_bits_list([0, 1, 0])  # width=3

    # 正常情况不抛异常
    _ = combine_trigrams(lower, upper)

    # upper 换成六爻卦，应抛异常
    bad_upper = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])
    with pytest.raises(ValueError):
        combine_trigrams(lower, bad_upper)


# ----------------------------------------------------------------------
# HexagramId / TrigramId 用法示例
# ----------------------------------------------------------------------


def test_hexagram_and_trigram_id_usage():
    """
    展示 hexagram_id / trigram_id 的基本用法：
    它们只是更语义化的 int 别名，不改变 bits 的值。
    """
    hex_g = GuaCore.from_bits_list([1, 1, 1, 1, 1, 1])  # 六阳
    tri_g = GuaCore.from_bits_list([0, 1, 0])           # 阴阳阴

    h_id = hexagram_id(hex_g)
    t_id = trigram_id(tri_g)

    assert int(h_id) == hex_g.bits
    assert int(t_id) == tri_g.bits

    # 类型上看，仍然是 int 的子类（NewType 的运行时效果如此）
    assert isinstance(h_id, int)
    assert isinstance(t_id, int)


def test_hexagram_id_requires_width_6():
    """
    hexagram_id 只接受 width=6 的 GuaCore。
    """
    tri_g = GuaCore.from_bits_list([1, 0, 1])  # width=3
    with pytest.raises(ValueError):
        hexagram_id(tri_g)


def test_trigram_id_requires_width_3():
    """
    trigram_id 只接受 width=3 的 GuaCore。
    """
    hex_g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])  # width=6
    with pytest.raises(ValueError):
        trigram_id(hex_g)


# ----------------------------------------------------------------------
# 基础变爻：flip_yao
# ----------------------------------------------------------------------


def test_flip_single_yao():
    """
    测试翻转单个爻位。

    示例：
        原卦：bits_list = [1, 0, 0, 0, 0, 0]
        只翻转初爻(0位)：
        新卦应为：[0, 0, 0, 0, 0, 0]
    """
    g = GuaCore.from_bits_list([1, 0, 0, 0, 0, 0])
    g2 = flip_yao(g, [0])

    assert g.to_bits_list() == [1, 0, 0, 0, 0, 0]  # 原卦不变
    assert g2.to_bits_list() == [0, 0, 0, 0, 0, 0]


def test_flip_multiple_yaos():
    """
    测试同时翻转多个爻位。

    示例：
        原卦：bits_list = [1, 0, 1, 0, 1, 0]
        翻转爻位 [0, 2, 4]（全部是阳）：
        新卦应为：[0, 0, 0, 0, 0, 0]
    """
    g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])
    g2 = flip_yao(g, [0, 2, 4])

    assert g2.to_bits_list() == [0, 0, 0, 0, 0, 0]


def test_flip_yao_out_of_range_raises():
    """
    当 positions 中包含越界爻位时，应抛出 ValueError。
    """
    g = GuaCore.from_bits_list([1, 0, 1, 0, 1, 0])  # width=6

    with pytest.raises(ValueError):
        flip_yao(g, [-1])

    with pytest.raises(ValueError):
        flip_yao(g, [6])  # 最大有效索引为 5


def test_flip_yao_usage_scenario():
    """
    模拟一个正常使用场景：

    - 给定一个六爻卦
    - 用户选择某几个爻作为“变爻”
    - 内部仅用 flip_yao 在 bit 层面实现翻转，
      至于如何解释这些变爻，将由后续语义层决定。
    """
    # 原卦：下三阳，上三阴
    g = GuaCore.from_bits_list([1, 1, 1, 0, 0, 0])

    # 用户指定变爻为 [2, 3]（第三爻和第四爻）
    g_changed = flip_yao(g, [2, 3])

    # 手工推导期望结果：
    # 原 bits_list: [1,1,1,0,0,0]
    # 位置 2: 1 -> 0
    # 位置 3: 0 -> 1
    # 结果：       [1,1,0,1,0,0]
    assert g_changed.to_bits_list() == [1, 1, 0, 1, 0, 0]
```

---

## 三、下一步怎么走？

现在你可以：

1. 在当前目录结构下新增：
   - `dao/ops_basic.py`（上面的代码）
   - `tests/test_ops_basic.py`（上面的测试）
2. 在项目根目录运行：

   ```bash
   python -m pytest
   ```

如果所有测试（包括 `test_core` 和 `test_ops_basic`）都通过，那么：

- L1.Core ✅
- L2.a 第一小块（上下卦拆/合 + 基础变爻） ✅

接下来，我们就可以开始讨论 **L1.B “静态语义表”的 schema 设计**：
比如：

- `HexagramMeta` 应该有哪些字段？
- 学派 / 版本 信息怎么表达？
- JSON 文件整体结构怎么组织最稳？

等你确认测试跑完没问题，我们就可以进入 **“静态表 schema 设计”** 这一小块。

-----

> 很好，我们开始下一小块吧

好，那我们进到 **L1.B 静态语义表**，但还是保持“小步走、讲清楚再写代码”的节奏。

这一步我打算只做三件小而清晰的事：

1. 先把“我们到底要存什么 & 存成什么结构”说清楚
2. 给出一个 **Python dataclass 设计**（只定义类型，不急着填满数据）
3. 给一个 **很小的 JSON 示例**，你照着就能建出第一份元数据文件

如果你认同这个 schema，下一小步再写 loader + pytest。

---

## 1. 静态语义表要解决的核心问题

对六爻卦/三爻卦，我们希望：

- 能从 `HexagramId / TrigramId (int)` 找到：
  - 名字（中文、拼音）
  - 上下卦（对六爻卦）
  - 一些大家争议不太大的基本属性（如：主流五行、方位、象征等）
- 这些信息是 **“多数人一致同意但不属于计算本体”** 的东西
- 还要预留空间给：
  - 不同学派/版本：`school`, `version`
  - 未来扩展字段：不要把结构定死到不能长

同时我们已经决定：

- **本体 ID 就是 bits**：
  - TrigramId = 0..7 （width=3 的 bits）
  - HexagramId = 0..63（width=6 的 bits）

---

## 2. 我们先只定义“字段结构”，不填完整内容

我建议先定义 3 类东西：

1. 一份“版本信息”：说明这是哪一派、哪一版
2. 一条“八卦的静态信息”：TrigramMeta
3. 一条“六十四卦的静态信息”：HexagramMeta

### 2.1 版本信息：MetaVersionInfo

这个附在整个文件头上，告诉自己和未来的你：

- 这一份数据是哪个学派整理的
- 什么版本号
- 来源/备注是什么

字段草案：

```python
@dataclass
class MetaVersionInfo:
    school: str        # 学派/体系名，例如 "mainstream", "wenwang", "jingfang"
    version: str       # 如 "1.0.0"
    source: str        # 文本来源，如 "周易", "某某整理版"
    last_updated: str  # "YYYY-MM-DD"
    notes: str | None  # 备注，可选
```

---

### 2.2 八卦静态信息：TrigramMeta

一条三爻卦的信息，我们先只放 **比较稳定、常用** 的字段：

- `id`: TrigramId（0..7）—— bits
- `name_zh`: 中文名（乾、坎、震…）
- `name_pinyin`: 拼音（qian, kan, zhen…）
- `element`: 五行（木火土金水），用字符串表示
- `direction`: 方位（"N", "NE", "E", "S", … 或 "北", "东北"）
- `symbol`: 象征（例如：乾=天，坤=地，震=雷…）
- `family`: 先天八卦中的“家人关系”（父、母、长男等）
- `notes`: 额外注解（可选）

可以长这样：

```python
@dataclass
class TrigramMeta:
    id: int                 # = TrigramId，但存成 int 更通用
    name_zh: str            # 卦名（中文）
    name_pinyin: str        # 卦名（拼音）
    element: str | None     # 五行（主流版本），先允许为空
    direction: str | None   # 方位（简写或中文），先允许为空
    symbol: str | None      # 卦象（天、地、雷、风、水、火、山、泽）
    family: str | None      # 家人（父、母、长男、长女等）
    notes: str | None       # 其他补充
```

**注意：** 很多字段先允许 `None`，这样我们可以逐步补全，不会一开始就逼自己填完所有东西。

---

### 2.3 六十四卦静态信息：HexagramMeta

六爻卦这边，我们先存三个层面的信息：

1. 身份：
   - `id` (= bits)
   - `upper_id` / `lower_id`（上卦/下卦的 TrigramId）
2. 名字与序号：
   - `name_zh`, `name_pinyin`
   - `kingwen_index`：文王卦序（1..64）
   - `binary_index`：按 bits 排序的索引（0..63），可选
3. 一些基本语义标签（以后语义层会用）：
   - `element`: 主流五行（有的按卦定，有的按卦宫等，这里先存“主流版本”）
   - `tags`: 关键词列表（["刚健", "创始", ...] 这类）

草案：

```python
from typing import List

@dataclass
class HexagramMeta:
    id: int                     # = HexagramId，但存成 int
    upper_id: int               # 上卦 TrigramId (0..7)
    lower_id: int               # 下卦 TrigramId (0..7)

    name_zh: str                # 卦名（中文）
    name_pinyin: str            # 卦名（拼音）

    kingwen_index: int | None   # 文王卦序（1..64），可选
    binary_index: int | None    # 按 bits 排序的序号（0..63），可选

    element: str | None         # 主流五行（先统一一个版本，不纠结细分）
    tags: List[str]             # 简短关键词列表
    notes: str | None           # 其他补充
```

这已经够我们先做一套 L1.B 的基础语义了。

---

## 3. 整体文件结构：一个 JSON 里放 meta + trigrams + hexagrams

我建议一个 JSON 文件的结构是：

```jsonc
{
  "_meta": {
    "school": "main",
    "version": "1.0.0",
    "source": "周易 + 主流整理",
    "last_updated": "2025-11-28",
    "notes": "仅示例，未完整收录。"
  },
  "trigrams": {
    "0": {
      "id": 0,
      "name_zh": "坤",
      "name_pinyin": "kun",
      "element": "土",
      "direction": "SW",
      "symbol": "地",
      "family": "母",
      "notes": null
    },
    "1": {
      "id": 1,
      "name_zh": "震",
      "name_pinyin": "zhen",
      "element": "木",
      "direction": "E",
      "symbol": "雷",
      "family": "长男",
      "notes": null
    }
    // ... 其他 trigram 可以以后再填
  },
  "hexagrams": {
    "0": {
      "id": 0,
      "upper_id": 0,
      "lower_id": 0,
      "name_zh": "坤",
      "name_pinyin": "kun",
      "kingwen_index": 2,
      "binary_index": 0,
      "element": "土",
      "tags": ["顺", "承载"],
      "notes": "示例数据，未必为最终定稿。"
    },
    "1": {
      "id": 1,
      "upper_id": 0,
      "lower_id": 1,
      "name_zh": "复",
      "name_pinyin": "fu",
      "kingwen_index": 24,
      "binary_index": 1,
      "element": "土木",
      "tags": ["归来", "循环"],
      "notes": null
    }
    // ... 其他 hexagram 以后再补
  }
}
```

要点：

- `trigrams` / `hexagrams` 都用 **字符串 key**（"0", "1", ...），方便 JSON；
  读出来后我们再转成 `int`。
- 每条记录内部也带 `id` 字段（冗余但好用）——有利于调试和检查。
- `_meta` 区块放版本/学派信息。

你可以把这类文件放在，比如：

```text
dao/
  data/
    metadata.main.v1.json
```

---

## 4. 把这些结构变成一个 Python 模块：`dao/metadata_types.py`

这一小步我们先 **只写类型和文档，不写 loader**，保持“粒度小”。

### `dao/metadata_types.py` 草案

```python
"""
metadata_types.py

L1.B：静态语义表（类型定义）

设计目标
--------
1. 定义「三爻卦 / 六爻卦静态信息」的数据结构（Python dataclass）。
2. 定义元数据版本信息（学派、版本号、来源等）。
3. 不负责文件 IO，只负责结构定义。
   具体的加载逻辑会在后续的 loader 模块中实现。

注意：
- 这里仍然不做任何运算，仅用于承载「多数人一致认同」的静态信息。
- 所有字段尽量使用 Optional（| None），以便逐步补全数据。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional


@dataclass
class MetaVersionInfo:
    """
    元数据版本信息（针对一整个 metadata 文件）。

    示例用途：
    - 标记此文件属于哪个学派/体系（school）
    - 使用哪个版本（version），便于迭代与兼容处理
    - 记录数据整理来源（source）
    - 记录更新日期与备注（last_updated / notes）
    """

    school: str           # 学派/体系名，例如 "main", "wenwang", "jingfang"
    version: str          # 版本号，例如 "1.0.0"
    source: str           # 数据来源说明，例如 "周易 + 主流整理"
    last_updated: str     # "YYYY-MM-DD" 格式的日期字符串
    notes: Optional[str]  # 备注，可空


@dataclass
class TrigramMeta:
    """
    三爻卦（八卦）的静态语义信息。

    说明：
    - id 对应 TrigramId（0..7），等于三爻卦的 bits 值。
    - 这些字段是不涉及「具体占断规则」的基础属性。
    """

    id: int                      # 0..7，对应 width=3 的 bits 值
    name_zh: str                 # 卦名（中文），例如 "乾"
    name_pinyin: str             # 卦名（拼音），例如 "qian"

    element: Optional[str]       # 五行，如 "金"、"木"；允许为空
    direction: Optional[str]     # 方位，如 "N"、"NE" 或 "北"；允许为空
    symbol: Optional[str]        # 卦象，如 "天"、"地"、"雷"；允许为空
    family: Optional[str]        # 家人，如 "父"、"母"、"长男"、"长女"；允许为空

    notes: Optional[str]         # 其他补充说明


@dataclass
class HexagramMeta:
    """
    六爻卦（六十四卦）的静态语义信息。

    说明：
    - id 对应 HexagramId（0..63），等于六爻卦的 bits 值。
    - upper_id / lower_id 为上卦/下卦的 TrigramId（0..7）。
    - 不在此处存储「卦辞原文」等长文本，避免掺入太多解释性内容。
      这些可以在更高一层的语义/文献模块中处理。
    """

    id: int                      # 0..63，对应 width=6 的 bits 值

    upper_id: int                # 上卦 TrigramId (0..7)
    lower_id: int                # 下卦 TrigramId (0..7)

    name_zh: str                 # 卦名（中文），例如 "坤"
    name_pinyin: str             # 卦名（拼音），例如 "kun"

    kingwen_index: Optional[int] # 文王卦序（1..64），允许为空
    binary_index: Optional[int]  # 按 bits 排序的序号（0..63），允许为空

    element: Optional[str]       # 主流五行归属，例如 "土"、"金水"；允许为空
    tags: List[str]              # 简短关键词列表，例如 ["顺", "承载"]

    notes: Optional[str]         # 其他补充说明


@dataclass
class MetadataBundle:
    """
    一整个 metadata 文件在内存中的承载结构。

    对应 JSON 结构大致为：
    {
      "_meta": { ... MetaVersionInfo ... },
      "trigrams": { "0": { ... TrigramMeta ... }, ... },
      "hexagrams": { "0": { ... HexagramMeta ... }, ... }
    }

    我们在 loader 中会把 JSON 中的 "0"/"1" 等字符串 key
    转换为 int，再组装成以下结构：
      - trigrams: dict[int, TrigramMeta]
      - hexagrams: dict[int, HexagramMeta]
    """

    meta: MetaVersionInfo
    trigrams: dict[int, TrigramMeta]
    hexagrams: dict[int, HexagramMeta]
```

这一小块做完，我们就有了：

- 清晰的静态语义数据结构
- 明确的文件结构对应（JSON ↔ dataclasses）
- 没有任何 IO/实现细节，便于讨论和调整

---

## 5. 下一小步建议

如果你对上面的 schema 没有异议，我们可以这样推进：

1. 你在本地创建 `dao/metadata_types.py`，拷进上面的代码。
2. （可选）新建一个 `dao/data/metadata.main.v1.json`，按我们给的 JSON 样例只填极少内容。
3. 下一步我们就写一个非常小的 loader 模块 `dao/metadata_loader.py`：
   - 提供函数：`load_metadata(path: str) -> MetadataBundle`
   - 再配一个 `tests/test_metadata_loader.py`，用小样例文件做 round-trip 测试

等 `loader + 测试` 通过，我们就真正完成了 L1.B 的“**数据形式 + 加载**”，
之后就可以开始 L1.C（关系图 schema）了。

你可以先看看这个 schema 有没有你觉得“不顺手或容易后悔”的地方，我们再微调；
如果你觉得可以，我们就按这个设计写 loader。

-----

> 对这个方案，我有一些想法。
> 一、文件中的内容太杂了，既不是全部的关联内容，又不是最基本的内容。我的想法是只放卦本身的信息，其他方向、五行、人际关系等等，都是各流派发展而赋予的意义，比如先天八卦的理论，各方向对应某一卦，这样我们后续加入先天八卦的理论时，就建一个先天八卦的文件，其中把方向与卦联系起来。这些内容，每填加一类，建立一个新的文件，比如family.json，这是把父母子女与卦象联系起来，那在这里面去建立这种联系。
> 这个思路，有点像插件化思路，也与你建立core时的思路类似，基础文件只建立最基本的内容，衍生开的无数应用，在建立其应用本身的数据处与基础数据产生关联。
> 这样，添加、删除、修改都更为容易。你的看法呢？
> 二、在程序中的metadata_types中，如果事先定义字段，则要每建立一个数据文件（如五行、方位、干支等）都在其中填加对应字段，且与数据文件中的重复。如果日后有修改，又忘了同步修改，很容易出错。
> 有没有可能，除了基础文件中的数据（如卦名等），其他字段名只在数据文件中指定，程序读取时，从数据文件中读取，并不预先设定。以避免我上面提到的问题。
> 你觉得这样可行吗？
> 我们先讨论一下这两个问题，你看看是否还有其他问题我们需要讨论，讨论好了我们再具体实现

这两个想法我非常赞同，而且和我们之前“core 要极简、其他都外挂”的思路是完全一致的 👍
我把你的想法稍微“工程化”一下，然后顺便补充几个需要提前想清楚的小点。

---

## 一、关于（1）：只在基础文件放“卦本身”，其他全部插件化

你现在的思路可以概括成一句话：

> **L1.B 只管“卦是谁”，不管“卦被怎么解释”；所有解释都单独建文件，以插件形式挂上来。**

这和我们做 Core 时的原则是一脉相承的，非常合理。

### 1.1 我们可以把 L1.B 再拆成两级

- **L1.B1：Core Metadata（卦的“身份证”）**
  - 内容只包括：
    - `id`（bits，对应 hexagram/trigram）
    - `name_zh`（卦名）
    - 也许可以加个 `name_pinyin`（方便英文环境用）
  - 不放：五行、方位、家人、卦序、卦辞、象义……

- **L1.B2：插件式语义文件（“表层解释”）**
  - 每类“解释体系”一个文件：
    - `direction.xiantian.json`：先天八卦 → 方位
    - `direction.houtian.json`：后天八卦 → 方位
    - `element.wuxing.main.json`：卦/爻 → 五行
    - `family.trigram.json`：八卦 ↔ 父母子女家人
    - `kingwen_order.json`：卦 ↔ 文王卦序
    - ……以及后续任何想加的东西
  - 每个文件只负责一类关系：“A 和 B 之间存在某种映射或标签”。

这样有几个直接好处：

1. **精神上非常“插件化”**：加一个新理论=加一个新 JSON，不动老文件。
2. **删除/替换很安全**：不想用某个流派=别加载那份文件即可。
3. **避免语义污染**：核心文件永远只管“卦长什么样、怎么叫”，不被任何学派“锁死”。

这一点我是完全支持的，而且还比我之前给的“把 element/direction 放进 HexagramMeta 里”的方案更干净。

---

## 二、关于（2）：metadata_types 要不要预先定义所有字段？

你提的问题非常关键：

> 如果 metadata_types 里事先定义了很多字段，那每新增一个数据文件（五行、方位、干支……）就要在那里增加对应字段，还会和 JSON 里重复，一旦不同步就埋雷。

这个担心是对的，而且在长期维护里几乎可以说是**必然会出问题**。

我建议做一个折中：

### 2.1 只对“核心不变字段”做强类型，其余都走“动态结构”

也就是：

1. **对“卦身份证”的那部分（L1.B1）用 dataclass 强类型**
   比如：

   ```python
   @dataclass
   class HexagramCoreInfo:
       id: int          # bits
       name_zh: str
       name_pinyin: str | None
   ```

   同样还有 `TrigramCoreInfo`。
   这几个字段：
   - 永远不会因为某个学派不同而改变含义
   - 改动概率非常低（名字换掉都算大地震了）

2. **对“插件式语义文件”（L1.B2）不要预定义字段，只定义一个通用容器结构**

   可以类似这样：

   ```python
   @dataclass
   class MetaVersionInfo:
       school: str
       version: str
       source: str
       last_updated: str
       notes: str | None

   @dataclass
   class GenericMappingFile:
       meta: MetaVersionInfo
       items: list[dict]
   ```

   或稍微严格一点：

   ```python
   @dataclass
   class MappingItem:
       target: dict  # { "kind": "hexagram", "id": 0 } 等
       data: dict    # 任意字段，比如 { "element": "土", "direction": "SW" }

   @dataclass
   class GenericMappingFile:
       meta: MetaVersionInfo
       items: list[MappingItem]
   ```

   也就是说：
   - 文件的“外壳结构”是固定的（`_meta` + `items`）
   - 每条 item 的内部字段完全由数据文件自己定义，不在代码里写死

   这样你新建一个 `family.trigram.json` 或 `wuxing.hexagram.json`：
   - **不需要改任何 Python 类型定义**
   - loader 只负责把 JSON 读成 `GenericMappingFile` + 一堆 dict，
     后续你要怎么解释这些字段（比如 `direction`、`element`）由更上层的逻辑决定

### 2.2 这样做的取舍

- ✅ 优点：
  - 不会出现“JSON 改了、dataclass 忘改”的双写问题
  - 插件文件可以随便增删字段，代码层只要按约好的外壳规范走
  - 非常灵活，和你说的“插件化思路”高度一致

- ⚠️ 缺点：
  - 类型系统帮不了太多忙（因为字段是动态 dict），
  - 但这个可以在“常用插件”上再加一层薄薄的封装（比如只对五行/方位写一点专门的 helper），不必所有文件都强类型。

我觉得对于你这么一个理论体系极其多样、未来会不断加新文件的项目，这种“**核心强类型 + 插件动态结构**”是比较健康的平衡点。

---

## 三、结合你的两个想法，我建议的整体设计调整

### 3.1 L1.B 的重新规划

我们稍微重构下原来的设计：

#### L1.B1：卦的“身份证”文件

- 例如：`core_trigrams.v1.json`, `core_hexagrams.v1.json`
- 内容极简：
  - `id`（bits）
  - `name_zh`
  - `name_pinyin`（可选）

示例（`core_hexagrams.v1.json`）：

```json
{
  "_meta": {
    "school": "core",
    "version": "1.0.0",
    "source": "周易 64 卦名",
    "last_updated": "2025-11-28",
    "notes": "仅包含卦名与 ID，不含任何解释性数据。"
  },
  "hexagrams": {
    "0": { "id": 0, "name_zh": "坤", "name_pinyin": "kun" },
    "1": { "id": 1, "name_zh": "复", "name_pinyin": "fu" }
  }
}
```

对应 Python 里只需要：

```python
@dataclass
class HexagramCoreInfo:
    id: int
    name_zh: str
    name_pinyin: str | None

@dataclass
class TrigramCoreInfo:
    id: int
    name_zh: str
    name_pinyin: str | None
```

再加一个：

```python
@dataclass
class CoreNamesBundle:
    meta: MetaVersionInfo
    trigrams: dict[int, TrigramCoreInfo]
    hexagrams: dict[int, HexagramCoreInfo]
```

这部分字段简单、稳定，不太会变化。

---

#### L1.B2：插件式语义文件（一个理论/映射一份）

文件组织大概像：

```text
dao/
  data/
    core/
      core_trigrams.v1.json
      core_hexagrams.v1.json
    mappings/
      direction.xiantian.v1.json
      direction.houtian.v1.json
      wuxing.trigram.main.v1.json
      wuxing.hexagram.main.v1.json
      family.trigram.v1.json
      kingwen_order.v1.json
```

每个 mapping 文件可以统一用一个简单 schema，比如：

```json
{
  "_meta": {
    "school": "xiantian",
    "version": "1.0.0",
    "source": "先天八卦说",
    "last_updated": "2025-11-28",
    "notes": "示例：方向与八卦对应关系"
  },
  "items": [
    {
      "target": { "kind": "trigram", "id": 0 },
      "data": {
        "direction": "N"
      }
    },
    {
      "target": { "kind": "trigram", "id": 1 },
      "data": {
        "direction": "SW"
      }
    }
  ]
}
```

或者更简单点（你可能会更喜欢）：

```json
{
  "_meta": { ... },
  "mapping": {
    "trigram:0": { "direction": "N" },
    "trigram:1": { "direction": "SW" }
  }
}
```

Python 里我们只定义“外壳”的结构，不定义 `data` 的字段：

```python
@dataclass
class MappingFile:
    meta: MetaVersionInfo
    mapping: dict[str, dict]  # key 比如 "trigram:0"，value 任意键值
```

至于 `direction`、`element`、`family`，全部写在 JSON 里，不进 Python 类型定义。

---

## 四、还有没有其他需要提前讨论的点？

我觉得还有两个小问题值得现在就说一下，避免后面踩坑：

### 4.1 ID 命名空间的问题

以后你的图里会有很多种“东西”：

- trigram（八卦）
- hexagram（六十四卦）
- 五行（木火土金水）
- 方位（N/E/S/W...）
- family（父/母/长男...）
- 节气、天干、地支……

为了避免不同种类的 ID 混在一起，我们最好 **统一规定一个“全局 ID/引用格式”**，比如：

- `"trigram:0"`：三爻卦 bits=0
- `"hexagram:7"`：六爻卦 bits=7
- `"element:wood"`
- `"direction:N"`
- `"family:father"`

这样无论是在 mapping 文件还是以后图结构里，只要出现 `"trigram:0"`，我们就知道它是谁，而不用再额外传个 `"kind": "trigram"`。

这个设计会直接影响 mapping JSON 的 key / 结构，我会建议现在就统一。

---

### 4.2 名字（`name_zh`）要不要也插件化？

我认为：

- **卦名（乾坤屯蒙……）可以视为 Core 的一部分**
  因为它几乎不存在“学派差异”，属于“最基础的约定”。
- 如果未来你需要多语言（比如英文翻译、日文名），那可以用 **插件文件** 方式单独加，比如 `names.en.v1.json`，里面把 `"hexagram:0" -> "The Receptive"` 之类。

所以我会建议：

- `HexagramCoreInfo` 中保留 `name_zh`，`name_pinyin`（可选）
- 其他语言名用插件文件挂上去

---

## 五、下一小步的建议

如果你觉得上面的调整方向 OK，我建议下一小步我们这样做：

1. **先定 L1.B1：卦“身份证”的 schema 和文件样例**
   - 写一个小的 `dao/metadata_core_types.py`，只定义：
     - `MetaVersionInfo`
     - `TrigramCoreInfo`
     - `HexagramCoreInfo`
     - `CoreNamesBundle`
   - 在 `dao/data/core/core_hexagrams.v1.json` 里只填 **2~3 个卦** 的示例（不用一口气填完）

2. 再下一步我们再设计 L1.B2 的“通用 mapping 文件 schema”（就是上面那种 `mapping` 或 `items` 形式），然后写 loader + 测试。

---

如果你同意这个 “**Core 卦名强类型 + 其他全部插件化、动态字段**” 的方向，我可以先给出：

- `metadata_core_types.py` 的定稿代码
- 一个极小的 `core_hexagrams.v1.json` 示例（只包含 2–3 个卦）

我们就继续用“**只动一小块、配测试**”的节奏往前推进。

-----

> 非常好，你提到的问题，4.1我完全同意你的提议，4.2也同意你的提议，名字不必插件化。
> 就按照你的方案，请继续吧

太好了，那我们就把这块“卦的身份证 + 插件式语义”的骨架落地。

这一步只做两件事：

1. 写一个 **`metadata_core_types.py`**：只定义“卦身份证”的 dataclass，不碰五行/方位等。
2. 给出 **极小的 JSON 示例文件** 结构，你可以照着建在 `dao/data/core/` 里（内容先当示例，不急着定最终映射）。

---

## 一、`dao/metadata_core_types.py`：只管“卦是谁”

放在：

```text
dao/
  core.py
  ops_basic.py
  metadata_core_types.py   ← 新文件
```

代码示例（已经加了详细注释，重点解释设计目标和用途）：

```python
"""
metadata_core_types.py

L1.B1：卦的“身份证”类型定义（Core Metadata）

设计目标
--------
1. 只描述「卦本身最基础、最稳定」的信息：
   - 哪个 bits 对应哪一卦（id）
   - 卦的中文名 / 拼音名
2. 不包含任何派生语义：
   - 不写：五行、方位、家人、卦辞、象义……
   - 不写：卦序关系（文王序等）
3. 为后续「插件式语义文件」提供挂载基础：
   - 其他文件只需要用统一 ID（例如 "hexagram:0"）就能对接到这里。

说明
----
- 本模块只定义数据结构，不做文件 IO。
- JSON 的存储形式会在 data/core/*.json 中体现，
  Loader 会在单独的模块中实现（例如 metadata_core_loader.py）。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Dict


# ----------------------------------------------------------------------
# 通用元信息：MetaVersionInfo
# ----------------------------------------------------------------------


@dataclass
class MetaVersionInfo:
    """
    元数据版本信息（针对一整个 metadata 文件）。

    示例用途：
    - 标记此文件属于哪个学派/用途（school）
    - 使用哪个版本（version），便于迭代与兼容处理
    - 记录数据整理来源（source）
    - 记录最后更新日期与备注（last_updated / notes）
    """

    school: str           # 学派/体系/用途名，例如 "core", "main", "wenwang"
    version: str          # 版本号，例如 "1.0.0"
    source: str           # 数据来源说明，例如 "周易 64 卦名"
    last_updated: str     # "YYYY-MM-DD" 格式的日期字符串
    notes: Optional[str]  # 备注，可空


# ----------------------------------------------------------------------
# 八卦 / 六十四卦的核心信息（只管“叫什么”）
# ----------------------------------------------------------------------


@dataclass
class TrigramCoreInfo:
    """
    三爻卦（八卦）的核心信息：只包含最基础的“身份”字段。

    字段说明
    --------
    id : int
        TrigramId，对应 width=3 的 bits（0..7）。
        注意：具体 "0..7 映射到哪一卦" 的方案需要由你在数据文件中明确。
              这里仅假设 id 是一个稳定、一致的标识。

    name_zh : str
        卦名（中文），例如 "乾"、"坎"、"震" 等。

    name_pinyin : Optional[str]
        卦名的拼音，例如 "qian"、"kan"、"zhen"。
        可选字段，方便在英文环境中展示。
    """

    id: int
    name_zh: str
    name_pinyin: Optional[str]


@dataclass
class HexagramCoreInfo:
    """
    六爻卦（六十四卦）的核心信息：只包含“ID + 名字”。

    字段说明
    --------
    id : int
        HexagramId，对应 width=6 的 bits（0..63）。
        同样，具体 bits 与传统卦序/卦名之间的对应关系，
        需要在数据整理阶段谨慎设计，本结构只负责承载。

    name_zh : str
        卦名（中文），例如 "坤"、"复" 等。

    name_pinyin : Optional[str]
        卦名的拼音，例如 "kun"、"fu"。
    """

    id: int
    name_zh: str
    name_pinyin: Optional[str]


# ----------------------------------------------------------------------
# 整体打包结构：一份“核心卦名”文件在内存中的样子
# ----------------------------------------------------------------------


@dataclass
class CoreNamesBundle:
    """
    一整套「卦的核心名字信息」在内存中的承载结构。

    典型 JSON 结构（示意）
    ---------------------
    {
      "_meta": { ... MetaVersionInfo 对应字段 ... },
      "trigrams": {
        "0": { "id": 0, "name_zh": "坤", "name_pinyin": "kun" },
        "1": { "id": 1, "name_zh": "震", "name_pinyin": "zhen" }
        ...
      },
      "hexagrams": {
        "0": { "id": 0, "name_zh": "坤", "name_pinyin": "kun" },
        "1": { "id": 1, "name_zh": "复", "name_pinyin": "fu" }
        ...
      }
    }

    读取策略
    --------
    - JSON 中使用字符串 key（"0", "1", ...），Loader 会将其转换为 int。
    - trigrams / hexagrams 在内存中用 dict[int, TrigramCoreInfo/HexagramCoreInfo] 表示。
    """

    meta: MetaVersionInfo
    trigrams: Dict[int, TrigramCoreInfo]
    hexagrams: Dict[int, HexagramCoreInfo]
```

> 这一步我们先不写 loader，只把“结构”定下来。
> 具体的 `load_core_names(path: str) -> CoreNamesBundle` 留到下一小步实现。

---

## 二、数据文件结构：`data/core/*.json` 示例

建议在项目根目录下新建一个 `data/core/` 目录：

```text
dao/
├─ dao/
│  ├─ core.py
│  ├─ ops_basic.py
│  ├─ metadata_core_types.py
│  └─ ...
└─ data/
   └─ core/
      ├─ core_trigrams.v1.json
      └─ core_hexagrams.v1.json
```

### 1. `data/core/core_trigrams.v1.json` 示例

这里只示意 2 个 trigram，**内容可以暂时视为占位/示例**，以后你可以再仔细决定 bits→卦名的最终映射。

```json
{
  "_meta": {
    "school": "core",
    "version": "1.0.0",
    "source": "示例八卦名称，仅作结构演示",
    "last_updated": "2025-11-28",
    "notes": "注意：此文件中的 id→卦名 映射暂为示例，不代表最终定稿。"
  },
  "trigrams": {
    "0": {
      "id": 0,
      "name_zh": "坤",
      "name_pinyin": "kun"
    },
    "1": {
      "id": 1,
      "name_zh": "震",
      "name_pinyin": "zhen"
    }
    /*
    之后可以继续补：
    "2": {...}, "3": {...}, ..., "7": {...}
    */
  },
  "hexagrams": {}
}
```

> 这里 `hexagrams` 先留空也没问题，或者你愿意也可以直接放到 `core_hexagrams.v1.json` 里。

### 2. `data/core/core_hexagrams.v1.json` 示例

同样只放 2 个卦作为演示（id 0 和 1；语义上你后面可以重新审定）：

```json
{
  "_meta": {
    "school": "core",
    "version": "1.0.0",
    "source": "示例六十四卦名称，仅作结构演示",
    "last_updated": "2025-11-28",
    "notes": "注意：此文件中的 id→卦名 映射暂为示例，不代表最终定稿。"
  },
  "trigrams": {},
  "hexagrams": {
    "0": {
      "id": 0,
      "name_zh": "坤",
      "name_pinyin": "kun"
    },
    "1": {
      "id": 1,
      "name_zh": "复",
      "name_pinyin": "fu"
    }
    /*
    之后可以继续补：
    "2": {...}, ..., "63": {...}
    */
  }
}
```

你完全可以选择：

- **一个文件放 trigram + hexagram（像上面那样都有字段）**，或
- **拆成两个文件**：一个专管 trigram，一个专管 hexagram

从类型上看，`CoreNamesBundle` 已经能承接“同时有两者”的情况；
如果你习惯 trigram / hexagram 各一文件，我们之后在 loader 里也可以支持合并。

---

## 三、下一步的小计划（提前说一声）

等你把这个文件和 JSON 放好之后，我们下一小步可以做：

1. 写一个简单的 loader：`dao/metadata_core_loader.py`
   - 比如提供函数：`load_core_names(path: str) -> CoreNamesBundle`
   - 做字符串 key → int 的转换
   - 做基本校验（id 一致、重复 id 等）

2. 写一个小测试：`tests/test_metadata_core_loader.py`
   - 用你刚刚这些示例 JSON 做 round-trip：
     - 读进来 → 得到 `CoreNamesBundle`
     - 检查 meta、trigrams、hexagrams 的内容正确

到这里，L1.B1“卦身份证 + 核心名字”就完整闭环了，
后面我们再来设计插件式 mapping 文件（L1.B2）和图结构（L1.C）。

---

你先看看这个 `metadata_core_types.py` 和 JSON 结构是不是完全符合你“核心简单 + 插件化扩展”的直觉；
如果 OK，我们下一步就写 loader + 测试，把这一小块也“锁死”下来。

-----

> 非常好，符合我的需求，对于trigram, hexagram，我倾向于分成两个文件。
> 好了，请按你的方案，继续下一个步骤

太好了，那我们把这一步 “**核心卦名的 loader + 测试**” 做完，让 L1.B1 真正可用起来。

你已经决定：

- trigram / hexagram 分成两个文件
- 但文件结构一致（都有 `_meta` / `trigrams` / `hexagrams`），只是某一边可以为空

我们就按这个来做一个通用的 `load_core_names(path)`，
**一个文件可以只装 trigram 或只装 hexagram，另一半就是空 dict。**

---

## 一、`dao/metadata_core_loader.py` —— 读取核心卦名 JSON 的 loader

放在：

```text
dao/
  dao/
    core.py
    ops_basic.py
    metadata_core_types.py
    metadata_core_loader.py   ← 新文件
  data/
    core/
      core_trigrams.v1.json
      core_hexagrams.v1.json
  tests/
    ...
```

代码：

```python
"""
metadata_core_loader.py

L1.B1：卦的“身份证”加载器（Core Metadata Loader）

职责
----
- 从 JSON 文件中加载核心卦名信息：
  - MetaVersionInfo
  - TrigramCoreInfo / HexagramCoreInfo 字典
- 不做任何派生语义处理（五行、方位等），只关心：
  - id 是否合理
  - JSON 结构是否符合预期

使用方式
--------
- 一个文件可以只包含 trigrams 或 hexagrams：
    data/core/core_trigrams.v1.json      # 只填 trigrams
    data/core/core_hexagrams.v1.json     # 只填 hexagrams

- 调用方式：
    from dao.metadata_core_loader import load_core_names

    bundle = load_core_names("data/core/core_trigrams.v1.json")
    # bundle.trigrams 有内容，bundle.hexagrams 可能为空 dict
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict

from .metadata_core_types import (
    MetaVersionInfo,
    TrigramCoreInfo,
    HexagramCoreInfo,
    CoreNamesBundle,
)


def _load_json(path: Path) -> Dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"Metadata file not found: {path}")

    text = path.read_text(encoding="utf-8")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse JSON from {path}: {e}") from e

    if not isinstance(data, dict):
        raise ValueError(f"Top-level JSON must be an object in {path}")
    return data


def _parse_meta(meta_dict: Dict[str, Any]) -> MetaVersionInfo:
    """
    从 JSON 的 `_meta` 字段解析 MetaVersionInfo。

    要求字段：
    - school, version, source, last_updated
    - notes 可选
    """
    try:
        school = meta_dict["school"]
        version = meta_dict["version"]
        source = meta_dict["source"]
        last_updated = meta_dict["last_updated"]
        notes = meta_dict.get("notes")
    except KeyError as e:
        raise ValueError(f"Missing required meta field: {e!r}") from e

    return MetaVersionInfo(
        school=school,
        version=version,
        source=source,
        last_updated=last_updated,
        notes=notes,
    )


def _parse_trigrams(trigrams_dict: Dict[str, Any]) -> Dict[int, TrigramCoreInfo]:
    """
    解析 JSON 中的 `trigrams` 字典：

    JSON 结构示例：
    "trigrams": {
      "0": { "id": 0, "name_zh": "坤", "name_pinyin": "kun" },
      "1": { "id": 1, "name_zh": "震", "name_pinyin": "zhen" }
    }

    转换为：
    dict[int, TrigramCoreInfo]
    """
    result: Dict[int, TrigramCoreInfo] = {}

    for key_str, payload in trigrams_dict.items():
        if not isinstance(payload, dict):
            raise ValueError(f"trigrams[{key_str!r}] must be an object")

        try:
            # key 本身应该是一个 int 字符串，例如 "0"
            key_id = int(key_str)
        except ValueError as e:
            raise ValueError(f"trigrams key must be an int string, got {key_str!r}") from e

        # payload 中的 id 字段如果存在，应与 key_id 一致
        payload_id = payload.get("id", key_id)
        if payload_id != key_id:
            raise ValueError(
                f"trigrams[{key_str!r}].id={payload_id} "
                f"does not match key {key_id}"
            )

        name_zh = payload.get("name_zh")
        if not isinstance(name_zh, str):
            raise ValueError(f"trigrams[{key_str!r}].name_zh must be a string")

        name_pinyin = payload.get("name_pinyin")
        if name_pinyin is not None and not isinstance(name_pinyin, str):
            raise ValueError(
                f"trigrams[{key_str!r}].name_pinyin must be a string or null"
            )

        result[key_id] = TrigramCoreInfo(
            id=key_id,
            name_zh=name_zh,
            name_pinyin=name_pinyin,
        )

    return result


def _parse_hexagrams(hexagrams_dict: Dict[str, Any]) -> Dict[int, HexagramCoreInfo]:
    """
    解析 JSON 中的 `hexagrams` 字典：

    JSON 结构示例：
    "hexagrams": {
      "0": { "id": 0, "name_zh": "坤", "name_pinyin": "kun" },
      "1": { "id": 1, "name_zh": "复", "name_pinyin": "fu" }
    }

    转换为：
    dict[int, HexagramCoreInfo]
    """
    result: Dict[int, HexagramCoreInfo] = {}

    for key_str, payload in hexagrams_dict.items():
        if not isinstance(payload, dict):
            raise ValueError(f"hexagrams[{key_str!r}] must be an object")

        try:
            key_id = int(key_str)
        except ValueError as e:
            raise ValueError(f"hexagrams key must be an int string, got {key_str!r}") from e

        payload_id = payload.get("id", key_id)
        if payload_id != key_id:
            raise ValueError(
                f"hexagrams[{key_str!r}].id={payload_id} "
                f"does not match key {key_id}"
            )

        name_zh = payload.get("name_zh")
        if not isinstance(name_zh, str):
            raise ValueError(f"hexagrams[{key_str!r}].name_zh must be a string")

        name_pinyin = payload.get("name_pinyin")
        if name_pinyin is not None and not isinstance(name_pinyin, str):
            raise ValueError(
                f"hexagrams[{key_str!r}].name_pinyin must be a string or null"
            )

        result[key_id] = HexagramCoreInfo(
            id=key_id,
            name_zh=name_zh,
            name_pinyin=name_pinyin,
        )

    return result


def load_core_names(path: str | Path) -> CoreNamesBundle:
    """
    从给定 JSON 文件加载核心卦名信息。

    参数
    ----
    path : str | Path
        JSON 文件路径，可以是相对或绝对路径。

    返回
    ----
    CoreNamesBundle
        - meta: 文件元信息
        - trigrams: dict[int, TrigramCoreInfo]
        - hexagrams: dict[int, HexagramCoreInfo]

    用法示例
    --------
    >>> from dao.metadata_core_loader import load_core_names
    >>> bundle = load_core_names("data/core/core_trigrams.v1.json")
    >>> bundle.meta.school
    'core'
    >>> bundle.trigrams[0].name_zh
    '坤'
    """
    p = Path(path)
    data = _load_json(p)

    # 解析 _meta
    meta_dict = data.get("_meta")
    if not isinstance(meta_dict, dict):
        raise ValueError(f"Metadata file {p} must contain a '_meta' object")
    meta = _parse_meta(meta_dict)

    # 解析 trigrams / hexagrams，可为空
    trigrams_raw = data.get("trigrams", {})
    hexagrams_raw = data.get("hexagrams", {})

    if not isinstance(trigrams_raw, dict):
        raise ValueError(f"'trigrams' must be an object in {p}")
    if not isinstance(hexagrams_raw, dict):
        raise ValueError(f"'hexagrams' must be an object in {p}")

    trigrams = _parse_trigrams(trigrams_raw)
    hexagrams = _parse_hexagrams(hexagrams_raw)

    return CoreNamesBundle(
        meta=meta,
        trigrams=trigrams,
        hexagrams=hexagrams,
    )
```

> 设计上，它不关心是“只 trigram”还是“只 hexagram”，
> 只要某一块为空 dict 就行。这样你分成两个文件也没问题。

---

## 二、测试：`tests/test_metadata_core_loader.py`

这里我假设你的目录结构是这样的（根目录是 `dao/` 仓库）：

```text
dao/
├─ dao/
│  ├─ core.py
│  ├─ ops_basic.py
│  ├─ metadata_core_types.py
│  └─ metadata_core_loader.py
├─ data/
│  └─ core/
│     ├─ core_trigrams.v1.json
│     └─ core_hexagrams.v1.json
└─ tests/
   ├─ test_core.py
   ├─ test_ops_basic.py
   └─ test_metadata_core_loader.py   ← 新文件
```

测试代码示例：

```python
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
```

> 这里用 `tmp_path` 做了一个“坏数据”测试，验证 loader 会在 id 和 key 不一致时抛错。

---

## 三、你现在可以做的具体步骤

1. 在 `dao/` 包里新建 `metadata_core_loader.py`，拷入上面的代码。
2. 确保你的目录里有：

   ```text
   data/core/core_trigrams.v1.json
   data/core/core_hexagrams.v1.json
   ```

   结构类似我们之前示例的那样（至少有一个 id=0 的记录）。

3. 在 `tests/` 下新建 `test_metadata_core_loader.py`，拷入上面的测试。
4. 在项目根目录运行：

   ```bash
   python -m pytest
   ```

如果 `test_core.py`、`test_ops_basic.py`、`test_metadata_core_loader.py` 都通过，那：

- L1.Core ✅
- L2.a 基础运算 ✅
- L1.B1 核心卦名 + loader ✅

接下来我们就可以讨论 **插件式 mapping 文件（L1.B2）和/或语义图（L1.C）** 的 schema 怎么设计了——这一步会真正开始把“五行/方位/家人”等“意义”以插件方式挂上来。

-----

> 测试报错，请帮着排错，顺便把两个数据文件的内容补全吧
> cwd: /home/xashes/projects/dao/
> cmd: pytest --color=no
>
> ============================== test session starts ==============================
> platform linux -- Python 3.11.7, pytest-8.4.2, pluggy-1.5.0
> rootdir: /home/xashes/projects/dao
> plugins: anyio-4.8.0
> collected 27 items
>
> tests/test_core.py .............                                          [ 48%]
> tests/test_metadata_core_loader.py FF.                                    [ 59%]
> tests/test_ops_basic.py ...........                                       [100%]
>
> =================================== FAILURES ====================================
> _________________________ test_load_core_trigrams_file __________________________
>
> path = PosixPath('/home/xashes/projects/dao/data/core/core_trigrams.v1.json')
>
>     def _load_json(path: Path) -> Dict[str, Any]:
>         if not path.is_file():
>             raise FileNotFoundError(f"Metadata file not found: {path}")
>
>         text = path.read_text(encoding="utf-8")
>         try:
> >           data = json.loads(text)
>                    ^^^^^^^^^^^^^^^^
>
> dao/metadata_core_loader.py:48:
> _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
> ../../anaconda3/lib/python3.11/json/__init__.py:346: in loads
>     return _default_decoder.decode(s)
>            ^^^^^^^^^^^^^^^^^^^^^^^^^^
> ../../anaconda3/lib/python3.11/json/decoder.py:337: in decode
>     obj, end = self.raw_decode(s, idx=_w(s, 0).end())
>                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
> _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
>
> self = <json.decoder.JSONDecoder object at 0x7fbd5aa73550>
> s = '{\n    "_meta": {\n        "school": "core",\n        "version": "1.0.0",\n        "source": "示例八卦名称，仅作结构演示",\n      ...   /*\n        之后可以继续补：\n        "2": {...}, "3": {...}, ..., "7": {...}\n        */\n    },\n    "hexagrams": {}\n}\n'
> idx = 0
>
>     def raw_decode(self, s, idx=0):
>         """Decode a JSON document from ``s`` (a ``str`` beginning with
>         a JSON document) and return a 2-tuple of the Python
>         representation and the index in ``s`` where the document ended.
>
>         This can be used to decode a JSON document from a string that may
>         have extraneous data at the end.
>
>         """
>         try:
> >           obj, end = self.scan_once(s, idx)
>                        ^^^^^^^^^^^^^^^^^^^^^^
> E           json.decoder.JSONDecodeError: Expecting property name enclosed in double quotes: line 20 column 9 (char 444)
>
> ../../anaconda3/lib/python3.11/json/decoder.py:353: JSONDecodeError
>
> The above exception was the direct cause of the following exception:
>
>     def test_load_core_trigrams_file():
>         """
>         使用 data/core/core_trigrams.v1.json 示例文件，验证：
>         - meta 信息读取正常
>         - trigrams 字典中包含预期 id
>         """
>         path = DATA_CORE_DIR / "core_trigrams.v1.json"
> >       bundle = load_core_names(path)
>                  ^^^^^^^^^^^^^^^^^^^^^
>
> tests/test_metadata_core_loader.py:30:
> _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
> dao/metadata_core_loader.py:211: in load_core_names
>     data = _load_json(p)
>            ^^^^^^^^^^^^^
> _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
>
> path = PosixPath('/home/xashes/projects/dao/data/core/core_trigrams.v1.json')
>
>     def _load_json(path: Path) -> Dict[str, Any]:
>         if not path.is_file():
>             raise FileNotFoundError(f"Metadata file not found: {path}")
>
>         text = path.read_text(encoding="utf-8")
>         try:
>             data = json.loads(text)
>         except json.JSONDecodeError as e:
> >           raise ValueError(f"Failed to parse JSON from {path}: {e}") from e
> E           ValueError: Failed to parse JSON from /home/xashes/projects/dao/data/core/core_trigrams.v1.json: Expecting property name enclosed in double quotes: line 20 column 9 (char 444)
>
> dao/metadata_core_loader.py:50: ValueError
> _________________________ test_load_core_hexagrams_file _________________________
>
> path = PosixPath('/home/xashes/projects/dao/data/core/core_hexagrams.v1.json')
>
>     def _load_json(path: Path) -> Dict[str, Any]:
>         if not path.is_file():
>             raise FileNotFoundError(f"Metadata file not found: {path}")
>
>         text = path.read_text(encoding="utf-8")
>         try:
> >           data = json.loads(text)
>                    ^^^^^^^^^^^^^^^^
>
> dao/metadata_core_loader.py:48:
> _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
> ../../anaconda3/lib/python3.11/json/__init__.py:346: in loads
>     return _default_decoder.decode(s)
>            ^^^^^^^^^^^^^^^^^^^^^^^^^^
> ../../anaconda3/lib/python3.11/json/decoder.py:337: in decode
>     obj, end = self.raw_decode(s, idx=_w(s, 0).end())
>                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
> _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
>
> self = <json.decoder.JSONDecoder object at 0x7fbd5aa73550>
> s = '{\n    "_meta": {\n        "school": "core",\n        "version": "1.0.0",\n        "source": "示例六十四卦名称，仅作结构演示",\n    ...       "name_pinyin": "fu"\n        },\n        /*\n    之后可以继续补：\n    "2": {...}, ..., "63": {...}\n    */\n    }\n}\n'
> idx = 0
>
>     def raw_decode(self, s, idx=0):
>         """Decode a JSON document from ``s`` (a ``str`` beginning with
>         a JSON document) and return a 2-tuple of the Python
>         representation and the index in ``s`` where the document ended.
>
>         This can be used to decode a JSON document from a string that may
>         have extraneous data at the end.
>
>         """
>         try:
> >           obj, end = self.scan_once(s, idx)
>                        ^^^^^^^^^^^^^^^^^^^^^^
> E           json.decoder.JSONDecodeError: Expecting property name enclosed in double quotes: line 21 column 9 (char 465)
>
> ../../anaconda3/lib/python3.11/json/decoder.py:353: JSONDecodeError
>
> The above exception was the direct cause of the following exception:
>
>     def test_load_core_hexagrams_file():
>         """
>         使用 data/core/core_hexagrams.v1.json 示例文件，验证：
>         - meta 信息读取正常
>         - hexagrams 字典中包含预期 id
>         """
>         path = DATA_CORE_DIR / "core_hexagrams.v1.json"
> >       bundle = load_core_names(path)
>                  ^^^^^^^^^^^^^^^^^^^^^
>
> tests/test_metadata_core_loader.py:53:
> _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
> dao/metadata_core_loader.py:211: in load_core_names
>     data = _load_json(p)
>            ^^^^^^^^^^^^^
> _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
>
> path = PosixPath('/home/xashes/projects/dao/data/core/core_hexagrams.v1.json')
>
>     def _load_json(path: Path) -> Dict[str, Any]:
>         if not path.is_file():
>             raise FileNotFoundError(f"Metadata file not found: {path}")
>
>         text = path.read_text(encoding="utf-8")
>         try:
>             data = json.loads(text)
>         except json.JSONDecodeError as e:
> >           raise ValueError(f"Failed to parse JSON from {path}: {e}") from e
> E           ValueError: Failed to parse JSON from /home/xashes/projects/dao/data/core/core_hexagrams.v1.json: Expecting property name enclosed in double quotes: line 21 column 9 (char 465)
>
> dao/metadata_core_loader.py:50: ValueError
> ============================ short test summary info ============================
> FAILED tests/test_metadata_core_loader.py::test_load_core_trigrams_file - Valu...
> FAILED tests/test_metadata_core_loader.py::test_load_core_hexagrams_file - Val...
> ========================= 2 failed, 25 passed in 0.08s ==========================

两个错误的核心原因其实只有一个：**JSON 文件里有注释（`/* ... */`）**，而标准 JSON 不允许任何注释，所以 `json.loads` 直接报错。

咱们一步一步把问题解决，再顺手把两个数据文件补全成可用版本（先给出完整结构，你以后可以根据自己的卦序方案调整映射）。

---

## 一、为什么会报错？

报错关键信息：

```text
JSONDecodeError: Expecting property name enclosed in double quotes: line 20 column 9
...
text = '{ ... /* 之后可以继续补： "2": {...}, ... */ }'
```

也就是说，你按照我之前的“示例”把这段带 `/* ... */` 的注释也写进了 `.json` 文件里：

```jsonc
    "1": {
      "id": 1,
      "name_zh": "震",
      "name_pinyin": "zhen"
    }
    /*
    之后可以继续补：
    "2": {...}, "3": {...}, ..., "7": {...}
    */
```

但标准 JSON 不允许：

- `// 注释`
- `/* 注释块 */`

所以 `json.loads` 一看到 `/*` 就崩了。

**解决办法**：把这类示例注释从文件里删掉，真正在文件中只保留合法 JSON。

---

## 二、给你两份“可直接用 + 完整内容”的数据文件

> 说明：
> - 这里我给的是“完整 8 卦 + 64 卦”的 **结构**。
> - **卦名是标准的，但 `id`（bits）与卦序的具体对应规则，你之后可以按自己的方案调整。**
> - 目前先给出一个简单的“按文王卦序 1–64 映射到 id 0–63”的版本，便于你顺利跑通 loader 和测试。
>   - 即：文王卦序 1（乾）→ id=0，文王卦序 2（坤）→ id=1，…，文王卦序 64（未济）→ id=63
>   - 这只是一个占位规则，将来你决定用“binary sequence 卦序”或者“王弼排序”等都可以再替换。

如果你暂时只想要“**能跑通，不纠结映射**”，就先按下面这些内容用；
以后你要精确对齐某个学派的位编码，我们再专门做一次“编码对照表设计”。

---

### 1. `data/core/core_trigrams.v1.json`

**内容：八卦的名字 + id=0..7 简单顺排**
（你以后可以把 bits 的含义重新设计，这里先只占位）

```json
{
  "_meta": {
    "school": "core",
    "version": "1.0.0",
    "source": "八卦名称示例，仅作结构演示",
    "last_updated": "2025-11-28",
    "notes": "当前 id=0..7 与具体卦象（二进制爻序）的对应关系为占位方案，未来可按需要重新定义。"
  },
  "trigrams": {
    "0": {
      "id": 0,
      "name_zh": "乾",
      "name_pinyin": "qian"
    },
    "1": {
      "id": 1,
      "name_zh": "兑",
      "name_pinyin": "dui"
    },
    "2": {
      "id": 2,
      "name_zh": "离",
      "name_pinyin": "li"
    },
    "3": {
      "id": 3,
      "name_zh": "震",
      "name_pinyin": "zhen"
    },
    "4": {
      "id": 4,
      "name_zh": "巽",
      "name_pinyin": "xun"
    },
    "5": {
      "id": 5,
      "name_zh": "坎",
      "name_pinyin": "kan"
    },
    "6": {
      "id": 6,
      "name_zh": "艮",
      "name_pinyin": "gen"
    },
    "7": {
      "id": 7,
      "name_zh": "坤",
      "name_pinyin": "kun"
    }
  },
  "hexagrams": {}
}
```

> 说明：八卦的顺序我这里随便选了一个常见排列（乾兑离震巽坎艮坤），**重点在于 JSON 是合法的**。
> 你以后可以定义一份 “trigram_bits_mapping.md”，把 bits→八卦的对应关系严格写清楚，然后再调这个文件里的 `id`。

---

### 2. `data/core/core_hexagrams.v1.json`

这里给出 **64 卦的名字 + id=0..63 的简单顺序映射**。
我用文王卦序（乾、坤、屯、蒙……）依次排列，对应 id 从 0 到 63。

> 你可以先直接用，下次我们如果要严谨设计“bits 编码↔卦序”的规则，可以单独开一小节，只讨论这个对照表。

```json
{
  "_meta": {
    "school": "core",
    "version": "1.0.0",
    "source": "周易六十四卦卦名，按文王卦序排列，仅作结构演示",
    "last_updated": "2025-11-28",
    "notes": "当前 id=0..63 仅按文王卦序 1..64 顺序映射，未与具体爻位二进制编码严格对齐，未来可按需要重新定义。"
  },
  "trigrams": {},
  "hexagrams": {
    "0":  { "id": 0,  "name_zh": "乾", "name_pinyin": "qian" },
    "1":  { "id": 1,  "name_zh": "坤", "name_pinyin": "kun" },
    "2":  { "id": 2,  "name_zh": "屯", "name_pinyin": "zhen" },
    "3":  { "id": 3,  "name_zh": "蒙", "name_pinyin": "meng" },
    "4":  { "id": 4,  "name_zh": "需", "name_pinyin": "xu" },
    "5":  { "id": 5,  "name_zh": "讼", "name_pinyin": "song" },
    "6":  { "id": 6,  "name_zh": "师", "name_pinyin": "shi" },
    "7":  { "id": 7,  "name_zh": "比", "name_pinyin": "bi" },
    "8":  { "id": 8,  "name_zh": "小畜", "name_pinyin": "xiaoxu" },
    "9":  { "id": 9,  "name_zh": "履", "name_pinyin": "lü" },
    "10": { "id": 10, "name_zh": "泰", "name_pinyin": "tai" },
    "11": { "id": 11, "name_zh": "否", "name_pinyin": "pi" },
    "12": { "id": 12, "name_zh": "同人", "name_pinyin": "tongren" },
    "13": { "id": 13, "name_zh": "大有", "name_pinyin": "dayou" },
    "14": { "id": 14, "name_zh": "谦", "name_pinyin": "qian2" },
    "15": { "id": 15, "name_zh": "豫", "name_pinyin": "yu" },
    "16": { "id": 16, "name_zh": "随", "name_pinyin": "sui" },
    "17": { "id": 17, "name_zh": "蛊", "name_pinyin": "gu" },
    "18": { "id": 18, "name_zh": "临", "name_pinyin": "lin" },
    "19": { "id": 19, "name_zh": "观", "name_pinyin": "guan" },
    "20": { "id": 20, "name_zh": "噬嗑", "name_pinyin": "shike" },
    "21": { "id": 21, "name_zh": "贲", "name_pinyin": "bi4" },
    "22": { "id": 22, "name_zh": "剥", "name_pinyin": "bo" },
    "23": { "id": 23, "name_zh": "复", "name_pinyin": "fu" },
    "24": { "id": 24, "name_zh": "无妄", "name_pinyin": "wuwang" },
    "25": { "id": 25, "name_zh": "大畜", "name_pinyin": "daxu" },
    "26": { "id": 26, "name_zh": "颐", "name_pinyin": "yi" },
    "27": { "id": 27, "name_zh": "大过", "name_pinyin": "daguo" },
    "28": { "id": 28, "name_zh": "坎", "name_pinyin": "kan" },
    "29": { "id": 29, "name_zh": "离", "name_pinyin": "li" },
    "30": { "id": 30, "name_zh": "咸", "name_pinyin": "xian" },
    "31": { "id": 31, "name_zh": "恒", "name_pinyin": "heng" },
    "32": { "id": 32, "name_zh": "遯", "name_pinyin": "dun" },
    "33": { "id": 33, "name_zh": "大壮", "name_pinyin": "dazhuang" },
    "34": { "id": 34, "name_zh": "晋", "name_pinyin": "jin" },
    "35": { "id": 35, "name_zh": "明夷", "name_pinyin": "mingyi" },
    "36": { "id": 36, "name_zh": "家人", "name_pinyin": "jiaren" },
    "37": { "id": 37, "name_zh": "睽", "name_pinyin": "kui" },
    "38": { "id": 38, "name_zh": "蹇", "name_pinyin": "jian" },
    "39": { "id": 39, "name_zh": "解", "name_pinyin": "xie" },
    "40": { "id": 40, "name_zh": "损", "name_pinyin": "sun" },
    "41": { "id": 41, "name_zh": "益", "name_pinyin": "yi2" },
    "42": { "id": 42, "name_zh": "夬", "name_pinyin": "guai" },
    "43": { "id": 43, "name_zh": "姤", "name_pinyin": "gou" },
    "44": { "id": 44, "name_zh": "萃", "name_pinyin": "cui" },
    "45": { "id": 45, "name_zh": "升", "name_pinyin": "sheng" },
    "46": { "id": 46, "name_zh": "困", "name_pinyin": "kun2" },
    "47": { "id": 47, "name_zh": "井", "name_pinyin": "jing" },
    "48": { "id": 48, "name_zh": "革", "name_pinyin": "ge" },
    "49": { "id": 49, "name_zh": "鼎", "name_pinyin": "ding" },
    "50": { "id": 50, "name_zh": "震", "name_pinyin": "zhen2" },
    "51": { "id": 51, "name_zh": "艮", "name_pinyin": "gen2" },
    "52": { "id": 52, "name_zh": "渐", "name_pinyin": "jian2" },
    "53": { "id": 53, "name_zh": "归妹", "name_pinyin": "guimei" },
    "54": { "id": 54, "name_zh": "丰", "name_pinyin": "feng" },
    "55": { "id": 55, "name_zh": "旅", "name_pinyin": "lü2" },
    "56": { "id": 56, "name_zh": "巽", "name_pinyin": "xun2" },
    "57": { "id": 57, "name_zh": "兑", "name_pinyin": "dui2" },
    "58": { "id": 58, "name_zh": "涣", "name_pinyin": "huan" },
    "59": { "id": 59, "name_zh": "节", "name_pinyin": "jie" },
    "60": { "id": 60, "name_zh": "中孚", "name_pinyin": "zhongfu" },
    "61": { "id": 61, "name_zh": "小过", "name_pinyin": "xiaoguo" },
    "62": { "id": 62, "name_zh": "既济", "name_pinyin": "jiji" },
    "63": { "id": 63, "name_zh": "未济", "name_pinyin": "weiji" }
  }
}
```

> 我这里的拼音字段里有些用了区分用的数字（比如 `qian2`、`dui2`），**你完全可以根据自己喜好改为标准拼音**。
> 重点仍然是：**JSON 合法 & 结构正确**，便于 loader 正常工作。

---

## 三、下一步你可以做什么？

1. 把你当前 `core_trigrams.v1.json` 和 `core_hexagrams.v1.json` 中的注释段删掉，或者直接整体替换为上面的版本。
2. 确认路径为：

   ```text
   /home/xashes/projects/dao/data/core/core_trigrams.v1.json
   /home/xashes/projects/dao/data/core/core_hexagrams.v1.json
   ```

3. 在项目根目录再跑一次：

   ```bash
   cd /home/xashes/projects/dao
   python -m pytest
   ```

如果还有错误，把新的报错贴出来，我们继续排；
一旦测试都通过，我们就可以开始设计 **插件式 mapping（五行、方位、先天/后天八卦等）的通用 schema** 了。

-----

> 很好，现在我们讨论一下怎么设计插件式Mapping的通用Schema

很好，我们现在正式来把「插件式 Mapping」这块设计清楚。

我会先讲一下 **目标和边界**，再给出一个我推荐的通用 Schema，并说明它将来怎么和图结构（L1.C）配合，而不会互相打架。

---

## 1. 先划清边界：Mapping 文件解决什么，不解决什么？

结合你前面的思路，可以这样定性：

- **Mapping 文件 = 某一类“标签/属性”的单独插件**
  - 比如：
    - `direction.xiantian.trigram.json`：先天八卦 → 方位
    - `family.trigram.json`：八卦 → 父母子女
    - `wuxing.hexagram.main.json`：六十四卦 → 五行属性
  - 每个文件只表达一种“从某个对象 → 一些属性/标签”的**简单映射**。
  - 典型形式：
    > 「这个 trigram/hexagram 拥有什么属性？」

- **图结构 L1.C = 复杂关系网络**
  - 多对多、路径、关系类型很丰富，比如：
    - 五行之间的生克：木→火（生）、木→土（克）
    - 卦气/节气/时间区间之间的关联
    - 纳甲：某卦某爻 → 某天干地支
  - 这是「A 和 B 存在某种关系」的网络，不一定是单向“属性”。

**简单说：**

> Mapping 用来做「归类 / 打标签」；
> Graph 用来做「连线 / 走路径」。

我们现在设计的是前者（Mapping）。

---

## 2. 统一 ID 规范（非常关键的一步）

为了让所有插件文件、图结构、代码能说同一种“语言”，我们给所有对象一个统一的“全局 ID 格式”。

先定一版简单的约定（够你用很久）：

- **卦类：**
  - 三爻卦：`"trigram:<id>"`，其中 `<id>` 是 `0..7`（width=3 的 bits）
    - 例：`"trigram:0"`
  - 六爻卦：`"hexagram:<id>"`，其中 `<id>` 是 `0..63`
    - 例：`"hexagram:23"`

- **五行：**
  - `"element:wood"`, `"element:fire"`, `"element:earth"`, `"element:metal"`, `"element:water"`

- **方位（示意）：**
  - `"direction:N"`, `"direction:NE"`, `"direction:E"`, … 或 `"direction:北"` 等

- **家人关系：**
  - `"family:father"`, `"family:mother"`, `"family:eldest_son"` 等

- **（预留）爻：**
  - `"yao:<hexagramId>:<pos>"`，比如 `"yao:23:0"` 表示「第 23 号卦的初爻」
  - 这个我们可以以后需要的时候再正式写规范

这样一来：

- Mapping 文件里的 key 就可以统一写成 `"trigram:0"`, `"hexagram:5"` 等。
- 图结构里的节点 ID 也用同样的格式。
- 任何地方只要看到 `trigram:0`，大家都知道那就是 **id=0 的三爻卦**，不需要额外带 `"kind": "trigram"`。

---

## 3. 我推荐的 Mapping 通用 Schema

### 3.1 目标

我们希望每个 Mapping 文件：

1. 有统一的“外壳结构”（元信息 + mapping 区块）。
2. 内部的字段（比如 `direction`, `element`, `family`）**只在 JSON 中定义**，Python 代码里不预设这些字段名。
3. 一份文件只负责一个“主题”（theme），例如 `direction.xiantian.trigram`。

### 3.2 通用 JSON Schema（示例）

以「**先天八卦方位**」这类为例，设计成这样：

```json
{
  "_meta": {
    "school": "xiantian",
    "version": "1.0.0",
    "source": "先天八卦方位说",
    "last_updated": "2025-11-28",
    "notes": "示例：先天八卦与方位的对应，仅作结构演示。",

    "theme": "direction",              // 新增：这个文件是关于“方向”的
    "target_kinds": ["trigram"]        // 新增：主要作用对象的种类
  },
  "mapping": {
    "trigram:0": {
      "direction": "N"
    },
    "trigram:1": {
      "direction": "SW"
    }
  }
}
```

要点：

- `_meta` 里除了之前的 `school, version, source, last_updated, notes` 外：
  - **`theme`**：这个插件属于哪个“主题”（direction / family / wuxing / names.en / ...）
  - **`target_kinds`**：主要作用对象类型列表（如只针对 trigram，也可以是 `[ "hexagram" ]`、`["trigram","hexagram"]` 等）
- `mapping`：
  - key：全局 ID 字符串（如 `"trigram:0"`, `"hexagram:23"`）
  - value：**任意字段的对象**，比如 `{ "direction": "N" }`、`{ "element": "earth", "phase": "yang" }` 等

对于另一个例子，“八卦→家人关系”插件，可以是：

```json
{
  "_meta": {
    "school": "family.trigram",
    "version": "1.0.0",
    "source": "传统八卦家人说",
    "last_updated": "2025-11-28",
    "notes": null,
    "theme": "family",
    "target_kinds": ["trigram"]
  },
  "mapping": {
    "trigram:0": {
      "family": "father"
    },
    "trigram:1": {
      "family": "mother"
    }
  }
}
```

对于“六十四卦→五行（主流版）”，可以是：

```json
{
  "_meta": {
    "school": "wuxing.main",
    "version": "1.0.0",
    "source": "某某易学体系整理",
    "last_updated": "2025-11-28",
    "notes": "示例：每卦一个主五行",
    "theme": "wuxing",
    "target_kinds": ["hexagram"]
  },
  "mapping": {
    "hexagram:0": {
      "element": "earth"
    },
    "hexagram:1": {
      "element": "wood"
    }
  }
}
```

**注意：**
`mapping` 里的字段名（`direction`, `family`, `element`）完全由 **数据文件决定**，代码只知道这是一个 `dict[str, any]`。

---

## 4. Python 侧的通用承载结构（只做“外壳强类型”）

按照你第二点的要求：**不要在 Python 中预定义所有字段名**，避免同步问题。我建议只对“外层”做强类型，对“每个项的内容”用动态 dict。

大致会是这样的设计（先是思路，不急着写代码）：

```python
@dataclass
class MappingMetaInfo:
    # 基本沿用 MetaVersionInfo，加上 theme / target_kinds
    school: str
    version: str
    source: str
    last_updated: str
    notes: str | None

    theme: str                   # 比如 "direction", "wuxing", "family"
    target_kinds: list[str]      # 比如 ["trigram"], ["hexagram"], ["element", "hexagram"]


@dataclass
class MappingFile:
    meta: MappingMetaInfo
    mapping: dict[str, dict[str, object]]
    # mapping 的 key 是全局 ID："trigram:0" / "hexagram:23" / "element:wood"
    # value 是字段 -> 任意值 的 dict
```

这样可以满足：

- **新增一个 Mapping 文件（五行、方位、干支……）时，无需修改任何 Python 类型定义。**
- Loader 只要做：
  - 解析 `_meta` 固定字段 + `theme` / `target_kinds`
  - 读取 `mapping` 为 `dict[str, dict]`，不关心里面具体字段名
- 使用者（上层逻辑）知道自己在处理什么主题，就可以用约定好的字段名去读，比如：

  ```python
  mf = load_mapping("data/mappings/direction.xiantian.trigram.v1.json")
  mf.mapping["trigram:0"]["direction"]  # "N"
  ```

---

## 5. 多对多 & 多种对象：Mapping vs Graph 怎么分工？

你可能会担心一个问题：

> 如果我要表示「五行生克」这种关系，是用 Mapping 还是 Graph？

我的建议是：

- **Mapping 文件用于“某个对象被赋予的属性/标签”**：
  - 这卦是什么五行？→ `hexagram:0` → `{ "element": "earth" }`
  - 这个 trigram 对应哪个方位？→ `trigram:3` → `{ "direction": "E" }`
  - 这个 hexagram 对应哪些象义关键词？→ `{ "keywords": ["刚健", "创始"] }`

- **复杂关系（尤其是 A 与 B 的连线）放到 Graph（L1.C）里：**
  - 木→火（生），火→土（生），木→土（克）…
  - “element:wood” → “element:fire” 的 `GENERATES` 边
  - “hexagram:23” ↔ “solar_term:lichun” 的时间关系等

当然，你也可以在 Mapping 里用数组表达“多值属性”，比如：

```json
"hexagram:0": {
  "elements": ["earth", "wood"]
}
```

这不冲突；Mapping 仍然是“基于一个对象的属性描述”，只是属性值本身是数组。

---

## 6. 总结一下这版 Schema 的特点

- **插件化非常彻底**：
  - 每个 Mapping 文件只负责一个 theme + 一组 target_kinds
  - 新增/删除/替换理论 = 新增/删除/替换文件，不动 Core / 其他文件
- **Python 端不被字段名拖累**：
  - 只对 `_meta`, `mapping` 这些公共结构做强类型
  - 具体字段名（方向、五行、家族、节气）全由 JSON 定义，避免双写
- **与图结构自然衔接**：
  - 全局 ID（`"trigram:0"` 等）在 Mapping 和 Graph 中共用
  - Mapping 更适合“对象→属性”，Graph 管“对象↔对象”关系

---

如果你对这套通用 Schema 没有异议，下一小步我可以帮你：

1. 写一个 `dao/mapping_types.py`：定义 `MappingMetaInfo` / `MappingFile` 这两个 dataclass。
2. 写一个 `dao/mapping_loader.py`：实现 `load_mapping(path: str) -> MappingFile`。
3. 做两个非常小的示例文件，比如：
   - `data/mappings/direction.xiantian.trigram.v1.json`
   - `data/mappings/family.trigram.v1.json`
4. 再配一份 `tests/test_mapping_loader.py`，用来验证结构 & 用法。

我们依然按“**一个小模块 + 一个测试文件**”的节奏推进。

-----

> 这个结构你已经设计的很好了，但我还是觉得有些疑惑的地方。比如说五行，一方面与卦象相关，一方面与方位相关，还与干支等等很多内容相关，这样用Mapping的形式存储，总感觉和数据本身的关联形状不太相符，实现和日后查询起来都有诸多困难。其他数据也是如此，道家玄学山医命相卜的各种理论元素之间，这种关联极其多，大多都是一种多对多的关系，这种关系，还有什么好的建模方法吗？当前的方式，还是感觉难以很好地对这些关联建立模型

你这个直觉是**对的**：
五行这种东西，天生就是“到处勾连、处处挂钩”的，多对多是常态，用简单 Mapping 去装它，本身就有点别扭。

其实我们已经在做对的事了：
- **Mapping 适合“打标签/归类”**
- **这种全场乱飞、连法极多的东西，应该用“关系为中心”的模型**

下面我换个角度帮你把这套建模方式讲完整一点。

---

## 1. 接受一个事实：**Mapping 不是“真相”，Graph 才是**

你现在感觉到的“别扭”，根源其实是：

> 你想把“复杂关系”塞到“属性表”里。

比如五行：

- 卦 ↔ 五行
- 方位 ↔ 五行
- 干支 ↔ 五行
- 脏腑 ↔ 五行
- 季节 ↔ 五行
- 颜色/味道/情志/音律…… ↔ 五行

这明显是一个**超巨大多对多关系网**，而不是“对象自带几个属性”这么简单。

所以建议做一个**心理结构调整**：

- **Mapping：**只是“某个角度的平面投影/视图（view）”
- **Graph：**才是“真实的三维结构”

换句话说：

> 把“五行”真正存在哪儿？——存进 **关系图（知识图谱）**。
> Mapping 只是从图里“切出一块平面”方便使用。

---

## 2. 用“关系为一等公民”的模型：**三元组 / 边对象**

我们给所有东西一个统一 ID（你之前已经接受的那套）：

- 八卦：`trigram:0` … `trigram:7`
- 六十四卦：`hexagram:0` … `hexagram:63`
- 五行：`element:wood` / `element:fire` ...
- 方位：`direction:N` / `direction:SE` ...
- 干支：`stem:jia`, `branch:zi`
- 脏腑：`organ:liver`，`organ:heart` ...

在这个基础上，**真正描述“知识”的单位，不是对象本身，而是一条“关系陈述”**，可以用“三元组 + 元数据”来表示：

```jsonc
{
  "subject": "trigram:0",
  "predicate": "corresponds_to.element",
  "object": "element:heaven",
  "context": {
    "school": "xiantian",
    "source": "xxx古籍",
    "confidence": 0.9
  }
}
```

再看一些例子：

### 2.1 卦 ↔ 五行

```jsonc
{
  "subject": "hexagram:1",
  "predicate": "corresponds_to.element",
  "object": "element:wood",
  "context": {
    "school": "某家六十四卦五行说",
    "comment": "主木"
  }
}
```

### 2.2 方位 ↔ 五行

```jsonc
{
  "subject": "direction:E",
  "predicate": "corresponds_to.element",
  "object": "element:wood",
  "context": {
    "school": "hou_tian",
    "comment": "后天八卦方位"
  }
}
```

### 2.3 干支 ↔ 五行

```jsonc
{
  "subject": "stem:jia",
  "predicate": "has_element",
  "object": "element:wood",
  "context": {
    "comment": "甲属阳木"
  }
}
```

### 2.4 五行内部的生克

```jsonc
{
  "subject": "element:wood",
  "predicate": "generates",
  "object": "element:fire",
  "context": {
    "system": "wuxing.standard"
  }
}
```

现在你会发现，**所有这些关系结构其实是统一的：**

> 主体（subject） + 关系类型（predicate） + 客体（object）
> 再加一点 context（学派、来源、强度、注解）

这就是一个**简化版的知识图谱 / RDF 三元组模型**，但我们可以用非常轻量的 JSON 来实现，不需要搞复杂的语义网技术栈。

---

## 3. 那 Mapping 还有什么用？

Mapping 的角色就变了：

- **不是“存储所有知识”**
- 而是从图里**切出某一类“方便查的表格视图”**

比如，你想要一个“六十四卦 → 主五行”的简单配置文件：

> 但在图里，其实一个卦可能有多个五行说法、多个学派、多个语境。

**做法：**

1. 在图结构里存所有复杂关系（如上面那些三元组）。
2. 写一个小工具 / 脚本，按某个规则（比如选“main 方案”和“某学派”）**生成一个 Mapping 文件**：

```json
{
  "_meta": {
    "school": "wuxing.main",
    "theme": "hexagram.element",
    "target_kinds": ["hexagram"]
  },
  "mapping": {
    "hexagram:0": { "element": "earth" },
    "hexagram:1": { "element": "wood" }
  }
}
```

这个 Mapping 文件只是一张**“方便读取的 cache / view”**：

- 快速查询的时候：
  `mapping["hexagram:1"]["element"]` → `wood`
- 需要更精细/多版本/追根溯源的时候：
  去图结构里查所有 `subject=hexagram:1 AND predicate=corresponds_to.element` 的边

所以你之前担心的点：

> 「五行既和卦象有关，又和方位有关，用 Mapping 感觉很难统一」

在这种设计下就不再是问题了，因为：

- “五行↔卦象”“五行↔方位”“五行↔干支”都是**同一类东西：图里的边**。
- Mapping 不再是“唯一的存储”，只是若干针对特定查询场景的“平面视图”。

---

## 4. 多对多、甚至多元关系，怎么处理？

### 4.1 普通多对多

像「某卦对应三个方位，某方位对应两个五行」这种，图里就是多条边：

```jsonc
{ "subject": "hexagram:1", "predicate": "corresponds_to.direction", "object": "direction:NE" }
{ "subject": "hexagram:1", "predicate": "corresponds_to.direction", "object": "direction:E" }
{ "subject": "direction:E", "predicate": "corresponds_to.element",  "object": "element:wood" }
```

查询“**与木相关的一切**”就非常自然：

> 找出所有 `subject=element:wood OR object=element:wood` 的边，然后把另一端全收集起来。

### 4.2 真正“多元”的关系（>2 个参数）

比如“纳甲”这种：
**某卦的某一爻 ↔ 某个天干**，关系是三元的：

- 卦：`hexagram:1`
- 爻位：`yao_pos:初爻`（或者 `yao:1:0`）
- 干：`stem:jia`

在双向边模型里，我们可以：

- 建一个“**关系节点**”来承载这件事：

```text
(NaJiaTriple:#123)
  ├─ relates hexagram:1
  ├─ relates yao_pos:0
  └─ relates stem:jia
```

JSON 写法类似：

```jsonc
{
  "id": "relation:najia:123",
  "type": "najia",
  "args": {
    "hexagram": "hexagram:1",
    "line": 0,
    "stem": "stem:jia"
  },
  "context": {
    "school": "xxx",
    "source": "xxx"
  }
}
```

这就是从“边是关系”再下一步，**关系本身变成一个节点 / 对象**。
但是整体思想一样：**关系是核心实体**，不是被动附属。

---

## 5. 给你一个可落地的分层方案

我们可以把这套东西整理成几个层级，你的项目就会非常清晰：

### L0. 词汇层（Vocabulary）

- 定义所有 ID 和类型：trigram/hexagram/element/direction/stem/branch/organ/time_period...
- 就是一个“术语表 + ID 规范”

### L1. 关系层（Core Graph）

- 核心数据形态 = 很多条 `Relation`（三元组 + context）：
  - `subject`, `predicate`, `object`, `context`
- 数据可拆成多个“知识包”文件：
  - `wuxing.core.json`
  - `bagua.direction.xiantian.json`
  - `ganzhi.element.json`
  - `najia.system1.json`
- 这是**真正的知识库主体**。

### L2. 视图 / Mapping 层（Projections / Views）

- 按主题、按学派、按用途，从 L1 生成（或人工维护）各种 Mapping：
  - `hexagram.main_element.v1.json`
  - `trigram.direction.xiantian.v1.json`
  - `branch.season.main.v1.json`
- 这些用于：
  - 快速查 “某对象的一个主属性”
  - 配置 UI、算法默认值
  - 做规则推理时的简化输入

### L3. 规则 / 推理层（Optional）

- 在 L1 + L2 的基础上跑规则：
  - “如果卦的五行是木，而某天干也属木，则……”
  - “如果五行相克，则减少权重……”
- 这层用纯代码就好。

---

## 6. 回答你最核心的那句话

> “道家玄学山医命相卜的各种理论元素之间，这种关联极其多，大多都是一种多对多的关系，这种关系，还有什么好的建模方法吗？”

**简明版回答：**

- 是的，这类系统本质上就是一个**超大的多对多关系网络**。
- 最合适的通用模型就是：
  - **统一 ID 的知识图谱（Graph）+ 关系为一等公民（三元组/关系对象）**
- Mapping 不是用来“装下所有关系”的，而是：
  - 在 Graph 之上，给不同“使用场景”提供的**专用视图/快捷表**。

如果你愿意，下一步我们可以：

1. 定义一个极简的 `Relation` 数据结构（Python + JSON）；
2. 用**五行 ↔ 卦 / 方位 / 干支** 这些你刚提到的典型体系，做一个“小规模 demo 知识图谱”；
3. 再在这个基础上，示范如何自动生成你之前设计的 Mapping 文件，让你真正感受到“Graph 是源头，Mapping 是投影”的工作流。

-----

> 对你讲的内容，我大概能听懂，但不敢说完全明了了。这个分层方案似乎不错，我想的也是，要先有一个词汇层（我想的是，所有元素，包括五行、干支、节气……都定义成Node，然后再以某种方式把它们都关联起来，有点像在图数据库中的操作）。我还有一个想法就是，每次看到一个新理论，要能方便地把它加入进来，比如看医书，看到五脏与卦象、五行、方位、季节的关系，就加入到现有系统中。
> 以上是添加，读取也是一样，比如我想看九宫图，图中要叠加河图洛书中的象数、五行、八卦、和人体的对应关系、方向等等，也可以直接读取。
> 如何建模才能做到这一点呢？
> 想到这里，是不是只有图结构才有可能？

先直接回答你最后一句：

> 想到这里，是不是只有图结构才有可能？

**概念层面：几乎是的。**
但“用图结构思考”≠“必须上某个图数据库”。你完全可以：

- **概念上用图模型（Node + Relation）去设计**
- 实现上，用 JSON / 关系型 / 文档库 / 图数据库都行

关键是**数据模型要是“关系为中心的图”**，而不是“对象带一堆字段”。

下面我把你关心的两件事拆开讲：

1. **随时往系统里加入新理论（看书随手录入）**
2. **像看九宫图一样，一次叠加多层对应关系进行读取**

---

## 一、核心建模思路：Node + Statement + Theory 三件套

你已经有了“所有元素都是 Node”的直觉，这个非常好。我们在这个基础上，把“关系”和“学派/来源”也提升为一等公民。

### 1. Node：一切“名词”

所有“可以被提到”的东西都是 Node：

- 五行：`element:wood` / `element:fire` …
- 干支：`stem:jia`, `branch:zi`
- 卦象：`trigram:zhen`, `hexagram:qian`
- 方位：`direction:E`, `direction:SE`
- 五脏：`organ:liver`, `organ:heart`
- 节气：`solar_term:lichun`
- 九宫格子：`palace:1`…`palace:9`
- 数字：`number:1_luoshu`（洛书一）、`number:1_hetu`（河图一）

**Node 结构很简单，只解决“它是谁”：**

```jsonc
{
  "id": "organ:liver",
  "kind": "organ",
  "names": {
    "zh": ["肝"],
    "pinyin": ["gan1"]
  },
  "meta": {
    "notes": "中医五脏之一"
  }
}
```

> 词汇层（vocabulary） = 一堆 Node

---

### 2. Statement：一条具体的“理论陈述”

真正的“知识”不是 Node 本身，而是**“谁和谁是什么关系”**。

我们用 **Statement** 来表示一条陈述（其实是“带上下文的边”）：

```jsonc
{
  "id": "stmt:00123",
  "subject": "organ:liver",
  "predicate": "corresponds_to.element",
  "object": "element:wood",
  "theory": "tcm.zangxiang.classic",
  "source": {
    "book": "黄帝内经·素问",
    "chapter": "阴阳应象大论",
    "page": 123
  },
  "meta": {
    "confidence": 0.9,
    "notes": "肝属木"
  }
}
```

再看几个例子：

#### 卦 ↔ 五行

```jsonc
{
  "id": "stmt:hexagram_qian_element",
  "subject": "hexagram:qian",
  "predicate": "corresponds_to.element",
  "object": "element:heaven",
  "theory": "zhouyi.wuxing.scheme1",
  "source": { "book": "某某易学著作" }
}
```

#### 方位 ↔ 五行

```jsonc
{
  "id": "stmt:direction_east_element",
  "subject": "direction:E",
  "predicate": "corresponds_to.element",
  "object": "element:wood",
  "theory": "bagua hậu thiên",
  "source": { "book": "易传", "comment": "东方木" }
}
```

#### 节气 ↔ 五行

```jsonc
{
  "id": "stmt:lichun_element",
  "subject": "solar_term:lichun",
  "predicate": "corresponds_to.element",
  "object": "element:wood",
  "theory": "tcm.four_seasons",
  "source": { "book": "黄帝内经" }
}
```

**注意：**

- `predicate` 是关系类型：`corresponds_to.element`, `has_number`, `governs.organ`…
- `theory` 把这条陈述挂到某套“理论体系/学派/作者”下面。

---

### 3. Theory：把同一路线的陈述组织在一起

例如：

```jsonc
{
  "id": "tcm.zangxiang.classic",
  "name": "中医·脏象学·经典体系",
  "domain": ["medicine"],
  "description": "以《内经》为主的五脏应五行、方位、季节等体系",
  "meta": {
    "period": "汉以后",
    "tags": ["五脏", "五行", "四时"]
  }
}
```

再比如：

- `bagua.direction.xiantian`：先天八卦方位说
- `bagua.direction.houtian`：后天八卦方位说
- `lo_shu.jiugong.standard`：九宫洛书标准象数
- `fengshui.school.x`：某派风水九宫配置

---

## 二、如何“看书时随手往系统里加理论”？（增量建模）

你说得很对：
> “看到医书里讲五脏与卦象、五行、方位、季节的关系，就加入到现有系统中。”

在上面这个模型下，**录入流程就非常自然**：

假设你在书里看到一句话（随便举例）：

> 肝应震卦，东方，春天，属木。

你做的事就是 3 步：

### 步骤 1：检查 Node 是否存在，不存在就补

- `organ:liver`
- `trigram:zhen`
- `direction:E`
- `season:spring`
- `element:wood`

缺哪个补哪个（词汇层只增不改，是最稳定的那层）。

### 步骤 2：为这句话拆成多条 Statement

```jsonc
{
  "subject": "organ:liver",
  "predicate": "corresponds_to.trigram",
  "object": "trigram:zhen",
  "theory": "tcm.zangxiang.classic",
  "source": { "book": "某医书", "page": 45 }
}
```

```jsonc
{
  "subject": "organ:liver",
  "predicate": "corresponds_to.direction",
  "object": "direction:E",
  "theory": "tcm.zangxiang.classic",
  "source": { "book": "某医书", "page": 45 }
}
```

```jsonc
{
  "subject": "organ:liver",
  "predicate": "corresponds_to.season",
  "object": "season:spring",
  "theory": "tcm.zangxiang.classic",
  "source": { "book": "某医书", "page": 45 }
}
```

```jsonc
{
  "subject": "organ:liver",
  "predicate": "corresponds_to.element",
  "object": "element:wood",
  "theory": "tcm.zangxiang.classic",
  "source": { "book": "某医书", "page": 45 }
}
```

### 步骤 3：存进去，就完了

- 不需要改“全局 schema”
- 不需要想“Mapping 结构咋办”
- 只要保证：
  - Node 用的是统一 ID
  - predicate 复用已有名称（比如 `corresponds_to.element`）

**以后别的书说“肝不属木，属火”也没关系：**

- 再加一条新的 Statement，挂在另一个 `theory` 下即可
- 矛盾是允许存在的，由“查询时选哪套 theory / 组合 theory”来解决

这就满足了你要的那个感觉：**看到新理论就能往里塞，而且不破坏旧的东西。**

---

## 三、九宫图叠加多层对应：怎么建模 + 怎么读？

你说的读取需求是这样的：

> “比如我想看九宫图，图中要叠加河图洛书中的象数、五行、八卦、和人体的对应关系、方向等等”

我们拆成两部分：
1. 九宫这个“底板”怎么建模？
2. 叠加各层信息时，如何从图里“读取”对应关系？

### 1. 九宫底板建模

#### 1.1 为九个宫格建 Node

```jsonc
{
  "id": "palace:1",
  "kind": "palace",
  "names": { "zh": ["一宫"] },
  "meta": { "grid": [0, 2] }  // 行列坐标：上中下 / 左中右 之类
}
```

一直到 `palace:9`。

#### 1.2 河图 / 洛书数布置

比如洛书：

```jsonc
{
  "subject": "palace:1",
  "predicate": "has_number",
  "object": "number:1_luoshu",
  "theory": "lo_shu.jiugong.standard"
}
```

```jsonc
{
  "subject": "palace:9",
  "predicate": "has_number",
  "object": "number:9_luoshu",
  "theory": "lo_shu.jiugong.standard"
}
```

河图如果也对应到九宫，也是一堆 `palace:x has_number number:y_hetu`，只是 `theory` 不同。

---

### 2. 往上叠：五行、八卦、人体等

比如你有某家风水/中医的九宫五行说法：

```jsonc
{
  "subject": "palace:1",
  "predicate": "corresponds_to.element",
  "object": "element:water",
  "theory": "jiugong.wuxing.scheme1"
}
```

八卦：

```jsonc
{
  "subject": "palace:1",
  "predicate": "corresponds_to.trigram",
  "object": "trigram:kan",
  "theory": "jiugong.bagua.scheme1"
}
```

人体（比如某体系认为九宫对应身体部位）：

```jsonc
{
  "subject": "palace:1",
  "predicate": "corresponds_to.organ",
  "object": "organ:kidney",
  "theory": "fengshui.body_mapping.scheme1"
}
```

方向：

```jsonc
{
  "subject": "palace:1",
  "predicate": "corresponds_to.direction",
  "object": "direction:N",
  "theory": "jiugong.direction.standard"
}
```

> 所有叠加层，本质上都是 “palace:x 和某个 Node 之间的一条 Statement”。

---

### 3. 真正“画九宫图时”的读取逻辑

当你要在界面上画一个九宫图，并叠加指定内容时，可以做这样一个“视图配置”：

```jsonc
{
  "view": "jiugong_overlay",
  "theory_filters": {
    "number": "lo_shu.jiugong.standard",
    "element": "jiugong.wuxing.scheme1",
    "trigram": "jiugong.bagua.scheme1",
    "organ": "fengshui.body_mapping.scheme1",
    "direction": "jiugong.direction.standard"
  },
  "predicates": {
    "number": "has_number",
    "element": "corresponds_to.element",
    "trigram": "corresponds_to.trigram",
    "organ": "corresponds_to.organ",
    "direction": "corresponds_to.direction"
  }
}
```

然后对于每一个宫 `palace:i`，做同样的图查询（伪代码）：

```text
for palace in [palace:1..9]:
  number   = 查找 Statement where subject=palace AND predicate=has_number            AND theory=lo_shu.jiugong.standard
  element  = 查找 Statement where subject=palace AND predicate=corresponds_to.element AND theory=jiugong.wuxing.scheme1
  trigram  = 查找 Statement where subject=palace AND predicate=corresponds_to.trigram AND theory=jiugong.bagua.scheme1
  organ    = 查找 Statement where subject=palace AND predicate=corresponds_to.organ   AND theory=fengshui.body_mapping.scheme1
  direction= 查找 Statement where subject=palace AND predicate=corresponds_to.direction AND theory=jiugong.direction.standard

  组装成一个结构交给前端：
  {
    palace_id: "palace:1",
    number: ...,
    element: ...,
    trigram: ...,
    organ: ...,
    direction: ...
  }
```

**这样你就能做到：**

- 换一套五行说法，只要把 `theory_filters.element` 换掉；
- 换一套八卦九宫排法，只换 `theory_filters.trigram`；
- 中医系统、风水系统甚至命理系统，都可以在同一个九宫底板上叠加不同“图层”。

本质上就是：**底板是固定 Node（palace），叠加的全是 Statement + Theory 的组合**。

---

## 四、Mapping 在这套体系里的位置

在这套设计里，你最开始的 Mapping 设计就有了一个很清晰的位置：

- **底层：Graph = Node + Statement + Theory**
- **上层：Mapping = 针对某一类问题的“预计算视图”**

例如你经常要查：

> “给我一个字，告诉我它的五行”

那你可以在 graph 上跑一遍，生成一个简化的 Mapping 文件：

```jsonc
{
  "_meta": {
    "theme": "char.element",
    "theory": "wuxing.main"
  },
  "mapping": {
    "char:甲": "element:wood",
    "char:乙": "element:wood",
    "char:丙": "element:fire"
  }
}
```

这个 Mapping 就是一个**缓存 + 快捷表**：

- 读的时候：O(1) hash 查询，非常快；
- 改理论的时候：
  - 不用“现场改 Mapping 文件”
  - 只是在图里新增/修改 Statement
  - 然后重新生成 Mapping

**所以你完全可以：**

> “以图结构为真相，以 Mapping 为快照。”

---

## 五、回到你的两个核心诉求

### 1. 「看医书看理论时，方便加入」

用上面的 **Node + Statement + Theory**：

- 看书时，只要认得出“名词”和“关系”，就能往里塞；
- 系统是 **append-only 的**（几乎不用删改旧数据）；
- 不同家说法不会互相打架，各自挂在各自的 `theory` 下。

### 2. 「像九宫图那样叠加各种关系来读」

- 九宫底板是 Node 系列（`palace`）
- 每一个“叠加层”是：
  - 一组 `subject=palace:x` 的 Statement
  - 搭配一个 `theory` 过滤
- UI 每次渲染，就是从图里按你选的理论组合，把相关 Statement 拉出来叠在底板上。

---

## 六、最后小结一下

- 你直觉中“这玩意只有图结构才搞得定”，**方向是对的**；
- 真正关键的是：
  - **所有事物都是 Node（词汇层）**
  - **所有知识都是 Statement（关系 + 上下文）**
  - **所有体系/流派都是 Theory（给 Statement 分组与过滤）**

在这个基础上：

- **增量录入**：不断加新的 Statement 就好；
- **多维叠加查询（九宫、河图洛书、人体对应等）**：
  本质是从图里挑选对应 Node + Statement，按不同理论组合在一起渲染。

如果你愿意，下一步我可以帮你：

- 选一种你最熟的“小系统”（比如“中医五脏 + 五行 + 方位 + 季节”），
- 写一份**完整的 JSON 数据示例 + 查询伪代码**，
- 让你一眼就能看出“实战代码里会长什么样”。

-----

> 看了你的讲解，我有几个想法。
> 我们现在的做法，像是在手动实现图数据库的节点和关系录入，并自己实现图查询语言。这种做法，比直接用图数据库有什么优势？（最大的优势是轻量级，因为不用再装一个数据库并开启服务）
> 此外，这个过程，你说的每一个输入模板，如果直接输入会不大方便，是否可以做一个界面，前端固定一些输入项，后端用程序识别并建立对应的文件（组）？
> 如果不考虑轻量级的问题，我们上述的方案和直接用图数据库相比，究竟哪个更有优势呢？

先直接捅穿一点：

**是的，我们现在做的，就是在自己实现一个“小号图数据库 + 自己的图查询语言”。**
但这个“小号”如果用得好，其实有它很大的价值，尤其是在你这种“边读经典边积累知识”的场景里。

我分三块聊：

1. 自己用文件实现图结构 vs 直接上图数据库：到底差在哪儿？
2. 能不能做个录入界面，自动生成 Node / Statement 文件？
3. 如果不考虑轻量级，只谈“长期整体优势”，该选谁？

---

## 1. 手工图结构 vs 图数据库：我们到底多做了/少做了什么？

### 我们现在的方案，本质是这样：

- **概念模型**：Node / Statement / Theory（这其实已经是个“小本体 + 知识图谱”的设计）
- **存储**：用 JSON/YAML 文件
- **查询**：自己写一些函数，比如：
  - `find_statements(subject=?, predicate=?, theory=?)`
  - `expand(node, depth=1..2, filters=...)`
  - `get_palace_overlay(theory_config)` 等「业务查询」

你说的非常对：**这就是在手工实现一个很小但定制的图系统**。

### 相比真正的图数据库（Neo4j、JanusGraph 之类），我们：

**少了这些东西：**

1. **现成的图查询语言**（Cypher / Gremlin / SPARQL 等）
2. **高性能索引和存储引擎**（百万节点、复杂多跳查询时的性能）
3. **并发 / 事务 / 锁 / 多人同时写入控制**
4. **一整套图算法工具箱**（最短路径、社群发现、中心性分析等）

**多了这些好处：**

1. ### 透明 & 可读 & 可 Git 管理

   - 所有知识就是一堆文件，**肉眼能看**。
   - 你可以：
     - 用 git 管理版本；
     - 看 diff 知道“这段时间我给‘肝’增加了哪些对应关系”；
     - 在编辑器里全局搜索某个 Node ID 看它在哪些地方被用到。
   - 对于「研究型」项目（尤其是你这种山医命相卜综合工程），这点非常重要：
     它更像“知识笔记 + 数据”而不是“黑盒数据库”。

2. ### 不被某个数据库的 schema / 语法锁死

   - 我们的 Node / Statement / Theory 是**概念模型**，跟底层技术无关。
   - 以后你要：
     - 换图数据库（从 Neo4j 换成别的）；
     - 或者干脆换成 document DB / SQL；
     - 或者做本地离线小工具；
   - 都可以只写一个“小适配器”，把这个抽象模型映射到底层。

   简单说：
   > 现在你在设计的是“玄学知识本体”，而不是“Neo4j 专用 schema”。

3. ### 完全离线、零运维、极简依赖

   - 不用装服务器，不用跑 Docker，不用写运维脚本；
   - 就是“一个目录 + 一些 JSON / YAML + 一个查询脚本”；
   - 对一个人/少数人长期维护的个人体系，这个极简性是很宝贵的。

4. ### 特别适合“理论经常重构”的早期阶段

   你现在还在摸索最舒服的：
   - Node 类型怎么分？
   - predicate 要长什么样？
   - Theory 如何拆？

   这个阶段，你其实经常需要“砸了重来”、“批量重命名 id”、“把两类 Node 合并”等等。
   用文件 + 脚本做这事，非常爽：
   - 用脚本处理文件；
   - 可控、可回滚。
   在图数据库里做 schema 大重构，会很“笨重”。

---

## 2. 是否可以做一个录入界面，让你只管填内容？

完全可以，而且我强烈推荐你这么做。
不然直接写 JSON 模板确实太痛苦了。

### 一个最小可用的录入界面可以长这样：

#### 1）选择/创建 Theory

- 左侧：一个下拉框或树状列表：
  - `tcm.zangxiang.classic`
  - `bagua.direction.houtian`
  - `lo_shu.jiugong.standard` …
- 支持“新建 theory”：输入 id、名称、简短说明。

录入时，你先选当前是在“哪套理论语境”下做记录。

#### 2）Node 选择/创建区

中间表单里：

- Subject：一个搜索框（模糊搜索 Node 名称 / 拼音 / id），选中后显示 `id` 和类型。
  - 没有就提示“创建 Node”→弹出小窗：
    - 名称（中文）
    - 类型（五行/五脏/卦/方位/节气/数/宫位…下拉框）
    - 其他可选信息（备注）
- Predicate：从预定义列表里选：
  - `corresponds_to.element`
  - `corresponds_to.trigram`
  - `corresponds_to.direction`
  - `has_number`
  - `dominates.organ` …
- Object：和 Subject 一样，用 Node 搜索/创建。

#### 3）Source / 注释区

- 文本框：原文抄录或页码；
- 简短备注：你当时怎么理解这条对应关系；
- 置信度/标记：比如“待考证”“异说”等。

#### 4）一键生成多条 Statement（批量模式）

因为你经常遇到的是这种句子：

> 肝应震卦，东方，春天，属木，通于目。

可以做一个“批量录入”模式：

- 左边一次选中 `organ:liver`
- 中间用几个输入框：
  - 卦象：选 `trigram:zhen`
  - 方位：选 `direction:E`
  - 季节：选 `season:spring`
  - 五行：选 `element:wood`
  - 官窍：选 `sense:eye`
- 然后点“生成”，后端自动拆成 5 条 Statement 写入文件。

这样你每看一段经典，就像填表一样录入，**不需要自己手写 JSON**。

---

### 后端要做什么？

一个简单的服务就够了（哪怕本地跑个脚本）：

1. 收到前端发来的内容：
   - theory id
   - subject / predicate / object（或一次一串）
   - source / note
2. 检查 Node 是否存在：
   - 不在就创建对应 Node 文件/记录。
3. 创建 Statement 记录：
   - 自动生成 id（比如 `stmt:20251128_xxx`）
   - 写入到某个文件：
     - 比如按 theory 分文件：`data/tcm.zangxiang.classic/statements.jsonl`
     - 或者按类型分：`statements/organ/xxx.jsonl`
4. 可选：更新一些“索引文件”或“缓存 mapping”，提高查询速度。

**对你来说：**
- 你只面对一个简单 GUI；
- 背后所有 Node/Statement 文件、id 命名、字段规范都由程序统一处理。

这其实就把你的“知识图谱录入”变成了一个**专用笔记软件**。

---

## 3. 不考虑轻量级，只跟图数据库正面比：谁更有优势？

我们可以从几个维度看：

### 3.1 规模 & 性能

- 如果以后你真的有 **百万级 Node + 数百万条对应关系**：
  - 复杂多跳查询（例如“从某 hexagram 出发，找与之同元素、且在某 theory 下共现的 organ 列表”）会越来越慢；
  - 这时图数据库天然有优势：有索引和优化。
- 但在“个人项目 + 中小数据量”的阶段（比如几万 Node / 几十万 Statement），
  一个做得不错的“内存索引 + 文件存储”的方案，**完全够用**。

### 3.2 查询复杂度 & 灵活性

- 图数据库的 **Cypher/Gremlin** 可以写非常复杂的模式匹配查询：
  - “找所有同时满足 A、B、C 条件的节点子图”
  - “找沿着某类边走 3~5 步能到达的所有节点”
- 你现在的需求，绝大多数是：
  - 给我这个 Node，它的这些关系（五行、卦、方位…）；
  - 以某个 Node 为中心单/双跳扩展；
  - 过滤理论（theory）不同组合。
- 这种**业务很集中**的情况，其实可以靠一小套“专用查询函数”来搞定，不需要一个通用图查询语言。

换句话说：

> 你不一定需要一个“通用图数据库”，你更像需要一个“玄学知识的专用引擎”。

### 3.3 数据演化 & 知识重构

- 早期：理论常常会重构、推翻、调整分类。
- 文件 + 自己的抽象模型 → **改 schema 成本很低**。
- 图数据库虽然也能改 schema，但：
  - 心理负担更重（担心搞坏库）；
  - 工具/迁移脚本更复杂。

对你这种“边研究边沉淀”的项目，我会更看重**可重构性 + 可读性**，而不是“工业级性能”。

### 3.4 工具生态 & 分析能力

图数据库的优势：

- 想做复杂的网络分析、可视化、路径算法时，有大量现成工具；
- 可以接入图算法库做“谁是核心节点”“哪种对应在网络中最关键”之类的分析。

但你完全可以以后：

- 把现在这套 Node/Statement/Theory 导出成一个 `.csv / .graphml`；
- 再导入某个图数据库/图分析工具做一次性分析。

也就是说：**分析可以“借用”图数据库，不一定要把线上主存储变成图数据库。**

---

## 4. 实际上可以采取的折中策略（也是我推荐的）

我会这样建议你：

### 阶段 1：坚持用“文件 + 自己的抽象模型”打底

- 把 **Node / Statement / Theory 三层模型做扎实**；
- 做一个好用的录入界面（你只管填理论内容）；
- 用脚本实现你目前真正需要的查询（九宫图叠加、五脏五行方位等）。

这一步做好的收获是：

1. 你会有一套 **完全独立于任何数据库产品的“玄学知识本体”**；
2. 你很清楚地知道：自己常用的查询到底是哪几类，这对将来是否值得迁移到图数据库非常关键。

### 阶段 2：当数据/需求长到一定程度，再挂一个“图数据库适配器”

也就是：

- 抽象一层接口，比如：

  ```python
  # 存储/查询接口（与底层无关）
  get_node(id)
  find_statements(subject=None, predicate=None, object=None, theory=None)
  expand(node_id, depth=1, filters={...})
  ```

- 现在实现的是 `FileBackend`：
  - 文件读入 → 内存里建索引 → 提供这些函数。
- 将来如果需要：
  - 再写一个 `GraphDBBackend`，内部用 Neo4j 或其他图 DB 实现；
  - 你的上层代码（前端 UI、九宫渲染等）不需要改。

这样一来：

- 你不会过早被任何 DB 绑死；
- 又保留了未来把整个东西“插到图数据库上”的可能性。

---

## 总结一句话版

- **现在的方案确实是在“自己做一个小图数据库”，但这是件有价值的事**，因为你是在为「道家玄学知识」打造一个专门的、可读、可重构的图模型。
- 完全可以做一个友好的录入界面，让你只负责选“肝 / 震卦 / 东方 / 春 / 木”，后端自动转换为 Node + Statement 文件。
- 如果不考虑轻量级：
  - 在**研究、整理、经常重构**阶段：文件 + 自建抽象层更有优势；
  - 在**大规模数据 + 复杂分析 + 多用户在线**阶段：专业图数据库更强。
- 最实用的路子：
  - 先把概念模型 + 文件系统搞扎实；
  - 等你数据和需求都清晰了，再考虑“挂一个图数据库适配器”。

如果你愿意，下一步我可以帮你：
**画一个简单的前端录入界面结构 + 后端文件组织示例**（比如实际的目录树长啥样，每个 theory 一个文件如何拆分），你直接拿去作为将来实现的草图。

-----

> 分析得很好，我完全同意你的方案，我们还是自己做，不用现有的图数据库。你说的对，要用最方便建立并维护一套玄学知识本体的方式，这个知识本体才是最重要的，一切后续功能的核心都是这个知识本体。
> 那我们回到原来的开发进度，下一步该做什么呢？我认为先不实现前端录入界面，还是先专注于后端数据组织形式，这才是根本，录入界面等所有功能都稳定后再设计也不迟。

好，现在正式轮到“插件式 Mapping 的通用 Schema”这块地基了 😊
你刚刚说的那两点，其实已经很接近一个成熟的本体设计思想了：

- Core 文件只管“谁是谁”（卦的身份证）
- 其他所有“解释”和“用途”都做成**插件文件**，各自挂在 core 上

下面我先把目标说清楚，再给一个我建议采用的通用 Schema，最后说说要注意的坑和下一小步怎么走。

---

## 1. 我们希望插件式 Mapping 文件解决什么问题？

一句话：

> “给一批对象（卦、爻、时间点……）挂上一类语义信息，而且**每一类语义**单独一个文件，方便增删改。”

典型例子：

- `direction.xiantian.trigram.json`
  → 先天八卦：八卦 ↔ 方位

- `direction.houtian.trigram.json`
  → 后天八卦：八卦 ↔ 方位（另一种说法）

- `wuxing.trigram.main.json`
  → 八卦 ↔ 五行（主流版）

- `family.trigram.json`
  → 八卦 ↔ 父母子女（先天“家人”关系）

- `kingwen.hexagram.json`
  → 六十四卦 ↔ 文王卦序号

特点：

- 每个文件只负责**一类关系/属性**（易维护、易替换）
- 全部都用 core 里定义的 **ID 作为“挂钩”**（统一入口）
- 字段名**只在文件里定义**，Python 这边不事先写死（避免你说的“双写不同步”问题）

---

## 2. 先统一一个“全局 ID 格式”

我们之前已经聊过，这一步很关键：

> 不同类型的对象共存时，用字符串前缀区分命名空间。

建议格式：

```text
<traget_type>:<id_or_name>
```

常见几类：

- 卦：
  - `trigram:0`  —— 三爻卦，id = bits（0..7）
  - `hexagram:23` —— 六爻卦，id = bits（0..63）

- 五行：
  - `element:wood` / `element:fire` / `element:earth` / `element:metal` / `element:water`

- 方位：
  - `direction:N` / `direction:NE` / ...

- 家人：
  - `family:father` / `family:mother` / `family:eldest_son` / ...

这样无论是在 mapping 文件还是未来的图里，看到 `"hexagram:23"` 一眼就知道是谁；mapping loader 也可以轻松做检查。

---

## 3. 一个插件 Mapping 文件的大体形状

我建议的**通用 Schema**：

```json
{
  "_meta": {
    "school": "xiantian",
    "version": "1.0.0",
    "source": "先天八卦说",
    "last_updated": "2025-11-28",
    "notes": "八卦与方位的对应关系，仅为先天一说。"
  },
  "domain": "trigram",
  "kind": "direction",
  "mapping": {
    "trigram:0": {
      "direction": "N"
    },
    "trigram:1": {
      "direction": "SW"
    }
  }
}
```

拆开来看：

### 3.1 `_meta`：沿用 MetaVersionInfo

- `school`：这个插件属于哪个体系/流派，例如 `"xiantian"`, `"houtian"`, `"main"`, `"wenwang"`…
- `version`：版本号
- `source`：整理来源
- `last_updated`：日期
- `notes`：备注

我们直接复用 `MetaVersionInfo`，不用再造一套。

### 3.2 `domain` & `kind`：告诉插件“在干什么”

- `domain`：**作用对象的类型**，例如 `"trigram"`, `"hexagram"`, `"yao"`, `"time"`, `"direction"`…
  表示“这份 mapping 的 key 主语是谁”。

- `kind`：这份 mapping 的“主题/功能名”，例如：
  - `"direction"`：方位
  - `"wuxing"`：五行
  - `"family"`：家人关系
  - `"kingwen_order"`：文王卦序
  - `"pinyin"`：拼音（你也可以做个多语言名插件）

这两个字段不参与计算，但：

- 方便你之后在代码里“按类别加载”
- 方便你自己整理文件时看一眼就知道这是干嘛的

### 3.3 `mapping`：真正的内容（ID → 自由结构的 data）

- key：统一用全局 ID 字符串，比如 `"trigram:0"`, `"hexagram:23"`
  loader 会做两件事：
  - 确认前缀（比如 `trigram`）和 `domain` 一致
  - 把后面的数字部分解析为 int id，用于快速索引 core names

- value：**完全由该插件自己决定的字段结构**
  比如：

  - 五行插件：

    ```json
    "trigram:0": { "element": "metal" }
    ```

  - 方位插件：

    ```json
    "trigram:0": { "direction": "N" }
    ```

  - 家人插件：

    ```json
    "trigram:0": { "family": "father" }
    ```

  - 甚至可以复杂一点（有多个字段）：

    ```json
    "hexagram:23": {
      "element": "earth",
      "direction": "SW",
      "tags": ["yielding", "receptive"]
    }
    ```

**重点**：这些字段名（`element`, `direction`, `family`, `tags`…）**完全不在 Python 代码里写死**，
正好对应你说的：

> “除了基础文件中的数据（如卦名等），其他字段名只在数据文件中指定，程序读取时，从数据文件中读取，并不预先设定。”

我们在代码里只把它当作 `dict[str, Any]` 来看，插件的格式由你在 README / 注释里描述清楚即可。

---

## 4. Python 这边的承载结构（类型只管“外壳”）

我们可以准备一个很薄的 dataclass，只描述“外壳”：

```python
from dataclasses import dataclass
from typing import Dict, Any
from .metadata_core_types import MetaVersionInfo

@dataclass
class MappingFile:
    meta: MetaVersionInfo          # 来自 _meta
    domain: str                    # "trigram" / "hexagram" / ...
    kind: str                      # "direction" / "wuxing" / ...
    mapping: Dict[str, Dict[str, Any]]
    # 例如:
    #   mapping["trigram:0"] = {"direction": "N"}
```

loader 的责任：

- 读 JSON
- 验证 `_meta`、`domain`、`kind` 顶层字段存在
- `mapping` 是一个对象
- key 形如 `"something:xxx"`，且前缀必须与 `domain` 一致
  （比如 `domain="trigram"` 时，key 必须形如 `trigram:0`）
- value 是一个对象（dict），内部字段不做检查（留给使用方）

这样：

- **新增一类插件文件，不需要改任何 dataclass**
- 只需要新建 JSON + 文档，就能加入一套新的理论映射

---

## 5. Mapping 文件和未来“图结构（L1.C）”的关系怎么处理？

你刚才也提到“知识本体是核心”，我建议这样理解两者关系：

- **Mapping 文件（L1.B2）**：
  - 更像“配置表”或“局部视图”：
    - 某一类对象 + 某一类属性/关系
  - 手工维护方便（你可以直接编辑 JSON）
  - 对你来讲“是写书/整理笔记时使用的格式”

- **图结构（L1.C）**：
  - 是整个知识本体的**统一视图**：
    - 所有 trigram/hexagram/element/direction/family/节气……都是 Node
    - 所有“对应”“属”“生”“克”“位于”等都是 Edge
  - 运行时可以把多个 mapping 文件“编译成”图中的若干条边
    - 比如：
      - `direction.trigram.xiantian.json` → `trigram:X --[DIRECTION_XIANTIAN]--> direction:N`
      - `wuxing.trigram.main.json` → `trigram:X --[ELEMENT_MAIN]--> element:wood`

这样我们就有一个非常干净的分层：

- 数据录入/维护：侧重 Mapping 文件（按理论/维度分文件）
- 运行时推演/查询：使用图结构（统一语义网络）

**你现在专注的“后端数据组织形式”，可以完全先在 Mapping 文件层搞定，
图结构层再用一个工具函数把这些 Mapping 转成 Graph 就行。**

---

## 6. 还有两个小细节，提前说清楚

### 6.1 冲突与优先级

将来你可能会有这种情况：

- `wuxing.trigram.main.json`：某卦五行 = 木
- `wuxing.trigram.alt.json`：某卦五行 = 火土（另一派）

这种情况就不用在一个文件里解决冲突：

- 每个文件在 `_meta.school` 里写清楚来源/派别
- 运行时你选择**加载哪一批文件**，就是选择当前“知识视角”

比如：

```python
load_mapping_files(school="main")      # 只用主流版
load_mapping_files(school in ["main", "alt"])  # 两个视角都加载
```

### 6.2 条件型关系怎么办（比如“逢甲日则…”）

这类涉及“时间/上下文”的关系就不适合放在简单 mapping 文件里了：

- 例如：某卦在某个日干下的纳甲
- 某个节气前后取不同卦气

这部分更适合：

- 放到 L1.C 图 + L2 规则引擎里
- 或者用一个更复杂的“规则文件”（比如自定义 DSL/表达式）

**Mapping 文件先只负责“静态、单维”的对应关系**，
动态、有条件的我们留到后面专门设计。

---

## 7. 下一小步的计划

如果你觉得这个 Schema 合你意，我们下一步可以做一个非常小的实践：

1. 在 `dao/` 里新建 `mapping_types.py`：
   - 定义 `MappingFile` dataclass（外壳结构）
2. 在 `dao/` 里新建 `mapping_loader.py`：
   - 定义 `load_mapping(path) -> MappingFile`
   - 和 core loader 类似，只检查外壳 + ID 格式
3. 在 `data/mapping/` 下建两个极简示例文件：
   - `direction.trigram.xiantian.v1.json`（随便填 2 个八卦的方位）
   - `wuxing.trigram.main.v1.json`（随便填 2 个八卦的五行）
4. 写 `tests/test_mapping_loader.py`：
   - 验证能正常加载 + 做 ID 前缀/越界之类的错误测试

等这一块通过，我们整个**数据层的骨架**就非常清楚了：

- L1.Core：bits & GuaCore ✅
- L1.B1：卦名 Core + loader ✅
- L1.B2：插件式 Mapping + loader ✅
- L1.C：图结构（下一步再设计 schema）

---

你先看看这个 Mapping 通用 Schema 有没有哪里让你觉得“不顺手”或“未来可能后悔”的地方，如果整体思路 OK，我们就按这个设计先落一个 `mapping_types.py + mapping_loader.py + 示例 JSON + 测试` 的小块下来。

-----

> 很好，就按你的方案进行下一步。不过，示例文件请直接把八个卦的内容都写全，方便测试。

太棒了，那我们来把“插件式 Mapping 的通用 Schema + 实现 + 示例文件（含 8 卦全量）”这一块落地。

接下来这一步我们做 3 件事：

1. 设计通用 Mapping 的 schema & Python 类型
2. 写 `load_mapping` 的 loader
3. 给出两个完整的 trigram 示例文件（方向 + 五行，8 卦全都有），并配测试

---

## 1. 通用 Mapping Schema 设计

我们统一用“**命名空间前缀 + 自由字段**”的形式。

### 1.1 文件结构（JSON）

约定一个插件式 mapping 文件长这样：

```json
{
  "_meta": {
    "school": "xiantian",
    "version": "1.0.0",
    "source": "示例：八卦方位（先天）",
    "last_updated": "2025-11-28",
    "notes": "示例数据，不代表任何特定学派的定稿。"
  },
  "domain": "trigram",
  "kind": "direction.xiantian",
  "mapping": {
    "trigram:0": { "direction": "N" },
    "trigram:1": { "direction": "NE" },
    "...":       { "direction": "..." }
  }
}
```

关键点：

- `_meta`：沿用你已有的 `MetaVersionInfo`，只管版本/来源/学派等。
- `domain`：说明这份文件作用在哪类对象上（比如 `"trigram"`、`"hexagram"`、以后可能有 `"yao"` 等）。
- `kind`：这是什么类型的语义映射，比如：
  - `"direction.xiantian"`：先天八卦方位
  - `"direction.houtian"`：后天八卦方位
  - `"wuxing.main"`：主流五行归属
  - `"family.trigram"`：八卦家人关系
- `mapping`：真正的映射表：
  - key：统一规范为 `"domain:id"`，比如 `"trigram:0"`、`"hexagram:23"`
  - value：**任意字段字典**，由数据文件自己定义，不在 Python 里写死

### 1.2 ID 范围约定（简单校验）

为了防止填错，我们在 loader 里做一点轻量校验：

- 如果 `domain == "trigram"`：
  - suffix 必须能转成 int，且 `0 <= id <= 7`
- 如果 `domain == "hexagram"`：
  - suffix 必须能转成 int，且 `0 <= id <= 63`
- 其他 domain（比如以后扩展）就只检查前缀，不强行校验 id

---

## 2. Python 类型：`dao/mapping_types.py`

新建文件：`dao/mapping_types.py`：

```python
"""
mapping_types.py

L1.B2：插件式语义 Mapping 的通用类型定义。

设计目标
--------
1. 为「任意学派 / 任意语义」的映射文件提供统一外壳结构：
   - 元信息（MetaVersionInfo）
   - 作用域（domain）
   - 语义种类（kind）
   - 映射表（mapping: key -> 任意字段）

2. 不预先约束 mapping 里的字段名：
   - direction / element / family / ... 全部由数据文件自己定义
   - Python 里仅用 dict[str, Any] 承载，避免 schema 双写问题

典型 JSON 结构
--------------
{
  "_meta": { ... MetaVersionInfo ... },
  "domain": "trigram",
  "kind": "direction.xiantian",
  "mapping": {
    "trigram:0": { "direction": "N" },
    "trigram:1": { "direction": "NE" },
    ...
  }
}
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict

from .metadata_core_types import MetaVersionInfo


@dataclass
class MappingBundle:
    """
    一份插件式语义 mapping 文件在内存中的承载结构。

    字段说明
    --------
    meta : MetaVersionInfo
        文件的版本/学派/来源等信息。

    domain : str
        作用域，如 "trigram"、"hexagram"、"yao" 等。

    kind : str
        映射的语义种类，如 "direction.xiantian"、"wuxing.main" 等。
        建议采用「类别.子类」的形式，便于分类管理。

    mapping : Dict[str, Dict[str, Any]]
        具体映射表：
        - key: 统一格式 "domain:id"，例如 "trigram:0"、"hexagram:23"
        - value: 任意字段字典，由数据文件自行定义。
          例如：{ "direction": "N" } 或 { "element": "金", "extra": "xxx" }
    """

    meta: MetaVersionInfo
    domain: str
    kind: str
    mapping: Dict[str, Dict[str, Any]]

    def get(self, key: str) -> Dict[str, Any] | None:
        """按完整 key（如 'trigram:0'）获取映射数据。"""
        return self.mapping.get(key)

    def key_for(self, obj_id: int) -> str:
        """辅助方法：根据 id 构造标准 key，例如 'trigram:0'。"""
        return f"{self.domain}:{obj_id}"
```

---

## 3. Loader 实现：`dao/mapping_loader.py`

新建：`dao/mapping_loader.py`：

```python
"""
mapping_loader.py

L1.B2：插件式 Mapping 文件加载器。

职责
----
- 从 JSON 文件中加载 MappingBundle：
  - 解析 _meta -> MetaVersionInfo
  - 解析 domain / kind
  - 解析 mapping，做基础校验：
      * key 前缀为 "{domain}:"
      * 若 domain 为 trigram/hexagram，则校验 id 范围

注意
----
- 不关心 mapping 内部字段具体含义，只保证结构合法。
- 语义解释（比如把 "direction" 映射为方位）由更高层处理。
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict

from .metadata_core_types import MetaVersionInfo
from .mapping_types import MappingBundle


def _load_json(path: Path) -> Dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"Mapping file not found: {path}")

    text = path.read_text(encoding="utf-8")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse JSON from {path}: {e}") from e

    if not isinstance(data, dict):
        raise ValueError(f"Top-level JSON must be an object in {path}")
    return data


def _parse_meta(meta_dict: Dict[str, Any]) -> MetaVersionInfo:
    try:
        school = meta_dict["school"]
        version = meta_dict["version"]
        source = meta_dict["source"]
        last_updated = meta_dict["last_updated"]
        notes = meta_dict.get("notes")
    except KeyError as e:
        raise ValueError(f"Missing required meta field: {e!r}") from e

    return MetaVersionInfo(
        school=school,
        version=version,
        source=source,
        last_updated=last_updated,
        notes=notes,
    )


def _validate_key_for_domain(domain: str, key: str) -> None:
    """
    校验 mapping 的 key 与 domain 是否匹配，并在部分 domain 上做 id 范围检查。

    规则：
    - key 必须以 "{domain}:" 开头
    - 若 domain == "trigram":
        id 必须是 0..7 的整数
    - 若 domain == "hexagram":
        id 必须是 0..63 的整数
    """
    prefix = f"{domain}:"
    if not key.startswith(prefix):
        raise ValueError(f"mapping key {key!r} must start with {prefix!r}")

    suffix = key[len(prefix):]

    if domain == "trigram":
        try:
            v = int(suffix)
        except ValueError as e:
            raise ValueError(f"trigram mapping key must end with int id, got {key!r}") from e
        if not (0 <= v <= 7):
            raise ValueError(f"trigram id out of range in key {key!r}: {v}")

    elif domain == "hexagram":
        try:
            v = int(suffix)
        except ValueError as e:
            raise ValueError(f"hexagram mapping key must end with int id, got {key!r}") from e
        if not (0 <= v <= 63):
            raise ValueError(f"hexagram id out of range in key {key!r}: {v}")

    # 其他 domain 暂不做 id 范围检查


def load_mapping(path: str | Path) -> MappingBundle:
    """
    从 JSON 文件加载插件式语义 Mapping。

    参数
    ----
    path : str | Path
        映射文件路径。

    返回
    ----
    MappingBundle
    """
    p = Path(path)
    data = _load_json(p)

    # meta
    meta_dict = data.get("_meta")
    if not isinstance(meta_dict, dict):
        raise ValueError(f"Mapping file {p} must contain a '_meta' object")
    meta = _parse_meta(meta_dict)

    # domain
    domain = data.get("domain")
    if not isinstance(domain, str) or not domain:
        raise ValueError(f"'domain' must be a non-empty string in {p}")

    # kind
    kind = data.get("kind")
    if not isinstance(kind, str) or not kind:
        raise ValueError(f"'kind' must be a non-empty string in {p}")

    # mapping
    mapping_raw = data.get("mapping")
    if not isinstance(mapping_raw, dict):
        raise ValueError(f"'mapping' must be an object in {p}")

    mapping: Dict[str, Dict[str, Any]] = {}
    for key, value in mapping_raw.items():
        if not isinstance(key, str):
            raise ValueError(f"mapping key must be string, got {key!r}")
        if not isinstance(value, dict):
            raise ValueError(f"mapping[{key!r}] must be an object")

        _validate_key_for_domain(domain, key)
        mapping[key] = value

    return MappingBundle(
        meta=meta,
        domain=domain,
        kind=kind,
        mapping=mapping,
    )
```

---

## 4. 示例文件：两个完整的八卦 Mapping（全部 8 卦）

新建目录：`data/mappings/`

```bash
mkdir -p data/mappings
```

### 4.1 八卦方位（示例版）：`data/mappings/trigram_direction_xiantian.v1.json`

> 说明：这些方位只是**示例**，方便测试和结构演示，不代表你最终要采用的学派。
> 你以后可以随时改成自己认可的先天/后天方位体系。

```json
{
  "_meta": {
    "school": "example",
    "version": "1.0.0",
    "source": "示例：八卦方位，仅用于结构和测试",
    "last_updated": "2025-11-28",
    "notes": "方位仅为占位示例，后续可按任意学派重新定义。"
  },
  "domain": "trigram",
  "kind": "direction.example",
  "mapping": {
    "trigram:0": { "direction": "N" },
    "trigram:1": { "direction": "NE" },
    "trigram:2": { "direction": "E" },
    "trigram:3": { "direction": "SE" },
    "trigram:4": { "direction": "S" },
    "trigram:5": { "direction": "SW" },
    "trigram:6": { "direction": "W" },
    "trigram:7": { "direction": "NW" }
  }
}
```

8 个卦（id 0–7）都有映射，方便测试。

> 将来如果你决定：
> - `id=0` 对应乾
> - 或者 `id=0` 对应坤
> 都没关系，只要 **core_trigrams 文件里的名字** 和 **你心里的编码方案** 对得上，
> 这里 `direction` 只是“id 上的标签”。

---

### 4.2 八卦五行（示例版）：`data/mappings/trigram_wuxing_main.v1.json`

这里给一个比较常见的八卦五行归属（乾兑金、离火、震巽木、坎水、艮坤土）
但同样，**这里只是示例**，你完全可以用自己的版本替换。

```json
{
  "_meta": {
    "school": "example",
    "version": "1.0.0",
    "source": "示例：八卦五行，仅用于结构和测试",
    "last_updated": "2025-11-28",
    "notes": "五行归属仅为占位示例，后续可按任意体系调整。"
  },
  "domain": "trigram",
  "kind": "wuxing.main",
  "mapping": {
    "trigram:0": { "element": "金" },
    "trigram:1": { "element": "金" },
    "trigram:2": { "element": "火" },
    "trigram:3": { "element": "木" },
    "trigram:4": { "element": "木" },
    "trigram:5": { "element": "水" },
    "trigram:6": { "element": "土" },
    "trigram:7": { "element": "土" }
  }
}
```

再次强调：
- **id→卦名→五行的具体关系，关键在你自己的 core_trigrams 设计**。
- 这里只是“8 行结构 + 每个 id 有一条记录”的完整示例，便于测试。

---

## 5. 测试：`tests/test_mapping_loader.py`

新建文件：`tests/test_mapping_loader.py`：

```python
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
```

---

## 6. 接下来你可以这样做

1. 把 `dao/mapping_types.py` 和 `dao/mapping_loader.py` 加进项目。
2. 新建 `data/mappings/` 目录，放入两个 JSON 文件（方位 + 五行）。
3. 新建 `tests/test_mapping_loader.py`。
4. 在项目根目录运行：

   ```bash
   python -m pytest
   ```

如果所有测试（core / ops_basic / metadata_core_loader / mapping_loader）都通过，那我们当前的 L1/L2 框架就非常稳了：

- L1.Core：卦的 bits 本体 ✅
- L1.B1：卦的“身份证”（名字） + loader ✅
- L1.B2：插件式语义 Mapping Schema + loader ✅
- L2.a：基础 bit-level 运算（上下卦拆/合 + flip_yao） ✅

下一步，我们就可以开始考虑 **L1.C 关系图（Graph）** 的 schema——也就是把这些 trigram / hexagram / 五行 / 方位 / 节气 作为节点，Mapping 文件可以看作“节点属性或边的输入”，再统一组合成一个小小的知识图谱内存结构。

-----

> 很好，测试通过了。对下一步的关系图我还不大了解，请你详细给我讲讲你的方案

核心思路先说一句：**关系图 = 把“所有卦象、五行、方位、时间、身体部位……这些东西都变成节点，然后用有类型的边把它们连起来”**。
这样以后任何占卜流程、本命盘算法、解释话术，其实都是“在图里走路 + 选边”。

我分几块讲：

1. 我们现在已经有什么（回顾一下）
2. 关系图需要满足的几条硬要求
3. 节点设计：都有哪些类别、ID 怎么定
4. 边（关系）设计：都有哪些关系类型
5. 和现在的 Mapping / Core 怎么联动
6. 多学派冲突怎么在图里优雅共存
7. 分阶段落地：我们下一步具体会先做哪一块

---

## 1. 现在已经有的“地基”

到目前为止，我们已经有：

- **位级别的本体（bit-level）**
  - `trigram_bits` / `hexagram_bits`：纯 0/1 表示的卦
  - 上下卦拆分、组合、爻位取反等运算（L2.a）

- **“身份证”层（core_*）**
  - `core_trigrams` / `core_hexagrams`：
    - 每个卦的 id、中文名、英文名、序号等
    - 这是“八卦 / 六十四卦是谁”的定义

- **插件式 Mapping 层（刚做好的）**
  - 比如：
    - `trigram_direction_xxx.json`：卦 → 方位
    - `trigram_wuxing_main.json`：卦 → 五行
  - Schema 已统一：`domain + kind + mapping`
  - 已有 loader，可以把这些 JSON 读成 `MappingBundle`

这些东西都还是“**表格形态**”：一行一行的数据。
接下来要做的关系图，就是把这些表格“立体化”，变成“**节点 + 边**”。

---

## 2. 关系图要满足的硬要求

根据你之前说的目标（多学派、可扩展、以本体为核心），我认为关系图至少要满足：

1. **所有“名词”都能变成节点**
   - 卦（八卦、六十四卦）
   - 五行
   - 天干地支
   - 方位、时间（节气、时辰、日、月）、季节
   - 身体部位、情绪、事件类型、职业等等
   - 以后想扩什么就扩什么

2. **所有“XXX 属于 YYY / 对应 ZZZ / 生克谁 / 组合成谁”类的句子，都能变成一个有类型的边**
   - 例如：
     - 震卦 ——(属)——> 木
     - 木 ——(生)——> 火
     - 寅月 ——(藏干有)——> 甲木
     - 乾卦 ——(象征)——> 父亲
   - 边要有：
     - 类型（关系类型）
     - 学派（school）
     - 来源、可信度（以后可以扩）

3. **多学派可以共存，互不覆盖**
   - 比如：
     - School A：坎卦 = 正北
     - School B：坎卦 = 北偏壬
   - 图里应该是：**同一个节点“坎”到两个不同的“方位节点”有两条边，school 不同**。
   - 查询的时候再选：只看某个学派，或者做“交集 / 并集 / 投票”。

4. **实现上足够轻量，不依赖外部图数据库**
   - 本项目内存中用 Python 自己的邻接表就够了
   - 不要 Neo4j、不要 RDF，太重、太拘束

---

## 3. 节点设计：Node

我们先按“**节点类型（kind） + 统一 ID**”的方式来设计。

### 3.1 节点 ID 方案

保持和之前 Mapping 一致，用 `"kind:local_id"`：

- 卦相关：
  - `trigram:0` ~ `trigram:7`
  - `hexagram:0` ~ `hexagram:63`
- 五行：
  - `wuxing:wood`
  - `wuxing:fire`
  - `wuxing:earth`
  - `wuxing:metal`
  - `wuxing:water`
- 方位（先简单点）：
  - `direction:N`
  - `direction:NE`
  - ...
- 时间：
  - 节气：`jieqi:lichun`、`jieqi:xiazhi`
  - 时辰：`shichen:zi`、`shichen:chou`
- 人体：
  - `body:head`
  - `body:heart`
- 抽象角色：
  - `role:father`
  - `role:mother`

这种方案有几个好处：

- 和 Mapping 里的 key（`trigram:0`）完全共享，不用转换
- 新增一个类型，只要约定一个前缀，比如 `emotion:joy` 就行

### 3.2 Node 结构（代码层）

在代码里，我们可以先定义一个通用 Node 类型，例如 `graph_types.py` 里：

```python
from dataclasses import dataclass, field
from typing import Any, Dict

@dataclass
class Node:
    id: str              # 如 "trigram:0", "wuxing:water"
    kind: str            # 如 "trigram", "wuxing", "jieqi"
    label: str           # 人类可读名：如 "坎", "水", "立春"
    attrs: Dict[str, Any] = field(default_factory=dict)
```

- `id`：作为全局唯一标识
- `kind`：方便按类别筛选，比如“找所有 trigram”
- `label`：展示用
- `attrs`：附加属性：
  - 比如：
    - 卦的拼音、象词、爻数等
    - 五行的颜色、季节、方位倾向
    - 节气对应的公历日期区间等
  - 多学派不一致的东西，一般考虑放到“边”里，而不是 node attrs 里

---

## 4. 边（关系）设计：Edge

### 4.1 Edge 的结构

同样在 `graph_types.py` 里：

```python
from dataclasses import dataclass, field
from typing import Any, Dict

@dataclass
class Edge:
    id: str              # 可选，可用 "{src}->{type}->{dst}->{school}" 拼出来
    src: str             # Node.id
    dst: str             # Node.id
    type: str            # 关系类型，如 "map:trigram->wuxing", "rel:wuxing:sheng"
    school: str          # 学派，如 "example", "liuren", "ziwei"
    weight: float = 1.0  # 可信度 / 强度，先保留字段
    attrs: Dict[str, Any] = field(default_factory=dict)
```

**关键字段：**

- `src` / `dst`：有向边，视情况可用“对称”的边表达对等关系
- `type`：字符串类型，建议用“命名空间风格”，比如：
  - `map:trigram->wuxing`：卦 → 五行映射
  - `attr:belongs_to`：某类属于某类
  - `rel:wuxing:sheng`：五行相生
  - `rel:wuxing:ke`：五行相克
- `school`：表示这条关系属于哪个学派
- `attrs`：附加信息，比如“来源书籍”、“页码”、“说明文字”

### 4.2 典型关系类型示例

我们可以预先准备一份“可用关系类型列表”，比如：

- **映射类**（map）
  - `map:trigram->wuxing`：卦 → 五行
  - `map:trigram->direction`：卦 → 方位
  - `map:hexagram->judgement`：卦 → 卦辞（也可以特殊处理）

- **结构类**（struct）
  - `struct:hexagram:upper`：六十四卦 → 上卦（三爻）
  - `struct:hexagram:lower`：六十四卦 → 下卦（三爻）
  - `struct:trigram:line`：卦 → 爻位（以后如果细到每一爻）

- **五行关系**（rel:wuxing）
  - `rel:wuxing:sheng`：相生
  - `rel:wuxing:ke`：相克
  - `rel:wuxing:cheng`：相乘
  - `rel:wuxing:hai`：相害

- **时空类**
  - `map:jieqi->wuxing`：节气 → 五行
  - `map:jieqi->direction`：节气 → 方位（比如立春属东方）

- **象类**
  - `symbol:trigram->body`：卦 → 身体部位
  - `symbol:trigram->role`：卦 → 人伦角色（父、母、长子等）

关系类型是开放集，以后遇到新需求随时加。

---

## 5. 和 Mapping / Core 的联动

关系图不是另起炉灶，而是“**把现有的 Core + Mapping 转换成 Node + Edge**”。

可以想象一个构建流程 `GraphBuilder`：

### 5.1 先建节点（Node）

1. 从 `core_trigrams` 里读取所有八卦
   - 为每个卦建一个节点：
     - `id="trigram:<id>"`
     - `kind="trigram"`
     - `label="乾"`
     - attrs 放上拼音、序号之类的基础信息
2. 从 `core_hexagrams` 里读取所有六十四卦
3. 预定义五行节点：
   - `wuxing:wood`（"木"）
   - `wuxing:fire`（"火"）
   - ...
4. 预定义基本方位节点：
   - `direction:N`、`direction:NE` 等
5. 以后加节气、天干地支，也是在这里建节点

### 5.2 再用 Mapping 生成边（Edge）

以你现在的两个 Mapping 为例：

- `trigram_wuxing_main.v1.json`
  - `domain="trigram"`
  - `kind="wuxing.main"`
  - `mapping["trigram:0"] = { "element": "金" }`

GraphBuilder 会这么干：

1. 遍历 mapping：
   - key = `"trigram:0"`
   - value = `{ "element": "金" }`
2. 把 `"金"` 转为统一的节点：
   - 例如我们约定：
     - `"金"` → `wuxing:metal`
3. 建一条边：
   - `src = "trigram:0"`
   - `dst = "wuxing:metal"`
   - `type = "map:trigram->wuxing"`
   - `school = bundle.meta.school`（比如 `"example"`）
   - `attrs` 里可以顺手记下 `"kind": bundle.kind` 等

方位 Mapping 也是类似：

- `trigram_direction_xiantian.v1.json`：
  - `"trigram:0" -> { "direction": "N" }`
- 转成一条边：
  - `src = "trigram:0"`
  - `dst = "direction:N"`
  - `type = "map:trigram->direction"`
  - `school = bundle.meta.school`
  - `attrs["kind"] = "direction.example"`（或者 "direction.xiantian"）

> 这一点非常关键：
> **Mapping 文件只是临时输入，关系图才是我们真正用来推理的结构。**

---

## 6. 多学派冲突怎么处理？

在图里，多学派就天然变成：**不同 school 的多条边**。

举个简单例子：

- School A：
  - `坎卦 -> 正北`
- School B：
  - `坎卦 -> 北偏壬`

图里的情况是：

```text
Node: trigram:KAN
Node: direction:N
Node: direction:N_by_ren  (随便举例)

Edge1:
  src = trigram:KAN
  dst = direction:N
  type = "map:trigram->direction"
  school = "schoolA"

Edge2:
  src = trigram:KAN
  dst = direction:N_by_ren
  type = "map:trigram->direction"
  school = "schoolB"
```

然后查询的时候：

- 如果用户选“按学派 A 解读”：
  - 过滤：`school == "schoolA"` 的边
- 如果用户说“尽量综合多学派意见”：
  - 可以：
    - 看所有 edge
    - 用 `weight` 做简单投票/加权
    - 或直接把所有结果列出来

以后如果你想在同一学派里也允许“版本演进”（比如 1.0、2.0），就可以：

- 在 Edge.attrs 里加 `version`
- 或者更严格一点，把 `MetaVersionInfo` 的部分字段也映射进来

---

## 7. 分阶段落地：下一步我们具体做什么？

你现在问的是“关系图的方案”，上面是整体设计。
为了不一下子搞太复杂，我会把实现拆成一个**最小可用版（MVP）**：

### 阶段 1：定义 Graph 类型 + 构建核心节点

新文件 `dao/graph_types.py`（或 `core/graph_types.py`）：

- 定义：
  - `Node`
  - `Edge`
  - `Graph`：

    ```python
    @dataclass
    class Graph:
        nodes: Dict[str, Node]
        edges: Dict[str, Edge]
        out_edges: Dict[str, list[str]]
        in_edges: Dict[str, list[str]]
    ```

- Graph 提供一些基础方法：
  - `add_node(node: Node)`
  - `add_edge(edge: Edge)`
  - `neighbors(src_id, type=None, school=None)`：查某个点出去的边

然后写一个 `build_base_graph()`：

- 从 core_trigrams + core_hexagrams 建所有卦节点
- 从“固定列表”建五行、方位节点
- 先不从 Mapping 里读边（或者只读你已有的两个 Mapping）

### 阶段 2：写 GraphBuilder，把 Mapping 转成边

- 新文件 `dao/graph_builder.py`：
  - `build_graph_from_core_and_mappings(core_data, mapping_bundles) -> Graph`
- 内部做两件事：
  1. 调用“阶段 1”的 `build_base_graph()` 得到一个 Graph
  2. 遍历所有 `MappingBundle`，按规则生成 Edge 加进 Graph

### 阶段 3：提供一个简单的查询 API

例如：

- `get_trigram_wuxing(graph, trigram_id, school)`：
  - 从 `"trigram:<id>"` 出发
  - 找边类型为 `"map:trigram->wuxing"`、school 符合的边
  - 返回目标五行节点（Node）

- `get_trigram_direction(graph, trigram_id, school)`：类似

这样我们就能很快验证关系图确实在工作：
从一个卦出发，查到它的五行、方位；
以后加节气、身体部位、情绪等等，都只是再加节点 & 边，不改核心逻辑。

---

## 总结一句话

- **Core / Mapping：** 解决“每个东西是谁 + 表格形式的对应关系”
- **关系图：** 解决“所有东西在一个大图里互相怎么连起来、怎么走”的问题
- 实现上：
  - 用统一 NodeId（`kind:id`）
  - Node 做“名词”
  - Edge 做“句子（关系）”，带 `type` + `school`
  - 构建 Graph 的过程，就是把现在的所有 JSON 解析结果“投影成节点和边”

如果你觉得这个设计 OK，下一步我就直接帮你**写出：**

- `graph_types.py`（Node / Edge / Graph）
- `graph_builder.py`（用现有 core + 两个 trigram mapping 构建一个最小可跑的 Graph + 简单查询函数）

这样你本地一跑，就能做到：

```python
graph = build_demo_graph()
get_trigram_wuxing(graph, trigram_id=0, school="example")  # -> "金"
get_trigram_direction(graph, trigram_id=0, school="example")  # -> "N"
```

然后我们再在这个基础上慢慢往里堆更多“玄学实体”和“玄学关系”。

-----

> 很好，就按你的方案进行下一步，并附上相应的测试文件‘

下面我直接给出这一阶段需要的代码文件 + 测试文件。
你可以按需改文件路径（我用的是 `dao/` 和 `tests/` 这种结构），逻辑是完全自洽的。

---

## 1. `dao/graph_types.py`

关系图的基础类型：节点、边、图本身 + 一些便捷方法。

```python
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
```

---

## 2. `dao/graph_builder.py`

这里实现：

- 基础节点（五行、方位）的构建
- 从“卦核心数据 + MappingBundle 风格对象”构建图
- 以及两个典型查询函数：卦 → 五行、卦 → 方位

```python
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
```

---

## 3. 测试文件：`tests/test_graph_builder.py`

这个测试文件是**完整可跑的最小示例**：

- 自己构造一个简化版的 `trigram_core`（八卦）
- 自己构造两个 MappingBundle 风格对象：
  - `trigram -> 五行`（一卦一五行，八个卦全写）
  - `trigram -> 方位`（先天八卦方位）
- 用 `build_graph_from_trigrams_and_mappings` 构建图
- 再用 `get_trigram_wuxing` / `get_trigram_direction` 做断言

```python
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

    # 4. 检查：坎卦 -> 五行（水）
    wuxing_nodes = get_trigram_wuxing(graph, trigram_id=5, school="example")
    assert len(wuxing_nodes) == 1
    assert wuxing_nodes[0].id == "wuxing:water"

    # 5. 检查：乾卦 -> 方位（西北）
    direction_nodes = get_trigram_direction(graph, trigram_id=0, school="example")
    assert len(direction_nodes) == 1
    assert direction_nodes[0].id == "direction:NW"

    # 6. 检查：坎卦 -> 方位（正北）
    direction_nodes = get_trigram_direction(graph, trigram_id=5, school="example")
    assert len(direction_nodes) == 1
    assert direction_nodes[0].id == "direction:N"


def test_multi_school_can_coexist():
    """
    验证多学派共存：同一个 trigram + 同一种关系类型，可以连到不同目标节点。
    """
    trigram_core = make_demo_trigram_core()
    wuxing_bundle_a = make_demo_trigram_wuxing_mapping_bundle()

    # 再造一套“学派 B”的五行关系，为了测试区分学派，这里故意弄得不同：
    mapping_b: Dict[str, Dict[str, str]] = {
        "trigram:0": {"element": "土"},  # 学派 B 认为乾为土（只是测试，没有玄学正确性）
    }
    wuxing_bundle_b = MappingBundleLike(
        meta=MappingMetaLike(domain="trigram", kind="wuxing.main", school="schoolB"),
        mapping=mapping_b,
    )

    graph = build_graph_from_trigrams_and_mappings(
        trigram_core=trigram_core,
        mapping_bundles=[wuxing_bundle_a, wuxing_bundle_b],
    )

    # 不指定学派时，应该能看到两条边（乾 -> 金 & 乾 -> 土）
    all_wuxing_nodes = get_trigram_wuxing(graph, trigram_id=0, school=None)
    all_ids = {n.id for n in all_wuxing_nodes}
    assert "wuxing:metal" in all_ids
    assert "wuxing:earth" in all_ids

    # 指定学派 example，只看到“金”
    wuxing_nodes_a = get_trigram_wuxing(graph, trigram_id=0, school="example")
    assert len(wuxing_nodes_a) == 1
    assert wuxing_nodes_a[0].id == "wuxing:metal"

    # 指定学派 schoolB，只看到“土”
    wuxing_nodes_b = get_trigram_wuxing(graph, trigram_id=0, school="schoolB")
    assert len(wuxing_nodes_b) == 1
    assert wuxing_nodes_b[0].id == "wuxing:earth"
```

---

## 4. 如何接到你现有工程里

你这一步要做的事情可以概括成三句：

1. 在工程里加上 `dao/graph_types.py` 和 `dao/graph_builder.py`
2. 把上面的 `tests/test_graph_builder.py` 丢进你的 `tests/` 目录（或你习惯的测试目录）
3. `pytest` 跑一下，确认通过

之后：

- 想和你已有的 `MappingBundle` 对接，只需要：
  - 保证它有 `.meta.domain / .meta.kind / .meta.school` 和 `.mapping`
  - 或者写一个很薄的适配层，把你的 Bundle 转成这里的 `MappingBundleLike` 再传入即可
- 想和“正式的八卦 core 数据”对接，只需要：
  - 把现在测试里的 `make_demo_trigram_core()` 换成你已有的 core 结构
  - 保证 `add_trigram_nodes_from_core` 能拿到中文名（或者你按需改一下字段名）

如果你愿意，下一步我可以基于你现在的 Mapping loader / core 数据结构，直接帮你写一段**集成代码**：
例如 `build_full_trigram_graph()`，自动从磁盘加载 JSON、构建 Graph，然后后续所有算法都基于这个 Graph 来做。

-----
