# llama-bench, locked vs unlocked (one session each, 5 repetitions per test)

llama.cpp build f3fb2fcdb (11734), CUDA backend, Qwen3-8B Q4_K_M (4.68 GiB),
`-ngl 99 -fa 1 -p 512,4096,16384 -n 128 -r 5`, 220 W power limit.

| test    | locked t/s         | unlocked t/s       | change  |
|---------|-------------------:|-------------------:|--------:|
| pp512   | 3026.49 ± 105.93   | 3094.64 ± 126.30   | +2.3 %  |
| pp4096  | 2883.59 ± 9.53     | 2991.60 ± 7.69     | +3.7 %  |
| pp16384 | 2294.64 ± 5.03     | 2484.74 ± 9.22     | +8.3 %  |
| tg128   | 71.18 ± 0.45       | 73.60 ± 0.33       | +3.4 %  |

**Upper bound, not a clean A/B.** During the locked run the desktop display was
driven by the RTX card (about 1.5 GB VRAM in use, SM clock already up). For the
unlocked run the display had been moved to the iGPU (0 MB in use, card idle).
Part of the change, and possibly all of the tg128 change, comes from that, not
from the unlock. pp512 is inside run-to-run noise.
