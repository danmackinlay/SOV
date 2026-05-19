#!/usr/bin/env python3
"""Work out which git commits a new digest should cover.

A digest covers the range (last digest's until_commit .. HEAD]. The
previous boundary is read from the YAML frontmatter of the most recent
file in the digest directory, so bookkeeping needs no separate state
file: each digest records where it stopped, and the next one starts
there.

Output is JSON on stdout so the calling skill can branch cleanly:

    {
      "since": "<sha or null on first run>",
      "until": "<HEAD sha>",
      "count": <int>,
      "first_run": <bool>,
      "nothing_new": <bool>,
      "log": "<git log oneline+stat for the range>"
    }
"""
import json
import re
import subprocess
import sys
from pathlib import Path

FRONTMATTER_UNTIL = re.compile(r"^until_commit:\s*([0-9a-f]{7,40})\s*$", re.M)


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True
    ).stdout.strip()


def latest_digest(digest_dir: Path) -> Path | None:
    if not digest_dir.is_dir():
        return None
    # Filenames are date-stamped (YYYY-MM-DD-...), so lexical sort == chronological.
    files = sorted(digest_dir.glob("*-digest.md"))
    return files[-1] if files else None


def main() -> int:
    digest_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("_digest")
    # Fallback start point when no prior digest exists. Default: 30 days back.
    fallback = sys.argv[2] if len(sys.argv) > 2 else "30 days ago"

    until = git("rev-parse", "HEAD")
    prev = latest_digest(digest_dir)

    if prev:
        m = FRONTMATTER_UNTIL.search(prev.read_text())
        if not m:
            print(
                f"error: {prev} has no 'until_commit:' in its frontmatter; "
                "cannot determine where the last digest stopped.",
                file=sys.stderr,
            )
            return 2
        since = git("rev-parse", m.group(1))
        first_run = False
    else:
        # No prior digest: bound the first one by date so it isn't the
        # entire repo history.
        since = git("rev-list", "-1", f"--before={fallback}", "HEAD") or None
        first_run = True

    rev_range = f"{since}..{until}" if since else until
    count = int(git("rev-list", "--count", rev_range))
    log = (
        git("log", "--stat", "--no-merges", "--date=short",
            "--pretty=format:%h %ad %an %s", rev_range)
        if count
        else ""
    )

    json.dump(
        {
            "since": since,
            "until": until,
            "count": count,
            "first_run": first_run,
            "nothing_new": count == 0,
            "log": log,
        },
        sys.stdout,
        indent=2,
    )
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
