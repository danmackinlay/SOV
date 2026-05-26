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

## Stack vocabulary

A local-LLM setup is a vertical stack of layers, and most "this app is faster than that one" or "why doesn't X work with Y" debates are really about which layer changed. The names below are the lingua franca for the rest of this doc (and a near-mirror of the [companion blog notebook's](https://danmackinlay.name/notebook/local_llm_mac.html#the-stack) version):

| Layer | What | Apple-track default | Other options |
|---|---|---|---|
| **Model** | The weights — `.safetensors`, distributed from Hugging Face | Qwen3.5-35B-A3B etc. (see [Models](#models)) | Any HF-distributed open-weight model |
| **Quant format** | How weights are stored on disk; different runtimes read different formats | MLX 4-bit (mlx-community ports) | GGUF (llama.cpp / Ollama), JANGTQ (Osaurus/jang-tools), `mxtq`, AWQ, FP8, … |
| **Runtime / inference engine** | The code that runs the matmuls — where the GPU work happens | MLX via `mlx-lm` (Python) | llama.cpp (via Cortex/Ollama), `vmlx-swift-lm` (via Osaurus, Swift), `ds4` (native Metal, V4-Flash only) |
| **Server / daemon** | Long-lived process exposing an OpenAI-compatible HTTP endpoint | `mlx_lm.server` on `:8080` | Ollama (`:11434`), Osaurus (`:1337`, also Anthropic + Ollama compat), `ds4-server` (`:8000`), `llama-server` |
| **Harness / agent loop** | Orchestration over the server — conversation state, tool calls, multi-turn agent loops, model switching | Aider for code; Jan for chat (Jan is a *thin* harness) | [`pi`](#pi-as-the-cross-track-harness) (npm, cross-platform, provider-agnostic), Osaurus (built-in), OpenCode, Continue, Claude Code (vendor-locked) |
| **Frontend / chat client** | The human-facing surface | Jan | Osaurus's chat window, LibreChat, LM Studio, web UIs, terminal TUIs (`pi`'s own) |

Most apps you've heard of are *vertical bundles*: Osaurus is frontend + harness + server + runtime in one; Ollama is server + runtime; Jan-as-thin-client is frontend pointed at someone else's server. SOV's apple-track default is the *unbundled* version — `mlx-lm` runtime, `mlx_lm.server` daemon, Aider/pi harness, Jan frontend — so any one layer can swap without disturbing the rest. The [Jan-thin-client](#why-jan-as-a-thin-client-not-as-a-full-stack) discussion, the [Osaurus-as-comprehensive-alternative](#osaurus-as-a-comprehensive-swift-native-alternative) discussion, and the [pi-as-cross-track-harness](#pi-as-the-cross-track-harness) discussion are all variations on "swap one layer, keep the rest."

The **harness layer** is where the apple-track / cloud-track muscle memory actually lives. A harness manages conversation state and connects to whichever OpenAI-compatible endpoint you point it at — that endpoint can be a local `mlx_lm.server`, a LiteLLM proxy, the audition's vLLM-on-RunPod, or Anthropic / OpenAI cloud APIs. **Picking a provider-agnostic, no-GUI-lock-in harness is what collapses the apple-personal and cloud-cooperative experiences into the same workflow.** The blog post's [member-side-stack section](https://danmackinlay.name/notebook/aus_sovereign_llm.html#the-member-side-stack) applies the same idea to the cooperative case.

## Stack at a glance

| Layer | Pick | Install | Why |
|---|---|---|---|
| MLX inference | `mlx-lm` | `uv tool install mlx-lm` | Fastest path for big reasoning models on Apple Silicon |
| GGUF fallback + embeddings | Ollama (kept) | `brew install ollama` (already done) | Embedding model auto-evict; GGUF coverage when MLX lags |
| Routing | LiteLLM proxy | `uv tool install 'litellm[proxy]'` | Single endpoint, model aliases, mix local + cloud |
| Chat client | Jan | DMG from [jan.ai](https://jan.ai) | Native macOS, points at LiteLLM, flight-mode capable |
| Editor agent | Aider | `uv tool install aider-chat` | Diff-based edits work on local models; prose-friendly |
| Cross-track harness | [`pi`](#pi-as-the-cross-track-harness) | per [earendil-works/pi](https://github.com/earendil-works/pi) ([details](#pi-as-the-cross-track-harness)) | Provider-agnostic CLI harness; same binary works against local `mlx_lm.server`, LiteLLM, the SOV cloud audition, and Anthropic — the layer that collapses apple-personal and cloud-cooperative into one workflow |
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

**Long-context-friendly alternative for `local-big`:** [DeepSeek V4-Flash](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash) (13 B active, 284 B total; April 2026). The interesting bit is the **DSA sparse attention**: per DeepSeek's tech report a full million-token context costs ~9.6 GB of KV cache instead of the tens of GB a conventional 13 B-active model would use. Practical apple-side implication: long-context workloads (sustained Aider sessions, large RAG queries) hit the KV-cache cliff much later than they would on Qwen3.5-122B-A10B — and laptops are exactly the regime where that matters, because unified-memory budgets are tight. See [ADR 0007](../docs/decisions/0007-deepseek-v4-and-the-concurrency-consequence.md) for the worked arithmetic (cloud-side, illustrative); apple-side numbers will differ proportionally with available memory.

### Decisions

The 50+ community V4-Flash quants on Hugging Face split into "drop in to `mlx_lm.server` and use the SOV-style stack" versus "needs a custom loader and runs outside the scaffolding." We adopt one of each:

- **Main-stack pick: [`mlx-community/DeepSeek-V4-Flash-2bit-DQ`](https://huggingface.co/mlx-community/DeepSeek-V4-Flash-2bit-DQ)** (~96.5 GB resident). Dynamic mixed-precision quant: 2-bit on routed-MoE experts, 4/6/8-bit on sensitive layers (attention projections, embeddings, lm_head). Vanilla `mlx-lm` loads it; no special tooling. Tight on a 128 GB Mac (leaves ~32 GB for OS + KV cache + apps) but workable for typical contexts; comfortable on Mac Studio class. When V4-Flash actually enters the apple track at [phase 3](#sub-phases), this is the `local-big` candidate that goes into [`bin/model-switch.sh`](bin/model-switch.sh).
- **Sideband experiment: [`OsaurusAI/DeepSeek-V4-Flash-JANGTQ2`](https://huggingface.co/OsaurusAI/DeepSeek-V4-Flash-JANGTQ2)** (~79.6 GB resident). 2-bit MXTQ on routed-expert MLPs + 8-bit affine on everything else, MTP head preserved. Smaller than `2bit-DQ` by ~17 GB on disk; the README argues the aggressive 2-bit holds because DSV4 routes top-6-of-256 experts per token plus a shared expert plus 3 hash layers, so per-token output averages codebook noise across 7+ pathways — much weaker quality constraint than top-1 architectures. **Plausible argument, unmeasured by us.** Needs a custom loader because the quant uses a non-standard `mxtq` codec that doesn't match vanilla MLX's `{bits, group_size}` quantization metadata — **LM Studio fails to load JANGTQ models with "Unsupported safetensors format: null"** (we tried; an earlier version of this doc claimed otherwise — that was wrong). The two paths that actually work:
    1. **[Osaurus](https://osaurus.ai)** ([osaurus-ai/osaurus](https://github.com/osaurus-ai/osaurus), MIT, native Swift, `brew install --cask osaurus`) — the intended runtime, by the same crew that uploads the JANGTQ models. See [Osaurus as a comprehensive Swift-native alternative](#osaurus-as-a-comprehensive-swift-native-alternative) below for what Osaurus is beyond the JANGTQ angle.
    2. **`jang-tools` Python loader** (`pip install jang-tools mlx-lm`) — the README's documented CLI path; no GUI, scriptable, useful if you want to wrap it in a custom server.

    Treated as a *parallel quality experiment* outside the SOV scaffolding; promote into the main stack only if (a) measured quality on real prompts holds and (b) someone packages a `mlx_lm.server`-compatible JANGTQ loader.

- **Native-Metal alternative: [DwarfStar / `ds4`](https://github.com/antirez/ds4)** by [antirez](https://github.com/antirez) (Salvatore Sanfilippo, of [Redis](https://redis.io)). Not a quant, not a runtime *plugin* — a **from-scratch single-model native Metal inference engine** for DeepSeek V4-Flash. No MLX, no Python, no PyTorch, no llama.cpp. The README is explicit about the scope: "a small native inference engine specific for DeepSeek V4 Flash. It is intentionally narrow: not a generic GGUF runner." Targets M3 Max, M3 Ultra, and M5 Max specifically. Independent benchmarks: ~14–15 tok/s decode at 62k context on M3 Max 128 GB; ~450 tok/s prompt-processing on M5 Max for a 10k-token codebase. The model file is a GGUF from antirez's own [HF org](https://huggingface.co/antirez/deepseek-v4-gguf) (~87 GB at the standard quant), unrelated to mlx-community or JANGTQ. Two ways to drive it:
    1. **Direct, via [`ds4-server`](https://github.com/antirez/ds4)** — a generic OpenAI-compatible endpoint on `127.0.0.1:8000`. Any harness or frontend can talk to it without further machinery; point Aider, LiteLLM, Osaurus, or `curl` at the port.
    2. **Via the [`pi` harness](#pi-as-the-cross-track-harness) and the [`mitsuhiko/pi-ds4`](https://github.com/mitsuhiko/pi-ds4) extension** — `pi install https://github.com/mitsuhiko/pi-ds4` clones antirez/ds4, builds it, downloads the GGUF, registers a `ds4/deepseek-v4-flash` model with pi, and handles per-PID lease + watchdog shutdown so the 87 GB-resident server doesn't sit idle. The most polished day-to-day experience if you're already on pi.

    **Spiritually-aligned variant: [`audreyt/pi-ds4`](https://github.com/audreyt/pi-ds4)** by [Audrey Tang](https://en.wikipedia.org/wiki/Audrey_Tang) (Taiwan's former Digital Minister) — a fork of mitsuhiko/pi-ds4 that swaps in [cyberneurova](https://huggingface.co/cyberneurova)'s **abliterated IQ2XXS quants** and turns on **uncertainty-mode directional steering** by default. This is an activation-space edit (analogous to abliteration, the same technique on the cloud-track [phase 2 workstream A](../PLAN.md#workstream-a-abliteration) roadmap) that puts the model into a "this is a contested question" register on prompts the unsteered model would emit a memorized closed-form answer to (Taiwan, Crimea, Kashmir, Western Sahara). Per the fork's README, a hedge-style system prompt alone does *not* flip the closed-form completion; the steering vector does, and the system prompt then supplies the specific positions to draw from. **Same bus-factor and scope caveats as JANG and antirez/ds4 apply** — one model, one author per fork, weeks-old at time of writing. Useful as a third reference point for what de-censored open-weight inference can actually feel like on a laptop.

This is now three tracks deliberately:
- **Vanilla `2bit-DQ` via `mlx_lm.server`** — keeps cross-track muscle memory intact (one stack, one launcher, one config).
- **JANGTQ2 via Osaurus** — sideband quality experiment we can compare against; loader is non-vanilla.
- **`ds4` via `ds4-server` (optionally through `pi-ds4`)** — entirely separate runtime; useful for benchmarking the SOV stack against a model-specific best-effort native engine, *and* for the abliterated-out-of-the-box experience via the `audreyt/pi-ds4` fork. All four of the named pi-ds4 contributors (antirez/Redis, mitsuhiko/Flask, badlogic/libGDX, audreyt/Pugs+Taiwan) converging on V4-Flash plus M-series Macs is a useful "this corner is taken seriously" signal even if the bus factor on each individual piece is small.

Active experiment status (as of 2026-05-26): Dan is currently testing all three — `pi` + `ds4` + Osaurus side-by-side on the same Mac. Findings will land back here as a [decisions §V4-Flash actuals](#decisions) update when the dust settles.

### Variants surveyed but passed on

For reference, in case the JANGTQ2 experiment goes sideways and we want to revisit:

| Repo | Size | Loader | Why passed |
|---|---|---|---|
| `inferencerlabs/DeepSeek-V4-Flash-MLX-2.8bit-EXP` | 102.2 GB | modified mlx fork | Author explicitly says "accuracy is degraded"; controlled experiment, not a recommendation. |
| `Thump604/DeepSeek-V4-Flash-MLX-Q2-mixed-gs128-affine` | 106.4 GB | vanilla `mlx-lm` | 106.94 GB peak measured on a 128 GB Mac Studio (zero swaps at 4k context), but author flags "not quality-qualified for production." Marginal headroom + same quality unknown as 2bit-DQ at higher cost. |
| `mlx-community/DeepSeek-V4-Flash-4bit` (and `-mxfp4`, `-nvfp4`) | 151.5 GB | vanilla `mlx-lm` | Doesn't fit 128 GB; Mac Studio 192 GB+ only. The `mxfp4`/`nvfp4` formats are about hardware-acceleration scaling on Blackwell, not bit-width reduction — same 151 GB. |

Caveats across the board:
- **No measured quality numbers for any aggressive V4-Flash variant** on the task suites we care about (math, code, long-context retrieval). Plausibility arguments and absence of obvious-incoherence claims are the state of the art. Phase-3 measurement is where we'd put real numbers behind these picks.
- **V4's `deepseek_v4` architecture is fast-moving.** ADR 0007 documents vLLM commit-sensitivity; the apple-side equivalent is to `uv tool upgrade mlx-lm` before pulling new V4 quants — mlx-lm's V4 support is itself under active development (Thump604's README explicitly lists FP4/FP8 handling, F8_E8M0 metadata reinterpretation, attention-sink dtype, and quantized grouped-output-projection fixes as in-progress).
- **Per-token speed** is slower than Qwen3.5-122B-A10B because V4-Flash has more active params (13 B vs 10 B); the win is long-context behaviour, not raw tok/s.

> **Model picks rot fast.** This table reflects May 2026. Before bootstrapping a fresh machine, re-check [mlx-community](https://huggingface.co/mlx-community), [Qwen](https://huggingface.co/Qwen) and [deepseek-ai](https://huggingface.co/deepseek-ai) for newer releases. The shape (MoE daily + dense math + larger-MoE stretch) is more durable than the specific repo names; substitute generation-for-generation as the families move.

## Sub-phases

Sub-phase directories are created when started, same convention as the main SOV phases.

| Directory | What | Status |
|---|---|---|
| [`phase-0/`](phase-0/) | Jan-as-full-MLX-stack one-shot: install Jan, chat with a local MLX model, confirm Apple Silicon LLMs work for you. Disposable; no extension to agentic coding. | scoped |
| [`phase-1/`](phase-1/) | SOV-style composable stack: `mlx_lm.server` + LiteLLM + Jan-as-thin-client + Aider. Unlocks agentic coding. | scoped |
| `phase-2/` | RAG: Marker + LanceDB + AnythingLLM over a Zotero subset; cloud-fallback aliases in LiteLLM | pending |
| `phase-3/` | Stretch model + vision: `local-big` (Qwen3.5-122B-A10B by default, or DeepSeek V4-Flash via [`2bit-DQ`](https://huggingface.co/mlx-community/DeepSeek-V4-Flash-2bit-DQ) for long-context-heavy workloads — fits 128 GB Macs tightly) and Qwen3-VL-8B loaded on demand. Two parallel experiments outside the main scaffolding: JANGTQ2 via Osaurus, and `ds4`/DwarfStar via `pi-ds4` (also enables the abliterated [`audreyt/pi-ds4`](https://github.com/audreyt/pi-ds4) fork) — see [V4-Flash decisions](#decisions). | pending |
| `phase-4/` | Side quests: LibreChat (web UI + MCP testing via OrbStack), opencode (Claude-Code-alike), [`pi`](#pi-as-the-cross-track-harness) (cross-platform harness, also useful as an apple-side dry-run for the cooperative member-side stack), Draw Things, ComfyUI, Stable Audio Open if motivated | pending |

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

## Osaurus as a comprehensive Swift-native alternative

[**Osaurus**](https://osaurus.ai) ([osaurus-ai/osaurus](https://github.com/osaurus-ai/osaurus), MIT, native Swift, 5k+ ★, active — latest release in the last 24 h at time of writing, `brew install --cask osaurus`) is the most ambitious of the alternative postures on the apple side. It is not a chat client like Jan, nor a runtime like `mlx_lm.server`, but a full **AI harness** that includes both and more:

- **Drop-in compatible APIs on `http://127.0.0.1:1337`**: OpenAI (`/v1/chat/completions`), Anthropic (`/anthropic/v1/messages`), Ollama (`/api/chat`). The Anthropic-compatible endpoint is directly relevant to [ADR 0007](../docs/decisions/0007-deepseek-v4-and-the-concurrency-consequence.md)'s observation that V4 ships a native Anthropic API — Osaurus is one place that path could land cleanly for Claude-Code-style clients.
- **Its own optimised MLX inference engine** (curated quants on [`huggingface.co/OsaurusAI`](https://huggingface.co/OsaurusAI), models stored under `~/MLXModels`).
- **MCP server *and* client** — exposes local tools to MCP-aware clients (`osaurus mcp` stdio bridge), and consumes URL-based remote MCP providers with OAuth/DCR for ~25 well-known integrations.
- **Apple Foundation Models bridge** on macOS 26+ (`model: "foundation"` — zero inference cost, on-device).
- **Agent loop with a sandboxed Linux VM** via Apple's Containerization framework (macOS 26+) — agents get shell / Python / Node in an isolated env, with a vsock bridge back to Osaurus for inference and tools.
- **Persistent agent memory, cryptographic identity (secp256k1), portable access keys, and a relay tunnel** (`agent.osaurus.ai`) for exposing agents to the internet without port forwarding.
- **Voice input via FluidAudio on the Apple Neural Engine** — one of the legitimate places ANE earns its keep ([ADR 0005](../docs/decisions/0005-apple-neural-engine.md)) — global hotkey transcription into any app.

### Why we don't adopt it as primary

For exactly the reasons we pass on Jan-as-full-stack: Osaurus is a *competing harness*, not a *composable part*. In principle it could replace `mlx_lm.server` + Jan + LiteLLM with a single Swift-native app. We don't because:

1. **Cross-track muscle memory.** SOV's cloud audition runs Jan as a thin client against vLLM via LiteLLM; the apple track mirrors that shape so collaborators don't context-switch. Osaurus is a different shape end-to-end.
2. **Composability.** `bin/model-switch.sh`, `bin/litellm-start.sh`, and the cwd-rooted runbook discipline assume small interchangeable parts. Osaurus owns the lifecycle.
3. **MLX quant scope.** Osaurus's curated MLX library is solid but narrower than the broader mlx-community catalogue; running an arbitrary `mlx-community/<repo>` requires more friction than vanilla `mlx-lm`.

### Why we add it to the documented options

- It's the **intended runtime for JANGTQ models** (see [V4-Flash Decisions](#decisions)). The earlier doc claim that LM Studio would load JANGTQ was wrong; Osaurus is the actual answer.
- The MCP server angle interacts directly with the [open question on MCP-based RAG inside Jan vs AnythingLLM](#open-questions) and with the cloud track's [LibreChat-for-MCP-testing](../docs/decisions/0003-audition-surface-and-auth.md) framing. If Osaurus's MCP server proves out, it might collapse some of that question.
- The **comprehensive-harness vs composable-parts** distinction is itself worth documenting. If a future collaborator wants the comprehensive path, Osaurus is the strongest candidate; we shouldn't bury that.
- **FOSS posture is strong** — MIT, Swift-native, no Electron, active maintenance. It would not be an exception to the closed-source-acceptable rule (the way Draw Things is); it's an outright FOSS competitor.

### Bus-factor caveat for the broader JANG ecosystem

One risk worth flagging up front: the **JANG / JANGTQ ecosystem is essentially one person**, [Jinho "Eric" Jang](https://github.com/jjang-ai), who maintains the JANG quantization format spec, the Swift engine ([`osaurus-ai/vmlx-swift-lm`](https://github.com/osaurus-ai/vmlx-swift-lm)) that Osaurus wraps, the Python engine ([`jjang-ai/vmlx`](https://github.com/jjang-ai/vmlx)), the [JANGQ-AI model zoo on Hugging Face](https://huggingface.co/JANGQ-AI), a sibling Mac app ([MLX Studio](https://github.com/jjang-ai/mlxstudio)), *and* the Osaurus app itself. The vertical integration is what makes Osaurus's JANGTQ support coherent and fast-moving; the cost is that bus factor for the format-and-zoo combination is 1. There is some community wariness about this — see the [r/LocalLLaMA "Is MLX Studio legit?"](https://www.reddit.com/r/LocalLLaMA/comments/1rzuazp/is_mlx_studio_legit_never_heard_of_it_before/) thread.

Mitigations: the code and format are MIT-licensed open source, so a community fork is possible if the author moves on; vanilla MLX quants (which Osaurus also loads) are unaffected. The risk is concentrated specifically on the JANGTQ-quantized models in the JANGQ-AI HF org — if those become orphaned, the loader path goes with them and we'd fall back to standard MLX quants. Acceptable given JANGTQ2 is already scoped as a sideband experiment, not a load-bearing track dependency.

### When you might actually use it

- **JANGTQ2 testing** (immediate). The sideband V4-Flash quality experiment lives here now.
- **MCP integration prototyping**, if you want to test "MCP-aware client → MCP server" loops without setting up LibreChat + OrbStack first.
- **Agent loop with sandboxed code execution**, if you want to compare Aider's diff-based editing against a more autonomous agent that can run shell/Python in a Linux VM.
- **As a benchmarking foil** to `mlx_lm.server`: Osaurus's Swift-native MLX engine is a clean comparison point against our Python `mlx_lm.server` for the [runtime-speed framework](#why-runtime-choice-changes-mlx-speed) above. Same MLX weights, different host code.

For routine SOV-style use, Jan-as-thin-client against `mlx_lm.server` remains the primary posture.

### Osaurus vs LM Studio

Honest assessment after the JANGTQ2 incident: **Osaurus dominates LM Studio on every axis that matters for the SOV apple track.** Documented here so future-us doesn't relitigate it:

| Axis | LM Studio | Osaurus | Winner |
|---|---|---|---|
| License | Closed-source proprietary | **MIT** | Osaurus |
| Native macOS | CEF-wrapped app | **Pure Swift, no Electron** | Osaurus |
| MLX inference engine | Yes (standard mlx format) | **Yes (standard mlx + JANGTQ + own curated quants)** | Osaurus |
| API surface | OpenAI-compat only | **OpenAI + Anthropic + Ollama compat** | Osaurus |
| MCP | Limited / recent | **Full MCP server *and* client, OAuth/DCR for ~25 providers** | Osaurus |
| Apple Foundation Models | No | **Yes (macOS 26+, `model: "foundation"`)** | Osaurus |
| Voice input on ANE | No | **Yes (FluidAudio, global hotkey)** | Osaurus |
| Agent loop with sandboxed VM | No | **Yes (Apple Containerization, macOS 26+)** | Osaurus |
| Persistent memory + cryptographic identity | No | **Yes (secp256k1, three-layer memory)** | Osaurus |
| Model browser UX | Polished, broad HF browse | Curated `OsaurusAI` library + arbitrary HF | LM Studio slightly |
| Familiarity / tutorials | Larger ecosystem | Newer | LM Studio slightly |

The two "slightly" rows are real but minor: LM Studio's model-discovery UI is more developed, and there's more third-party tutorial content for LM Studio out there. Neither outweighs the licensing posture, the API breadth, or the MCP/agent capabilities — and they're convergence-time issues that close further as Osaurus matures.

**Implication for this track:** LM Studio drops out of the recommended-alternative tier. If you have it installed from earlier exploration, leave it or uninstall as you prefer; we don't suggest installing it fresh. Osaurus replaces it as "the more-capable single-app alternative to the SOV-style composable stack."

LM Studio remains in the [Why runtime choice changes "MLX speed"](#why-runtime-choice-changes-mlx-speed) section below as one of several runtimes that illustrate the variance-source framework — that's an educational example, not a recommendation.

## `pi` as the cross-track harness

[**`pi`**](https://github.com/earendil-works/pi) ([earendil-works/pi](https://github.com/earendil-works/pi), MIT, npm-installable — see the upstream README for the current install incantation, which has churned during early development) is [Mario Zechner](https://github.com/badlogic)'s ([libGDX](https://libgdx.com)) cross-platform agent harness. It is the **harness layer** of the [stack vocabulary](#stack-vocabulary) above — manages tool-call loops, conversation state, slash commands; talks to whichever OpenAI- or Anthropic-compatible endpoint you point it at. Not a runtime, not a chat window in the Jan/LM-Studio/Osaurus sense (though it has a built-in TUI). Specifically:

- **Cross-platform** — Node, runs on macOS, Linux, Windows, **and Android** via Termux.
- **Provider-agnostic by design** — 15+ named providers (Anthropic, OpenAI, Google, xAI, Groq, Cerebras, …) plus arbitrary OpenAI- or Anthropic-compatible endpoints via a small JSON config (`~/.pi/agent/models.json`). The collective endpoint, your local `mlx_lm.server`, the SOV phase-1 LiteLLM proxy, the SOV cloud audition's vLLM-on-RunPod, your Anthropic key, and your Ollama instance can all sit in the same config; switch between them with `/model` or `Ctrl+L` inside an active session.
- **Harness-only** — no GUI lock-in, no bundled chat window beyond the TUI, no opinions about which runtime or model serves your tokens. The composability of the SOV apple track survives.
- **Extension model** — `pi install <github-url>` for plugins. Used in the [V4-Flash decisions](#decisions) section by `mitsuhiko/pi-ds4` and `audreyt/pi-ds4` to bolt antirez's `ds4` runtime onto the harness with per-PID lease and watchdog shutdown.
- **Agent runtime with tool calling** — the conventional harness features (file edits, shell, web fetch via MCP, etc.) are there; not as polished as Aider's diff-based flow for code edits, but more general.

### Why pi is the Schelling point we think it is

The harness layer is structurally where the apple-track and cloud-track converge — Aider, OpenCode, Continue, Cursor, Claude Code all live there, and most of them are bundled with either an editor (Cursor, Continue), a vendor's API (Claude Code), or a specific workflow style (Aider's diffs). `pi` is the rare member of that category that's **(a) provider-agnostic by design, (b) not bundled with a GUI, (c) MIT-licensed, (d) cross-platform, (e) extension-driven, and (f) being adopted by the people who already write the engines underneath** — the antirez-mitsuhiko-badlogic-audreyt convergence around V4-Flash on M-series Macs (see [V4-Flash decisions](#decisions)) is a small-but-real Schelling signal. If a single harness becomes the "semi-pro local-LLM" default the way Aider became the "small-team coding assistant" default, `pi` is the candidate.

For SOV specifically:

- **Apple-track:** A pi config that lists `local-small` / `local-math` / `local-big` (via the phase-1 LiteLLM proxy at `127.0.0.1:4000`), the audition's cloud endpoint, and a fallback to Anthropic, gives a member exactly one harness across all three. The `/model` swap inside a session is the failover from "local is fine" → "I need the big one" → "the audition node is up, try that" → "everything's down, hit Anthropic." Same muscle memory throughout.
- **Cloud-track parity:** The blog post's [member-side-stack section](https://danmackinlay.name/notebook/aus_sovereign_llm.html#the-member-side-stack) is explicit that the cooperative case looks the same — the collective owns the *server* (vLLM on the DGX), each member picks their own harness and frontend. `pi` is the harness that fits that model with the least friction. Adopting it apple-side now is also a dry-run for the cloud-side member experience.
- **Phase-2 abliteration roadmap:** [`audreyt/pi-ds4`](https://github.com/audreyt/pi-ds4) ships abliterated-by-default V4-Flash through pi. That is the same maneuver SOV cloud-track [phase 2 workstream A](../PLAN.md#workstream-a-abliteration) is targeting, on a different model, at much smaller scale — useful as a working reference for what "the abliterated experience" actually feels like from inside a real harness, *now*, before we spend any cloud GPU time generating our own weights.

### Why we don't (yet) make it primary

- **Phase 1 ships with Aider** because Aider's diff-based code-editing flow is sharper than pi's general tool-calling for the specific workflow we want to test at phase 1 (small Qwen-class models doing code edits). Aider stays the recommended workhorse for the "is the apple stack actually useful for coding" question. pi sits beside it, not above it.
- **Cross-track muscle memory is still real.** The cloud audition's phase-1 surface is LibreChat-the-frontend + vLLM-the-server (per [ADR 0003](../docs/decisions/0003-audition-surface-and-auth.md)); the harness layer there isn't pinned to pi yet either. If phase-2 workstream B picks a different harness as the canonical agentic POC, the apple track will probably mirror that.
- **It's young.** Active development, fast-moving API, small community relative to Aider or Claude Code. Adopt with the same posture as JANGTQ — useful, watched, not yet load-bearing.

### When you'd use pi today

- **Active experimentation against `ds4`** (see [V4-Flash decisions](#decisions)) — the `pi-ds4` extensions are the polished path.
- **Multi-provider session** where you want to swap models mid-conversation — Anthropic for one turn, local Qwen for the next, cloud audition for a third.
- **Android or Linux client** against the apple-track LiteLLM proxy or the SOV cloud audition — pi is one of the few harnesses that runs natively on both.
- **As a benchmarking foil** to Aider for the same workload — same backend, different harness, see what the harness layer actually costs.

For the SOV phase-1 default (Aider against `local-small` via LiteLLM), nothing changes. pi is *additive* — install it alongside Aider, point it at the same LiteLLM proxy, use whichever fits the task.

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

## Memory: the wired-RAM ceiling

The cliff we keep alluding to has a specific shape worth knowing. The operational-discipline bullet says "watch unified-memory pressure, not free RAM" — this section is the *why* and what to do about it.

**macOS "Memory Used" is misleading.** It folds the file cache into the "used" total, and the file cache is reclaimable on demand. The metric that matters is **Memory Pressure** (green / yellow / red in Activity Monitor, or `Pages purgeable` / `Pages compressed` from `vm_stat`). A 128 GB Mac showing 120 GB "used" with green pressure has plenty of room.

But there is a separate, **hard cap** that bites MLX specifically.

### The wired-limit

Apple sets a hard ceiling on how much RAM Metal — and therefore MLX — is allowed to *wire* (lock into physically resident, GPU-accessible memory). The default is **~67% on Macs ≤36 GB and ~75% on larger ones**. On a 128 GB Mac that means **MLX refuses to allocate past ~96 GB**, regardless of how much actually-free memory there is. That is exactly where the [`mlx-community/DeepSeek-V4-Flash-2bit-DQ`](#decisions) pick (96.5 GB resident) sits — *at* the default cliff — which explains why JANGTQ2 at 79.6 GB feels comfortable and `2bit-DQ` feels tight on the same hardware. The cliff isn't a swap-pressure cliff; it's an MLX-allocator refusal.

Raise it at runtime (Sonoma 14.x+):

```bash
# Cap MLX at 112 GB — leaves ~16 GB for the OS and other apps
sudo sysctl iogpu.wired_limit_mb=114688

# Confirm
sudo sysctl iogpu.wired_limit_mb

# Reset to default
sudo sysctl iogpu.wired_limit_mb=0
```

Not persistent across reboots — wrap in a LaunchDaemon or `/etc/sysctl.conf` entry to make it sticky if you'll routinely run near the limit.

**Do not set it to the full 128 GB.** If MLX wires more than the OS can spare, the machine kernel-panics — Michael Hannecke's [postmortem](https://medium.com/@michael.hannecke/how-my-local-coding-agent-crashed-my-mac-and-what-i-learned-about-mlx-memory-management-e0cbad01553c) is the cautionary tale. Leave at least 10–16 GB of headroom; on a machine running Slack and Chrome alongside, more.

Both `mlx_lm.server` and the Swift `vmlx-swift-lm` engine that [Osaurus](#osaurus-as-a-comprehensive-swift-native-alternative) wraps call `mx.set_wired_limit()` on startup, coordinating the limit across concurrent requests. The Swift side's [wired-memory documentation](https://swiftpackageindex.com/ml-explore/mlx-swift-lm/3.31.3/documentation/mlxlmcommon/wired-memory) is the upstream reference.

### Pre-launch housekeeping

Before launching a memory-tight model run:

- **`sudo purge`** flushes the file cache so the OS has clean room to allocate. Available RAM jumps; subsequent file I/O is slower until the cache refills.
- **Quit Electron apps.** Slack, Discord, Cursor, VS Code, Chrome each routinely pin 4–8 GB. The savings compound.
- **`export MLX_LM_CACHE_LIMIT=0`** prevents MLX's internal allocation cache from growing unboundedly during long sessions — useful for sustained embedding or agent workloads where the cache otherwise creeps up over hours.
- **`mactop`** in another pane to watch pressure, swap-out rate, and GPU memory utilization live; [`bin/model-status.sh`](bin/model-status.sh) is the one-shot equivalent.

### When the model genuinely doesn't fit

Two escape valves once you've raised the wired limit and done the housekeeping:

- **JANGTQ-class mixed-precision quants** at the low end (see [V4-Flash Decisions](#decisions)). JANGTQ2 at 79.6 GB fits a 284 B-parameter model in the wired-limit budget where vanilla 4-bit MLX cannot. Same trick generalises to other models when JANG ports exist.
- **Smelt mode** in [MLX Studio / vMLX](https://github.com/jjang-ai/mlxstudio) — for MoE models, loads only a subset of experts into RAM and keeps the rest on SSD. Quality stays coherent; throughput drops because expert swaps hit SSD on the hot path. Not in the SOV-style stack, but worth knowing exists if you're testing the edge of fit-on-this-machine.

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

### Backup & indexing exclusions

Model weights are the single biggest way this stack will balloon a Time Machine (or any incremental) backup, *and* the worst possible thing to feed Spotlight (it'll grind for hours indexing opaque `.safetensors` blobs and produce nothing useful). Both background services want the same list of directories — exclude once, in one place. None of it is worth the cycles; every byte is re-downloadable.

Sizes below are indicative (from one 128 GB Mac mid-phase-1); yours will differ. The "reconstruct via" column is why none of this is worth backup space.

| Path | Typical size | What | Reconstruct via |
|---|---|---|---|
| `~/.cache/huggingface` | 20 GB+ and growing | mlx-lm / `hf download` model cache — the big one | `hf download` |
| `~/.cache/uv` | 10–20 GB | uv build/package cache | re-resolved on next `uv` run |
| `~/.ollama/models` | grows with use | Ollama GGUF blobs (embeddings etc.) | `ollama pull` |
| `~/.lmstudio` | several GB | LM Studio models + runtime backends (if installed) | re-download in app |
| `~/Library/Application Support/Jan/data/llamacpp/models` | several GB | Jan's Cortex/GGUF models | re-download in Jan |
| `~/Library/Application Support/Jan/data/mlx/models` | grows if Jan-as-MLX used | Jan's native-MLX models | re-download in Jan |
| `~/MLXModels` | grows if Osaurus used | Osaurus's MLX model directory (default; override via `OSU_MODELS_DIR`) | re-download in Osaurus |
| `~/.pi` | up to ~90 GB if `pi-ds4` installed | pi harness extensions + their model downloads (the `pi-ds4` extension drops the ~87 GB V4-Flash GGUF here) | `pi install <ext-url>` re-downloads |
| `~/.local/share/uv` | 2–3 GB | installed uv tools (mlx-lm, litellm, aider…) | re-run the `uv tool install` lines |

`Jan` and `jan` under Application Support are the **same directory** (case-insensitive APFS — same inode), not two; don't double-count or double-exclude.

One array, two loops — Time Machine uses **sticky path exclusions** (`-p`) so they survive the tools deleting and recreating dirs (a plain `tmutil addexclusion` sets an xattr that's lost on recreate, which is exactly what caches do), and Spotlight uses Apple's documented [`.metadata_never_index`](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/MDImporters/Concepts/Troubleshooting.html) marker file. Both require the directory to exist before they will accept it, hence the `[ -d "$d" ]` guard.

```bash
model_dirs=(
  ~/.cache/huggingface                                                  # the big one
  ~/.cache/uv
  ~/.ollama/models
  ~/.lmstudio                                                            # only if still installed
  "$HOME/Library/Application Support/Jan/data/llamacpp/models"
  "$HOME/Library/Application Support/Jan/data/mlx/models"
  ~/MLXModels                                                            # Osaurus default; or $OSU_MODELS_DIR
  ~/.pi                                                                  # pi harness + extension downloads (pi-ds4 lands ~87 GB V4 GGUF here)
  ~/.local/share/uv                                                      # optional — re-run `uv tool install` after restore
)

# Time Machine
for d in "${model_dirs[@]}"; do
  [ -d "$d" ] && sudo tmutil addexclusion -p "$d"
done

# Spotlight — drop the marker file so `mds_stores` skips the dir + subtree
for d in "${model_dirs[@]}"; do
  [ -d "$d" ] && touch "$d/.metadata_never_index"
done

# Verify a few
for d in "${model_dirs[@]}"; do
  [ -d "$d" ] && echo "$d: $(tmutil isexcluded "$d" 2>&1 | head -1) | spotlight-marker: $([ -f "$d/.metadata_never_index" ] && echo yes || echo no)"
done
```

If you ever want to re-index a directory (model dir promoted to "actual content"), `rm "$dir/.metadata_never_index"` and `mdimport -r "$dir"` puts it back.

Draw Things has a custom path that doesn't fit the array pattern (it's a sandboxed-app container, not a cache dir):

```bash
sudo tmutil addexclusion -p ~/Documents/Draw\ Things\ Models/  # if you've used the External Model Folder Setting
```

Judgement calls:

- **Jan: exclude the two `*/models` subdirs, not the whole `Jan/` dir.** The parent also holds conversation history and settings — small and worth keeping. If you don't care about Jan chat history, excluding `"$HOME/Library/Application Support/Jan"` wholesale is simpler.
- **Osaurus: exclude `~/MLXModels` wholesale** (or wherever `OSU_MODELS_DIR` points). Conversation history, agent state, identity keys live elsewhere under `~/Library/Application Support/Osaurus` — *keep* those; they're small and re-deriving identity keys is annoying.
- **LM Studio: exclude `~/.lmstudio` wholesale, or just uninstall.** LM Studio is dominated by Osaurus on every axis that matters to this track (see [Osaurus vs LM Studio](#osaurus-vs-lm-studio) below) — its presence in the exclusion list is for collaborators who still have it installed from earlier exploration, not because we recommend keeping it around.
- **pi: prefer excluding the extension subdir, not `~/.pi` wholesale.** `~/.pi/agent/models.json`, slash-command history, and pi's small config are *worth keeping* — backing them up reproduces your per-collaborator harness state. The heavy thing is what extensions download; `pi-ds4` lands the V4-Flash GGUF (~87 GB) inside its own extension dir. If you have only one extension installed and it's `pi-ds4`, the wholesale `~/.pi` exclusion above is fine; if you want finer control, exclude `~/.pi/extensions/` (or whatever exact path your pi version uses for extension assets — check with `du -sh ~/.pi/*` first, since pi's layout has churned during early development).
- **`~/.cache/huggingface` is the win** — the one that actually matters; everything else is rounding error by comparison.

#### Image-gen tools (phase 4 — paths confirmed when installed)

Not on the critical path until [phase 4](#sub-phases), but they balloon backups harder than the LLM side (Flux/SDXL/video weights run to tens of GB):

- **Draw Things** (sandboxed Mac App Store app): models at `~/Library/Containers/com.liuliu.draw-things/Data/Documents/Models` ([Draw Things docs](https://docs.drawthings.ai/documentation/documentation/2.models)). Clean single-path exclusion — *unless* you've used Draw Things' [External Model Folder Setting](https://wiki.drawthings.ai/wiki/External_Model_Folder_Setting) to relocate models (common on a high-RAM Mac running an external SSD), in which case exclude wherever you pointed it.
- **ComfyUI Desktop**: app state (config + logs, ~MB, *keep these*) is at `~/Library/Application Support/ComfyUI` and `~/Library/Logs/ComfyUI`. **Weights have no fixed default** — the install directory is chosen in the setup wizard (commonly `~/Documents/ComfyUI` but not forced; `brew install comfyui` differs again). Find the real path via the app's **Help → Open Folder → Open Model Folder**, or check `~/Library/Application Support/ComfyUI/config.json` / `extra_models_config.yaml`. Exclude `<that-install-dir>/models`. This one can't be blind-scripted; confirm per-install. The phase-4 doc will pin the exact exclusion once ComfyUI is actually in the track.

## Open questions

- **MCP-based RAG inside Jan vs. dedicated AnythingLLM.** Phase 2 uses AnythingLLM for time-to-working. A later phase may swap to a Zotero MCP server feeding Jan directly, which is more SOV-spirit (composable parts). Decision deferred to phase-2 retro.
- **opencode adoption.** Phase 4 scopes it as an Aider-alternative experiment. If it works well on `local-small`, may promote it; if it's too token-hungry for 30B-class models, stays an experiment.
- **`pi` as the canonical apple-track harness.** Phase 4 currently scopes pi as a side-quest. The argument for promotion to primary (alongside or replacing Aider for the agentic POC slot) is the [Schelling-point story](#pi-as-the-cross-track-harness): one harness across apple-personal, the SOV cloud audition, and the eventual cooperative DGX endpoint. Argument against: Aider's diff-based code-editing flow is currently sharper for the small-model code-editing workflow phase 1 actually tests. Decision deferred to phase-4 once we've used pi in anger for a few sessions; in the meantime pi and Aider coexist pointed at the same LiteLLM proxy.
- **DwarfStar / `ds4` as a V4-Flash path.** Currently flagged as a parallel experiment alongside JANGTQ2 (see [V4-Flash decisions](#decisions)). Promotion criteria mirror JANGTQ2's: measured quality on real prompts + a `bin/model-switch.sh`-compatible wrapper or a clean OpenAI-compat behind LiteLLM. The `audreyt/pi-ds4` fork specifically — abliterated weights + uncertainty-mode steering — is also a working reference for what the cloud-track [phase 2 workstream A](../PLAN.md#workstream-a-abliteration) outcome should feel like; worth a separate evaluation pass even if `ds4` doesn't become primary.
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
| Osaurus | [osaurus-ai/osaurus](https://github.com/osaurus-ai/osaurus) · [docs.osaurus.ai](https://docs.osaurus.ai) |
| AnythingLLM | [docs.anythingllm.com](https://docs.anythingllm.com/installation-desktop/macos) |
| Aider | [aider.chat/docs/llms/openai-compat.html](https://aider.chat/docs/llms/openai-compat.html) |
| `pi` harness | [earendil-works/pi](https://github.com/earendil-works/pi) |
| DwarfStar / `ds4` | [antirez/ds4](https://github.com/antirez/ds4) · [mitsuhiko/pi-ds4](https://github.com/mitsuhiko/pi-ds4) · [audreyt/pi-ds4](https://github.com/audreyt/pi-ds4) (abliterated fork) |
| opencode | [github.com/sst/opencode](https://github.com/sst/opencode) |
| Draw Things | [drawthings.ai](https://drawthings.ai) |
| ComfyUI + node packs | [comfyanonymous/ComfyUI](https://github.com/comfyanonymous/ComfyUI) · [city96/ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF) |

When something on this list goes stale, fix it in place and bump a "last freshness audit" note here so the next bootstrap doesn't repeat the same hunt.

**Last freshness audit:** 2026-05-26 (added stack-vocabulary layering, `pi` as cross-track harness, DwarfStar/`ds4`/`pi-ds4`).
