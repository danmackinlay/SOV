# ADR 0006 — Secret handling and configuration

**Status:** Accepted
**Date:** 2026-05-12

## Context

Both tracks need credentials: RunPod / Lambda / HF tokens for the cloud track, optional Anthropic / OpenAI API keys for cross-stack routing on either track, ephemeral session-shared keys generated per launch. The [public-repo policy](../context/public-repo-policy.md) forbids any of these from landing in git. We need an explicit pattern for *how* collaborators handle them.

The choice space is wide — `.env` files, password-manager CLIs, SOPS-encrypted files in-repo, full-blown secret managers (Vault, Bitwarden Secrets Manager, Infisical, Doppler, AWS Secrets Manager). All of them earn their keep at *some* scale; none of them is right at *all* scales. The KISS principle in CLAUDE.md says we should pick the simplest layer that holds and only escalate when it stops holding.

A specific simplification falls out of how SOV is designed: **most SOV secrets are per-collaborator, not shared.** The audition's "shared key" pattern is shared *within a single ephemeral session* (generated per pod launch, dies with the pod) — it never needs to live anywhere persistent. The persistent secrets (RunPod API key, Lambda credentials, HF token, personal Anthropic key for cloud routing) are each collaborator's own and don't cross between people. The first shared-persistent secret on the roadmap is phase-2 abliterated-weights storage credentials (PLAN.md §9 open question 1), and that's still hypothetical.

## Decision

**Phased adoption matching the rest of SOV's "cheap now, escalate when forced" posture:**

### Phase 0–1: direnv + per-collaborator `.envrc.local`

- **[direnv](https://direnv.net/)** loads environment variables when you `cd` into the repo and unloads them when you leave. `brew install direnv`; hook into your shell.
- A committed `.envrc` at repo root declares which variables the project consumes (one bullet per var with a one-line description) and `dotenv_if_exists .envrc.local`. No secret values in any committed file.
- A committed `.envrc.example` is the template a new collaborator copies to `.envrc.local`, fills in their personal values, and runs `direnv allow`.
- `.envrc.local` is gitignored. It is the *only* secret-bearing filename pattern the policy accepts in the repo working tree.
- Sub-track `.envrc` files in [`phases-cloud/`](../../phases-cloud/) and [`phases-apple/`](../../phases-apple/) `source_up` the parent so values cascade and don't need to be repeated.
- Apple-side and cloud-side share env-var names where they overlap (`HF_TOKEN`, `ANTHROPIC_API_KEY`) so one `.envrc.local` covers both tracks. Track-specific vars (e.g., `RUNPOD_API_KEY` only matters cloud-side) sit unset on the other side, harmless.

### Optional, any time: personal-vault integration

Collaborators who prefer not to keep secrets in flat files can source them from a password manager via direnv's `op`-style stdlib functions. Within SOV the preferred personal vault is **[Bitwarden](https://bitwarden.com/)** (cleaner FOSS posture than 1Password); the `bw` CLI integrates with direnv via straightforward shell helpers. 1Password's `op` CLI works equivalently if a collaborator already lives there. This is per-collaborator preference, no project-level coordination — the `.envrc.local` file just sources from `bw get` instead of holding literals.

### Phase 2: introduce SOPS+age **only if** a shared persistent secret actually materialises

The first plausible shared-persistent-secret trigger is PLAN.md §9 open question 1 (abliterated-weights storage credentials). If that lands as "private HF org token" or "shared S3-equivalent bucket credentials", we add **[SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age)** as a way to commit encrypted secrets to the repo, decryptable by collaborators holding age private keys. SOPS-encrypted files live in git; the age private keys themselves stay in each collaborator's `.envrc.local` / personal vault. direnv keeps working unchanged; the source of values just shifts. Smallest possible step up — no server, no service.

If the §9 question resolves as "regenerate from script each time, never store", we skip this step entirely.

### Phase 3: real secret manager

Triggered by cooperative formation (real members, real shared infrastructure, real audit-log requirements), not by audition needs. Candidates at the time:

- **[Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/)** — natural extension if collaborators are already using Bitwarden personally, FOSS-aligned.
- **[HashiCorp Vault](https://www.vaultproject.io/)** — credible at this stage; several SOV collaborators have prior Vault experience and may pitch it. Heavier than the alternatives but battle-tested.
- **[Infisical](https://infisical.com/)** / **[Doppler](https://www.doppler.com/)** — SaaS, lower operational burden, weaker on the sovereignty narrative.
- **HashiCorp/Bitwarden self-hosted on the DGX** — keeps secret management on owned infrastructure, fits the sovereignty arc.

Picked by an ADR at phase 3, not now. The phase 0–2 work stays valid: a future Vault or BWS deployment just becomes another `direnv` source.

## What we explicitly aren't doing

- **No `.env` files** in repo subdirectories. `.envrc.local` is the single secret-bearing pattern.
- **No secret management server in phases 0–2.** Three collaborators, no shared persistent secrets, no audit-log requirement; a server is theatre.
- **No committing encrypted secrets to the repo before phase 2.** SOPS+age is fine when it earns its keep; before that, two people each maintaining their own gitignored `.envrc.local` is simpler.
- **No bypassing direnv for production-style env injection** at phases 0–2 (i.e., no `--env-file` to `docker run` that points at a non-direnv file). One mechanism, fewer places to leak.

## Consequences

- Every phase doc / launch script that needs credentials reads them from environment variables, not files. This already matches the [public-repo policy](../context/public-repo-policy.md) "scripts read from env vars; never inline."
- The committed `.envrc.example` is the canonical inventory of "what credentials does SOV need from me." Keep it up to date as new vars enter the stack.
- New collaborator onboarding: install direnv, `cp .envrc.example .envrc.local`, fill in values, `direnv allow`. Documented in repo README.
- Ephemeral session keys (`SOV_API_KEY`, LiteLLM master key) are generated by launch scripts and never written to disk — they live only in the running container's env. Don't conflate them with persistent credentials.
- Pre-commit check from [public-repo policy](../context/public-repo-policy.md) already greps for `token|key|secret|password` in staged diffs; this ADR doesn't change that.

## Re-evaluate when

- PLAN.md §9 question 1 resolves in favour of a shared persistent secret (triggers the SOPS+age step).
- Membership grows past audition scale and real shared state emerges (triggers the phase-3 manager choice).
- A collaborator accidentally commits a secret to git history despite the policy (triggers a pre-commit-hook hardening pass, possibly `git-secrets` or `trufflehog`).
- Any collaborator's `.envrc.local` is meaningfully painful to maintain (the warning sign that we've outgrown the simple pattern).
