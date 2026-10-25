# AGENTS.md: replication brief for AI agents

This file is for an AI agent that helps a person apply this kit to their own
RTX 3070 LHR. It restates [README.md](README.md) as an ordered checklist.
If this file and the README disagree, the README wins. Stop and tell your
person.

## Ground rules (read first, follow always)

1. **Your person must be present for every boot.** You never reboot, shut
   down, power on or press keys in a pre-boot screen on their behalf. Steps
   marked **[PERSON]** are done by them, at the machine.
2. **No VBIOS or PROM flashing.** Nothing in this kit writes the VBIOS. Do
   not add a step that does.
3. **No power-limit, clock or fan changes.** Read `nvidia-smi` only.
4. **No writes outside the USB stick** before the OS: no NVRAM variables,
   no Windows EFI System Partition, no BCD, no permanent boot entry. The stick
   is booted once, from the one-time boot menu, each time.
5. **No NVIDIA binaries in any commit, fork or upload.** The build makes the
   firmware files locally from NVIDIA's own packages.
6. **Never reuse another card's `PROFILE.BIN`.** Build one from your
   person's own probe capture.
7. **Do not post private data.** PROM dumps (`PROM.BIN`, `ROMIMAGE.BIN`),
   serial numbers, PC names, user names and file paths stay private.
8. Get your person's explicit yes before each **[PERSON]** step, and tell
   them the risks in [README.md#risks](README.md#risks) first. In one public
   report for this card ([Zagitta #137](https://github.com/Zagitta/gpu-unlock/issues/137)),
   1 of 5 unlocked boots hard-locked. Only a power cycle recovered it.

## Stop conditions

Stop, report to your person, and do not continue if any of these is true:

- The GPU is not PCI `10de:2488` (Device Manager > Hardware Ids, or
  `lspci -nn`). This build is tested only on `10de:2488`, and
  `make-profile.sh` refuses other IDs.
- The PC has no non-NVIDIA display output (usually an Intel iGPU), or the
  person can't move the monitor cable to it.
- The person can't change UEFI settings, can't recover a PC that hangs
  before the OS, or doesn't have their BitLocker recovery key (if BitLocker
  is on).
- Any built file's SHA-256 differs from `SHA256SUMS.expected`.
- The probe report shows an NVIDIA GOP, no `10de:2488` target, or more than
  one physical GOP.
- The unlock screen shows `card already initialised since power on`, or
  `POWER OFF using the physical power button`.
- The unlock log has no `FINAL status=0 ... clean=1` line.
- After the unlock, `verify/mma_rate.py` reads about 0.5.
- Any hang, freeze or crash. Have the person power off, then use
  [How to revert](#how-to-revert).

## Prerequisites (check every item)

Hardware:

- [ ] RTX 3070 LHR, PCI `10de:2488`.
- [ ] Intel iGPU (or another non-NVIDIA display output), with the monitor
      cabled to the motherboard.
- [ ] A USB stick of 64 GiB or less. It will be erased.

UEFI settings, done by **[PERSON]** (menu names vary by board):

- [ ] CSM disabled.
- [ ] Secure Boot disabled (on AMI firmware: Secure Boot OS Type = Other OS).
      This can trigger a BitLocker recovery prompt and can block some
      anti-cheat software.
- [ ] Primary Display set to the iGPU directly (not Auto).
- [ ] iGPU Multi-Monitor enabled, if the board has it.
- [ ] No display cable on the RTX card, and no dummy plug.

Build machine (Linux or WSL2):

- [ ] `git`, `bun`, `clang`, `lld-link`, `python3`, MinGW-w64 headers.
      On Debian or Ubuntu: `apt install git clang lld mingw-w64 python3`,
      plus bun from https://bun.sh.

Target PC:

- [ ] Administrator PowerShell, for `scripts/windows/`.

## Steps

### 1. Build the payload (build machine)

```sh
./scripts/build-usb.sh            # writes ./usb-payload
```

Check: the script verifies every output against `SHA256SUMS.expected`. The
unlock EFI (`STAGE/UNLOCK.EFI`) must be
`d7c22f5cc393543441b8fb69cfbbf44475c16ad3320ebb5f50f5ebe41dff669a`.
The probe EFI must be
`09d391cbeb0c7400605eba62b792b11ebacdb60e5181f07b2094b35685946f1a`.
Any mismatch: stop.

### 2. Write the stick (target PC, admin PowerShell)

```powershell
.\scripts\windows\Flash-Usb.ps1 -DriveLetter <letter> -Source <path>\usb-payload
```

The script refuses non-USB disks, disks over 64 GiB, and disks with a boot or
system partition. It asks for the disk number. **Have your person confirm
the disk number themselves.**

### 3. Run the read-only probe

1. **[PERSON]** Full shutdown (not Restart). Power on, open the one-time boot
   menu, choose **UEFI: <USB stick>**. The probe writes
   `RTX30-PROBE\RUNxx\` and returns to the firmware. Boot Windows.
2. Copy the report: `.\scripts\windows\Collect-Probe.ps1 -DriveLetter <letter>`
3. Check `REPORT.TXT`: one `10de:2488` target, exactly one physical GOP on the
   iGPU, and at most one GOP with no device path and a zero-size
   framebuffer (an AMI "forwarder"). An NVIDIA GOP means: fix the display
   settings and probe again.

### 4. Build the profile (build machine)

```sh
./scripts/make-profile.sh <capture>/RUNxx <usb-root>
```

This writes `RTX-UNLOCK\PROFILE.BIN` for this card only.

### 5. Arm the stick (target PC)

```powershell
.\scripts\windows\Swap-ToUnlock.ps1 -DriveLetter <letter>
```

Check: it prints the hash of `EFI\BOOT\BOOTX64.EFI`. It must equal the
unlock EFI hash from step 1.

### 6. Boot the unlock once, by hand ([PERSON], every cold start)

1. Full shutdown, then power on. The card must be in its cold state.
2. One-time boot menu > **UEFI: <USB stick>**.
3. Wait for `READY ... Press U to attempt once; Esc or 30-second timeout cancels.`
4. Press **U** once. The screen may blank briefly. Do not reset and do not
   pull the stick while it shows `ARMED`.
5. On `FINAL status=0 ... clean=1`, choose **Windows Boot Manager**.
6. On `POWER OFF using the physical power button`: hold the power button
   until off, then boot Windows normally. The card is stock. Stop.

Check the log `RTX-UNLOCK\RUNnn\UNLOCK.TXT`. A good log contains:

```
selector write: SS0=0x88888888
selector write: SS1=0x8
PCIe FLR returned: result=0
transaction result=0 containment=0 started=1 quiesced=1 fault=0 retained=0 maps=0 FLR=1
FINAL status=0 stage=transaction attempted=1 driver_release=1 clean=1
```

### 7. Verify (WSL2 with GPU support, or Linux)

```sh
python3 verify/mma_rate.py
```

Needs `libcuda.so.1` and `python3` only.

| ratio | verdict | meaning |
|---|---|---|
| about 0.5 | `likely_locked` | stock, FP32 accumulate at half rate |
| about 1.0 | `likely_unlocked` | unlock active |

Run it after **every** boot before trusting any benchmark. The ratio doesn't
depend on clocks or power.

Optional benchmark:

```sh
LLAMA_BENCH=/path/to/llama-bench MODEL=/path/to/model.gguf ./verify/run-bench.sh <tag>
```

## Expected results

Measured on our card only (RTX 3070 LHR, VBIOS 94.04.46.00.1a, 220 W stock
limit, Windows 11, one unlock run):

| metric | locked | unlocked |
|---|---:|---:|
| mma ratio, FP32-acc / FP16-acc | 0.507 | 1.000 |
| llama.cpp Qwen3-8B Q4_K_M pp512 (t/s) | 3026 | 3095 |
| llama.cpp pp4096 (t/s) | 2884 | 2992 |
| llama.cpp pp16384 (t/s) | 2295 | 2485 |
| llama.cpp tg128 (t/s) | 71.18 | 73.60 |

The llama.cpp numbers are an **upper bound**. The desktop was on the RTX
card in the locked run only. Q4 models run mostly on INT8 kernels, which
the unlock doesn't speed up. See [README.md#expected-results](README.md#expected-results).
Dense GEMM, S3 and warm reboot are not measured on our card yet.

Other users' numbers, not ours, from the Zagitta Linux kernel module on the
same PCI ID:
[Zagitta #74](https://github.com/Zagitta/gpu-unlock/issues/74) reports GEMM
with FP32 accumulate +76 % to +79 %.
[Zagitta #137](https://github.com/Zagitta/gpu-unlock/issues/137) reports BF16
GEMM +77 % to +84 % and 1 hard lock in 5 unlocked boots.

**The mma ratio is the proof of the unlock.** A ratio near 1.0 with a small
LLM gain is a normal result.

## How to revert

1. **[PERSON]** Remove the stick, full shutdown (cold power-off), power on.
2. Run `verify/mma_rate.py`. It must read about 0.5.
3. To reset the stick to the read-only probe:
   `.\scripts\windows\Swap-ToProbe.ps1 -DriveLetter <letter>`
4. Optional, by **[PERSON]**: Secure Boot back on, Primary Display back to the
   PCIe card (or Auto), monitor cable back to the RTX card.

Known limits: the unlock is lost on cold power-off and, by design, on S3 sleep.
Warm-reboot behavior is unverified, so always measure after a Restart.

## File a compatibility report

Report every result, good or bad, with your person's approval. Remove private
data first (rule 7).

- Form: https://github.com/lemonaide152/gpu-unlock-3070-lhr/issues/new?template=compatibility-report.yml
- Fields (see [COMPATIBILITY.md](COMPATIBILITY.md#submit-your-card)): result,
  card, PCI device ID, VBIOS version, NVIDIA driver version, OS, boot method
  and display setup, results (the `mma_rate.py` JSON, locked and unlocked,
  and the `FINAL` line from `UNLOCK.TXT`), and stability (any hang, freeze
  or crash, and what was running).
- Optional: S3 and warm-reboot results (run `mma_rate.py` after each), and
  benchmarks with the exact command and confounds.
- If you used the Linux kernel module instead, report to
  [Zagitta/gpu-unlock](https://github.com/Zagitta/gpu-unlock/issues/new?template=compatibility-report.yml).
