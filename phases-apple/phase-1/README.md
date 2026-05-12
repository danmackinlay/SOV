# Apple laptop phase 1 — SOV-style composable stack

**Goal:** stand up the controlled endpoint that the rest of the apple track depends on. Replace phase 0's all-in-one Jan-as-MLX-stack with a stack of composable pieces: `mlx_lm.server` running the model, [LiteLLM](https://github.com/BerriAI/litellm) proxy in front exposing model aliases, [Aider](https://aider.chat) wired up as the first agentic-coding client. Jan stays — its posture flips from "full stack" to "thin client against the LiteLLM endpoint."

This is the phase that unlocks agentic work. Phase 0 proved your Mac can serve a local model at all; phase 1 makes that serving *programmable*.

Equivalent in spirit to the main [SOV cloud phase 0](../../phases-cloud/) — same "validate the composable stack end-to-end" framing — but on Apple Silicon, no cloud GPU.

## Prerequisites

- Phase 0 passed. (You've had at least one working Jan-internal-MLX conversation on this Mac. If not, do that first.)
- macOS 14+ on Apple Silicon. The `local-small` reference pick (Qwen3.5-35B-A3B) wants ≥ 32 GB unified memory; on smaller machines, substitute per the [RAM-tier sizing table](../README.md#ram-tier-sizing).
- [`uv`](https://docs.astral.sh/uv/) installed (`brew install uv`).
- Homebrew + Ollama (`brew install ollama`) — Ollama stays around for embeddings later; phase 1 doesn't strictly need it but it's a one-liner.
- Free disk: ≥ 30 GB in `~/.cache/huggingface/` for the small-model weights; budget more if you'll pull `local-math` or `local-big` later. Cleanup commands: [Cleanup & disk management](../README.md#cleanup--disk-management).
- direnv configured per [ADR 0006](../../docs/decisions/0006-secret-handling.md); `HF_TOKEN` set in `.envrc.local` if you'll pull gated models.

The commands below use `mlx-community/Qwen3.5-35B-A3B-4bit` as the example model. On a smaller-RAM machine substitute the appropriate pick (e.g. an 8 B-class Qwen3 quant on a 24 GB Mac). The flow is identical.

Before starting, glance at the [freshness audit](../README.md#freshness-audit) in the track README. Model names rot fast; the example below was current at 2026-05-12.

## Install

```bash
# MLX inference engine
uv tool install mlx-lm

# Hugging Face CLI — installs the new `hf` binary (`huggingface-cli` was
# deprecated in 2026 and is now a non-functional warning shim).
uv tool install hf

# LiteLLM proxy with the [proxy] extras for the OpenAI-compat router
uv tool install 'litellm[proxy]'

# Aider — agentic coding/prose editor; works against any OpenAI-compat endpoint
uv tool install aider-chat

# Pre-pull the model weights so first-token doesn't wait on the network
hf download mlx-community/Qwen3.5-35B-A3B-4bit  # or your tier's pick

# Live system view (optional but recommended)
brew install mactop
```

If `mlx-community/Qwen3.5-35B-A3B-4bit` isn't the exact current quant name on Hugging Face, search [`mlx-community`](https://huggingface.co/mlx-community) for the latest matching repo and update the alias in [`../bin/model-switch.sh`](../bin/model-switch.sh).

## Launch mlx-lm.server via the switch helper

Phase 1 introduces the [`bin/model-switch.sh`](../bin/model-switch.sh) discipline: one MLX model at a time, on port 8080, managed by a script that enforces the one-at-a-time rule and waits for the model to be ready before returning.

```bash
# From the repo root (so direnv picks up .envrc):
./phases-apple/bin/model-switch.sh small   # launches Qwen3.5-35B-A3B per the MODELS map
./phases-apple/bin/model-status.sh         # confirm what's loaded, see memory pressure
```

`small` corresponds to `local-small` in the [model aliases](../README.md#models); the `math` and `big` aliases work the same way.

Smoke-test the raw endpoint:

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "mlx-community/Qwen3.5-35B-A3B-4bit",
    "messages": [{"role": "user", "content": "Prove that the square root of 2 is irrational."}],
    "max_tokens": 4000
  }' | jq -r '.choices[0].message | "=== reasoning ===\n" + (.reasoning // "") + "\n\n=== answer ===\n" + (.content // "")'
```

You should see a multi-paragraph thinking trace followed by a proof. Tokens-per-second on a comfortably-provisioned machine (~2× the model's resident size in unified memory) should be in the tens. If it's single digits, check `mactop` for swap pressure — drop to a smaller-tier model.

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

## LiteLLM proxy

The proxy is what turns "one model at a fixed port" into "named aliases your clients can address." Phase 1 wires the three local aliases; phase 2 adds Anthropic/OpenAI cloud routing on top of the same config.

The config lives at **[`phases-apple/phase-1/litellm-config.yaml`](./litellm-config.yaml)** — committed in the repo, no secrets, no need to create it yourself. When phase 2 adds cloud backends, their `api_key` fields read from env vars via direnv (`os.environ/ANTHROPIC_API_KEY` etc.), so the file stays committable.

For reference, the starter contents:

```yaml
model_list:
  - model_name: local-small
    litellm_params:
      model: openai/mlx-community/Qwen3.5-35B-A3B-4bit
      api_base: http://127.0.0.1:8080/v1
      api_key: not-needed

  - model_name: local-math
    litellm_params:
      model: openai/mlx-community/DeepSeek-R1-0528-Qwen3-8B-4bit
      api_base: http://127.0.0.1:8080/v1
      api_key: not-needed

  - model_name: local-big
    litellm_params:
      model: openai/mlx-community/Qwen3.5-122B-A10B-4bit
      api_base: http://127.0.0.1:8080/v1
      api_key: not-needed

litellm_settings:
  drop_params: true   # silently drop unsupported params instead of erroring
```

All three aliases point at the same port 8080 because `model-switch.sh` only ever has one model loaded there. The alias name in the request tells you which model you *intend* to use; if the wrong one is loaded, the proxy will happily forward the request and mlx-lm.server may answer with a different model than the alias name suggests. **Run `model-switch.sh small|math|big` first to load the model you want; the alias is documentation, not routing.**

(Later phases that wire cloud backends will get a real model-to-port mapping; for phase 1 this is intentionally simple.)

Launch the proxy (from the repo root — all SOV commands run from there, per the [working-directory rule](../README.md#operational-discipline)):

```bash
./phases-apple/bin/litellm-start.sh
```

You now have an OpenAI-compatible endpoint at `http://127.0.0.1:4000/v1` that knows three model names. The wrapper handles `--config`, `--host 127.0.0.1`, and the port default; extra args pass through. Two env-var overrides if you want to deviate:

- `LITELLM_CONFIG=path/to/other.yaml ./phases-apple/bin/litellm-start.sh` — point at a different config file.
- `LITELLM_PORT=4001 ./phases-apple/bin/litellm-start.sh` — bind a different port (e.g. when running two proxies side-by-side for A/B work).

**Why a wrapper and not just `litellm --config ... --host 127.0.0.1 --port 4000`?** Two reasons:

1. **LiteLLM defaults to `--host 0.0.0.0` (all interfaces), which on a wifi-connected laptop exposes the proxy and the model behind it to anyone on the LAN.** A direct CLI invocation that forgets `--host 127.0.0.1` is a foot-gun. The wrapper makes the safe default the easy default.
2. **LiteLLM also reads an unscoped `HOST` env var** as the `--host` fallback (via its `envvar="HOST"` Click option). Exporting `HOST=127.0.0.1` repo-wide via direnv would collide with shells, ssh wrappers, and generic web tooling that all touch `HOST`. The wrapper scopes the env var to the litellm subprocess only (single-command prefix, not an export), and also passes `--host 127.0.0.1` explicitly as belt-and-braces.

There is no YAML-config equivalent — host binding lives in CLI/env-var space only.

Sanity-check the bind after launch:

```bash
lsof -nP -iTCP:4000 -sTCP:LISTEN
# Expect a single line with "127.0.0.1:4000". If it shows "*:4000" the
# wrapper got bypassed somehow — debug.
```

If you need to launch directly without the wrapper (one-off testing, a different cwd, a one-shot port change), the explicit form is:

```bash
litellm --config phases-apple/phase-1/litellm-config.yaml --host 127.0.0.1 --port 4000
```

Remembering `--host 127.0.0.1` is the load-bearing discipline in that form.

(From [ADR 0006](../../docs/decisions/0006-secret-handling.md) and the [LiteLLM CVE history](../README.md#operational-discipline): pin LiteLLM ≥ 1.83.7 by digest, never internet-exposed.)

## Reconfigure Jan as a thin client

In Jan: **Settings → Model Provider → switch from MLX (phase 0 setup) to OpenAI-compatible** with:

- **API base:** `http://127.0.0.1:4000/v1` (LiteLLM, not mlx-lm directly — gives you alias routing)
- **API key:** anything; LiteLLM doesn't check at this stage (master-key gating arrives in phase 2 when cloud backends enter).
- **Models:** add `local-small`, `local-math`, `local-big` as three available models.

Start a new thread, pick `local-small`, say hello. Same conversation experience as phase 0, but now the model is loaded by `model-switch.sh` and exposed through LiteLLM, which means the next sections (Aider, eventually MCP and RAG) can address the same endpoint.

Jan's internal MLX backend from phase 0 doesn't need to be disabled — it just sits unused. The "Disable on startup" toggle from the [Why Jan as a thin client](../README.md#why-jan-as-a-thin-client-not-as-a-full-stack) section saves a few hundred MB of RAM if you're tight.

## Aider against the local endpoint

Aider is the first agentic-coding client wired against the SOV stack. It edits files via unified-diff prompting, which works well even on 30 B-class local models because it sends small per-turn payloads rather than re-streaming the whole file.

**Env vars** — Aider (and any other openai-SDK client) discovers the proxy via two env vars:

- `OPENAI_API_BASE` is **auto-set** by [`phases-apple/.envrc`](../.envrc) to `http://127.0.0.1:4000/v1` (the wrapper's port). No action required as long as your cwd is anywhere under `phases-apple/`. Repo-root cwd inherits via direnv's parent chain on shell load. Override in `.envrc.local` if you ever want a different proxy.
- `OPENAI_API_KEY` is **per-collaborator** and lives in your `.envrc.local` — see [`.envrc.example`](../../.envrc.example) for the template. At phase 1 LiteLLM doesn't validate the key (any non-empty string works; a sentinel like `local-not-checked` is nice in tracebacks); at phase 2 it becomes the proxy's master key.

Launch in a directory you'd like Aider to edit:

```bash
./phases-apple/bin/model-switch.sh small   # if not already
aider --model openai/local-small --no-stream  # --no-stream helps reasoning models
```

Try a small task — open one of your own `.qmd` notebook entries (or any prose file) and ask Aider to tighten a paragraph, rename a section heading, or add a sentence. Watch the diff land.

For genuine code work, expect Qwen3.5-35B-A3B to handle small-to-medium edits well; multi-file refactors or anything requiring a lot of project context will feel limited compared to Claude. That's expected — local models trade ceiling for sovereignty.

Aider's full local-model documentation: [aider.chat/docs/llms/openai-compat.html](https://aider.chat/docs/llms/openai-compat.html).

## Exit criteria

Phase 1 is done when **all** of these are true:

1. `model-switch.sh small|math|big` swaps the running model cleanly; `model-status.sh` reflects reality.
2. LiteLLM proxy serves the three aliases on port 4000; a curl to `/v1/models` lists them.
3. Jan, reconfigured to point at LiteLLM, completes a conversation against `local-small`.
4. Aider, pointed at LiteLLM, makes at least one successful edit to a real file (prose or code) and the diff is what you expected.
5. `mactop` shows no swap during normal operation.
6. A short note in [`impressions.md`](impressions.md) records: does the local stack feel useful enough to be the flight-mode fallback? Aider against `local-small` — usable for what kinds of work, frustrating for what kinds?

## Budget

| Item | Cost |
|---|---|
| Weights download (~23 GB reference pick; less for smaller tiers) | bandwidth + ~30 min |
| Tool installs (`uv tool install`s) | < 5 min |
| Active phase-1 testing | a day |
| Phase 1 dollar cost | $0 |

The cost cap on the apple track is thermal and battery, not currency. Running `local-small` on battery for an hour is fine on most tiers; running `local-big` (phase 3) on battery is never a good idea.

## What's deliberately out of scope here

- **RAG, embeddings, PDF ingestion** → phase 2 (Marker + LanceDB + AnythingLLM).
- **Stretch model + vision** → phase 3 (`local-big`, Qwen3-VL-8B).
- **LibreChat web UI + MCP testing + OrbStack** → phase 4. Phase 1 deliberately doesn't introduce Docker on the apple side; Jan handles the chat surface already.
- **opencode as Claude-Code-alike** → phase 4. Aider is enough at phase 1.
- **Image and audio generation** → phase 4 side quests.
- **Cloud routing through LiteLLM** (Anthropic, OpenAI fallbacks) → phase 2 alongside RAG. Phase 1's `litellm-config.yaml` stays local-only.

## Open questions for phase 1

- **`--no-stream` vs streaming with Aider.** Local thinking-mode models can produce confusing streamed output (the `reasoning` field doesn't stream cleanly through all clients). If you find Aider misbehaving with the default streaming, `--no-stream` is the reliable fallback.
- **Should `litellm-config.yaml` live in `phases-apple/phase-1/` (per-phase) or somewhere shared?** Phase 2 will add cloud backends; if those configs duplicate across phases, refactor to `phases-apple/litellm-config.yaml` shared. Defer the decision until phase 2 makes the duplication concrete.
- **Aider edit-format on local models.** Aider defaults vary by model; `--edit-format diff` is reliable across models but verbose. Worth tuning per-model after a few sessions.

## Bridge to phase 2

Phase 2 introduces RAG over your Zotero / PDF corpus. The phase-1 stack stays exactly as-is — phase 2 adds:

1. Marker for PDF → markdown ingestion.
2. LanceDB as a file-backed vector store.
3. mixedbread embeddings via the existing Ollama install.
4. AnythingLLM as the RAG-aware desktop client (alongside Jan, not replacing it).
5. Anthropic / OpenAI as optional cloud-fallback aliases in `litellm-config.yaml` for when local context is insufficient.

When you're ready, open `phases-apple/phase-2/README.md` (created when phase 2 begins).
