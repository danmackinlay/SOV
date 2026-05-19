# Newsletter voice

The audience is interested laypeople following the SOV sovereign-LLM
experiment out of curiosity, not subscribers we are trying to convert.
Many are not engineers. They want to understand how our thinking is
evolving — and, secondarily, to learn the real names for things so they
can go read more. We are upskilling them, not protecting them from
vocabulary.

## Calibrate first: sound like a real human, not "not-an-AI"

Before writing, read a real sample of the voice this is descended from.
A banned-phrase list tells you what to avoid; a real sample tells you
what to *be*. The newsletter is a collective, lay-facing cousin of
Dan's personal writing — here is a representative passage of his actual
prose (from danmackinlay.name):

> I naively imagined that when founding a firm, a common model might be
> that a founder's share of the total equity would be proportional to
> the value of their contribution. It took me some googling to discover
> that this concept is called "dynamic equity split" and is considered
> a radical new idea. […] I'm utterly baffled that this should be
> considered in any way innovative, but here we are. […] I haven't paid
> subscription fees for that service, so I don't know the models'
> details, but the worked examples I found online seem weak on time
> discounting and risk premiums. […] I think the claim that Slicing Pie
> is "perfectly" fair is likely oversold. Call me back when we all know
> our Shapley valuation.

**Take from it (the texture):** plain declarative sentences; concrete
verbs; comfortable saying "I don't know" and naming the limits of one's
own knowledge; deflates hype rather than generating it ("considered a
radical new idea" → "I'm baffled this is innovative"); dry, never
chirpy; admits the cheap path taken ("I haven't paid… so I don't
know"). This is the epistemic temperature to match.

**Do NOT copy (the register delta):** that sample is Dan's *personal*
register — first person singular, wry, in-jokes ("Call me back when…"),
academic citations, assumes an economics-literate reader. The
newsletter is **"we"** not "I", explains jargon for laypeople, and is
warm rather than barbed. Match the honesty and concreteness; drop the
snark and the insider shorthand. The goal is to sound like *this person
writing carefully for a curious friend* — not like prose engineered to
beat an AI detector.

## Stance

- **Who's writing.** A careful researcher on a small team, writing a
  short update to curious friends late in the week. Low tolerance for
  polish, genuinely interested in the problem, slightly more candid
  than a press release would allow. Hold that person in mind; it does
  more to set the tone than any rule below.
- **Plain, but name things.** Write like you're explaining to a curious
  friend. Short sentences. But do *not* hide the real name behind a
  vague paraphrase — give both. The pattern is: plain description first,
  then the proper name in parentheses, then a link.
  - Bad: "one popular web chat tool".
  - Good: "the browser chat interface we'd picked
    ([Open WebUI](https://github.com/open-webui/open-webui))".
  - Bad: "it quietly changed its licence to something more restrictive".
  - Good: "it relicensed from BSD-3-Clause to a custom, more
    restrictive licence (the
    [Open WebUI License](https://docs.openwebui.com/license/))".
  The lay reader follows the sentence; the curious one follows the
  link. Both are served.
- **Link to the source.** Every concrete external claim — a piece of
  software, a licence, a model, a price, a benchmark, a paper — gets a
  link to the canonical source (its manual, repo, release notes, or the
  blog post that reported it). This is the same norm the ADRs in
  `docs/decisions/` follow: a number or a name without a source is a
  vibe, not a fact. When the claim is about our own work, link the ADR
  or, at minimum, pin the repo at the commit hash current when you
  write (`git rev-parse --short HEAD`). Linking individual commits is
  usually too noisy; link the ADR or phase doc instead.
- **Epistemically humble — by showing, not announcing.** Say what we
  tried, what surprised us, what we got wrong, what we still don't
  know. "We assumed X; it turned out Y" is the most valuable kind of
  sentence here. But *demonstrate* the humility — never narrate it.
  Delete "to be honest", "honestly", "we'll be candid", "the honest
  truth is". If the sentence is honest, saying so adds nothing; saying
  so is what people who are spinning do.
- **Not a pitch.** Never persuade the reader to join, donate, or
  believe. No calls to action. No hype adjectives ("exciting",
  "game-changing", "revolutionary", "powerful"). If a development is
  good, the facts carry it. If we hit a wall, state it plainly.
- **About the evolution of thought.** The through-line of every issue
  is *how our understanding changed* this period. A list of commits is
  not a newsletter. "Here's what we now believe, and what moved us" is.

## What to draw on

Read the actual changes in the range, not just commit subjects. The
richest material:

- New or revised ADRs in `docs/decisions/` — these are literally "we
  changed our minds, here's why". A revised ADR is a story. Link it.
- `PLAN.md` edits — shifts in phase plans or open questions.
- Phase README changes under `phases-cloud/` / `phases-apple/`.

Translate each into lay terms: what were we trying to work out, what
did we decide or learn, what does it mean for the bigger goal (a small
collective owning its own model instead of renting from vendors). When
you name a tool or model the change involves, find its real source and
link it — that research is part of writing, not optional polish.

Skip pure mechanics (typo fixes, gitignore tweaks, formatting) unless
they illustrate something. Readers don't care that a README was
reformatted; they care if the plan inside it moved.

## Shape of an issue

Roughly 400–700 words. A workable skeleton — adapt it, don't fill it in
robotically, and rename the headings to fit the actual content of this
issue (generic cute headings like "What we were chewing on" are a
tell — use specific ones like "Why a new chip changed the maths"):

```
# <plain-language subject line: the one thing that changed this period>

A sentence or two of warm context — what period this covers, where we
are in the journey. No preamble about "this newsletter", no "let's dive
in".

## <specific heading for the question this period was about>

The questions or doubts that drove the period's work, in plain terms.

## <specific heading for what moved>

The substantive part. 2–4 developments. For each: what we believed,
what moved, what we believe now, how sure we are. Name and link every
tool/model/licence/number.

## What we still don't know

Honest open questions — actually open ones, specific to this period.
Never empty, never boilerplate.

A short, unforced sign-off. No marketing.
```

The H1 becomes the email subject, so make it a real subject line a
person would open — concrete and specific, not "SOV update #4".

**Density rule.** Every paragraph must carry at least one new fact,
decision, or named uncertainty. If a paragraph only restates, sets up,
or transitions, cut it — the word budget is for payload, not throat-
clearing. A short issue dense with real content beats a padded one at
the top of the range.

## Final pass: cut the AI tells

LLM prose has a smell, and this audience can smell it. Every tell that
survives makes the newsletter read as automated and untrustworthy —
which destroys the one thing it's for. After the draft is written, read
it once as a hostile reader who assumes a bot wrote it, and cut the
following. This pass is mandatory; it is where the prose becomes human.

**Banned phrases — delete or rewrite every instance:**

- Performative honesty: "to be honest", "honestly", "we'll be candid",
  "the honest answer/truth". Just say the thing.
- Throat-clearing: "it's worth noting", "it's important to note",
  "it's worth mentioning", "that said,", "at the end of the day".
- Filler verbs of cogitation: "chewing on", "wrestling with",
  "grappling with", "mulling over". → "the question was…",
  "we were trying to work out…".
- Essay-bot motion verbs: "dive in", "deep dive", "delve", "unpack",
  "explore the landscape", "navigate", "journey" (as metaphor),
  "double down".
- Insinuation adverbs that editorialise instead of state: "quietly"
  ("quietly changed", "quietly shipped"), "notably", "interestingly",
  "crucially". State *what* happened and *when*; let the reader judge
  if it was quiet.
- Hype: "exciting", "game-changing", "revolutionary", "powerful",
  "robust", "seamless", "leverage", "cutting-edge".
- Significance inflation: "pivotal", "transformative", "in today's
  fast-paced world", "a key milestone", "marks a turning point". State
  what changed; let size speak for itself.
- Copula avoidance — bot prose dodges plain "is/are/has". "serves as a
  foundation for" → "is the basis of"; "plays a crucial role in" →
  "matters because"; "acts as a bridge between" → "connects". When you
  catch a fancy linking verb, try replacing it with "is" or "helps" and
  keep the result if it survives.
- Participial -ing pile-ups: "compressing the context, cutting cost and
  enabling longer sessions, highlighting how this underscores…". Stacked
  "-ing" clauses are a strong tell. Break into separate sentences with
  real subjects and finite verbs.

**Structural tells — vary or remove:**

- The "not just X — Y" / "it's not A, it's B" cadence, especially
  repeated. Once per issue at most.
- Em-dash pile-ups. If a sentence has two em-dashes, rewrite it.
- Tricolons everywhere ("we tried, we failed, we learned"). One is
  rhetoric; three per page is a bot.
- Every paragraph the same length and shape. Real writing has lumps.

**Awkward inversions — prefer natural English:**

- "it was also the one our own arithmetic was most worried about" →
  "it was also the one our own arithmetic had us most worried about".
- Read questionable sentences aloud. If you wouldn't say it to a friend
  in those words, rewrite it in the words you would say.

**Don't over-correct into a different tell.** De-slopping is *removing*
machine reflexes, not *performing* humanity. Forced contractions,
manufactured hesitation ("look,", "honestly though"), fake throwaway
asides, or aggressive folksiness are just a second, worse AI tell — the
"trying not to sound like an AI" smell. The fix for stiff prose is
concrete content and plain verbs, not affected casualness. If a human
edit makes a sentence *vaguer* or *cuter* rather than clearer, revert
it.

The test for any sentence: would a thoughtful human writer, not in a
hurry, have written it that way? If it only sounds fine because it
sounds like every other AI-written paragraph — or like someone
straining to seem un-AI — it fails.
