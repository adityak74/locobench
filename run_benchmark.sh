#!/usr/bin/env bash

set -euo pipefail

MODEL="qwen3.6:35b-mlx-64k"
API_BASE="http://127.0.0.1:11434"

show_usage() {
    echo "Usage: $0 [smoke|full]"
    echo "  smoke  - Run a 3-task smoke test using Terminal-Bench 2.1"
    echo "  full   - Run the complete 89-task Terminal-Bench 2.1 benchmark"
    exit 1
}

if [[ $# -ne 1 ]]; then
    show_usage
fi

MODE=$1

# Verify Harbor is installed
if ! command -v harbor &> /dev/null; then
    echo "Error: 'harbor' CLI is not installed. Run 'uv tool install harbor' to install it."
    exit 1
fi

# Verify Ollama is serving the model
echo "Checking Ollama server at $API_BASE..."
if ! curl -s --fail "$API_BASE/api/tags" &> /dev/null; then
    echo "Error: Ollama server is not running or unreachable at $API_BASE."
    echo "Please open Ollama Desktop or run 'ollama serve' first."
    exit 1
fi

case "$MODE" in
    smoke)
        echo "Launching 3-task smoke test benchmark..."
        harbor run \
          --job-name "qwen36-35b-mlx-64k-tb21-smoke-timeout" \
          -d terminal-bench/terminal-bench-2-1 \
          -a terminus-2 \
          -m "ollama_chat/$MODEL" \
          --agent-timeout-multiplier 3 \
          --ak api_base="$API_BASE" \
          --ak temperature=0 \
          --ak max_turns=100 \
          --ak 'model_info={"max_input_tokens":65536,"max_output_tokens":8192,"input_cost_per_token":0,"output_cost_per_token":0}' \
          --ak 'llm_call_kwargs={"timeout":1800}' \
          -l 3 \
          -k 1 \
          -n 1
        ;;
    full)
        echo "Launching full Terminal-Bench 2.1 benchmark..."
        harbor run \
          --job-name "qwen36-35b-mlx-64k-tb21-full" \
          -d terminal-bench/terminal-bench-2-1 \
          -a terminus-2 \
          -m "ollama_chat/$MODEL" \
          --agent-timeout-multiplier 3 \
          --ak api_base="$API_BASE" \
          --ak temperature=0 \
          --ak max_turns=100 \
          --ak 'model_info={"max_input_tokens":65536,"max_output_tokens":8192,"input_cost_per_token":0,"output_cost_per_token":0}' \
          --ak 'llm_call_kwargs={"timeout":1800}' \
          -k 1 \
          -n 1
        ;;
    *)
        show_usage
        ;;
esac
