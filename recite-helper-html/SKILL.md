---
name: recite-helper-html
description: "背书助手：纯前端单文件 HTML 背诵工具（知识块切割 + 关键词挖空，圈圈记忆法）。三步走流程——粘贴长文本 → 自动生成思维导图树（大括号层级、可增删改、勾选联动）并选中文字圈成关键词 → 挖空背诵模式（椭圆空位点击翻面显示、全部显示/遮挡、打印PDF）。无后端、无 AI、无依赖，浏览器直接打开即用。当用户要『背书/记忆/挖空/知识块切割/课文法规背诵工具』时使用。"
version: 1.0.0
author: Hermes Agent
platforms: [web]
metadata:
  hermes:
    tags: [html, javascript, study-tool, mindmap, cloze, single-file, chinese]
    related_skills: [claude-design, sketch, github-push-publish]
---

# 背书助手 · 纯前端 HTML 背诵工具（知识块切割 + 关键词挖空）

## 何时用

用户要背课文/法规/知识点，需要一个"把长文切成知识块 → 圈出关键词 → 挖空自测"的工具。市面上有成熟 App（背书匠），但用户往往只要**核心的知识块切割 + 关键词挖空**两项能力，不要 AI、不要账号、不要后端——那就写一个单文件 HTML，双击浏览器打开即用，可以发给任何人、可以打印成 PDF 纸质背诵。

设计参考：竞品「背书匠」（http://beishujiang.hnzsjkj.com/）的交互逻辑。**做减法**是关键：用户明确说"不要搞得很复杂"，所以砍掉 AI 辅助、拖拽排序、云端存储，只保留切割 + 挖空 + 打印。

**已跑实例（2026-09，Ariana）**：`~/Desktop/背书助手/index.html`（1589 行单文件，纯 HTML+CSS+JS，浏览器实测可用）。完整源码：本技能 `templates/index.html`。

## 三步走产品流程（别改这个骨架，用户认这个心智模型）

```
第一步 输入文本        第二步 思维导图 + 关键词        第三步 挖空背诵
textarea 粘贴长文   →   自动切段成树 + 勾选 + 圈词   →   关键词变椭圆空位，点击翻面
"下一步：开始分段"      "下一步：开始背诵"              全部显示/全部遮挡/打印PDF
```

顶部有步骤指示器（1-2-3 圆圈 + 连接线，当前蓝色 active、已完成绿色 done），用户随时知道自己在哪一步、能往回退。

### 第一步：输入

- 大 textarea（min-height 300px），placeholder 提示"按段落分行，系统会自动按段落切割知识块"
- **「加载示例文本」按钮**（`loadSample()`）——必做，用户第一次打开时不知道贴什么，有示例才能立刻体验全流程（内置光合作用四段文本）

### 第二步：思维导图 + 关键词圈选（核心步骤）

**自动切割（`generateMindMap`）**：按 `\n+` 分段 → 每段前 15 字作主题节点（超出加`...`）→ 段内按中文标点 `，。、；：` 切短语，筛长度 2-15 字的，取前 3 个作子节点。根节点固定叫"核心主题"。这是**纯规则的粗切**，不是 NLP——目的是给用户一个可编辑的起点，不是精准提取。

**树形渲染（`createMindMapNode`）**：原生 `<ul>/<li>` 嵌套，**用 CSS border 画「大括号」层级线**（子 `ul` 加 `border-left/top/bottom` + 左侧圆角 + `::before` 画一根横线连到父节点），视觉上像思维导图的括号分组，但零依赖、零 canvas、可打印。根节点的 `ul` 去掉边框。

**节点能力**：
- `contenteditable` 直接改文字，`onblur` 同步回数据（`node.text` = textContent、`node.html` = innerHTML，**html 字段承载关键词标记，必须存**）
- 悬停显示 `+`（加子节点）/ `−`（删节点，根节点不给删）按钮
- checkbox 勾选，**父级勾选联动所有子孙**（`setAllChildrenSelected` 递归），第三步只背诵勾上的节点
- 自动序号（`assignNumbers`）：一级 `一、二、三、`（中文数字），二级 `1. 2. 3.`，三级及以下 `1.1 1.2`
- 底部实时关键词计数（"已标记 N 个关键词"）

**关键词圈选（圈圈记忆法的"圈"）**：
- 样式 `span.keyword` = **透明底 + 1.5px 黑色椭圆边框**（`border-radius: 50%`），像用笔圈起来，不是常见的黄色荧光笔——这是本工具的视觉签名
- 选中文字 → 浮动工具栏「标记关键词」；选中已圈的词 → 工具栏变「取消标记」（解包 span + `parent.normalize()` 合并文本节点）

### 第三步：挖空背诵

- 复用第二步的树结构和大括号样式（`#recite-mindmap-container`），只保留勾选节点（`deepCopyMindmap` 深拷贝时过滤 `selected === false`）
- 关键词 → `span.blank`：**白色椭圆空框**（min-width 48px、2px 黑边、圆角 50%），文字藏在内层 `.blank-text`（`display:none`）
- **点击空框翻面**：toggle `.revealed` 类 → 变黄底（`#fff3b0`）方角显示原文。用**事件委托**（document 级 click + `e.target.closest('.blank')`），不给每个空位绑监听
- 控制条：「全部显示」（检查用）/「全部遮挡」（重新自测）/「上一步」（回去改标记）/「返回首页」/「打印PDF」
- **打印PDF**：`@media print` 里隐藏 header/steps-bar/控制条/第一二步，强制显示 `#step3`（连 `.hidden` 也覆盖掉）；空框打印成黑色椭圆轮廓、`.blank-text` 强制 `display:none`（**纸质背诵时不能泄露答案**）；`li` 加 `page-break-inside: avoid` 防节点被劈成两页。`printAsPDF()` 先 `hideAll()` 再 `setTimeout(window.print, 100)`——必须等 UI 更新完再打印，否则会打出已翻面的答案

## 关键技术点与踩过的坑

- **⚠️ `range.surroundContents(span)` 会在跨节点选区抛异常**（选区横跨多个元素/部分选中节点时 `InvalidStateError`）。必须 try/catch 兜底：
  ```js
  try { range.surroundContents(span); }
  catch (e) { const f = range.extractContents(); span.appendChild(f); range.insertNode(span); }
  ```
- **⚠️ 点浮动工具栏会先吃掉选区**：工具栏必须用 `mousedown` 事件 + `e.preventDefault()`，否则 click 前浏览器已经清空 selection，拿不到 range。同理"点别处关闭工具栏"要 `setTimeout(..., 150)` 延迟判断。
- **⚠️ 选区检测要等一帧**：`mouseup` 里直接读 `window.getSelection()` 可能拿到旧选区，包一层 `requestAnimationFrame()` 再检测。
- **工具栏定位**：`range.getBoundingClientRect()` 取选区位置，居中放在上方 8px；左右 clamp 到视口内（`Math.max(8, Math.min(left, innerWidth - w - 8))`）；上方放不下（top < 8）就翻到选区下方。
- **选区归属判断**：从 `range.commonAncestorContainer` 往上爬 parentNode，找最近的 `.block-content` 或 `.mindmap-node-text`，用它的 `data-*` id 定位数据；爬不到就隐藏工具栏（防止在页面任意处选中都能标记）。
- **判断"是否已在关键词内"**：`range.startContainer`/`endContainer`（文本节点取 parentNode）相等且带 `.keyword` 类 → 显示"取消标记"。
- **数据与 DOM 双向同步**：contenteditable 改完 `onblur` 写回 `node.html`；圈词/取消圈词后调 `syncMindmapNodeHtml(nodeId)`（递归找节点 → 从 DOM 读回 innerHTML）。**html 字段是唯一真相来源**，text 只是纯文本备份。
- **XSS 防护**：所有用户文本进 DOM 前过 `escapeHtml()`（`div.textContent = t; return div.innerHTML`）。示例文本和自动切割结果都要过。
- **无状态设计**：数据只在内存（`mindMapData` / `blocks` 两个全局变量），刷新即清空——这是**有意为之**（轻量工具定位，用户贴一段背一段）。若用户要"存草稿"，加 `localStorage.setItem('reciteData', JSON.stringify(mindMapData))`，在 `generateMindMap` 后存、`DOMContentLoaded` 时读。
- **Toast 提示**：所有操作（加载示例、增删节点、标记/取消标记）都给 2 秒浮层反馈，`transform: translateY(-100px)` → `.show` 类归零做滑入动画。`pointer-events: none` 防挡点击。

## 视觉规范（用户认这套配色，改版别乱换）

- 背景：浅蓝渐变 `linear-gradient(180deg, #e8f4fd 0%, #f5f7fa 100%)`
- 主色：`#0084ff`（蓝），成功 `#52c41a`（绿），危险 `#ff4d4f`（红），关键词圈 `#333`，翻面黄底 `#fff3b0` + 边 `#f0c000`
- 卡片：白底 + `border-radius: 12px` + `box-shadow: 0 2px 8px rgba(0,0,0,0.06)`
- 主内容区 `max-width: 900px` 居中；正文 `line-height: 2`（背诵时要行距宽松）
- 字体：`-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Microsoft YaHei', sans-serif`（中英混排都稳）

## 交付流程

1. **拷模板**：`cp templates/index.html <目标目录>/index.html`，改标题/示例文本/配色即可。
2. **本地验证**（"别自嗨"纪律，浏览器 GUI 工具必须真验）：
   ```bash
   open "/path/to/index.html"        # macOS 默认浏览器打开
   ```
   验收清单（逐条肉眼过，或让用户 30 秒亲手试）：
   - 点「加载示例文本」→ textarea 出现四段文字
   - 点「下一步：开始分段」→ 出现带大括号的树，序号"一、二、三"和"1. 2. 3."正确
   - 选中一段文字 → 上方浮出「标记关键词」→ 点击 → 文字被黑椭圆圈住，底部计数 +1
   - 再选中已圈的词 → 工具栏变「取消标记」→ 点击 → 圈消失，计数 -1
   - 取消勾选某个父节点 → 子节点全部取消勾选
   - 点「下一步：开始背诵」→ 只出现勾选的节点，圈过的词变成白椭圆空框
   - 点击空框 → 翻面显示黄底原文；再点 → 盖回去
   - 「全部显示」/「全部遮挡」批量生效
   - 「打印PDF」→ 预览里只有第三步内容、空框是黑色椭圆**且看不到答案文字**、无节点被跨页劈开
3. **给用户的"操作 → 效果"对照表**（非技术用户必备，见下）。
4. **同步镜像**：改完 index.html 记得同步到本技能 `templates/index.html`；若已发布到 GitHub 仓库则一并 push（流程见技能 `github-push-publish`）。

## 与 Ariana 协作偏好

- 中文沟通；技术名词先大白话解释（"contenteditable = 让网页上的字能直接用鼠标点进去改"）。
- 交付要给**「操作 → 效果」对照表**让她自己试，而不是只说"已完成"。
- 她说"不要搞得很复杂"就是真话：**做减法优先**，砍功能比加功能更符合需求；每加一个功能先问自己是不是核心（切割 / 圈词 / 挖空 / 打印）。
- 小步迭代，每步真验证后再报喜。

## 支持文件

- `templates/index.html` — 完整可用源码（1589 行单文件，2026-09 浏览器实测）：三步走流程、大括号树、勾选联动、关键词圈选/取消、挖空翻面、全部显示/遮挡、打印PDF、Toast。改标题/示例文本/配色即可复用于其它背诵场景（英语单词、法条、考点）。
- 本包同步发布在 GitHub：`Ariana-Zhao/AI` 仓库 `recite-helper-html/` 目录。
