# Cloud audition track

The main SOV audition arc: rented GPUs, a target model under realistic load, an answer to the "should we buy hardware" question. Master plan lives in [`../PLAN.md`](../PLAN.md) §3–§7; this README is the directory index.

The personal Apple Silicon stack runs as a parallel track at [`../phases-apple/`](../phases-apple/) (rationale: [ADR 0004](../docs/decisions/0004-apple-laptop-personal-track.md)).

## Phase map

Each subdirectory is created when its phase begins, not before. Every phase directory contains:

- `README.md` — runbook for the phase
- `launch.sh` — entry point for spinning up the audition (with `--max-runtime-hours` cap)
- `teardown.sh` — explicit destroy
- Phase-specific assets (Compose files, benchmark scripts, model configs, etc.)

| Directory | What |
|---|---|
| `phase-0-stack-validation/` | Single-GPU end-to-end stack test with Qwen3-30B |
| `phase-1-full-audition/` | Qwen3.5-122B-A10B FP8 on 3× H200 or 4–8× H100 with benchmarks (vLLM vs SGLang; FP8 vs AWQ) |
| `phase-2-decensor-agentic/` | Abliteration + agentic POC + heterogeneous routing |
| `phase-3-dgx-migration/` | Physical DGX Station migration (gated on cooperative formation) |
