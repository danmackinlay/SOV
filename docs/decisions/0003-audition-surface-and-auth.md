# ADR 0003 — Audition surface and ephemeral auth model

**Status:** Accepted (revised 2026-05-12 — LibreChat promoted to primary surface; see §Revision below)
**Date:** 2026-05-08

## Context

The audition is for three collaborators. We need them to be able to use the SOV stack themselves — not just watch a demo. But we cannot afford to keep the GPU running 24/7 (audition cost would explode), and we don't want to build real account management at the prototype stage.

Constraints:

- Three collaborators must be able to obtain working tokens themselves during a session.
- The audition runs in discrete sessions, typically <24 hours each, with a hard runtime cap enforced by launch scripts.
- Cost must be bounded even if URLs or keys leak — i.e., the failure mode of a leaked URL is "the existing session burns its remaining capped budget", not "an attacker mines tokens for a week."
- Building real auth (OAuth, per-user accounts, RBAC) is out of scope at this stage.
- Both an OpenAI-compatible API endpoint and a browser-accessible chat UI are needed.

## Decision

The audition surface is:

1. **An OpenAI-compatible HTTP endpoint** served by vLLM, for collaborators wiring their own tools (Claude Code, Aider, custom agents) into the stack.
2. **A [LibreChat](https://github.com/danny-avila/LibreChat) instance** sharing the same vLLM backend, for collaborators who'd rather click a link and chat in a browser. (Promoted from "phase-3 swap target" to primary on 2026-05-12 — see §Revision.)
3. **[Jan](https://jan.ai/)** is recommended (not provided) as a desktop client — collaborators who already use Jan can point it at the OpenAI-compatible endpoint with no install on our side.

The auth model is:

1. **Each session spins up a fresh pod with a unique random URL** (RunPod's `*.proxy.runpod.net` covers this; Cloudflare Tunnel as fallback for non-RunPod providers).
2. **The vLLM endpoint is started with `--api-key <random_token>`** — vLLM's built-in shared-key flag.
3. **LibreChat is started in no-registration mode** (`ALLOW_REGISTRATION=false`, `ALLOW_EMAIL_LOGIN=false`, a single pre-seeded admin account whose password is rotated per session) configured to forward the same vLLM key on its calls.
4. **The launch script prints, on startup**: the URL, the shared API key, the runtime cap, and the projected cost at cap.
5. **The launch script enforces a hard runtime cap** (`--max-runtime-hours`) by scheduling its own auto-destruct. Default 4 hours, ceiling 24.
6. **The teardown command is printed alongside** so collaborators can destroy early if done.

## Why not real accounts

- Three users. Real accounts are ceremony.
- We will get more signal on what auth actually needs to look like at phase 3 by *not* building it now. Premature account systems usually need to be ripped out.

## Why not just paste keys into a Slack channel

The shared-key + URL combo *is* basically that. The novel part is:

- The **URL** carries enough entropy that scanning the public internet won't find it.
- The **runtime cap** means the worst-case cost of a leak is the remaining session budget, not an open-ended bill.
- **No persistent state** — when the pod is destroyed, both keys and URL are gone. No revocation, no rotation; new session = new credentials.

## Why LibreChat (and not Open WebUI)

- **MIT licensed.** Open WebUI relicensed at v0.6.6 (April 2025) from BSD-3 to a custom non-OSI "Open WebUI License" with a CLA and a >50-user branding clause. LibreChat is MIT throughout. SOV's CLAUDE.md commits to "FOSS over vendor lock-in where it doesn't cost much"; the license tension makes Open WebUI marginally costly here.
- **MCP and OpenAI-plugin-standard alignment.** LibreChat ships first-class MCP support and aligns with the OpenAI plugin spec; Open WebUI's plugin system is custom (functions / pipelines). The MCP angle matters for SOV's composable-parts ethos and for cross-track workflow testing with the apple track.
- **Conversation forking.** LibreChat lets you branch a thread from any message — meaningful for serious work (compare prompt variants, explore alternative answers in parallel). Open WebUI has no equivalent.
- **Multi-model side-by-side comparison.** Useful for the phase-1 vLLM-vs-SGLang and FP8-vs-AWQ benchmark walkthroughs.

## What we trade off by choosing LibreChat

Honest assessment:

- **Slightly more deployment complexity.** Compose-y, more services than Open WebUI's single container. Manageable for SOV but not zero. The phase-1 docker-compose file absorbs this.
- **Single-user / no-signup mode is configured rather than default.** `ALLOW_REGISTRATION=false` plus a pre-seeded admin per session, rather than Open WebUI's one-flag toggle. Documented in the phase-1 runbook.
- **RAG out-of-box is less polished** than Open WebUI's collections / file-upload story. Acceptable at audition scale; if SOV's phase-2 RAG ambitions grow, this is the most likely friction point to revisit.

## Why Jan as a client recommendation but not a server

Jan is primarily an Electron desktop client (with a Jan Server option that is comparatively young). For collaborators who already use Jan, "point Jan at this URL" is a great experience. But running Jan Server as the *hosted* option for the audition would be choosing a less-mature option for an undifferentiated benefit. LibreChat is the better hosted choice today.

## Consequences

- Every launch script must produce: URL + API key + runtime cap + projected cost + teardown command, in a structured printout that's easy to paste into a chat for collaborators.
- The shared API key is an environment variable (`SOV_API_KEY` or similar) baked into the running containers — never written to disk in the repo.
- vLLM 0.7+ accepts multiple `--api-key` flags. If phase 2 or 3 wants per-collaborator keys without standing up real OAuth, this is the cheap shim — defers the auth ADR a phase further at zero infrastructure cost.
- LibreChat's no-registration single-admin config (env vars + a pre-seeded admin account whose credentials are rotated per session) is documented and the same across phases.
- Scripts assume RunPod's proxy URL by default; phase 1 may add a Cloudflare Tunnel codepath for Lambda. Note: **Cloudflare's 100-second proxy timeout** applies on the RunPod-proxy path and can cut very long streaming responses; if collaborators hit this, fall back to a direct TCP-port exposure or a Cloudflare Tunnel with the timeout extended.

## Re-evaluate when

- We move toward actual cooperative formation and recurring members. At that point, ADR 0006-or-whatever introduces real auth — likely an OAuth-fronted Caddy + per-user keys + capped quotas. That is a phase-3 problem, not earlier.
- A session leak actually happens. Post-mortem and harden as needed.
- A collaborator finds LibreChat insufficient for a real workflow and we need to evaluate alternatives. (Open WebUI is the closest if-LibreChat-doesn't-work fallback, accepting the licensing trade-off.)

## Revision 2026-05-12 — LibreChat promoted to primary

The original 2026-05-08 version of this ADR chose Open WebUI as the hosted browser UI on a "more battle-tested for self-hosted OpenAI-compat backends" reasoning. The 2026-05-12 cloud-track freshness audit surfaced two facts that flipped the call:

1. Open WebUI relicensed at v0.6.6 (April 2025) from BSD-3 to a custom non-OSI "Open WebUI License" requiring a CLA and a >50-user branding clause. SOV's stated FOSS principle (CLAUDE.md) tensions with shipping a non-OSI surface.
2. LibreChat's MCP and OpenAI-plugin-standard alignment is materially better for SOV's composable-parts ethos and for cross-track parity with the apple track's `mlx-lm + LiteLLM` stack — which is the workflow we want collaborators to practice.

The original ADR's pre-commit-to-LibreChat-at-phase-3 plan is collapsed: we go direct now rather than carry the licensing tension through phases 0–2 only to swap later. Cost of the earlier move is small (slightly more deployment complexity); benefit is FOSS branding consistency from day 1 plus better MCP testing throughout the audition.
