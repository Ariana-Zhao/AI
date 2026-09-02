# 📌 macos-sticky-note · 桌面学习便利贴（Skill 包）

把 Obsidian / 任意 Markdown 文件的内容，以**桌面便利贴**形态常驻显示，支持点击打勾并双向同步。
本目录是完整可迁移的 skill 包（Hermes 技能 `macos/macos-sticky-note` 的镜像副本，含最新双向打勾版源码）。

## 这套系统在跑什么（Ariana 的 eHR 英语 30 天学习）

```
Hermes cron（工作日 9:00）
  ├─ 推送学习内容到聊天
  ├─ 写入 Obsidian vault：/Users/didi/Desktop/语言准备/今日学习.md + 每日学习/Day NN.md（todo 清单）
  └─ 唤起 Obsidian 聚焦今日学习页
桌面便签 LearningSticky（LaunchAgent 常驻，开机自启）
  ├─ 每 30s 读 今日学习.md → 米黄便利贴显示当天 10 句 + Key terms
  ├─ 点 ☐/☑ → 翻转勾选并写回文件 → Obsidian 同步
  └─ 右上角按钮 / 双击 → 折叠成小条；右键 → 刷新/打开 Obsidian/重置勾选/退出
```

## 目录结构

| 文件 | 说明 |
| --- | --- |
| `SKILL.md` | Skill 定义与完整操作手册（与 Hermes 内同步） |
| `templates/main.swift` | 便利贴源码（最新版：折叠/展开 + 双向打勾 + 一键重置） |
| `scripts/build-and-restart.sh` | 改完源码 → 编译 + 重启（日常迭代用这个） |
| `scripts/install.sh` | 首次安装（拷贝 LaunchAgent + 启动） |
| `scripts/uninstall.sh` | 停止并移除开机自启 |
| `scripts/update-daily-todo.py` | 把进度文件对应 Day 的内容写入 vault（todo 化） |
| `LaunchAgent/com.ari.learning-sticky.plist` | 开机自启 + 崩溃自愈配置 |

## 常用操作

```bash
# 改代码后重编译并重启便签
./scripts/build-and-restart.sh

# 首次安装 / 卸载
./scripts/install.sh
./scripts/uninstall.sh

# 手动把当前学习进度同步进 Obsidian（不推进进度）
python3 scripts/update-daily-todo.py
```

## 关键位置速查

- 便签二进制：`~/Library/Application Support/LearningSticky/LearningSticky`
- LaunchAgent：`~/Library/LaunchAgents/com.ari.learning-sticky.plist`
- 内容源：`/Users/didi/Desktop/语言准备/今日学习.md`（源码里 `kFilePath` 常量，换内容就改它）
- Obsidian vault：`/Users/didi/Desktop/语言准备`（库名"语言准备"）
- 学习内容源：`hermes-home/data/ehr-offboarding-en/week1~6.md` + `progress.json`

## 复用到其它场景

1. `templates/main.swift` 改三处：`kFilePath`（读哪个文件）、窗口宽高、标题文案；
2. 把 `scripts/build-and-restart.sh` 里的 BIN_NAME / plist Label 换成新的；
3. `./scripts/build-and-restart.sh` 即上线。
（详见 SKILL.md）
