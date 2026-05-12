# ADR 0005 — Apple Neural Engine: not a target for the laptop track

**Status:** Accepted
**Date:** 2026-05-12

## Context

The Apple Neural Engine (ANE) is the dedicated neural accelerator on M-series chips, sold as the low-power inference path. It is the natural thing to ask about when someone says "AI on an Apple laptop." The laptop track ([ADR 0004](0004-apple-laptop-personal-track.md)) needs to take a position.

Three coexisting runtimes are available for AI workloads on Apple Silicon, summarised in [`livingthing/notebook/image_ai_clients.qmd`](https://danmackinlay.name/notebook/image_ai_clients.html#how-models-actually-run-on-a-mac):

- **GPU / Metal** — via PyTorch+MPS, llama.cpp's Metal backend, or Apple's [MLX](https://github.com/ml-explore/mlx) array framework. The fastest path for models that fit in unified memory; broadest architecture coverage; what mlx-lm, Ollama, and Draw Things all use.
- **Apple Neural Engine** — via Core ML. Lowest power per token, lowest RAM footprint, but every model needs offline conversion via [`coremltools`](https://developer.apple.com/documentation/coreml), and the ANE has tighter constraints on what shapes and quantizations it accepts.
- **CPU** — fallback; uninteresting for LLMs.

The question this ADR answers: should the laptop track prefer the ANE where possible?

## Decision

**No. The laptop track targets GPU / Metal via MLX as the primary path. ANE is not a deliberate target.**

ANE is mentioned where it earns its keep (small-RAM image generation via Mochi Diffusion, speech-to-text via whisper.cpp's Core ML backends if/when we adopt local STT), but no sub-phase of the laptop track will optimise for ANE-first inference of an LLM.

## Why not target ANE

Five reasons, roughly in priority order:

1. **No mature LLM serving stack on ANE.** Apple's own [`ml-stable-diffusion`](https://github.com/apple/ml-stable-diffusion) conversion pipeline is in maintenance (last tagged release May 2024, ad-hoc community PRs since). The equivalent for LLMs is even less established: research-grade `coremltools` and `transformers-to-coreml` paths exist, but there is no `mlx_lm.server`-equivalent that "just works." The audition-relevant Qwen3-thinking and DeepSeek-R1 architectures have no Apple-blessed Core ML port at time of writing.
2. **Models we care about are too big for ANE's effective working set.** ANE was designed around small, mobile-class models (≤ a few billion parameters held tightly). The 30 B-class reasoners that justify a 64 GB+ Mac, let alone the 235 B-class stretch model on 128 GB+, are far outside the regime where ANE is faster than GPU. Once weights spill, the ANE's bandwidth and energy advantages evaporate.
3. **The MLX team is Apple's own AI inference team.** MLX exists because Apple decided that for the model sizes their hardware can hold, a Metal-targeted array framework was the better investment than pushing everything onto the ANE. Following that judgement, rather than working around it, is the lower-risk choice.
4. **GPU/Metal is where the ecosystem lives.** mlx-lm, Ollama, llama.cpp, ComfyUI, Draw Things, InvokeAI — every tool the laptop track adopts uses Metal. ANE adoption would mean abandoning that ecosystem for one model at a time, with offline conversion as the cost.
5. **Power and noise are not the binding constraint.** The "ANE is more battery-efficient" argument matters most for iPad/iPhone, or for sustained background workloads on a laptop. The laptop track's profile is bursty interactive use (read a prompt, think for 5–60 s, return). At that duty cycle, the absolute energy cost of a GPU-served burst is small; the binding constraint is throughput-per-token, which favours Metal.

## Where ANE may matter (documented for completeness, not promoted)

- **Stable Diffusion 1.5 on RAM-constrained hardware** via [Mochi Diffusion](https://github.com/MochiDiffusion/MochiDiffusion) — runs an SD pipeline at ~150 MB RAM footprint by routing through Core ML. Niche; the laptop track's image-gen sub-phase prefers Draw Things and ComfyUI for everything more recent than SDXL. Documented in detail at [`image_ai_clients.qmd`](https://danmackinlay.name/notebook/image_ai_clients.html#coreml-conversion-in-practice).
- **whisper.cpp** has Core ML / ANE backends for the encoder. If/when a future sub-phase adopts local speech-to-text — currently scoped out per ADR 0004's "don't care about TTS" plus the matching STT inference — this is the place ANE would re-enter the conversation.
- **Small vision models for incidental OCR.** A hypothetical Core ML conversion of Qwen2.5-VL-3B or a comparable small vision model would benefit from ANE. The phase-3 default (Qwen2.5-VL-7B via MLX) is fine for laptops with ≥ 32 GB; collaborators with 16 GB Macs may wish to convert a smaller VLM to Core ML for that workload specifically. Not on the critical path.

## Consequences

- **Sub-phase docs do not need ANE notes** beyond passing acknowledgements where relevant (the image-gen sub-phase, eventually the STT side-quest if it happens).
- **No `coremltools` setup** in any phase-0 or phase-1 install steps.
- **The `model-switch.sh` helper targets `mlx_lm.server` exclusively** and does not branch on ANE-vs-GPU. Simpler.
- **Closed-source clients that use ANE under the hood** (Mochi Diffusion for SD 1.5) are acceptable per ADR 0004 if and where they save time, but their ANE usage is incidental — we adopt them for their feature set, not for ANE access.
- **`model-status.sh` does not report ANE utilization.** `mactop` shows it for the curious; it should mostly read zero on this track.

## Re-evaluate when

- **Apple ships a first-party `mlx-lm`-equivalent that targets the ANE** for current-generation reasoning models. This would obsolete most of reasons (1) and (3) at once.
- **A Core ML quantization scheme that fits a 30 B-class reasoner on the ANE without spilling to GPU/CPU** emerges. Reason (2) is the underlying physical constraint; this would relax it.
- **A future Apple Silicon chip splits unified memory differently** (e.g., dedicated ANE-resident memory pool at scale). Hypothetical, not on any roadmap we can see.
- **The laptop track's workload shifts to sustained low-power inference** (background agents, always-on assistants, on-device classifiers). Reason (5) flips for that profile.
