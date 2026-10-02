#!/usr/bin/env python3
"""Print a one-line Claude Code status for the watch, as a Pulse Link `status` message.

Reads the newest Claude Code transcript of a project (the last assistant turn's token usage and
model) and prints, for example:
  {"v": 1, "type": "status", "text": "pulse Opus 5.5 ctx 25%", "title": "Claude", "ctx": 25,
   "lines": ["pulse", "Opus 5.5", "250k / 1000k  rb", "ba2d0b1a  14:25"]}

usage: claude_status.py [--cwd DIR] [--window 1000000] [--text-only]
  --cwd     the project directory Claude Code runs in (default: the current directory)
  --window  the model's context window in tokens (default 1,000,000)
Nothing is sent anywhere: pipe the output to whatever delivers it to the watch.
"""
import argparse, glob, json, os, re

ap = argparse.ArgumentParser()
ap.add_argument("--cwd", default=os.getcwd())
ap.add_argument("--window", type=int, default=1_000_000)
ap.add_argument("--text-only", action="store_true")
a = ap.parse_args()

home = os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))
enc = re.sub(r"[/.]", "-", os.path.abspath(a.cwd))
files = sorted(glob.glob(os.path.join(home, "projects", enc, "*.jsonl")), key=os.path.getmtime)
if not files:
    raise SystemExit(f"no Claude Code transcript for {a.cwd}")

usage, model, session = None, None, os.path.basename(files[-1])[:8]
with open(files[-1], encoding="utf-8", errors="replace") as f:
    for line in f:
        if '"usage"' not in line:
            continue
        try:
            msg = json.loads(line).get("message") or {}
        except ValueError:
            continue
        if msg.get("role") == "assistant" and msg.get("usage"):
            usage, model = msg["usage"], msg.get("model") or model

if not usage:
    raise SystemExit("no assistant turn with token usage yet")
used = sum(usage.get(k) or 0 for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
pct = round(100 * used / a.window)
m = re.match(r"claude-([a-z]+)-(\d+)-(\d+)", model or "")
name = f"{m.group(1).title()} {m.group(2)}.{m.group(3)}" if m else (model or "?")
repo = os.path.basename(os.path.abspath(a.cwd))
text = f"{repo} {name} ctx {pct}%"
import time
token = os.environ.get("CLAUDE_TOKEN_NAME", "")
msg = {
    "v": 1, "type": "status", "text": text,           # line under the cat on the clock
    "title": "Claude", "ctx": max(0, min(100, pct)),   # page 2: title and context bar
    "lines": [repo, name, f"{used // 1000}k / {a.window // 1000}k" + (f"  {token}" if token else ""),
              f"{session}  {time.strftime('%H:%M')}"],
}
print(text if a.text_only else json.dumps(msg))
