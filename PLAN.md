# Plan: Sovereign-LLM Audition

This document describes the engineering plan for the SOV repo: how we get from "no infrastructure" to "the cooperative has tried the experience on rented GPUs and decided whether to buy hardware."

It is the live plan. Revise it in place when reality diverges; mark superseded sections rather than deleting them so we keep an audit trail.

**Reading order:** [rationale](docs/rationale/) → this plan → individual [phase docs](phases-cloud/) as they're created.

---

## 0. TL;DR

We're auditioning a sovereign-LLM software stack on rented cloud GPUs across four phases:

| Phase | Goal | Hardware | Headline cost | Duration |
|---|---|---|---|---|
| **0** | Validate the stack end-to-end with a small model | 1× H100 (RunPod / vast.ai) | ~$50–$150 AUD | 1–3 days of active work |
| **1** | Run the full target model under realistic load | 4–8× H100 (Lambda or RunPod) | ~$500–$1,500 AUD | 1–2 weeks |
| **2** | De-censor + agentic POC + heterogeneous routing | Same as phase 1 plus 1× H100 sidecar | ~$1,000–$2,500 AUD | 2–3 weeks |
| **3** | Physical DGX Station migration | NVIDIA DGX Station GB300 | $135k–$195k AUD one-time | TBD; gated on cooperative formation |

The audition through end of phase 2 is **~$1,500–$4,000 AUD** total. That is the budget that lets the three of us decide whether the hardware purchase is worth pitching to a wider group.

---

## 1. Scope and non-goals

### In scope
- A reproducible cloud-GPU stack that mirrors what would later run on a DGX Station.
- Launch scripts with hard runtime caps and printable URLs for ephemeral collaborator access.
- Side-by-side benchmarks of vLLM and SGLang on representative agentic workloads.
- A documented de-censoring procedure (abliteration only — DPO is out of scope until there's actual demand).
- An agentic proof-of-concept workflow runnable by any collaborator.
- A path-to-production architecture for the eventual physical DGX Station, written but not built.

### Out of scope (at this stage)
- Real user accounts or production-grade auth. Audition runs use ephemeral pod URLs + a shared API key.
- Kubernetes, Ansible, NixOS, or any orchestration with a learning curve. Bash + Docker Compose is the floor and the ceiling.
- DPO / SFT fine-tuning beyond the basic abliteration step. Cost and complexity don't pay off until there's a committed cooperative.
- Public-facing recruitment material. We summarise for laypeople once the audition is complete.
- Australian-hosted GPU rental. AU GPU availability is thin and expensive; we accept the US-cloud audition for the prototype and surface the tension in the eventual cooperative pitch.
- Multi-region failover, observability platforms beyond a `docker logs`, or any "production hardening" that doesn't earn its keep at three users.

### Non-goal: matching commercial models
The rationale document is explicit about this: a self-hosted open-weight model is *not* trying to beat Claude or GPT-5. It's trying to be good enough that we'd be glad to have it if the commercial options went away. Don't optimise for benchmark scores against frontier models; optimise for "the audition feels like a usable working environment."

---

## 2. Architecture decisions (recap)

Full ADRs are in [`docs/decisions/`](docs/decisions/). One-line summaries:

| Choice | Decision | Why |
|---|---|---|
| Audition cloud | RunPod primary; vast.ai for cheap phase-0; Lambda for phase-1 scale | Familiarity, fast spin-up, ephemeral URLs built in. Vast.ai is cheaper but has trust caveats. |
| Inference engine | vLLM primary; SGLang benchmarked at phase 1; NIM documented for DGX migration | vLLM has the broadest ecosystem (Aider, Claude Code, LangChain) and lowest lock-in. |
| User-facing surface | OpenAI-compatible endpoint + Open WebUI; Jan as recommended desktop client | OpenAI compat is the universal interface; Open WebUI is zero-install for collaborators. |
| Auth (audition) | Ephemeral pod URLs + shared API key + runtime cap | Cost-bounded blast radius even if URL leaks. |
| Orchestration | `docker run` at phase 0; Docker Compose from phase 1 | Compose is the floor for multi-service. Heterogeneous routing via LiteLLM proxy. |
| Models | Qwen3-30B → Qwen3-235B → de-censored + reasoning sidecar → DGX | Each phase exercises more of the stack at higher cost; can stop at any phase. |
| Decensoring | Abliteration only at this stage; DPO deferred | Abliteration is ~$50–$100 USD; DPO is $1.5–4k AUD and only earns its keep with a committed cooperative. |

---

## 3. Phased roadmap

Each phase has its own directory under [`phases-cloud/phase-N-name/`](phases-cloud/) with a `README.md`, scripts, and an exit-criteria checklist. The phase directory is created when the phase begins, not before.

### High-level dependency graph

```
phase 0 (stack validation)
   |
   v
phase 1 (full audition)        --> ADR: keep/swap engine
   |
   v
phase 2 (decensor + agentic + routing)
   |
   v
phase 3 (DGX migration)        --> gated on cooperative legal formation
```

Phases must be done in order; nothing in phase 1 should require revisiting phase-0 decisions, and so on.

### Parallel tracks

Some work doesn't fit the cloud-audition phase numbering but is still under SOV's umbrella because it shares interface conventions:

- [**`phases-apple/`**](phases-apple/) — Mac-native personal stack on Apple Silicon, mirroring the audition's OpenAI-compatible + LiteLLM interface choices but with mlx-lm and Ollama as backends. Daily use of the laptop track is practice for the cloud audition. Rationale: [ADR 0004](docs/decisions/0004-apple-laptop-personal-track.md); position on Apple Neural Engine: [ADR 0005](docs/decisions/0005-apple-neural-engine.md). The laptop track has its own internal sub-phases (`phase-0` through `phase-4`) which are independent of the audition phases.

---

## 4. Phase 0 — stack validation

**Goal:** prove the full stack runs end-to-end on a single GPU with a small model. We are not testing model quality here; we are testing that we can spin up a pod, serve an OpenAI-compatible API, hit it from Open WebUI, hit it from a collaborator's machine, and tear it down with a printable cost.

### Hardware

- **Primary:** 1× H100 80GB on **RunPod**. Roughly $2–$3 USD/hour as of writing.
- **Alternative for cost-conscious experimentation:** 1× H100 or RTX 6000 Ada on **vast.ai**, typically 30–50% cheaper. **Caveat:** vast.ai hosts have root on the physical machine. Use only with public open-weight models and synthetic test prompts; do not feed it anything sensitive. ADR in [`docs/decisions/0001-cloud-providers.md`](docs/decisions/0001-cloud-providers.md) covers the trade-off in detail.

### Model

- **[Qwen3-30B-A3B-Instruct](https://huggingface.co/Qwen/Qwen3-30B-A3B-Instruct-2507)** (or its 4-bit quantized variant) — small enough to fit on one H100 with room for a healthy KV cache.
- This is *not* the audition model. It's the stack-validation model. Do not draw quality conclusions from it.

### Software stack

```
RunPod pod
  |--> docker run vllm/vllm-openai:latest serving Qwen3-30B
  |--> docker run open-webui/open-webui pointed at vLLM
  '--> RunPod proxy URL exposed on a unique random hostname
```

No Docker Compose at this phase. Two `docker run` commands and a launch script that orchestrates them is enough.

### Deliverables

When phase 0 is "done", the repo contains:

- [`phases-cloud/phase-0-stack-validation/README.md`](phases-cloud/) — runbook
- [`phases-cloud/phase-0-stack-validation/launch.sh`](phases-cloud/) — script that:
  - takes a `--max-runtime-hours N` flag with a default of 4 and a hard cap of 24
  - spins up a RunPod pod (via `runpodctl` or the API)
  - waits for vLLM and Open WebUI to be ready
  - prints the access URL and the shared API key
  - prints the destruction command
  - schedules its own self-destruct at the runtime cap
- [`phases-cloud/phase-0-stack-validation/teardown.sh`](phases-cloud/) — explicit destroy command
- A short ADR in [`docs/decisions/`](docs/decisions/) recording any discoveries that reshape later phases (e.g., RunPod startup-time gotchas)

### Exit criteria

A collaborator who has never seen the repo can:
1. Clone it
2. Set their RunPod API key in `.env`
3. Run `./phases-cloud/phase-0-stack-validation/launch.sh`
4. Open the printed URL in their browser
5. Have a conversation with Qwen3-30B in Open WebUI
6. Hit the OpenAI-compatible endpoint from `curl` with the printed API key
7. Walk away and have it auto-destroy at the runtime cap

…all within 30 minutes of starting and for under $15 AUD.

### Budget

| Item | Cost |
|---|---|
| RunPod 1× H100, 4-hour test session | ~$10–$15 USD (~$15–$23 AUD) |
| Vast.ai equivalent | ~$5–$8 USD |
| Phase 0 total (across multiple test sessions during development) | **~$50–$150 AUD** |

### Open questions for phase 0

- Are we OK shipping a single shared API key per pod, or do we want one-key-per-collaborator from day 0? (Default: shared. Re-evaluate at phase 2.)
- RunPod's built-in proxy URL vs. a Cloudflare Tunnel for portability across clouds? (Default: RunPod's. Cloudflare Tunnel becomes interesting at phase 1 when we may use Lambda.)

---

## 5. Phase 1 — full audition

**Goal:** run the actual target model under realistic load and produce the data needed to decide whether the hardware purchase makes sense.

### Hardware

- **Primary:** 4–8× H100 80GB on **Lambda Labs** or **RunPod**.
- 4× H100 = 320 GB HBM. Qwen3-235B-A22B at AWQ 4-bit needs ~124 GB for weights, leaving ~190 GB for KV cache across the cluster. That fits comfortable concurrency for our 3-collaborator audition.
- 8× H100 if we want headroom for the SGLang benchmark and concurrent agentic sessions.

### Model

- **[Qwen3-235B-A22B-Instruct-2507](https://huggingface.co/Qwen/Qwen3-235B-A22B-Instruct-2507) at AWQ 4-bit.**
- Confirms numbers in the [technical rationale](https://danmackinlay.name/notebook/aus_sovereign_llm_technical.html) — same model, same quantization, same KV-cache configuration.

### Software stack

```
Lambda or RunPod multi-GPU pod
  '--> docker compose up
        |--> vllm/vllm-openai (Qwen3-235B AWQ, tensor-parallel across 4-8 GPUs)
        |--> open-webui (pointed at vLLM)
        |--> nginx or caddy reverse proxy w/ shared-key auth
        '--> [optional] sglang sidecar for benchmarking
```

Docker Compose from this phase onward. The Compose file is the source of truth for what services exist; the launch script just wraps `docker compose up` plus pod orchestration.

### Benchmarks

This is the phase where we generate the evidence for or against the hardware purchase. Benchmarks must include:

1. **Single-stream latency** (TTFT and tokens/sec) at three context lengths: 2k, 16k, 64k.
2. **Concurrent throughput** with 3, 8, and 16 simulated users running representative workloads.
3. **Agentic round-trip** — measure the full latency of one tool-calling cycle (prompt → tool call → tool result → response) on at least one realistic agentic task.
4. **vLLM vs. SGLang** side-by-side on the same workload. Document any differences > 15%.

Output: a `phases-cloud/phase-1-full-audition/benchmarks.md` with results, raw data, and a recommendation.

### Deliverables

- [`phases-cloud/phase-1-full-audition/README.md`](phases-cloud/) — runbook
- [`phases-cloud/phase-1-full-audition/docker-compose.yml`](phases-cloud/) — service definitions
- [`phases-cloud/phase-1-full-audition/launch.sh`](phases-cloud/) — multi-GPU pod orchestration with cap
- [`phases-cloud/phase-1-full-audition/teardown.sh`](phases-cloud/)
- [`phases-cloud/phase-1-full-audition/benchmarks/`](phases-cloud/) — scripts that run the benchmarks above and write reproducible results
- [`phases-cloud/phase-1-full-audition/benchmarks.md`](phases-cloud/) — written-up findings
- One ADR in [`docs/decisions/`](docs/decisions/) recording vLLM-vs-SGLang outcome

### Exit criteria

1. The three collaborators have each had at least one extended (60+ minute) work session against the audition stack and written up subjective impressions in `phases-cloud/phase-1-full-audition/impressions.md`.
2. Throughput numbers from the benchmark suite are within ±25% of the [technical rationale's predictions](https://danmackinlay.name/notebook/aus_sovereign_llm_technical.html) — discrepancies investigated and explained.
3. We have a written go/no-go recommendation on phase 2.

### Budget

| Item | Cost |
|---|---|
| 8× H100 on Lambda @ ~$24 USD/hr × 30 hrs of active testing | ~$720 USD |
| RunPod or vast.ai equivalents for ad-hoc work between sessions | ~$200 USD |
| Phase 1 total | **~$1,000–$1,500 AUD** |

If we restrict to 4× H100 and tight session discipline, this drops by ~40%.

---

## 6. Phase 2 — decensor + agentic POC + heterogeneous routing

**Goal:** show the cooperative what life with sovereign compute would actually feel like — a model that doesn't refuse on Tiananmen, an agent that does real work, and a routing layer that lets us mix small and large models.

This phase has three independent workstreams that can run in parallel.

### Workstream A: Abliteration

Apply abliteration to Qwen3-235B-A22B using [Heretic](https://github.com/p-e-w/heretic) or [llm-abliteration](https://github.com/jim-plus/llm-abliteration). Run on rented 8× H100 for 2–4 hours.

**Deliverables:**
- [`phases-cloud/phase-2-decensor-agentic/abliteration/run.sh`](phases-cloud/) — automated pipeline
- Pre-and-post evaluation against the [Shisa.AI Qwen2 censorship taxonomy](https://shisa.ai/posts/qwen2-chinese-llm-censorship-analysis/) in both English and Chinese, results checked into the repo
- The abliterated weights themselves stored on… [open question — see §9]

**Cost:** ~$50–$100 USD compute + iteration time.

### Workstream B: Agentic proof-of-concept

A runnable demo where each collaborator can experience an agent doing real-ish work against the sovereign endpoint.

**Candidate POCs** (we pick one or two; do not build all):

1. **Aider** pointed at the SOV endpoint, doing a small refactor on a sample repo. Lowest implementation cost; immediate signal on coding-agent feel.
2. **Claude Code in API mode** with `ANTHROPIC_BASE_URL` redirected to the SOV endpoint via an OpenAI-to-Anthropic translation shim. Highest "wow factor" if it works; significant integration cost (Claude Code expects Anthropic-format API).
3. **A small custom Python agent** that does something concrete: read a CSV, do a multi-step research task, write a report. Maximum control; least transferable.

**Default:** Aider as the workhorse POC plus a 50-line custom Python agent that exercises tool calling end-to-end. Claude-Code-in-API-mode is a stretch goal.

**Deliverables:**
- [`phases-cloud/phase-2-decensor-agentic/agentic/`](phases-cloud/) — runnable demos and a written walkthrough
- A note on what worked, what frustrated, and how it compares to Claude Code against Anthropic's actual API (the realistic baseline)

**Cost:** development time + a few hours of GPU time for testing.

### Workstream C: Heterogeneous routing

Add a [LiteLLM](https://github.com/BerriAI/litellm) proxy in front of the inference layer. Wire two backends:

1. **Qwen3-235B-A22B (abliterated)** — the workhorse.
2. **DeepSeek-R1-Distill-Qwen-32B** or similar — a fast/cheap "sanity-check" or "pre-filter" model running on its own GPU.

LiteLLM presents a single OpenAI-compatible endpoint. Clients pick a model by name; LiteLLM routes to the right backend.

This sets up the architecture pattern we'd want on the eventual DGX setup: workhorse + sidecar(s).

**Deliverables:**
- Updated [`docker-compose.yml`](phases-cloud/) including LiteLLM and the second model server
- [`phases-cloud/phase-2-decensor-agentic/routing/litellm-config.yaml`](phases-cloud/)
- A short runbook documenting how to add a third backend

**Cost:** ~1× extra H100-hour per testing session; mostly absorbed in workstream A and B's GPU time.

### Phase 2 exit criteria

1. Abliterated weights pass a documented evaluation showing dramatic refusal-rate reduction without obvious quality regression on a held-out task suite.
2. At least one collaborator has used the agentic POC for a non-trivial real task and written up the experience.
3. LiteLLM routing demonstrably switches between workhorse and sidecar based on model name, with at least one documented use case where the sidecar is genuinely useful (e.g., quick classification before invoking the big model).

### Budget

**~$1,000–$2,500 AUD** total. Abliteration is cheap; the routing setup is just config. Most cost is repeated audition sessions while iterating on the agentic POC.

---

## 7. Phase 3 — physical DGX Station migration (outline only)

This is gated on:
- Cooperative legal formation (incorporated association, see [legal section in the rationale](https://danmackinlay.name/notebook/aus_sovereign_llm_technical.html#legal-coop)).
- Sufficient member commitment to fund the purchase.
- A go-recommendation from phases 1 and 2.

**At a high level**, this phase will:

1. Place the order through an Australian NVIDIA partner ([XENON](https://xenon.com.au/product/nvidia-dgx-station/), Dell, MMT). Lead time: months.
2. Pick the hosting venue: home, shared office, or colo. The rationale doc has a full discussion; the network reliability section will drive the call.
3. Migrate the phase-2 stack to the DGX. The whole point of standardising on vLLM + Docker Compose is that this should be a config change, not a rewrite. The rationale document mentions NIM as the smoothest migration target; we will evaluate at the time but expect to stay on vLLM.
4. Burn-in and member onboarding.

**We will write phase 3 in detail when we are within ~3 months of placing an order.** Everything before that is speculative.

---

## 8. Cross-cutting concerns

These apply to every phase.

### Cost discipline

- Every launch script enforces `--max-runtime-hours` with a hard ceiling of 24 hours.
- Every launch script prints, on startup: the runtime cap, the projected cost at cap, and the destruction command.
- The teardown script is idempotent (running it twice is fine) and verifies the resource is actually gone before exiting 0.
- We log every audition session in [`docs/sessions.md`](docs/) with date, duration, cost, and what was learned.

### Security posture

- Shared API keys live in `.env`, which is gitignored. Never commit a key.
- vast.ai is treated as untrusted; we don't process anything sensitive on it.
- The shared key + ephemeral URL approach assumes the URL itself is the secret. Don't post URLs in public channels or screenshots while a session is live.
- Auto-destruction caps blast radius if a key or URL leaks.

### Observability

- `docker logs <service>` and the vLLM `/metrics` endpoint are sufficient at the audition scale.
- We write a minimum-viable structured log of each session to [`docs/sessions.md`](docs/) for institutional memory.
- Real observability infrastructure (Grafana, Prometheus stacks) is out of scope until phase 3.

### Reproducibility

- Every script pins versions: vLLM image tag, model revision, RunPod pod template ID. No `:latest` tags except where explicitly marked "track upstream".
- The Compose file is the contract; updating it requires updating the phase doc that references it.

---

## 9. Open questions and deferred decisions

These are real questions we have not yet answered. Record the resolution here when we make a call.

1. **Where do we store the abliterated weights?** Options: HuggingFace private repo, an S3-equivalent bucket, or just regenerate from the script each time. Cost vs. convenience trade-off. Resolve before phase 2.
2. **Does Claude Code's API mode work via an OpenAI-to-Anthropic shim?** Investigate before phase 2 workstream B; it would be a high-impact demo if so.
3. **Is the Australian-cloud-purity tension worth surfacing in the audition itself, or only in the eventual recruitment doc?** Default: surface in [`docs/decisions/0001-cloud-providers.md`](docs/decisions/) and let it inform the recruitment narrative; don't change audition behaviour.
4. **What's the right license for this repo?** Probably MIT or Apache-2.0 to encourage forking by other collectives. Resolve before going public.
5. **Phase 3 hosting venue (home / office / colo).** Defer until phase 2 results inform reliability requirements.
6. **NIM evaluation depth at phase 3.** We've decided not to use it as the audition path, but we should at minimum verify it can serve the same weights when we get to physical hardware. Defer.

---

## 10. Repo layout

```
SOV/
  README.md                  short repo overview
  CLAUDE.md                  shared agent context
  PLAN.md                    this document
  .gitignore
  docs/
    rationale/               read-only mirrors of the case-for-this-work posts
    decisions/               ADRs (architectural decision records)
    context/                 supplementary context for collaborators and agents
    sessions.md              log of every audition session (created at phase 0)
  phases-cloud/                cloud-audition track (the main SOV arc)
    phase-0-stack-validation/  created when phase 0 begins
    phase-1-full-audition/     created when phase 1 begins
    phase-2-decensor-agentic/  created when phase 2 begins
    phase-3-dgx-migration/     created when phase 3 is real
  phases-apple/                parallel track: Mac-native personal stack
    phase-0/                   mlx-lm + Jan baseline
    bin/                       model-switch.sh, model-status.sh
  scripts/
    common/                    shared bash helpers used across tracks
```

A phase directory always contains:

- `README.md` — runbook for the phase
- `launch.sh` — entry point for spinning up the audition
- `teardown.sh` — explicit destroy
- Whatever phase-specific assets the workstreams require (Compose files, benchmark scripts, model configs)

---

## 11. What happens next

Immediate next step is to **scope phase 0 in detail with Dan**: confirm RunPod account credentials and quotas, decide on `runpodctl` vs. raw API, settle the Open WebUI vs. raw API surface for the first session, and write the launch script. That conversation produces the contents of [`phases-cloud/phase-0-stack-validation/`](phases-cloud/) and triggers the first auditioned run.

After phase 0 ships, we recap what we learned, update this plan if anything changed, and scope phase 1 the same way.
