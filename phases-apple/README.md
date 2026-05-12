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
| Vision/OCR | Qwen3-VL-8B via mlx-lm (or rely on Qwen3.5 daily driver's native VL) | (pulled on demand) | Ad-hoc image-to-text; Marker has its own OCR |
| Image gen | Draw Things | App Store | Mac-native sweet spot ([rationale](https://danmackinlay.name/notebook/image_ai_clients.html#draw-things)) |
| Image gen (power) | ComfyUI + ComfyUI-MLX + ComfyUI-GGUF | `uv venv` + `uv pip install` | Graph-level control; GGUF quants help on lower-RAM Macs |
| Audio gen | Stable Audio Open via `stable-audio-tools` | Deferred | Low priority ([context](https://danmackinlay.name/notebook/nn_generative_audio.html)) |

## Models

Three resident-on-disk aliases, math-reasoning-prioritised. **The picks below are written for a high-RAM machine (96 GB+) and should be tuned to your hardware** — see [RAM-tier sizing](#ram-tier-sizing) below, and edit [`bin/model-switch.sh`](bin/model-switch.sh) to match. The shape of the stack (three aliases, MoE for daily driver, dense for math, stretch for occasional heavy reasoning) holds across the range.

| Alias | Reference pick (96 GB+, as of 2026-05) | Quant | Resident | Use |
|---|---|---|---|---|
| `local-small` | [Qwen3.5-35B-A3B](https://huggingface.co/Qwen/Qwen3.5-35B-A3B) (MoE, 3 B active; thinking-by-default, natively VL) | MLX 4-bit | ~23 GB | Daily driver. Successor to Qwen3-30B-A3B (the SOV cloud phase-0 model). |
| `local-math` | [DeepSeek-R1-0528-Qwen3-8B](https://huggingface.co/deepseek-ai/DeepSeek-R1-0528-Qwen3-8B) | MLX 4-bit | ~5 GB | Mathematics, proofs, formal reasoning. 8 B distill that ties Qwen3-235B-Thinking on AIME-2024. Heavier alternative for non-AIME-style math (formal proofs, abstract algebra): [DeepSeek-R1-Distill-Qwen-32B](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-32B) (MLX 4-bit, ~19 GB). DeepSeek-Math-V2 is the open-weight math frontier but is 685 B with no MLX port. |
| `local-big` | [Qwen3.5-122B-A10B](https://huggingface.co/Qwen/Qwen3.5-122B-A10B) (MoE, 10 B active) | MLX 4-bit | ~65 GB | Stretch model. Smaller and faster than Qwen3-235B-A22B at comparable quality; the new sweet spot for 96 GB+ Macs. |

Add `anthropic-claude` and `anthropic-haiku` to the same LiteLLM config when you want online cloud routing.

### RAM-tier sizing

Apple Silicon Macs span 16 GB to 192 GB+ of unified memory; the right pick per alias scales with what's available. Rough guidance — always leave ~16 GB of headroom for macOS and other apps, and assume MLX 4-bit unless noted:

| Unified RAM | `local-small` | `local-math` | `local-big` | Notes |
|---|---|---|---|---|
| 16 GB | Qwen3-class 4 B (dense) | DeepSeek-R1-0528-Qwen3-8B (tight) | — | LLM headroom tight; close other apps. No stretch tier. |
| 24 GB | Qwen3-class 8 B–14 B (dense, tight at 14 B) | DeepSeek-R1-0528-Qwen3-8B | — | First viable tier for "real" reasoning. |
| 32–48 GB | Qwen3.5-35B-A3B (MoE) | DeepSeek-R1-0528-Qwen3-8B (or 32 B distill for heavier math) | — | Sweet spot starts here; everything in this doc behaves. |
| 64 GB | Qwen3.5-35B-A3B (Q5) | DeepSeek-R1-0528-Qwen3-8B (Q6/Q8) or 32 B distill (Q5) | — | Higher quants comfortable. |
| 96 GB | Qwen3.5-35B-A3B (Q5/Q6) | 8 B distill (Q8) or 32 B distill (Q6) | Qwen3.5-122B-A10B (Q4) | Stretch becomes possible. |
| 128 GB+ | Qwen3.5-35B-A3B (Q4–Q6) | DeepSeek-R1-0528-Qwen3-8B | Qwen3.5-122B-A10B (Q4–Q6) | The reference picks as written. |
| 192–256 GB | Qwen3.5-35B-A3B | DeepSeek-R1-0528-Qwen3-8B or 32 B distill | Qwen3.5-397B-A17B (Q4) | New top end (Mac Studios primarily). |

Quant suffixes assume MLX repos in [`mlx-community/`](https://huggingface.co/mlx-community) on Hugging Face; substitute the closest existing quant when the exact one isn't published. The [`model-switch.sh`](bin/model-switch.sh) helper has these picks in one place — edit, don't fork.

**Heavier daily-driver alternative for 64 GB+ Macs:** [Qwen3-Next-80B-A3B-Thinking](https://huggingface.co/Qwen/Qwen3-Next-80B-A3B-Thinking) (3 B active, 80 B total; Sep 2025 release sitting between Qwen3-30B-A3B and Qwen3.5-35B-A3B in the lineage). MLX-4bit port at [`mlx-community/Qwen3-Next-80B-A3B-Thinking-4bit`](https://huggingface.co/mlx-community/Qwen3-Next-80B-A3B-Thinking-4bit), ~45 GB resident. Same per-token speed as the smaller A3B picks (still 3 B active), more quality at the cost of more RAM. Swap into `local-small` if you have headroom and prefer ceiling-of-quality over lightness.

> **Model picks rot fast.** This table reflects May 2026. Before bootstrapping a fresh machine, re-check [mlx-community](https://huggingface.co/mlx-community), [Qwen](https://huggingface.co/Qwen) and [deepseek-ai](https://huggingface.co/deepseek-ai) for newer releases. The shape (MoE daily + dense math + larger-MoE stretch) is more durable than the specific repo names; substitute generation-for-generation as the families move.

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
- **Pre-pull weights** before flight mode: `hf download <repo>` (the old `huggingface-cli` is deprecated as of 2026; `uv tool install huggingface_hub` still installs the new `hf` binary). First-token-after-flight should not wait on the network.
- **Watch unified-memory pressure**, not free RAM. macOS swaps aggressively before showing low free memory, and swap on an LLM is unusable. `mactop` ([metaspartan/mactop](https://github.com/metaspartan/mactop)) is the live view; [`bin/model-status.sh`](bin/model-status.sh) is the one-shot.
- **Update mlx-lm every few weeks** (`uv tool upgrade mlx-lm`). New Qwen / DeepSeek releases need fresh architecture support.
- **LiteLLM (phase 1 onward) pinned by digest, never internet-exposed.** Even on a laptop bound to `127.0.0.1`. Pin a known-good version ≥1.83.7 (CVE-2026-42208 pre-auth SQL injection fixed there; a March 2026 PyPI supply-chain attack pushed malicious 1.82.7/1.82.8). On a laptop the blast radius is small but the discipline is identical to the cloud-track rule.
- **Honest about what mlx-lm gives up vs. the cloud audition.** No built-in RadixAttention-style prefix cache, no xgrammar-class structured-output framework, no FP8 path on Apple Silicon. For prose editing, occasional code edits, and PDF Q&A the practical impact is unmeasured — possibly small. If you find sustained multi-turn agentic sessions (long Aider conversations, repeated RAG over the same shared prefix) feel materially slower than the same workflow against a cloud SGLang/vLLM endpoint, this is the likely cause. We haven't benchmarked it head-to-head and don't want to overclaim either direction.

## Helpers

| Script | Job |
|---|---|
| [`bin/model-switch.sh`](bin/model-switch.sh) | Kill the running mlx-lm.server, launch a new one by alias, wait for health |
| [`bin/model-status.sh`](bin/model-status.sh) | One-shot summary: Ollama, MLX process, memory pressure, HF cache disk |

## Open questions

- **MCP-based RAG inside Jan vs. dedicated AnythingLLM.** Phase 2 uses AnythingLLM for time-to-working. A later phase may swap to a Zotero MCP server feeding Jan directly, which is more SOV-spirit (composable parts). Decision deferred to phase-2 retro.
- **opencode adoption.** Phase 4 scopes it as an Aider-alternative experiment. If it works well on `local-small`, may promote it; if it's too token-hungry for 30B-class models, stays an experiment.
- **Cloud routing through LiteLLM.** Phase 1 wires Anthropic into LiteLLM as `anthropic-claude`. Flight-mode behaviour: model alias errors out cleanly if upstream unreachable, the local aliases keep working.
- **Embedding model upgrade.** Phase 2 uses the existing `mxbai-embed-large` via Ollama, but that model's Ollama distribution has been frozen at v1 since 2024 — Mixedbread's 2026 flagship (Wholembed v3) is hosted-only. For an open-weight upgrade path the field has moved to [Qwen3-Embedding](https://huggingface.co/Qwen) and Jina v5. Re-evaluate at phase 2 if retrieval quality is the bottleneck.

## Freshness audit

This page dates fast — model names, CLI verbs and node-pack repos churn. **Before bootstrapping a new machine, re-verify these upstream pages**; they are the canonical sources:

| Layer | Re-verify at |
|---|---|
| MLX inference | [mlx-lm/SERVER.md](https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md) |
| MLX model quants | [huggingface.co/mlx-community](https://huggingface.co/mlx-community) (sort by downloads) |
| Frontier open models | [huggingface.co/Qwen](https://huggingface.co/Qwen) · [huggingface.co/deepseek-ai](https://huggingface.co/deepseek-ai) |
| HF CLI | [huggingface_hub CLI guide](https://huggingface.co/docs/huggingface_hub/guides/cli) — `hf` (not `huggingface-cli`) since 2026 |
| Ollama | [docs.ollama.com](https://docs.ollama.com/faq) |
| LiteLLM | [docs.litellm.ai/docs/proxy/quick_start](https://docs.litellm.ai/docs/proxy/quick_start) |
| Jan | [janhq/jan](https://github.com/janhq/jan) |
| AnythingLLM | [docs.anythingllm.com](https://docs.anythingllm.com/installation-desktop/macos) |
| Aider | [aider.chat/docs/llms/openai-compat.html](https://aider.chat/docs/llms/openai-compat.html) |
| opencode | [github.com/sst/opencode](https://github.com/sst/opencode) |
| Draw Things | [drawthings.ai](https://drawthings.ai) |
| ComfyUI + node packs | [comfyanonymous/ComfyUI](https://github.com/comfyanonymous/ComfyUI) · [city96/ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF) |

When something on this list goes stale, fix it in place and bump a "last freshness audit" note here so the next bootstrap doesn't repeat the same hunt.

**Last freshness audit:** 2026-05-12.
