#!/usr/bin/env python3
"""Tensor-core issue-rate check via CUDA driver API + PTX (no torch/nvcc).
Measures mma.sync.aligned.m16n8k16 FP16 inputs with FP32 accumulate vs FP16 accumulate.
GeForce Ampere locked: FP32-acc ~ half rate of FP16-acc (ratio ~0.5).
Unlocked (SS0=0x88888888): ratio ~1.0. Ratio is largely clock/power independent.
Exits 0 always; prints JSON. Requires libcuda.so.1 (Linux, or WSL2 with NVIDIA GPU support).
"""
from __future__ import annotations
import ctypes, json, sys, time

CUDA = ctypes.CDLL("libcuda.so.1")
CU_RESULT = ctypes.c_int
CUdevice = ctypes.c_int
CUcontext = ctypes.c_void_p
CUmodule = ctypes.c_void_p
CUfunction = ctypes.c_void_p
CUdeviceptr = ctypes.c_uint64

def ck(r: int, what: str) -> None:
    if r != 0:
        raise SystemExit(f"{what} failed: CUresult={r}")

CHAINS = 8  # independent accumulator chains to keep the pipeline busy

def make_ptx(acc32: bool) -> bytes:
    # One warp (32 threads). Each mma consumes the same A/B; many independent C tiles.
    n_regs = CHAINS * (4 if acc32 else 2)
    lines = [
        ".version 7.0",
        ".target sm_80",
        ".address_size 64",
        ".visible .entry k(.param .u64 out, .param .u32 iters) {",
        ".reg .b32 a<4>; .reg .b32 b<2>; .reg .u32 i, n, tid; .reg .pred p;",
        ".reg .u64 o, off;",
        f".reg .{'f32' if acc32 else 'b32'} c<{n_regs}>;",
        ".reg .f32 s, t;",
        "mov.u32 tid, %tid.x;",
        # non-trivial but finite FP16 bit patterns (1.0 / small ints)
        "mov.b32 a0, 0x3c003c00;",
        "mov.b32 a1, 0x3c003c00;",
        "mov.b32 a2, 0x3c003c00;",
        "mov.b32 a3, 0x3c003c00;",
        "mov.b32 b0, 0x3c003c00;",
        "mov.b32 b1, 0x3c003c00;",
    ]
    for j in range(n_regs):
        lines.append(f"mov.{'f32' if acc32 else 'b32'} c{j}, {'0f00000000' if acc32 else '0'};")
    lines += [
        "ld.param.u32 n, [iters];",
        "mov.u32 i, 0;",
        "LOOP:",
        "setp.ge.u32 p, i, n;",
        "@p bra DONE;",
    ]
    for ch in range(CHAINS):
        if acc32:
            base = ch * 4
            lines.append(
                f"mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 "
                f"{{c{base}, c{base+1}, c{base+2}, c{base+3}}}, "
                f"{{a0, a1, a2, a3}}, {{b0, b1}}, "
                f"{{c{base}, c{base+1}, c{base+2}, c{base+3}}};"
            )
        else:
            base = ch * 2
            lines.append(
                f"mma.sync.aligned.m16n8k16.row.col.f16.f16.f16.f16 "
                f"{{c{base}, c{base+1}}}, "
                f"{{a0, a1, a2, a3}}, {{b0, b1}}, "
                f"{{c{base}, c{base+1}}};"
            )
    lines += ["add.u32 i, i, 1;", "bra LOOP;", "DONE:"]
    # Collapse so the compiler can't DCE the MMAs; write one float per thread.
    if acc32:
        lines.append("mov.f32 s, c0;")
        for j in range(1, n_regs):
            lines.append(f"add.f32 s, s, c{j};")
    else:
        lines.append("cvt.f32.f16 s, c0;")
        for j in range(1, n_regs):
            lines += [f"cvt.f32.f16 t, c{j};", "add.f32 s, s, t;"]
    lines += [
        "ld.param.u64 o, [out];",
        "mul.wide.u32 off, tid, 4;",
        "add.u64 o, o, off;",
        "st.global.f32 [o], s;",
        "ret;",
        "}",
    ]
    return ("\n".join(lines) + "\n").encode()

def load_kernel(ptx: bytes):
    mod = CUmodule()
    ck(CUDA.cuModuleLoadData(ctypes.byref(mod), ptx), "cuModuleLoadData")
    fn = CUfunction()
    ck(CUDA.cuModuleGetFunction(ctypes.byref(fn), mod, b"k"), "cuModuleGetFunction")
    return mod, fn

def time_kernel(fn, out_ptr, iters: int, repeats: int = 7) -> float:
    # Launch one block of 32 threads (one warp). Warm up, then median of repeats.
    grid, block = 1, 32
    times = []
    for r in range(repeats + 2):
        i_c = ctypes.c_uint32(iters)
        o_c = ctypes.c_uint64(out_ptr)
        args = (ctypes.c_void_p * 2)(ctypes.cast(ctypes.byref(o_c), ctypes.c_void_p),
                                     ctypes.cast(ctypes.byref(i_c), ctypes.c_void_p))
        ck(CUDA.cuCtxSynchronize(), "sync-pre")
        t0 = time.perf_counter()
        ck(CUDA.cuLaunchKernel(fn, grid, 1, 1, block, 1, 1, 0, None,
                               ctypes.cast(args, ctypes.c_void_p), None), "launch")
        ck(CUDA.cuCtxSynchronize(), "sync-post")
        dt = time.perf_counter() - t0
        if r >= 2:
            times.append(dt)
    times.sort()
    return times[len(times)//2]

def main() -> int:
    ck(CUDA.cuInit(0), "cuInit")
    dev = CUdevice()
    ck(CUDA.cuDeviceGet(ctypes.byref(dev), 0), "cuDeviceGet")
    name = ctypes.create_string_buffer(64)
    CUDA.cuDeviceGetName(name, 64, dev)
    ctx = CUcontext()
    ck(CUDA.cuCtxCreate(ctypes.byref(ctx), 0, dev), "cuCtxCreate")
    out = CUdeviceptr()
    ck(CUDA.cuMemAlloc(ctypes.byref(out), 32 * 4), "cuMemAlloc")

    # Pick iters so each kernel runs ~50-150 ms
    iters = 200_000
    results = {}
    for label, acc32 in (("fp16_acc", False), ("fp32_acc", True)):
        mod, fn = load_kernel(make_ptx(acc32))
        # calibrate
        dt = time_kernel(fn, int(out.value), iters // 10, repeats=3)
        target = 0.08
        scaled = max(10_000, int((iters // 10) * (target / max(dt, 1e-4))))
        med = time_kernel(fn, int(out.value), scaled, repeats=7)
        # Each iter does CHAINS mmas; each mma is 16*8*16*2 FLOPs = 4096
        flops = scaled * CHAINS * 4096 * 32  # 32 threads? No: one mma per warp covers the tile.
        # Correct: one mma.sync per warp computes a 16x8 tile = 16*8*16*2 = 4096 FLOPs, once per chain.
        flops = scaled * CHAINS * (16 * 8 * 16 * 2)
        tflops = flops / med / 1e12
        results[label] = {"iters": scaled, "median_s": round(med, 6), "TFLOPS_per_warp": round(tflops, 3)}
        CUDA.cuModuleUnload(mod)

    ratio = results["fp32_acc"]["TFLOPS_per_warp"] / max(results["fp16_acc"]["TFLOPS_per_warp"], 1e-9)
    verdict = "likely_unlocked" if ratio > 0.85 else ("likely_locked" if ratio < 0.65 else "uncertain")
    out_json = {
        "device": name.value.decode(),
        "results": results,
        "ratio_fp32acc_over_fp16acc": round(ratio, 3),
        "verdict": verdict,
        "note": "locked Ampere ~0.5; unlocked ~1.0. Absolute TFLOPS here is per-warp synthetic, not dense GEMM.",
    }
    print(json.dumps(out_json, indent=2))
    CUDA.cuMemFree(out)
    CUDA.cuCtxDestroy(ctx)
    return 0

if __name__ == "__main__":
    sys.exit(main())
