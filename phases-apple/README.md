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
| [`phase-0/`](phase-0/) | Jan-as-full-MLX-stack one-shot: install Jan, chat with a local MLX model, confirm Apple Silicon LLMs work for you. Disposable; no extension to agentic coding. | scoped |
| [`phase-1/`](phase-1/) | SOV-style composable stack: `mlx_lm.server` + LiteLLM + Jan-as-thin-client + Aider. Unlocks agentic coding. | scoped |
| `phase-2/` | RAG: Marker + LanceDB + AnythingLLM over a Zotero subset; cloud-fallback aliases in LiteLLM | pending |
| `phase-3/` | Stretch model + vision: `local-big` and Qwen3-VL-8B loaded on demand | pending |
| `phase-4/` | Side quests: LibreChat (web UI + MCP testing via OrbStack), opencode (Claude-Code-alike), Draw Things, ComfyUI, Stable Audio Open if motivated | pending |

## Operational discipline

Documented properly per sub-phase; for now, the rules that apply throughout:

- **One MLX model at a time.** `mlx_lm.server` is one model per process. Use [`bin/model-switch.sh`](bin/) to swap. Don't leave two big models loaded "just in case."
- **Ollama auto-evicts** with `OLLAMA_KEEP_ALIVE=15m`. Embedding model gets pulled on demand and freed shortly after.
- **Don't run Draw Things or ComfyUI alongside `local-big`.** GPU contention will stall both. Phase 4 documents the cohabitation rules.
- **Pre-pull weights** before flight mode: `hf download <repo>` (the old `huggingface-cli` is deprecated as of 2026). Install with `uv tool install hf` — the standalone slim CLI package on PyPI. The heavier `huggingface_hub` library also ships `hf`, but `hf` alone is the cleaner install when you only want the CLI. First-token-after-flight should not wait on the network.
- **Watch unified-memory pressure**, not free RAM. macOS swaps aggressively before showing low free memory, and swap on an LLM is unusable. `mactop` ([metaspartan/mactop](https://github.com/metaspartan/mactop)) is the live view; [`bin/model-status.sh`](bin/model-status.sh) is the one-shot.
- **Update mlx-lm every few weeks** (`uv tool upgrade mlx-lm`). New Qwen / DeepSeek releases need fresh architecture support.
- **LiteLLM (phase 1 onward) pinned by digest, never internet-exposed.** Pin a known-good version ≥1.83.7 (CVE-2026-42208 pre-auth SQL injection fixed there; a March 2026 PyPI supply-chain attack pushed malicious 1.82.7/1.82.8). On a laptop the blast radius is small but the discipline is identical to the cloud-track rule. **Bind loopback-only via [`bin/litellm-start.sh`](bin/litellm-start.sh).** LiteLLM defaults to `--host 0.0.0.0` (exposes the proxy to anyone on your wifi); it also reads an unscoped `HOST` env var as the fallback, which would collide with shells / ssh / web frameworks that all touch `HOST`. The wrapper scopes `HOST=127.0.0.1` to the litellm subprocess only and passes `--host 127.0.0.1` as belt-and-braces. No YAML config equivalent for host binding exists. If you must launch litellm directly without the wrapper, remembering `--host 127.0.0.1` is the load-bearing discipline.
- **Honest about what mlx-lm gives up vs. the cloud audition.** No built-in RadixAttention-style prefix cache, no xgrammar-class structured-output framework, no FP8 path on Apple Silicon. For prose editing, occasional code edits, and PDF Q&A the practical impact is unmeasured — possibly small. If you find sustained multi-turn agentic sessions (long Aider conversations, repeated RAG over the same shared prefix) feel materially slower than the same workflow against a cloud SGLang/vLLM endpoint, this is the likely cause. We haven't benchmarked it head-to-head and don't want to overclaim either direction.
- **Container runtime for compose-y workloads (phase 4 onward): [OrbStack](https://orbstack.dev) preferred, [Colima](https://github.com/abiosoft/colima) as the FOSS fallback. Avoid Docker Desktop.** OrbStack uses macOS's Virtualization.framework natively (real memory pressure, not VM-allocated-and-pinned), ~10× faster filesystem I/O than Docker Desktop, no nagware; closed-source, free for personal use, paid above commercial thresholds. Colima (Apache-2.0) is fully open-source and works fine for the workloads we'll throw at it — slower than OrbStack for I/O but no licensing concerns. Mirrors the [Draw Things exception](../docs/decisions/0004-apple-laptop-personal-track.md) (closed-source GUI acceptable where it saves material time; FOSS alternative documented). Docker Desktop's eager-VM model and recurring upgrade nags are out of step with the rest of this track and we're not the audience for either.
- **Run commands from the repo root.** Every path in a phase runbook (`./phases-apple/bin/model-switch.sh`, `phases-apple/phase-1/litellm-config.yaml`, etc.) is repo-relative. Stay `cd`-ed to the repo root unless a step explicitly says otherwise; direnv loads `.envrc` correctly, helper scripts can find each other, and the docs stay legible. Tools that take a `--config <path>` (like LiteLLM) expect the repo-relative path you read in the doc — no copying config files into your home directory.

## Helpers

| Script | Job |
|---|---|
| [`bin/model-switch.sh`](bin/model-switch.sh) | Kill the running mlx-lm.server, launch a new one by alias, wait for health |
| [`bin/model-status.sh`](bin/model-status.sh) | One-shot summary: Ollama, MLX process, memory pressure, HF cache disk |
| [`bin/litellm-start.sh`](bin/litellm-start.sh) | Launch the LiteLLM proxy with `HOST=127.0.0.1` scoped to the subprocess (avoids polluting shell env) + explicit `--host 127.0.0.1` belt-and-braces |

## Why Jan as a thin client, not as a full stack

Jan was designed to be self-contained — it ships [Cortex](https://github.com/janhq/cortex.cpp) (a llama.cpp / GGUF runtime) and, since [Jan 0.7.7](https://github.com/janhq/jan/releases/tag/v0.7.7) (Feb 2026), a native MLX backend bundled inside the app. The Configurable Model Providers feature we use here — pointing Jan at `http://127.0.0.1:8080/v1` — is a bolt-on, not Jan's design centre. There are three coherent ways to run Jan on Apple Silicon; SOV picks the middle one:

| Posture | Engine | "Easy" | Composable with SOV stack |
|---|---|---|---|
| Jan as full MLX stack | Jan's native MLX backend (0.7.7+) | ✅ one app, one window | ❌ — Jan owns the model lifecycle, port, params |
| **Jan as thin client to `mlx_lm.server`** (this track) | External `mlx_lm.server` launched by `bin/model-switch.sh` | ⚠️ two things to start | ✅ — fits LiteLLM, `model-switch.sh`, cross-track parity |
| Jan as full GGUF stack via Cortex | llama.cpp / Cortex (Jan's default) | ✅ one app | ❌ and slower on Apple Silicon than MLX |

The MLX-in-Jan path is a legitimate alternative for someone doing laptop-only LLM work with no interest in the SOV stack — same MLX speed advantage, single-app convenience, Jan handles model download / parameter UI / lifecycle. We pass on it for three SOV-specific reasons:

1. **LiteLLM (phase 1) needs a backend at a fixed `localhost:8080`** you control. Jan's internal MLX runtime isn't designed to be that endpoint.
2. **`bin/model-switch.sh` discipline is cross-phase.** Jan's internal model picker doesn't compose with it.
3. **Cross-track muscle memory.** Jan on the cloud audition is also a thin client (against vLLM); keeping the apple-track posture identical means you don't context-switch UI behaviours between the two.

**One concrete friction to watch for in either posture:** Jan launches its internal runtime(s) on startup whether or not you're using them. The "spinner waiting for a model server" you may see on first launch is Cortex / the MLX backend starting up, not Jan failing to connect to your external endpoint. On a 128 GB box it's invisible; on tighter machines you may want to disable internal-runtime auto-start in **Settings → Local API Server** so RAM isn't pre-allocated to runtimes you don't use. Don't let Jan auto-download models either — use `hf download` so the cache discipline below applies and `bin/model-status.sh` reflects reality.

## Why runtime choice changes "MLX speed"

A common confusion: "the same MLX model runs at different tok/s in Ollama vs LM Studio vs Jan vs `mlx_lm.server` — why?" Because **a model file is inert weights; speed is a property of the stack that runs it.** The weights are maybe 10% of the story. Observed throughput is roughly:

```
tok/s ≈ f( which engine, engine version, quant variant,
           inference features, runtime/IPC overhead,
           generation defaults, memory headroom )
```

| Layer | Why it moves the number |
|---|---|
| **Engine identity** | Biggest one. [Ollama](https://github.com/ollama/ollama) is **not an MLX runtime** — it runs **GGUF** via [llama.cpp](https://github.com/ggml-org/llama.cpp)'s Metal kernels, an independently-written engine from [MLX](https://github.com/ml-explore/mlx). Comparing Ollama to an MLX runtime is GGUF-vs-MLX, not a fair "same model" test. [LM Studio](https://github.com/lmstudio-ai/mlx-engine) and [Jan ≥0.7.7](https://github.com/janhq/jan/releases/tag/v0.7.7) ship *both* a llama.cpp engine and an MLX engine; which one runs depends on the model you pick. |
| **Engine version skew** | MLX kernels (fused attention, faster quant matmul) improve monthly. Each app vendors a *pinned* `mlx`/`mlx-lm`; a 3-month-old bundled MLX is materially slower than current for the identical model. `mlx_lm.server` lets you `uv tool upgrade mlx-lm` — you control this. |
| **Quant variant** | "[MLX 4-bit](https://huggingface.co/docs/hub/en/mlx)" is underspecified: group size (32/64/128), which tensors are quantized (embeddings? `lm_head`?). Two apps' "4-bit" of the same model can differ in memory traffic → speed (and quality). Some apps silently re-quantize on import. |
| **Inference features** | Speculative decoding (draft model) = 1.5–3× on the same target. Prompt/KV-cache reuse vs recompute-every-turn = large multi-turn divergence. KV-cache quantization, max-context allocation. |
| **Runtime / IPC overhead** | Per-token, a fast MoE (Qwen3.5-A3B, 3 B active) is so cheap that *wrapper overhead dominates*. `mlx_lm.server`: tight Python loop + one loopback HTTP hop. LM Studio: lean managed subprocess. Jan: Electron ↔ backend subprocess ↔ OpenAI-compat HTTP, more layers. Gap *widens* on small/fast models, *shrinks* on big ones (compute dominates). |
| **Generation defaults** | Context length, sampler complexity (`min_p`+`top_k`+repetition-penalty is more per-token work than greedy), batch size, fused-attention on/off. Apps ship different invisible defaults. |
| **Memory headroom** | MLX uses unified memory; cross into pressure and macOS swaps → *cliff*, not slope (10× slowdowns). Two apps sizing KV caches differently can land on opposite sides. This is what `bin/model-status.sh`'s swap canary and the `mactop` rule above guard against. |

**Why this justifies `mlx_lm.server` for the SOV apple track:** version you control (skew), quant you chose via `hf download` (no silent re-quant), one documented HTTP hop (predictable overhead), explicit defaults (in the curl/config, not buried in a settings panel), and `model-status.sh` + `mactop` observability (which side of the memory cliff). The apps are *easier*; `mlx_lm.server` is *legible and reproducible* — the right trade for a track whose point is mirroring a controlled stack.

References: [MLX](https://github.com/ml-explore/mlx) · [mlx-lm](https://github.com/ml-explore/mlx-lm) ([SERVER.md](https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md)) · [llama.cpp](https://github.com/ggml-org/llama.cpp) · [LM Studio mlx-engine](https://github.com/lmstudio-ai/mlx-engine) · [LM Studio API docs](https://lmstudio.ai/docs/app/api) · [Jan 0.7.7 release notes](https://github.com/janhq/jan/releases/tag/v0.7.7) · [Ollama](https://github.com/ollama/ollama) · [HF MLX format](https://huggingface.co/docs/hub/en/mlx).

## Cleanup & disk management

The Hugging Face cache at `~/.cache/huggingface/` accumulates relentlessly — every `hf download` lands a new revision, MoE weight shards are big, nothing is ever auto-removed. Budget on disk hygiene every few weeks.

The relevant `hf` subcommands (current as of 2026; the old `huggingface-cli` aliases are deprecated):

| Command | Job |
|---|---|
| `hf cache ls` | List cached repos with sizes; the "largest repos" block in [`bin/model-status.sh`](bin/model-status.sh) is a five-row version of this. |
| `hf cache rm <repo>` | Remove a specific cached repo. Example: `hf cache rm mlx-community/<old-quant-name>` after a model upgrade leaves the older quant unused. Pick exact repo names from `hf cache ls` output. |
| `hf cache prune` | Remove detached revisions — orphaned blobs left behind when a repo updated and the new revision replaced the old. Safe by default; doesn't touch current revisions. Run this monthly. |
| `hf cache verify <repo>` | Sanity-check checksums for one repo. Useful if you suspect a partial download. |

**Don't `rm` a model that `mlx_lm.server` is currently serving.** The process holds open file handles via `mmap`; on macOS the rm "succeeds" but the disk space isn't reclaimed until the process exits, and the next load may fail or read junk. Use `model-switch.sh off` first, then evict.

To move the cache off the boot volume (large models on an external SSD, say), set `HF_HOME` in your `.envrc.local` — direnv will export it to every `hf` and `mlx_lm` process automatically.

### Time Machine / backup exclusions

Model weights are the single biggest way this stack will balloon a Time Machine (or any incremental) backup. They're also the most pointless thing to back up — every byte is re-downloadable. Exclude the model/cache directories before your first backup after bootstrapping.

Sizes below are indicative (from one 128 GB Mac mid-phase-1); yours will differ. The "reconstruct via" column is why none of this is worth backup space.

| Path | Typical size | What | Reconstruct via |
|---|---|---|---|
| `~/.cache/huggingface` | 20 GB+ and growing | mlx-lm / `hf download` model cache — the big one | `hf download` |
| `~/.cache/uv` | 10–20 GB | uv build/package cache | re-resolved on next `uv` run |
| `~/.ollama/models` | grows with use | Ollama GGUF blobs (embeddings etc.) | `ollama pull` |
| `~/.lmstudio` | several GB | LM Studio models + runtime backends (if installed) | re-download in app |
| `~/Library/Application Support/Jan/data/llamacpp/models` | several GB | Jan's Cortex/GGUF models | re-download in Jan |
| `~/Library/Application Support/Jan/data/mlx/models` | grows if Jan-as-MLX used | Jan's native-MLX models | re-download in Jan |
| `~/.local/share/uv` | 2–3 GB | installed uv tools (mlx-lm, litellm, aider…) | re-run the `uv tool install` lines |

`Jan` and `jan` under Application Support are the **same directory** (case-insensitive APFS — same inode), not two; don't double-count or double-exclude.

Apply as **sticky path exclusions** (`-p`) so they survive the tools deleting and recreating these dirs — a plain `tmutil addexclusion` sets an xattr that's lost on recreate, which is exactly what caches do:

```bash
sudo tmutil addexclusion -p ~/.cache/huggingface
sudo tmutil addexclusion -p ~/.cache/uv
sudo tmutil addexclusion -p ~/.ollama/models
sudo tmutil addexclusion -p ~/.lmstudio
sudo tmutil addexclusion -p "$HOME/Library/Application Support/Jan/data/llamacpp/models"
sudo tmutil addexclusion -p "$HOME/Library/Application Support/Jan/data/mlx/models"
# optional — only if you accept re-running the uv tool installs after a restore:
sudo tmutil addexclusion -p ~/.local/share/uv
```

Verify:

```bash
for p in ~/.cache/huggingface ~/.cache/uv ~/.ollama/models ~/.lmstudio \
  "$HOME/Library/Application Support/Jan/data/llamacpp/models"; do
  tmutil isexcluded "$p"
done
```

Judgement calls:

- **Jan: exclude the two `*/models` subdirs, not the whole `Jan/` dir.** The parent also holds conversation history and settings — small and worth keeping. If you don't care about Jan chat history, excluding `"$HOME/Library/Application Support/Jan"` wholesale is simpler.
- **LM Studio: exclude `~/.lmstudio` wholesale.** None of it is precious if LM Studio isn't a primary client (and on this track it isn't — see [Why Jan as a thin client](#why-jan-as-a-thin-client-not-as-a-full-stack)).
- **`~/.cache/huggingface` is the win** — the one that actually matters; everything else is rounding error by comparison.

#### Image-gen tools (phase 4 — paths confirmed when installed)

Not on the critical path until [phase 4](#sub-phases), but they balloon backups harder than the LLM side (Flux/SDXL/video weights run to tens of GB):

- **Draw Things** (sandboxed Mac App Store app): models at `~/Library/Containers/com.liuliu.draw-things/Data/Documents/Models` ([Draw Things docs](https://docs.drawthings.ai/documentation/documentation/2.models)). Clean single-path exclusion — *unless* you've used Draw Things' [External Model Folder Setting](https://wiki.drawthings.ai/wiki/External_Model_Folder_Setting) to relocate models (common on a high-RAM Mac running an external SSD), in which case exclude wherever you pointed it.
- **ComfyUI Desktop**: app state (config + logs, ~MB, *keep these*) is at `~/Library/Application Support/ComfyUI` and `~/Library/Logs/ComfyUI`. **Weights have no fixed default** — the install directory is chosen in the setup wizard (commonly `~/Documents/ComfyUI` but not forced; `brew install comfyui` differs again). Find the real path via the app's **Help → Open Folder → Open Model Folder**, or check `~/Library/Application Support/ComfyUI/config.json` / `extra_models_config.yaml`. Exclude `<that-install-dir>/models`. This one can't be blind-scripted; confirm per-install. The phase-4 doc will pin the exact exclusion once ComfyUI is actually in the track.

## Open questions

- **MCP-based RAG inside Jan vs. dedicated AnythingLLM.** Phase 2 uses AnythingLLM for time-to-working. A later phase may swap to a Zotero MCP server feeding Jan directly, which is more SOV-spirit (composable parts). Decision deferred to phase-2 retro.
- **opencode adoption.** Phase 4 scopes it as an Aider-alternative experiment. If it works well on `local-small`, may promote it; if it's too token-hungry for 30B-class models, stays an experiment.
- **Cloud routing through LiteLLM.** Phase 2 wires Anthropic / OpenAI into LiteLLM as fallback aliases for when local context is insufficient (deferred from phase 1 to keep the SOV-style stack rollout focused on local-only first). Flight-mode behaviour: model alias errors out cleanly if upstream unreachable, the local aliases keep working.
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
