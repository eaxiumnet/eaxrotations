# Init Log Cleanup — 2026-06-30

## Goal
Reduce verbose EaxRotations initialization spam. Currently logs ~25 lines on boot/UI load
for a class match (e.g. MAGE), with several redundant "module loaded", "registered",
"debug-first-call" gates and `[EaxRotations]` prefix duplication in call sites.

## Source of observed spam (from user's paste)

```
[EaxAutoQuester] Header validated — class: 8                       # 1
[EaxRotations] Header validated - Class: MAGE                       # 2
[Eax Druid Feral ] Player is not Druid; disabling addon.           # 3 (out of scope: from another plugin)
[EaxRotations] Header validated - Class: MAGE                       # 2b (duplicate)
[EaxRotations] Initializing framework for MAGE                     # 4
[EaxRotations] Version 2.2.2 loaded                                # 5
[EaxRotations] [EaxRotations] units domain installed — GetPlayer=... # 6 (double prefix)
[EaxRotations] [PROBE] spell_book present | ...                    # 7 (debug probe)
[EaxRotations] Core runtime loaded (core-v2: pcall buff_manager)   # 8
[EaxRotations] GameVersion: Tbc                                   # 9
[EaxRotations] ExactVersion: wow_tbc_us                           # 10
[EaxRotations] Helper import module loaded                         # 11
[EaxRotations] TBC gear set registry loaded                        # 12
[EaxRotations] IncomingHeals module loaded                         # 13
[EaxRotations] HealerDeficit module loaded                         # 14
[EaxRotations] HotTickTracker module loaded                        # 15
[EaxRotations] Common schema helpers loaded                        # 16
[EaxRotations] Rotation dispatcher loaded                          # 17
[EaxRotations] Mage leveling rotation registered                   # 18
[EaxRotations] Mage arcane rotation registered (burn/conserve ...) # 19
[EaxRotations] Mage fire rotation registered (deep enhanced)       # 20
[EaxRotations] Mage frost rotation registered                      # 21
[EaxRotations] Mage class module loaded                            # 22
[EaxRotations] Class module loaded: MAGE                           # 23 (duplicate of 22)
[EaxRotations:main] REGISTER result=true                          # 24
[EaxRotations:main] REGISTER result=true                          # 24b (print + core.log duplicate)
[EaxRotations] Framework initialized successfully!               # 25
[EaxRotations] Class: MAGE                                        # 26
[EaxRotations] APIs: core, izi_sdk (Project Sylvanas native)       # 27
[EaxRotations] Optimizations: DecisionCache (state tracking)       # 28
[SentinelNavClient] Loaded | Plugin Ready!                         # (out of scope)
[EaxRotations:main] FIRST on_update CALL -- dispatcher is alive    # 29 (one-shot debug)
[EaxRotations:main] HEARTBEAT: on_update callback is firing!..     # 30 (one-shot debug)
[EaxRotations] Rotation Enabled                                  # 31
[EaxRotations] Active playstyle: leveling                         # 32
[EaxRotations:main] ALL-GUARDS-PASSED: reached dispatcher block   # 33 (one-shot debug)
```

Target output (clean summary):
```
[EaxAutoQuester] header validated (class 8)                        # unchanged
[EaxRotations] v2.2.2 loaded for MAGE (core+izi_sdk, 20Hz dispatch) # consolidated
[EaxRotations] Class module: MAGE (4 rotations + leveling)        # consolidated
[EaxRotations] Active playstyle: leveling                         # unchanged
[EaxRotations] Rotation Enabled                                  # unchanged
```

That's 5 lines per class instead of 33.

## Required Behaviour Preserved
- All `core.log` / `core.log_warning` / `core.log_error` sites still callable.
- `NS.log`, `NS.log_warning`, `NS.log_error` still emit default-tagged messages.
- `NS.dump_class_spells` still works (diagnostic dump button).
- All existing tests still pass (210 rotation + 11 leveling).
- Diagnostic/sentinel logs (FIRST on_update, HEARTBEAT, GUARD-N, ALL-GUARDS-PASSED,
  [PROBE], per-module "loaded" announcements, per-rotation "registered" messages,
  [EaxRotations:TRACE]) are demoted to `NS.debug()` and gated behind a default-off
  setting so they can be re-enabled for debugging on demand without code changes.

## Implementation Plan

### 1. `EaxRotations/core/diagnostics.lua` — add `NS.debug`/`NS.verbose` gate
- Add `NS.debug(enabled, msg)` with default `enabled = false`.
- `NS.verbose(msg)` → thin alias of `NS.debug(true, msg)`.
- Add a getter `NS.debug_mode()` that reads the `eax_rotations_debug` setting via
  `NS.get_setting` (default false).
- Keep `NS.log` / `NS.log_warning` / `NS.log_error` as-is (info-level default).

### 2. `EaxRotations/main.lua` — demote + consolidate
- Replace `Header validated` log in `header.lua` to NOT prefix with `[EaxRotations]`
  when called via `core.log`. (Or guard the second duplicate.)
- Consolidate the initial 4-5 startup log lines into TWO summary lines:
  `core.log("[EaxRotations] v" .. version .. " loaded for " .. class_name .. " (core+izi_sdk, 20Hz dispatcher)")`
  `core.log("[EaxRotations] Class module: " .. class_name .. " (N rotations + leveling)")`
  where N = number of registered rotations.
- Demote `FIRST on_update CALL`, `HEARTBEAT`, `GUARD-N`, `ALL-GUARDS-PASSED` from
  `core.log` to `NS.debug()`.
- Remove the duplicate `print("[EaxRotations:main] REGISTER result=true")` next to
  the `core.log` call (it appears twice because both print and log fire).
- Demote `Optimizations:`, `APIs:`, `Framework initialized successfully!` since
  the consolidated startup line covers them.

### 3. `EaxRotations/header.lua` — silence the duplicate
- The header's "Header validated" line is duplicated by main.lua's
  "Initializing framework for X". Drop the header line or merge into the
  consolidated message.

### 4. `EaxRotations/core_sylvanas.lua` — strip redundant prefixes and demote probes
- Lines 523, 1088, 1093, 1098, 1210, 1225 all start `NS.log/something("[EaxRotations] ...")`.
  Since `NS.log` auto-prepends `[EaxRotations]`, these become
  `[EaxRotations] [EaxRotations] units domain...`. Remove the inner prefix.
  Pattern: drop leading `[EaxRotations]` from call-site messages when the
  prefix is already added by the emit helper.
- Lines 5634, 5638 ([PROBE] ...) → demote to `NS.debug`.
- Lines 5667-5668 (GameVersion/ExactVersion at startup) → demote to `NS.debug`.
- Line 1088, 1093, 1098 (tick-source registration messages) → demote to `NS.debug`.

### 5. `EaxRotations/main_sylvanas.lua` — demote tracing and `[EaxRotations:TRACE]` lines
- Lines 955, 962, 967 (context trace / callback trace) → demote to `NS.debug`.
- Line 1115 (strategy trace) → demote to `NS.debug`.

### 6. `EaxRotations/shared/*` and `EaxRotations/classes/*` — demote "module loaded"
- Each shared module's `if NS.log then NS.log("X module loaded") end` → demote to `NS.debug`.
- Each rotation's `NS.log("Mage X rotation registered")` → demote to `NS.debug`.
- Files touched: ~17 shared modules + ~4 spec files per class. That's ~75+ files.

To avoid touching every spec, I'll instead **bypass this by silencing at the dispatch
sink**: in `core_sylvanas.lua` (or `core/diagnostics.lua`), I'll make `NS.log` itself
suppress known noisy prefixes unless a debug flag is on.

**Decision**: Take the second approach — gate noisy INFO-level messages at the
diagnostics sink. Forward a small allowlist:
- Always visible: errors/warnings, combat events, "Active playstyle:", "Rotation Enabled".
- Default-suppressed (debug-only): "loaded", "registered", "installed", domain/heartbeat/guard.

This avoids touching ~75 spec files while still gating the same set of lines.

### 7. `EaxRotations/gear_sets_sylvanas.lua`, `helpers_sylvanas.lua`, `common_sylvanas.lua`
- Demote `NS.log("X loaded")` → `NS.debug`.

## Files Touched (planned)
- `EaxRotations/core/diagnostics.lua`           (add NS.debug)
- `EaxRotations/core_sylvanas.lua`              (string gate + prefix cleanup)
- `EaxRotations/main.lua`                       (consolidate + demote)
- `EaxRotations/header.lua`                     (silent header, demote probe)
- `EaxRotations/main_sylvanas.lua`              (demote trace)
- `EaxRotations/gear_sets_sylvanas.lua`         (demote loaded message)
- `EaxRotations/helpers_sylvanas.lua`           (demote loaded message)
- `EaxRotations/common_sylvanas.lua`            (demote loaded message)
- `EaxAutoQuester/header.lua`                   (optional: keep)

## Tests
- `lua EaxRotations/tests/run_rotation_tests.lua`    — 210 PASS (unchanged)
- `lua EaxRotations/tests/run_leveling_tests.lua`    — 11 PASS (unchanged)
- `luac -p` on every modified file should pass.

## Out of Scope
- EaxAutoQuester-only logging (one line, not noisy)
- SentinelNavClient log lines (third-party)
- `[Eax Druid Feral]` debug messages (out of class, third-party)

## Risk
LOW. We're only:
(1) Demoting INFO lines to DEBUG (no functional change; can be toggled back via setting).
(2) Fixing double-prefix strings (cosmetic only — pure noise reduction).
(3) Consolidating startup log lines (readability — same info).
(4) Removing a duplicated `print()` mirroring a `core.log()`.

No data flows, no behavior changes, no regression risk to rotation logic.
