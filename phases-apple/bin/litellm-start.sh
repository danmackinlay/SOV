#!/usr/bin/env bash
# litellm-start.sh — launch the apple-track LiteLLM proxy safely.
#
# LiteLLM's --host flag defaults to 0.0.0.0 (all interfaces), which on a
# wifi-connected laptop exposes the proxy and the local model behind it
# to anyone on the LAN. It also reads an unscoped HOST env var as its
# default, which we refuse to set repo-wide because HOST is also touched
# by shells / ssh wrappers / generic web tooling.
#
# This wrapper threads the needle: it sets HOST=127.0.0.1 *for the
# litellm subprocess only* (single-command env prefix, not an export),
# and also passes --host 127.0.0.1 as belt-and-braces in case the CLI
# flag mechanism is the one that changes in a future LiteLLM release.
#
# Usage (from the repo root):
#   ./phases-apple/bin/litellm-start.sh                    # defaults
#   ./phases-apple/bin/litellm-start.sh --port 4001        # extra args pass through
#   LITELLM_CONFIG=path/to/other.yaml ./phases-apple/bin/litellm-start.sh
#
# Sanity-check the bind after launch:
#   lsof -nP -iTCP:4000 -sTCP:LISTEN
# Expect "127.0.0.1:4000". If "*:4000" the wrapper got bypassed; debug.

set -euo pipefail

CONFIG="${LITELLM_CONFIG:-phases-apple/phase-1/litellm-config.yaml}"
PORT="${LITELLM_PORT:-4000}"

if [[ ! -f "$CONFIG" ]]; then
  echo "litellm-start.sh: config not found at $CONFIG" >&2
  echo "  Run from the repo root, or set LITELLM_CONFIG=<path>." >&2
  exit 2
fi

# Subprocess-scoped HOST + explicit --host. exec replaces this shell so
# the litellm process becomes the foreground child of whoever launched.
exec env HOST=127.0.0.1 litellm \
  --config "$CONFIG" \
  --host 127.0.0.1 \
  --port "$PORT" \
  "$@"
