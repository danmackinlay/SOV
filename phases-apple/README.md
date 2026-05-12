# Apple laptop track

A parallel track to the main SOV audition. Same interface conventions (OpenAI-compatible + LiteLLM routing); Mac-native backends (mlx-lm + Ollama). Rationale and scope are in [ADR 0004](../docs/decisions/0004-apple-laptop-personal-track.md); the "why not Apple Neural Engine" question is answered in [ADR 0005](../docs/decisions/0005-apple-neural-engine.md).

This is a *personal* stack — currently just for Dan but should be generic across Apple hardware —  Daily use of it is practice for the cloud audition: when you sit down to use Jan against `local-small` it's the same muscle memory as Jan against the audition's `audition-235b`.

## Layered shape

```
┌─ Clients ──────────────────────────────────────────────────┐
│  Jan (chat)   Aider (prose/code edits)   AnythingLLM (RAG) │
└────────────────────────┬───────────────────────────────────┘
                         │ OpenAI-compatible
┌────────────────────────▼───────────────────────────────────┐
│  LiteLLM proxy  ← one endpoint, model aliases, flight-mode │
└──────┬─────────────────────────┬──────────────────────┬────┘
       │                         │                      │
┌──────▼──────────┐     ┌────────▼───────────┐  ┌───────▼────────┐
│ mlx-lm.server   │     │ Ollama (kept)      │  │ Cloud (online) │
│ (MLX, primary)  │     │ GGUF + embeddings  │  │ Anthropic etc. │
└─────────────────┘     └────────────────────┘  └────────────────┘
```

Image generation (Draw Things, ComfyUI) and audio generation (Stable Audio Open, deferred) sit beside this core.

## Stack at a glance

| Layer | Pick | Install | Why |
|---|---|---|---|
| MLX inference | `mlx-lm` | `uv tool install mlx-lm` | Fastest path for big reasoning models on Apple Silicon |
| GGUF fallback + embeddings | Ollama (kept) | `brew install ollama` (already done) | Embedding model auto-evict; GGUF coverage when MLX lags |
| Routing | LiteLLM proxy | `uv tool install 'litellm[proxy]'` | Single endpoint, model aliases, mix local + cloud |
| Chat client | Jan | DMG from [jan.ai](https://jan.ai) | Native macOS, points at LiteLLM, flight-mode capable |
| Editor agent | Aider | `uv tool install aider-chat` | Diff-based edits work on local models; prose-friendly |
| RAG | AnythingLLM | DMG from [anythingllm.com](https://anythingllm.com) | Desktop app, points at LiteLLM, manages PDF workspaces |
| PDF → markdown | Marker | `uv tool install marker-pdf` | Math/table-aware; fast on Apple Silicon |
| Vision/OCR | Qwen2.5-VL-7B via mlx-lm | (pulled on demand) | Ad-hoc image-to-text; Marker has its own OCR |
| Image gen | Draw Things | App Store | Mac-native sweet spot ([rationale](https://danmackinlay.name/notebook/image_ai_clients.html#draw-things)) |
| Image gen (power) | ComfyUI + ComfyUI-MLX + ComfyUI-GGUF | `uv venv` + `uv pip install` | Graph-level control; GGUF quants help on lower-RAM Macs |
| Audio gen | Stable Audio Open via `stable-audio-tools` | Deferred | Low priority ([context](https://danmackinlay.name/notebook/nn_generative_audio.html)) |

## Models

Three resident-on-disk aliases, math-reasoning-prioritised. **The picks below are written for a high-RAM machine (96 GB+) and should be tuned to your hardware** — see [RAM-tier sizing](#ram-tier-sizing) below, and edit [`bin/model-switch.sh`](bin/model-switch.sh) to match. The shape of the stack (three aliases, MoE for daily driver, dense for math, stretch for occasional heavy reasoning) holds across the range.

| Alias | Reference pick (96 GB+) | Quant | Resident | Use |
|---|---|---|---|---|
| `local-small` | [Qwen3-30B-A3B-Thinking-2507](https://huggingface.co/Qwen/Qwen3-30B-A3B-Thinking-2507) (MoE, 3 B active) | MLX 4-bit | ~17 GB | Daily driver. Matches SOV phase 0. |
| `local-math` | [DeepSeek-R1-Distill-Qwen-32B](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-32B) | MLX 4-bit | ~19 GB | Mathematics, proofs, formal reasoning. |
| `local-big` | [Qwen3-235B-A22B-Thinking-2507](https://huggingface.co/Qwen/Qwen3-235B-A22B-Thinking-2507) (MoE, 22 B active) | MLX 3-bit | ~95–105 GB | Stretch model. Matches SOV phase 1. |

Add `anthropic-claude` and `anthropic-haiku` to the same LiteLLM config when you want online cloud routing.

### RAM-tier sizing

Apple Silicon Macs span 16 GB to 192 GB+ of unified memory; the right pick per alias scales with what's available. Rough guidance — always leave ~16 GB of headroom for macOS and other apps, and assume MLX 4-bit unless noted:

| Unified RAM | `local-small` | `local-math` | `local-big` | Notes |
|---|---|---|---|---|
| 16 GB | Qwen3-4B-Thinking | — | — | LLM headroom is tight; close other apps. No math/stretch tier. |
| 24 GB | Qwen3-8B or Qwen3-14B-Thinking (tight) | DeepSeek-R1-Distill-Qwen-7B | — | First viable tier for "real" reasoning. |
| 32–48 GB | Qwen3-30B-A3B-Thinking (MoE) | DeepSeek-R1-Distill-Qwen-14B → 32B | — | Sweet spot starts here; everything in this doc behaves. |
| 64 GB | Qwen3-30B-A3B-Thinking (Q5) | DeepSeek-R1-Distill-Qwen-32B (Q5) | — | Higher quants comfortable. |
| 96 GB | Qwen3-30B-A3B-Thinking (Q5/Q6) | DeepSeek-R1-Distill-Qwen-32B (Q6) | Qwen3-235B-A22B-Thinking (Q2/Q3, tight) | Stretch becomes possible. |
| 128 GB+ | Qwen3-30B-A3B-Thinking (Q4–Q6) | DeepSeek-R1-Distill-Qwen-32B (Q4–Q6) | Qwen3-235B-A22B-Thinking (Q3) | The reference picks as written. |

Quant suffixes assume MLX repos in [`mlx-community/`](https://huggingface.co/mlx-community) on Hugging Face; substitute the closest existing quant when the exact one isn't published. The model-switch helper has these picks in one place — edit, don't fork.

## Sub-phases

Sub-phase directories are created when started, same convention as the main SOV phases.

| Directory | What | Status |
|---|---|---|
| [`phase-0/`](phase-0/) | mlx-lm + Jan + Qwen3-30B-A3B-Thinking; confirm one model "feels" useful | scoped |
| `phase-1/` | LiteLLM proxy + Aider; edit a `.qmd` against `local-small` | pending |
| `phase-2/` | RAG: Marker + LanceDB + AnythingLLM over a Zotero subset | pending |
| `phase-3/` | Stretch model + vision: `local-big` and Qwen2.5-VL-7B loaded on demand | pending |
| `phase-4/` | Side quests: Draw Things, ComfyUI; opencode as an Aider alternative; Stable Audio Open if motivated | pending |

## Operational discipline

Documented properly per sub-phase; for now, the rules that apply throughout:

- **One MLX model at a time.** `mlx_lm.server` is one model per process. Use [`bin/model-switch.sh`](bin/) to swap. Don't leave two big models loaded "just in case."
- **Ollama auto-evicts** with `OLLAMA_KEEP_ALIVE=15m`. Embedding model gets pulled on demand and freed shortly after.
- **Don't run Draw Things or ComfyUI alongside `local-big`.** GPU contention will stall both. Phase 4 documents the cohabitation rules.
- **Pre-pull weights** before flight mode: `huggingface-cli download <repo>`. First-token-after-flight should not wait on the network.
- **Watch unified-memory pressure**, not free RAM. macOS swaps aggressively before showing low free memory, and swap on an LLM is unusable. `mactop` is the live view; [`bin/model-status.sh`](bin/) is the one-shot.
- **Update mlx-lm every few weeks** (`uv tool upgrade mlx-lm`). New Qwen / DeepSeek releases need fresh architecture support.

## Helpers

| Script | Job |
|---|---|
| [`bin/model-switch.sh`](bin/model-switch.sh) | Kill the running mlx-lm.server, launch a new one by alias, wait for health |
| [`bin/model-status.sh`](bin/model-status.sh) | One-shot summary: Ollama, MLX process, memory pressure, HF cache disk |

## Open questions

- **MCP-based RAG inside Jan vs. dedicated AnythingLLM.** Phase 2 uses AnythingLLM for time-to-working. A later phase may swap to a Zotero MCP server feeding Jan directly, which is more SOV-spirit (composable parts). Decision deferred to phase-2 retro.
- **opencode adoption.** Phase 4 scopes it as an Aider-alternative experiment. If it works well on `local-small`, may promote it; if it's too token-hungry for 30B-class models, stays an experiment.
- **Cloud routing through LiteLLM.** Phase 1 wires Anthropic into LiteLLM as `anthropic-claude`. Flight-mode behaviour: model alias errors out cleanly if upstream unreachable, the local aliases keep working.
