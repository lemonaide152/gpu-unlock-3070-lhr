# full-offload (PARTIAL, paused)

Status: paused. The bench stopped after 14 of 36 runs. These numbers are not a result. The node restarts from scratch on resume, because the pause would confound timing.

Config under test: Qwen3-8B Q4_K_M, all layers on GPU (-ngl 99), ctx 8192, KV q8_0/q8_0, flash attention on, 1 slot. VRAM about 5.4 GiB under load.

Partial agent bench runs (trial 1 complete, trial 2 started):
- 2 of 14 passed (both planner/pm tasks, 14 s and 16 s).
- Failure causes seen: gofmt 6, build 1, vet 1, review 2, missing output 1, agent error 1 (173 tool calls on one task).
- Short tasks finished in 7 to 26 s each. Long testwriter tasks took 180 to 205 s.

Confounds: 14 runs only; ctx 8192 may cut long jobs (not yet checked against p95 context); no power summary computed.
The lab server config was reverted to the previous default while paused.
