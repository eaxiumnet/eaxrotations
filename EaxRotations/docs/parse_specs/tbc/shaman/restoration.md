# Parse Spec — shaman/restoration (TBC Anniversary 2.5.5)

Pinned source spec for the Shaman Restoration healer rotation
(`EaxRotations/classes/shaman/restoration_sylvanas.lua`). Written 2026-08-13
(Phase 2.2d of the Top-Tier Parsing Campaign).

## Pinned source

- **Primary**: TBC-era resto shaman consensus — wowsims/tbc has **no**
  restoration rotation (engine scaffolding only; `sim/shaman/restoration.go`
  defines no `OnGCDReady` and there is no `apls/` dir), so there is no APL
  fixture to pin. The APL-conformance manifest keeps this spec `pending` by
  design (see `docs/scorecard.md` "Why some healer rows show APL = `pending`"
  and `tools/evidence/apl/SOURCES.md`).
- **Secondary**: Icy Veins / Wowhead TBC resto guides: Chain Heal primary,
  Earth Shield on tank, downranked Chain Heal during mana pressure, Water
  Shield upkeep, Nature's Swiftness emergency save, Mana Tide + Bloodlust CDs,
  totem auto-management.
- **Correctness gates**: behavioral battery (resto = 31 strategies, 0
  never-firing), rotation + leveling + wotlk suites, sylvanas spell-ID audit
  (all cast IDs exist in the 2.5.5 DBC).

## Priority order (live, 2026-08-13 — 31 strategies)

```
FriendlyTarget             Step 0 manual target (threshold 90%)
ManaPotion                 mana <= 20%, in combat, potion available
Healthstone                hp <= 28%, in combat, stone available
ManaEmergencyWand          mana < 5% — blocks all spells, auto-attack only
WaterShield                missing / 0 charges (never during mana emergency)
LightningShield            pre-62 fallback when Water Shield unavailable
EarthShieldTank            tank refresh: charges <= 2 or expiring
NaturesSwiftness           lowest <= 30% HP + TTD <= 3s, buff not already up
ManaTideTotem              in combat, group mana < 60%, group healthy
Bloodlust                  in combat, group healthy (or PvP burst window)
HealingWay                 tank stack < 3, Healing Wave (rank by mana)
PreemptiveChainHeal        predicted damage on cluster, not moving
FSRPause                   five-second-rule pause
LesserHealingWaveEmergency lowest <= 30% HP + TTD <= 3s  <-- Phase 2.2d lane
ChainHeal                  AoE cluster >= 2 targets, lowest <= 65% HP
SmartHeal                  single-target heal selection (HW/LHW by triage)
Purge / TremorTotem / GroundingTotem / totem drops / CurePoison /
CureDisease / PoisonCleansingTotem / DiseaseCleansingTotem
EarthShock / FlameShock / ChainLightning / LightningBolt   (idle DPS)
```

## Thresholds

| Threshold | Default | Setting key |
|---|---|---|
| Chain Heal target HP | 65% | `restoration_chain_heal_hp` |
| Chain Heal min cluster | 2 targets | — |
| Friendly-target HP | 90% | `restoration_friendly_target_threshold` |
| Emergency HP (NS + LHW) | 30% | — (mirrors `natures_swiftness_matches`) |
| Emergency time-to-die | 3s | — (mirrors `natures_swiftness_matches`) |
| Mana low / conserve / emergency | 30 / 15 / 5% | `restoration_mana_low_pct` / `_conserve_pct` / `_emergency_pct` |
| Mana Tide | 60% | `restoration_mana_tide_pct` |
| Earth Shield refresh | charges <= 2 | `restoration_earth_shield_charge_threshold` |
| Healing Wave downrank (mana) | >30 / >15 / else | rank 12 / 11 / 10 |
| Chain Heal downrank (mana) | <45 / <25 | conserve / efficient ranks |

## Divergence record

- **APL**: no wowsims restoration rotation exists for TBC (see Pinned
  source) — this spec is battery-verified internal correctness, not sim
  conformance. No divergence to record.
- **Era mirror**: the strategy set is TBC-only by design; the WotLK mirror
  (`restoration_wotlk.lua`) is a minimal build-out. Divergences are pinned in
  `tests/era_pair_seed.lua` (`shaman/restoration` rows) — every TBC-era
  utility/heal lane, including the new `LesserHealingWaveEmergency`, is
  allowlisted there with the "WotLK-era build-out" rationale. Regenerate with
  `python EaxRotations/tools/generate_era_pair_seed.py` after any strategy
  rename/add, and run `run_era_pair_audit_tests.lua` + `--seed-freshness`.

## Phase 2.2d — LesserHealingWaveEmergency (new lane)

- **Position**: index 14, immediately ABOVE the `ChainHeal` lane (and below
  `FSRPause`), so a dying ally never waits on AoE cluster gating.
- **Gates** (mirror the existing `natures_swiftness_matches` exactly):
  1. `state.mana_emergency` false (spells forbidden below 5% mana);
  2. `state.lowest` exists with a unit;
  3. `state.lowest.effective_hp <= 30` (`> 30` rejects);
  4. `state.lowest_time_to_die <= 3` (`> 3` rejects — the triage scan sets
     TTD = 3 for allies at <= 30% HP);
  5. `state.lesser_healing_wave_ready` (populated in `build_state` from
     `NS.spell_ready(ACTION.LesserHealingWave, me, { skip_range = true })`);
  6. `NS.spell_ready(ACTION.LesserHealingWave, state.lowest.unit, { skip_range = true })`
     (per-target range check).
- **Execute**: casts max-rank Lesser Healing Wave (25420) on `state.lowest.unit`
  with label `[RESTO] LesserHealingWave emergency <hp>%`.
- **Why separate from NaturesSwiftness**: NS is a buff that makes the NEXT
  heal instant — spending it on a cheap LHW wastes the big-heal save. The new
  lane fires the 1.5s LHW directly and leaves the NS buff up for a follow-up
  emergency Healing Wave, so the two lanes stack.
- **Battery observability**: fires in 6 battery scenarios
  (`group_critical`, `group_emergency`, `holy_bop_focused`,
  `holy_last_resort`, `me_casting`, `tank_low` — all carry an ally at
  <= 30% HP with TTD 3). Battery never count unchanged at 16; resto stays
  0 never-firing (31 strategies).
- **Tests**: `test_restoration_dsl_priority.lua` pins the new index, the
  above-ChainHeal ordering, and 5 match/no-match gates (positive + hp / ttd /
  ready / mana-emergency negatives).
