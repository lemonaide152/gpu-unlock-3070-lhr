# ram-wsl-check (read-only)

Measured 2026-10-25, with the lab server loaded and the full-offload agent bench running.

| item | value |
|---|---|
| Windows physical RAM | 32 GiB |
| WSL2 memory limit | 15.5 GiB visible (no memory= line in .wslconfig, so the default 50% cap applies) |
| WSL2 used / available during bench | 3.6 GiB used, 11.9 GiB available (6.3 GiB free plus 6.1 GiB page cache) |
| WSL2 swap | 4.0 GiB, 0 used |
| WSL2 processors | 8 (.wslconfig sets processors=8) |
| p95 of per-run max context | reported by the full-offload node |

Notes
- The MoE node estimates 11 to 12 GiB free RAM for CPU-side experts. About 11.9 GiB is available, so it is marginal at the default cap, with no room for build and test jobs.
- Raising the cap needs an edit to .wslconfig and a WSL2 restart. That stops lab services and needs the owner's go. Nothing was edited.
- The processors=8 limit means CPU-side MoE experts and agent build jobs share 8 threads.
