#!/usr/bin/env python3
"""eHR 每日学习 → Obsidian todo 清单写入器（正式版）

读取进度 progress.json 的 current_day=N，从同目录 week1.md~week6.md 取出
'## Day N' 小节，转成可勾选 todo 清单（- [ ] 英文 — 中文 + Key terms + 复习项），
写入 Obsidian vault：
  - <vault>/每日学习/Day NN.md   （永久归档，NN 两位数补零）
  - <vault>/今日学习.md          （覆盖为当天内容，桌面便签读取此文件）

【不动 progress.json】——推进进度由 Hermes cron 任务负责（推送完成后 +1）。
本脚本适合：手动预填/修复 vault 内容、或作为 cron 写库步骤的精确参照实现。
"""
import json, re, subprocess, urllib.parse, sys

DATA = "/Users/didi/Library/Application Support/cn.org.hermesagent.desktop/runtime/hermes-home/data/ehr-offboarding-en"
VAULT = "/Users/didi/Desktop/语言准备"

def main():
    prog = json.load(open(f"{DATA}/progress.json", encoding="utf-8"))
    N = prog["current_day"]
    if N > 30:
        print("N>30，学习已结束，无需写入")
        return
    week = f"week{(N - 1) // 5 + 1}.md"
    text = open(f"{DATA}/{week}", encoding="utf-8").read()

    m = re.search(rf"^## Day {N} \|.*$", text, re.M)
    if not m:
        print(f"ERROR: Day {N} section not found in {week}"); sys.exit(1)
    nxt = re.search(rf"^## Day {N+1} \|", text, re.M)
    sec = text[m.start(): nxt.start() if nxt else len(text)]
    lines = sec.splitlines()
    title = lines[0].strip()

    items, keyline = [], None
    cur_num, cur_en = None, None
    for line in lines[1:]:
        s = line.strip()
        if not s:
            continue
        if s.startswith("🔑"):
            keyline = s
            cur_num = cur_en = None
            continue
        mm = re.match(r"^(\d+)\.\s+(.*)$", s)
        if mm:
            cur_num, cur_en = int(mm.group(1)), mm.group(2)
        elif cur_en is not None:
            items.append((cur_num, cur_en, s))
            cur_num = cur_en = None

    assert len(items) >= 10, f"parsed only {len(items)} sentences"
    assert keyline, "Key terms line not found"

    out = [title, "", "读完一句勾一句，全勾完 = 今日打卡成功 🎉", ""]
    for num, en, cn in items:
        out.append(f"- [ ] {num}. {en} — {cn}")
    out += ["", keyline, "", "- [ ] 复习并朗读今日 Key terms", ""]
    content = "\n".join(out)

    arch = f"{VAULT}/每日学习/Day {N:02d}.md"
    today = f"{VAULT}/今日学习.md"
    open(arch, "w", encoding="utf-8").write(content)
    open(today, "w", encoding="utf-8").write(content)
    print(f"✅ 已写入（Day {N}）: {arch}")
    print(f"✅ 已写入: {today}")

    uri = "obsidian://open?vault=" + urllib.parse.quote("语言准备") + "&file=" + urllib.parse.quote("今日学习")
    subprocess.run(["open", uri], check=True)
    print("✅ 已唤起 Obsidian 聚焦今日学习页")

if __name__ == "__main__":
    main()
