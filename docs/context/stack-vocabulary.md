# Stack vocabulary

Shared terminology for the layered shape of a local-LLM or self-hosted-LLM setup. Both SOV tracks ([`phases-cloud/`](../../phases-cloud/) and [`phases-apple/`](../../phases-apple/)) reference these names; the layers exist everywhere even when a single app appears to handle "the whole thing." Knowing which layer is doing what is how you reason about leaks (tokenizer drift, runtime-speed variance, harness-vs-runtime confusion).

Near-mirrors live in the [companion blog notebook](https://danmackinlay.name/notebook/local_llm_mac.html#the-stack) (apple-flavoured examples) and the [member-side-stack section](https://danmackinlay.name/notebook/aus_sovereign_llm.html#the-member-side-stack) of the cooperative post (cloud-flavoured examples). This page is the in-repo canonical version, vendor- and platform-agnostic.

## The six layers

| Layer | What it is | Examples |
|---|---|---|
| **Model** | The weights themselves, distributed from Hugging Face (or equivalent) as `.safetensors`. The model is identity-of-thing; everything below is *how it runs*. | Qwen3.5-122B-A10B, DeepSeek V4-Flash, Llama 3.x, etc. |
| **Quant format** | How weights are stored on disk. Different runtimes consume different formats; "the same model in 4-bit" is not a single artefact. | GGUF (llama.cpp family), MLX safetensors (mlx-lm), AWQ / GPTQ (vLLM/SGLang), FP8 (vLLM on Hopper+), JANGTQ (Osaurus / jang-tools), `mxtq`, `mxfp4`, `nvfp4`, BNB. |
| **Runtime / inference engine** | The code that runs the matmuls — where the GPU work happens. Often the source of the largest performance variance between superficially-similar setups. | vLLM, SGLang, llama.cpp, MLX / `mlx-lm`, `vmlx-swift-lm` (Swift), `ds4` (single-model native Metal), Ollama's bundled engine, NVIDIA Dynamo. |
| **Server / daemon** | Long-lived process exposing an OpenAI- (or Anthropic-, or Ollama-) compatible HTTP endpoint. The contract between everything above and everything below. | `vllm serve`, `sglang serve`, `mlx_lm.server`, Ollama, `llama-server`, Osaurus, `ds4-server`, LiteLLM (a router; not a runtime, but is a server). |
| **Harness / agent loop** | Orchestration over the server endpoint — conversation state, tool-call loops, system prompts, multi-turn agent loops, slash commands, model switching. The harness layer is where most of the cross-platform / cross-track muscle memory actually lives. | Aider, [`pi`](https://github.com/earendil-works/pi), OpenCode, Continue, Cursor, Claude Code (vendor-locked), Osaurus's built-in loop. |
| **Frontend / chat client** | The human-facing surface. Pure-presentation, or presentation + thin harness. | Jan, LibreChat, Open WebUI, Osaurus's chat window, LM Studio, web UIs, harness TUIs (pi's, Aider's). |

## Vertical bundles vs unbundled stacks

Most apps you've heard of are **vertical bundles** of two or more of these layers:

- **Ollama** = server + runtime + a thin frontend
- **Jan** = frontend + (optionally) harness + (optionally) server + runtime via its Cortex/MLX bundles
- **LM Studio** = frontend + harness + server + runtime
- **Osaurus** = frontend + harness + server + runtime + MCP server/client + agent VM
- **vLLM / SGLang** (as a server) = server + runtime
- **Claude Code / Cursor / Continue** = harness + frontend, with the server/runtime/model hosted by a vendor

The SOV-style choice (both tracks) is the **unbundled** version: small interchangeable parts, each layer swappable, the contract between them being an OpenAI-compatible HTTP endpoint. The cost is two-or-three-things-to-start instead of one; the benefit is that no single layer change forces you to re-learn anything above or below it.

When an abstraction leaks, it usually leaks at a specific layer:

- Throughput variance "between MLX runtimes" → almost always an **engine** or **engine-version** difference (see the apple-track [runtime-speed framework](../../phases-apple/README.md#why-runtime-choice-changes-mlx-speed)).
- "Why is my Ollama tokenizer disagreeing with HF's?" → **quant format** + **runtime**, both re-implementing tokenization independently.
- "Why won't this Anthropic-only harness work against vLLM?" → the **harness** layer is talking the wrong dialect to the **server**.

## The harness layer is the Schelling point

The harness layer is structurally where the SOV apple-track and cloud-track converge. A harness manages conversation state and connects to whichever OpenAI-compatible endpoint you point it at — that endpoint can be a local `mlx_lm.server`, a LiteLLM proxy in front of it, the SOV cloud audition's vLLM-on-RunPod, the eventual cooperative DGX, or Anthropic / OpenAI cloud APIs.

**Picking a harness that's provider-agnostic and not bundled with a specific GUI is the change that collapses the apple-personal and cloud-cooperative experiences into the same workflow.** Same binary, same config file format, same keybindings, same `/model` swap behaviour — different backend per session, transparent to the user.

The cooperative-side argument is identical to the apple-side argument: the [member-side-stack section](https://danmackinlay.name/notebook/aus_sovereign_llm.html#the-member-side-stack) of the blog post is explicit that members each pick their own harness and frontend, while the collective owns the server. A provider-agnostic harness is what makes that posture work without per-member-per-backend ceremony.

`pi` ([earendil-works/pi](https://github.com/earendil-works/pi)) is the current SOV candidate for that role. See the apple-track [`pi`-as-cross-track-harness](../../phases-apple/README.md#pi-as-the-cross-track-harness) discussion for the deeper argument; the cloud-track equivalent will land in [phase-2 workstream B](../../PLAN.md#workstream-b-agentic-proof-of-concept) once we've trialled it in anger.

## Track-specific specialisations

The vocabulary above is platform-neutral. Each track has its own table of *defaults* and *alternatives* per layer:

- **Apple track:** [`phases-apple/README.md#apple-track-specialisation`](../../phases-apple/README.md#apple-track-specialisation) — MLX-via-`mlx-lm` runtime, `mlx_lm.server` daemon, Aider + `pi` harnesses, Jan frontend. Apple-specific alternatives include Osaurus (Swift-native vertical bundle), `ds4` (single-model native Metal engine), JANGTQ mixed-precision quants.
- **Cloud track:** added when [`phases-cloud/`](../../phases-cloud/) ships — vLLM / SGLang runtime, AWQ / FP8 quant formats, the audition's vLLM-as-server, LibreChat as the hosted frontend, and the same harness layer (Aider, `pi`, possibly Claude Code via API).

The harness layer is intentionally the same across both tracks. The runtime, server, quant format, and frontend differ; the harness is what the human's hands actually touch.
