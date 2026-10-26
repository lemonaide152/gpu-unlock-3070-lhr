# Lossless pause: slot save/restore benchmark

Build: llama.cpp b11734 CUDA 12.8 (prebuilt).
Model: Qwen3-8B-Q4_K_M. Server: ngl 30, ctx 65536, KV q4_0/q4_0, flash-attn on, parallel 1.
Script: `pause_bench.py 660 1760`.

Method per size: cold `lab start` -> prompt A (log prefix + "READY") -> `lab game`
(save slot 0, stop, 5 s cool-down) -> `lab start` (auto-restore latest) -> follow-up B
(same prefix, new question) -> erase slot 0 -> same B again (cold re-read) -> `lab stop`.
A needle fact (a 4-digit number) sits mid-prefix to check the restored state is real.

| metric | ~15K context | ~40K context |
|---|---|---|
| context tokens saved | 15,090 | 40,158 |
| slot save time (server) | 432 ms | 991 ms |
| `lab game` wall (save+stop+cool-down) | 6.2 s | 6.7 s |
| slot file size | 626 MB (597 MiB) | 1,666 MB (1.55 GiB) |
| `lab start` wall incl. model load + restore | 3.4 s | 3.6 s |
| slot restore time (server) | 180 ms | 391 ms |
| follow-up TTFT after restore | **1.31 s** (21 new tokens, 15,076 cached) | **3.67 s** (21 new, 40,144 cached) |
| same follow-up, cold re-read | 12.21 s (15,097 tokens @ 1,265 tok/s) | 41.66 s (40,165 tokens @ 980 tok/s) |
| speedup on first post-pause reply | 9.4x | 11.3x |
| needle answer after restore / cold | correct / correct | correct / correct |
| generation tok/s (follow-up) | 10.7 | 5.3 |
| VRAM loaded / after stop | 7,629 / 1,348 MiB | 7,527 / 1,313 MiB |
| CUDA error on stop | no | no |

Smoke test (1,158 tokens): save 45 ms / 48 MB, restore 15 ms, follow-up reused 1,145 cached tokens.
Slot file size is ~41.5 KB per token with q4_0/q4_0 (30 GPU + 6 CPU layers).

## Findings
- q4_0/q4_0 KV works with `--slot-save-path` save/restore at b11734: no errors, and the
  restored state answered the needle question identically to a cold read.
- The 21 "new" tokens after restore take 1.0 s (15K) / 3.1 s (40K) to process, much slower
  than their count suggests. That is attention over the full restored context plus
  first-request warm-up after a fresh start. TTFT still drops ~10x.
- Pause and resume are each under 7 s wall. Disk cost per save is 0.6-1.7 GB; `lab.sh`
  keeps the newest 3 (`SLOT_KEEP`).

## Incident during the run
The owner saw the screen blank under GPU load around this run. The bench had already
finished. Peak during the run (5 s samples): 174.8 W of the 220 W limit, 63.2 C,
throttle mask 0x4 (SW power cap) at times. No Kernel-Power 41, 6008, 4101 (TDR), WHEA,
or nvlddmkm/Display event in the Windows System log for the run window.
Do not start the server again until the blanking is understood.
