# EaxRotations Logic Gap Audit

> **Scope**: read-only review of 11 high-priority specs and 8 shared modules against TBC/Classic APL expectations.
> **Method**: `rg` scans for TODO/stub, CD/snapshot/AoE/PvP/trinket integration, plus targeted code reads.
> **Counts**: all 220 rotation suites and 13 leveling suites are green; this audit is about fidelity gaps, not syntax.

---

## P0 — Fix before next release ✅

> All P0 items were addressed in commits `f95a560d` (Fury) through `e99ebb6f` (Affliction).
> See `CHANGELOG.md` v2.3.15 and `RELEASE_NOTES_EaxRotations_v2.3.15.md` for user-facing notes.
>
> What was fixed:
> - Marksmanship Bestial Wrath gated on `is_spell_learned`.
> - Cooldown planner adopted by Fury Death Wish/Recklessness, Enhancement Shamanistic Rage,
>   Fire Combustion, Beast Mastery Bestial Wrath, Shadow racials, and Affliction racials.
>
> What intentionally remains in existing behavior:
> - Hunter Major CDs other than Bestial Wrath (Rapid Fire / Readiness / Trueshot Aura) were not
>   changed in this pass because they already coordinate closely with shot weaving; aligning
>   them with power windows can be added later behind a setting without breaking current tests.
> - Shadowfiend, Dark Pact, and Power Infusion remain mana/defensive-gated rather than burst-gated
>   because that is their primary role for casters.

### 1. Marksmanship Hunter includes Bestial Wrath (BM-only)
- **File / line**: `classes/hunter/marksmanship_sylvanas.lua:461`
- **Current**: strategy `BestialWrath` calls `SPELLS.BestialWrath` unconditionally (`return NS.try_cast(SPELLS.BestialWrath, ...)`).
- **Expected behavior**: Bestial Wrath is not available to a Marksmanship build. Remove the strategy or gate it on `NS.spell_exists(SPELLS.BestialWrath)` / talent detection so MM does not waste a strategy slot or log errors.
- **Related**: `classes/hunter/survival_sylvanas.lua` may have the same leak; verify all 3 hunter specs.

### 2. Cooldown Planner adoption is incomplete
- **File / line**: `shared/cooldown_planner_sylvanas.lua` is live; only `classes/mage/arcane_sylvanas.lua:9` and `classes/paladin/retribution_sylvanas.lua:11` import it.
- **Specs with major CDs but no planner import**:
  - `classes/mage/fire_sylvanas.lua` — Combustion (~:89) and PoM (~:244 for arcane but not fire; fire has none)
  - `classes/warrior/fury_sylvanas.lua` — Recklessness (:528), Death Wish (:546)
  - `classes/shaman/enhancement_sylvanas.lua` — Shamanistic Rage (:666), Bloodlust (:687)
  - `classes/hunter/beast_mastery_sylvanas.lua` — Bestial Wrath
  - `classes/hunter/marksmanship_sylvanas.lua` — Rapid Fire, Readiness, Trueshot Aura
  - `classes/hunter/survival_sylvanas.lua` — same cooldowns
  - `classes/priest/shadow_sylvanas.lua` — racials, Shadowfiend, Power Infusion (if available)
  - `classes/warlock/affliction_sylvanas.lua` — racials, Dark Pact, trinkets
- **Expected behavior**: every major offensive CD should consult `planner.should_fire_offensive(context)` with a `trinket_align_with_cds` fallback to legacy behavior.

### 3. Fury Warrior major CDs fire on cooldown, not stacked
- **File / lines**: `classes/warrior/fury_sylvanas.lua:528` (`recklessness_matches`), `:546` (`death_wish_matches`).
- **Current**: both pass boss-only and TTD gates, then fire as soon as ready (Recklessness even has 1800s cooldown = 30 min). Death Wish only gates on `hp > 45`.
- **Expected behavior**: align 180s Death Wish with Bloodlust/Heroism/Drums/major CDs; Recklessness (30 min) should reliably stack with BL + Death Wish unless the encounter is too short. Add timeout/TTD fallback so it never rots.

### 4. Enhancement Shamanistic Rage is gated defensively only
- **File / line**: `classes/shaman/enhancement_sylvanas.lua:666`.
- **Current**: only fires when `(mana_pct > 40 and hp_pct > 40)` is false — i.e., only at low mana or low HP.
- **Expected behavior**: SR also converts AP to mana and is an offensive throughput CD. Add an offensive branch: fire during Bloodlust/Drums/trinket burst even when resources are healthy. Keep defensive branch as fallback.

### 5. Fire Mage Combustion lacks power-window gating
- **File / line**: `classes/mage/fire_sylvanas.lua:89` (`combustion_matches_fn`).
- **Current**: fires when `context.should_burst` is true or via `NS.should_use_long_cd`. No Bloodlust/Drums/major-CD awareness.
- **Expected behavior**: align Combustion with Bloodlust/Heroism or another major CD; stack with Scorch 5-stack and TrinketManager offensive window.

### 6. `dot_refresh_sylvanas.lua` exists but is unused
- **File**: `shared/dot_refresh_sylvanas.lua` (APL-driven pandemic math + haste-aware refresh windows + tick data from DBC bridge).
- **Usage**: zero references in `classes/`.
- **Impact**: Shadow Priest, Affliction, Balance, Fire/Destruction likely implement their own pandemic/snapshot math with inconsistent constants.
- **Expected behavior**: adopt `NS.should_refresh_dot()` in DoT specs; remove duplicated refresh logic.

### 7. Hunter specs ignore `aspect_manager_sylvanas.lua` and `shot_timer_sylvanas.lua`
- **Files**: `shared/aspect_manager_sylvanas.lua`, `shared/shot_timer_sylvanas.lua`.
- **Usage**: zero references in `classes/hunter/`.
- **Impact**: aspect logic (Hawk ↔ Viper), shot clipping prevention, and auto-shot weaving are duplicated across BM/MM/Survival with minor differences, causing inconsistent DPS and maintenance burden.
- **Expected behavior**: migrate duplicated aspect/shot-timer code to the shared modules.

---

## P1 — Significant fidelity improvements (remaining)

### 8. Affliction lacks combat-mode switching / multi-target policy
- **File / lines**: `classes/warlock/affliction_sylvanas.lua` has no `combat_mode`/ `effective_mode` fields; only `enemy_count` is used for curse choice (`:352`).
- **Current**: Seed of Corruption strategy exists (`:748`) but no threshold-driven tab-corruption or SoC spam on 4+ targets.
- **Expected behavior**: add auto/st/cleave/aoe mode; spread Corruption on 2–4 targets; Seed of Corruption on ≥4 grouped targets; skip CC'd targets (already partially done).

### 9. Shadow & Affliction racial CDs not aligned with power windows
- **Files / lines**: Shadow `racial_matches` (around `:620`); Affliction racial strategies near `:360`.
- **Current**: only TTD and combat gates; no Bloodlust/Drums/trinket alignment.
- **Expected behavior**: Berserking, Blood Fury, Arcane Torrent should fire during major power windows where applicable.

### 10. `combat_mode_sylvanas.lua` shared module is unused
- **File**: `shared/combat_mode_sylvanas.lua`.
- **Usage**: zero references in `classes/`.
- **Impact**: threshold drift across specs (e.g., Shadow cleave at ≥3 enemies, Holy Nova AoE at ≥3, Affliction never switches).
- **Expected behavior**: centralize auto/st/cleave/aoe mode detection; delete duplicated threshold logic in Shadow/Enhancement.

### 11. Hunter trinket logic is duplicated, not centralized
- **File / lines**: `classes/hunter/beast_mastery_sylvanas.lua:558` custom `trinket_matches` and per-spec `trinket_mode` setting.
- **Expected behavior**: remove per-spec trinket logic and rely on `NS.TrinketManager` (which now supports cooldown planner alignment). Ensure BM/Survival/MM no longer maintain their own trinket code.

### 12. No standardized snapshot module
- **Observation**: `shared/snapshot_sylvanas.lua` does not exist. Shadow (`:203`), Affliction (`:197`), and Feral Cat (`:129`) each inline snapshot state and `should_snapshot_upgrade()` math.
- **Expected behavior**: create a shared snapshot helper that records `spell_damage`/`attack_power` per target per debuff, computes pandemic/upgrade refresh, and is consumed by DoT/bleed specs.

### 13. Execute-phase handling is ad-hoc per spec
- **Examples**: Shadow SW:D at 25% (`:745`), Feral at 25%, Fury Execute on `target_hp < 20`.
- **Expected behavior**: unify execute thresholds and cooldown logic (if adding a shared execute manager later).

---

## P2 — Polish / future

### 14. PvP CC / DR integration gaps
- Affliction has Fear/CoEx/CoTongues but no DR tracking.
- Hunter Freezing Trap in Marksmanship lacks DR check.
- Shadow has Psychic Scream but shares PvP strategies;
- Expected: integrate `NS.DRTracker` consistently for all hard-CC strategies.

### 15. Consumable manager vs. potion_helper split
- `shared/consumable_manager_sylvanas.lua` exists, but most specs still use `shared/potion_helper_sylvanas.lua`.
- Expected: converge on one module for combat/racial/defensive/damage consumables.

### 16. Dot TTD gating is only used in a few specs
- `shared/dot_ttd_gating_sylvanas.lua` is required/tested; verify it is wired in Affliction/Shadow/Balance rather than inlined.

---

## Recommended next commit order

1. **(P0)** Gate/remove Marksmanship `BestialWrath` and verify Survival.
2. **(P0)** Roll cooldown planner into Fury (Death Wish + Recklessness), Enhancement (SR + Bloodlust), Fire (Combustion), BM (Bestial Wrath).
3. **(P1)** Replace duplicated hunter aspect/shot-timer logic with `aspect_manager_sylvanas.lua` / `shot_timer_sylvanas.lua`.
4. **(P1)** Adopt `dot_refresh_sylvanas.lua` in Shadow and Affliction; then Balance/Fire.
5. **(P2)** Add DR checks to PvP CC strategies.

> **Success criteria for each commit**: `luac -p` on changed files, all 220 rotation suites and 13 leveling suites green, changelog entry.
