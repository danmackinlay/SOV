# ADR 0008 — Newsletter digest talks to Buttondown via the REST API, not the CLI

**Status:** Accepted
**Date:** 2026-05-19

## Context

We publish an occasional plain-language newsletter so interested
laypeople can follow how SOV's thinking evolves. The mechanical half of
that — turn recent git activity into a date-stamped draft and put it in
Buttondown as an *unsent* draft for a human to humanise and send — is
done by a local Claude skill (`sov-newsletter-digest`, lives under the
gitignored `.claude/`, so it is not itself a tracked repo artefact;
this ADR is). The skill is draft-only by design: it never sends, that
stays a human action.

Buttondown exposes two integration surfaces: an official Node CLI
(`@buttondown/cli`) and a documented REST API
(`POST https://api.buttondown.com/v1/emails`). The CLI was the intended
tool — it models a newsletter as a synced folder of markdown files
(`pull`/`push`), which would also give us a git-tracked archive of every
issue, something we actively want. We evaluated it properly before
deciding.

Findings (verified 2026-05-19, not assumed):

- **The only released CLI version (`1.0.9`, the sole npm release ever,
  Oct 2025) is broken for our use.** Its `push` sends the entire local
  file — YAML frontmatter included — as the email body; Buttondown
  rejects that ("email body appears to contain frontmatter"). It fails
  on the very files `buttondown create` produces. This is upstream
  issue [buttondown/cli#14], closed with "fixed in `main`, just needs a
  release" — a release that has not happened.
- **`buttondown login` is unusable headless.** It is an interactive Ink
  TUI that errors in any non-interactive shell, and it persists the API
  key to disk (`~/Library/Preferences/buttondown-cli-nodejs`). Dan
  manages several newsletters with different keys from one machine; a
  persisted key is exactly how the wrong list gets mailed. Both reasons
  make `login` a non-starter regardless of the bug.
- **Pinning to the fixed code is fragile.** The public `buttondown/cli`
  repo is a *squashed mirror* — one commit (`70654ba`), no granular
  history, no tags, `package.json` still says `1.0.9`. The only
  pinnable artefact is that mirror commit, which can be re-mirrored.
  Building from it needs `bun` (`prepare: bun run build`); `npm install`
  at that commit fails `ERESOLVE`. Installable with effort, not cleanly.
- **The REST path works today.** It is one documented endpoint with
  `Authorization: Token <key>`, the key read per-invocation from the
  direnv environment (ADR 0006), persisted nowhere. Tested live on
  2026-05-19: draft created, unsent, correct.

The decisive lens is the CLAUDE.md replicability norm: *a second
collective should be able to fork this repo and follow it.* A
dependency that is broken in its only release and otherwise needs a
`bun` build of an unreleasable squashed-mirror commit is the least
replicable option on the table. ~40 lines of Python stdlib hitting a
documented endpoint is the most replicable.

## Decision

**The newsletter skill creates Buttondown drafts by POSTing to the REST
API directly (Python stdlib, no third-party dependency). It does not
use the `buttondown` CLI and never runs `buttondown login`.**

Mechanics and guarantees:

- The API key comes from `BUTTONDOWN_API_KEY` in the direnv environment
  (ADR 0006), used for the one request, written nowhere. The script
  never reads `.envrc.local`; if the var is unset it says so and stops.
  When direnv is not loaded in-shell, invoke under `direnv exec .` so
  the key is injected without anyone reading the secrets file.
- The payload is `status: draft` with no publish date. The skill never
  calls a send or schedule endpoint. Sending stays a human action in
  the Buttondown dashboard. This editorial boundary is deliberate.
- The digest's bookkeeping frontmatter (commit range etc.) is stripped
  before upload so subscribers never see it and the API does not reject
  the body.

## What we explicitly aren't doing

- **Not using `@buttondown/cli`** at any version while its only release
  is broken for draft creation and the fix is unreleased.
- **Not pinning the CLI to the squashed-mirror commit.** Reproducibility
  cost (bun build, `ERESOLVE`, re-mirrorable hash, lying version
  metadata) outweighs the benefit for a one-endpoint task.
- **Not building the git-tracked email archive yet.** The CLI's
  `pull`-style mirror of all issues into committed markdown is
  genuinely wanted, but it is a *feature*, not a blocker for shipping
  drafts. When built it will be our own `GET /v1/emails` → `emails/*.md`
  mirror in a format we own, not a CLI-dependent one.

## Consequences

- The newsletter integration has zero third-party runtime dependency;
  any forking collective reproduces it with a Python interpreter and a
  Buttondown key. Matches the public-repo policy (scripts read secrets
  from env, never inline).
- We carry ~40 lines of integration code we own outright. If Buttondown
  changes the `/emails` contract, we fix one function — no waiting on an
  upstream release cycle that has fired once in the project's life.
- No git-tracked newsletter archive *yet*; issue history currently lives
  only in date-stamped `_digest/<YYYY-MM-DD>-digest.md` files plus
  whatever is in the Buttondown dashboard.

## Re-evaluate when

- Buttondown publishes a real npm release that closes
  [buttondown/cli#14]. At that point `buttondown pull`/`push` becomes
  the lowest-maintenance way to keep a git-tracked archive and is worth
  a ~5-minute swap — *if* the per-invocation `--api-key` (never
  `login`) and isolated-working-dir safety properties still hold.
- The git-tracked full-history archive becomes a priority rather than a
  nice-to-have (build the `GET /v1/emails` → committed `emails/*.md`
  mirror; revisit CLI-vs-own-code for that specific job then).
- The skill ever needs to do more than create one draft per issue
  (branding, templates, bulk reconciliation) — that is where the CLI's
  sync model earns its keep and the trade reopens.

[buttondown/cli#14]: https://github.com/buttondown/cli/issues/14
