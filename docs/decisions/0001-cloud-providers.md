# ADR 0001 — Cloud GPU providers for the audition

**Status:** Accepted
**Date:** 2026-05-08

## Context

We need rented GPUs for the SOV audition. Constraints:

- We are familiar with RunPod; not familiar with Lambda or DGX Cloud.
- The audition narrative is about *sovereignty*, so a US-cloud audition has an irony we should at least acknowledge.
- Australian-hosted GPU rental has grown materially in 2025–2026 (**SHARON AI** has 1,016× H200/B200 in an AU datacenter; **ResetData AI-F1** runs B200 in Melbourne; **Micron21** offers Tier IV-hosted H100 dedicated leases; **NEXTDC** colocates H200 fleets; plus AWS Sydney / Azure Australia East). On-demand hourly pricing still runs ~30–60% above US-region equivalents, and most AU offers are bare-metal monthly leases rather than minute-billed pods — a poor fit for our ephemeral-audition model. For the audition, the cost and pattern mismatch are hard to justify; for the eventual real deployment, the whole point is to own the hardware so AU residency is automatic.
- We want a left-field cheap option to sanity-check pricing.

## Decision

For the audition phases:

1. **RunPod is the primary provider** for phases 0–2. It has built-in ephemeral proxy URLs (`*.proxy.runpod.net`) that are perfect for our shared-key + capped-runtime auth model, and we are familiar with it. May 2026 pricing: H100 PCIe ~$2.39/hr, H100 SXM ~$2.99/hr, H200 SXM ~$3.99/hr, B200 ~$5.49/hr.
2. **Lambda is the phase-1 fallback** when we need 8× H100 in a single pod and RunPod availability is poor. Note the domain rename: lambdalabs.com → **lambda.ai**. May 2026 pricing: H100 SXM ~$3.99/GPU/hr on-demand self-serve (i.e. 8× H100 ≈ $32/hr, not the $24/hr the early plan assumed); B200 SXM ~$6.69/GPU/hr.
3. **vast.ai is documented as the cheap-experimentation option** for phase 0 only, with explicit security caveats. May 2026 pricing: H100 SXM ~$2.00/hr (~33% below RunPod), H100 NVL ~$1.52/hr.
4. **Crusoe is a documented backup** if both RunPod and Lambda have availability issues. H100 ~$3.90/hr, H200 ~$4.29/hr; same US-cloud sovereignty caveat as the others but with a clean-energy angle that resonates with the broader cooperative-pitch narrative. Not the default — listed so we don't scramble for an alternative if both primaries are full.
5. **Australian-hosted cloud is out of scope for the audition.** We surface the irony in the eventual cooperative-pitch document; we don't pay 1.5× for a prototype.
6. **DGX Cloud is documented as a phase-3 option** — relevant for verifying the NIM/Dynamo stack works before physical-workstation delivery, not for the prototype.

## vast.ai security caveat

vast.ai is a peer-to-peer GPU marketplace: hosts (anyone with a GPU) rent their hardware to renters. Hosts have **root on the physical machine** and could in principle inspect a renter's container memory, traffic, or persistent storage. This is fine for:

- Running unmodified open-weight model checkpoints (the weights are public).
- Synthetic test prompts.
- Stack-validation traffic (`curl` health checks, throughput probes).

It is **not** fine for:

- Internal cooperative documents.
- Member prompts containing real work content.
- Any fine-tuning that produces weights we'd want to keep private.

Vast.ai now offers a tiered verification system (automated machine-level checks plus a **Certified Data Center** label introduced in 2025, with a blue trust badge for identity-verified operators running 5+ GPU servers in a managed facility). Filtering to certified-DC hosts narrows the trust gap considerably. We still treat untiered vast.ai as a "cheap-and-public" tier and never put non-public data through it.

## Consequences

- Phase 0 launch script targets RunPod by default with a `--provider vast` flag for the cheap path.
- Phase 1 onward uses RunPod or Lambda only.
- ADR 0003 (auth model) is built around RunPod's proxy URL convention; if we move to a provider without that, we need a Cloudflare Tunnel fallback.
- The eventual cooperative-pitch document needs an explicit section on "we auditioned on US clouds — here's why that's still consistent with the sovereignty argument."

## Re-evaluate when

- A cheaper or more reliable AU-hosted GPU option becomes available.
- We hit a RunPod-specific limitation that costs more to work around than to switch.
- We start auditioning with non-public data, in which case vast.ai is removed from the phase-0 menu.
