# ADR 0001 — Cloud GPU providers for the audition

**Status:** Accepted
**Date:** 2026-05-08

## Context

We need rented GPUs for the SOV audition. Constraints:

- We are familiar with RunPod; not familiar with Lambda or DGX Cloud.
- The audition narrative is about *sovereignty*, so a US-cloud audition has an irony we should at least acknowledge.
- Australian-hosted GPU rental exists (AWS Sydney, Azure Australia East, some local providers) but H100 / equivalent availability is thin and prices run 30–60% above US-region equivalents. For an audition, the price delta is hard to justify; for the eventual real deployment, the whole point is to own the hardware so AU residency is automatic.
- We want a left-field cheap option to sanity-check pricing.

## Decision

For the audition phases:

1. **RunPod is the primary provider** for phases 0–2. It has built-in ephemeral proxy URLs (`*.proxy.runpod.net`) that are perfect for our shared-key + capped-runtime auth model, and we are familiar with it.
2. **Lambda Labs is the phase-1 fallback** when we need 8× H100 in a single pod and RunPod availability is poor.
3. **vast.ai is documented as the cheap-experimentation option** for phase 0 only, with explicit security caveats.
4. **Australian-hosted cloud is out of scope for the audition.** We surface the irony in the eventual cooperative-pitch document; we don't pay 1.5× to fix it for a prototype.
5. **DGX Cloud is documented as a phase-3 option** — relevant for verifying the NIM stack works before physical-DGX delivery, not for the prototype.

## vast.ai security caveat

vast.ai is a peer-to-peer GPU marketplace: hosts (anyone with a GPU) rent their hardware to renters. Hosts have **root on the physical machine** and could in principle inspect a renter's container memory, traffic, or persistent storage. This is fine for:

- Running unmodified open-weight model checkpoints (the weights are public).
- Synthetic test prompts.
- Stack-validation traffic (`curl` health checks, throughput probes).

It is **not** fine for:

- Internal cooperative documents.
- Member prompts containing real work content.
- Any fine-tuning that produces weights we'd want to keep private.

Vast.ai has a verified-host program that mitigates some of this; we should still treat vast.ai as a "cheap-and-public" tier and never put non-public data through it.

## Consequences

- Phase 0 launch script targets RunPod by default with a `--provider vast` flag for the cheap path.
- Phase 1 onward uses RunPod or Lambda only.
- ADR 0003 (auth model) is built around RunPod's proxy URL convention; if we move to a provider without that, we need a Cloudflare Tunnel fallback.
- The eventual cooperative-pitch document needs an explicit section on "we auditioned on US clouds — here's why that's still consistent with the sovereignty argument."

## Re-evaluate when

- A cheaper or more reliable AU-hosted GPU option becomes available.
- We hit a RunPod-specific limitation that costs more to work around than to switch.
- We start auditioning with non-public data, in which case vast.ai is removed from the phase-0 menu.
