# full-offload (MEASURED, kept, card headless)

Status: measured (2026-10-26). Kept as the current best config. Two earlier attempts are discarded and are not used in this result:
1. A 14-run partial at ctx 8192, stopped for an operator pause.
2. A complete 36-run attempt at the same config as this run, confounded because the desktop was drawn on the 3070. It recorded 4 of 36 passes, agent median output 53.82 tok/s and 202.6 W mean board power. These figures are kept only for reference. They are not a result.

## Config under test
- Qwen3-8B Q4_K_M, llama.cpp b11734, all layers on GPU (-ngl 99), flash attention on, 1 slot.
- ctx 16384, KV q8_0/q8_0. Confirmed from the running server args: `--ctx-size 16384 --gpu-layers 99 --cache-type-k q8_0 --cache-type-v q8_0 --flash-attn on --parallel 1`.
- Note: the default lab config (used outside this node) is ctx 24576, -ngl 30, KV q4_0/q4_0, which matches the configs on the research side. This node overrides it with a drop-in.
- VRAM under load: 6312 MiB of 8192 with the card headless.

## Context check (p95 basis)
- Per-run max context from existing pi agent runs: p95 6248 tokens (nearest rank, n=60, both arms), interpolated 6681, max 10587. Unlocked arm alone: n=36, p95 4496, max 6248.
- Server log of the 14-run partial at ctx 8192: per-request n_tokens p95 6310 (n=240), 3 requests truncated at the limit, 2 requests rejected for exceeding context (13318 and 13812 tokens).
- Choice: 16384. It covers the observed max request and stays under the 32k cap. q8_0/q8_0 fits, so q4_0 was not needed.

## Unlock and machine state at start
- mma ratio FP32-acc / FP16-acc: 1.0 and 1.0 idle before relaunch, 1.0 at bench start (unlocked).
- WSL2 memory cap is 24 GB for the later MoE node. WSL2 reports MemTotal 24612532 kB.
- Idle GPU with the display on the integrated GPU and no lab process: 321 MiB VRAM, 0% utilization, about 6 W, Display Active off, no process listed on the card. With the display on the 3070 it had been 693 MiB, about 25% and about 11 W.

## Bench
- 36-run factory core bench (-n 3), variant base, new tag for this run. Board power logged at 1 s from before the first task, plus a 5 s GPU log.
- Pre-bench tokbench (n=8 and n=4 requests): 2000-token prompt, decode 54.2 tok/s, prefill 442 tok/s; 6000-token prompt, decode 18.9 tok/s, prefill 1844 tok/s.
- All 36 runs completed in about 26 minutes of bench time. Server stayed healthy, no context-exceeded or out-of-memory errors in the server log, no GPU watchdog trip.

## Confounds
- Residual idle VRAM of 321 MiB (baseline idle was 0 MiB). The display itself is off the 3070.
- WSL2 memory cap differs from the baseline (24 GB vs default).
- ctx 16384 differs from the 14-run partial (8192).
- Warm run. n=36 when done; pass rates will carry 95% intervals.

## Results
Compared with the partial-offload agent bench (Qwen3-8B Q4_K_M, -ngl 30, same 36-task set, unlocked, 2026-10-25). The model and quant of that bench are confirmed in its session meta.

| metric | partial offload | full offload | change |
|---|---:|---:|---:|
| passes | 3 of 36 | 6 of 36 | +3 |
| pass rate (Wilson 95% CI) | 8.3% (2.9 to 21.8) | 16.7% (7.9 to 31.9) | intervals overlap |
| passes per hour | 1.716 | 14.54 | 8.5x |
| agent median output tok/s | 18.22 | 57.54 | +216% |
| median wall s per task | 73.4 | 18.39 | -75% |
| board Wh per task | 2.535 | 2.329 | -8% |
| board Wh per pass | n/a | 13.97 | |
| board Wh per 1M output tokens | n/a | 1009 | |
| mean board W during bench | n/a | 203.1 | |
| out-of-memory errors | | 0 | |
| peak VRAM (5 s log) | | 6318 MiB of 8192 | |

Per role, pass rate: pm 5 of 6 (was 3 of 6), testwriter 1 of 6 (was 0), ci, debugger, implementer and reviewer 0 of 6 each (unchanged).

Failure causes of the 30 non-passing runs: gofmt 9, tests 6, review 6, build 4, vet 3, rubric 1, missing output 1. gofmt, build and vet together are 16 of 30, which is the target of test-gate.

## Verdict
Kept for throughput. Targets: decode at least 40 tok/s (57.54 vs 18.22), passes per hour at least 1.5x baseline (14.54 vs 1.716, 8.5x), not below 3 of 36 passes (6), zero OOM (0). All met.

The gain is in passes per hour and throughput. Most of it comes from shorter wall time per task (18.39 s vs 73.4 s median). The pass rate is not shown to be better: 6 of 36 (CI 7.9% to 31.9%) and 3 of 36 (CI 2.9% to 21.8%) overlap, so no pass-rate gain is claimed.

Board power runs near the 220 W limit under full offload (203 W mean), against about 56 W at partial offload. Energy per task still fell slightly because tasks finish about 4x faster.
