#!/usr/bin/env zsh

set -euo pipefail

INPUT_JSON="${1:-data/kuaishou/json/search_contents_2026-02-28.json}"
OUTPUT_DIR="${2:-data/kuaishou/videos}"

if [[ ! -f "${INPUT_JSON}" ]]; then
  echo "Input json not found: ${INPUT_JSON}"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

python - "${INPUT_JSON}" "${OUTPUT_DIR}" <<'PY'
import json
import os
import sys
import urllib.request

input_json = sys.argv[1]
output_dir = sys.argv[2]

with open(input_json, "r", encoding="utf-8") as f:
    rows = json.load(f)

ok = 0
skip = 0
fail = 0

for i, row in enumerate(rows, start=1):
    video_id = (row.get("video_id") or "").strip()
    play_url = (row.get("video_play_url") or "").strip()
    if not video_id or not play_url:
        skip += 1
        continue

    out_path = os.path.join(output_dir, f"{video_id}.mp4")
    if os.path.exists(out_path) and os.path.getsize(out_path) > 0:
        print(f"[{i}] SKIP exists: {out_path}")
        skip += 1
        continue

    try:
        req = urllib.request.Request(
            play_url,
            headers={
                "User-Agent": "Mozilla/5.0",
                "Referer": "https://www.kuaishou.com/",
            },
        )
        with urllib.request.urlopen(req, timeout=60) as resp, open(out_path, "wb") as wf:
            wf.write(resp.read())
        print(f"[{i}] OK   {video_id}")
        ok += 1
    except Exception as e:
        print(f"[{i}] FAIL {video_id}: {e}")
        fail += 1

print(f"Done. ok={ok}, skip={skip}, fail={fail}, output={output_dir}")
PY
