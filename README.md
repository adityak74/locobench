# Local Coding Model Benchmarking with Harbor, Terminus-2, and Ollama

This repository contains the setup, requirements, and instructions for running local agentic benchmarks using the **Harbor** harness, the **Terminus-2** agent, and local models served via **Ollama**.

---

## Architecture Overview

```mermaid
graph TD
    subgraph Host Mac
        Ollama[Ollama Server]
        Harbor[Harbor CLI]
        Terminus[Terminus-2 Agent Process]
    end
    subgraph Docker Containers
        TaskEnv[Task Environment Container]
    end

    Harbor -->|Spins up| TaskEnv
    Harbor -->|Runs| Terminus
    Terminus -->|Coordinates shell commands| TaskEnv
    Terminus -->|Calls LLM API| Ollama
```

---

## Prerequisites

1. **Docker / OrbStack**: Ensure Docker is running.
2. **uv**: Install via `brew install uv`.
3. **Harbor**: Install via `uv tool install harbor`.
4. **Ollama Desktop**: Install and ensure the server is serving the API at `http://127.0.0.1:11434`.

---

## Setup & Optimization Guide

When running large local models (like `qwen3.6:35b-mlx`), the default context window (e.g. 262K tokens) requires a massive KV cache that can easily exceed the unified memory/VRAM of your Mac. This forces the system to swap virtual memory heavily, causing extreme latency (frequent timeouts).

Follow these steps to optimize the setup:

### 1. Limit the Model Context Size (Ollama Modelfile)
Limit the context size to `64K` (or `32K`) to keep the KV cache within GPU memory.

Create a file named `Modelfile`:
```dockerfile
FROM qwen3.6:35b-mlx
PARAMETER num_ctx 65536
```

Then build the optimized model:
```bash
ollama create qwen3.6:35b-mlx-64k -f Modelfile
```

Verify it is registered:
```bash
ollama list
```

### 2. Guard Against Model Thrashing
Ollama unloads the active model if another request arrives for a different model. Make sure other background processes (like IDE test suites running `gemma4` or other local models) are paused or finished before starting the benchmark.

---

## Running Benchmarks

### 1. Hello-World Smoke Test
Run a quick, single-task test to verify the communication chain:
```bash
MODEL='qwen3.6:35b-mlx-64k'

harbor run \
  -d harbor/hello-world \
  -a terminus-2 \
  -m "ollama_chat/$MODEL" \
  --ak api_base=http://127.0.0.1:11434 \
  --ak temperature=0 \
  --ak max_turns=50 \
  --ak 'model_info={"max_input_tokens":65536,"max_output_tokens":8192,"input_cost_per_token":0,"output_cost_per_token":0}' \
  -n 1
```

### 2. Three-Task Terminal-Bench Test
Run a 3-task smoke test. Because complex tasks generate deep reasoning chains, we increase:
- Harbor's agent timeout multiplier: `--agent-timeout-multiplier 3` (increases trial timeout to 45 minutes)
- LiteLLM's HTTP request timeout: `--ak 'llm_call_kwargs={"timeout":1800}'` (increases request timeout to 30 minutes)

```bash
MODEL='qwen3.6:35b-mlx-64k'

harbor run \
  --job-name "qwen36-35b-mlx-64k-tb21-smoke-timeout" \
  -d terminal-bench/terminal-bench-2-1 \
  -a terminus-2 \
  -m "ollama_chat/$MODEL" \
  --agent-timeout-multiplier 3 \
  --ak api_base=http://127.0.0.1:11434 \
  --ak temperature=0 \
  --ak max_turns=100 \
  --ak 'model_info={"max_input_tokens":65536,"max_output_tokens":8192,"input_cost_per_token":0,"output_cost_per_token":0}' \
  --ak 'llm_call_kwargs={"timeout":1800}' \
  -l 3 \
  -k 1 \
  -n 1
```

### 3. Full Benchmark
To run the full 89-task benchmark, remove the `-l 3` limit:
```bash
MODEL='qwen3.6:35b-mlx-64k'

harbor run \
  --job-name "qwen36-35b-mlx-64k-tb21-full" \
  -d terminal-bench/terminal-bench-2-1 \
  -a terminus-2 \
  -m "ollama_chat/$MODEL" \
  --agent-timeout-multiplier 3 \
  --ak api_base=http://127.0.0.1:11434 \
  --ak temperature=0 \
  --ak max_turns=100 \
  --ak 'model_info={"max_input_tokens":65536,"max_output_tokens":8192,"input_cost_per_token":0,"output_cost_per_token":0}' \
  --ak 'llm_call_kwargs={"timeout":1800}' \
  -k 1 \
  -n 1
```

---

## Daily Automated Leaderboard Pipeline

For everyday testing of new model releases from Ollama, running the full 89-task benchmark (which can take 15+ hours) is often not feasible. 

Instead, use `run_daily.sh` which executes a **curated subset of 8 representative tasks** (covering Unix skills, log parsing, data processing, async coding, compilers, and distributed systems parallelization). The script automatically parses the results, updates a local `leaderboard.json`, and commits/pushes the updates to GitHub.

### How to Run the Daily Pipeline
Run the script on your Mac Mini server, passing the base Ollama model name:
```bash
./run_daily.sh qwen3.6:35b-mlx
```
This will automatically:
1. Check if the optimized `qwen3.6:35b-mlx-64k` model exists, and create it via `Modelfile` if missing.
2. Run Harbor on the 8 selected tasks with custom high timeouts.
3. Call `update_leaderboard.py` to parse `result.json`.
4. Update `leaderboard.json` in the root of the repository.
5. Push the updated `leaderboard.json` to GitHub.

### Integrating with Your Website
The pipeline outputs a flat JSON array sorted by score in `leaderboard.json` which has the following schema:
```json
[
    {
        "model": "qwen3.6:35b-mlx-64k",
        "date": "2026-07-09",
        "mean_reward": 0.875,
        "duration_minutes": 115.4,
        "input_tokens": 184510,
        "output_tokens": 42091,
        "cache_tokens": 0
    }
]
```
You can read this JSON file directly in your frontend code (e.g. using `fetch('/path/to/leaderboard.json')`) to display a dynamically updated leaderboard table on your website.

---

## Analyzing Results

Launch Harbor's local UI viewer to inspect task trajectories, terminal inputs/outputs, rewards, and token logs:
```bash
harbor view jobs
```
This opens the job comparison dashboard in your web browser.

