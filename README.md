# SOV

> **SOV Outlasts Vendors.**

Prototype work for an Australian sovereign-LLM cooperative — a "try before you buy" audition of the software stack that would eventually run on owned hardware.

We're building in the open. Three initial collaborators are scoping it; the repo is public so other Australian groups thinking about the same problem can find us, fork freely, and (eventually) run their own audition. We are not yet at a stage where we accept code contributions from outside collaborators.

## Where to start

1. **Why we're doing this** — read the rationale, two posts on Dan's blog:
   - [The institutional/geopolitical case](https://danmackinlay.name/notebook/aus_sovereign_llm.html)
   - [The technical companion](https://danmackinlay.name/notebook/aus_sovereign_llm_technical.html)
   - See [`docs/rationale/`](docs/rationale/) for a short index pointing at these. We don't mirror them in-repo, to avoid drift.

2. **What we're building** — read [`PLAN.md`](PLAN.md). That's the live plan, the architecture decisions, and the phased roadmap.

3. **How we collaborate with Claude Code** — see [`CLAUDE.md`](CLAUDE.md) for shared agent context. Anyone running Claude Code in this repo will get this loaded automatically.

## Status

Early. Currently in **planning**. No phase has shipped yet.

See [`PLAN.md`](PLAN.md) for the current phase, exit criteria, and what we're working on next.

## Contributing

We're an early, three-person project — please don't open PRs without checking in first. We may not be able to review them, and we don't want to mislead anyone about engagement bandwidth.

What's welcome:

- **Issues** flagging factual errors in [`PLAN.md`](PLAN.md) or the [ADRs](docs/decisions/) — we'd rather know.
- **Forks** by other groups thinking about sovereign compute. The Apache-2.0 [`LICENSE`](LICENSE) is permissive; replication is a stated goal of the project. If you fork to start your own collective, [say hi](https://danmackinlay.name/contact.html).
- **Contact** if you're interested in the cooperative itself — see Dan's contact page.

What gets kept out of the public repo (operational secrets, member info, internal discussions) is documented in [`docs/context/public-repo-policy.md`](docs/context/public-repo-policy.md).
