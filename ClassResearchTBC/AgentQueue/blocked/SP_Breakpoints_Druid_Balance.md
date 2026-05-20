# SP Breakpoints — Druid Balance

Status: blocked
Created: 2026-05-21
Parent job: 001_Druid_Balance (now completed)
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Balance_CHECKLIST.md

## Background

The Druid Balance Research.md contains [VERIFY] rows for SP breakpoint thresholds:
- 800 SP: switch to Wrath filler
- 1000 SP: intermediate breakpoint
- 1200 SP: Starfire dominates

These thresholds determine when the rotation should prefer Starfire vs Wrath as primary filler, and affect mana conserve behavior.

## Why Blocked

No sim or combat log evidence is available to confirm or refute the Research.md breakpoints. The thresholds are currently exposed via the `balance_starfire_mana` slider in `schema_sylvanas.lua` (line 47), allowing player tuning, but auto-switching based on actual spell power is not wired.

## Required Evidence

| Evidence type | Source | Status |
|---|---|---|
| wowsims/tbc simulation data | WowSims TBC module or similar | Not obtained |
| TBC Classic combat logs | Live Sylvanas runtime or WCL | Not obtained |

## Relation to Parent Job

001_Druid_Balance was moved to completed on 2026-05-21 after resolving two of three blockers:
1. ✅ Hurricane Barkskin automation (already implemented, documentation updated)
2. ✅ Innervate assignment-aware casting (smart healer scanning ported from Resto)
3. ⛔ SP breakpoints (this file — tracked separately)

The parent job is complete; all other Druid Balance requirements are implemented and verified.

## Resolution Criteria

To unblock: run wowsims/tbc simulations at gear levels matching 800, 1000, and 1200 spell power with the Balance rotation. Use the results to either:
- Confirm the breakpoints and wire auto-switching into `build_state()` (preferred)
- Refute the breakpoints and update Research.md with corrected values
- Keep thresholds configurable but remove [VERIFY] tags (acceptable fallback)
