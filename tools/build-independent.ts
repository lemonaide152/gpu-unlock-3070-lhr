import assert from "node:assert/strict"
import { resolve } from "node:path"
import Bun, { $ } from "bun"

const root = resolve(import.meta.dir, "..")
const output = "build/efi-independent"
const toolOptions = process.env.LLVM_BIN ? { PATH: process.env.LLVM_BIN } : undefined
const clang = Bun.which("clang", toolOptions)
const linker = Bun.which("lld-link", toolOptions)
if (!clang || !linker) throw new Error("Need clang and lld-link")

// Classic unlock efi_main lives in src/unlock/app.c when GU_GOP_EXPERIMENT is unset.
const sources = [
  "src/unlock/app",
  "src/unlock/app_io",
  "src/unlock/ownership",
  "src/unlock/sha256",
  "src/unlock/checks",
  "src/unlock/port",
  "src/unlock/compat",
  "src/unlock/format",
  "src/unlock/runtime",
  "src/unlock/runtime_profile",
  "src/unlock/vendor/unlock_610",
  "src/unlock/vendor/prep_610",
  "src/unlock/vendor/layout_610",
  "src/unlock/vendor/vbios_610",
  "src/unlock/vendor/gfw_eval",
]
const flags = [
  "-target", "x86_64-pc-windows-msvc", "-std=c11", "-ffreestanding", "-fno-builtin",
  "-fno-stack-protector", "-mno-red-zone", "-fshort-wchar", "-Os", "-Wall", "-Wextra", "-Werror",
  "-D__KERNEL__", "-DGU_UEFI_PORT", "-DGU_RUNTIME_PROFILE_BUILD", "-DGU_SSD_EXPERIMENT",
  "-DGC_PRODUCTION",
  // Explicitly NOT defining GU_GOP_EXPERIMENT / GC_FULL_FLR / GC_FULL_UNLOCK / GC_WINDOWS_HANDOFF
  "-Wno-unused-parameter", "-Wno-unused-function",
  "-idirafter", "/usr/x86_64-w64-mingw32/include",
  "-I", "src/unlock/compat",
  "-I", "deps/edk2/MdePkg/Include",
  "-I", "deps/edk2/MdePkg/Include/X64",
]

await $`mkdir -p ${output}`.cwd(root)
const objects: string[] = []
for (const source of sources) {
  const object = `${output}/${source.replaceAll("/", "_")}.obj`
  await $`${clang} ${flags} -c ${source + ".c"} -o ${object}`.cwd(root)
  objects.push(object)
}
await $`${linker} /nologo /nodefaultlib /subsystem:efi_application /entry:efi_main /machine:x64 /base:0 /dynamicbase /nxcompat /timestamp:0 /opt:ref /opt:icf ${"/map:" + output + "/BOOTX64.map"} ${"/out:" + output + "/BOOTX64.EFI"} ${objects}`.cwd(root)
await $`${process.execPath} tools/verify_pe.ts ${output + "/BOOTX64.EFI"} ${output + "/BOOTX64.map"} --output ${output + "/pe-verification.json"}`.cwd(root)
const map = await Bun.file(resolve(root, output, "BOOTX64.map")).text()
for (const symbol of ["DisplayCheck", "GuIndependentDisplay", "gpu_unlock_610_unlock", "GuProfileDecode"]) {
  assert(new RegExp(`\\b${symbol}\\b`).test(map), `Missing symbol: ${symbol}`)
}
assert(!/\bGfPrepare\b/.test(map), "GfPrepare must not be linked (GOP-release path)")
assert(!/\bChildren\b/.test(map), "Children must not be linked")
console.log(`Built independent-display unlock: ${resolve(root, output, "BOOTX64.EFI")}`)
