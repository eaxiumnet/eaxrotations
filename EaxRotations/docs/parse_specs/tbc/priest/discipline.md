# Parse Spec — Priest / Discipline (TBC Classic Anniversary 2.5.5)

**Source file**: `EaxRotations/classes/priest/discipline_sylvanas.lua`
**Campaign**: Top-Tier Parsing, Phase 2.2c (guide-divergence resolution)
**Date**: 2026-08-13
**Status**: RESOLVED (pinned order kept; opt-in setting closes the guide gap)

---

## 1. Pinned source

| Pin | Location | What it pins |
|-----|----------|--------------|
| Strategy order (full, by index) | `EaxRotations/tests/test_discipline_dsl_priority.lua` (`expected_order`, lines 131–141; exact-index asserts lines 151–157) | The complete `discipline_sylvanas.lua` strategy sequence — **including `GreaterHeal`(7) above `FSRPause`(8), `BindingHeal`(9), `PrayerOfHealing`(10)**. |
| APL conformance manifest | `tools/apl_status.lua` (manifest) + `EaxRotations/tests/test_apl_conformance.lua` | **TBC discipline is NOT pinned** by any wowsims APL. APL pins for priest are only: `wotlk/priest/discipline` (PW:S > Penance > PoM, `discipline_wotlk.lua`) and `wotlk/priest/holy`. TBC-era pins are `priest/shadow` and `priest/smite` only. |
| PoH nil-guard / threshold contract | `EaxRotations/tests/test_priest_discipline_poh_nil_guard.lua` | Matcher must not crash on nil counts; default 0 gates out; count >= threshold proceeds. Boundary value was 4, **re-pinned to 3 on 2026-08-13** (see §4). |
| PoH threshold boundary | `EaxRotations/tests/test_discipline_custom_matches.lua` (PoH block) | "below N injured gates, at N matches". Boundary **re-pinned 4 → 3 on 2026-08-13**. |
| Scenario fidelity (battery) | `EaxRotations/tests/test_heal_scan_lane_regression.lua` (disc block) | Battery `group_aoe` scenario must still yield `group_damaged_count >= 4` (unchanged; label updated to the new matcher threshold). |

**Pin-check result (2026-08-13)**: the TBC discipline **order is PINNED** by
`test_discipline_dsl_priority.lua` (exact full-sequence assert), even though the
APL conformance layer has no TBC discipline pin. Per campaign §3.1: **keep the
pinned order** — do not reorder.

---

## 2. Guide priority (divergence)

The rotation guide places **Prayer of Healing + Binding Heal ABOVE the GH/FH
tier** (Greater Heal / Flash Heal). The pinned file order has them BELOW it:

```
... EmergencyFlashHeal(5) → PreemptiveGreaterHeal(6) → GreaterHeal(7)
    → FSRPause(8) → BindingHeal(9) → PrayerOfHealing(10) ...
```

## 3. Divergence resolution — `disc_poh_priority` (default OFF)

Because the order is pinned, the gap is closed at runtime with an **opt-in
setting**: `disc_poh_priority` (menu widget in
`EaxRotations/classes/priest/schema_sylvanas.lua`, "Discipline → Healing
Priority" section; default `false`).

When enabled, `_poh_priority_yield(context, s)` makes the GH/FH-tier matchers
yield whenever BindingHeal or PrayerOfHealing **would fire**:

| Strategy gated | File:line (discipline_sylvanas.lua, 2026-08-13) |
|----------------|--------------------------------------------------|
| `GreaterHeal` (`greater_heal_matches`) | yield gate as first matcher check |
| `PreemptiveGreaterHeal` (GH tier) | yield gate as first matcher check |
| `EmergencyFlashHeal` (FH tier, DSL custom condition) | yield gate as first custom-fn check |

`_poh_priority_yield` = `setting_bool(context, "disc_poh_priority", false)`
AND (`binding_heal_matches(context, s)` OR `prayer_of_healing_matches(context, s)`).
BindingHeal/PrayerOfHealing matchers themselves are unchanged (they just become
reachable first, because the tier above them steps aside). When the setting is
OFF (default) every matcher behaves byte-identically to the pinned order — the
battery never-list (TBC = 16) is unaffected.

Lua scoping note: `binding_heal_matches` / `prayer_of_healing_matches` are
forward-declared as locals before `_poh_priority_yield` (upvalue capture) and
assigned in function form below (`binding_heal_matches = function ... end`).

## 4. Threshold changes (matcher-only)

| Key | Before | After | Where |
|-----|--------|-------|-------|
| PoH injured-count threshold | `poh_count < 4` | `poh_count < 3` | `prayer_of_healing_matches` (single matcher line) |

`poh_count` priority: `party_injured_count` → `subgroup_damaged_count` →
`group_damaged_count` → 0 (safe_state schema default). Nil counts still gate
out (0 < 3), so the nil-guard contract in
`test_priest_discipline_poh_nil_guard.lua` is preserved unchanged.

## 5. Battery observability

No strategy was added, removed, or reordered; the opt-in gates are inactive by
default. `behavioral_audit.lua` before/after: **never = 16** (priest/discipline
never-fires = 0). No triage addendum or scorecard pin change required.

## 6. Verification

- `luac -p` on `discipline_sylvanas.lua`, `schema_sylvanas.lua`,
  `test_discipline_custom_matches.lua`, `test_heal_scan_lane_regression.lua`
- `lua EaxRotations/tests/run_rotation_tests.lua --quiet`
- `lua EaxRotations/tests/run_leveling_tests.lua --quiet`
- `lua EaxRotations/tests/run_wotlk_tests.lua --quiet`
- `lua EaxRotations/tests/run_verify_all.lua` (exit 0)
- `lua EaxRotations/tests/behavioral_audit.lua` — never = 16
- `lua tools/spec_scorecard.lua --check` — in sync (no pin changes)
