# gpu-unlock-3070lhr

A guide and build kit to apply the FP32-accumulate tensor-core unlock to a
**GeForce RTX 3070 LHR (GA104, PCI `10de:2488`)** on **Windows**. The unlock
runs **before Windows starts**, from a UEFI application on a USB stick.

> **Status: experimental.** We tested this build on **one card in one PC**.
> Read [Risks](#risks) before you start.

## Who this is for

- You own an RTX 3070 LHR (`10de:2488`). An RTX 3070 non-LHR (`10de:2484`)
  uses the same GA104 chip, but this build is **not tested** on it. See
  [COMPATIBILITY.md](COMPATIBILITY.md).
- You use Windows. On Linux, use the kernel module from
  [Zagitta/gpu-unlock](https://github.com/Zagitta/gpu-unlock) instead. It is
  simpler and better tested.
- Your PC has a second display source that is not the RTX card, usually an
  **Intel iGPU**. This build does not work when the RTX card drives the boot
  display.
- You can recover a PC that hangs before the OS starts, and you can change
  UEFI (BIOS) settings.

If any item is not true for you, stop here.

## Risks

Read all of this. Use this kit only if you accept every risk.

- **This is experimental.** It is unofficial, low-level code. It runs NVIDIA
  firmware on your GPU and changes internal GPU settings outside any
  supported path.
- **A hard lock can happen.** In a public report for the same card
  ([Zagitta/gpu-unlock #137](https://github.com/Zagitta/gpu-unlock/issues/137)),
  **one of five unlocked boots hard-locked** about 40 s after the desktop
  came up. It was the first unlocked boot. Only a power cycle recovered it.
  The next four unlocked boots were clean. That report used the Linux module with the card
  as the display card. The cause is unknown.
- **The unlock is lost on power-off.** It is volatile. A cold power-off or
  S3 sleep clears it. You must boot the stick again after each cold start.
- **Warm-reboot persistence is unverified.** We do not know if a Windows
  Restart keeps the unlock. Always measure after a restart.
- **No warranty.** The software comes with no warranty (GPL-2.0 sections
  11 and 12). The authors are not liable for damage or data loss. Use of this
  kit can affect your hardware warranty and can conflict with NVIDIA license
  terms or terms of service.
- **You keep your own VBIOS.** This kit does **not** flash the VBIOS or the
  PROM. It does not change power limits. It does not write NVRAM variables,
  the Windows EFI System Partition or BCD. It writes only to the USB stick.
- **Secure Boot must be off.** This can trigger a BitLocker recovery prompt
  and can block some anti-cheat software.
- **No endorsement.** NVIDIA and the upstream authors do not endorse this kit.

## How it works

GeForce Ampere cards run FP16/BF16 tensor-core MMA with **FP32 accumulation**
at half the rate of FP16 accumulation. The
[gpu-unlock](https://github.com/Zagitta/gpu-unlock) research found a volatile
speed-select setting. When NVIDIA's own signed firmware writes it, the limit
goes away until the next power-off.

This kit uses a UEFI port of that sequence:

1. A **probe** EFI reads the card and the display setup. It writes a report to
   the stick. It does not change the GPU.
2. You build a `PROFILE.BIN` for **your** card from that report.
3. The **unlock** EFI checks the card against the profile. It waits for you
   to press **U**. Then it runs the pinned NVIDIA 610.43.03 firmware sequence,
   writes the speed-select registers (`SS0 = 0x88888888`, `SS1 = 0x8`), does
   one PCIe function-level reset (FLR) and returns to the UEFI firmware.
4. Windows boots normally. The NVIDIA driver loads on the unlocked card.

## Prerequisites

Hardware:

- An RTX 3070 LHR (`10de:2488`).
- An Intel iGPU (or another non-NVIDIA display output) and a cable from the
  monitor to the motherboard video output.
- A USB stick of **64 GiB or less**. The kit erases it.

UEFI settings (menu names change from board to board):

1. **Disable CSM** (Compatibility Support Module). The unlock EFI is a UEFI
   application. On many boards, the iGPU is an option for primary display
   only when CSM is off.
2. **Disable Secure Boot.** The unlock EFI is not signed. It also checks that
   Secure Boot is off before it continues. On AMI firmware, set Secure Boot
   OS Type to *Other OS*.
3. **Set Primary Display to the iGPU** (often called *CPU Graphics* or *IGFX*).
   Select it directly. Do not use *Auto*.
4. **Enable iGPU Multi-Monitor** if your board has it. This keeps the RTX card
   visible to the OS for compute.
5. **Remove all display cables from the RTX card.** Do not use a dummy plug.

Why the display must not be on the RTX card: the unlock resets the card with
an FLR. The UEFI firmware must not use the card for the screen at that time.
The unlock EFI accepts exactly one physical display output (GOP), and it
must be on a non-NVIDIA device. It refuses to run if an NVIDIA GOP is present.

Build machine:

- Linux or WSL2 with `git`, [`bun`](https://bun.sh), `clang`, `lld-link`
  (LLVM), `python3` and the MinGW-w64 headers.
  On Debian or Ubuntu: `apt install git clang lld mingw-w64 python3`.

Target PC:

- An administrator PowerShell, for the scripts in `scripts/windows/`.
- Your BitLocker recovery key, if BitLocker is on.

## Step 1: Build the USB payload (build machine)

```sh
./scripts/build-usb.sh            # writes ./usb-payload
```

The script does these steps:

1. It clones [craftingmod/rtx30-unlock](https://github.com/craftingmod/rtx30-unlock)
   at commit `5c076dc4`.
2. It applies `patches/0001-independent-display-runtime-profile.patch`.
3. It builds the probe EFI and the unlock EFI.
4. It downloads the pinned NVIDIA 610.43.03 packages from NVIDIA, checks
   them and makes the five firmware files **on your machine**.
5. It checks every output file against `SHA256SUMS.expected`.

The build is bit-for-bit reproducible. The unlock EFI must have SHA-256
`d7c22f5c…dff669a`. The probe EFI must have `09d391cb…5946f1a`. If a hash
is different, stop.

Payload layout:

```
EFI/BOOT/BOOTX64.EFI   active EFI (starts as the probe)
STAGE/PROBE.EFI        spare copy of the probe
STAGE/UNLOCK.EFI       the unlock
RTX30-PROBE/           the probe writes RUNxx/ here
RTX-UNLOCK/ASSETS/     five NVIDIA firmware files (made locally)
RTX-UNLOCK/NVIDIA-LICENSE
RTX-UNLOCK/PROFILE.BIN you add this in step 4
```

## Step 2: Write the USB stick (target PC)

In an administrator PowerShell:

```powershell
.\scripts\windows\Flash-Usb.ps1 -DriveLetter E -Source <path>\usb-payload
```

The script refuses a disk that is not USB, is larger than 64 GiB, or holds a
boot or system partition. It asks you to type the disk number. Then it erases
the stick, makes one GPT/FAT32 partition and copies the payload.

## Step 3: Run the probe (read-only)

1. **Shut down fully.** Do not use Restart.
2. Power on. Open the one-time boot menu (often F8, F11 or F12). Select the
   **UEFI: <your USB stick>** entry. Do not change the permanent boot order.
3. The probe writes `RTX30-PROBE\RUNxx\` and returns to the firmware.
   Boot Windows.
4. Copy the report from the stick:
   `.\scripts\windows\Collect-Probe.ps1 -DriveLetter E`

Open `REPORT.TXT` and check it:

- It shows one `10de:2488` target.
- It shows exactly one physical GOP, on the iGPU.
- It shows at most one GOP with no device path and a zero-size framebuffer.
  Some AMI firmware adds this "forwarder" GOP.

If the report shows an NVIDIA GOP, fix the display settings and run the probe
again.

## Step 4: Build your profile (build machine)

```sh
./scripts/make-profile.sh <capture>/RUNxx <usb-root>
```

This uses the upstream tools to write `RTX-UNLOCK\PROFILE.BIN`. The profile
records your card's PCI ID, subsystem, chip ID, cold-state registers, memory
layout and PROM SHA-256. The unlock refuses to run if any of these change.

**Never use a profile from another card.**

## Step 5: Arm the stick (target PC)

```powershell
.\scripts\windows\Swap-ToUnlock.ps1 -DriveLetter E
```

This copies `STAGE\UNLOCK.EFI` to `EFI\BOOT\BOOTX64.EFI` and prints its hash.

## Step 6: Boot the unlock once, by hand

Do this every time. Do not set the stick as a permanent boot entry.

1. **Shut down fully**, then power on. The unlock needs the card in its
   cold state. If a driver already ran, it refuses with
   "card already initialised since power on".
2. Open the one-time boot menu. Select **UEFI: <your USB stick>**.
3. The EFI checks the profile, Secure Boot, the PCI target, the display, the
   PROM and the firmware files. Then it shows:
   `READY ... Press U to attempt once; Esc or 30-second timeout cancels.`
4. Press **U** one time. The screen can go blank for a short time.
   Do not reset the PC and do not remove the stick while it shows `ARMED`.
5. On success, it logs `FINAL status=0 ... clean=1` and returns to the
   firmware. Select **Windows Boot Manager**. Do not reset between these steps.
6. If the screen shows `POWER OFF using the physical power button`, hold the
   power button until the PC turns off. Then boot Windows normally. The card
   is back to stock.

The log is in `RTX-UNLOCK\RUNnn\UNLOCK.TXT` on the stick. A good log has
these lines:

```
selector write: SS0=0x88888888
selector write: SS1=0x8
PCIe FLR returned: result=0
transaction result=0 containment=0 started=1 quiesced=1 fault=0 retained=0 maps=0 FLR=1
FINAL status=0 stage=transaction attempted=1 driver_release=1 clean=1
```

## Step 7: Verify

Run the check in WSL2 (with GPU support) or in Linux. It needs `libcuda.so.1`
and `python3`. It does not need PyTorch or `nvcc`.

```sh
python3 verify/mma_rate.py
```

The script times one tensor-core instruction (`mma.sync.m16n8k16`, FP16
inputs) with FP16 accumulation, then with FP32 accumulation. It prints the
ratio of the two rates:

| ratio | verdict | meaning |
|---|---|---|
| about **0.5** | `likely_locked` | stock: FP32 accumulate runs at half rate |
| about **1.0** | `likely_unlocked` | the unlock is active |

The ratio does not depend on clock speed or power. Run it after **every**
boot, before you trust a benchmark.

For an optional benchmark, `verify/run-bench.sh <tag>` runs the ratio check,
`nvidia-smi` and a `llama-bench` sweep. Set `LLAMA_BENCH` and `MODEL` first.

## How to revert

The unlock does not persist. To remove it:

1. Remove the USB stick.
2. **Shut down fully** (cold power-off) and power on. The card is stock again.
3. Run `verify/mma_rate.py`. The ratio must be about 0.5.

To put the stick back to the read-only probe (for example, after a BIOS or
cable change), run:

```powershell
.\scripts\windows\Swap-ToProbe.ps1 -DriveLetter E
```

Optional: turn Secure Boot on again, set Primary Display back to the PCIe card
(or *Auto*) and move the monitor cable back to the RTX card.

## Expected results

Our card: RTX 3070 LHR, VBIOS 94.04.46.00.1a, 220 W power limit (stock),
Windows 11. We used the same driver and the same binaries before and after.

| metric | locked | unlocked | change |
|---|---:|---:|---:|
| **mma ratio, FP32-acc / FP16-acc** (`verify/mma_rate.py`) | **0.507** | **1.000** | FP32-acc rate x2 |
| llama.cpp pp512 (t/s) | 3026 | 3095 | +2.3 % ¹ |
| llama.cpp pp4096 (t/s) | 2884 | 2992 | +3.7 % ¹ |
| llama.cpp pp16384 (t/s) | 2295 | 2485 | +8.3 % ¹ |
| llama.cpp tg128 (t/s) | 71.18 | 73.60 | +3.4 % ¹ |

llama.cpp build 11734, CUDA backend, Qwen3-8B Q4_K_M,
`-ngl 99 -fa 1 -p 512,4096,16384 -n 128 -r 5`. Raw data is in
[`results/`](results/).

¹ **These llama.cpp numbers are an upper bound.** Read these confounds:

- **The display moved.** In the locked run, the desktop was on the RTX card
  (about 1.5 GB VRAM in use). In the unlocked run, the desktop was on the
  iGPU and the card was idle. Some or all of the gain can come from that
  change. pp512 is inside run-to-run noise.
- **Q4 models use integer kernels.** llama.cpp runs Q4 quantized matrix
  multiplies mostly through its MMQ kernels, which use INT8 math. The unlock
  does not make INT8 faster. So small gains are expected. FP16/BF16 models
  or cuBLAS paths can gain more. We have not measured that yet.
- **Partial offload hides GPU gains.** The table above uses full offload
  (`-ngl 99`). Our other application runs used partial offload, with some
  layers on the CPU. With partial offload, the CPU limits speed and the
  unlock gain is smaller still.
- **Decode is memory-bound.** Token generation (tg) depends on memory
  bandwidth, not tensor math. Do not expect a large tg gain.

The mma ratio is the real proof of the unlock. For dense FP16/BF16 GEMM with
FP32 accumulation, public reports on GA104 show about +77 % to +84 %. See
[COMPATIBILITY.md](COMPATIBILITY.md).

## Known limits

- The unlock is lost on cold power-off and on S3 sleep.
- Warm-reboot behavior is unverified.
- The boot display must come from a non-NVIDIA device. On our PC, the
  upstream path that keeps the display on the RTX card failed with
  `FULL_CHILDREN / EFI_UNSUPPORTED`.
- The patch changes only how the display check accepts one AMI forwarder GOP.
  The forwarder mode must still match the single iGPU GOP. The check still
  refuses any GOP on an NVIDIA device.
- `make-profile.sh` accepts only `10de:2488`.

## Report your card

Please report your result, good or bad.
[Open a new issue](https://github.com/lemonaide152/gpu-unlock-3070-lhr/issues/new) and give the fields in
[COMPATIBILITY.md](COMPATIBILITY.md#submit-your-card).

## Credits

This kit is a small patch and build scripts on top of the work of others:

- **[Zagitta/gpu-unlock](https://github.com/Zagitta/gpu-unlock)**
  (GPL-2.0-only): the original unlock research, the Linux kernel module and
  the 610.43.03 unlock core (`unlock_610`, `prep_610`, `layout_610`,
  `vbios_610`, `gfw_eval`) that the UEFI port uses. Commit `0ebdb1c6`.
- **[rough2515-hub/rtx3080-unlock-public](https://github.com/rough2515-hub/rtx3080-unlock-public)**
  (GPL-2.0): the UEFI port. craftingmod/rtx30-unlock is a fork of it.
- **[craftingmod/rtx30-unlock](https://github.com/craftingmod/rtx30-unlock)**
  (GPL-2.0): the UEFI probe, runtime profile, unlock application and firmware
  tools that this kit builds. Commit `5c076dc4`.
- V67 signature constants: WildFlash1st/cmp90hx-unlock (GPL-2.0), through
  upstream.
- EDK2 MdePkg headers: TianoCore (BSD-2-Clause-Patent), through upstream.

[NOTICE.md](NOTICE.md) lists the exact commits and every change we made.

## License

The patch, the build scripts, the PowerShell scripts and `verify/` are
**GPL-2.0-only** (`LICENSE`), the same as the upstream code they change.
Third-party notices are in `LICENSES/` and `NOTICE.md`.

**This repository has no binaries and no NVIDIA firmware.** We do not ship the
EFI images, because GPL-2.0 requires the full corresponding source with them,
and the build is reproducible. The NVIDIA firmware files are under the NVIDIA
Driver License Agreement (`LICENSES/NVIDIA-Driver.txt`). That license does not
clearly allow redistribution in a UEFI payload, so `build-usb.sh` downloads
NVIDIA's own packages and makes the files on your machine. **Do not commit
NVIDIA firmware to this repository or to a fork of it.**
