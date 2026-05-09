# Public-repo policy

The SOV repo is public. We benefit from openness: the rationale documents are already public on Dan's blog, replication by other collectives is a stated goal of the project, and discoverability compounds. But "public" needs an explicit perimeter so we can stay public confidently.

## What goes in the public repo

- The plan, ADRs, phase docs, scripts, Compose files, benchmark results.
- Discussion of architectural trade-offs, including criticism of vendors.
- De-identified summaries of audition session findings.
- Test prompts that are synthetic or already public (e.g., from published evaluation suites or from the rationale's de-censoring test taxonomy).

## What does NOT go in the public repo

- **Operational secrets.** API keys (RunPod, Lambda, vast.ai, OpenAI-compatible endpoints, HuggingFace tokens, anything else); SSH keys; access tokens. `.env` files. These are gitignored; double-check before each commit.
- **Identifying info on individual humans** beyond the publicly-named project leads. No teammate's home address, no real names of would-be members, no Slack/Signal/email handles unless the person has explicitly OK'd publication.
- **Member rosters** (when there are members). Membership belongs to the cooperative, not the public.
- **Internal cooperative discussions.** Meeting notes, contentious deliberations, financial details of individual members. Use a private channel; if a decision lands in the repo, it lands as a finalised ADR or short note, not as a transcript.
- **Real prompt content from individual users.** When we test with non-synthetic data, redact identifying material before checking in benchmark traces or example outputs.
- **Anything that would compromise an audition session in flight** — live URL + key combos. These are destroyed when the pod is destroyed; don't paste them into commits.

## When we'd lock the repo down

We flip to private if any of the following happens:

- Coordinated adversarial attention that makes it hard to collaborate.
- A specific operational reason — e.g., a member-onboarding workflow that genuinely requires private development for a window.
- A legal or regulatory reason we don't currently anticipate.

If we lock down, we announce it in the README first so anyone watching knows what happened.

## How to check before committing

Before any commit, particularly when scripts or `.env` examples are involved:

1. `git status` — confirm `.env` and any `secrets/` paths are not staged.
2. `git diff --staged | grep -iE 'token|key|secret|password|api[-_]?key'` — quick eyeball for inline credentials.
3. If a script needs a credential, it reads from environment variables. Never inline.

If something sensitive does land in a commit, **don't just delete it in a follow-up commit** — the history is public. Rotate the credential immediately and consider rewriting history (`git filter-repo`) if it was a high-value secret.
