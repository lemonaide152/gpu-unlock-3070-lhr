# Unlocked replication (lab server stopped)

Source: the lab's unlocked replication run. The lab server was stopped for this run and restored after it.
mma ratio (FP32-acc/FP16-acc): 1.0 in three separate checks.

## llama-bench full offload (ngl 99, fa 1, f16 KV), mean of 3 reps x -r 5
| test | locked (earlier, display on RTX) | unlocked earlier | unlocked replication |
|---|---:|---:|---:|
| pp512 | 3026 | 3094.6 | 2963.8 (rep1 2759.7 +-284, reps 2-3 3070.3/3061.3) |
| pp4096 | 2884 | 2991.6 | 2963.7 |
| pp16384 | 2295 | 2484.7 | 2492.6 |
| tg128 | 71.18 | 73.60 | 73.80 |

## GEMM diagnostic, median of 3 reps (TFLOPS; INT8 in TOPS). No locked GEMM baseline exists.
| shape | FP16 in/FP32 acc | FP16 in/FP16 acc | BF16 | TF32 | INT8 | FP32acc/FP16acc |
|---|---:|---:|---:|---:|---:|---:|
| sq4096 | 67.29 | 66.42 | 70.99 | 34.88 | 39.84 | 1.014 |
| pp512_qkv | 58.63 | 62.29 | 58.12 | 31.48 | 34.97 | 0.942 |
| pp512_ffn_up | 63.02 | 62.15 | 63.55 | 32.04 | 37.98 | 1.010 |
| pp512_ffn_down | 61.68 | 63.21 | 64.45 | 32.46 | 38.84 | 0.976 |
| pp4096_ffn_up | 72.67 | 74.26 | 73.56 | 36.63 | 40.72 | 0.979 |

## llama-bench -fa 0 (attention via cuBLAS), 1 run x -r 5; no locked fa0 baseline
pp512 2726.3, pp4096 1976.4, pp16384 185.0 tok/s.

## KV-cache A/B, ngl 30, 64K ctx, 15,414-token prompt, 3 reps (prefill / gen tok/s, peak VRAM MiB)
| K/V | prefill | gen | peak VRAM | FA fallback flag |
|---|---:|---:|---:|---|
| q4_0/q4_0 | 1322-1350 | 11.5-12.1 | 6393 | 0 |
| q8_0/q8_0 | 1277-1308 | 9.6-10.2 | 7933 | 0 |
| q8_0/q4_1 | 1294-1311 | 9.4-9.7 | 7473 | 1 |
| q8_0/q4_0 | 1233-1330 | 9.0-10.0 | 7355 | 1 |
| f16/f16 | 92-95 | 3.98-4.05 | 7935 | 0 |
f16/f16 sits at the 8 GB ceiling; the collapse is likely memory spill (hunch, not verified).

## Load test (lab server, 600 s, 3 reps): gen_tps mean 20.63 / 21.43 / 21.81; pp_tps mean 63.3 / 65.1 / 65.8.
Locked reference (earlier log, 1 rep): gen 21.17, pp 101.4. Different day, server config not re-checked.

## Confounds
No locked GEMM or fa0 baseline. Locked runs had the desktop on the RTX (~850 MiB more VRAM in use). Locked pi n=2/task, unlocked n=3. pi agent is non-deterministic. Unlocked power telemetry starts after the first pi tasks, so those tasks have no energy, and unlocked Wh/task averages only covered tasks (Wh/pass, Wh/Mtok, W mean stay null). Locked power comes from a 5 s nvidia-smi log; locked mma was not measured in-session (null).
