# Plan: Targeted `skip_range=true` follow-up (range-verification, phase 2)

**Started:** 2026-07-06
**Status:** Categories A+B+D COMPLETE (committed). Category C deferred.
**Predecessor:** `plans/_archive/range-verification-audit-2026-07-06.md` (phase 1, COMMITTED a338f0f1)

## Context
Phase 1 added the centralized `NS.is_out_of_range` defense-in-depth gate in
`NS.evaluate_cast`, so any `try_cast` WITHOUT `skip_range` now correctly returns
false on OOR (dispatcher falls through). Calls that pass `{ skip_range = true }`
**bypass** that gate. For self-targeted casts (PLAYER_UNIT / `me` / `nil`) that is
correct (no target range). This plan covers the **targeted** (non-self)
`skip_range = true` calls that still bypass the gate.

## Audit result
- **506 self-targeted** `skip_range=true` calls → SAFE (no target range). Untouched.
- **~22 targeted** `skip_range=true` calls across classes/ + shared/. Clustered:

### Category A — Dispels / cleanses on a party member (stall risk: real, low freq)
`try_cast(..., member/target, { skip_range = true })` on a 30–40yd dispel. An OOR
party member could commit and stall.
- `druid/middleware_sylvanas.lua:418` Remove Curse (target)
- `druid/middleware_sylvanas.lua:422` Abolish Poison (target)
- `mage/middleware_sylvanas.lua:378` Remove Curse (target)
- `priest/middleware_sylvanas.lua:338` Dispel Magic (member)
- `priest/middleware_sylvanas.lua:417` Abolish Disease (member)

### Category B — Party buffs / utility on a member (stall risk: real, low freq)
- `druid/middleware_sylvanas.lua:580` Innervate (member)
- `druid/middleware_sylvanas.lua:629` Rebirth (member) — battle rez, range matters
- `priest/discipline_sylvanas.lua:728` Power Infusion (pi_target)

### Category C — Enemy-targeted abilities (mixed; verify intent per spell)
Some target an enemy only to *select* it (effect is self/pet); skip_range may be
intentional. Others (melee interrupts) are wrong to skip.
- `warrior/protection_sylvanas.lua:837` Pummel (target) — **melee interrupt, skip_range LIKELY WRONG**
- `rogue/subtlety_sylvanas.lua:256` & `subtlety_vanilla.lua:215` Premeditation (target)
- `hunter/beast_mastery_sylvanas.lua:616,791` + vanilla `:491,627` Misdirection/BestialWrath
- `hunter/middleware_sylvanas.lua:188` Misdirection (target), `:374` Feed Pet (pet)
- `priest/middleware_sylvanas.lua:456` Shadowfiend (target)

### Category D — Ally movement (stall risk: real)
- `warrior/protection_sylvanas.lua:1049` Intervene (ally.unit)

### Category E — Readiness-only (NOT a cast; lower risk, may need no change)
`spell_ready(..., target, { skip_range = true })` used only to *gate* matches; the
actual cast presumably goes through `try_cast` without skip_range. Verify before
touching.
- `mage/fire_sylvanas.lua:223,351` DragonsBreath readiness on target
- `shaman/restoration_sylvanas.lua:499,559` + vanilla `:367` HealingWave readiness on tank/focus
- `shaman/restoration_sylvanas.lua:42` & vanilla `:30` generic readiness helper (self — safe)

## Status
- **Commit 1 (core):** `a338f0f1` — is_spell_in_range respects native false; is_out_of_range gate; get_spell_range fix. ✅
- **Commit 2 (dispels):** `ad6acff9` — 5 targeted dispel skip_range removed. ✅
- **Commit 3 (party buffs + ally movement):** `298ca818` — Innervate, Rebirth, PI, Intervene skip_range removed. ✅
- **Commit 4 (enemy/pet targeted):** `482482b3` — Pummel, Shadowfiend, Feed Pet skip_range removed. ✅
- **Category C remainder + Category E:** Deferred/verified safe (see below).

## Deferred / verified safe (intentionally kept skip_range)
- **Misdirection** (hunter BM/middleware, vanilla) — targets focus/pet/self; 100yd range; generous by design.
- **BestialWrath** (hunter BM) — self-buff cast via pet target; self-cast pattern.
- **Shadowfiend** (discipline/holy spec files) — `nil` target = self-cast; already safe.
- **Premeditation** (rogue subtlety) — `spell_ready` only (readiness gate), not a cast.
- **DragonsBreath/HealingWave readiness** (Category E) — readiness-only gates; actual casts go through try_cast without skip_range.
