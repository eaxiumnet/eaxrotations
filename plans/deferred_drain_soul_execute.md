# Deferred Concern: Drain Soul "execute" uses Wrath mechanic (not TBC)

**Raised:** 2026-06-25 (APL optimization session, HEAD after `cddd6393`)
**Status:** DEFERRED — mechanic-correctness fix, not an APL reorder. Needs a focused effort.
**Affects:** `EaxRotations/classes/warlock/affliction_sylvanas.lua`, `EaxRotations/classes/warlock/demonology_sylvanas.lua`

## The problem

Both Warlock DPS specs cast Drain Soul as a **sub-25% "execute"**:

- Affliction: `DrainSoulExecute` strategy, `local EXECUTE_HP = 25` (line 56), match gates on
  `state.target_hp <= EXECUTE_HP`. Comment: "Drain Soul (execute <25%)".
- Demonology: `DrainSoul` strategy, `local EXECUTE_THRESHOLD = 25` (line 27), match gates on
  `s.target_hp_pct <= EXECUTE_THRESHOLD`.

## Why it's wrong for TBC Anniversary (2.5.5)

Authoritative TBC guides (Icy-Veins + Warcraft Tavern, both reviewed for the 2.5.5 Anniversary
client, Dec 2025) are explicit:

> "Execute / sub-25%: NONE in TBC. The 'Drain Soul does 4× damage below 25%' execute is a
> **Wrath (3.3.5) mechanic**. In TBC you only cast Drain Soul as a mob dies to grab a Soul
> Shard."

TBC Drain Soul (rank 5) is ~62 damage/sec channeled — vs Shadow Bolt filler at ~250 dps. So
channeling Drain Soul at 25% (for ~75% of the execute window) is a **large DPS loss** in TBC.
The only valid TBC use is shard capture as the mob dies.

## Why it wasn't fixed in the APL sweep

This is a **mechanic/threshold correctness** bug, not a **priority-ordering** gap. The APL
sweep's method (research → compare → reorder the strategy table) doesn't apply — the fix is a
threshold + semantic change ("execute" → "shard capture") and it is **encoded in the test
contract**:

- `test_affliction_custom_matches.lua` lines 283–313 explicitly assert:
  `DrainSoul should not match when target HP > 25%` and `DrainSoul should match when target HP <= 25%`.

Per AGENTS.md Rule 5 (don't loop) and the Assassination-lesson caution (check test contracts
before changing match fns; don't break tests carelessly), a threshold guess + test rewrite
across 2 specs does not belong in the APL-ordering sweep. Deferred to its own concern.

## Suggested fix (for the focused effort)

1. Repurpose both strategies from "execute" to "shard capture": fire Drain Soul only when the
   mob is about to die during the channel, not at 25%.
2. Prefer a **TTD-based** gate (`context.ttd_known and context.ttd < N`) over a flat HP%, since
   a flat % is wrong for high-HP bosses (5% of a boss is still a long channel). The codebase
   already uses `context.ttd` elsewhere (e.g. DoT TTD gates).
3. Optionally add a "needs a shard" condition if shard count is trackable (avoid channeling
   Drain Soul when shards are full).
4. Update both match functions + **both tests** (`test_affliction_custom_matches.lua` and the
   demonology drain-soul test, if any) to assert the new shard-capture behavior, not 25%.
5. Keep the strategy NAMES or update `find_strategy(...)` calls in tests accordingly.
6. Gate: `luac -p` + `validate.cmd` must end `ALL CHECKS PASSED`.

## Verification of the finding

- Spell existence: Drain Soul is a valid TBC spell (not a Wrath spell to remove) — the bug is
  the **threshold/mechanic**, not the spell ID. No DBC change needed.
- No other specs use a Drain Soul execute (only the two Warlock DPS specs).
