#!/usr/bin/env bash
# Before/after measurement: mma ratio probe + llama-bench. Run once locked, once unlocked,
# with nothing else using the GPU. Writes into OUT.
# usage: LLAMA_BENCH=/path/to/llama-bench MODEL=/path/to/model.gguf ./run-bench.sh <tag>
set -euo pipefail
TAG=${1:?tag e.g. locked|unlocked}
OUT=${OUT:-./results-$TAG}
LLAMA_BENCH=${LLAMA_BENCH:?set LLAMA_BENCH}
MODEL=${MODEL:?set MODEL (we used Qwen3-8B Q4_K_M)}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
nvidia-smi --query-gpu=name,memory.used,power.limit,power.draw,clocks.sm --format=csv | tee "$OUT/nvidia-smi.txt"
python3 "$HERE/mma_rate.py" | tee "$OUT/mma_rate.json"
"$LLAMA_BENCH" -m "$MODEL" -ngl 99 -fa 1 -p 512,4096,16384 -n 128 -r 5 2>&1 | tee "$OUT/llama-bench.txt"
