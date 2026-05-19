#!/usr/bin/env python3
"""Upload a digest as an unsent Buttondown draft.

A note on why this calls the REST API directly rather than the
`buttondown` CLI: the CLI was the intended tool, but its `push` command
is broken for our use. It sends the *entire local file* — YAML
frontmatter included — as the email body (see its sync.js: `body:
processedContent` where processedContent is the raw file). Buttondown's
API then refuses with "email body appears to contain frontmatter". That
makes `push` unable to create a draft from the very files `buttondown
create` itself produces. Until that's fixed upstream we talk to the
documented endpoint the CLI wraps:

    POST https://api.buttondown.com/v1/emails
    Authorization: Token <key>

The safety properties Dan cares about are preserved and are in fact
stronger this way:

- The key is read from the environment (direnv put it there per ADR
  0006). It is used for this one request and never written anywhere.
- We never run `buttondown login` (interactive-only; would persist a
  key on disk — the cross-newsletter hazard, since Dan manages several
  lists from one machine).
- We never read `.envrc.local`. If `BUTTONDOWN_API_KEY` is not in the
  environment, we say so and stop.
- The email is created with `status: draft` and no publish date, so it
  is unsent and cannot be sent automatically. Sending stays a human
  action in the Buttondown dashboard. This script never calls a
  send/schedule endpoint.

Usage:
    buttondown_draft.py _digest/2026-05-19-digest.md --dry-run  # preview, no API call
    buttondown_draft.py _digest/2026-05-19-digest.md            # create the draft
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

API_URL = "https://api.buttondown.com/v1/emails"


def parse(md: str) -> tuple[str, str]:
    """Return (subject, body). Subject is the frontmatter `subject:` if
    present, else the first markdown H1. The digest's bookkeeping
    frontmatter (since_commit/until_commit/generated) is stripped so
    subscribers never see it and so Buttondown doesn't reject the body."""
    subject = None
    body = md
    fm = re.match(r"^---\n(.*?)\n---\n(.*)$", md, re.S)
    if fm:
        meta, body = fm.group(1), fm.group(2).lstrip("\n")
        sm = re.search(r"^subject:\s*(.+?)\s*$", meta, re.M)
        if sm:
            subject = sm.group(1).strip().strip('"').strip("'")
    if not subject:
        h1 = re.search(r"^#\s+(.+?)\s*$", body, re.M)
        subject = h1.group(1).strip() if h1 else "SOV research notes"
    return subject, body


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    if not args:
        print("usage: buttondown_draft.py <digest.md> [--dry-run]", file=sys.stderr)
        return 2

    path = Path(args[0])
    if not path.is_file():
        print(f"error: {path} not found", file=sys.stderr)
        return 2

    subject, body = parse(path.read_text())
    payload = {"subject": subject, "body": body, "status": "draft"}

    if dry:
        print("DRY RUN — no API call made.")
        print(f"  subject : {subject}")
        print(f"  body    : {len(body)} chars")
        print(f"  status  : draft (unsent)")
        print(f"  POST    : {API_URL}")
        return 0

    key = os.environ.get("BUTTONDOWN_API_KEY")
    if not key:
        print(
            "error: BUTTONDOWN_API_KEY is unset. It should come from the "
            "repo's direnv environment (see ADR 0006 / .envrc.example). "
            "Do NOT run `buttondown login` and do NOT read .envrc.local — "
            "if it's missing, ask Dan to `direnv allow`.",
            file=sys.stderr,
        )
        return 1

    req = urllib.request.Request(
        API_URL,
        data=json.dumps(payload).encode(),
        method="POST",
        headers={
            "Authorization": f"Token {key}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        print(
            f"error: Buttondown returned {e.code}: {e.read().decode()}",
            file=sys.stderr,
        )
        return 1

    eid = data.get("id", "?")
    print(f"Draft created: {subject!r}")
    print(f"  id: {eid}")
    print("  Review, humanise, and send it from "
          "https://buttondown.com/emails/drafts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
