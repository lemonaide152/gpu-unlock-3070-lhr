# RTX 3070 tech tree

Version 1.1.0 (public copy). Updated 2026-10-25.

This tree shows how to get the most real work from one RTX 3070 with 8 GB of VRAM. LHR cards are included. The work is local LLM inference and coding agents. Each node is one experiment. A node runs only when all of its prereqs are measured. The machine-readable form is [tech-tree.json](tech-tree.json).

All numbers in this file come from one test machine. All runs are warm, not cold boot. The sample sizes are small. Each measured value names its source file. A value marked "Target" is a goal. It is not a result.

## Status counts

| status | nodes |
|---|---:|
| measured | 8 |
| in progress | 0 |
| paused | 1 |
| queued | 18 |
| needs owner | 2 |
| blocked | 0 |
| total | 29 |

Status values: `measured` means done. `in_progress` means the lab runs it now. `paused` means the lab started it and stopped. Its dependents wait, and it restarts from scratch. `queued` means ready, or ready when its prereqs are measured. `needs_owner` (shown as "needs owner") means the owner must be present or must approve. `blocked` means a prereq is not available.

## Graph

```mermaid
flowchart LR
  subgraph foundation["Foundation"]
    stack_baseline["Driver, CUDA and WSL2 baseline<br/>measured"]
    harness["Measurement harness<br/>measured"]
    unlock_fp32acc["FP32-accumulate unlock<br/>measured"]
    ram_wsl_check["System RAM and WSL2 memory limit<br/>measured"]
    cold_boot["Cold-boot arms<br/>needs owner"]
    locked_ab["Clean locked vs unlocked A/B<br/>needs owner"]
  end
  subgraph inference["Inference"]
    kv_cache_types["KV cache types<br/>measured"]
    flash_attention["Flash attention<br/>measured"]
    full_offload["Full GPU offload<br/>paused"]
    quant_choice["Weight quant choice<br/>queued"]
    spec_ngram["Speculative decoding: n-gram<br/>queued"]
    spec_draft["Speculative decoding: draft model<br/>queued"]
    dense_newer["Newer small dense model at full offload<br/>queued"]
    moe_offload["MoE expert offload (Qwen3.6-35B-A3B)<br/>queued"]
    fp16_workloads["Workloads that use the unlocked math<br/>queued"]
  end
  subgraph agent["Agent reliability"]
    failure_sort["Failure sort<br/>measured"]
    test_gate["Test-gated done<br/>queued"]
    tool_call_format["Tool-call format<br/>queued"]
    sampler["Sampler settings<br/>queued"]
    thinking_budget["Thinking budget<br/>queued"]
    loop_guard["Loop guard<br/>queued"]
    agent_stack["Stacked agent fixes on a held-out set<br/>queued"]
  end
  subgraph throughput["Throughput"]
    parallel_slots["Parallel slots<br/>queued"]
    agent_workers["Concurrent agent workers<br/>queued"]
    best_of_n["Best-of-N with a visible-test selector<br/>queued"]
  end
  subgraph efficiency["Efficiency"]
    power_log["Board power logging<br/>measured"]
    wh_per_pass["Wh per passing task<br/>queued"]
  end
  subgraph capstone["Capstones"]
    bigger_class["Bigger model class on 8 GB<br/>queued"]
    useful_work_per_wh["Self-funding throughput: useful work per Wh<br/>queued"]
  end
  stack_baseline --> harness
  stack_baseline --> unlock_fp32acc
  harness --> unlock_fp32acc
  stack_baseline --> ram_wsl_check
  harness --> cold_boot
  unlock_fp32acc --> cold_boot
  harness --> locked_ab
  unlock_fp32acc --> locked_ab
  harness --> kv_cache_types
  harness --> flash_attention
  stack_baseline --> full_offload
  harness --> full_offload
  kv_cache_types --> full_offload
  flash_attention --> full_offload
  full_offload --> quant_choice
  full_offload --> spec_ngram
  spec_ngram --> spec_draft
  full_offload --> dense_newer
  ram_wsl_check --> moe_offload
  kv_cache_types --> moe_offload
  full_offload --> moe_offload
  unlock_fp32acc --> fp16_workloads
  harness --> failure_sort
  failure_sort --> test_gate
  full_offload --> test_gate
  failure_sort --> tool_call_format
  full_offload --> tool_call_format
  failure_sort --> sampler
  full_offload --> sampler
  failure_sort --> thinking_budget
  full_offload --> thinking_budget
  failure_sort --> loop_guard
  full_offload --> loop_guard
  test_gate --> agent_stack
  tool_call_format --> agent_stack
  sampler --> agent_stack
  thinking_budget --> agent_stack
  loop_guard --> agent_stack
  full_offload --> parallel_slots
  parallel_slots --> agent_workers
  parallel_slots --> best_of_n
  test_gate --> best_of_n
  harness --> power_log
  power_log --> wh_per_pass
  full_offload --> wh_per_pass
  moe_offload --> bigger_class
  agent_stack --> bigger_class
  wh_per_pass --> useful_work_per_wh
  best_of_n --> useful_work_per_wh
  agent_stack --> useful_work_per_wh
  classDef measured fill:#0a0a0a,color:#f2f2f2,stroke:#0a0a0a
  classDef live fill:#f6e9dc,color:#9a4a06,stroke:#9a4a06
  classDef queued fill:#f2f2f2,color:#0a0a0a,stroke:#6b6b6b,stroke-dasharray:3 3
  class stack_baseline,harness,unlock_fp32acc,ram_wsl_check,kv_cache_types,flash_attention,failure_sort,power_log measured
  class cold_boot,locked_ab,full_offload live
  class quant_choice,spec_ngram,spec_draft,dense_newer,moe_offload,fp16_workloads,test_gate,tool_call_format,sampler,thinking_budget,loop_guard,agent_stack,parallel_slots,agent_workers,best_of_n,wh_per_pass,bigger_class,useful_work_per_wh queued
```

## Next order

The lab runs these nodes in this order. Dependency order comes first. Expected value comes second.

| rank | node | reason |
|---:|---|---|
| 1 | `full-offload` | Paused after 14 of 36 runs. It restarts from scratch at lab resume and gates 17 nodes. Agent decode is 18.22 tok/s at partial offload. llama-bench tg128 at full offload is 73.80 tok/s. |
| 2 | `test-gate` | gofmt, build and vet cause 25 of 55 failures. A gate before 'done' targets them directly. |
| 3 | `tool-call-format` | 311 of 661 tool calls failed. This is the next largest fixable cause. |
| 4 | `loop-guard` | 39 of 60 runs had a loop event, and none of them passed. |
| 5 | `sampler` | Vendor sampler for quantized Qwen3. One flag change. |
| 6 | `thinking-budget` | Targets 20 output-limit hits and 8 timeouts. |
| 7 | `moe-offload` | Needs more system memory than WSL2 gets by default. 11.9 GiB is available at the default cap, which is marginal. Runs after the loop fixes so the 35B model is tested with them. |
| 8 | `wh-per-pass` | Free with each bench once power logging starts before task 1. |
| 9 | `parallel-slots` | Mean board power was 56.43 W of a 220 W limit during the agent bench, so the card has spare capacity. |
| 10 | `agent-stack` | Confirms the agent fixes on a held-out set. |
| 11 | `bigger-class` | Capstone. Needs moe-offload and agent-stack measured. |
| 12 | `best-of-n` | Uses spare slots plus the test gate to lift the 0-pass roles. |
| 13 | `agent-workers` | More jobs per hour if the CPU keeps up. |
| 14 | `spec-ngram` | No VRAM cost. Helps code and JSON output. |
| 15 | `spec-draft` | Bigger speed-up, but it costs VRAM. |
| 16 | `dense-newer` | A newer small model may pass more tasks at full offload. |
| 17 | `quant-choice` | Small expected gain. Run after the agent fixes settle. |
| 18 | `fp16-workloads` | The only place the unlock pays. Unlocked-only numbers until locked-ab runs. |
| 19 | `useful-work-per-wh` | Capstone. Runs when its prereqs are measured. |

## Nodes

### Foundation

Know the stack, measure it the same way every time, and confirm the FP32-accumulate unlock.

| id | goal | test | metric | target | status | result |
|---|---|---|---|---|---|---|
| `stack-baseline` | Record the exact software and card state so that every other result can be replicated. | Read-only queries: nvidia-smi (name, driver, power limit, VRAM), llama.cpp build number, model file. Record them in every session. | Recorded fields present in each session meta file (yes/no). | Target: every session records driver, llama.cpp build, model, power limit and display GPU. | measured | driver: 621.01; power limit: 220 W, not changed; llama.cpp build: b11734, CUDA backend; model: Qwen3-8B Q4_K_M (4.68 GiB); runtime: llama.cpp in WSL2 |
| `harness` | Run the same benchmarks the same way, with n, variance and warm or cold state labeled on every number. | llama-bench with -r 5 and 3 reps for raw speed. A 12-task agent coding bench (6 roles x 2 tasks, hidden checks) at n=3 per task (36 runs). Board power sampled every 5 s. Summaries with 95% confidence intervals. | Pass rate with 95% CI, passes per hour, median output tok/s, board Wh per task, run-to-run spread. | Target: every result states n, warm or cold, and its confounds. | measured | agent bench baseline (unlocked): 3 of 36 passes, 8.3%, 95% CI 2.9-21.8%; agent bench passes per hour (unlocked, serial): 1.716; agent bench median output tok/s (unlocked): 18.22; agent bench baseline (locked): 2 of 24 passes, 8.3%, 95% CI 2.3-25.9% |
| `unlock-fp32acc` | Confirm that FP16 tensor-core math with FP32 accumulate runs at the full rate. | MMA microbenchmark: FP16 inputs with FP32 accumulate vs FP16 accumulate. Then a GEMM diagnostic at model-shaped sizes. | mma ratio = FP32-acc rate / FP16-acc rate. Locked GeForce Ampere is near 0.5. Unlocked is near 1.0. | Target: ratio 1.0 in every unlocked session. | measured | mma ratio, locked: 0.507; mma ratio, unlocked: 1.0; mma ratio, unlocked replication: 1.0; GEMM FP32acc/FP16acc, sq4096 (unlocked, median of 3): 1.014; GEMM FP32acc/FP16acc, pp512_qkv (unlocked, median of 3): 0.942 |
| `ram-wsl-check` | Find how much system RAM the WSL2 VM can use, and the longest context the jobs need. | Read-only: free -g and nproc inside WSL2. Read the context percentiles from existing agent runs. | Total RAM, WSL2 memory limit, free RAM with the lab server loaded, p95 of per-run max context. | Target: values recorded. The MoE node needs this result. | measured | Windows physical RAM: 32 GiB; WSL2 memory limit: 15.5 GiB (default 50% cap, no memory= line in .wslconfig); WSL2 available RAM with the lab running: 11.9 GiB; WSL2 swap: 4.0 GiB, 0 used; WSL2 processors: 8 (.wslconfig processors=8); p95 of per-run max context: pending, from full-offload |
| `cold-boot` | Measure power-on to first token and power-on to first passing task, for unlocked and locked boots. | The owner cold-boots the machine and marks power-on and unlock-done times. The harness records boot, WSL up, server start, model ready, first token, warm, first pass. | Time to first token (s), time to first passing task (s), per arm. | Target: both arms measured with n of at least 3 boots each. | needs owner | — |
| `locked-ab` | Remove the display confound from the unlock comparison. | A locked cold boot with the display on the integrated GPU. Run the same llama-bench, GEMM, fa-off and agent bench as the unlocked arm. | Delta per metric, locked vs unlocked, same display state. | Target: every unlock claim has a same-display locked baseline. | needs owner | — |

### Inference

Get the most tokens per second from 8 GB of VRAM.

| id | goal | test | metric | target | status | result |
|---|---|---|---|---|---|---|
| `kv-cache-types` | Pick the KV cache type pair that is fast and fits. | Same 15,414-token prompt at 64K context, -ngl 30, 3 reps per K/V pair. Log the flash-attention fallback flag and peak VRAM. | Prefill tok/s, decode tok/s, peak VRAM MiB, fallback flag. | Target: no fallback, and the fastest decode that fits. | measured | q4_0/q4_0: prefill 1322-1350, decode 11.5-12.1 tok/s, 6393 MiB, no fallback; q8_0/q8_0: prefill 1277-1308, decode 9.6-10.2 tok/s, 7933 MiB, no fallback; q8_0/q4_1: prefill 1294-1311, decode 9.4-9.7 tok/s, 7473 MiB, fallback; q8_0/q4_0: prefill 1233-1330, decode 9.0-10.0 tok/s, 7355 MiB, fallback; f16/f16: prefill 92-95, decode 3.98-4.05 tok/s, 7935 MiB, no fallback |
| `flash-attention` | Confirm flash attention is on and measure what it gives at long prompts. | llama-bench -ngl 99, -fa 1 vs -fa 0, pp512/pp4096/pp16384. | Prefill tok/s per prompt length. | Target: flash attention on for every config. Re-check at each new build. | measured | pp16384, fa 1 (unlocked replication): 2492.6; pp16384, fa 0 (unlocked, 1 run x -r 5): 185.0; pp4096, fa 1 / fa 0: 2963.7 / 1976.4; pp512, fa 1 / fa 0: 2963.8 / 2726.3 |
| `full-offload` | Put every layer on the card at a context sized to real use. | llama-server -ngl 99 -fa on, context at p95 of real use (max 32k), KV q8_0/q8_0 (q4_0/q4_0 if it does not fit). Then the 36-run agent bench with board power logged from the first task. | Agent median output tok/s, passes per hour, pass rate, Wh per pass, out-of-memory count. | Target: agent decode at least 40 tok/s, passes per hour at least 1.5x baseline, pass rate not below 3 of 36, zero out-of-memory errors. | paused | partial run (not a result): 2 of 14 passes before the pause; config -ngl 99, ctx 8192, KV q8_0/q8_0, FA on. Restarts from scratch on resume.; llama-bench tg128 at -ngl 99 (unlocked replication, warm): 73.8; lab server load test at partial offload, gen tok/s, 3 reps (before this node): 20.63 / 21.43 / 21.81; agent bench median output tok/s at partial offload (before this node): 18.22; per-run max context, unlocked bench: p50 / p95 / max (tokens): 2811.5 / 4396 / 6248 |
| `quant-choice` | Find the weight quant with the best passes per hour that fits at full offload. | Same model at Q4_K_M, IQ4_XS and Q5_K_M (if it fits). llama-bench, then the 36-run agent bench at the full-offload settings. | Pass rate, passes per hour, decode tok/s, VRAM headroom. | Target: pick the quant with the most passes per hour. No out-of-memory errors. | queued | — |
| `spec-ngram` | Speed up decode on edit-heavy roles with no extra VRAM. | Turn on the n-gram lookup mode of your llama.cpp build (check llama-server --help). Run the token bench and the 36-run agent bench. | Agent decode tok/s, draft acceptance rate, pass rate, Wh per pass. | Target: agent decode at least 1.3x with the same pass rate. | queued | — |
| `spec-draft` | Speed up code and JSON output with a small draft model. | llama-server -md Qwen3-0.6B-Q8_0.gguf with a draft length of 8-12, if VRAM allows at full offload. | Agent decode tok/s, acceptance rate, VRAM, pass rate. | Target: agent decode at least 1.3x over n-gram mode or over no speculation. | queued | — |
| `dense-newer` | Test whether a newer small model (Qwen3.5-9B) passes more tasks at a similar speed. | Qwen3.5-9B Q4_K_M at -ngl 99. Check the chat and tool-call template. llama-bench pp512/pp4096/tg128, then the 36-run agent bench. | Pass rate, decode tok/s, prefill tok/s. | Target: at least 10 of 36 passes at 40 tok/s or more. | queued | — |
| `moe-offload` | Run a 35B-total, 3B-active MoE model with some experts in system RAM. | Qwen3.6-35B-A3B (UD-IQ4_XS GGUF). llama-bench at --n-cpu-moe 24, 27 and 30. Then the 36-run agent bench. | Decode and prefill tok/s, pass rate, RAM use, Wh per pass. | Target: at least 10 of 36 passes and agent decode at least 18 tok/s. | queued | — |
| `fp16-workloads` | Find end-to-end jobs that gain from FP32-accumulate FP16/BF16 math. | Unlocked arm: PyTorch fp16/bf16 matmul TFLOPS, an image-generation it/s run, and a BF16 vs F16 small-model llama-bench pp512/pp2048. | End-to-end speed per workload. Later: ratio vs the clean locked arm. | Target: at least 1.4x on one end-to-end FP16/BF16 workload vs the locked arm. | queued | — |

### Agent reliability

Make more agent tasks pass on the same model and card.

| id | goal | test | metric | target | status | result |
|---|---|---|---|---|---|---|
| `failure-sort` | Count why agent tasks fail, so that each fix targets a real cause. | Group all existing agent runs by failure cause, tool-call errors, loop events, output-limit hits and false 'done'. | Failures per cause, tool-call error share, runs with loops. | Target: a ranked cause list that sets the order of the agent fixes. | measured | runs / passes (locked 24 + unlocked 36): 60 / 5; failures by cause (55 failures): gofmt 17, review 10, timeout 8, rubric 6, build 6, tests 4, vet 2, missing_output 2; tool-call errors / tool calls: 311 / 661; runs with at least one loop event (non-empty loops field): 39 of 60 (locked 16 of 24, unlocked 23 of 36); 0 passes among them; runs with false_done = true: 8 of 60 (locked 5, unlocked 3); all 8 failed; output-limit hits (sum of length_hits): 20 hits in 18 runs (locked 9 in 7, unlocked 11 in 11); passes by role: planner (pm) 5 of 10; other five roles 0 of 50 |
| `test-gate` | Do not accept 'done' until format, vet, build and visible tests pass. | Before the agent can finish, run gofmt -l, go vet, go build and visible tests. On failure, return the output to the agent. 36-run agent bench. | Pass rate, gofmt/build/vet failure count, false 'done' count. | Target: gofmt, build and vet failures cut by half or more. Pass rate up. | queued | — |
| `tool-call-format` | Cut tool-call errors with constrained output. | Constrain tool calls with a JSON schema or grammar in llama-server. 36-run agent bench. | Tool-call error share, pass rate. | Target: tool-call errors cut by half. | queued | — |
| `sampler` | Use the model vendor's sampler for quantized models. | --temp 0.6 --top-p 0.95 --top-k 20 --presence-penalty 1.5 (Qwen3-8B GGUF model card). 36-run agent bench. | Pass rate, loop events, tool-call errors. | Target: loop events cut by half with no drop in pass rate. | queued | — |
| `thinking-budget` | Stop runaway thinking and output-limit hits. | Set a thinking budget per role (--reasoning-budget in llama-server, or no thinking for edit roles). 36-run agent bench. | Output-limit hits, timeouts, pass rate, wall time. | Target: zero output-limit hits. Timeouts cut by half. | queued | — |
| `loop-guard` | Stop the agent from repeating the same tool call. | After 3 identical tool calls, reset the turn with a short note to the agent. 36-run agent bench. | Loop events per run, pass rate, wall time. | Target: loop events cut by half. | queued | — |
| `agent-stack` | Combine the fixes that helped and check them on tasks that were not used to tune them. | Turn on all fixes that won. Run the 36-run bench and a held-out task set. | Pass rate on the tuned set and on the held-out set, reported apart. | Target: at least 10 of 36 passes (one-sided Fisher p about 0.03 vs 3 of 36). | queued | — |

### Throughput

Keep the card busy while agents wait on builds and tests.

| id | goal | test | metric | target | status | result |
|---|---|---|---|---|---|---|
| `parallel-slots` | Serve 2-4 requests at once to fill idle GPU time. | llama-server --parallel 1, 2, 4 with total context = slots x per-slot context. Token bench at each setting. | Aggregate tok/s, per-request tok/s, aggregate tok/s per board W. | Target: aggregate tok/s per board W at least 1.5x at 4 slots. | queued | — |
| `agent-workers` | Run 2 agent jobs side by side. | Agent bench with 2 workers against a 2-slot server. | Passes per hour, pass rate, CPU load. | Target: passes per hour at least 1.5x vs 1 worker. | queued | — |
| `best-of-n` | Turn spare capacity into more passes. | Best-of-3 on implementer and debugger roles. Pick the attempt whose build, vet and visible tests pass. Never use the hidden check. | Role pass rate, passes per hour, Wh per pass. | Target: implementer + debugger from 0 of 12 to at least 3 of 12. | queued | — |

### Efficiency

Measure energy per passing task. Do not tune power.

| id | goal | test | metric | target | status | result |
|---|---|---|---|---|---|---|
| `power-log` | Log board power for every task with full coverage. | nvidia-smi power.draw at 5 s, read-only, started before the first task. | Board Wh per task, coverage share of tasks with power data. | Target: 100% of tasks covered. | measured | board Wh per task, locked / unlocked: 2.99 / 2.53; board Wh per pass, locked: 35.88; board W mean during agent bench, locked: 56.43; board peak W under llama load (pause bench): 174.8 |
| `wh-per-pass` | Report energy per passing task for every config. | Every agent bench reports board Wh per pass and tok/s per W. Add wall-meter data if a plug meter is fitted. | Board Wh per pass (and wall Wh per pass when available). | Target: Wh per pass at least 30% lower than the locked baseline after full offload. | queued | — |

### Capstones

Combine the wins into a bigger model class and more useful work per Wh.

| id | goal | test | metric | target | status | result |
|---|---|---|---|---|---|---|
| `bigger-class` | Run a 35B-class model on 8 GB that beats the 8B baseline on passes per hour. | Best MoE settings plus the stacked agent fixes. 36-run bench and held-out set. | Pass rate, passes per hour, Wh per pass vs the 8B stack. | Target: more passes per hour than the best 8B stack. | queued | — |
| `useful-work-per-wh` | Find the config with the most passing tasks per Wh and per hour on one card. | Combine the best inference, agent and throughput settings. Run a long agent bench with full power logs. | Passing tasks per Wh, passing tasks per hour. | Target: passing tasks per Wh at least 2x the locked baseline. | queued | — |

## Measured results and sources

Every measured value names its source file. Paths are relative to the repo root.

### `stack-baseline`

- driver: **621.01**. Source: `results/agent-bench/unlocked/meta.json`
- power limit: **220 W, not changed**. Source: `results/agent-bench/unlocked/meta.json`
- llama.cpp build: **b11734, CUDA backend**. Source: `results/llama-bench.md`
- model: **Qwen3-8B Q4_K_M (4.68 GiB)**. Source: `results/llama-bench.md`
- runtime: **llama.cpp in WSL2**. Source: `results/pause-bench.md`
- Confounds: The desktop display moved from the RTX card to the integrated GPU between the locked and unlocked sessions. This frees VRAM and idles the card.

### `harness`

- agent bench baseline (unlocked): **3 of 36 passes, 8.3%, 95% CI 2.9-21.8%**. Source: `results/agent-bench/unlocked/summary.json`
- agent bench passes per hour (unlocked, serial): **1.716**. Source: `results/agent-bench/unlocked/summary.json`
- agent bench median output tok/s (unlocked): **18.22**. Source: `results/agent-bench/unlocked/summary.json`
- agent bench baseline (locked): **2 of 24 passes, 8.3%, 95% CI 2.3-25.9%**. Source: `results/agent-bench/locked/summary.json`
- Confounds: All runs so far are warm. The cold-start fields are null. The agent is not deterministic. n=3 per task is small. The locked arm has n=2 per task and the unlocked arm has n=3 per task.

### `unlock-fp32acc`

- mma ratio, locked: **0.507**. Source: `results/mma_rate-locked.json`
- mma ratio, unlocked: **1.0**. Source: `results/mma_rate-unlocked.json`
- mma ratio, unlocked replication: **1.0**. Source: `results/agent-bench/unlocked/mma.json`
- GEMM FP32acc/FP16acc, sq4096 (unlocked, median of 3): **1.014**. Source: `results/unlocked-replication.md`
- GEMM FP32acc/FP16acc, pp512_qkv (unlocked, median of 3): **0.942**. Source: `results/unlocked-replication.md`
- Confounds: No locked GEMM baseline exists. The mma test is a per-warp synthetic test, not dense GEMM.

### `ram-wsl-check`

- Windows physical RAM: **32 GiB**. Source: `results/ram-wsl-check.md`
- WSL2 memory limit: **15.5 GiB (default 50% cap, no memory= line in .wslconfig)**. Source: `results/ram-wsl-check.md`
- WSL2 available RAM with the lab running: **11.9 GiB**. Source: `results/ram-wsl-check.md`
- WSL2 swap: **4.0 GiB, 0 used**. Source: `results/ram-wsl-check.md`
- WSL2 processors: **8 (.wslconfig processors=8)**. Source: `results/ram-wsl-check.md`
- p95 of per-run max context: **pending, from full-offload**. Source: `results/ram-wsl-check.md`
- Confounds: Measured while the full-offload bench ran. Available RAM changes with load. WSL2 caps memory at 50% of Windows RAM by default (Microsoft WSL config docs).

### `kv-cache-types`

- q4_0/q4_0: **prefill 1322-1350, decode 11.5-12.1 tok/s, 6393 MiB, no fallback**. Source: `results/unlocked-replication.md`
- q8_0/q8_0: **prefill 1277-1308, decode 9.6-10.2 tok/s, 7933 MiB, no fallback**. Source: `results/unlocked-replication.md`
- q8_0/q4_1: **prefill 1294-1311, decode 9.4-9.7 tok/s, 7473 MiB, fallback**. Source: `results/unlocked-replication.md`
- q8_0/q4_0: **prefill 1233-1330, decode 9.0-10.0 tok/s, 7355 MiB, fallback**. Source: `results/unlocked-replication.md`
- f16/f16: **prefill 92-95, decode 3.98-4.05 tok/s, 7935 MiB, no fallback**. Source: `results/unlocked-replication.md`
- Confounds: Measured at partial offload (-ngl 30), not full offload. Mixed K/V types hit the flash-attention fallback. They decoded slowest of the quantized pairs. f16/f16 sits at the 8 GB limit. The collapse is probably memory spill. This is not verified.

### `flash-attention`

- pp16384, fa 1 (unlocked replication): **2492.6**. Source: `results/unlocked-replication.md`
- pp16384, fa 0 (unlocked, 1 run x -r 5): **185.0**. Source: `results/unlocked-replication.md`
- pp4096, fa 1 / fa 0: **2963.7 / 1976.4**. Source: `results/unlocked-replication.md`
- pp512, fa 1 / fa 0: **2963.8 / 2726.3**. Source: `results/unlocked-replication.md`
- Confounds: No locked fa 0 baseline. fa 0 is 1 run x -r 5. fa 1 is the mean of 3 reps x -r 5.

### `full-offload`

- partial run (not a result): **2 of 14 passes before the pause; config -ngl 99, ctx 8192, KV q8_0/q8_0, FA on. Restarts from scratch on resume.**. Source: `results/full-offload.md`
- llama-bench tg128 at -ngl 99 (unlocked replication, warm): **73.8**. Source: `results/unlocked-replication.md`
- lab server load test at partial offload, gen tok/s, 3 reps (before this node): **20.63 / 21.43 / 21.81**. Source: `results/unlocked-replication.md`
- agent bench median output tok/s at partial offload (before this node): **18.22**. Source: `results/agent-bench/unlocked/summary.json`
- per-run max context, unlocked bench: p50 / p95 / max (tokens): **2811.5 / 4396 / 6248** (computed from the max_ctx field of 36 runs). Source: `results/agent-bench/unlocked/pi_results.jsonl`
- Confounds: The partial run stopped at 14 of 36 runs. The pause confounds timing, so the node restarts from scratch. The prior values are from before this node. They are not its result. The max_ctx field may not equal the context the server needs. Check it against server logs.

### `failure-sort`

- runs / passes (locked 24 + unlocked 36): **60 / 5**. Source: `results/agent-bench/locked/pi_results.jsonl ; results/agent-bench/unlocked/pi_results.jsonl`
- failures by cause (55 failures): **gofmt 17, review 10, timeout 8, rubric 6, build 6, tests 4, vet 2, missing_output 2**. Source: `results/agent-bench/locked/pi_results.jsonl ; results/agent-bench/unlocked/pi_results.jsonl`
- tool-call errors / tool calls: **311 / 661**. Source: `results/agent-bench/locked/pi_results.jsonl ; results/agent-bench/unlocked/pi_results.jsonl`
- runs with at least one loop event (non-empty loops field): **39 of 60 (locked 16 of 24, unlocked 23 of 36); 0 passes among them**. Source: `results/agent-bench/locked/pi_results.jsonl ; results/agent-bench/unlocked/pi_results.jsonl`
- runs with false_done = true: **8 of 60 (locked 5, unlocked 3); all 8 failed**. Source: `results/agent-bench/locked/pi_results.jsonl ; results/agent-bench/unlocked/pi_results.jsonl`
- output-limit hits (sum of length_hits): **20 hits in 18 runs (locked 9 in 7, unlocked 11 in 11)**. Source: `results/agent-bench/locked/pi_results.jsonl ; results/agent-bench/unlocked/pi_results.jsonl`
- passes by role: **planner (pm) 5 of 10; other five roles 0 of 50**. Source: `results/agent-bench/locked/pi_results.jsonl ; results/agent-bench/unlocked/pi_results.jsonl`
- Confounds: First pass from result fields only. No transcript review yet. gofmt, build and vet failures (25 of 55) are checks the agent can run itself before it says 'done'.

### `power-log`

- board Wh per task, locked / unlocked: **2.99 / 2.53**. Source: `results/agent-bench/compare.json`
- board Wh per pass, locked: **35.88**. Source: `results/agent-bench/compare.json`
- board W mean during agent bench, locked: **56.43**. Source: `results/agent-bench/compare.json`
- board peak W under llama load (pause bench): **174.8**. Source: `results/pause-bench.md`
- Confounds: Unlocked power data starts after the first tasks. Unlocked Wh per pass is null. Board power only. The rest of the PC is not measured.

## Key findings so far

- The unlock works. The mma ratio is 0.507 locked and 1.0 unlocked.
- The unlock gives a small gain for the 4-bit chat model. tg128 is 73.80 tok/s unlocked vs 71.18 locked (+3.7%). pp16384 is 2492.6 vs 2295 (+8.6%). The locked run had the display on the RTX card, so these are upper bounds.
- The agent pass rate did not change. It is 8.3% locked (2 of 24) and unlocked (3 of 36).
- Agent median output tok/s rose 1.8% (17.91 to 18.22).
- Flash attention matters at long prompts. pp16384 is 2492.6 tok/s with it and 185.0 without it.
- Mixed K/V cache types (q8_0 K with q4_0 or q4_1 V) hit the flash-attention fallback. They decoded slowest of the quantized pairs.
- Most failures are not about speed. gofmt, build and vet cause 25 of 55 failures. 311 of 661 tool calls failed.
- All 5 passes came from the planner role (5 of 10). The other five roles passed 0 of 50.
- 39 of 60 runs had a loop event. None of them passed. This is a correlation, not a cause.
- WSL2 sees 15.5 of 32 GiB of RAM under its default 50% cap. 11.9 GiB was available with the lab running. That is marginal for MoE expert offload.

## How to replicate

Use your own paths and model files. Check each flag with `--help` on your llama.cpp build. Flag names change between builds.

1. Record the stack (read-only):
   ```
   nvidia-smi --query-gpu=name,driver_version,power.limit,memory.total --format=csv
   llama-cli --version
   free -g; nproc
   ```
2. Check the unlock state. Run the mma rate test from this repo. It prints `ratio_fp32acc_over_fp16acc`. A value near 0.5 means locked. A value near 1.0 means unlocked.
3. Raw speed, full offload, flash attention on and off:
   ```
   llama-bench -m Qwen3-8B-Q4_K_M.gguf -ngl 99 -fa 1 -p 512,4096,16384 -n 128 -r 5
   llama-bench -m Qwen3-8B-Q4_K_M.gguf -ngl 99 -fa 0 -p 512,4096,16384 -n 128 -r 5
   ```
4. KV cache types. Use the same long prompt for each pair. Log peak VRAM. Look for the flash-attention fallback in the server log.
   ```
   llama-server -m MODEL.gguf -ngl 99 -fa on -c CTX -ctk q8_0 -ctv q8_0
   llama-server -m MODEL.gguf -ngl 99 -fa on -c CTX -ctk q4_0 -ctv q4_0
   ```
   Keep K and V the same type.
5. Full offload for agents. Set CTX to the p95 of the context your jobs use (max 32768):
   ```
   llama-server -m MODEL.gguf -ngl 99 -fa on -c CTX -ctk q8_0 -ctv q8_0 --parallel 1 --jinja
   ```
6. Sampler (from the Qwen3-8B GGUF model card):
   ```
   --temp 0.6 --top-p 0.95 --top-k 20 --presence-penalty 1.5
   ```
7. Thinking budget: `--reasoning-budget N`, or no thinking for edit roles.
8. Speculative decoding: n-gram lookup mode first (see `--help`). Then a draft model:
   ```
   llama-server ... -md Qwen3-0.6B-Q8_0.gguf --draft-max 8
   ```
9. Parallel slots. Total context is shared by all slots:
   ```
   llama-server ... --parallel 4 -c $((4*CTX))
   ```
10. MoE expert offload:
    ```
    llama-bench -m Qwen3.6-35B-A3B-UD-IQ4_XS.gguf -ngl 99 -fa 1 --n-cpu-moe 27
    ```
    Check free RAM inside WSL2 first. WSL2 caps memory at 50% of Windows RAM by default.
11. Board power, read-only, every 5 s:
    ```
    nvidia-smi --query-gpu=timestamp,power.draw,temperature.gpu,clocks_throttle_reasons.active --format=csv -lms 5000
    ```
    Start it before the first task. Then Wh per task = sum of (W x 5 s) / 3600 over the task.
12. Agent bench. Run the same task set at n=3 per task. Record pass, failure cause, tool calls, tool errors, loop events, output-limit hits and false "done" per run. Report the pass rate with a 95% confidence interval.

## Measurement rules

- State n for every number. Use `-r 5` and 3 reps for llama-bench where possible.
- Label each run warm or cold. All results in this version are warm.
- Keep the desktop display on the integrated GPU for A/B runs. If you cannot, label the confound.
- Change one thing per run.
- Never use the hidden checks to select or gate agent output.
- Report pass rates with 95% confidence intervals. Small n gives wide intervals.
- Label every confound next to the number.
- A target is a goal. It is not a result.

## Safety limits

- Do not change the power limit, clocks or undervolt.
- Do not reboot, shut down or sleep the machine while unlocked.
- Do not write firmware, VBIOS, ESP, BCD or NVRAM.
- A WSL2 memory-cap change needs the owner's approval.
- Cold-boot arms need the owner present.
- Stop if the screen blanks under load.

## Open items

- The MoE node needs more memory than WSL2 gets at its default 50% cap (15.5 of 32 GiB visible).
- The longest context that real jobs need is not verified against server logs.
- No locked GEMM baseline and no locked flash-attention-off baseline exist.
- The unlocked power log does not cover the first tasks. Unlocked Wh per pass is not known yet.
- Deferred areas: other inference engines and LoRA training for weak roles. They are not in this version of the tree.
