# Parse Spec — Druid / Balance (TBC Classic Anniversary 2.5.5)

**Source file**: `EaxRotations/classes/druid/balance_sylvanas.lua`
**Campaign**: Top-Tier Parsing, Phase 2.2b (guide-divergence resolution)
**Date**: 2026-08-13
**Status**: RESOLVED (wrath-conserve opt-out + InnervateHealer split restored; Insect Swarm item closed as already-present no-op)

---

## 1. Pinned source

| Pin | Location | What it pins |
|-----|----------|--------------|
| Strategy order (full, by index) | `EaxRotations/tests/test_balance_dsl_priority.lua` (`expected_order` + exact-index asserts) | The complete `balance_sylvanas.lua` strategy sequence. **27 strategies as of 2026-08-13** (was 26; `InnervateHealer` inserted at index 6, immediately after `InnervateSelf` — pure insertion, all existing relative order preserved). |
| APL conformance manifest | `tools/apl_status.lua` (manifest) + `EaxRotations/tests/test_apl_conformance.lua` | `tbc/balance` **pass** — Go reference `FaerieFireDebuff > InsectSwarmDoT > MoonfireDoT > StarfirePrimary` (no full-sequence TBC balance pin; only the wotlk balance APL is exact-pinned). |
| Matcher behavior | `EaxRotations/tests/test_balance_custom_matches.lua` | WrathFiller / StarfirePrimary mana-tier gating, InnervateSelf self-only, DoT refresh gates, etc. |

**Pin-check result (2026-08-13)**: the TBC balance order is PINNED by
`test_balance_dsl_priority.lua` (exact full-sequence assert). Per campaign
§3.1 the pinned order is kept; this phase only **inserts** one strategy
(insertion is pin-safe) and adds opt-in/opt-out settings.

---

## 2. Guide divergences (P2.2b brief)

Three items from the brief, resolved as follows.

### 2a. `balance_wrath_conserve` (opt-OUT, default **true**)

Current behavior (pre-2.2b): Wrath is a mana-conservation filler — `_choose_nuke`
returns `"wrath"` only below the `balance_wrath_mana` floor (35), Starfire is the
primary nuke. The guide divergence: an aggressive Wrath filler (cast freely
whenever mana allows) for parse play.

Resolution: `balance_wrath_conserve` checkbox (default **true** = opt-OUT) in the
Balance tab (`classes/druid/schema_sylvanas.lua`). The gate is a **first-branch
guard** in `_choose_nuke` (`balance_sylvanas.lua`):

| Setting | `_choose_nuke` behavior |
|---------|--------------------------|
| unset / `true` (default) | byte-equivalent to pre-2.2b: NG → Starfire; mana < floor → Wrath; else Starfire |
| `false` | NG → Starfire; mana >= 10 → Wrath (free filler); else Starfire |

Byte-equivalence at default is proven mechanically: a matcher-output matrix
(13 contexts x 3 states x all 27 strategies, conserve key absent AND explicitly
true) diffed against the HEAD file shows **zero differences** for every existing
strategy (only the new `InnervateHealer` lane lines appear, all `false` with no
`innervate_target`).

### 2b. Insect Swarm opt-in — **already present, closed as no-op**

The brief's `balance_is_enable` opt-in (default false) is a **no-op for this
file**: `InsectSwarmDoT` (index 11) is already live in the single-target rotation
by default with the exact "<3s refresh" contract requested — the matcher refreshes
when `insect_remains <= 2` (`balance_sylvanas.lua`), gated only by the existing
opt-out `balance_use_insect_swarm` (default `true`, schema "Balance" tab) plus the
Phase-2.1 min-SP gate (inert at `spell_damage=0`). Multi-DoT spread
(`InsectSwarmSpread`) also maintains IS when `balance_multidot_enabled`.
Adding a `balance_is_enable` widget that does nothing when toggled would be a dead
menu item; **no widget was added**. If the campaign intends the reverse divergence
(IS *skipped* for parse), that is a different item and is not in the brief text.

### 2c. Smart Innervate healer scan (Pattern 13) — **scan present, lane restored**

The low-mana-healer party scan exists and is correct:
- `_HEALER_IDS = { [2]=true, [5]=true, [7]=true, [11]=true }` (`balance_sylvanas.lua`)
- gated behind `ctx.in_combat` + `spec_kit.setting_bool(ctx, "druid_group_aware_utility", true)` + `ctx.is_group` + `NS.GetPartyMembers()`
- 2s throttled (`_INNERVATE_SCAN_INTERVAL`), first low-mana healer wins (`break`), self fallback at `mana <= balance_innervate_mana`

**Degraded part found**: the scan handed `innervate_target` to a healer but only
`InnervateSelf` existed, which rejects non-self targets — the healer-priority
branch could never cast. Fixed by restoring the `InnervateHealer` strategy
(split per Pattern 13), inserted directly after `InnervateSelf` (index 6, mirroring
resto's adjacency). The two matchers are mutually exclusive on
`NS.same_unit(innervate_target, me)`, so insertion order between them is
semantically irrelevant.

---

## 3. Battery observability

Two scenarios added to `EaxRotations/tests/behavioral_audit.lua` (opt-in pattern (a)):
- `balance_innervate_healer` — `party_members = { _friend(100, 30, 5) }` (priest
  class 5) + bank mana 25 (<= `balance_innervate_mana` 30 + 5). Drives the restored
  `InnervateHealer` lane. Requires the new scenario-aware `ns.GetPartyMembers`
  stub in `apply_battery_state` (live engine API — `main_sylvanas.lua:178/:949` —
  unlike the bare `party_members` field the 2026-08-11 sweep removed).
- `balance_wrath_divergence` — `balance_wrath_conserve = false` at mana 90.
  Proves WrathFiller ALSO fires when the mana-tier gate is removed (it already
  fires at low mana by default, so the never contract is non-vacuous either way).

TBC battery before/after: **never = 16 both** (balance row `never-fires=0` before
with 26 strategies, after with 27). WotLK stays 0, vanilla stays 13 — the new
scenarios are balance-scoped (settings keys + party_members are only read by the
druid innervate scan; mana 90 ≈ the base mana-spec context) and touch none of the
pinned era lanes.

## 4. Verification

- `luac -p` on `balance_sylvanas.lua`, `schema_sylvanas.lua`,
  `test_balance_dsl_priority.lua`, `test_balance_custom_matches.lua`,
  `behavioral_audit.lua`
- `lua EaxRotations/tests/run_rotation_tests.lua --quiet` — 513/513
- `lua EaxRotations/tests/run_leveling_tests.lua --quiet` — 32/32
- `lua EaxRotations/tests/run_wotlk_tests.lua --quiet` — 45/45
- `lua EaxRotations/tests/behavioral_audit.lua` — never = 16
- `lua EaxRotations/tests/behavioral_audit.lua vanilla` — never = 13
- `lua EaxRotations/tests/run_verify_all.lua` — all green (exit 0)
- `lua tools/spec_scorecard.lua` (regenerated `docs/scorecard.md`) + `--check` — in sync
- `python EaxRotations/tools/generate_era_pair_seed.py` (regenerated seed) + `--check` — in sync
  (seed also absorbs concurrent in-flight divergences: elemental
  ChainLightningSingleTarget/FlameShockMaintain, affliction CurseFirst — other
  agents' uncommitted work, per the concurrent-regeneration rule)
