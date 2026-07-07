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
- [x] Write clean bear_sylvanas.lua (~600 lines, down from ~870)
- [x] luac -p passes
- [x] test_bear_custom_matches passes
- [x] test_state_field_nil_guards passes (22/22)
- [x] test_archive_self_buff_aliases passes
- [x] Full 221 rotation suite passes (0 failures)
- [x] 13 leveling suites pass
- [x] Sylvanas audit: 61 files clean, 0 invalid spell IDs

## COMPLETE — 2026-07-06

### What was removed (form-shifting cruft)
- MarkOfTheWild/GiftOfTheWild/Thorns OOC buffing — KEPT (pre-pull caster prep, never in combat)
- RemoveCurse (caster form) — REMOVED
- FerociousBiteExecute (cat form) — REMOVED
- NaturesGraspPvP (caster form) — REMOVED
- All PvP branches (BashPvP, FeralChargePvP, NaturesGraspPvP, FaerieFirePvP) — REMOVED
- ClearcastingMangle / ClearcastingLacerate (redundant) — REMOVED
- MangleOpener (redundant with MangleBear) — REMOVED
- OffTargetLacerate spreading + scan_pack scoring system — REMOVED
- PoolForMangle wait strategy — REMOVED (tanking = active threat, not idle pooling)

### What was kept (pure bear-form tanking APL)
22 strategies in priority order:
- OOC: Mark/Gift, Thorns, BearForm, PrePullEnrage
- Pull: FeralChargePull, FaerieFirePull
- Defensives: Healthstone, HealingPotion, FrenziedRegeneration, Barkskin
- Taunts: ChallengingRoar (AoE), Growl (single)
- Interrupt: BashInterrupt (via InterruptManager)
- Debuffs: DemoralizingRoar → FaerieFireFeral (Demo before FF — test contract)
- Core: MangleBear → Lacerate → SwipeAoE → Swipe → Maul
- Utility: EnrageCombat (rage gen when starved)

## Constraints
- Test-pinned behavior preserved (FaerieFireFeral, Lacerate, SwipeAoE, Swipe, Maul, DemoRoar-before-FF)
- Pattern 14 nil-guards (rage=0, hp=100 defaults)
- Pattern 15 header (WHAT + SAFETY)
- No banned APIs
