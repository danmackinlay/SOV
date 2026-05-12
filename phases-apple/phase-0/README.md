# Apple laptop phase 0 — Jan as full MLX stack

**Goal:** prove that an MLX-quantized open-weight model will talk to you on this specific Mac. One app, one model, one conversation. **Disposable by design** — phase 0 establishes "did Apple Silicon LLMs work for me at all" and nothing more. The composable, SOV-aligned stack (mlx-lm.server, LiteLLM, agentic coding) is phase 1.

Why a separate phase for this: the phase-1 stack is fiddlier than it needs to be for first contact. If your Mac, your model, or Jan itself has a problem, you want to find out before installing four more pieces on top.

## Prerequisites

- macOS 14+ on Apple Silicon. The Jan-bundled MLX backend requires ≥ Jan 0.7.7 (Feb 2026); Jan picks up its own runtime automatically — you don't install MLX separately.
- Free disk for the model you'll download (~20 GB for the reference pick).
- Network access for the initial model download (or a manual model import — see below).

## Install

1. Download Jan from [jan.ai](https://jan.ai) and drag to `/Applications`.
2. Open Jan, accept the macOS Gatekeeper prompt.
3. **Settings → Model Provider → choose MLX as the backend** (not Cortex/llama.cpp). On Jan 0.7.7+ the MLX option only appears on macOS; if you don't see it, update Jan.

That's the entire setup. No `uv tool install`, no terminal sessions, no port management.

## Pull a model and chat

1. In Jan's **Hub** tab, search for `Qwen3.5-35B-A3B` (or any other MLX model — Hub surfaces what its MLX downloader knows about).
2. Click Download. Wait for it to land in Jan's managed model directory.
3. New thread → pick the model → say hello.

The reference pick assumes ≥ 32 GB unified memory. On smaller Macs substitute per the [RAM-tier sizing table](../README.md#ram-tier-sizing) in the track README — anything in the `local-small` column will work for phase 0.

## Manual MLX model import (if Jan's Hub doesn't have what you want)

Jan's Hub catalog lags [mlx-community](https://huggingface.co/mlx-community) on Hugging Face. To use any MLX model Jan doesn't natively offer:

```bash
# Pull the full repo to a folder of your choice (not Jan's managed dir)
hf download mlx-community/Qwen3.5-35B-A3B-4bit --local-dir ~/Models/Qwen3.5-35B-A3B-4bit
```

Then in Jan: **My Models → Import → MLX (folder picker)** — point at the directory. Jan's MLX backend reads its own metadata from the folder contents.

## Exit criteria

Phase 0 is done when **one** thing is true: you've had a normal conversation with a local MLX model in Jan, on this Mac, that finished without crashing or stalling. That's it. No tokens-per-second target, no swap-pressure check, no smoke-test endpoint — those belong to phase 1.

If the conversation works: phase 0 ✅. Move on to phase 1.

If it doesn't:

- **Model fails to load:** likely RAM-pressure on a tight-tier machine. Try a smaller model from the sizing table; check Activity Monitor for memory pressure.
- **Jan stuck on "starting model server":** that's Jan's internal MLX backend booting. On first launch it can take a few minutes (cold caches, signature verification). If it never settles, restart Jan; failing that, file an issue with Jan and move to phase 1 (which uses an external runtime you control).
- **Conversation works but is unbearably slow:** smaller model, or jump to phase 1 where you'll get a clearer picture of what's loaded and how much it's consuming.

## What's deliberately out of scope here

Everything that makes the apple track *composable*:

- `mlx_lm.server` as an external endpoint at `localhost:8080` → phase 1.
- LiteLLM routing in front, model aliases, cloud fallback → phase 1.
- `bin/model-switch.sh` discipline, `bin/model-status.sh` introspection → phase 1.
- Aider, opencode, anything that needs a controllable endpoint for agentic coding → phase 1.
- RAG over Zotero / PDFs → phase 2.
- LibreChat web UI, MCP testing, cross-track parity with the cloud audition → phase 4.

The phase 0 setup is **not extensible**. Don't try to wire Aider against Jan's internal MLX runtime — it'll only frustrate you. When you're ready for agentic work, move to phase 1 and use Jan as a thin client against a runtime you control. See [Why Jan as a thin client, not a full stack](../README.md#why-jan-as-a-thin-client-not-as-a-full-stack) in the track README.

## Bridge to phase 1

When phase 0 passes its single exit criterion:

1. **Don't uninstall Jan.** It stays — its posture just changes from "full MLX stack" to "thin client against an external endpoint."
2. **Don't uninstall Jan's downloaded models either.** They're harmless in Jan's directory; you simply stop using Jan's internal runtime to serve them. Phase 1's `bin/model-switch.sh` works against the [`mlx-community` Hugging Face cache](../README.md#cleanup--disk-management), separate from Jan's models.
3. **Open [phases-apple/phase-1/README.md](../phase-1/README.md)** and follow the install steps.
