# Compatibility matrix

This file lists GA104 RTX 3070-family results that we know of. Only the first
row is our own result. All other rows are **third-party reports**. We copied
them from the linked public issues and did not test them. A field is
`unknown` when the source does not give it.

## RTX 3070 LHR (`10de:2488`)

| field | this kit (our card) | third-party: [Zagitta #74](https://github.com/Zagitta/gpu-unlock/issues/74) | third-party: [Zagitta #137](https://github.com/Zagitta/gpu-unlock/issues/137) |
|---|---|---|---|
| card | RTX 3070 LHR 8 GB | RTX 3070 LHR | Gigabyte RTX 3070 LHR 8 GB |
| PCI ID | `10de:2488` | `10de:2488` | `10de:2488` |
| VBIOS | 94.04.46.00.1a | 94.04.46.40.16 | 94.04.46.80.05 |
| card modified | no (stock) | no (stock) | no (stock) |
| power limit | 220 W (stock) | unknown | 270 W (board default) |
| OS | Windows 11 | Arch Linux | Bazzite 44 (Fedora 44) |
| method | this kit: pre-OS UEFI EFI from USB | Zagitta kernel module `af28cbb` | Zagitta kernel module `af28cbb` |
| NVIDIA driver | unknown in this table ¹ | 615.78.08 | 615.78.08 (open modules) |
| boot display | Intel iGPU | unknown | the RTX card |
| result | unlocked | unlocked | unlocked |
| proof | mma ratio 0.507 → 1.000 | PyTorch TFLOPS | cuBLAS GEMM TFLOPS |
| FP16 (FP32 acc) | not measured | 46.25 → 82.84 TFLOPS (+79 %) | 8192³: 45.7 → 81.0 TFLOPS (+77 %) |
| BF16 (FP32 acc) | not measured | 46.09 → 81.4 TFLOPS (+77 %) | 8192³: 45.3 → 80.1 (+77 %); 4096³: +84 % |
| TF32 | not measured | 23.12 → 40.74 TFLOPS (+76 %) | 8192³: 22.6 → 40.3 (+78 %) |
| INT8 | not measured | unknown | no change (41.8 → 42.3 TOPS) |
| LLM | llama.cpp Qwen3-8B Q4_K_M, `-ngl 99`: pp512 +2.3 %, pp4096 +3.7 %, pp16384 +8.3 %, tg128 +3.4 % ² | unknown | Ollama qwen3-vl:4b (quantized): no change |
| after S3 sleep | lost (the UEFI flow has no resume path) | still unlocked (the module unlocks again on resume) | not tested |
| warm reboot | unverified | unknown | the module unlocked again on 3 warm reboots |
| stability | one unlock run, completed clean | unknown | **1 of 5 unlocked boots hard-locked** (the first boot; cause unknown). The next 4 boots were clean. |

¹ Our A/B used the same driver before and after. We do not list the version.

² Upper bound. The desktop was on the RTX card in the locked run and on the
iGPU in the unlocked run. Q4 models run mostly through INT8 MMQ kernels, which
the unlock does not speed up. See the [README](README.md#expected-results).

## Other GA104 cards (third-party only)

| card | PCI ID | method | OS | result | gain | source |
|---|---|---|---|---|---|---|
| RTX 3070 (non-LHR) | `10de:2484` | Zagitta kernel module | Linux | unlocked | dense GEMM +73–81 % | [Zagitta README tested-cards table](https://github.com/Zagitta/gpu-unlock#tested-cards), citing [#10](https://github.com/Zagitta/gpu-unlock/issues/10) and [#12](https://github.com/Zagitta/gpu-unlock/issues/12). Other fields unknown. |
| RTX 3070 Ti | `10de:2482` | UEFI port in impacifist/Windows-GPU-UNLOCK | Windows 11 | unlocked (`SS0=0x88888888 SS1=0x8 FLR=1 clean=1`) | FP16 GEMM n=4096: about 43.7 → 88.7 TFLOPS | [Zagitta #32](https://github.com/Zagitta/gpu-unlock/issues/32). VBIOS and power limit unknown. That report used a PC with no iGPU. |

**This kit is tested only on `10de:2488`.** `make-profile.sh` refuses other IDs.

## Submit your card

Please report every result, good or bad. A failed run is also useful.

1. [Open a new issue in this repository](https://github.com/lemonaide152/gpu-unlock-3070-lhr/issues/new) with the title
   `Compatibility: <card> (<PCI ID>), <result>`.
2. Give these fields. Write `unknown` for a field you do not know.
   - Card name and PCI ID (from Device Manager → Hardware Ids, or
     `lspci -nn`). Subsystem ID is optional.
   - VBIOS version (`nvidia-smi -q | findstr /C:"VBIOS"` or GPU-Z).
   - Stock or modified card. Power limit (`nvidia-smi -q -d POWER`).
   - OS and NVIDIA driver version.
   - Which device drives the boot display (iGPU or RTX card).
   - The `mma_rate.py` JSON output, locked and unlocked.
   - The `FINAL` line from `RTX-UNLOCK\RUNnn\UNLOCK.TXT`.
   - Any hang, freeze or crash, and what was running at that time.
   - Optional: S3 sleep and warm-reboot results (run `mma_rate.py` after each).
   - Optional: benchmarks, with the exact command and the confounds.
3. **Remove private data before you post.** Do not post your PROM dump
   (`PROM.BIN`, `ROMIMAGE.BIN`), serial numbers, PC names, user names or file
   paths. Do not attach NVIDIA firmware files.

If you use the Linux kernel module, report to
[Zagitta/gpu-unlock](https://github.com/Zagitta/gpu-unlock/issues/new?template=compatibility-report.yml)
instead.
