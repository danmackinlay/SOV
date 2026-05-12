# SOV — agent context

This file is shared context for Claude Code (or any agent) working in the SOV repo. It is the project's collective memory; treat it as authoritative for "what are we doing here, and how."

## Project in one paragraph

SOV is the engineering arm of the sovereign-LLM cooperative described in [Dan's blog post](https://danmackinlay.name/notebook/aus_sovereign_llm.html) (and its [technical companion](https://danmackinlay.name/notebook/aus_sovereign_llm_technical.html)). The end-state is a small Australian collective that owns an NVIDIA DGX Station, runs a de-censored open-weight model on it, and serves inference to its members. Before we spend ~$160k AUD on hardware, we are building a *cloud-rented audition* — the same software stack on rented GPUs — so prospective members can try the experience and decide whether to commit. This repo is where that audition is built.

## What we're optimising for

- **Sovereignty narrative consistency.** Pick FOSS over vendor lock-in where it doesn't cost much; surface the trade-off when it does.
- **Cost containment.** Every audition session has a cap; nothing runs idle.
- **Replicability.** A second collective should be able to fork this repo and follow it.
- **KISS over MLOps maximalism.** Three collaborators, none of us specialise in MLOps. Bash + Docker Compose; no Kubernetes.

## Architectural choices, in brief

These are documented with full reasoning in [`docs/decisions/`](docs/decisions/). Quick reference:

- **Cloud (audition):** RunPod primary; vast.ai for cheap exploration with a security caveat; Lambda Labs for full-scale phase 1.
- **Inference engine:** vLLM primary. SGLang benchmarked side-by-side at phase 1. NIM documented as a DGX-migration option but not the prototype path.
- **Surface:** OpenAI-compatible endpoint as the canonical interface. Open WebUI as the hosted browser UI. Jan recommended as a supported desktop client.
- **Routing (phase 2+):** LiteLLM in front of multiple model backends for heterogeneous deployments.
- **Auth (audition only):** Ephemeral pod URLs + shared API key + runtime cap. No real user accounts at the prototype stage.
- **Orchestration:** Bare `docker run` at phase 0; Docker Compose from phase 1 onward.
- **Models:** Qwen3-30B-A3B (phase 0) → Qwen3-235B-A22B AWQ (phase 1) → de-censored variant + reasoning sidecar (phase 2) → physical DGX (phase 3).

## Working norms

- **Plans are public.** Every phase has its own directory — cloud-audition phases under [`phases-cloud/`](phases-cloud/), the parallel laptop track under [`phases-apple/`](phases-apple/) — each with a README, scripts, and an exit-criteria checklist. Don't write code without a phase doc to anchor it.
- **Decisions are durable.** When we make an architectural choice (or revise one), record it as a short ADR in [`docs/decisions/`](docs/decisions/). Format: context → decision → consequences. Keep them under a page.
- **Scripts are launchable.** Every script that spins up cloud infra prints its destruction command and its cost cap on launch. No surprises on the credit card.
- **The rationale documents are external.** They live on Dan's blog ([post](https://danmackinlay.name/notebook/aus_sovereign_llm.html), [technical](https://danmackinlay.name/notebook/aus_sovereign_llm_technical.html)) and are the canonical source. SOV doesn't mirror them, to avoid drift.
- **The repo is public.** Treat anything you write as world-readable. Operational secrets and member info do not belong here — see [`docs/context/public-repo-policy.md`](docs/context/public-repo-policy.md) for the full perimeter and pre-commit checks.

## When asked to "build the next thing"

Default workflow:
1. Read [`PLAN.md`](PLAN.md) to find the current phase and its exit criteria.
2. Read the corresponding phase directory under [`phases-cloud/`](phases-cloud/) or [`phases-apple/`](phases-apple/) if it exists.
3. Ask Dan for any specifics the phase doc doesn't pin down before writing scripts.
4. Add the new code with a phase-doc update in the same change.

## What this repo is *not*

- Not a public-facing recruitment doc. That comes later, summarised for laypeople from our findings here.
- Not a generic LLM serving framework. We are auditioning a specific path to a specific outcome.
- Not a place for unverified vibes. If a number is in here (a price, a throughput estimate, a memory budget), it should either come from the source rationale documents or have a citation in a decision record.
