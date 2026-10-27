# tool-call-format (MEASURED, negative result, reverted; redefined: edit-tool reliability)

Status: measured (2026-10-26). Negative result. Reverted; the best config stays full-offload. The node id stays `tool-call-format`. The goal is now edit-tool reliability.

## Baseline: tool calls in the full-offload run
Source: the raw per-call log `tool-call-format-errors.jsonl` in this folder. It has one row per errored call (role, task, trial, attempt, tool, error class, short scrubbed message). It was extracted from the event logs of the full-offload headless run (36-run core bench, card headless, base variant).

| class | calls | share |
|---|---:|---:|
| all tool calls | 363 | bash 124, edit 110, read 81, write 48 |
| calls with an error | 144 | 39.7% of 363 |
| malformed calls (bad JSON or schema) | 0 | 0% |
| edit mismatch | 52 | 47.3% of 110 edit calls; 14.3% of 363 |
| - oldText not found | 24 | |
| - oldText not unique | 21 | |
| - no change | 7 | |
| bash command with a non-zero exit | 83 | 66.9% of 124 bash calls; 22.9% of 363 |
| output-limit truncation (call not run) | 9 | write 5, edit 4 |

52 + 83 + 9 = 144.

Correction: the earlier lab count gave bash 78 and truncation 14. A keyword match had put 5 bash errors whose output contained the word "parse" into the truncation class. The per-call log above replaces that count.

## Decisions
- Grammar arm: measured negative result. No call was malformed, and pi already sends a strict JSON schema for tool calls. It is not run.
- Primary target: the 52 edit mismatches.
- Bash non-zero exits (83): secondary metric only. Many are normal test or build failures that the agent must see.
- Output-limit truncations (9): moved to the thinking-budget node.

## Arm (built, opt-in)
A patched copy of pi 1.3.0. The edit tool is changed only when the env flag PI_EDITREL=1 is set, and only the bench's pi wrapper sets it. The live pi install and the harness binary are not changed.
1. Precise mismatch errors.
   - Not found: the nearest match (similarity %, line range, numbered lines) and the first differing line.
   - Not unique: the count and the line numbers of each copy.
   - No change: the edit and its line.
2. Line-anchored edits.
   - Optional startLine and endLine (1-based, inclusive).
   - Without oldText, the arm replaces those lines.
   - With oldText, the arm picks the one copy that starts in that range, so it settles duplicates.
3. Fuzzy match only on a unique hit after whitespace normalization.
   - The hit must be line-aligned and unique.
   - If it is ambiguous, the arm refuses and lists the lines.
   - pi's own partial-line fuzzy match is no longer applied.

Tests: 12 of 12 unit tests pass. They cover each behaviour, refusal when ambiguous, an invalid range and overlapping edits. 4 of 4 integration tests pass through the real tool with the flag on, and 2 of 2 with it off; with the flag off the schema has no startLine.

## Metric
- Edit-error rate per edit call: edit errors, excluding output-limit truncations, over all edit calls.
- Passes per hour and pass rate, n=36 on the core set, against the current best config.
- Secondary: bash non-zero exits per bash call.

The chain computes these from each run's event logs.

## Results
See the lab chain section below.

## Results (lab chain)

Variant editrel-on-base.

| metric | baseline | this node |
|---|---:|---:|
| passes | 6 | 3 |
| runs | 36 | 36 |
| passes per hour | 14.54 | 3.56 |
| median output tok/s | 57.54 | 57.92 |
| board Wh per task | 2.33 | 4.90 |
| board Wh per pass | 13.97 | 58.76 |
| mean board W | 203.15 | 209.13 |
| edit-error rate per edit call (excl. truncation) | 0.47 | 0.67 |
| edit errors | 52 | 108 |
| edit calls | 110 | 162 |
| bash non-zero exits (secondary) | 83 | 246 |
| calls not run: output-limit truncation | 9 | 48 |
| loop events per run | 1.31 | 1.44 |
| runs with a loop event | 28 | 30 |
| loop resets used | 0 | 0 |
| tool error share | 0.40 | 0.65 |
| median wall s | 18.39 | 45.07 |

| role | runs | tool calls | truncated calls | share | length stops | baseline truncated |
|---|---:|---:|---:|---:|---:|---:|
| ci | 6 | 240 | 163 | 0.679 | 8 | 4 |
| debugger | 6 | 141 | 23 | 0.163 | 2 | 1 |
| implementer | 6 | 98 | 7 | 0.071 | 7 | 1 |
| pm | 6 | 16 | 0 | 0.000 | 0 | 0 |
| reviewer | 6 | 29 | 0 | 0.000 | 0 | 0 |
| testwriter | 6 | 93 | 10 | 0.108 | 10 | 3 |

Failures: {'gofmt': 9, 'build': 6, 'review': 6, 'tests': 3, 'rubric': 3, 'vet': 3, 'tampered': 2, 'missing_output': 1}
Baseline failures: {'gofmt': 9, 'tests': 6, 'review': 6, 'build': 4, 'vet': 3, 'rubric': 1, 'missing_output': 1}
mma ratio at start: 1.0. Display on iGPU: True. Warm run, n=36.

## Verdict
Measured negative result. Reverted.

| metric | full-offload (base) | tool-call-format |
|---|---:|---:|
| passes | 6 of 36 | 3 of 36 |
| passes per hour | 14.54 | 3.56 |
| edit-error rate per edit call | 0.47 | 0.67 |
| board Wh per task | 2.33 | 4.90 |

The arm raised the edit-error rate instead of lowering it, and passes per hour fell to about a quarter of the baseline. Calls not run because of output-limit truncation rose from 9 to 48, and the per-role table shows the ci role with by far the highest truncated share (163 of 240 calls), which points to a max-output-tokens follow-up. The best config stays full-offload.
