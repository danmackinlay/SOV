#!/usr/bin/env bash
# model-status.sh — one-shot summary of what's loaded and how tight RAM is.
#
# Run this before launching anything big. Or run it once a minute in a
# tmux pane if you want a poor-man's dashboard. (For live monitoring,
# prefer `mactop` in another pane — this is a snapshot, not a stream.)

set -uo pipefail

PORT=8080
HOST=127.0.0.1
HF_CACHE="${HF_HOME:-${HOME}/.cache/huggingface}"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }

# ---- MLX (mlx-lm.server) ------------------------------------------------
bold "MLX (mlx_lm.server)"
mlx_pids="$(pgrep -f 'mlx_lm.server' || true)"
if [[ -z "$mlx_pids" ]]; then
  dim "  not running"
else
  for pid in $mlx_pids; do
    # rss in KB on macOS; comm gives basename only, so fish command line out of ps -o args.
    rss_kb="$(ps -o rss= -p "$pid" | tr -d ' ')"
    rss_gb="$(awk "BEGIN{printf \"%.1f\", ${rss_kb}/1024/1024}")"
    cmd="$(ps -o args= -p "$pid" | tr -s ' ')"
    echo "  pid $pid, ${rss_gb} GB resident"
    echo "  cmd: ${cmd}"
  done
  model="$(curl -s --max-time 2 "http://${HOST}:${PORT}/v1/models" 2>/dev/null \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["data"][0]["id"])' 2>/dev/null \
    || true)"
  if [[ -n "$model" ]]; then
    echo "  serving: $model"
    echo "  endpoint: http://${HOST}:${PORT}/v1"
  else
    dim "  /v1/models did not respond — server may still be loading weights"
  fi
fi
echo

# ---- Ollama -------------------------------------------------------------
bold "Ollama"
if command -v ollama >/dev/null 2>&1; then
  if pgrep -x ollama >/dev/null 2>&1 || pgrep -f 'ollama serve' >/dev/null 2>&1; then
    ps_out="$(ollama ps 2>/dev/null)"
    # `ollama ps` always prints a header row; any line beyond that is a loaded model.
    if [[ "$(echo "$ps_out" | wc -l | tr -d ' ')" -gt 1 ]]; then
      echo "$ps_out" | sed 's/^/  /'
    else
      dim "  daemon running, no models currently loaded"
    fi
  else
    dim "  daemon not running (start with: ollama serve, or it'll auto-start on first request)"
  fi
else
  dim "  not installed"
fi
echo

# ---- Memory pressure ----------------------------------------------------
bold "Memory pressure"
# memory_pressure prints a friendly summary; pull the most useful lines.
mp="$(memory_pressure 2>/dev/null)"
if [[ -n "$mp" ]]; then
  echo "$mp" | grep -E '(System-wide memory free|System-wide compressor|System-wide memory pressure)' | sed 's/^/  /'
else
  dim "  memory_pressure unavailable"
fi
# Page-in/out via vm_stat for the swap-on-LLM canary.
if command -v vm_stat >/dev/null 2>&1; then
  swapins="$(vm_stat | awk '/Swapins/ {print $2}' | tr -d '.')"
  swapouts="$(vm_stat | awk '/Swapouts/ {print $2}' | tr -d '.')"
  echo "  swap-ins (cumulative): ${swapins:-?}"
  echo "  swap-outs (cumulative): ${swapouts:-?}"
  dim  "  (non-zero swap-outs while an LLM is loaded == danger)"
fi
echo

# ---- HF cache disk usage ------------------------------------------------
bold "Hugging Face cache"
if [[ -d "$HF_CACHE" ]]; then
  echo "  path: $HF_CACHE"
  du -sh "$HF_CACHE" 2>/dev/null | awk '{print "  total: "$1}'
  # Top 5 biggest model repos in the cache.
  hub_dir="${HF_CACHE}/hub"
  if [[ -d "$hub_dir" ]]; then
    echo "  largest repos:"
    du -sh "$hub_dir"/models--* 2>/dev/null \
      | sort -rh \
      | head -n5 \
      | sed -E 's|.*/models--|    |; s|--|/|'
  fi
else
  dim "  $HF_CACHE not present yet"
fi
echo

# ---- Free disk ----------------------------------------------------------
bold "Free disk on /"
df -h / | awk 'NR==2 {printf "  available: %s of %s (%s used)\n", $4, $2, $5}'
