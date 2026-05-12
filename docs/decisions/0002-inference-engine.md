# ADR 0002 — Inference engine: vLLM primary

**Status:** Accepted (last reviewed 2026-05-12)
**Date:** 2026-05-08

## Context

We need an inference engine to serve open-weight models for the audition. The mature options as of May 2026:

- **[vLLM](https://github.com/vllm-project/vllm)** — community-driven, broadest ecosystem (~2,400 contributors), OpenAI-compatible, continuous batching, paged attention, prefix caching, KV offloading via LMCache, expert parallelism for MoE. Current release v0.20.x. Default choice in most production deployments today. **First-class GB300/DGX Station support** as of the GTC 2026 timeframe.
- **[SGLang](https://github.com/sgl-project/sglang)** — RadixAttention KV cache wins on multi-turn workloads; xgrammar integration delivers ~3× faster structured output with 96–98% JSON compliance. **2026 numbers vs vLLM: ~29% faster on standard H100 workloads, ~2× output-token throughput, up to ~6.4× on prefix-heavy / multi-turn / RAG workloads, ~3.1× on DeepSeek models (officially endorsed by DeepSeek).** Used in production by xAI/Grok, Azure, LinkedIn, Cursor.
- **[NVIDIA Dynamo 1.0](https://github.com/ai-dynamo/dynamo)** — announced at GTC 2026 as NVIDIA's open-source distributed-inference "OS" that integrates *with* vLLM/SGLang/llm-d/LMCache rather than replacing them. ~7× Blackwell perf per NVIDIA's marketing; broadly adopted across AWS/Azure/GCP/OCI/Cursor/Perplexity. Effectively supersedes NIM as the marquee NVIDIA inference story.
- **[NVIDIA NIM](https://docs.nvidia.com/nim/)** — packaged inference (TensorRT-LLM under the hood) + OpenAI-compatible API + monitoring in one container. Was the smoothest path to physical DGX in 2025; Dynamo now competes for that role with less lock-in.
- **[TensorRT-LLM](https://github.com/NVIDIA/TensorRT-LLM)** — fastest on NVIDIA hardware but production complexity is high. Not for our scale. NVIDIA is now contributing TensorRT-LLM CUDA kernels back to FlashInfer for native integration with vLLM/SGLang, so the performance gap is closing *without* requiring us to adopt TensorRT-LLM directly.

The collaborators are interested in agentic and reasoning workloads, which raises the bar on:

- Tool / function calling support.
- Reasoning-token streaming (separating thinking content from final answer).
- Structured output decoding (JSON schema, regex constraints).
- Multi-turn KV cache reuse.

## Decision

**vLLM is the primary inference engine for phases 0–2.**

**SGLang is benchmarked side-by-side at phase 1** on representative workloads, with results broken down by workload class. The 2026 numbers strongly suggest SGLang wins on the workloads we care about (multi-turn agentic, DeepSeek-class sidecar models, prefix-heavy RAG); the flat "25% on multi-turn" threshold from the original 2025-08 framing is no longer the right bar. **Revised re-evaluation criteria:** if SGLang shows >25% improvement on *unique-prompt* benchmarks (where its prefix-cache advantage is neutralised), *or* >2× on prefix-heavy / multi-turn workloads relative to vLLM, we promote SGLang from sidecar to primary at phase 2. We expect at least one of those to fire — the live question is whether the ecosystem-compat tax of switching is worth paying when the benchmark lands.

**Dynamo 1.0 is documented as a phase-3 migration option** alongside NIM, with native vLLM-on-GB300 as the no-migration baseline. We expect to stay on vLLM through phase 3 unless Dynamo offers something compelling at the time; the prior assumption that "physical DGX = leave vLLM for NIM" no longer holds.

**TensorRT-LLM remains out of scope** for this prototype.

## Deliberately not using

- **[llm-d](https://github.com/llm-d/llm-d)** — Kubernetes-native disaggregated vLLM scheduler (v0.6/0.7, CNCF Sandbox as of March 2026). Excellent for scale-out production, irrelevant at SOV's three-collaborator scale where we've explicitly chosen Compose-over-K8s. Re-evaluate only if a future SOV deployment outgrows single-host Compose.
- **TensorRT-LLM directly** — production complexity not worth the throughput delta at our scale; benefits arrive indirectly via FlashInfer kernel contributions to vLLM/SGLang.

## Why vLLM (still) primary in May 2026

- vLLM's ecosystem advantage is real today: every agentic tool that "just works" with OpenAI-compatible endpoints has been tested against vLLM more than against SGLang.
- The performance delta on agentic workloads has grown (~29% standard, much higher on prefix-heavy per public 2026 benchmarks), which is non-trivial — but at audition scale (three collaborators, bursty interactive use) absolute throughput is not the binding constraint; feeling-of-use and tool compatibility are.
- We can always promote SGLang to primary at phase 2 once the benchmark lands; the cost of being wrong here for one phase is small.
- Strategic hedge: **Dynamo integrates with both vLLM and SGLang**, so committing to vLLM at phase 1 does not foreclose the Dynamo-on-DGX path at phase 3.

## Why not NIM (or Dynamo) as primary

- Vendor lock-in (NIM) or NVIDIA-coupled tooling (Dynamo) conflicts with the sovereignty narrative.
- NIM's "everything in one container" simplicity is real but masks the layers we want our collaborators to understand. Dynamo's distributed-inference framing is overkill at our scale.
- We'd be coupling the audition to the physical-DGX migration path; better to decouple and re-evaluate at phase 3 when vLLM-on-GB300 is also a credible no-migration option.

## Consequences

- Launch scripts default to `vllm/vllm-openai` Docker image, version-pinned to a specific tag (not `:latest`).
- Phase 1 has a benchmark workstream comparing vLLM and SGLang, **split by workload class** (unique-prompt vs prefix-heavy/multi-turn) rather than reporting a single throughput number.
- Reasoning-mode tests (Qwen3.5 thinking, DeepSeek-R1) use vLLM's reasoning-output flags and equivalent SGLang flags in the benchmark.
- Documentation of Dynamo and NIM as phase-3 migration options lives in phase-3 prep, not in phase-0/1/2 scripts.

## Re-evaluate when

- Phase 1 benchmark shows SGLang >25% faster on workloads we care about.
- A new engine emerges that obsoletes both (e.g., a hypothetical mature open-source successor to TensorRT-LLM that doesn't carry NVIDIA's lock-in).
- Our agent stack of choice (Aider, Claude Code) drops vLLM compatibility, which is implausible.
