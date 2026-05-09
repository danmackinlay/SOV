# Phases

Each subdirectory here is created when a phase begins, not before. The high-level definition of each phase, exit criteria, and budget lives in [`../PLAN.md`](../PLAN.md). The subdirectory contains the runnable artefacts:

- `README.md` — runbook for the phase
- `launch.sh` — entry point for spinning up the audition (with `--max-runtime-hours` cap)
- `teardown.sh` — explicit destroy
- Phase-specific assets (Compose files, benchmark scripts, model configs, etc.)

The plan's phase map:

| Directory | What |
|---|---|
| `phase-0-stack-validation/` | Single-GPU end-to-end stack test with Qwen3-30B |
| `phase-1-full-audition/` | Qwen3-235B-A22B AWQ on 4–8× H100 with benchmarks |
| `phase-2-decensor-agentic/` | Abliteration + agentic POC + heterogeneous routing |
| `phase-3-dgx-migration/` | Physical DGX Station migration (gated on cooperative formation) |
