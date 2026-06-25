# Implementation Plan: APL & Guide-Based Rotation Optimization (29 Specs)

**Created:** 2026-06-25
**API Surface:** All `api/` files; `apidocs/pages/dev/api/` for spellbook, buffs, input
**Docs References:** AGENTS.md Pattern 10, Pattern 14, Pattern 15

## Overview

The original project goal was to optimize all 29 EaxRotations specs against authoritative sources (Wowhead, IcyVeins, SimulationCraft APL, tbc-main reference). This has NOT been done. Current rotations were written by prior authors and may deviate from optimal TBC Anniversary (2.5.5) priorities.

This plan documents a systematic, spec-by-spec optimization effort. Each spec is researched independently, compared against its current implementation, and updated if gaps are found.

**Scope:** 29 TBC specs (`*_sylvanas.lua`) + 11+ vanilla variants (`*_vanilla.lua`). Vanilla is lower priority.

## Methodology (Per Spec)

For each spec:

1. **Research** — Read 2–3 authoritative sources:
   - Wowhead TBC Classic guide for the spec (e.g., `wowhead.com/tbc/guide/classes/warrior/arms`)
   - IcyVeins TBC Classic guide (if available)
   - SimC APL from `tbc-main/` or `tbc-new/` reference repos (internal clones, NOT committed)
   - `wowhead_data/spells/tbc/<id>.json` for spell data verification

2. **Extract Priority List** — Build a text priority list from the guide

3. **Compare** — Read current `<spec>_sylvanas.lua` strategy table, line up against extracted list

4. **Identify Gaps** — Note missing strategies, wrong ordering, incorrect thresholds, outdated spells

5. **Implement** — Edit the spec file (Pattern 10 structure). Nil-guard all changes (Pattern 14).

6. **Validate** — `luac -p` + full gate (`validate.cmd`) + add/update test if behavior changes

7. **Commit** — One concern per commit

## Files to Touch

| File | Change | Verification |
|------|--------|------------|
| `EaxRotations/classes/<class>/<spec>_sylvanas.lua` | Strategy reordering/addition/removal | Gate + spec-specific test |
| `EaxRotations/tests/test_<spec>_custom_matches.lua` (existing) | Update if strategies change | Existing test must still pass |
| `EaxRotations/tests/test_<spec>_feature_gaps.lua` (existing) | Update count assertions | Bump if strategy count changes |
| `plans/apl-guide-optimization-2026-06.md` | Mark spec done | Track progress |

## Task List

### Phase 0: Planning & Reference Extraction
- [ ] **P0.1** Extract APL priority lists from `tbc-main/` and `tbc-new/` reference repos (read-only, internal)
  - Files: `tbc-main/classes/<class>/<spec>.lua` (or equivalent)
  - Acceptance: Documented priority lists for all 29 specs in this plan
  - Verify: N/A (research only)

- [ ] **P0.2** Identify specs with KNOWN issues from test suite / bug reports
  - Files: Review test failures, skipped tests, TODO comments
  - Acceptance: List of "high-confidence gap" specs
  - Verify: Read test files

### Phase 1: Warrior (3 specs)
- [ ] **P1.1** Arms — compare against Wowhead Arms Warrior TBC guide
  - Files: `EaxRotations/classes/warrior/arms_sylvanas.lua`
  - API Used: `izi.spell()`, `NS.buff_points()`, `core.object_manager.*`
  - Acceptance: Execute phase threshold correct, Rend maintenance logic verified, Sweeping Strikes usage
  - Verify: `luac -p`, gate, `test_arms_*`

- [ ] **P1.2** Fury — compare against Wowhead Fury Warrior TBC guide
  - Files: `EaxRotations/classes/warrior/fury_sylvanas.lua`
  - Acceptance: BT/Whirlwind priority, Execute sub-20%, Flurry uptime
  - Verify: `luac -p`, gate, `test_fury_*`

- [ ] **P1.3** Protection — compare against Wowhead Prot Warrior TBC guide
  - Files: `EaxRotations/classes/warrior/protection_sylvanas.lua`
  - Acceptance: Shield Slam > Revenge > Devastate, threat vs survival tradeoffs
  - Verify: `luac -p`, gate

### Phase 2: Hunter (3 specs)
- [ ] **P2.1** Beast Mastery — compare against Wowhead BM Hunter TBC guide
  - Files: `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua`
  - Acceptance: Steady Shot weave, Kill Command, pet management, aspect logic
  - Verify: `luac -p`, gate, `test_hunter_*`

- [ ] **P2.2** Marksmanship — compare against Wowhead MM Hunter TBC guide
  - Files: `EaxRotations/classes/hunter/marksmanship_sylvanas.lua`
  - Acceptance: Steady Shot priority, Arcane Shot weaving, Trueshot Aura
  - Verify: `luac -p`, gate

- [ ] **P2.3** Survival — compare against Wowhead SV Hunter TBC guide
  - Files: `EaxRotations/classes/hunter/survival_sylvanas.lua`
  - Acceptance: Explosive Shot (if TBC-era), trap weaving, serpent sting
  - Verify: `luac -p`, gate

### Phase 3: Mage (3 specs)
- [ ] **P3.1** Arcane — compare against Wowhead Arcane Mage TBC guide
  - Files: `EaxRotations/classes/mage/arcane_sylvanas.lua`
  - Acceptance: Arcane Blast spam vs Arcane Missiles, evocation timing
  - Verify: `luac -p`, gate

- [ ] **P3.2** Fire — compare against Wowhead Fire Mage TBC guide
  - Files: `EaxRotations/classes/mage/fire_sylvanas.lua`
  - Acceptance: Scorch maintenance, Fireball vs Scorch filler, combustion
  - Verify: `luac -p`, gate, `test_fire_*`

- [ ] **P3.3** Frost — compare against Wowhead Frost Mage TBC guide
  - Files: `EaxRotations/classes/mage/frost_sylvanas.lua`
  - Acceptance: Frostbolt filler, Waterbolt pet, ice lance (if backported)
  - Verify: `luac -p`, gate, `test_frost_*`

### Phase 4: Rogue (3 specs)
- [ ] **P4.1** Assassination — compare against Wowhead Assassination Rogue TBC guide
  - Files: `EaxRotations/classes/rogue/assassination_sylvanas.lua`
  - Acceptance: Mutilate spam, rupture maintenance, envenom timing
  - Verify: `luac -p`, gate

- [ ] **P4.2** Combat — compare against Wowhead Combat Rogue TBC guide
  - Files: `EaxRotations/classes/rogue/combat_sylvanas.lua`
  - Acceptance: Sinister Strike vs Hemorrhage, Slice and Dice maintenance, Adrenaline Rush
  - Verify: `luac -p`, gate, `test_rogue_*`

- [ ] **P4.3** Subtlety — compare against Wowhead Subtlety Rogue TBC guide
  - Files: `EaxRotations/classes/rogue/subtlety_sylvanas.lua`
  - Acceptance: Backstab/Ambush priority, hemorrhage maintenance, Premeditation
  - Verify: `luac -p`, gate

### Phase 5: Paladin (3 specs)
- [ ] **P5.1** Holy — compare against Wowhead Holy Paladin TBC guide
  - Files: `EaxRotations/classes/paladin/holy_sylvanas.lua`
  - Acceptance: Holy Light vs Flash of Light, downranking, Divine Favor
  - Verify: `luac -p`, gate, `test_paladin_holy_*`

- [ ] **P5.2** Protection — compare against Wowhead Prot Paladin TBC guide
  - Files: `EaxRotations/classes/paladin/protection_sylvanas.lua`
  - Acceptance: Avenger's Shield opener, consecration, Holy Shield uptime
  - Verify: `luac -p`, gate

- [ ] **P5.3** Retribution — compare against Wowhead Ret Paladin TBC guide
  - Files: `EaxRotations/classes/paladin/retribution_sylvanas.lua`
  - Acceptance: Seal twisting, Judgement priority, Crusader Strike, Avenging Wrath
  - Verify: `luac -p`, gate, `test_paladin_tbc_seals`

### Phase 6: Priest (4 specs)
- [ ] **P6.1** Holy — compare against Wowhead Holy Priest TBC guide
  - Files: `EaxRotations/classes/priest/holy_sylvanas.lua`
  - Acceptance: Greater Heal vs Flash Heal, Renew maintenance, CoH usage
  - Verify: `luac -p`, gate, `test_priest_holy_*`

- [ ] **P6.2** Discipline — compare against Wowhead Disc Priest TBC guide
  - Files: `EaxRotations/classes/priest/discipline_sylvanas.lua`
  - Acceptance: PW:S priority, Penance (if Wrath-backported), Power Infusion
  - Verify: `luac -p`, gate, `test_discipline_*`

- [ ] **P6.3** Shadow — compare against Wowhead Shadow Priest TBC guide
  - Files: `EaxRotations/classes/priest/shadow_sylvanas.lua`
  - Acceptance: VT > SW:P > MB > MF priority, shadow weaving
  - Verify: `luac -p`, gate

- [ ] **P6.4** Smite — compare against Wowhead Holy DPS Priest TBC guide
  - Files: `EaxRotations/classes/priest/smite_sylvanas.lua`
  - Acceptance: Smite spam, Holy Fire, SW:P maintenance
  - Verify: `luac -p`, gate

### Phase 7: Warlock (3 specs)
- [ ] **P7.1** Affliction — compare against Wowhead Affliction Warlock TBC guide
  - Files: `EaxRotations/classes/warlock/affliction_sylvanas.lua`
  - Acceptance: UA > Corruption > CoA > Siphon Life > Drain Life priority
  - Verify: `luac -p`, gate, `test_affliction_*`

- [ ] **P7.2** Demonology — compare against Wowhead Demonology Warlock TBC guide
  - Files: `EaxRotations/classes/warlock/demonology_sylvanas.lua`
  - Acceptance: Shadowbolt filler, demon form (if Wrath-backported), pet management
  - Verify: `luac -p`, gate

- [ ] **P7.3** Destruction — compare against Wowhead Destruction Warlock TBC guide
  - Files: `EaxRotations/classes/warlock/destruction_sylvanas.lua`
  - Acceptance: Immolate > Incinerate/Shadowbolt, Conflagrate, curse priority
  - Verify: `luac -p`, gate, `test_destruction_*`

### Phase 8: Druid (4 specs)
- [ ] **P8.1** Balance — compare against Wowhead Boomkin TBC guide
  - Files: `EaxRotations/classes/druid/balance_sylvanas.lua`
  - Acceptance: Moonfire > Starfire > Wrath, insect swarm, eclipse (if Wrath-backported)
  - Verify: `luac -p`, gate, `test_balance_*`

- [ ] **P8.2** Feral Cat — compare against Wowhead Feral Cat TBC guide
  - Files: `EaxRotations/classes/druid/cat_sylvanas.lua`
  - Acceptance: Mangle > Rip > Rake > Ferocious Bite, SR cycle, powershifting
  - Verify: `luac -p`, gate, `test_cat_*`

- [ ] **P8.3** Feral Bear — compare against Wowhead Feral Bear TBC guide
  - Files: `EaxRotations/classes/druid/bear_sylvanas.lua`
  - Acceptance: Mangle > Lacerate > Swipe, demo roar, survival priorities
  - Verify: `luac -p`, gate, `test_bear_*`

- [ ] **P8.4** Restoration — compare against Wowhead Resto Druid TBC guide
  - Files: `EaxRotations/classes/druid/resto_sylvanas.lua`
  - Acceptance: Lifebloom stacking, Rejuvenation, Regrowth, Swiftmend
  - Verify: `luac -p`, gate, `test_druid_resto_*`

### Phase 9: Shaman (3 specs)
- [ ] **P9.1** Elemental — compare against Wowhead Elemental Shaman TBC guide
  - Files: `EaxRotations/classes/shaman/elemental_sylvanas.lua`
  - Acceptance: Lightning Bolt > Chain Lightning, Flame Shock, totem management
  - Verify: `luac -p`, gate, `test_elemental_*`

- [ ] **P9.2** Enhancement — compare against Wowhead Enhancement Shaman TBC guide
  - Files: `EaxRotations/classes/shaman/enhancement_sylvanas.lua`
  - Acceptance: Stormstrike > Earth Shock > Flame Shock, totem twisting, WF/FT
  - Verify: `luac -p`, gate

- [ ] **P9.3** Restoration — compare against Wowhead Resto Shaman TBC guide
  - Files: `EaxRotations/classes/shaman/restoration_sylvanas.lua`
  - Acceptance: Healing Wave rank selection, Chain Heal, Earth Shield, Riptide (if Wrath)
  - Verify: `luac -p`, gate, `test_shaman_resto_*`

### Phase 10: Vanilla Variants (Lower Priority)
- [ ] **P10.1** Audit all `_vanilla.lua` specs for Vanilla Anniversary correctness
  - Files: All `*_vanilla.lua` files
  - Acceptance: Spell ranks appropriate for Vanilla 1.15.x, no TBC-only spells
  - Verify: `luac -p`, gate

### Phase 11: Final Validation
- [ ] **P11.1** Full gate run: `validate.cmd` → ALL CHECKS PASSED
- [ ] **P11.2** Spell audit: all referenced spell IDs exist in DBC
- [ ] **P11.3** Update README with any spec list changes

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Guide data is for 2.4.3, not 2.5.5 Anniversary | Wrong priorities | Cross-check against DBC (`wowheadScrape/dbc_extract/wowsims.db`) for spell existence |
| Wrath-backported spells confuse guide vs reality | Missing valid spells | DBC is authoritative; keep Wrath-backported spells if in DB |
| Changing strategy order breaks existing tests | Regression | Run full gate after every spec change |
| Over-optimization for raid vs solo/5-man | Wrong behavior in context | Verify context.is_group / is_raid gates |
| User preference differs from guide | Wrong "feel" | All changes opt-out via menu settings |

## References

- **Internal clones** (read-only, NOT committed): `tbc-main/`, `tbc-new/`, `Sonah/`, `HealPredict/`, `LibHealComm-4.0.lua`
- **Spell verification**: `wowheadScrape/dbc_extract/wowsims.db` (SQLite), `lexxer.org/api/v1/spells/{id}?game=tbc`
- **AGENTS.md**: Pattern 10 (spec structure), Pattern 14 (nil-guards), Pattern 15 (headers)
- **Test gate**: `validate.cmd` (Lua 5.1)
