# Bear Druid Clean Rebuild

**Started:** 2026-07-06
**Goal:** Rewrite `bear_sylvanas.lua` as a pure bear-form tank rotation — no cat/caster form shifting.
**Source:** wowsims/tbc `sim/druid/tank/rotation.go` + Icy Veins / Warcraft Tavern consensus.

## Problem
Current file is 41KB / ~870 lines with:
- Caster-form buffs (Mark/Thorns/GotW) — form shifting
- RemoveCurse (caster form) — form shifting
- Ferocious Bite execute (cat form) — form shifting
- Nature's Grasp (caster form) — form shifting
- 6 PvP-specific strategies (BashPvP, FeralChargePvP, NaturesGraspPvP, FaerieFirePvP, etc.)
- Off-target lacerate spreading (scan_pack scoring system)
- ~20 helper functions for unit introspection used only by removed strategies

## APL (wowsims/tbc tank)
1. Lacerate refresh (5 stacks, ≤1.5s remaining)
2. Faerie Fire (Feral) maintain
3. Demoralizing Roar maintain
4. Swipe (AoE mode OR high AP at 5 stacks)
5. Mangle (Bear) on CD
6. Swipe (high AP filler)
7. Lacerate (default filler)
- Maul queued on auto-attack (rage dump, not GCD)
- Growl: single taunt; Challenging Roar: AoE taunt (3min)
- Frenzied Regen + Barkskin: defensives

## Changes
- [x] Baseline GREEN (220 suites)
- [ ] Write clean bear_sylvanas.lua (~400 lines)
- [ ] luac -p passes
- [ ] test_bear_custom_matches passes
- [ ] test_state_field_nil_guards passes
- [ ] Full 220 suite passes

## Constraints
- Test-pinned behavior preserved (FaerieFireFeral, Lacerate, SwipeAoE, Swipe, Maul, DemoRoar-before-FF)
- Pattern 14 nil-guards (rage=0, hp=100 defaults)
- Pattern 15 header (WHAT + SAFETY)
- No banned APIs
