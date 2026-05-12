# ADR 0004 — Apple laptop as a parallel personal track

**Status:** Accepted
**Date:** 2026-05-12

## Context

The SOV audition is cloud-rented by design: every collaborator hits an OpenAI-compatible endpoint on a rented H100 pod. That's the right call for the audition, but it leaves a gap.

The originating use case is Dan's, but the track is written to generalise across Apple Silicon Macs (16 GB → 192 GB+). The need: daily LLM-assisted work — prose editing of [danmackinlay.name](https://danmackinlay.name) notebook entries, RAG over a personal Zotero library, occasional code editing — including in flight mode where the cloud audition is unreachable. The realistic options:

1. **Use commercial cloud assistants (Claude, GPT) and ignore SOV on the laptop.** Convenient. Drifts furthest from the sovereignty narrative; the daily user is paying Anthropic-shaped rent in exchange for not running anything.
2. **Build a separate, Mac-native local stack with no SOV connection.** Frictionless but produces no transferable knowledge for the audition.
3. **Build a Mac-native local stack that deliberately mirrors SOV's *interfaces* (OpenAI-compatible + LiteLLM routing) while swapping the *backends* for what runs well on Apple Silicon.** Daily use of the laptop track becomes practice for the SOV audition: same client config, same routing pattern, same prompt-craft, smaller models.

A laptop is not a mini-DGX. It cannot serve the audition. A reasonably-provisioned Mac (32 GB+) *can* run Qwen3-30B-A3B-Thinking comfortably, and a high-end one (96 GB+) can run Qwen3-235B-A22B-Thinking at low quant when patient — the same two models SOV uses at phases 0 and 1. That coincidence is what makes option 3 viable across a useful range of Apple hardware.

## Decision

**Add `phases-apple/` as a parallel sibling to `phases-cloud/` at the repo root, separate from the cloud-audition phase numbering.**

Concretely:

1. The track lives at [`phases-apple/`](../../phases-apple/) with its own sub-phases (`phase-0`, `phase-1`, …) that do not share numbering with the cloud-audition phases.
2. The track mirrors SOV's **interface choices** (OpenAI-compatible endpoint, LiteLLM proxy in front, model-name routing) so that learning carries across.
3. The track **does not** mirror SOV's backend choices. vLLM and Docker Compose are wrong for Apple Silicon; the laptop track uses [mlx-lm](https://github.com/ml-explore/mlx-lm) as the primary engine and keeps the already-installed Ollama for embeddings and GGUF fallback.
4. The user-facing client is **Jan**, not Open WebUI. ADR 0003 lists Jan as a recommended desktop client; the laptop track promotes it to primary because there's no zero-install collaborator-onboarding requirement here.
5. Closed-source GUIs (Draw Things; LM Studio if it earns its keep) are acceptable on this track where they save material time. The Mac-native generative-art ecosystem documented in [`livingthing/notebook/image_ai_clients.qmd`](https://danmackinlay.name/notebook/image_ai_clients.html) has them at the Pareto frontier; FOSS purity isn't worth the productivity loss for the personal track.

## What the laptop track is *not*

- **Not the audition.** Members do not "audition on a laptop." The audition is on cloud GPUs running the target model.
- **Not a substitute for SOV.** If we conclude the laptop is good enough, we have not validated the cooperative; we have validated that one person doesn't need a cooperative. The two paths answer different questions.
- **Not a public recruitment surface.** Like the rest of SOV, the laptop track is build-in-the-open documentation, not marketing.

## Consequences

- **Repo shape:** `phases-apple/` is a top-level sibling of `phases-cloud/`. The track's sub-phase numbering is independent. [`phases-cloud/README.md`](../../phases-cloud/README.md), [`phases-apple/README.md`](../../phases-apple/README.md) and [`PLAN.md`](../../PLAN.md) reference both.
- **Interface consistency pays off:** moving from laptop to cloud audition is a LiteLLM-config change, not a re-wiring of clients. Aider, Jan, AnythingLLM all keep working.
- **Two stacks to maintain.** Acceptable: the laptop stack is half a dozen `uv tool install` lines and a couple of shell scripts, not another `docker compose` graph.
- **Closed-source exception is explicit.** SOV's CLAUDE.md prefers FOSS "where it doesn't cost much." Draw Things is the documented exception. LM Studio is not adopted; mlx-lm + Ollama cover its job at zero closed-source cost.
- **Vendor lock-in on coding assistants:** Claude Code cannot use the laptop backend (Anthropic-only). The track plans Aider as the primary local code/prose editor, with [opencode](https://github.com/sst/opencode) as a later-phase experiment in Claude-Code-shaped local UX.

## Re-evaluate when

- The laptop's model coverage drifts so far below the cloud audition that the "practice for audition" framing breaks. Concretely: if Apple Silicon can no longer run any variant of the phase-1 target model, the tracks have nothing in common and we should stop pretending.
- Members other than Dan want a laptop track of their own. At that point we either generalise the docs or fork.
- A future macOS-targeted runtime (a hypothetical native MLX-based audition path on Mac Studios, for example) makes the "different backends, same interface" framing obsolete.
