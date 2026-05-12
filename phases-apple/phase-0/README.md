# Apple laptop phase 0 — bare floor

**Goal:** prove that mlx-lm can serve a thinking-class small model on an Apple Silicon Mac and that Jan can talk to it. We are not yet testing routing, RAG, agents, or anything else. One model, one client, one endpoint.

Equivalent in spirit to the main [SOV cloud phase 0](../../phases-cloud/) — same "validate end-to-end with the small model" framing — but on Apple Silicon with no cloud component.

## Prerequisites

- macOS 14+ on Apple Silicon. The `local-small` reference pick (Qwen3.5-35B-A3B) wants ≥ 32 GB unified memory; on smaller machines, substitute per the [RAM-tier sizing table](../README.md#ram-tier-sizing) in the track README. Phase 0 only needs *some* model to work, not the reference one.
- [`uv`](https://docs.astral.sh/uv/) installed (`brew install uv`).
- Homebrew + Ollama (`brew install ollama`).
- Free disk: ≥ 30 GB in `~/.cache/huggingface/` for the small-model weights; budget more if you'll pull `local-math` or `local-big` in later phases.

The commands below use `mlx-community/Qwen3.5-35B-A3B-4bit` as the example model. On a smaller-RAM machine substitute the appropriate pick (e.g. an 8 B-class Qwen3 quant on a 24 GB Mac). The flow is identical.

Before starting, glance at the [freshness audit](../README.md#freshness-audit) in the track README. Model names rot fast; the example below was current at 2026-05-12, and the canonical place to check is [mlx-community](https://huggingface.co/mlx-community).

## Install

```bash
# MLX inference engine
uv tool install mlx-lm

# Hugging Face CLI — installs the new `hf` binary (`huggingface-cli` was
# deprecated in 2026 and is now a non-functional warning shim).
uv tool install huggingface_hub

# Pre-pull the model weights so first-token doesn't wait on the network
hf download mlx-community/Qwen3.5-35B-A3B-4bit  # or your tier's pick

# Live system view (optional but recommended)
brew install mactop

# Jan (chat client)
# Download the DMG from https://jan.ai and drag to /Applications
```

If `mlx-community/Qwen3.5-35B-A3B-4bit` isn't the exact current quant name on Hugging Face, search [`mlx-community`](https://huggingface.co/mlx-community) for the latest matching repo and update the alias in [`../bin/model-switch.sh`](../bin/model-switch.sh).

## Launch

```bash
# Start the mlx-lm server (one model, foreground, port 8080)
mlx_lm.server \
  --model mlx-community/Qwen3.5-35B-A3B-4bit \
  --host 127.0.0.1 \
  --port 8080
```

In another terminal, smoke-test the endpoint:

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "mlx-community/Qwen3.5-35B-A3B-4bit",
    "messages": [{"role": "user", "content": "Prove that the square root of 2 is irrational."}],
    "max_tokens": 4000
  }' | jq -r '.choices[0].message | "=== reasoning ===\n" + (.reasoning // "") + "\n\n=== answer ===\n" + (.content // "")'
```

You should see a multi-paragraph thinking trace followed by a proof. Tokens-per-second on a comfortably-provisioned machine (i.e. one with at least ~2× the model's resident size in unified memory) should be in the tens. If it's single digits, check `mactop` for swap pressure — you're likely running with too little headroom and should drop to a smaller-tier model from the [sizing table](../README.md#ram-tier-sizing).

### Response-shape gotchas

mlx-lm.server is OpenAI-*compatible*, not OpenAI-*identical* — two quirks worth knowing before they bite:

1. **Thinking traces land in a separate `reasoning` field** (not the OpenAI-standard `reasoning_content`). If you naively pull `.choices[0].message.content` from a thinking model's response and the model spent its whole token budget reasoning, you'll get an empty string. The jq filter above unions both fields; Jan's reasoning panel reads them automatically.
2. **Thinking-mode models need bigger `max_tokens`.** Qwen3.5 (and Qwen3 `*-Thinking`, and DeepSeek-R1-class models) think by default. A few-hundred-token cap that worked for non-thinking models will get truncated mid-thought; budget 2000–4000+ for non-trivial prompts.

### Disabling thinking per request

When you want a terse reply (one-line factual queries, structured output, agentic tool-calls), disable thinking via the chat-template kwarg — verified for mlx-lm.server with Qwen3.5:

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "mlx-community/Qwen3.5-35B-A3B-4bit",
    "messages": [{"role": "user", "content": "What is 2+2? Answer briefly."}],
    "max_tokens": 200,
    "chat_template_kwargs": {"enable_thinking": false}
  }' | jq -r '.choices[0].message.content'
# -> "4"
```

The key is `chat_template_kwargs` (note the `_kwargs` suffix — `chat_template_args` is silently ignored). The same flag works for Qwen3, Qwen3-Next, and the Qwen3.5 family; DeepSeek-R1-class models use a different mechanism (their template doesn't expose a disable-thinking switch — for those, just live with the trace or pick a non-reasoning model).

## Configure Jan

1. Open Jan.
2. Settings → Model Providers → Add new (OpenAI-compatible):
   - **Name:** `Local MLX`
   - **API base:** `http://127.0.0.1:8080/v1`
   - **API key:** anything; mlx-lm doesn't check.
3. Add a model entry with the same id you launched mlx-lm.server with.
4. Start a thread; pick that model.

Talk to it. Confirm it answers, thinks visibly (in `<think>` tags or Jan's reasoning panel, depending on Jan version), and feels responsive.

## Exit criteria

Phase 0 is done when **all** of these are true:

1. A conversation in Jan against the local model completes end-to-end with no errors.
2. Tokens-per-second on a non-trivial prompt is in the tens, not single digits, on a comfortably-provisioned machine. (On a tight-tier machine, drop the bar to "acceptable for your patience and adjust the model picks down.")
3. `mactop` shows no swap during a conversation.
4. The weights are on disk and the model loads from local cache (verify by airplane-mode + restart).
5. A one-line answer is written to [`impressions.md`](impressions.md) on whether `local-small` feels useful for prose editing tasks. (Not "is it as good as Claude" — is it good enough to be the flight-mode fallback?)

## Budget

| Item | Cost |
|---|---|
| Weights download (~23 GB for the reference pick; less for smaller-tier picks) | bandwidth + ~30 min |
| Active "is this useful?" testing | half a day |
| Phase 0 dollar cost | $0 |

The cost cap on the laptop track is thermal and battery, not currency. Running `local-small` on battery for an hour is fine on most tiers; running `local-big` (phase 3) on battery is never a good idea.

## What's deliberately out of scope here

- LiteLLM proxy → phase 1.
- Aider against a local model → phase 1.
- RAG, embeddings, PDFs → phase 2.
- Anything visual (Draw Things, ComfyUI, vision models) → phase 3 / 4.
- The `model-switch.sh` and `model-status.sh` helpers work already, but phase 0 doesn't strictly need them — running one model from one terminal is the point.

## Open questions for phase 0

- **Thinking-mode vs. instruct-mode.** Phase 0 uses a thinking-by-default variant on the bet that explicit reasoning will be more useful than terseness for the prose/math workload. (Qwen3.5 thinks by default; older Qwen3 had explicit `-Thinking` vs `-Instruct` variants.) If it's painfully slow on the laptop or the trace is noisy, disable thinking at request time via `chat_template_kwargs: {"enable_thinking": false}` (see [Response-shape gotchas](#response-shape-gotchas) above) or swap to a non-thinking model.
- **Should Jan be configured to filter thinking traces from the visible reply?** Default: keep them visible during phase 0 so we can see what the model is doing. Revisit at phase 1.
