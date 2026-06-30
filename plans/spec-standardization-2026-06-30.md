# Spec Standardization — Open-Source Readability

**Started:** 2026-06-30
**Goal:** Uniform, self-documenting layout across 9 classes / 29 specs / 9 leveling rotations / 9 menu schemas, locked by compliance tests.
**Motivation:** Open-source release — a new contributor reads one pattern and understands all 29 specs.

## Phase 0 — Canonical template + contract lock

- [x] Fix pre-existing pattern15_audit failure (wowhead_data_bridge_sylvanas.lua lowercase header keys -> uppercase)
- [x] Create `tests/test_spec_layout_compliance.lua` — contract lock for spec files
- [x] Register test in `run_rotation_tests.lua`
- [x] Update AGENTS.md Pattern 16 — promote to authoritative template with canonical skeleton
- [x] Add README "How to Read a Spec" section + migration state table
- [x] Full suite green (212+11 + new test)

**Acceptance:** luac -p clean; full suite green; compliance test passes; AGENTS.md + README updated.

## Phase 1 — Track A: Schema standardization (~1 day, low risk)

1. Extract shared Consumables tab (9x copy) into `shared/schema_consumables_sylvanas.lua`
2. Define required common key set; confirm each of 9 schemas has them
3. Write `tests/test_schema_compliance.lua`
4. Normalize tab ordering: General -> per-spec -> Leveling -> Consumables

**Acceptance:** schema compliance test green; no menu behavior change.

## Phase 2 — Track C: Leveling + class_config alignment (~0.5 day, low risk)

1. Bring all 9 leveling files to canonical return shape + guarded registration
2. Standardize leveling module-table name to `<class>_leveling` with `build_state` field
3. Extend schema compliance test: class_config.playstyles subset of schema playstyle values subset of registered keys

**Acceptance:** leveling suite (11) green; cross-consistency assertion passes.

## Phase 3 — Track B: Opportunistic spec_kit migration (ongoing, ~3-5 days)

Convert remaining 28 specs to canonical template, one at a time, only when already editing.

Per spec:
1. `spell()` -> `spec_kit.define_action_for_class(SPELLS)`
2. Manual Pattern 14 guards -> `spec_kit.safe_state(raw, schema)` (audit state fields first!)
3. Normalize `build_state` name, guarded registration, return shape
4. Add to CONVERTED table in test_spec_layout_compliance.lua
5. Gate: `luac -p` + full 208+11 suite. R5: >2 attempts -> STOP.

**First 2 conversions (GLM-5.2 — recipe-setting):**
- [ ] fury_sylvanas.lua (sibling to arms, same class)
- [ ] balance_sylvanas.lua (different class, non-standard _LOCAL_SPELLS pattern — stress test)

**Remaining 26 (Qwen3.7 Plus — mechanical grind):**
- [ ] bear, cat, caster, resto, healing (druid)
- [ ] beast_mastery, marksmanship, survival, leveling (hunter)
- [ ] arcane, fire, frost, leveling (mage)
- [ ] holy, protection, retribution, leveling (paladin)
- [ ] discipline, holy, shadow, smite, leveling (priest)
- [ ] assassination, combat, subtlety, leveling (rogue)
- [ ] elemental, enhancement, restoration, leveling (shaman)
- [ ] affliction, demonology, destruction, leveling (warlock)
- [ ] kebab, protection, leveling (warrior)

## Model usage

- **GLM-5.2 1.0M:** Phase 0 (contract test), first 2 Phase 3 conversions (recipe), R5 unblocks
- **Qwen3.7 Plus 1M:** Phase 1, Phase 2, Phase 3 mechanical grind (26 specs)
- **Kimi K2.7 Code 262K:** fallback if Qwen3.7 Plus rate-limited

## Risks

- Big-bang temptation: rejected by charter. Compliance test + migration table make partial state legible.
- safe_state field audit: each spec must verify state fields are in SAFE_STATE_DEFAULTS before swap.
- Two-pattern window during Phase 3: mitigated by README migration table + "arms is reference" pointer.