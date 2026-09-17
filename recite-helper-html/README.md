# 📖 背书助手 · 纯前端 HTML 背诵工具（Skill 包）

把长文本（课文 / 法规 / 考点）切成知识块、圈出关键词、挖空自测——**圈圈记忆法**。
纯 HTML + CSS + JavaScript 单文件，无后端、无 AI、无依赖、无需安装，浏览器双击打开即用，还能打印成 PDF 纸质背诵。

本目录是完整可迁移的 skill 包（Hermes 技能 `creative/recite-helper-html` 的镜像副本）。

## 三步走

```
① 输入文本  →  ② 思维导图 + 圈关键词  →  ③ 挖空背诵
粘贴长文       自动切段成树，勾选+圈词      关键词变椭圆空位，点击翻面
```

## 操作 → 效果对照表

| 操作 | 效果 |
| --- | --- |
| 点「加载示例文本」 | textarea 填入四段示例（光合作用），立刻可体验全流程 |
| 点「下一步：开始分段」 | 按段落自动切成带大括号的树，序号「一、」「1.」自动编排 |
| 点节点文字 | 直接编辑（contenteditable） |
| 悬停节点 → `+` / `−` | 添加子节点 / 删除节点 |
| 勾选 / 取消勾选 checkbox | 父级联动所有子孙；第三步只背勾选的部分 |
| 鼠标选中文字 | 上方浮出「标记关键词」工具栏 |
| 点「标记关键词」 | 选中文字被黑色椭圆圈住（圈圈记忆法），底部计数 +1 |
| 再选中已圈的词 → 点「取消标记」 | 圈消失，计数 -1 |
| 点「下一步：开始背诵」 | 圈过的词变成白色椭圆空框 |
| 点击空框 | 翻面显示黄底原文；再点盖回去 |
| 「全部显示」/「全部遮挡」 | 批量检查 / 重新自测 |
| 「打印PDF」 | 只打印第三步，空框为黑色椭圆**且不含答案文字**，节点不跨页劈开 |

## 目录结构

| 文件 | 说明 |
| --- | --- |
| `SKILL.md` | Skill 定义与完整技术手册（含踩坑记录，与 Hermes 内同步） |
| `templates/index.html` | 完整源码（1589 行单文件，浏览器实测可用） |

## 快速上手

```bash
git clone https://github.com/Ariana-Zhao/AI.git
open AI/recite-helper-html/templates/index.html   # 直接打开就能用
```

复用改造：改 `<title>`、`loadSample()` 里的示例文本、配色变量即可迁移到其它背诵场景（英语单词、法条、考点）。

## 技术要点（详见 SKILL.md）

- 大括号层级线 = 纯 CSS `border-left/top/bottom` + `::before` 横线，零 canvas / 零依赖 / 可打印
- 圈词用 Selection API + `range.surroundContents()`，跨节点选区 try/catch 兜底 `extractContents()`
- 浮动工具栏必须用 `mousedown` + `preventDefault()`，否则点击前选区已被浏览器清空
- 空位翻面用事件委托（document 级 `closest('.blank')`），不逐个绑监听
- 数据存内存（`mindMapData`），刷新即清空——轻量工具定位；要存草稿加 `localStorage`
- 所有用户文本过 `escapeHtml()` 防 XSS

## 验证状态

- ✅ JS 语法：`node --check` 通过
- ✅ HTML 结构：标签闭合完整，15 个必需 id 齐全
- ✅ 切割逻辑：段落切分 + 主题提取 + 子节点筛选冒烟测试通过
- ✅ 15 个核心函数全部就位
