# SOV

> **SOV Outlasts Vendors.**

Prototype work for an Australian sovereign-LLM cooperative — a "try before you buy" audition of the software stack that would eventually run on owned hardware.

We're building in the open.
The initial collaborators are scoping it; the repo is public so other Australian groups thinking about the same problem can find us, fork freely, and (eventually) run their own audition.
We are not yet at a stage where we accept code contributions from outside collaborators.

This repo will be most LLM-agent built; we are rapidly auditioning technology here for now and drilling down later.

## End goal

If the audition succeeds, the target is a small Australian collective that owns a DGX-class workstation, runs a de-censored open-weight model on it, and serves inference to its members — with no commercial vendor in the dependency chain. The diagram below sketches that target. It is not a commitment: the audition exists to test whether it is worth building.

```mermaid
flowchart TB
  members["Cooperative members (AU)<br/>LibreChat in the browser · Jan on the desktop · agentic tools"]
  subgraph sov["Owned, in Australia — outlasts vendors"]
    box["GB300-class DGX workstation<br/>bought once, hosted by the collective"]
    model["De-censored open-weight model<br/>+ fast reasoning sidecar"]
    stack["vLLM + LiteLLM + Caddy<br/>OpenAI-compatible endpoint"]
  end
  vendors["Commercial LLM vendors"]
  members -->|members' own keys| stack
  stack --> model
  model --> box
  members -. no dependency .-> vendors
```

## Where to start

0. **Interested? [Sign up for updates](https://woozy-page-39c.notion.site/32d398af2ab0805293a9dfb1561b4bdf?pvs=105).**
1. **Why we're doing this** — read the rationale, two posts on Dan's blog:
   - The [institutional/geopolitical case](https://danmackinlay.name/notebook/aus_sovereign_llm.html)
   - The [technical sktch](https://danmackinlay.name/notebook/aus_sovereign_llm_technical.html) (which we hope to be superceded by this)
   - See [`docs/rationale/`](docs/rationale/) for the executive summary.

2. **What we're building** — read [`PLAN.md`](PLAN.md). That's the live plan, the architecture decisions, and the phased roadmap.

3. **How we collaborate with Claude Code** — see [`CLAUDE.md`](CLAUDE.md) for shared agent context. Anyone running Claude Code in this repo will get this loaded automatically.

## Status

See [`PLAN.md`](PLAN.md) for the current phase, exit criteria, and what we're working on next.

## Contributing

We're an early, small-collective project — please don't open PRs without checking in first.
We may not be able to review them, and we don't want to mislead anyone about engagement bandwidth.

What's welcome:

- **Issues** flagging factual errors in [`PLAN.md`](PLAN.md) or the [ADRs](docs/decisions/) — we'd rather know.
- **Forks** by other groups thinking about sovereign compute. The Apache-2.0 [`LICENSE`](LICENSE) is permissive; replication is a stated goal of the project. If you fork to start your own collective, [say hi](https://danmackinlay.name/contact.html).
- **Contact** if you're interested in the cooperative itself — see Dan's contact page.

What gets kept out of the public repo (operational secrets, member info, internal discussions) is documented in [`docs/context/public-repo-policy.md`](docs/context/public-repo-policy.md).
