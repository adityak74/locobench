#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <ollama_model_name>"
    echo "Example: $0 qwen3.6:35b-mlx"
    exit 1
fi

BASE_MODEL=$1
API_BASE="http://127.0.0.1:11434"

# 1. Prepare optimized model name
MODEL_SUFFIX="-64k"
if [[ "$BASE_MODEL" == *"$MODEL_SUFFIX" ]]; then
    OPTIMIZED_MODEL="$BASE_MODEL"
else
    OPTIMIZED_MODEL="${BASE_MODEL}${MODEL_SUFFIX}"
fi

# 2. Verify Ollama is running
if ! curl -s --fail "$API_BASE/api/tags" &> /dev/null; then
    echo "Error: Ollama server is unreachable at $API_BASE."
    exit 1
fi

# 3. Create the optimized model if it doesn't exist
if ! ollama list | grep -q "$OPTIMIZED_MODEL"; then
    echo "Creating optimized model '$OPTIMIZED_MODEL' with 64K context..."
    # Generate temporary Modelfile
    echo "FROM $BASE_MODEL" > TempModelfile
    echo "PARAMETER num_ctx 65536" >> TempModelfile
    ollama create "$OPTIMIZED_MODEL" -f TempModelfile
    rm TempModelfile
else
    echo "Optimized model '$OPTIMIZED_MODEL' already exists."
fi

# 4. Run the curated 8-task daily benchmark suite
JOB_NAME="daily-${OPTIMIZED_MODEL//:/_}-$(date +%Y%m%d)"
echo "Running daily benchmark suite as job: $JOB_NAME..."

# Selected representative tasks:
# - hello-world: Sanity check (simple)
# - openssl-selfsigned-cert: UNIX utility skills (simple/medium)
# - nginx-request-logging: Log parsing and server config (medium)
# - mteb-leaderboard: Data processing / pandas script (medium)
# - cancel-async-tasks: Async python concurrency (medium/hard)
# - write-compressor: Advanced C compression logic (hard)
# - schemelike-metacircular-eval: Metacircular compiler evaluation (hard)
# - torch-tensor-parallelism: Distributed AI systems optimization (hard)

harbor run \
  --job-name "$JOB_NAME" \
  -d terminal-bench/terminal-bench-2-1 \
  -a terminus-2 \
  -m "ollama_chat/$OPTIMIZED_MODEL" \
  --agent-timeout-multiplier 3 \
  --ak api_base="$API_BASE" \
  --ak temperature=0 \
  --ak max_turns=100 \
  --ak 'model_info={"max_input_tokens":65536,"max_output_tokens":8192,"input_cost_per_token":0,"output_cost_per_token":0}' \
  --ak 'llm_call_kwargs={"timeout":1800}' \
  -i "openssl-selfsigned-cert" \
  -i "nginx-request-logging" \
  -i "mteb-leaderboard" \
  -i "cancel-async-tasks" \
  -i "write-compressor" \
  -i "schemelike-metacircular-eval" \
  -i "torch-tensor-parallelism" \
  -k 1 \
  -n 1

# 5. Extract results and update leaderboard JSON
RESULT_FILE="./jobs/$JOB_NAME/result.json"
if [[ -f "$RESULT_FILE" ]]; then
    echo "Job finished. Parsing results..."
    python3 update_leaderboard.py "$RESULT_FILE"
    
    # 6. Auto-commit and push updates to website repository
    if command -v git &> /dev/null && git rev-parse --is-inside-work-tree &> /dev/null; then
        echo "Staging and pushing leaderboard updates..."
        git add leaderboard.json
        git commit -m "Auto-update leaderboard: $OPTIMIZED_MODEL ($(date +%Y-%m-%d))" || echo "No changes to commit."
        git push origin main || echo "Warning: Failed to push to remote repository."
    fi
else
    echo "Error: Result file not found at $RESULT_FILE."
    exit 1
fi

echo "Daily run for $OPTIMIZED_MODEL complete!"
