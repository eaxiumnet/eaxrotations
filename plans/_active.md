# Vanilla Anniversary APL Audit — COMPLETE

**Started:** 2026-06-26
**Status:** COMPLETE (2026-06-26)
**Plan:** `plans/vanilla-apl-audit-2026-06.md`

## Baseline
- HEAD: 2f88f02f (in sync with origin/master)
- 171 rotation + 11 leveling suites PASS
- Vanilla spell audit: 31 specs clean, 0 tainted
- All 40/40 vanilla files have Pattern 15 headers

## Completed
- [x] Pattern 15 headers added to all 35 vanilla files that lacked them
- [x] Fixed false-positive forbidden-token matches in test_classic_remaining_specs
- [x] Classic Era DBC extracted to `wowheadScrape/dbc_extract/wowsims_classic_era.db`
- [x] **TBC-only dead code removed from ALL 22 vanilla specs that had it:**
  - **Hunter BM**: Misdirection (TBC-only threat redirect)
  - **Hunter MM**: Steady Shot, Kill Command, Aspect of Viper, pre_steady_leveling state, dead helpers
  - **Hunter Survival**: Steady Shot, Kill Command, Aspect of Viper, pre_steady_leveling state
  - **Mage Arcane**: FireBlast-as-primary-filler → Frostbolt primary nuke; FireBlast now moving-only
  - **Mage Fire**: Dragon's Breath, Blast Wave
  - **Mage Frost**: Water Elemental, Ice Lance
  - **Paladin Ret**: Avenging Wrath, Crusader Strike
  - **Paladin Prot**: Avenging Wrath, Righteous Defense, Crusader Strike, Holy Shield (TBC versions)
  - **Priest Disc**: Binding Heal (TBC-only)
  - **Priest Holy**: Shadowfiend (TBC-only)
  - **Rogue Assassination**: Cloak of Shadows, Shiv, Envenom, Mutilate, Deadly Throw
  - **Rogue Combat**: Shiv Purge strategy + state fields
  - **Rogue Subtlety**: Cloak of Shadows, Shiv, Shadowstep, Deadly Throw + all helpers
  - **Shaman Ele**: Totem of Wrath, Water Shield, Shamanistic Rage, Bloodlust
  - **Shaman Enh**: Water Shield, Shamanistic Rage, Bloodlust + state fields
  - **Shaman Resto**: Water Shield, Earth Shield, Bloodlust + state fields
  - **Warlock Aff**: Soulshatter, Seed of Corruption, Unstable Affliction
  - **Warlock Demo**: Soulshatter
  - **Warlock Dest**: Incinerate, Soulshatter
- [x] **Rotation Scorecard** — 66 specs × 6 content types, auto-computed
  - Average: 4.3/5.0 (23 S-tier, 38 A-tier, 5 B-tier)
  - `build_tools/compute_scorecard.lua` | `SCORECARD.md` | `EaxRotations/scorecard_data.json`
- [x] **README badges + per-class rotation guides** — shipped in repo
- [x] **WoWSims upstream tracking** — `wowsims_classic/` clone + APL analyzer + sync script

## Remaining UnavailableClassic References
- All remaining references are SPELLS table definitions (e.g., `UnavailableClassicXxx = nil`) — these are the correct pattern for Vanilla vs TBC spell mapping and do not represent dead code strategies.
- 0 strategy-level UnavailableClassic references remain in any vanilla spec.

## Gate Status
- `validate.cmd`: **ALL CHECKS PASSED** (171 rotation + 11 leveling suites + spell audit)
- Pre-commit hooks: vanilla TBC spell ID audit + sylvanas spell ID audit both pass

## Notes
- EaxAutoQuester has uncommitted changes from another agent — intentionally not touched
- Fury spec uses table-driven `add_strategy` pattern — APL analyzer strategy extraction has known limitation
- `docs/` removed from `.gitignore` — `.md` rotation guides ship with releases
