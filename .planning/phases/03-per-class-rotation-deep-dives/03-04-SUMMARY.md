---
phase: 03-per-class-rotation-deep-dives
plan: 04
subsystem: warlock-rotations
requirements-completed: [LOCK-01, LOCK-02, LOCK-03]
completed: 2026-03-20
---

# Phase 03 Plan 04: Warlock Rotation Deep Dives Summary

Implemented Warlock rotation upgrades across Affliction, Destruction, and Demonology.

## Completed Work
- Affliction: integrated `dot_manager` clip-safe refresh checks for UA/Corruption/Siphon Life and safer curse refresh logic.
- Destruction: added explicit Conflagrate-on-Immolate behavior and improved proc-aware cast flow.
- Demonology: added Metamorphosis, Immolation Aura, and Shadow Cleave integration with a dedicated demon-form rotation branch.

## Files Modified
- `EAXWarlockAffliction/main.lua`
- `EAXWarlockDestruction/main.lua`
- `EAXWarlockDemonology/main.lua`

## Task Commits
1. `fdfec77` — Affliction DoT clip prevention
2. `08a8ba4` — Destruction Conflagrate proc timing
3. `(this commit)` — Demonology Metamorphosis/Felguard flow + summary completion

## Notes
- Warlock specs continue using shared managers from `eax_shared` (dot/threat/encounter integration preserved).
- Rotations remain compatible with existing interrupt/defensive/OOC framework.

## Self-Check: PASSED
