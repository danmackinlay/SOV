# ADR 0007 — DeepSeek V4 and the concurrency consequence

**Status:** Accepted
**Date:** 2026-05-17

## Context

DeepSeek released V4 in April 2026. Two open-weight variants:

- **V4-Pro** — 1.6T total / 49B active. Rivals top closed models; state-of-the-art open agentic coding.
- **V4-Flash** — 284B total / 13B active. Reasoning approaches V4-Pro; multi-tier thinking modes (Non-think / Think-High / Think-Max).

The parameter counts are not why this lands in our decision log. The attention design is. V4 uses sparse attention (DSA / CSA+HCA): it compresses context before storing it, so a full million-token conversation costs roughly 9.6 GB of KV cache instead of the tens of GB a conventional model of the same class needs — about a 90% reduction (DeepSeek tech report; corroborated by Together.ai and the Hugging Face tech blog).

That number changes the arithmetic the whole sovereign-per-box economic case rests on. What follows works that arithmetic from the ground up, because the conclusion is only as trustworthy as a reader's ability to redo it.

### An accounting identity

A model generates text one token at a time, and each new token attends to every token before it. Recomputing the whole conversation per token would be quadratically wasteful, so when a token is first seen the model computes a Key and a Value vector for it and stores them. Future tokens reuse the stored vectors. That store is the KV cache.

The property we care about: model weights are a fixed cost paid once and shared by everyone, whereas the KV cache is a per-conversation, per-token cost, and it sits in the same scarce fast memory as the weights. So:

```
fast GPU memory  =  weights (paid once)  +  KV cache (paid per user, per token)

concurrent users  ≈  (memory left after weights)  ÷  (KV cost of one conversation)
```

Everything below is those two lines with numbers in them.

### A conventional model, worked

Using the figures the [technical rationale](https://danmackinlay.name/notebook/aus_sovereign_llm_technical.html) already audits, so this stays internally consistent with the repo:

| Quantity | Value | Source |
|---|---|---|
| Fast memory on the box (`M`) | 252 GB | DGX-class HBM |
| Weights, 4-bit (`W`) | ≈124 GB | rationale's quantization table |
| KV budget `B = M − W` | ≈128 GB | subtraction |
| KV cost per token (`k`), FP8 | ≈96 KB | rationale's per-token KV formula |

Tokens the box can hold in cache at once:

```
B ÷ k  =  128 GB ÷ 96 KB
       =  137,000,000,000 bytes ÷ 98,304 bytes
       ≈  1,400,000 tokens          (≈1.4M — matches the rationale's table)
```

Tokens become people once we divide by how long each conversation is:

```
@   8K tokens/session :  1.4M ÷     8,000  ≈ 175 users
@  32K tokens/session :  1.4M ÷    32,000  ≈  44 users
@ 128K tokens/session :  1.4M ÷   128,000  ≈  11 users
@   1M tokens/session :  1.4M ÷ 1,000,000  ≈ 1.4 users
```

Pause on the 32K row before reading on: why is the 8K row exactly four times larger? Because the token pool is fixed and concurrency is just pool ÷ session length. We lean on that one line for the rest of this note.

### Where the agentic regime breaks it

Read the table top to bottom and concurrency falls off a cliff as conversations lengthen. A 50-person collective with 5–15 active members is comfortable at 8K–32K and falls over at 1M, where one member running a single million-token agentic session fills the box.

This is the assumption hiding in the rationale's economics: the comfortable numbers assume short conversations. The collective's headline use case — agentic and long-context work — drives sessions toward the bottom rows, where the box chokes. The KV cache is the wall, and agentic work runs straight at it.

### The same arithmetic with DSA

V4-Flash changes one input to the calculation above: a full million-token context costs ≈9.6 GB of KV rather than tens of GB. Same identity, new numbers:

| Quantity | Value | Note |
|---|---|---|
| Fast memory (`M`) | 252 GB | same box |
| V4-Flash weights, 4-bit (`W`) | ≈90 GB | search-corroborated; conservative |
| KV budget `B` | ≈160 GB | 252 − 90, rounded down for overhead |
| KV cost of a full 1M-token session | ≈9.6 GB | DeepSeek published figure |

```
concurrent users, each holding a FULL 1M-token context:
   B ÷ 9.6 GB  =  160 GB ÷ 9.6 GB  ≈  16–17 users
```

The two worked examples side by side, at the regime the collective cares about:

```
                       conventional model      V4-Flash + DSA
  @ 1M-token session :     ≈ 1.4 users     →      ≈ 16 users      (~11× more)
  @ 128K-token session:    ≈ 11 users      →      hundreds*       (KV no longer the limit)
```

\*At 128K each session uses a small fraction of the 9.6 GB figure, so KV memory stops being what limits the box in that regime — the constraint moves elsewhere (see caveats).

The economic case was tightest exactly where the collective most wants to work — long-context agentic — because the KV wall put it there. DSA moves the wall out by roughly an order of magnitude in the memory dimension. The box does not become infinite; the question changes from "we run out of memory after one power user" to "how much throughput does the box have", which is measurable and fundable. That is a better question.

### Caveats

1. These are illustrative figures, not measurements. They reuse the repo's audited conventional numbers and DeepSeek's *published* DSA figure. Phase-1's benchmark workstream exists to replace them with measured numbers; treat the above as order-of-magnitude. The repo's "no unverified vibes" norm stays intact precisely because the working is shown and labelled.
2. A memory ceiling is not a throughput guarantee. Sixteen million-token sessions *fitting in memory* does not mean the box can *generate tokens fast enough* for sixteen heavy users at once. DSA also cuts attention compute (~27% of the prior generation's at 1M, per the tech report), which helps, but the binding constraint moves rather than disappears.
3. We anchored on the endpoints we can cite — the rationale's audited conventional KV figure and DeepSeek's published 1M figure — rather than inventing V4-Flash's intermediate per-token head maths.

## Decision

1. **V4-Flash enters the phase-1 bake-off as a third arm**, alongside Qwen3.5-122B-A10B FP8 and AWQ. Not an automatic swap — same compute class, newer, stronger published agentic/reasoning numbers, native vLLM `deepseek_v4` support, but the comparison is empirical and belongs in phase 1.
2. **V4-Pro is a cloud-rented ceiling reference only.** At ≈648 GB even at Q6 it does not usably fit the owned box (same failure mode the rationale documents for Kimi K2, worse). Its role is the audition question "here is the best open model money can rent versus the one that fits our box — is the gap acceptable", which the rationale already frames as the point of the exercise.
3. **The DSA concurrency consequence is load-bearing for the economic case**, not a footnote. A note propagates back to the `livingthing` rationale (Dan owns that text); SOV records the working here.
4. **Phase-2 workstream C keeps a two-backend LiteLLM demo regardless.** If V4-Flash's multi-tier thinking collapses the workhorse/reasoning-sidecar split, repurpose the second slot to a cheap classifier rather than dropping to one backend — the demo is the DGX-pattern rehearsal and is worth keeping.
5. **Phase-2 workstream B notes V4's native Anthropic API** as a likely elimination of the OpenAI→Anthropic shim (PLAN §9 open question #2).

## Consequences

- Phase-1 benchmark matrix gains a model arm; the §5 quant/engine grid is now Qwen3.5-122B {FP8, AWQ} × {vLLM, SGLang} plus V4-Flash FP8.
- vLLM must be pinned to a known-good V4 commit, not just a release tag — multiple reports of V4 working then breaking across vLLM commits (NVIDIA dev forum, May 2026). This sharpens the §10 "never `:latest`" rule rather than adding a new one.
- Abliteration carries an architecture-lag risk. Heretic issue #310 (V4-Flash) is open and unresolved; a community abliterated V4-Flash exists but only as GGUF for llama.cpp, so phase-2 workstream A would still need to produce a vLLM-servable FP8 abliterated build. Do not assume Qwen-level abliteration maturity.
- The CCP-guardrail position is unchanged. Open weights neutralize the dependency problem, not the alignment one; V4 only changes which model sits under the abliteration knife.

## Re-evaluate when

- Phase-1 benchmark lands measured numbers — replace the illustrative arithmetic here with the real table and link it.
- Heretic issue #310 resolves, or another tool demonstrates a vLLM-servable abliterated V4-Flash.
- A smaller DSA-class open model appears that fits the box with more headroom than V4-Flash.
