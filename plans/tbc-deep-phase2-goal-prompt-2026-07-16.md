# TBC Anniversary Phase 2 — Goal Prompt (copy-paste ready)

**Date:** 2026-07-16  
**Purpose:** Mirror of Classic Vanilla Phase 2 deep audit, adapted for **TBC Classic Anniversary (2.5.5.x)**.  
**Not execution:** pasting this as a goal starts the work; this file only stores the prompt.

### Key deltas vs Vanilla Phase 2

| Dimension | Vanilla | TBC Anniversary |
|-----------|---------|-----------------|
| Files | `*_vanilla.lua` | `*_sylvanas.lua` (29 combat) + `leveling_sylvanas.lua` (9) |
| Levels | 10/25/40/60 | **10/25/40/60/70** |
| Endgame APL | `data/wowsims_classic/**` | `data/tbc-new/ui/**/apls/*.apl.json` |
| TBC spells | Forbidden as only path | **Expected cores** when learned |
| Baseline not re-claim | load-coverage / thin matrix | gap-matrix **aligned** header pass |

---

## Prompt (paste into goal / agent)

@EaxRotations Deep TBC Anniversary Phase 2 — per-class 1–70 spell ladders + content modes

## Context (do not re-claim prior TBC “aligned” passes as done)
- Read first: AGENTS.md, plans/tbc-rotation-gap-matrix-2026-07-16.md,
  plans/become-1-rotation-system-classic-tbc-2026-07-05.md,
  plans/low-level-spell-coverage-audit-2026-07-15.md (TBC sections),
  plans/research_rotation_sources_report.md (if present)
- Baseline: prior TBC gap matrix marked many specs **aligned** via strategy-order /
  wowsims endgame comparison + isolated fixes (e.g. Destro Shadowburn). That is
  **NOT** proof rotations work from level 1–70 for solo grind, 5-man dungeons,
  group, and raid (70) with tests driving SHIPPED matches/build_state.
- This goal is NOT another “scan headers / compare APL names for 11 minutes.”
  Prove ladders + content modes with real tests.

## Scope
- All **TBC Classic Anniversary ONLY**:
  - Combat: EaxRotations/classes/**/*_sylvanas.lua specializations (29 combat specs
    under AGENTS.md; exclude middleware-only / class_ / schema_ / pure helpers
    unless a ladder gap requires a shared fix)
  - Leveling: EaxRotations/classes/*/leveling_sylvanas.lua (9 classes)
- **NO** Classic Era `*_vanilla.lua` rewrites for this goal.
- **NO** WotLK `*_wotlk.lua` / Death Knight work.
- Authoritative sources you MUST use:
  1. scraped_docs_md/dev/api/* + scraped_docs_md/dev/libraries/izi/*
     (cast, spellbook ranks, buffs, pet, party, dungeons)
  2. .api/ stubs (READ-ONLY) for signatures: spell_helper, buff_manager,
     pet_handler, izi_sdk, game_object, core
  3. data/tbc-new/ui/**/apls/*.apl.json for **B5 / level-70** priority only
     (not L20 truth)
  4. classes/*/class_sylvanas.lua rank `levels` tables + DBC
     (wowheadScrape/dbc_extract/wowsims.db) for learn ladders & spell existence
  5. lexxer.org `?game=tbc` only as cross-check; **DBC wins**
  6. Written TBC guides (Wowhead TBC / Icy Veins TBC / Warcraft Tavern) for
     healers + contested priorities (Fire/Frost Mage, Holy specs, etc.)

## Critical expansion rules (TBC Anniversary)
- TBC Anniversary runs on **2.5.5.x**, not 2.4.3 pure and not Wrath 3.3.5.
- Some Wrath-era IDs were **backported** into 2.5.5 (e.g. Ice Lance 30455,
  Seal of Blood 31892) — verify against DBC before deleting or hard-gating.
- **TBC-era cores ARE expected** at appropriate levels: Steady Shot, Kill Command,
  Vampiric Touch, Shadowfiend, Mangle (cat/bear), Lacerate, Fel Armor, Felguard,
  Unstable Affliction, Arcane Blast, Earth Shield, Lifebloom, Avenging Wrath
  (talent/level gated), etc.
- Do **not** treat “looks WotLK” as invalid without DBC + lexxer cross-check.
- Soft-gate high talents when unlearned (SS 40, Mangle 50, etc.) so low-level
  fillers still match — same structural rule as Vanilla Phase 2, different spell set.

## Definition of done
For EACH of the 9 classes, complete a class batch (one class per commit preferred):

### A. Spell ladder (B1–B5)
At simulated levels **10, 25, 40, 60, 70**, with spell_ready/spell_exists filtered so
only spells learnable by that level return true (derive from class_sylvanas levels
or an explicit TBC LEARN map):
- At least one **filler/builder** matches when high talents (BT, MS, Steady, Mangle,
  Stormstrike, Shadowfiend, etc.) are unlearned at lower bands.
- No strategy requires a **WotLK-only / non-DBC** spell as the only combat path.
- Hard gates on unlearned debuffs/stacks (e.g. 5 Scorch, Mangle, UA, Lifebloom 3)
  must be spell_exists/level gated so L10–40 is not dead.

### B. Content modes
- **Solo:** self-heal/defensive/pet mend/call can fire; not raid-CD dependent;
  aspects/totems/seals sane for grind.
- **Group:** no assigned-debuff stomps without settings (curses, sunders, demo,
  FF, ISB, judgments); interrupts where class has them.
- **Dungeon:** AoE path exists (Multi/Cleave/Consecrate/TC/Swipe/Hurricane/etc.)
  and is gated by enemy_count / schema thresholds; threat tools (FD/Fade/Soulshatter).
- **Raid 70:** core APL priority still holds (wowsims tbc-new where available;
  written guides for healers).

### C. Settings
- Schema keys that claim to change TBC behavior actually change matches
  (spot-check **3–5 keys per class**, not 5 total globally).
- Nil-guard all menu/settings reads (Pattern 8 / 14).
- Group-overwrite settings (curse mode, assigned curse, sunder mode, demo shout,
  seal prefs, aspect/totem prefs) have at least one real matches test each class
  that has them.

### D. Tests (no theater)
- Add `test_tbc_spell_ladders.lua` (+ `tbc_ladder_helper.lua`) OR extend an existing
  TBC coverage suite that:
  - loads real `*_sylvanas.lua` / leveling modules
  - calls real matches/build_state with level + learned-spell mock
  - fails if L10 has zero combat fillers when high spells are mocked unlearned
- Keep existing TBC regression suites green (e.g. destruction Shadowburn order,
  hunter steady weave, ret seal twist, affliction curse gates, low-level Scorch/
  Immolate/Maul gates as applicable).
- luac -p on changed files; full run_rotation_tests.lua + run_leveling_tests.lua green.

### E. Matrix + release hygiene
- Create/update `plans/tbc-deep-audit-matrix-2026-07-16.md` (or dated equivalent)
  per class with evidence (strategy names, test names, source). Cells: B1–B5 + S/G/D/R
  with OK / FIX / GAP / WATCH — never OK without test or explicit soft-gate proof.
- After each class batch OR after all classes: version bump, CHANGELOG-dev +
  CHANGELOG_CUSTOMER + EaxRotations/CHANGELOG.md, header.lua + VERSION.txt +
  README badge, commit, push.
- Stage only TBC Phase-2 files (dirty tree may have Vanilla/WotLK/WIP — do not ship noise).

## Class order (do in this order)
1. Hunter (BM/MM/Survival + leveling) — Steady/KC weave; Aimed gates; pet Call/Mend/Revive
2. Warrior (Arms/Fury/Prot/Kebab + leveling) — BT/MS gates; Execute; Sunder/Demo settings
3. Warlock (Aff/Demo/Destro + leveling) — UA/Fel Armor/Felguard; Shadowburn/SoulFire execute; curse governance
4. Mage (Arcane/Fire/Frost + leveling) — AB burn/conserve; Scorch gate; water elemental (Frost)
5. Rogue (Combat/Sin/Sub + leveling) — SnD/Evis vs Envenom per swords APL; Mutilate dagger gates
6. Shaman (Ele/Enh/Resto + leveling) — totems; Stormstrike soft-gate; Earth Shield resto; BL
7. Priest (Holy/Disc/Shadow/Smite + leveling) — VT/SW:D/Shadowfiend when learned; triage
8. Paladin (Holy/Prot/Ret + leveling) — seal twist; Holy Shield charges; Avenger’s; LG chain
9. Druid (Balance/Cat/Bear/Caster/Resto + leveling) — Mangle/Lacerate/Lifebloom level-aware

## Class-specific critical items (TBC)

1. Hunter
• Steady Shot weave uses correct auto gap / clip tracker (not Vanilla 3s Aimed-only model)
• Kill Command when learned; pet BW/Mend all specs + leveling
• Multi/Volley enemy_count gated; aspect Hawk/Viper mana hysteresis
• Aimed combat gates (MM opener rules) stay green

2. Warrior
• Fury: Execute priority vs wowsims; BT/WW/HS ladder when BT unlearned
• Arms: MS learn gate; OP weave settings
• Prot: SS/Revenge/Devastate; no dead strategies
• Group: sunder/demo/shout settings prevent stomps

3. Warlock
• Aff: UA when learned; assigned curse / curse_mode hard blocks stomps
• Demo: Felguard path; Soul Link; pet summon OOC
• Destro: Shadowburn before filler at execute; Conflagrate; Fel Armor OOC
• Life Tap / wand OOM thresholds; Health Funnel

4. Mage
• Arcane: AB stacks burn/conserve; no dead PoM/AP order
• Fire: Scorch known-gate; Fireball when Scorch unlearned
• Frost: Frostbolt primary; Ice Lance shatter window only if DBC-valid; water elemental
• Leveling: nuke ladder + wand

5. Rogue
• Combat: swords APL Evis-first; Envenom secondary when configured
• Assassination: Mutilate dagger requirement; DP stacks
• Subtlety: openers soft when untalented
• Leveling: SS/Evis/SnD

6. Shaman
• Ele: LB/CL; totems; Elemental Mastery settings
• Enh: WF weapon + Stormstrike soft-gate; totem twist
• Resto: Earth Shield when learned; CH/HW; no missing ES as hard-required pre-learn
• Leveling: shock fallback (Earth when Flame not ready)

7. Priest
• Shadow: VT/SW:P/MB/MF; Shadowfiend mana; SW:D safe gates
• Holy/Disc: triage solo vs group; PI/Pain Supp settings
• Smite: TBC tools gated (not Classic-stripped incorrectly)
• Leveling: Smite/SW:P ladder

8. Paladin
• Ret: SoB/SoM/Command twist; CS/Judge order vs wowsims
• Prot: Holy Shield charges; Consecrate AoE; Avenger’s pull
• Holy: FoL/HL/LG chain; blessings group-safe
• Leveling: seals + judgement

9. Druid
• Cat: Mangle when learned; Shred/Rip/FB CP by level (no Mangle-required at L20)
• Bear: Mangle/Lacerate when learned; Maul/Swipe/Demo fallbacks
• Balance: MF/IS/Starfire-Wrath; Hurricane AoE
• Resto: Lifebloom 3-stack when learned; Rejuv/Regrowth/HT; Swiftmend
• Leveling: form + Wrath/Moonfire

## Content-mode cross-cut (after classes or interleaved)
• Solo self-heal pass (healers + hybrid DPS)
• Dungeon AoE thresholds audit (enemy_count / aoe_threshold settings) — **required match**, not soft-pass
• Group assist / mark / interrupt / assigned-debuff pass
• Raid 70 APL spot-check vs data/tbc-new for DPS/tanks; guide triage for healers

## Infrastructure (do first if missing)
• [ ] Build TBC learned-spell mock helper (spell_ready / spell_exists / is_spell_learned
      honor level + rank levels from class tables + TBC LEARN map)
• [ ] Register ladder suite in run_rotation_tests.lua
• [ ] Document learn-level map for key TBC spells (Steady 50, KC 66, BT 40, MS 40,
      Mangle 50, VT 50, Shadowfiend 66, SS 40, AB 64, etc.)
• [ ] Grep all *_sylvanas combat specs for hard-required high talents without
      spell_exists/level gate; track in matrix

## Per class (repeat template × 9)

For each class, check all of these:

Leveling (leveling_sylvanas.lua)
• [ ] L10: has a castable filler (not only endgame talents)
• [ ] L25: mid-game spells enter priority without blocking older fillers
• [ ] L40+: talent spells appear when learned; still fall back if not
• [ ] L60–70: TBC tools enter when learned (Steady, AB, VT, Mangle, etc.)
• [ ] Solo grind: OOC buffs, pet call/mend (Hunter/Warlock), wand where applicable
• [ ] Dungeon packs: AoE or multi-target path if class has one

Each combat spec
• [ ] B1–B5 ladder tests (matches with unlearned high spells)
• [ ] Solo defensives / self-sustain
• [ ] Group: no bad overwrites without settings
• [ ] Dungeon: enemy_count AoE + threat tools
• [ ] Raid 70: APL-aligned core priority (wowsims tbc-new if exists)
• [ ] Settings wired + nil-guarded (3–5 keys proven)
• [ ] Update deep matrix row to OK with test names

## Ship
• [ ] Matrix fully filled (no empty B1–B5 / S/G/D/R cells)
• [ ] Full suites green; scratch evidence
• [ ] Version bump (suggest **2.10.0** when all 9 classes done)
• [ ] Dev + customer changelogs; commit; push Phase-2 TBC only

## Non-goals
- Live raid parses / in-game botting
- Classic Vanilla re-audit or WotLK foundation work
- Raising scorecard cells without material bugs
- Editing .api/ or scraped_docs_md (read-only)
- Claiming “aligned” from strategy-name grep alone

## Process
- Follow AGENTS.md (luac, full suites, one concern per commit).
- If a task loops >2 attempts, stop and write a note under plans/.
- Be honest in matrix: OK / FIX / GAP / WATCH — never mark OK without a test or
  explicit soft-gate proof.
- Prefer shared LEARN mock; drive shipped matches only (no test theater).

## Suggested cadence

| Session | Deliverable |
|---------|-------------|
| 1 | TBC LEARN mock + ladder harness + Hunter + Warrior |
| 2 | Warlock + Mage |
| 3 | Rogue + Shaman |
| 4 | Priest + Paladin + Druid |
| 5 | Content-mode cross-cut + matrix final + 2.10.0 release |

## One-line title
TBC Anniversary Phase 2: for all 9 classes, prove 1–70 spell ladders + solo/group/dungeon/raid(70) with real matches tests, update deep matrix, ship past baseline — DBC + scraped_docs + tbc-new wowsims + rank tables; no Vanilla/WotLK.
