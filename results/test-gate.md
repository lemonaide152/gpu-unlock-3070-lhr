# test-gate (MEASURED, negative result, reverted)

Status: measured (2026-10-26). Negative result. Reverted; the best config stays full-offload.

## What changes
- Variant `testgate` is a copy of the `base` variant. Only the verify step of the four Go roles in the bench (ci, debugger, implementer, testwriter) changes.
- New verify step, run before the agent is allowed to finish: `gofmt -l .` (fails with the file list and a diff if anything is unformatted), then `go vet ./...`, `go build ./...` and `go test -count=1 ./...` on the visible tests in the work tree.
- On failure the output goes back to the agent, same as base. Attempts stay at 2, as in base, so the gate content is the only variable.
- Before this, the base verify steps were uneven: implementer had no gofmt check, debugger had no gofmt or build check, ci had no tests.
- The hidden checks (check.sh) are never used as the gate.
- pm and reviewer are unchanged and act as a control.

## Config
- Current best config from full-offload: Qwen3-8B Q4_K_M, -ngl 99, ctx 16384, KV q8_0/q8_0, flash attention on, 1 slot, card headless.
- Unlock mma ratio 1.0 at start. Pre-bench tokbench matches full-offload (2000-token prompt decode 54.2 tok/s; 6000-token prompt decode 19.0 tok/s).
- Board power logged at 1 s from before the first task, plus a 5 s GPU log with a watchdog.

## Baseline (full-offload, base variant)
6 of 36 passes, 14.54 passes per hour. Failures: gofmt 9, build 4, vet 3 (16 of 30), tests 6, review 6, rubric 1, missing output 1.

## Notes
- A first launch failed before any task ran (the service environment lacked the GPU tool path and the unlock checker path). It was stopped, archived and relaunched with the environment set. No task ran in the failed launch.

## Discarded attempt (wrong task set)
- The first full run picked up the full task set (9 roles, including architect, docs and triage) because the core-set setting was missing from the service environment.
- Stopped at 52 runs and 10 passes. 31 of the 36 core rows (same role, task and trial as the full-offload run) were done, with 4 passes. Missing: pm/webhooks t3, reviewer/paginate t3, reviewer/stats t3, testwriter/parsesize t3, testwriter/semver t3.
- Not all 36 core rows were present, so no result was computed from it. It is archived as -fullset-wrongset and not used.
- Fix: both bench run scripts now default the core set and refuse to start if it is missing.

## Rerun (core set)
- Restarted on the 36-run core set with the same gate settings and attempts 2. Power logger started before the first task. mma ratio 1.0. Pre-bench tokbench: 2000-token prompt decode 54.1 tok/s, 6000-token prompt decode 18.9 tok/s.
- First task ran normally (ci/cishell t1: fail on the ci script check, 14 s). VRAM 6318 MiB under load.

## Results
See the lab chain section below.

## Results (lab chain)

Variant testgate.

| metric | baseline | this node |
|---|---:|---:|
| passes | 6 | 6 |
| runs | 36 | 36 |
| passes per hour | 14.54 | 9.64 |
| median output tok/s | 57.54 | 58.47 |
| board Wh per task | 2.33 | 3.59 |
| board Wh per pass | 13.97 | 21.53 |
| mean board W | 203.15 | 207.58 |
| edit-error rate per edit call (excl. truncation) | 0.47 | 0.49 |
| edit errors | 52 | 44 |
| edit calls | 110 | 89 |
| bash non-zero exits (secondary) | 83 | 70 |
| calls not run: output-limit truncation | 9 | 19 |
| loop events per run | 1.31 | 1.36 |
| runs with a loop event | 28 | 29 |
| loop resets used | 0 | 0 |
| tool error share | 0.40 | 0.37 |
| median wall s | 18.39 | 21.68 |

Failures: {'build': 8, 'review': 6, 'gofmt': 5, 'tests': 5, 'ci_script': 2, 'rubric': 2, 'vet': 2}
Baseline failures: {'gofmt': 9, 'tests': 6, 'review': 6, 'build': 4, 'vet': 3, 'rubric': 1, 'missing_output': 1}
mma ratio at start: 1.0. Display on iGPU: True. Warm run, n=36.

## Verdict
Measured negative result. Reverted.

| metric | full-offload (base) | test-gate |
|---|---:|---:|
| passes | 6 of 36 | 6 of 36 |
| passes per hour | 14.54 | 9.64 |
| board Wh per task | 2.33 | 3.59 |
| gofmt + build + vet failures | 16 of 30 | 15 of 30 |

The gate did not cut gofmt, build and vet failures by half, and passes per hour fell by a third. The extra gate runs on every attempt raise wall time and energy per task. The chain did not move the best config, so later nodes build on the base variant.
