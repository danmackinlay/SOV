# ADR 0003 — Audition surface and ephemeral auth model

**Status:** Accepted
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
2. **An [Open WebUI](https://github.com/open-webui/open-webui) instance** sharing the same vLLM backend, for collaborators who'd rather click a link and chat in a browser.
3. **[Jan](https://jan.ai/)** is recommended (not provided) as a desktop client — collaborators who already use Jan can point it at the OpenAI-compatible endpoint with no install on our side.

The auth model is:

1. **Each session spins up a fresh pod with a unique random URL** (RunPod's `*.proxy.runpod.net` covers this; Cloudflare Tunnel as fallback for non-RunPod providers).
2. **The vLLM endpoint is started with `--api-key <random_token>`** — vLLM's built-in shared-key flag.
3. **Open WebUI is started in single-user mode** (no signup) with a random shared password, configured to forward the same vLLM key on its calls.
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

## Why Open WebUI not LibreChat (today, with a phase-3 trigger)

- Open WebUI is more battle-tested for self-hosted, OpenAI-compatible-backend deployments.
- Its single-user mode is genuinely zero-friction for our use case.
- LibreChat is more featureful but heavier to deploy and configure; we don't need its multi-provider support at audition scale.

**Licensing caveat noted on 2026-05-12:** Open WebUI relicensed at v0.6.6 (April 2025) from BSD-3 to a custom **non-OSI "Open WebUI License"** that requires a CLA and mandates branding visibility (headers / sidebars / login / about) for any deployment with >50 users in a 30-day window. The 3-collaborator audition is well under that threshold and is compliant, but this tensions with SOV's stated "FOSS over vendor lock-in" principle (see CLAUDE.md). We accept it for the audition. **Pre-committed swap at phase 3** to [LibreChat](https://github.com/danny-avila/LibreChat) (MIT) before any plan that would push the cooperative past 50 members. The swap is straightforward at our scale because the surface contract (OpenAI-compatible backend, shared API key) is identical between the two.

## Why Jan as a client recommendation but not a server

Jan is primarily an Electron desktop client (with a Jan Server option that is comparatively young). For collaborators who already use Jan, "point Jan at this URL" is a great experience. But running Jan Server as the *hosted* option for the audition would be choosing a less-mature option for an undifferentiated benefit. Open WebUI is the better hosted choice today.

## Consequences

- Every launch script must produce: URL + API key + runtime cap + projected cost + teardown command, in a structured printout that's easy to paste into a chat for collaborators.
- The shared API key is an environment variable (`SOV_API_KEY` or similar) baked into the running containers — never written to disk in the repo.
- vLLM 0.7+ accepts multiple `--api-key` flags. If phase 2 or 3 wants per-collaborator keys without standing up real OAuth, this is the cheap shim — defers the auth ADR a phase further at zero infrastructure cost.
- Open WebUI's "single-user mode" config is documented and the same across phases (until the LibreChat swap; see licensing caveat above).
- Scripts assume RunPod's proxy URL by default; phase 1 may add a Cloudflare Tunnel codepath for Lambda. Note: **Cloudflare's 100-second proxy timeout** applies on the RunPod-proxy path and can cut very long streaming responses; if collaborators hit this, fall back to a direct TCP-port exposure or a Cloudflare Tunnel with the timeout extended.

## Re-evaluate when

- We move toward actual cooperative formation and recurring members. At that point, ADR 0006-or-whatever introduces real auth — likely an OAuth-fronted Caddy + per-user keys + capped quotas. That is a phase-3 problem, not earlier.
- A session leak actually happens. Post-mortem and harden as needed.
- A collaborator finds Open WebUI insufficient for a real workflow and we need to evaluate alternatives.
- **Membership trajectory points at >50 users**, triggering the pre-committed Open WebUI → LibreChat swap (see licensing caveat above). Don't wait for the threshold to actually crack; rotate at phase 3 planning.
