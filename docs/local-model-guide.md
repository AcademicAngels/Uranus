# Local LLM Model Guide

A complete guide for OPC developers on using local LLM models with HiClaw.

## How HiClaw Routes LLM Calls

All LLM calls go through Higress AI Gateway. To use a local model, point `HICLAW_OPENAI_BASE_URL` at your local model server. HiClaw agents don't know or care whether the model is cloud or local — they just call the gateway.

```
HiClaw Agent → Higress AI Gateway → local model server (Ollama / LM Studio / vLLM)
```

## Why Use Local Models

- Agents consume 10–50x more tokens than regular chat
- Local models eliminate per-token API costs
- Complete data privacy — nothing leaves your machine
- No rate limits or quotas

## Ollama Setup

```bash
# Install
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model
ollama pull qwen3:27b

# Start server (default port 11434)
ollama serve
```

Configure HiClaw:

```bash
export HICLAW_OPENAI_BASE_URL=http://localhost:11434/v1
export HICLAW_DEFAULT_MODEL=qwen3:27b
```

Important Ollama settings:

- `OLLAMA_KEEP_ALIVE=24h` — default 5 min unload is too short for agents
- `OLLAMA_NUM_CTX=32768` — default 2048 tokens is insufficient for agents

## LM Studio Setup

1. Download from https://lmstudio.ai/
2. Load a model in the GUI
3. Start local server (Settings → Local Server, default port 1234)

Configure HiClaw:

```bash
export HICLAW_OPENAI_BASE_URL=http://localhost:1234/v1
export HICLAW_DEFAULT_MODEL=<model-name-from-lm-studio>
```

Windows native — no WSL needed.

## vLLM Setup (Production / GPU)

```bash
pip install vllm
vllm serve Qwen/Qwen3-27B --port 8000
```

Configure HiClaw:

```bash
export HICLAW_OPENAI_BASE_URL=http://localhost:8000/v1
export HICLAW_DEFAULT_MODEL=Qwen/Qwen3-27B
```

Best for: high-throughput, multi-user, production environments. Requires NVIDIA GPU with 24+ GB VRAM.

## Recommended Models

| Model | Params | Best For | VRAM | License |
|---|---|---|---|---|
| Qwen3-27B | 27B | General coding & reasoning | ~22 GB | Apache 2.0 |
| Qwen3-8B | 8B | Lightweight tasks, fast response | ~8 GB | Apache 2.0 |
| Devstral-24B | 24B | Agent coding tasks | ~20 GB | Apache 2.0 |
| bge-m3 | — | Embedding (memory search) | ~1-2 GB | MIT |

Hardware sweet spot: RTX 4090 (24 GB VRAM), 8B models at 50–80 tok/s.

## Embedding Model (Separate)

The embedding model for memory search is configured separately:

```bash
export HICLAW_EMBEDDING_MODEL=bge-m3
```

This controls the ReMe memory search, not the main LLM.

## Windows / WSL Considerations

- **Ollama**: native Windows installer available at https://ollama.com/download/windows
- **LM Studio**: native Windows app
- **vLLM**: requires WSL2 with CUDA

## Docker Deployment

Set env vars before running the installer or add to `hiclaw-manager.env`:

```bash
HICLAW_OPENAI_BASE_URL=http://host.docker.internal:11434/v1
HICLAW_DEFAULT_MODEL=qwen3:27b
```

Use `host.docker.internal` to reach host-side Ollama from inside containers.

## K8s / Helm Deployment

```yaml
controller:
  env:
    HICLAW_OPENAI_BASE_URL: "http://ollama-service:11434/v1"
    HICLAW_DEFAULT_MODEL: "qwen3:27b"
```
