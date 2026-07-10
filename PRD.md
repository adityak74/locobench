# PRD: Harbor + Terminus-2 + Ollama Setup

The cleanest setup is Harbor + Terminus-2 + Ollama.
Terminal-Bench measures an agent–model combination, not just the model. To compare local models fairly, keep the agent fixed as terminus-2 and change only the Ollama model. Harbor is now the official Terminal-Bench harness. (Harbor)

## 1. Install Harbor
Make sure Docker Desktop is installed and running.
```bash
brew install uv
uv tool install harbor

harbor --version
docker info
```
Harbor supports local Docker execution and installs through `uv tool install harbor`. (GitHub)
To upgrade later:
```bash
uv tool upgrade harbor
```

## 2. Verify Ollama
Since you already have `qwen3.6:35b-mlx` (or any other model):
```bash
ollama list
ollama ps
curl -s http://127.0.0.1:11434/api/tags | head
```
Open Ollama Desktop first. Only run `ollama serve` when the desktop app is not already serving the API.

## 3. Smoke-test the local model
Start with Harbor’s one-task hello-world dataset:
```bash
MODEL='qwen3.6:35b-mlx'

harbor run \
  -d harbor/hello-world \
  -a terminus-2 \
  -m "ollama_chat/$MODEL" \
  --ak api_base=http://127.0.0.1:11434 \
  --ak temperature=0 \
  --ak max_turns=50 \
  --ak 'model_info={"max_input_tokens":262144,"max_output_tokens":8192,"input_cost_per_token":0,"output_cost_per_token":0}' \
  -n 1
```
The `ollama_chat/` prefix tells LiteLLM to use its Ollama chat provider, which LiteLLM recommends over the basic Ollama completion interface. Terminus-2 directly supports custom `api_base` and `model_info` settings. (LiteLLM)
Use `127.0.0.1`, not `host.docker.internal`: Terminus-2’s model-calling process runs outside the task container on your Mac. (Harbor)

## 4. Run a three-task Terminal-Bench test
I would use Terminal-Bench 2.1 for your local benchmark because it fixes or improves 26 tasks from 2.0. Use 2.0 only when you specifically need direct comparison with older 2.0 leaderboard results. Both currently contain 89 tasks. (Harbor Hub)
```bash
harbor run \
  --job-name "qwen36-35b-mlx-tb21-smoke" \
  -d terminal-bench/terminal-bench-2-1 \
  -a terminus-2 \
  -m "ollama_chat/$MODEL" \
  --ak api_base=http://127.0.0.1:11434 \
  --ak temperature=0 \
  --ak max_turns=100 \
  --ak 'model_info={"max_input_tokens":262144,"max_output_tokens":8192,"input_cost_per_token":0,"output_cost_per_token":0}' \
  -l 3 \
  -k 1 \
  -n 1
```
Here:
* `-l 3` runs only three tasks.
* `-k 1` performs one attempt per task.
* `-n 1` runs one trial at a time, appropriate for one local Ollama instance.
* `--ak` passes typed agent arguments; Harbor parses JSON dictionaries such as `model_info`. (raw.githubusercontent.com)

## 5. Run the complete benchmark
Remove `-l 3`:
```bash
harbor run \
  --job-name "qwen36-35b-mlx-tb21-full" \
  -d terminal-bench/terminal-bench-2-1 \
  -a terminus-2 \
  -m "ollama_chat/$MODEL" \
  --ak api_base=http://127.0.0.1:11434 \
  --ak temperature=0 \
  --ak max_turns=100 \
  --ak 'model_info={"max_input_tokens":262144,"max_output_tokens":8192,"input_cost_per_token":0,"output_cost_per_token":0}' \
  -k 1 \
  -n 1
```
For Terminal-Bench 2.0 instead: `-d terminal-bench/terminal-bench-2`

## 6. View results and trajectories
```bash
harbor view jobs
```
This opens Harbor’s local viewer, where you can compare jobs, inspect task rewards, view terminal trajectories, examine token usage and diagnose failures. (Harbor)

## Recommended benchmark protocol
For your local coding-model benchmark:
1. Use the same Terminus-2 configuration for every model.
2. Keep temperature at 0.
3. Run the same Terminal-Bench version.
4. Keep Ollama context size and output-token limit consistent.
5. Start with `-k 1`; use `-k 3` for models you want to evaluate more rigorously.
6. Record pass rate, tokens, wall-clock duration and memory usage.
7. Keep `-n 1` unless your Ollama server can handle parallel requests.

One practical concern with your `qwen3.6:35b-mlx`: the model and its 262K KV cache can consume substantial unified memory while Docker tasks need their own memory. If macOS begins swapping, reduce Ollama context for the benchmark—such as 64K or 128K—rather than allowing memory pressure to distort latency results.
