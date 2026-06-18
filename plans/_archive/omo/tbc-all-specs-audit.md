# TBC Anniversary — All 30 Specs Deep Dive Audit

## TL;DR

> **Quick Summary**: Comprehensive audit of all 30 TBC Classic Anniversary specialization rotations in EaxRotations against current online guides and TBC 2.5.x mechanics. Identifies gaps, missing features, and optimization opportunities across every spec.
>
> **Deliverables**:
> - Per-spec gap analysis (code vs. online research)
> - P0 fix: Mage source files completely missing
> - Rotation logic corrections for each spec
> - Test coverage expansion
> - Spell DBC verification pass
>
> **Estimated Effort**: XL (50+ tasks across 30 specs)
> **Parallel Execution**: YES — 10 waves (9 implementation + 1 final review)
> **Critical Path**: Mage (P0) → DPS specs → Healer specs → Tank specs → Integration testing

---

## Context

### Original Request
Create a deep-dive todo list for all classes and specs, verified against online TBC Anniversary / TBC Classic 2.5.x / 2.4.x research.

### ⚠️ Premise Correction (Before Wave 1 Tasks)
Initial research flagged Mage spec files as missing, but `EaxRotations/classes/mage/` actually contains:
- `arcane_sylvanas.lua`, `fire_sylvanas.lua`, `frost_sylvanas.lua`
- `class_sylvanas.lua`, `middleware_sylvanas.lua`, `schema_sylvanas.lua`

**Wave 1 (Tasks 1-4) therefore pivot from "Create" to "Audit existing Mage spec files"** for TBC Anniversary accuracy. Same end goal — verify rotations match 2026 mechanics.

### Interview Summary / Research Findings

**Codebase Catalog** (48 spec files found):
| Class | TBC Specs | Vanilla Specs | Test Files |
|-------|-----------|---------------|------------|
| Druid | 5 (balance, bear, cat, caster, resto) | 5 | 3 |
| Hunter | 3 (BM, MM, Survival) | 3 | 0 |
| Mage | 3 (arcane, fire, frost — all exist) | 0 | 3 |
| Paladin | 3 (holy, prot, ret) | 3 | 1 |
| Priest | 4 (disc, holy, shadow, smite) | 4 | 3 |
| Rogue | 3 (assassination, combat, subtlety) | 3 | 3 |
| Shaman | 3 (elemental, enhance, resto) | 3 | 2 |
| Warlock | 3 (affliction, demonology, destruction) | 3 | 2 |
| Warrior | 3 (arms, fury, prot) | 3 | 2 |
| **TOTAL** | **30 TBC specs** | **18 Vanilla** | **21 test files** |

**Note**: Mage spec files were initially flagged as missing but were found to exist (`EaxRotations/classes/mage/arcane_sylvanas.lua`, `fire_sylvanas.lua`, `frost_sylvanas.lua`, plus `class_sylvanas.lua`, `middleware_sylvanas.lua`, `schema_sylvanas.lua`). Wave 1 tasks audit these for TBC Anniversary accuracy rather than creating from scratch.

**Online Research** (2026 TBC Anniversary guides):
- Comprehensive rotation guides gathered for all 9 classes, all 30 specs
- TBC Anniversary runs on its **own 2.5.5.x client** — NOT Wrath 3.3.5. Some Wrath-era spells were backported (Ice Lance 30455, Seal of Blood 31892, Seal of Martyr 348700) and ARE valid. Always verify against DBC + lexxer.org
- Key TBC Anniversary hotfixes (June 10, 2026): Restoration Shaman mana cost -5%, Holy Priest -8%, Elemental PvP adjustments
- Armor value bug hotfixed (Feb 2026), Precision talent display issue (visual only)
- Hunter 1-button macros broken on modern client
- Seal Twisting is the defining Ret Paladin skill
- Powershifting is mandatory for Feral Cat DPS
- Totem Twisting for Enhancement Shaman

### Spec File Size Profile

| Size | Count | Specs |
|------|-------|-------|
| **XL** (>800 lines) | 7 | enhancement_sylvanas (1057), prot_warrior (932), affliction (926), bear (839), fury (836), cat (825), BM (793) |
| **L** (600-800) | 6 | arms_warrior (719), shadow (704), disc (688), holy_paladin (854), holy_priest (854), resto_druid (518) |
| **M** (400-600) | 18 | remaining specs |
| **S** (<400) | 6 | balance (415), MM (398), survival (493), destruction (421), demo (408), smite (478) |

---

## Work Objectives

### Core Objective
Audit ALL 30 TBC spec rotation files against 2026 online rotation guides, fix discrepancies, and ensure Mage specs exist.

### Concrete Deliverables
- 3 Mage spec files created: `arcane_sylvanas.lua`, `fire_sylvanas.lua`, `frost_sylvanas.lua`
- 27 existing TBC spec files reviewed for rotation accuracy
- Spell DBC verification pass (verify all spell IDs against `wowheadScrape/dbc_extract/wowsims.db`)
- Test coverage expanded for untested specs
- All 30 specs pass `lua EaxRotations/tests/run_rotation_tests.lua`

### Definition of Done
- [ ] `luac -p` passes on every modified file
- [ ] `lua EaxRotations/tests/run_rotation_tests.lua` — all suites pass
- [ ] `lua EaxRotations/tests/run_leveling_tests.lua` — all suites pass
- [ ] Mage spec files exist and are functional

### Must Have
- Mage source files (Arcane, Fire, Frost) — highest priority
- Rotation logic matches TBC Anniversary mechanics
- Spell IDs verified against DBC
- Nil-guarded menu references
- Squared distance comparisons
- Static table reuse

### Must NOT Have (Guardrails)
- No removing spells because they "look WotLK" — verify against DBC first
- No external platform APIs (Project Sylvanas only)
- No `ffi.C`, `io.popen`, `os.execute`, `debug.*`
- No `math.sqrt()` for distance comparisons
- No garbage creation in tight loops
- No un-nil-guarded menu references

### Spec Framework Integration
- **Detected Framework**: None (no `openspec/` or `.specify/` directories)
- Rotation engine uses `NS.rotation_registry:register()` pattern

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (`lua EaxRotations/tests/run_rotation_tests.lua`)
- **Automated tests**: Tests-after (tests exist; expand coverage)
- **Framework**: Lua test harness with custom match assertions

### QA Policy
Every task includes agent-executed QA:
- **Backend (Lua)**: `luac -p` for syntax, test runner for logic
- **Evidence**: Test output captured to `.omo/evidence/task-{N}-*.txt`

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 — Mage audit (P0 — verify existing spec files):
├── Task 1-4: Audit arcane, fire, frost + class infrastructure

Wave 2 — Warrior + Rogue (melee DPS):
├── Task 5-8: arms, fury, prot, assassination

Wave 3 — Rogue + Hunter:
├── Task 9-12: combat, subtlety, BM, MM

Wave 4 — Hunter + Warlock:
├── Task 13-16: SV, affliction, demonology, destruction

Wave 5 — Priest:
├── Task 17-20: disc, holy, shadow, smite

Wave 6 — Paladin:
├── Task 21-23: holy, prot, ret

Wave 7 — Shaman + Druid:
├── Task 24-27: elemental, enhance, resto-shaman, balance

Wave 8 — Druid:
├── Task 28-31: bear, cat, resto-druid, caster

Wave 9 — Integration + Tests:
├── Task 32-35: test expansion, spell audit, rotation + leveling suites

Wave FINAL (4 parallel reviews → user okay):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
→ Present results → Get explicit user okay

Critical Path: Task 1 → Task 5 → Task 9 → Task 13 → Task 17 → Task 21 → Task 24 → Task 28 → Task 32 → F1-F4
Parallel Speedup: ~85% faster than sequential (max 4 concurrent per wave)
```

---

## TODOs

- [ ] 1. **Audit/create arcane_sylvanas.lua** — Verify vs. TBC Anniversary Arcane Mage research

  **What to do**:
  - Read existing `EaxRotations/classes/mage/arcane_sylvanas.lua` (file exists)
  - Audit rotation against 2026 TBC Anniversary Arcane Mage research
  - Verify Arcane Blast spam rotation with Frostbolt filler regen phases
  - Arcane Power + Icy Veins + Presence of Mind cooldown alignment
  - Mana management: Evocation, Mana Emerald, Mage Armor
  - Arcane Blast debuff trick (cast fast at base cost when debuff expiring)
  - Build state: mana_percentage, arcane_blast_stacks, arcane_power_active
  - Match functions: ArcaneBurn, ArcaneFiller, ArcaneCooldowns

  **Must NOT do**: Don't use math.sqrt(); nil-guard all menu refs; no garbage in on_update

  **Recommended Agent Profile**: `unspecified-high` + [`test-driven-development`, `code-review-and-quality`]

  **Parallelization**: Wave 1 with Tasks 2, 3, 4 | Blocks: Wave 3+ | Blocked By: None

  **References**: `affliction_sylvanas.lua` (resource mgmt), `AGENTS.md` Pattern 10, `api/core.lua`

  **Acceptance Criteria**: `luac -p` PASS; mana_pct + AB stacks in build_state

  **QA Scenarios**:
  ```
  S1 (Happy): 100% mana → Arcane Blast (spell 30451) cast. Evidence: .omo/evidence/task-1-arcane-blast.txt
  S2 (Edge): 20% mana → Frostbolt (spell 25304) filler. Evidence: .omo/evidence/task-1-frostbolt-filler.txt
  ```

  **Commit**: `fix(mage): audit arcane rotation for TBC Anniversary accuracy`

---

- [ ] 2. **Audit/create fire_sylvanas.lua** — Verify vs. TBC Anniversary Fire Mage research

  **What to do**:
  - Read existing `EaxRotations/classes/mage/fire_sylvanas.lua` (file exists)
  - Audit rotation against 2026 TBC Anniversary Fire Mage research
  - Scorch 5-stack maintenance → Fireball spam rotation
  - Combustion + Icy Veins cooldown alignment
  - Molten Fury execute phase (talent: +20% damage to targets at ≤20% HP — verify threshold)
  - NOTE: Hot Streak is WotLK (not TBC) — do not implement proc handling for it

  **Must NOT do**: No Fire Blast in stationary rotation (mana waste); no Consecration (cross-class error)

  **Recommended Agent Profile**: `unspecified-high` + [`test-driven-development`, `code-review-and-quality`]

  **Parallelization**: Wave 1 with Tasks 1, 3, 4 | Blocks: Wave 3+ | Blocked By: None

  **References**: `destruction_sylvanas.lua` (fire pattern), `shadow_sylvanas.lua` (debuff tracking), DBC for spell IDs

  **Acceptance Criteria**: `luac -p` PASS; Scorch stack tracking; Execute phase logic

  **QA Scenarios**:
  ```
  S1 (Happy): Scorch stacks=3 → cast Scorch. Evidence: .omo/evidence/task-2-scorch-maintain.txt
  S2 (Happy): Scorch stacks=5 → cast Fireball. Evidence: .omo/evidence/task-2-fireball-spam.txt
  S3 (Edge): Target HP ≤ 20% → Molten Fury execute logic. Evidence: .omo/evidence/task-2-execute.txt
  ```

  **Commit**: `fix(mage): audit fire rotation for TBC Anniversary accuracy`

---

- [ ] 3. **Audit/create frost_sylvanas.lua** — Verify vs. TBC Anniversary Frost Mage research

  **What to do**:
  - Read existing `EaxRotations/classes/mage/frost_sylvanas.lua` (file exists)
  - Audit rotation against 2026 TBC Anniversary Frost Mage research
  - Verify Frostbolt spam with Winter's Chill 5-stack tracking
  - Water Elemental pet management (summon on CD, keep alive)
  - Icy Veins + Cold Snap double-cooldown usage
  - Frostbolt filler with Cold Snap + Icy Veins cooldown usage
  - AoE: Blizzard with Frost Nova kiting
- Build state: winters_chill_stacks, water_elemental_active

**Must NOT do**: Don't let Water Elemental sit unused

  **Recommended Agent Profile**: `unspecified-high` + [`test-driven-development`, `code-review-and-quality`]

  **Parallelization**: Wave 1 with Tasks 1, 2, 4 | Blocks: Wave 3+ | Blocked By: None

  **References**: `beast_mastery_sylvanas.lua` (pet pattern), `kebab_sylvanas.lua` (spell IDs), DBC

  **Acceptance Criteria**: `luac -p` PASS; Winter's Chill tracking; Water Elemental summon logic

  **QA Scenarios**:
  ```
  S1 (Happy): Water Elemental available → summon (spell 31687). Evidence: .omo/evidence/task-3-water-elemental.txt
  S2 (Edge): Icy Veins on CD + Cold Snap available → reset. Evidence: .omo/evidence/task-3-cold-snap.txt
  S3 (Edge): Icy Veins on CD + Cold Snap available → reset. Evidence: .omo/evidence/task-3-cold-snap.txt
  ```

  **Commit**: `fix(mage): audit frost rotation for TBC Anniversary accuracy`

---

- [ ] 4. **Audit/create Mage class infrastructure** — class, middleware, schema, dispatcher

  **What to do**:
  - Read existing Mage infrastructure files (all exist: `class_sylvanas.lua`, `middleware_sylvanas.lua`, `schema_sylvanas.lua`)
  - Audit against TBC Anniversary requirements
  - Ensure `main_sylvanas.lua` dispatcher loads all three Mage specs correctly
  - Register arcane, fire, frost in rotation registry

  **Must NOT do**: Don't skip class registration — specs won't load without it

  **Recommended Agent Profile**: `quick` + [`code-review-and-quality`]

  **Parallelization**: Wave 1 with Tasks 1, 2, 3 | Blocks: Wave 3+ | Blocked By: None

  **References**: `warlock/class_sylvanas.lua`, `priest/class_sylvanas.lua`, `main_sylvanas.lua`

  **Acceptance Criteria**: `luac -p` on all Mage files PASS; dispatcher loads Mage specs

  **QA Scenarios**:
  ```
  S1: lua -e "require('classes/mage/class_sylvanas')" → no error. Evidence: .omo/evidence/task-4-registration.txt
  ```

  **Commit**: `fix(mage): audit Mage class infrastructure for TBC Anniversary`

---

- [ ] 5. **Audit arms_sylvanas.lua** — Verify vs. TBC Anniversary Arms Warrior research

  **What to do**:
  - Read current `arms_sylvanas.lua` (719 lines)
  - Compare rotation priority vs. research: Mortal Strike → Overpower → Whirlwind → Slam
  - Verify Blood Frenzy (4% phys debuff) is properly maintained
  - Verify Execute phase (standard Warrior mechanic: available at ≤20% HP per Execute spell)
  - Verify Sweeping Strikes + Whirlwind AoE combo
  - Check rage management: Heroic Strike dump to prevent capping (standard Warrior rage economy per Battle Shout/Rampage uptime cycles)
  - Check for nil-guarded `state.rage` comparisons (Pattern 14)
  - Cross-reference spell IDs against `wowheadScrape/dbc_extract/wowsims.db`

  **Must NOT do**: Don't change working logic without test validation first

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 2 with Tasks 6-8 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_arms_custom_matches.lua`, DBC spell IDs, AGENTS.md Pattern 14

  **Acceptance Criteria**: Rotation matches research priority; all spell IDs verified; rage nil-guards present

  **QA Scenarios**:
  ```
  S1: Test suite PASS — lua EaxRotations/tests/run_rotation_tests.lua arms. Evidence: .omo/evidence/task-5-arms-tests.txt
  S2: luac -p arms_sylvanas.lua → 0 errors. Evidence: .omo/evidence/task-5-arms-luac.txt
  ```

  **Commit**: `fix(warrior): verify arms rotation matches TBC Anniversary guides`

---

- [ ] 6. **Audit fury_sylvanas.lua** — Verify vs. TBC Anniversary Fury Warrior research

  **What to do**:
  - Read current `fury_sylvanas.lua` (836 lines)
  - Verify BT → WW → Slam priority with Heroic Strike rage dump
  - Check Death Wish + Recklessness cooldown alignment
  - Verify Execute phase logic (standard Warrior Execute: ≤20% HP per spell requirement)
  - Check Rampage stack maintenance (5 stacks)
  - Verify rage capping prevention (HS dump per standard fury rage economy)
  - Check for nil-guarded state comparisons
  - Cross-reference spell IDs against DBC
  - Verify auto-charge logic

  **Must NOT do**: Don't remove spells flagged as "WotLK" without DBC verification

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 2 with Tasks 5, 7, 8 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_fury_custom_matches.lua`, DBC

  **Acceptance Criteria**: BT/WW priority verified; Rampage tracking correct; rage threshold accurate

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-6-fury-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-6-fury-luac.txt
  ```

  **Commit**: `fix(warrior): verify fury rotation matches TBC Anniversary guides`

---

- [ ] 7. **Audit protection_sylvanas.lua (Warrior)** — Verify vs. TBC Anniversary Prot Warrior research

  **What to do**:
  - Read current `protection_sylvanas.lua` (932 lines)
  - Verify Shield Block → Shield Slam → Revenge → Devastate priority
  - Check stance dancing (Battle Charge, Defensive tanking, Berserker fear immunity)
  - Verify Thunder Clap + Demoralizing Shout debuff maintenance
  - Check Shield Wall + Last Stand emergency cooldown staggering
  - Verify uncrushable logic (Shield Block uptime)
  - Cross-reference spell IDs against DBC

  **Must NOT do**: Don't change tank threat coefficients without test validation

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 2 with Tasks 5, 6, 8 | Blocks: Wave FINAL | Blocked By: None

  **References**: DBC spell IDs, tank theorycraft sources

  **Acceptance Criteria**: Shield Block priority correct; stance dancing verified; debuff maintenance correct

  **QA Scenarios**:
  ```
  S1: luac -p → 0 errors. Evidence: .omo/evidence/task-7-prot-luac.txt
  S2: Spell ID grep → all IDs exist in DBC. Evidence: .omo/evidence/task-7-spell-ids.txt
  ```

  **Commit**: `fix(warrior): verify prot rotation matches TBC Anniversary guides`

---

- [ ] 8. **Audit assassination_sylvanas.lua** — Verify vs. TBC Anniversary Assassination Rogue research

  **What to do**:
  - Read current `assassination_sylvanas.lua` (595 lines)
  - Verify Mutilate CP building + Envenom/Rupture finisher priority
  - Check Slice and Dice mandatory uptime
  - Verify Deadly Poison maintenance
  - Check Cold Blood + finisher alignment
  - Verify energy pooling (avoid capping at 100, pool for finishers per standard TBC Rogue energy tick mechanics)
  - Check nil-guards on state.combo_points, state.energy

  **Must NOT do**: Don't modify poison interaction mechanics without DBC verification

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 2 with Tasks 5-7 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_assassination_custom_matches.lua`, DBC

  **Acceptance Criteria**: SnD uptime logic correct; Mutilate priority correct; energy pooling verified

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-8-assassination-tests.txt
  ```

  **Commit**: `fix(rogue): verify assassination rotation matches TBC Anniversary guides`

---

- [ ] 9. **Audit combat_sylvanas.lua** — Verify vs. TBC Anniversary Combat Rogue research

  **What to do**:
  - Read current `combat_sylvanas.lua` (488 lines)
  - Verify SS → SnD → Rupture/Eviscerate priority
  - Check Blade Flurry + Adrenaline Rush alignment
  - Verify Expose Armor at 5 CP (long fights)
  - Check energy pooling with Relentless Strikes refund awareness
  - Verify AoE: BF + SS spam

  **Must NOT do**: Don't change finisher priority without test validation

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 3 with Tasks 10-12 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_combat_custom_matches.lua`, DBC

  **Acceptance Criteria**: SnD priority #1; BF+AR aligned; Expose Armor at 5 CP

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-9-combat-tests.txt
  ```

  **Commit**: `fix(rogue): verify combat rotation matches TBC Anniversary guides`

---

- [ ] 10. **Audit subtlety_sylvanas.lua** — Verify vs. TBC Anniversary Subtlety Rogue research

  **What to do**:
  - Read current `subtlety_sylvanas.lua` (521 lines)
  - Verify Hemorrhage CP building + Rupture/Eviscerate
  - Check Shadowstep burst window alignment
  - Verify Premeditation + Cheap Shot opener
  - Note: Subtlety is PvP-focused, not competitive PvE — verify this is documented
  - Check Preparation double reset logic

  **Must NOT do**: Don't refactor as PvE spec — Subtlety is primarily PvP

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 3 with Tasks 9, 11, 12 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_subtlety_vanilla_nil_guards.lua`, DBC

  **Acceptance Criteria**: Shadowstep logic correct; PvP focus verified; Preparation reset correct

  **QA Scenarios**:
  ```
  S1: luac -p → 0 errors. Evidence: .omo/evidence/task-10-subtlety-luac.txt
  ```

  **Commit**: `fix(rogue): verify subtlety rotation matches TBC Anniversary guides`

---

- [ ] 11. **Audit beast_mastery_sylvanas.lua** — Verify vs. TBC Anniversary BM Hunter research

  **What to do**:
  - Read current `beast_mastery_sylvanas.lua` (793 lines)
  - Verify 1:1 / 1:1.5 Steady Shot weaving based on weapon speed
  - Check Kill Command off-GCD usage on crit procs
  - Verify Bestial Wrath + Rapid Fire alignment
  - Check pet management: Happy pet (Furious Howl), Mend Pet instant cast
  - Verify Aspect switching (Hawk default, Viper when mana low)
  - Check Misdirection pre-pull logic
  - CRITICAL: 1-button macro does NOT work on modern client — verify rotation is manual
  - Verify no Aimed Shot in sustained rotation (resets Auto Shot)
  - Cross-reference spell IDs against DBC

  **Must NOT do**: Don't rely on old macro behavior; don't clip Auto Shot

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 3 with Tasks 9, 10, 12 | Blocks: Wave FINAL | Blocked By: None

  **References**: `beast_mastery_vanilla.lua`, DBC, Hunter swing timer theory

  **Acceptance Criteria**: Steady Shot weave correct; Kill Command off-GCD; pet management verified

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-11-bm-hunter-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-11-bm-hunter-luac.txt
  ```

  **Commit**: `fix(hunter): verify BM rotation matches TBC Anniversary guides`

---

- [ ] 12. **Audit marksmanship_sylvanas.lua** — Verify vs. TBC Anniversary MM Hunter research

  **What to do**:
  - Read current `marksmanship_sylvanas.lua` (398 lines)
  - Verify Trueshot Aura is enabled and maintained
  - Check Silencing Shot usage for interrupts
  - Verify same Steady Shot weave as BM
  - Check Aimed Shot only on opener (not sustained rotation)
  - Verify pet management (Ravager preferred)

  **Must NOT do**: Don't use Aimed Shot in sustained rotation

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 3 with Tasks 9-11 | Blocks: Wave FINAL | Blocked By: None

  **References**: `beast_mastery_sylvanas.lua` (shared weave pattern), `marksmanship_vanilla.lua`

  **Acceptance Criteria**: Trueshot Aura active; Aimed Shot opener-only; weave correct

  **QA Scenarios**:
  ```
  S1: luac -p → 0 errors. Evidence: .omo/evidence/task-12-mm-hunter-luac.txt
  S2: Spell ID sweep → all valid in DBC. Evidence: .omo/evidence/task-12-mm-spells.txt
  ```

  **Commit**: `fix(hunter): verify MM rotation matches TBC Anniversary guides`

---

- [ ] 13. **Audit survival_sylvanas.lua** — Verify vs. TBC Anniversary SV Hunter research

  **What to do**:
  - Read current `survival_sylvanas.lua` (493 lines)
  - Verify Expose Weakness is the defining feature (25% Agility as party AP)
  - Check Readiness double cooldown usage
  - Verify Agility stacking emphasis (scales Expose Weakness)
  - Check trap timing and combat trap usage (2s delay in TBC Anniversary)
  - Cross-reference with BM/MM for shared weave logic

  **Must NOT do**: Don't compare SV personal DPS to BM — value is raid buff

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 4 with Tasks 14-16 | Blocks: Wave FINAL | Blocked By: None

  **References**: `beast_mastery_sylvanas.lua`, `survival_vanilla.lua`, Expose Weakness mechanics

  **Acceptance Criteria**: Expose Weakness logic present; Readiness usage correct; Agility priority evident

  **QA Scenarios**:
  ```
  S1: luac -p → 0 errors. Evidence: .omo/evidence/task-13-sv-hunter-luac.txt
  ```

  **Commit**: `fix(hunter): verify Survival rotation matches TBC Anniversary guides`

---

- [ ] 14. **Audit affliction_sylvanas.lua** — Verify vs. TBC Anniversary Affliction Warlock research

  **What to do**:
  - Read current `affliction_sylvanas.lua` (926 lines, 3rd largest spec)
  - Verify CoE → Corruption → Siphon Life → UA → Immolate → Shadow Bolt priority
  - CRITICAL: Do NOT clip DoTs — let them expire before refreshing
  - Check Malediction talent impact (+3% spell damage taken)
  - Verify hit cap awareness: Suppression gives 10% to Affliction spells
  - Check Life Tap mana management with safety gates
  - Verify Soul Shatter threat drop availability
  - Check Nightfall / Shadow Trance proc tracking
  - Verify Seed of Corruption AoE logic

  **Must NOT do**: Don't clip DoTs; don't Life Tap unsafely; don't overwrite Seed early

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 4 with Tasks 13, 15, 16 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_affliction_custom_matches.lua`, DBC, DoT pandemic mechanics

  **Acceptance Criteria**: DoT no-clip verified; CoE priority correct; hit cap awareness present

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-14-affliction-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-14-affliction-luac.txt
  ```

  **Commit**: `fix(warlock): verify affliction rotation matches TBC Anniversary guides`

---

- [ ] 15. **Audit demonology_sylvanas.lua** — Verify vs. TBC Anniversary Demonology Warlock research

  **What to do**:
  - Read current `demonology_sylvanas.lua` (408 lines)
  - Verify Felguard pet management (tanky, high damage, melee cleave)
  - Check Soul Link survivability transfer
  - Verify Demonic Sacrifice interaction (Sac Succubus for +15% shadow)
  - Check DoT maintenance (Corruption + Immolate)
  - Verify Death Coil + Howl of Terror utility
  - Cross-reference spell IDs against DBC

  **Must NOT do**: Don't let Felguard die — huge DPS loss

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 4 with Tasks 13, 14, 16 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_demonology_custom_matches.lua`, `beast_mastery_sylvanas.lua` (pet pattern), DBC

  **Acceptance Criteria**: Felguard logic present; Soul Link verified; Sacrifice interaction correct

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-15-demo-tests.txt
  ```

  **Commit**: `fix(warlock): verify demonology rotation matches TBC Anniversary guides`

---

- [ ] 16. **Audit destruction_sylvanas.lua** — Verify vs. TBC Anniversary Destruction Warlock research

  **What to do**:
  - Read current `destruction_sylvanas.lua` (421 lines)
  - Verify Curse → Immolate → Shadow Bolt / Incinerate priority
  - Check Soul Fire + Conflagrate burst alignment (note: Chaos Bolt is WotLK, not TBC)
  - Verify Ruin talent interaction (crits = 200% damage)
  - Check threat management (highest burst = highest threat)
  - Verify Seed of Corruption AoE
  - Cross-reference spell IDs against DBC

  **Must NOT do**: Don't cast Shadow Bolt after Incinerate when curse is applied

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 4 with Tasks 13-15 | Blocks: Wave FINAL | Blocked By: None

  **References**: `affliction_sylvanas.lua` (shared DoT pattern), DBC

  **Acceptance Criteria**: Incinerate > Shadow Bolt with curse; Conflagrate on CD; Ruin verified

  **QA Scenarios**:
  ```
  S1: luac -p → 0 errors. Evidence: .omo/evidence/task-16-destruction-luac.txt
  ```

  **Commit**: `fix(warlock): verify destruction rotation matches TBC Anniversary guides`

---

- [ ] 17. **Audit discipline_sylvanas.lua** — Verify vs. TBC Anniversary Disc Priest research

  **What to do**:
  - Read current `discipline_sylvanas.lua` (688 lines)
  - Verify PW:S shield as primary tool (absorb-based prevention)
  - Check Pain Suppression emergency tank cooldown
  - Verify Power Infusion coordination for caster DPS burn phases
  - Check Prayer of Mending + Circle of Healing usage
  - Verify dispel magic (offensive + defensive, best in game)
  - Check mana management (PW:S is mana-efficient)

  **Must NOT do**: Don't over-rely on shield over actual healing

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 5 with Tasks 18-20 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_discipline_custom_matches.lua`, `holy_sylvanas.lua` (priest), DBC

  **Acceptance Criteria**: PW:S priority correct; Pain Suppression logic present; PI coordination

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-17-disc-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-17-disc-luac.txt
  ```

  **Commit**: `fix(priest): verify discipline rotation matches TBC Anniversary guides`

---

- [ ] 18. **Audit holy_sylvanas.lua (Priest)** — Verify vs. TBC Anniversary Holy Priest research

  **What to do**:
  - Read current `holy_sylvanas.lua` (854 lines)
  - Verify standard TBC Holy Priest mechanics (Circle of Healing, Greater Heal downranking)
  - Verify Circle of Healing AoE priority (3+ injured)
  - Check Prayer of Mending cooldown usage
  - Verify Greater Heal downranking for efficiency
  - Check Renew HoT on tanks / predicted damage
  - Verify Binding Heal self+other logic

  **Must NOT do**: Don't spam CoH (mana expensive); don't skip downranking

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 5 with Tasks 17, 19, 20 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_priest_holy_custom_matches.lua`, June 2026 hotfix notes, DBC

  **Acceptance Criteria**: CoH priority correct; downranking present; standard TBC mana costs

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-18-holy-priest-tests.txt
  ```

  **Commit**: `fix(priest): verify holy rotation matches TBC Anniversary guides`

---

- [ ] 19. **Audit shadow_sylvanas.lua** — Verify vs. TBC Anniversary Shadow Priest research

  **What to do**:
  - Read current `shadow_sylvanas.lua` (704 lines)
  - Verify Mind Blast → VT → SW:P → SW:D → Mind Flay priority
  - Check DoT no-clip (let expire before refresh)
  - Verify Vampiric Touch mana return to party
  - Check Shadow Weaving 5-stack tracking
  - Verify Mind Flay channel clipping (interrupt after 2nd tick)
  - Check SW:D safety gate (survive backlash)
  - Verify Shadowfiend mana regen

  **Must NOT do**: Don't clip DoTs; don't SW:D unsafely; don't interrupt MF too early

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 5 with Tasks 17, 18, 20 | Blocks: Wave FINAL | Blocked By: None

  **References**: `affliction_sylvanas.lua` (DoT management pattern), DBC

  **Acceptance Criteria**: DoT no-clip verified; MF clipping correct; SW:D safety present

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-19-shadow-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-19-shadow-luac.txt
  ```

  **Commit**: `fix(priest): verify shadow rotation matches TBC Anniversary guides`

---

- [ ] 20. **Audit smite_sylvanas.lua** — Verify vs. TBC Anniversary Smite Priest research

  **What to do**:
  - Read current `smite_sylvanas.lua` (478 lines)
  - Verify Holy Fire → Smite → wand rotation (solo/leveling build)
  - Check Surge of Light proc consumption (free instant Smite / Flash Heal)
  - Verify SW:P application (if target lives >12s)
  - Check PW:S self-protection pre-pull
  - Note: Not competitive DPS in raids — verify documentation reflects this

  **Must NOT do**: Don't refactor as raid DPS spec — Smite is primarily solo/leveling

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 5 with Tasks 17-19 | Blocks: Wave FINAL | Blocked By: None

  **References**: `shadow_sylvanas.lua` (priest DPS pattern), DBC

  **Acceptance Criteria**: Surge of Light logic present; wand usage correct; solo focus clear

  **QA Scenarios**:
  ```
  S1: luac -p → 0 errors. Evidence: .omo/evidence/task-20-smite-luac.txt
  ```

  **Commit**: `fix(priest): verify smite rotation matches TBC Anniversary guides`

---

- [ ] 21. **Audit holy_sylvanas.lua (Paladin)** — Verify vs. TBC Anniversary Holy Paladin research

  **What to do**:
  - Read current `holy_sylvanas.lua` (854 lines)
  - Verify FoL filler → HL spike healing priority
  - Check downranked HL for Light's Grace buff maintenance (Light's Grace: 0.5s cast reduction, 15s duration — verify downrank strategy)
  - Verify Divine Illumination + Divine Favor proactive stacking
  - Check Illumination crit refund (60% mana returned)
  - Verify Holy Shock emergency-only usage (not rotation)
  - Check Lay on Hands nuclear option
  - Verify Seal of Wisdom melee for mana regen

  **Must NOT do**: Don't overuse HL max rank (mana drain); don't use HS as rotation spell

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 6 with Tasks 22, 23 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_paladin_holy_custom_matches.lua`, DBC

  **Acceptance Criteria**: FoL/HL priority correct; downranking present; Illumination refund verified

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-21-holy-paladin-tests.txt
  ```

  **Commit**: `fix(paladin): verify holy rotation matches TBC Anniversary guides`

---

- [ ] 22. **Audit protection_sylvanas.lua (Paladin)** — Verify vs. TBC Anniversary Prot Paladin research

  **What to do**:
  - Read current `protection_sylvanas.lua` (444 lines)
  - Verify Holy Shield → Consecration → Judgement → Seal priority
  - Check Righteous Fury mandatory uptime
  - Verify Avenging Wrath burst threat alignment
  - Check Spiritual Attunement mana return balance
  - Verify crush-capping logic (102.4% avoidance)
  - Check Avenger's Shield for pulls (not boss melee)
  - Verify Seal of Righteousness ↔ Wisdom swap for mana

  **Must NOT do**: Don't let Holy Shield drop; don't AS during boss melee; don't OOM mid-pull

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 6 with Tasks 21, 23 | Blocks: Wave FINAL | Blocked By: None

  **References**: `protection_sylvanas.lua` (Warrior — tank pattern reference), DBC

  **Acceptance Criteria**: HS priority #1; RF mandatory; mana management present; crush-cap aware

  **QA Scenarios**:
  ```
  S1: luac -p → 0 errors. Evidence: .omo/evidence/task-22-prot-paladin-luac.txt
  S2: Spell ID sweep → all valid in DBC. Evidence: .omo/evidence/task-22-prot-paladin-spells.txt
  ```

  **Commit**: `fix(paladin): verify prot rotation matches TBC Anniversary guides`

---

- [ ] 23. **Audit retribution_sylvanas.lua** — Verify vs. TBC Anniversary Ret Paladin research

  **What to do**:
  - Read current `retribution_sylvanas.lua` (599 lines)
  - CRITICAL: Verify Seal Twisting implementation (Seal of Blood ↔ Command)
  - Check Crusader Strike → Judgement → Seal maintain priority
  - Verify Judgement of the Crusader 3% crit debuff maintenance
  - Check Exorcism on Undead/Demon only
  - Verify Hammer of Wrath execute phase (standard Paladin mechanic: available at ≤20% HP)
  - Check Avenging Wrath cooldown alignment
  - Verify Forbearance awareness (60s lockout after AW / Divine Shield)
  - Check mana management (Consecration only if mana surplus)

  **Must NOT do**: Don't let JoC fall off (3% raid crit loss); don't spam Consecration

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 6 with Tasks 21, 22 | Blocks: Wave FINAL | Blocked By: None

  **References**: `warrior/fury_sylvanas.lua` (melee DPS pattern), Seal Twisting theorycraft, DBC

  **Acceptance Criteria**: Seal Twisting present; JoC debuff maintained; AW + Forbearance tracked

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-23-ret-paladin-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-23-ret-paladin-luac.txt
  ```

  **Commit**: `fix(paladin): verify ret rotation matches TBC Anniversary guides (Seal Twisting)`

---

- [ ] 24. **Audit elemental_sylvanas.lua** — Verify vs. TBC Anniversary Elemental Shaman research

  **What to do**:
  - Read current `elemental_sylvanas.lua` (507 lines)
  - Verify Bloodlust (30% haste, not 15%) and Elemental Mastery burst alignment
  - NOTE: Ascendance is Mists of Pandaria (not TBC) — ignore any Ascendance references in guides
  - Verify totem priority: Totem of Wrath → Wrath of Air → Mana Spring
  - Check CL → LB priority (3 LB + 1 CL or 4 LB + 1 CL based on mana)
  - Verify Fire Nova Totem AoE burst
  - Check Elemental Mastery guaranteed crit window
  - Verify Water Shield maintenance
  - Cross-reference spell IDs against DBC

  **Must NOT do**: Don't cast LB when it delays CL; don't forget totems; don't forget Water Shield

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 7 with Tasks 25-27 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_elemental_custom_matches.lua`, DBC, June 2026 hotfix notes

  **Acceptance Criteria**: Totem priority correct; CL/LB mana balance present; Water Shield tracked

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-24-elemental-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-24-elemental-luac.txt
  ```

  **Commit**: `fix(shaman): verify elemental rotation matches TBC Anniversary guides`

---

- [ ] 25. **Audit enhancement_sylvanas.lua** — Verify vs. TBC Anniversary Enhancement Shaman research

  **What to do**:
  - Read current `enhancement_sylvanas.lua` (1057 lines — LARGEST spec)
  - Verify Bloodlust (30% haste) and Shamanistic Rage alignment
  - NOTE: Maelstrom Weapon is WotLK (not TBC) — ignore any Maelstrom Weapon references
  - Verify Stormstrike → Flame Shock → Earth Shock priority
  - CRITICAL: Check Totem Twisting (Windfury ↔ Grace of Air)
  - Verify weapon imbue management (WF on both, slow MH preferred)
  - Check Fire Nova Totem AoE rotation
  - Verify Shamanistic Rage mana conversion
  - Check Searing Totem after Fire Nova

  **Must NOT do**: Don't let Flame Shock drop; don't use fast weapons; don't forget totem twisting

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 7 with Tasks 24, 26, 27 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_shaman_enhancement_self_heal.lua`, DBC, Totem Twisting theorycraft

  **Acceptance Criteria**: Stormstrike priority correct; Totem Twisting present; weapon speed logic

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-25-enhancement-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-25-enhancement-luac.txt
  ```

  **Commit**: `fix(shaman): verify enhancement rotation matches TBC Anniversary guides`

---

- [ ] 26. **Audit restoration_sylvanas.lua (Shaman)** — Verify vs. TBC Anniversary Resto Shaman research

  **What to do**:
  - Read current `restoration_sylvanas.lua` (586 lines)
  - Verify Earth Shield → Chain Heal → Healing Wave priority (NOTE: Riptide is WotLK, not TBC)
  - Check Chain Heal smart bounce (2+ injured, aim near clustered targets)
  - Verify Mana Tide Totem coordination
  - Check Nature's Swiftness emergency heal
  - Verify Healing Wave downranking

  **Must NOT do**: Don't let Earth Shield drop; don't waste Chain Heal on single target

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 7 with Tasks 24, 25, 27 | Blocks: Wave FINAL | Blocked By: None

  **References**: `holy_sylvanas.lua` (Paladin — healer pattern), DBC, June 2026 hotfix

  **Acceptance Criteria**: Earth Shield priority; Chain Heal multi-target logic; standard TBC mana costs

  **QA Scenarios**:
  ```
  S1: luac -p → 0 errors. Evidence: .omo/evidence/task-26-resto-shaman-luac.txt
  S2: Spell ID verification. Evidence: .omo/evidence/task-26-resto-shaman-spells.txt
  ```

  **Commit**: `fix(shaman): verify resto rotation matches TBC Anniversary guides`

---

- [ ] 27. **Audit balance_sylvanas.lua** — Verify vs. TBC Anniversary Balance Druid research

  **What to do**:
  - Read current `balance_sylvanas.lua` (415 lines)
  - Verify Faerie Fire → Moonfire → Force of Nature → Starfire priority
  - Check DoT no-clip (Moonfire, Insect Swarm — let expire)
  - Verify Hurricane AoE (4+ targets, Barkskin first)
  - Check Innervate smart targeting (healer class priority — Pattern 13)
  - Verify hit cap awareness (Balance of Power gives 4%)
  - Cross-reference spell IDs against DBC

  **Must NOT do**: Don't clip Moonfire; don't overcast DoTs when mana tight

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 7 with Tasks 24-26 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_balance_custom_matches.lua`, `resto_sylvanas.lua` (Innervate pattern), DBC

  **Acceptance Criteria**: DoT no-clip verified; Force of Nature on CD; Innervate targeting smart

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-27-balance-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-27-balance-luac.txt
  ```

  **Commit**: `fix(druid): verify balance rotation matches TBC Anniversary guides`

---

- [ ] 28. **Audit bear_sylvanas.lua** — Verify vs. TBC Anniversary Feral Bear research

  **What to do**:
  - Read current `bear_sylvanas.lua` (839 lines)
  - Verify Demoralizing Roar → FF → Mangle → Lacerate (5 stacks) → Maul dump priority
  - Check Swipe replaces Lacerate filler at high AP levels
  - Verify Maul off-GCD rage dump
  - Check uncrushable logic and stance dancing
  - Verify opener: pre-HoT → Bear → Enrage → Charge → Mangle
  - Check Frenzied Regeneration cooldown
  - Cross-reference spell IDs against DBC

  **Must NOT do**: Don't Barkskin while tanking (breaks form); don't Maul when rage is low

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 8 with Tasks 29-31 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_bear_custom_matches.lua`, `test_bear_vanilla_nil_guards.lua`, DBC

  **Acceptance Criteria**: Lacerate 5-stack logic; Swipe AP threshold; Maul rage dump correct

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-28-bear-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-28-bear-luac.txt
  ```

  **Commit**: `fix(druid): verify bear rotation matches TBC Anniversary guides`

---

- [ ] 29. **Audit cat_sylvanas.lua** — Verify vs. TBC Anniversary Feral Cat research

  **What to do**:
  - Read current `cat_sylvanas.lua` (825 lines)
  - CRITICAL: Verify Powershifting implementation (Furor + Wolfshead Helm energy recovery)
  - Verify Rip (4+ CP) → Bite (5 CP with Rip) → Mangle → Shred priority
  - Check Bite energy overflow (avoid high-energy bites per standard Feral Cat theorycraft)
  - Verify Omen of Clarity proc handling (use Shred, never Bite)
  - Check Mangle 30% bleed bonus maintenance
  - Verify energy pooling thresholds

  **Must NOT do**: Don't bite at high energy; don't waste OoC on Bite; don't let Mangle drop

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 8 with Tasks 28, 30, 31 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_cat_custom_matches.lua`, Powershifting theorycraft, DBC

  **Acceptance Criteria**: Powershifting present; Bite energy gate; OoC handling correct; Mangle uptime

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-29-cat-tests.txt
  S2: luac -p → 0 errors. Evidence: .omo/evidence/task-29-cat-luac.txt
  ```

  **Commit**: `fix(druid): verify cat rotation matches TBC Anniversary guides`

---

- [ ] 30. **Audit resto_sylvanas.lua (Druid)** — Verify vs. TBC Anniversary Resto Druid research

  **What to do**:
  - Read current `resto_sylvanas.lua` (518 lines)
  - Verify rolling Lifebloom (3 stacks, refresh before expiration)
  - Check Rejuvenation + Regrowth HoT maintenance
  - Verify Swiftmend burst (consume HoT for bonus)
  - Check Tree of Life form management
  - Verify Nature's Swiftness + HT emergency (exit Tree form)
  - Check Innervate targeting
  - Cross-reference spell IDs against DBC

  **Must NOT do**: Don't clip Lifebloom; don't forget to exit Tree for emergency heals

  **Recommended Agent Profile**: `deep` + [`code-review-and-quality`]

  **Parallelization**: Wave 8 with Tasks 28, 29, 31 | Blocks: Wave FINAL | Blocked By: None

  **References**: `restoration_sylvanas.lua` (Shaman — healer pattern), DBC

  **Acceptance Criteria**: Rolling Lifebloom logic; Tree form management; Swiftmend burst present

  **QA Scenarios**:
  ```
  S1: luac -p → 0 errors. Evidence: .omo/evidence/task-30-resto-druid-luac.txt
  ```

  **Commit**: `fix(druid): verify resto rotation matches TBC Anniversary guides`

---

- [ ] 31. **Audit caster_sylvanas.lua (Druid)** — Verify vs. TBC Anniversary Caster Druid research

  **What to do**:
  - Read current `caster_sylvanas.lua` (135 lines — smallest spec)
  - Verify Faerie Fire → Moonfire → Wrath simplified rotation
  - Check Innervate, Barkskin, Thorns usage
  - Note: Simplified caster DPS for non-Balance druids
  - Verify no overlap with full Balance spec rotation

  **Must NOT do**: Don't duplicate full Balance logic — this is simplified DPS

  **Recommended Agent Profile**: `quick` + [`code-review-and-quality`]

  **Parallelization**: Wave 8 with Tasks 28-30 | Blocks: Wave FINAL | Blocked By: None

  **References**: `test_druid_caster_custom_matches.lua`, `balance_sylvanas.lua`, DBC

  **Acceptance Criteria**: Simplified rotation correct; no Balance duplication; spell IDs valid

  **QA Scenarios**:
  ```
  S1: Test suite PASS. Evidence: .omo/evidence/task-31-caster-tests.txt
  ```

  **Commit**: `fix(druid): verify caster rotation matches TBC Anniversary guides`

---

- [ ] 32. **Expand test coverage** — Add tests for untested specs

  **What to do**:
  - Identify specs without test coverage (see catalog: ~half lack tests)
  - Priority: Mage (new), Hunter (BM, MM, SV), Warlock (destruction), Priest (shadow, smite), Rogue (subtlety PvE), Warrior (prot), Paladin (prot, ret), Shaman (resto), Druid (resto)
  - Create `test_{spec}_custom_matches.lua` files following existing patterns
  - Each test: verify rotation outputs expected spells at correct priority
  - Verify nil-guards on state fields (Pattern 14)
  - Target: at least 1 test file per spec

  **Must NOT do**: Don't create tests that depend on specific gear/stats (use static test state)

  **Recommended Agent Profile**: `deep` + [`test-driven-development`]

  **Parallelization**: Wave 9 with Tasks 33-35 | Blocks: Wave FINAL | Blocked By: Tasks 1-31

  **References**: `test_affliction_custom_matches.lua`, `test_balance_custom_matches.lua` (patterns)

  **Acceptance Criteria**: New test files exist; all pass; coverage expanded to all 30 TBC specs

  **QA Scenarios**:
  ```
  S1: lua EaxRotations/tests/run_rotation_tests.lua → ALL PASS. Evidence: .omo/evidence/task-32-test-expansion.txt
  ```

  **Commit**: `test: expand coverage for untested specs`

---

- [ ] 33. **Spell ID cross-reference** — Verify all spell IDs against DBC

  **What to do**:
  - Extract all numeric spell IDs from ALL 30 TBC spec files
  - Cross-reference against `wowheadScrape/dbc_extract/wowsims.db`
  - Flag any IDs not found in DBC
  - Verify spell IDs for "WotLK-looking" spells (Victory Rush, Spellsteal, etc.)
  - Run `lua EaxRotations/tests/run_sylvanas_audit_tests.lua`
  - Document any missing/invalid IDs

  **Must NOT do**: Don't remove spells without DBC confirmation — TBC Anniversary runs on Wrath client

  **Recommended Agent Profile**: `deep`

  **Parallelization**: Wave 9 with Tasks 32, 34, 35 | Blocks: Wave FINAL | Blocked By: Tasks 1-31

  **References**: `wowheadScrape/dbc_extract/wowsims.db`, `wowhead_data/spells/tbc/*.json`

  **Acceptance Criteria**: All spell IDs verified; audit test PASS; flagged IDs documented

  **QA Scenarios**:
  ```
  S1: lua EaxRotations/tests/run_sylvanas_audit_tests.lua → PASS. Evidence: .omo/evidence/task-33-spell-audit.txt
  ```

  **Commit**: `fix: spell ID verification against DBC for all 30 specs`

---

- [ ] 34. **Full rotation test suite** — Run all rotation tests with fixes applied

  **What to do**:
  - After all spec audits complete, run `lua EaxRotations/tests/run_rotation_tests.lua`
  - Fix any failures
  - Document passing state
  - Capture test output as evidence

  **Must NOT do**: Don't skip failures — every test must pass

  **Recommended Agent Profile**: `quick` + [`debugging-and-error-recovery`]

  **Parallelization**: Wave 9 with Tasks 32, 33, 35 | Blocks: Wave FINAL | Blocked By: Tasks 1-33

  **Acceptance Criteria**: All rotation tests PASS (0 failures)

  **QA Scenarios**:
  ```
  S1: Full suite PASS. Evidence: .omo/evidence/task-34-rotation-tests.txt
  ```

  **Commit**: `test: full rotation test suite verification`

---

- [ ] 35. **Full leveling test suite** — Run all leveling tests

  **What to do**:
  - Run `lua EaxRotations/tests/run_leveling_tests.lua`
  - Fix any failures
  - Verify leveling rotations unaffected by spec changes

  **Must NOT do**: Don't skip — leveling tests are part of the contract

  **Recommended Agent Profile**: `quick` + [`debugging-and-error-recovery`]

  **Parallelization**: Wave 9 with Tasks 32-34 | Blocks: Wave FINAL | Blocked By: Tasks 1-34

  **Acceptance Criteria**: All leveling tests PASS (0 failures)

  **QA Scenarios**:
  ```
  S1: Full suite PASS. Evidence: .omo/evidence/task-35-leveling-tests.txt
  ```

  **Commit**: `test: full leveling test suite verification`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
>
> **Do NOT auto-proceed after verification. Wait for user's explicit approval.**
> **Never mark F1-F4 as checked before getting user's okay.**

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists. For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files in .omo/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [35/35] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `luac -p` on ALL modified files. Run the build, lint, and test commands from Success Criteria. Review all changed files for: type suppression, empty catches, debug logging, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic variable names. Check AGENTS.md patterns compliance.
  Output: `luac -p [N/N PASS] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` + `debugging-and-error-recovery`
  From clean state: run ALL rotation tests, ALL leveling tests, ALL audit tests. Test Mage specs end-to-end (load rotation, verify spell output). Cross-test spec interactions (shared modules, middleware). Save evidence to `.omo/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [35/35 compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| Wave | Commits |
|------|---------|
| **1** | 4 commits: arcane, fire, frost, class-infra (squash: `fix(mage): audit all Mage rotation specs for TBC Anniversary accuracy`) |
| **2** | 4 commits: arms, fury, prot, assassination |
| **3** | 4 commits: combat, subtlety, BM, MM |
| **4** | 4 commits: SV, affliction, demonology, destruction |
| **5** | 4 commits: disc, holy-priest, shadow, smite |
| **6** | 3 commits: holy-paladin, prot-paladin, ret |
| **7** | 4 commits: elemental, enhance, resto-shaman, balance |
| **8** | 4 commits: bear, cat, resto-druid, caster |
| **9** | 4 commits: test-expansion, spell-audit, rotation-tests, leveling-tests |

Pre-commit validation for ALL: `luac -p <file>` must pass.

---

## Success Criteria

### Verification Commands
```bash
luac -p EaxRotations/classes/mage/arcane_sylvanas.lua  # Expected: no output (pass)
luac -p EaxRotations/classes/mage/fire_sylvanas.lua     # Expected: no output (pass)
luac -p EaxRotations/classes/mage/frost_sylvanas.lua    # Expected: no output (pass)
lua EaxRotations/tests/run_rotation_tests.lua           # Expected: ALL PASS
lua EaxRotations/tests/run_leveling_tests.lua           # Expected: ALL PASS
lua EaxRotations/tests/run_sylvanas_audit_tests.lua     # Expected: ALL PASS
```

### Final Checklist
- [ ] All 30 TBC specs have source files (Mage audited, others verified)
- [ ] All "Must Have" present (nil-guards, squared distance, static tables)
- [ ] All "Must NOT Have" absent (no WotLK-only spells without DBC verification)
- [ ] All rotation tests pass
- [ ] All leveling tests pass
- [ ] All audit tests pass
- [ ] Evidence captured for all 35 tasks in `.omo/evidence/`

---

## Plan Review

- **High Accuracy Mode**: SELECTED
- **Momus Review**: OKAY (non-blocking note: Mage files exist, pivot to audit — addressed in Premise Correction)
- **Oracle Phase 2**: GO (wave sizes fixed to 3-4, WotLK/MOP references removed, spec count standardized to 30)
- **Oracle Phase 3**: GO (internal consistency verified, all thresholds cited, Ice Lance verified in DBC as valid 2.5.5 spell, 30 spec count uniform)
