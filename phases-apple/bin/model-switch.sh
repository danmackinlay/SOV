#!/usr/bin/env bash
# model-switch.sh — swap the running mlx-lm.server between aliases.
#
# Enforces "one MLX model at a time" on the laptop. Kills any existing
# mlx_lm.server process, launches a new one in the background, and waits
# for the /v1/models endpoint to respond before returning.
#
# Usage:
#   model-switch.sh small   # Qwen3-30B-A3B-Thinking-2507 (daily driver)
#   model-switch.sh math    # DeepSeek-R1-Distill-Qwen-32B (math/proofs)
#   model-switch.sh big     # Qwen3-235B-A22B-Thinking-2507 (stretch)
#   model-switch.sh off     # kill everything, don't relaunch
#   model-switch.sh status  # show what's running, exit
#
# Each alias loads on port 8080. LiteLLM aliases (local-small, local-math,
# local-big) all point at 127.0.0.1:8080; switching here is what changes
# which actual model serves them.
#
# The MODELS map below is the only thing to edit when tuning the stack to
# your hardware. Defaults are sized for 96 GB+ unified memory; on smaller
# Macs drop each row to the picks in the RAM-tier sizing table at
# ../README.md#ram-tier-sizing. Keep the alias names (small/math/big) so
# the LiteLLM config and muscle memory carry over.

set -euo pipefail

PORT=8080
HOST=127.0.0.1
LOG_DIR="${HOME}/.local/state/sov-laptop"
LOG_FILE="${LOG_DIR}/mlx-lm.log"
PID_FILE="${LOG_DIR}/mlx-lm.pid"

declare -A MODELS=(
  [small]="mlx-community/Qwen3-30B-A3B-Thinking-2507-4bit"
  [math]="mlx-community/DeepSeek-R1-Distill-Qwen-32B-4bit"
  [big]="mlx-community/Qwen3-235B-A22B-Thinking-2507-3bit"
)

usage() {
  # Print every leading comment line after the shebang, stopping at the
  # first non-comment line. Survives growth of the comment block.
  awk 'NR==1{next} /^#/{sub(/^# ?/, ""); print; next} {exit}' "$0"
  exit "${1:-0}"
}

current_pid() {
  # Prefer the pid file; fall back to pgrep if it's stale.
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    cat "$PID_FILE"
    return
  fi
  pgrep -f "mlx_lm.server" | head -n1 || true
}

current_model() {
  # mlx-lm.server reports its loaded model at /v1/models.
  curl -s --max-time 2 "http://${HOST}:${PORT}/v1/models" 2>/dev/null \
    | python3 -c 'import sys, json; d=json.load(sys.stdin); print(d["data"][0]["id"])' 2>/dev/null \
    || true
}

stop_server() {
  local pid
  pid="$(current_pid)"
  if [[ -n "$pid" ]]; then
    echo "stopping mlx_lm.server (pid $pid)..."
    kill "$pid" 2>/dev/null || true
    # Wait up to 10s for graceful exit, then SIGKILL.
    for _ in $(seq 1 20); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.5
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo "  forcing SIGKILL"
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  # Belt-and-braces: anything else on the port?
  local stragglers
  stragglers="$(lsof -ti tcp:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$stragglers" ]]; then
    echo "killing stragglers on port $PORT: $stragglers"
    # shellcheck disable=SC2086
    kill -9 $stragglers 2>/dev/null || true
  fi
}

start_server() {
  local alias="$1"
  local model="${MODELS[$alias]:-}"
  if [[ -z "$model" ]]; then
    echo "unknown alias: $alias" >&2
    echo "known aliases: ${!MODELS[*]}" >&2
    exit 2
  fi

  mkdir -p "$LOG_DIR"
  echo "starting mlx_lm.server with $model on ${HOST}:${PORT}..."
  echo "  logs: $LOG_FILE"
  : > "$LOG_FILE"

  nohup mlx_lm.server \
    --model "$model" \
    --host "$HOST" \
    --port "$PORT" \
    >> "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"

  echo "  waiting for /v1/models to respond (up to 5 minutes for weight load)..."
  local started
  started=$(date +%s)
  while true; do
    if curl -s --max-time 2 "http://${HOST}:${PORT}/v1/models" >/dev/null 2>&1; then
      echo "  ready after $(( $(date +%s) - started ))s"
      return 0
    fi
    if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "mlx_lm.server died before becoming ready; tail of log:" >&2
      tail -n 30 "$LOG_FILE" >&2
      exit 3
    fi
    if (( $(date +%s) - started > 300 )); then
      echo "timed out waiting for mlx_lm.server" >&2
      exit 4
    fi
    sleep 2
  done
}

show_status() {
  local pid model
  pid="$(current_pid)"
  if [[ -z "$pid" ]]; then
    echo "mlx_lm.server: not running"
    return
  fi
  model="$(current_model)"
  echo "mlx_lm.server: pid $pid, port $PORT, model ${model:-unknown}"
}

case "${1:-}" in
  small|math|big)
    stop_server
    start_server "$1"
    show_status
    ;;
  off)
    stop_server
    echo "mlx_lm.server stopped."
    ;;
  status)
    show_status
    ;;
  -h|--help|help|"")
    usage 0
    ;;
  *)
    echo "unknown command: $1" >&2
    usage 1
    ;;
esac
