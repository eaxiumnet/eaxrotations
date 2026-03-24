# EAX TBC Classic Rotations - Handover Document

## OpenCode MCP Rule

When working anywhere under `C:\newbot\scripts` or its subdirectories, use the `sylvanas` MCP server first for:

- Project Sylvanas docs and API lookup
- searching and reading local script files
- inspecting runtime artifacts from `C:\newbot\scripts_data` and `C:\newbot\scripts_log`
- checking current runtime issues before guessing about failures

Prefer these `sylvanas` MCP tools when relevant:

- `sylvanas_inspect_sylvanas_runtime_issues`
- `sylvanas_list_sylvanas_runtime_artifacts`
- `sylvanas_get_sylvanas_runtime_artifact`
- `sylvanas_search_sylvanas_scripts`
- `sylvanas_get_sylvanas_script_file`
- `sylvanas_search_sylvanas_api`
- `sylvanas_get_sylvanas_api_file`
- `sylvanas_search_sylvanas_docs`
- `sylvanas_resolve_sylvanas_symbol`

For Sylvanas runtime debugging, check the runtime issue/artifact tools before proposing fixes.

**Last Updated**: 2026-03-21 (third pass)
**Repo**: https://github.com/eaxiumnet/eax-tbc-classic-rotations
**Local Path**: `C:\newbot\scripts`

## What Was Done

### ✅ Completed This Session (2026-03-21) — First Pass

1. **Git Recovery** - Restored 174 uncommitted commits, cleaned up git state
2. **Critical Bug Fix** - Fixed broken `require` paths: `common/eax_shared/` → `eax_shared/` across all 27 specs (all stubs were referencing non-existent paths)
3. **Performance: Spell Resolution Cache** - Created `eax_shared/spell_resolver.lua` with persistent caching
   - Previously: ~810+ `is_spell_learned()` API calls/sec across 27 specs
   - Now: cached after first resolve, invalidated on talent change
4. **Performance: Combat Context Throttle** - Throttled `combat_context.build()` to 2-second refresh
   - Previously: 20+ pcall API calls per frame × 27 specs
   - Now: cached for 2 seconds
5. **Performance: Target Finder** - Optimized `find_best_target()` in all 27 specs
   - Early exit for existing current target
   - Distance culling with squared-distance checks
   - Limited scan to 50 objects
6. **Performance: Mode Detector** - Moved `detect_mode()` to shared `utils.detect_mode(me)` with 5s throttle
   - Previously: per-spec inline O(n) scan every frame
   - Now: 5-second throttle, cached result
7. **Performance: ESP Renderer** - Static `_tracked_auras` table reuse in all 27 specs
   - Previously: `{}` allocated every frame
   - Now: static table reused, zero allocations
8. **Performance: Local API Caching** - Added `_core_time`, `_get_local_player`, `_get_gcd`, `_get_spell_cd` aliases in all 27 main.lua files
9. **Performance: Pet Manager** - Removed unused `me_to_target` and `pet_to_me` distance calculations; replaced sqrt with squared-distance comparisons
10. **.gitignore** - Added build artifacts (`luac.out`, `nul`, `.tmp_wfu_luac.txt`, `EaxFishing_v2_0_1/`)

### ✅ Completed This Session (2026-03-21) — Second Pass (Runtime Fixes)

1. **Critical Runtime Fix: spell_resolver.lua require** - All 27 specs had `require("eax_shared/spell_resolver")` in `utils.lua` that failed at runtime because there was no per-spec `eax_shared/` subfolder. Created 27 identical per-spec `spell_resolver.lua` stub files (4 lines each) that mirror the `defensive_manager.lua` pattern: `return require("eax_shared/spell_resolver")`. This bridges the relative require to the root `eax_shared/` module.

2. **Critical Runtime Fix: EAXWarriorFury >60 upvalues** - `on_update()` captured 65 chunk-local identifiers (exceeding Lua's 60 upvalue limit). Root cause: debug block + control panel callback registration + conflict detection were ALL running inside `on_update()` every frame. Fix: (a) moved conflict detection `do` block to module scope (runs once at load, not every tick), (b) simplified debug block to just log output, (c) moved control panel callback registration to module scope alongside other callback registrations. Net result: ~6 upvalues eliminated from `on_update()`.

3. **.gitignore updated** - Added `*.zip` (except plugins-listing), `sylvanas-dev-docs-llm/`, and `.api/` to prevent temp files from being tracked.

### ✅ Completed This Session (2026-03-21) — Third Pass (TBC Rewrite Sweep)

#### P1 rewrites completed
1. **Hunter Survival** - Removed WotLK-only `Explosive Shot` and rebuilt the spec as a TBC trap/utility rotation around `Serpent Sting`, `Aimed Shot`, `Steady Shot`, and `Mongoose Bite`.
2. **Warlock Demonology** - Removed `Metamorphosis`, `Immolation Aura`, and other non-TBC mechanics; rebuilt around TBC curse/DoT pressure and Shadow Bolt filler.
3. **Mage Fire** - Removed `Hot Streak`/Wrath proc logic and corrected self-buff behavior toward TBC `Mage Armor` usage.
4. **Mage Frost** - Removed `Fingers of Frost` / `Brain Freeze` behavior and returned the spec to a TBC Frostbolt-centered rotation.
5. **Hunter Marksmanship** - Removed `Chimera Shot` and rebuilt the shot priority as TBC `Aimed Shot` / `Serpent Sting` / `Arcane Shot` / `Multi-Shot` / `Steady Shot`.
6. **Paladin Protection** - Removed Holy Power, `Shield of the Righteous`, and `Hammer of the Righteous`; rebuilt around TBC `Holy Shield`, seal/judgement cadence, `Consecration`, `Exorcism`, and `Avenger's Shield`.

#### P2 rewrites completed
7. **Druid Balance** - Removed Eclipse, Starfall, Typhoon, and Berserk logic; rebuilt the rotation around `Moonfire`, `Insect Swarm`, `Starfire` / `Wrath`, `Hurricane`, and `Force of Nature`.
8. **Druid Restoration** - Removed Lifebloom and Wild Growth; rebuilt healing around `Rejuvenation`, `Regrowth`, `Swiftmend`, `Healing Touch`, `Nature's Swiftness`, `Innervate`, and TBC DPS fallback.
9. **Paladin Holy** - Removed Beacon, Divine Plea, Word of Glory, Light of Dawn, and Holy Power logic; restored TBC Holy healing with `Holy Light`, `Flash of Light`, `Holy Shock`, `Divine Illumination`, `Cleanse`, and blessings.
10. **Priest Shadow** - Fixed hostile DoT timing to use debuff APIs, removed Shadow Orb / Wrath contamination, ensured `Shadow Word: Death` executes correctly, and added the missing hostile debuff helper in `utils.lua`.
11. **Warlock Destruction** - Removed `Chaos Bolt`, added curse maintenance, and restored a TBC `Immolate` -> `Conflagrate` -> `Incinerate` / `Shadow Bolt` shell with execute/shard support.
12. **Paladin Retribution** - Removed Holy Power finishers and `Divine Plea`, restored seal/judgement flow, added `Divine Illumination`, and wired missing menu toggles so the rewritten rotation actually executes.
13. **Warrior Arms** - Wired `Thunder Clap` into single-target play, kept `Slam` as the primary filler, and restricted `Whirlwind` to AoE-oriented situations.
14. **Shaman Elemental** - Removed `Lava Burst`, `Thunderstorm`, `Wind Shear`, and `Lava Flood`; restored a TBC `Flame Shock` / `Lightning Bolt` / `Chain Lightning` / `Earth Shock` rotation with existing mana-aware behavior.

#### Verification completed
- `luac -p` passes on every touched Lua file across: `EAXDruidBalance`, `EAXDruidRestoration`, `EAXPaladinHoly`, `EAXPaladinRetribution`, `EAXPriestShadow`, `EAXShamanElemental`, `EAXWarlockDestruction`, and `EAXWarriorArms`.
- `lsp_diagnostics` reports **0 errors** in all eight rewritten spec directories above.
- Root `README.md` now reflects the TBC-accuracy push, including the Holy Paladin `Divine Illumination` correction.

### ✅ Already Implemented (from previous work)

- **Set Bonus Detection** - `eax_shared/set_bonus.lua` (443 lines, 60+ T4/T5/T6 sets)
- **ESP/HUD** - Per-spec `esp_renderer.lua` with spec isolation (state_by_spec)
- **Interrupt Manager** - `eax_shared/interrupt_manager.lua` (262 lines, priority-based)
- **Defensive Manager** - `eax_shared/defensive_manager.lua` (73 lines, HP-threshold tiers)
- **Racial Manager** - `eax_shared/racial_manager.lua` (129 lines, all TBC races)
- **Pet AI** - `EAXHunterBeastMastery/pet_manager.lua` (342 lines, state machine)
- **Shaman Totems** - `eax_shared/totem_manager.lua` (111 lines, bag scanning)
- **Spell Resolution** - `eax_shared/spell_resolver.lua` (85 lines, persistent cache)
- **Combat Context** - `eax_shared/combat_context.lua` (431 lines, throttled to 2s)
- **Reactive Runtime** - `eax_shared/reactive_runtime.lua` (350 lines, cached context)

---

## What Remains

### Immediate / Manual Verification

- **In-game validation still required** for all rewritten specs. Syntax and diagnostics are clean, but the original user requirement was to confirm sluggishness and rotation feel in the live Sylvanas runtime.
- **Priority live checks:**
  - Druid Balance / Restoration cast cadence and mana pacing
  - Holy / Retribution Paladin seal, blessing, and GCD cadence
  - Shadow Priest DoT refresh + `Shadow Word: Death` execute behavior
  - Destruction Warlock curse maintenance and shard spend behavior
  - Arms Warrior `Thunder Clap` frequency in single target
  - Elemental Shaman mana floor behavior without Wrath spells

### Remaining rotation work (lower priority than P1/P2)

#### Follow-up fixes completed after the P2 sweep
- **Affliction Warlock** - Removed lingering `Haunt` contamination from spell/docs and kept `Drain Soul` as the execute filler after DoT/curse upkeep.
- **Assassination Rogue** - Added group-content `Expose Armor` maintenance when neither `Expose Armor` nor `Sunder Armor` is already present, and tightened `Envenom` finisher gating around the existing Deadly Poison requirement.
- **Enhancement Shaman** - Removed lingering `Lava Lash` and `Feral Spirit` assumptions so the combat lane stays on TBC `Stormstrike` / shock / spell-weave behavior.
- **Fury Warrior** - Moved `Overpower` and `Rend` behind the main Fury core so `Bloodthirst` / `Whirlwind` stay primary, and limited `Rend` to true spare Battle Stance windows.
- **Subtlety Rogue** - Rebalanced stealth/control behavior so `Cheap Shot` stays a solo-control opener and `Shadowstep` / `Preparation` no longer pre-empt the steady PvE damage lane.
- **Restoration Shaman** - Tightened stopcast logic to use triage-aware cancellation and fixed Tremor / Grounding totem edge cases around destroyed or already-active totems.
- **Beast Mastery Hunter** - Polished `Kill Command` timing so it only fires once the pet is actually engaged on target, and aligned the menu/docs wording with that behavior.
- **Warrior Protection** - Restored single-target `Thunder Clap` upkeep as a debuff-maintenance utility action and aligned the menu/docs with proactive group-mode `Shield Block` sequencing.

These specs were previously graded as "mostly workable" but still have gaps worth revisiting:

- **Enhancement Shaman** - Remove any lingering Wrath-era `Lava Lash` / `Feral Spirit` assumptions if still present
- **Fury Warrior** - Overpower placement, Rend filler usage, and talent gating cleanup
- **Subtlety Rogue** - PvP utility vs steady PvE rotation balance
- **Restoration Shaman** - Stopcast behavior and Tremor/Totem edge cases

### New API Additions (2026-03-21)
The following Sylvanas API features are now available and could be integrated:

| API | Description | Specs Affected |
|-----|-------------|---------------|
| `core.input.enable_pet_autocast(name)` | Enable pet autocast ability | Hunter (all 3) |
| `core.input.disable_pet_autocast(name)` | Disable pet autocast ability | Hunter (all 3) |
| `core.spell_book.get_pet_action_info()` | Get pet action name, texture, autocast state, range | Hunter (all 3) |
| `core.input.quick_cat()` | Quick cat form (Druid) | Druid (all 3) |
| `obj:get_armor()` | Get unit armor value | Tank specs |
| `core.character.get_combat_rating_bonus()` | Combat rating bonus lookup | All |
| `core.world.is_flyable_area()` | Check if area is flyable | All outdoor |
| `core.world.get_encounters_on_map()` | Boss encounter tracking | Dungeon/Raid |
| `core.game_ui.get_all_completed_quest_ids()` | Quest completion data | Questing |
| `core.game_ui.reset_instances()` | Reset dungeon instances | Group content |
| `core.quests.*` | Full quest log, gossip, trainer, accept/complete API | Questing |
| `core.auction_house.*` | Full AH API: scans, posting, bidding, commodities | Economy |

### Low Priority / Future

- **Shaman Totem Items** - May need `core.input.use_item()` for core totem items in bag
- **Buff Manager** - `common/modules/buff_manager` require may fail (path doesn't exist on disk)

---

## Reference Files

| Purpose | Location |
|---------|----------|
| Complete spell lists | `/c/618497f1/scripts/tbc/sim/*/` |
| Set bonus implementation | `/c/618497f1/scripts/tbc/sim/core/item_sets.go` |
| Rotation examples | `/c/618497f1/scripts/PublicGithubs/BRLite-main/` |
| Rotation examples | `/c/618497f1/scripts/PublicGithubs/ni-main/` |
| Sylvanas API docs | `/c/618497f1/scripts/sylvanas-dev-docs-llm/` |

---

## Commands

```bash
# Clone (if not already)
git clone https://github.com/eaxiumnet/eax-tbc-classic-rotations.git
cd eax-tbc-classic-rotations

# Pull latest
git pull

# Push changes
git add -A && git commit -m "feat: description" && git push
```
