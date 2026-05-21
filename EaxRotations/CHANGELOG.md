# Changelog

## 1.0.17 - 2026-05-21

- Druid Balance: SP breakpoint research completed — TBC spell coefficients verified (Starfire ~1.0, Wrath ~0.571/0.671, Moonfire ~0.15 direct + ~0.52 DoT, Insect Swarm ~0.76) against Elitist Jerks, Wowhead, and wowsims sources.
- Druid Balance: 800/1000/1200 SP breakpoints confirmed — these thresholds are DoT GCD-value decisions, not Starfire vs Wrath filler preference; Starfire wins at all SP levels on mana efficiency and crit synergy.
- Docs: all three `[VERIFY]` tags in `Research.md` Angle 4 resolved to `verified`.
- Docs: `SP_Breakpoints_Druid_Balance.md` blocker file rewritten with comprehensive coefficient analysis, corrected mathematical proof, and deferred-implementation recommendation (Option B).
- Docs: `Druid_Balance_CHECKLIST.md` SP breakpoint row updated to verified status.

## 1.0.16 - 2026-05-21

- Druid Balance: smart Innervate targeting — party scan identifies healer-class units (Paladin/Priest/Shaman/Druid) and picks the lowest-effective-HP target for InnervateHealer strategy; InnervateSelf fallback when no suitable healer found.
- Druid Balance: Hurricane Barkskin automation — Hurricane now defers when Barkskin is ready (not on cooldown), letting PreHurricaneBarkskin handle the Barkskin→Hurricane sequence for 20% damage reduction synergy.
- Discipline: PW:S absorb tracking via `Healing.pws_absorb_remaining` — skips PW:S recast when remaining absorb exceeds 200 (prevents wasting mana and triggering Weakened Soul unnecessarily).
- Core: `NS.buff_points`/`NS.debuff_points` read the `points` array from aura data, enabling variable-value tracking (Holy Shield charges, PW:S absorb remaining, etc.).
- Tests: fixed `test_balance_custom_matches.lua` Hurricane cooldown mock for Barkskin-ready deferral logic.
- Docs: AGENTS.md updated with Patterns 11–13 (buff_points, PW:S absorb tracking, smart Innervate targeting); all stale per-spec library references cleaned up for flat-file architecture.
- Queue: 001_Druid_Balance moved from `blocked/` to `completed/` (2 of 3 blockers resolved); remaining SP breakpoints tracked in `SP_Breakpoints_Druid_Balance.md`.
- All 106 regression suites (95 rotation + 11 leveling) pass with zero failures.

## 1.0.15 - 2026-05-16

- Improved TBC spell and aura coverage for racials, common crowd control, Druid utility, and Hunter abilities.
- Improved Hunter leveling stability, including safer API fallbacks and correct Serpent Sting refresh timing.
- Improved Warrior buff-cancel and Shaman totem handling through safer shared helpers.
- Cleaned the release package so it contains only Lua source and Markdown documentation.
- Added audit documentation for spell IDs, archive comparisons, and static behavior checks.
- Verified release health: Lua syntax passes, all 106 regression suites pass, online TBC ID audit passes, and package file-type checks pass.

## 1.0.14 - 2026-05-15

- Made menu playstyle selection authoritative: Leveling no longer overrides Elemental, Enhancement, or Restoration for under-70 players.
- Fixed Enhancement self-heals so Lesser Healing Wave and Chain Heal do not fire at full health.
- Added Enhancement self-heal HP controls and throttled fallback Lightning Shield refreshes in the Leveling playstyle.

## 1.0.13 - 2026-05-15

- Added Shaman leveling weapon imbue support with auto Windfury/Rockbiter/Flametongue selection.
- Added Shaman leveling Searing, Strength of Earth, and water totem support with refresh throttles.
- Added missing TBC Shaman spell entries used by leveling: weapon imbues, Searing Totem, Stoneclaw Totem, and Healing Stream Totem.

## 1.0.12 - 2026-05-15

- Fixed Shaman Leveling loading but not registering with the dispatcher, which left the selected Leveling playstyle with no actions to run.
- Fixed Shaman Leveling using the legacy empty `NS.SPELLS` table instead of `NS.ShamanSpells`.
- Fixed Druid, Rogue, and Warrior Leveling dispatcher registration; all class leveling modules now register the `leveling` playstyle.
- Under-70 characters now run the Leveling playstyle as a pre-pass before the selected spec, so leveling support works automatically instead of requiring manual playstyle selection.
- Improved broken `spell_book.is_spell_learned` fallback to choose the best rank allowed by player level when spell metadata includes rank levels.
- Fixed low-level Shaman OOC buff fallback so Water Shield is not attempted before level 60 and Lightning Shield can be maintained below that level.

## 1.0.11 - 2026-05-15

- Fixed "trying to pop up spell which isnt learned": when spell_book API is broken, `NS.get_spell_id` now returns the lowest rank (`ids[#ids]`) instead of the highest (`ids[1]`). This ensures low-level players always get a castable spell rank.
- Both the normal resolution path and the fallback path now use lowest-rank-safe logic when API health is broken

## 1.0.10 - 2026-05-15

- Fixed `[DIAG] buff_up` printing table addresses instead of spell IDs (now shows `27044,25296,...`)
- Fixed `rotation callback failed` spamming every frame: rate-limited to once per 2s, changed from log_error to log
- Fixed `NS.get_spell_id` cache poisoning: clear spell cache when API health break is detected so previously cached fallback IDs get re-resolved
- Fixed rotation running in character menu/dead: added guards for `core.is_main_menu_open()`, `player:is_alive()`, and player existence check in `main.lua on_update`

## 1.0.9 - 2026-05-15

- Full system audit: 195 Lua files, 46 shared modules, 65 tests checked
- All files pass luac -p and LSP with zero errors
- Zero banned API violations confirmed
- All hot-path NS.log calls gated behind debug_system (74 guards)
- README synced to v1.0.9, status set to Stable
- Shared module audit: no duplicate overlap with core_sylvanas.lua
- Spec audit: druid/caster identified as thin (7 strategies)
- Retribution uses add_strategy (38 calls), Arms uses STRATEGY_SPECS (29 entries)

## 1.0.8 - 2026-05-15

- Properly compared archive modules vs new system: deleted `dot_manager_sylvanas.lua` (duplicate of existing `dot_refresh.lua` + `NS.should_refresh_dot`), `threat_manager_sylvanas.lua` (duplicate of existing `NS.should_drop_threat`/`NS.threat_status`), `dispel_engine_sylvanas.lua` (duplicate of `NS.has_dispel_type_debuff`/`NS.healing_get_cleanse_target`, used raw WoW API), `mana_conservator_sylvanas.lua` (duplicate of `NS.mana_pct`/`action.min_mana`)
- Rewrote `pet_manager_sylvanas.lua` to match archive's full state machine (per-spec tracking, pet spell scanning, growl/claw/special rotation with cooldown gating)
- Fixed `consumable_manager_sylvanas.lua` typo (`griffed` -> `grilled_mudfish`)
- Removed unused `SCROLLS` table from consumable_manager (no callers)
- Verified all remaining shared modules (`totem_manager`, `pvp_manager`, `pet_manager`, `consumable_manager`) have no duplicates in the existing system

## 1.0.7 - 2026-05-15

- Ported 3 shared modules from archive: `pet_manager_sylvanas.lua`, `totem_manager_sylvanas.lua`, `pvp_manager_sylvanas.lua`
- Pet manager: pet attack/follow/passive controls, growl/claw/bite/special ability casting, HP monitoring
- Totem manager: bag scanning for totem items, per-spec totem placement (elemental/enhancement/restoration), full TBC spell ID tables
- PvP manager: arena/BG map detection, enemy player targeting with healer priority, PvP trinket detection, arena frame support

## 1.0.6 - 2026-05-15

- Added diagnostic logging to `NS.buff_up`: logs when all buff detection methods fail (enable debug_system to see)
- Added `min_interval` support to action rows and `NS.action_matches` — prevents recast of buff actions within N seconds
- Added per-spell 5s rate limiter in `NS.try_cast` via `_last_spell_cast[id]` tracker — prevents same spell from being cast more than once per 5s regardless of code path
- Set `min_interval = 60` for Aspect of the Hawk and `min_interval = 30` for Aspect of the Viper across all 3 hunter specs
- Added `_last_action_exec` / `_last_spell_cast` timestamps at all cast success paths

## 1.0.5 - 2026-05-15

- Added comprehensive auto-consumable system: shared `consumable_manager_sylvanas.lua` manages flasks, potions, elixirs, food, scrolls, weapon buffs, drums, healthstones, and runes for all 9 classes
- Wired consumable strategies into all class middleware (warrior, mage, druid, hunter, warlock, paladin, shaman, priest, rogue)
- Consumables auto-detect class role for optimal item selection
- Throttled to 3s checks; logging behind debug_system only

## 1.0.4 - 2026-05-15

- Gated remaining un-gated logs behind `debug_system`: Druid Bear item usage, Druid middleware consumables, Warrior middleware (HS dequeue, PW:S/BoP cancel), Mage middleware mana gem
- Cross-spec audit complete: all `NS.log()` calls in hot paths now gated behind `debug_system` setting

## 1.0.3 - 2026-05-15

- Fixed Hunter rotation ability spam: KillCommand and AspectOfTheHawk no longer spammed every frame
- Added 0.3s anti-flicker protection to `skip_gcd` cast path in `core_sylvanas.lua` — covers all skip_gcd actions across all classes (KillCommand, Bloodrage, Powershift, etc.)
- Gated all action execution debug logs behind `debug_system` setting in `NS.action_execute`, `NS.try_cast`, and `NS.try_cast_position`
- Gated Paladin Holy item usage logs behind `debug_system`
- Gated Druid Resto mana potion log behind `debug_system`
- Restored `exporter.lua` from broken state (malformed table syntax, undefined variable reference)
- All version refs synced across header.lua, exporter.lua, optimizer_bridge.lua

## 1.0.2 - 2026-05-15

- Full diagnostic audit across all 29 specs: verified spell IDs, buff checks, nil safety, API compliance
- Fixed version inconsistencies across exporter.lua, optimizer_bridge.lua, and header.lua
- All 62 tests passing; luac -p passes on all .lua files; zero banned API usage
- Verified zip contains only .lua and .md files

## 1.0.1 - 2026-05-15

- Fixed Hunter Aspect of the Hawk rank IDs to prevent repeated Hawk recasts.

## 1.0.0 - 2026-05-15

- Initial release
