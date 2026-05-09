# ADR 0002 — Inference engine: vLLM primary

**Status:** Accepted
**Date:** 2026-05-08

## Context

We need an inference engine to serve open-weight models for the audition. The mature options are:

- **[vLLM](https://github.com/vllm-project/vllm)** — community-driven, broadest ecosystem, OpenAI-compatible, continuous batching, paged attention, prefix caching, KV offloading via LMCache, expert parallelism for MoE. Default choice in most production deployments today.
- **[SGLang](https://github.com/sgl-project/sglang)** — newer, RadixAttention KV cache better for multi-turn workloads, slightly stronger structured-output support (xgrammar integration), reportedly 5–15% faster on multi-turn workloads vs vLLM.
- **[NVIDIA NIM](https://docs.nvidia.com/nim/)** — packaged inference (TensorRT-LLM under the hood) + OpenAI-compatible API + monitoring in one container. Smoothest path to physical DGX. Vendor lock-in.
- **[TensorRT-LLM](https://github.com/NVIDIA/TensorRT-LLM)** — fastest on NVIDIA hardware but production complexity is high. Not for our scale.

The collaborators are interested in agentic and reasoning workloads, which raises the bar on:

- Tool / function calling support.
- Reasoning-token streaming (separating thinking content from final answer).
- Structured output decoding (JSON schema, regex constraints).
- Multi-turn KV cache reuse.

## Decision

**vLLM is the primary inference engine for phases 0–2.**

**SGLang is benchmarked side-by-side at phase 1** on a representative agentic workload. If SGLang shows >25% improvement on the multi-turn / structured-output benchmarks that matter to us, we revisit. Below that threshold, the broader vLLM ecosystem (Aider, Claude Code, LangChain, the OpenAI Python SDK, every agent framework worth using) makes vLLM the safer default.

**NIM is documented as a phase-3 migration option** — to be evaluated when we have physical DGX hardware in hand, not before. We expect to stay on vLLM through phase 3 unless NIM offers something compelling at the time.

**TensorRT-LLM is out of scope** for this prototype.

## Why not SGLang as primary

- vLLM's ecosystem advantage is real today: every agentic tool that "just works" with OpenAI-compatible endpoints has been tested against vLLM more than against SGLang.
- The performance delta on agentic workloads (≈10% per public benchmarks) does not outweigh ecosystem maturity for an audition where "feels good to use" is the main criterion.
- We can always add SGLang as a sidecar later via LiteLLM routing if a workload demands it.

## Why not NIM as primary

- Vendor lock-in conflicts with the sovereignty narrative.
- NIM's "everything in one container" simplicity is real but masks the layers we want our collaborators to understand.
- We'd be coupling the audition to the physical-DGX migration path; better to decouple and re-evaluate at phase 3.

## Consequences

- Launch scripts default to `vllm/vllm-openai` Docker image, version-pinned.
- Phase 1 has a benchmark workstream specifically comparing vLLM and SGLang.
- Reasoning-mode tests (Qwen3 thinking mode, DeepSeek-R1) use vLLM's `--enable-reasoning` flag and equivalent SGLang flag in the benchmark.
- Documentation of NIM as a migration option lives in phase-3 prep, not in phase-0/1/2 scripts.

## Re-evaluate when

- Phase 1 benchmark shows SGLang >25% faster on workloads we care about.
- A new engine emerges that obsoletes both (e.g., a hypothetical mature open-source successor to TensorRT-LLM that doesn't carry NVIDIA's lock-in).
- Our agent stack of choice (Aider, Claude Code) drops vLLM compatibility, which is implausible.
