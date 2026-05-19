---
name: sov-newsletter-digest
description: >-
  Turn recent git activity in the SOV repo into a friendly, plain-language
  draft newsletter for interested laypeople, and upload it to Buttondown as
  an unsent draft for a human to humanise and send. Use this whenever Dan
  asks to "write the newsletter", "do a digest", "update followers",
  "summarise what's changed since last time", "draft the next issue", or
  otherwise wants recent SOV progress turned into subscriber-facing prose.
  Also use proactively after a meaningful run of commits/ADRs when Dan
  mentions telling followers or writing an update, even without the word
  "newsletter".
---

# SOV newsletter digest

This skill produces the *draft* of a recurring newsletter that explains
the SOV sovereign-LLM experiment to interested laypeople. It does the
mechanical work — figure out what changed since last time, write a
humble plain-language summary, save it date-stamped, push it to
Buttondown as an unsent draft. The human then edits it in Buttondown's
dashboard and presses send. The skill never sends anything itself; that
editorial boundary is deliberate.

Run every step from the repo root (`/Users/dan/Source/SOV`).

## Step 1 — Find what changed since the last digest

Each digest records the commit it stopped at in its YAML frontmatter, so
there is no separate state file. Let the helper work out the range:

```bash
python3 .claude/skills/sov-newsletter-digest/scripts/digest_range.py _digest
```

It prints JSON: `since`, `until`, `count`, `first_run`, `nothing_new`,
and a `log` of the commits + file stats in range.

- If `nothing_new` is true, tell Dan there's nothing new since the last
  digest and stop. Don't write an empty issue.
- If `first_run` is true there's no prior digest; the range is bounded
  to the last ~30 days so the first issue isn't the whole repo history.
  Mention this to Dan in case he wants a different starting point.

## Step 2 — Understand the changes, not just the log

The commit log is raw material, not the story. Read the actual diffs
for anything substantive in the range — especially:

- new or revised ADRs under `docs/decisions/` (these *are* "we changed
  our minds" stories),
- `PLAN.md` edits (phase or open-question shifts),
- phase README changes under `phases-cloud/` / `phases-apple/`.

`git show <sha>` or `git diff <since>..<until> -- <path>` as needed.
Skip pure mechanics (formatting, gitignore, typos) unless they
illustrate a real shift.

## Step 3 — Write the issue

Read [`references/voice.md`](references/voice.md) and follow it closely —
the tone (friendly, epistemically humble, never a pitch, focused on how
our *thinking* evolved) is the entire value of this newsletter, so this
is the step that matters most. Pay particular attention to its
"Calibrate first" section and read the embedded voice sample before you
start writing — matching a real human's texture works better than
avoiding a banned list. The repo's `CLAUDE.md` has the project context
(the audition concept, the "SOV Outlasts Vendors" motto, the phases)
you need to explain things in lay terms.

While writing, gather sources as you go — this is research, not
optional polish. Every tool, model, licence, price, or paper you
mention gets its real name *and* a link to the canonical source (its
manual, repo, release notes, or the post that reported it), exactly as
the ADRs do. You can't link a manual you didn't open, so open it. For
claims about our own work, link the relevant ADR/phase doc, or pin the
repo at the current short hash (`git rev-parse --short HEAD`).

Write the file to `_digest/<YYYY-MM-DD>-digest.md` using today's date.
The date in the filename is the bookkeeping key — keep that format so
the next run's range detection works.

It must start with this frontmatter (the commit SHAs come straight from
Step 1's JSON; they are how the *next* run knows where to start):

```markdown
---
subject: <the plain-language subject line, also used as the email subject>
generated: <YYYY-MM-DD>
since_commit: <since sha from step 1, or "ROOT" on first run>
until_commit: <until sha from step 1>
---

# <subject line>

<body — see references/voice.md for shape and tone>
```

## Step 3b — The de-slop pass (do not skip)

A first draft from an LLM always carries the tells in
`references/voice.md`'s "Final pass" section — performative honesty,
"chewing on", "quietly changed", essay-bot motion verbs, the "not just
X — Y" cadence, awkward inversions. These are nearly impossible to
avoid while generating and easy to catch on a hostile re-read, so they
get their own pass rather than being trusted to the first draft.

Re-read the whole draft as a reader who assumes a bot wrote it and is
looking for proof. Apply the blocklist and the structural/inversion
checks in `references/voice.md` literally. Rewrite, don't just trim —
but heed the "Don't over-correct" warning: the fix for stiff prose is
concrete content and plain verbs, not affected casualness. Then check
every external claim actually carries a link.

When you show Dan the result, lead with a short bulleted list of the
specific tells you found and what you changed (e.g. "cut 'chewing on' →
'the question was'; named Open WebUI + licence; broke an -ing pile-up").
This is not bookkeeping — Dan is upskilling on this too, and seeing the
catch (and what you might have missed) is half the value. Then show the
de-slopped draft prose so he can react before it goes anywhere.

## Step 4 — Upload to Buttondown as a draft

Once Dan is happy with the prose, upload it. Always do a dry run first
so Dan sees exactly the subject and body that will be staged and
nothing surprising hits the API:

```bash
python3 .claude/skills/sov-newsletter-digest/scripts/buttondown_draft.py \
  _digest/<YYYY-MM-DD>-digest.md --dry-run
```

Then, on Dan's go-ahead, the real upload (same command without
`--dry-run`). The script strips the digest's bookkeeping frontmatter so
subscribers never see it, derives the subject from the `subject:`
field, and creates the email with status `draft` — unsent, sitting in
the dashboard for Dan to humanise and send by hand.

How it talks to Buttondown, and why this way:

- It POSTs to Buttondown's documented endpoint
  (`https://api.buttondown.com/v1/emails`) with
  `Authorization: Token <key>`. The `buttondown` CLI was the intended
  tool but its `push` is upstream-broken for this: it sends the whole
  local file (frontmatter and all) as the email body, and Buttondown
  rejects that. The script's header comment records the detail.
- **Never run `buttondown login`.** It is interactive-only (hangs in a
  non-interactive shell) and persists a key on disk. Dan manages
  several newsletters with different keys from one machine; a persisted
  key is how you'd push to the wrong list. The script reads the key
  fresh from the environment per run and writes it nowhere.
- **Never read `.envrc.local`.** That's Dan's secret store. The key is
  already in the environment via direnv (per ADR 0006). The script
  reads `BUTTONDOWN_API_KEY` from the environment only; if it's unset
  it says so and points at `.envrc.example` — do not go hunting for the
  value. (If direnv isn't loaded in your shell, run the script under
  `direnv exec . python3 …` so the key is injected without anyone
  reading the secrets file.)
- The payload is `status: draft` with no publish date, so the email is
  unsent and cannot be sent automatically.

If the dry run or the real call reports anything other than one draft
created, stop and show Dan the output rather than retrying blindly.

## Notes

- The date-stamped `_digest/<YYYY-MM-DD>-digest.md` files are working
  artefacts. They are not secret (no keys, just prose), so they're fine
  to commit if Dan wants a history of issues — but that's his call, not
  automatic.
- Never call the Buttondown send/scheduling endpoints, and never run
  `buttondown login`. This skill's contract is draft-only; sending
  stays a human action.
- The *why* behind using the REST API instead of the `buttondown` CLI
  (and the conditions under which we'd revisit) is recorded in
  [ADR 0008](../../../docs/decisions/0008-newsletter-buttondown-integration.md).
  If you find yourself reconsidering the integration, read it first.
