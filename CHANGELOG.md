# Changelog

All notable changes to this project will be documented in this file.

## [1.9.0] - 2026-03-18

### Fixed — Critical Rotation Bugs (all 27 specs)

**GCD Interval spam (all specs)**
- `GCD_INTERVAL` and `GCD_CAST_INTERVAL` were set to `0.05s` (50ms) across all specs,
  causing rotations to fire dozens of times per second and spam the spell queue.
  Fixed to correct TBC values: `1.5s` for casters/healers, `1.0s` for melee/rogues/warriors.

**`cast_target` missing cooldown check (Elemental, Mage specs)**
- `utils.cast_target()` queued spells without checking `is_spell_learned` or
  `get_spell_cooldown`, allowing spells on cooldown to re-queue every frame.
  Added both checks to all affected specs.

**Debuff detection on training dummies / special units (all specs)**
- `utils.has_debuff()` only checked `get_debuff_data`, which fails on training
  dummies and some special NPCs. Added `get_aura_data` fallback across all 27 specs.

**Flame Shock time-based anti-spam (Elemental)**
- Added per-target timestamp tracking so Flame Shock won't re-apply within its
  ~12s duration even when debuff detection returns false (e.g. training dummies).

**Lightning Bolt range restriction (Elemental)**
- `range_min` defaulted to 22 yards, blocking Lightning Bolt at melee range.
  Changed default to 0 (no minimum restriction).

**Pending cast timeout too short (Hunter, Enhancement, Elemental)**
- `PENDING_CAST_TIMEOUT_S` was 1.25s — shorter than many spell cast times.
  Increased to 2.5s.

### Fixed — Eating/Drinking Cancellation (all 27 specs)

**`is_eating_or_drinking` rewritten with 3-layer detection**
- Old: matched a small hardcoded list of buff IDs (missed custom server items like `24707`).
- New detection layers applied in order:
  1. `me:is_casting_spell()` — catches eating/drinking mid-cast
  2. `me:is_channelling_spell()` — catches channeled interactions
  3. Aura name scan — searches all active buff names for food/drink keywords
     (`well fed`, `refreshed`, `stew`, `fish`, `bread`, `feast`, etc.)
  4. Original hardcoded IDs as final fallback

**`try_ghost_wolf` direct casting check (Elemental, Enhancement)**
- Added redundant `is_casting_spell` + `is_channelling_spell` checks inside
  `try_ghost_wolf` itself as a belt-and-suspenders guard.

**`ooc_manager.try_group_buff` (all 27 specs)**
- Group buffs (Mark of the Wild, Arcane Intellect, Power Word: Fortitude, etc.)
  could fire while player was eating, cancelling the eat. Added `is_casting_spell`
  and `is_channelling_spell` guards to `try_group_buff` in all 27 `ooc_manager.lua` files.

### Added — Shaman Elemental

- **Water Shield / Lightning Shield maintenance** — Auto mode selects Water Shield
  at level 60+, Lightning Shield below. Configurable per menu.
- **Self-heal (Healing Wave)** — Emergency cast at configurable HP threshold.
  Added to Defensive section in menu.
- **Ghost Wolf OOC** — Automatically shifts to Ghost Wolf when out of combat.
  Respects eating/casting guards.
- **Totemic Call** — Recalls totems for 25% mana refund when OOC and mana < 50%.
- **Shield Mode, Self-Heal, Ghost Wolf, Totemic Call** added to Control Panel.

### Added — Shaman Enhancement

- **Water Shield / Lightning Shield maintenance** — Auto mode (Lightning Shield
  default for melee DPS). Configurable per menu.
- **Self-heal (Healing Wave + Lesser Healing Wave)** — Emergency cast at
  configurable HP threshold; prefers Lesser HW when available (faster/cheaper).
- **Ghost Wolf OOC** — Auto-shift out of combat for faster travel.
- **Lightning Bolt ranged pull** — Opens with LB on targets beyond configurable
  range (default 25yd) before closing to melee.
- **Shield Mode, Self-Heal, LB Pull, Ghost Wolf** added to Control Panel.

### Added — Conflict Detection (all 27 specs)

- Each spec registers itself in `_G.__EAX_LOADED` at load time.
- At runtime, if 2+ specs of the same class are **enabled simultaneously**, a
  warning fires: console log + in-game notification every 10 seconds.
- Warning only triggers when specs are actually enabled — not just installed.

### Added — ESP Guard (all 27 specs)

- `on_render` callback now checks `menu.enabled:get_state()` before rendering.
  Disabled specs no longer draw their HUD/ESP overlay.

### Added — Control Panel collapse-on-disable (all 27 specs)

- Control panel sub-items only appear when the spec's master toggle is enabled,
  preventing the panel from filling the screen with disabled specs.

### Fixed — Menu Deduplication (Shaman Elemental, Enhancement)

- Duplicate "Out-of-Combat" tree nodes removed. All OOC options (shields,
  ghost wolf, self-heal, totemic call, LB pull) are now rendered inside the
  existing `ps.render_ooc()` call — no extra tab.

### Fixed — Defensive Section "(none configured)" (Elemental, Enhancement)

- Elemental: now shows Emergency Healing Wave with HP threshold slider.
- Enhancement: now shows Emergency Healing Wave + Shamanistic Rage note.

### Fixed — Stormstrike ID scan (Enhancement)

- Added broader fallback ID scan on load. Logs which ID resolves or whether
  the talent hasn't been learned yet.

### Changed — version bump

- All 27 `plugin_info.lua` files updated to `1.9.0`.
- 19 specs that were missing `plugin_info.lua` now have one.

---

## [1.2.0] - 2026-03-16

### Added — New Shared Modules (`common/eax_shared/`)
- **`racial_manager.lua`** — Unified racial ability system for all TBC races:
  - Offensive: Blood Fury (Orc), Berserking (Troll)
  - Utility/Interrupt: Arcane Torrent (Blood Elf), War Stomp (Tauren)
  - Defensive: Stoneform (Dwarf), Escape Artist (Gnome), Will of the Forsaken (Undead)
  - Wired into all 23 combat plugins via `racial_manager.try_offensive()` and `racial_manager.try_utility()`
- **`ttd_tracker.lua`** — Per-target rolling time-to-death estimator:
  - 10-second sliding window, HP loss rate calculation
  - `ttd_tracker.update(target)` wired into 20 DPS spec rotations
  - `ttd_tracker.is_dying(target, threshold_s)` for execute-phase gating
- **Updated `__init__.lua`** — exports all 9 shared modules

### Added — Spec-Specific Rotation Improvements
- **Warrior Arms**: Charge (pre-combat opener), Death Wish, Recklessness, Sweeping Strikes,
  Enraged Regeneration (≤70% HP), Pummel interrupt wired into rotation
- **Paladin Retribution**: Divine Storm, Avenging Wrath (syncs with burst window)
- **Shaman Enhancement**: Lava Lash (talent-gated), Feral Spirit (talent-gated),
  weapon imbue maintenance (Windfury MH + Flametongue OH, throttled 30s)
- **Druid Feral**: Demoralizing Roar (bear, debuff-checked), Maim (cat, interrupt fallback)
- **Rogue Combat**: Killing Spree (wired after Adrenaline Rush)
- **Mage Arcane**: interrupt call wired (was imported but not called)
- **Hunter Survival**: interrupt call wired (was imported but not called)

### Fixed
- Systematic mangled-code bug across all plugins: racial_manager injection had been
  merged into the interrupt_manager.try_interrupt() call, creating invalid Lua.
  All 15 affected plugins repaired.
- HunterSurvival: TTD tracker was inserted inside the defensive_manager block
  (inside the `then...end`), causing it to only run when a defensive was triggered.
  Moved to correct position before defensive check.

---

## [1.1.0] - 2026-03-16

### Added
- **Comprehensive TBC Spell Database** - Complete spell ID mappings for all 29 specs
- **Racial Abilities** - Added to spells.lua across all classes
- **Consumables & Gear Support** - Potions, scrolls, engineering, trinkets
- **Pet System** - Hunter and Warlock pet coverage
- **Utility Spells** - Disengage, Feign Death, Traps, Weapon imbues, etc.
- **Shared Modules** (`common/eax_shared/`):
  - `interrupt_manager.lua` — priority-based interrupt system (all 23 combat plugins)
  - `defensive_manager.lua` — layered HP-threshold defensive system (all 27 plugins)
  - `spell_resolver.lua` — unified spell ID resolution with caching
  - `mode_detector.lua` — solo/dungeon/raid detection
  - `target_finder.lua` — consistent target selection
  - `pet_manager.lua` — Hunter/Warlock pet helpers
  - `talents.lua` — talent detection helpers

### Fixed
- 5 critical bugs from v1.0.0:
  1. WarlockAffliction: `try_apply_curse()` — undefined `me` variable
  2. WarlockAffliction: Shadow Bolt filler — inverted conditional
  3. MageArcane/Fire/Frost: `try_ice_block` called but never defined
  4. RogueCombat: `try_evasion` called but never defined
  5. HunterSurvival/Marksmanship: `try_mend_pet` called but never defined

---

## [1.0.0] - 2026-03-16

### Added
- Initial EAX TBC rotation plugins — all 27 specs
- Base architecture: main.lua, menu.lua, spells.lua, utils.lua
- Focus target priority, self-emergency healing
- Mode detection (solo/dungeon/raid)

## [1.2.1] - 2026-03-17 (patch)

### Added
- **Hunter (all 3 specs)**: Disengage (kite when target ≤8yd) and Feign Death
  (emergency threat drop ≤30% HP) wired into all three Hunter rotations
- **Shaman Elemental**: Lava Burst wired — casts when Flame Shock is on target
  (guaranteed crit interaction)
- **Warlock Affliction**: Howl of Terror wired as AoE emergency fear (≤40% HP,
  ≥1 melee attacker)
- **Priest Shadow**: Devouring Plague added to DoT refresh cycle alongside
  Vampiric Touch and Shadow Word: Pain

### Fixed
- **TTD positioning bug** (affected 12 plugins): `ttd_tracker.update(target)` had
  been inserted *inside* the `defensive_manager.try_defensive` block during the
  prior patch, meaning TTD samples only collected when a defensive CD was triggered.
  Moved to correct position before the defensive check in all affected specs:
  WarlockAffliction, WarlockDemonology, WarlockDestruction, RogueAssassination,
  RogueCombat, RogueSubtlety, ShamanElemental, PaladinRetribution, MageFire,
  MageFrost, HunterBeastMastery, HunterMarksmanship, PriestShadow

## [1.3.0] - 2026-03-17

### Added — From tbc/ simulator + OldClasses reference analysis

**Rogue (all 3 specs)**
- **Feint** wired into all three specs (Combat, Assassination, Subtlety) — threat
  drop in dungeon/raid mode; does not fire in solo
- **Expose Armor** (Combat only) — 5-CP finisher on bosses when neither Expose
  Armor nor Sunder Armor is active on the target
- **Rupture TTD gating** — Rupture is now skipped when `ttd_tracker` estimates
  the target will die within 12 seconds, preventing wasted combo points
  (pattern from tbc/ rogue/rotation.go)

**Warlock Affliction**
- **Amplify Curse properly wired** — cast immediately before every Curse of
  Doom / Curse of Agony application when the talent is learned (was in
  spells.lua but the cast was broken; now calls `cast_self_fast` correctly)
- **Improved Life Tap pre-regen** — also taps when mana < 50% even if above
  the normal threshold, to prepare for the next burst window (pattern from
  warlock/rotations.go mana regen logic)

**Hunter (all 3 specs)**
- **Auto Shot clip buffer** — instant-cast spells (Serpent Sting, Arcane Shot,
  Multi-Shot, Kill Command) are now blocked within 200ms of the next Auto Shot
  timer. Prevents clipping the auto-attack cycle. Pattern from
  OpenHunter2/engines/shared.lua `allow_instant()`

**Druid Feral (Bear)**
- **Lacerate** — full DoT stack maintenance added to bear rotation. Builds to
  5 stacks, then refreshes when < 3s remaining. Priority: Mangle > Lacerate >
  Swipe. Key TBC bear ability for both threat and DPS.

**Shaman Enhancement**
- **Searing Totem / Magma Totem maintenance** — fire totem is now maintained
  automatically. Uses Searing Totem for single targets, Magma Totem for 3+
  enemies. Throttled to avoid GCD waste; skipped while moving.

## [1.4.0] - 2026-03-17

### Warlock (all 3 specs)
- **Pet selection by scenario** — automatically summons the correct pet when out of combat: Imp in raid, Felhunter in dungeon, Voidwalker in solo. Demonology overrides to Felguard when talented. Pattern from OpenWarlock2/systems/pet.lua
- **Soul Shard farming** — Drain Soul now fires automatically on targets ≤10% HP when shard count is below the menu threshold (Affliction, Demonology, Destruction)
- **Seed of Corruption AoE** — Affliction and Destruction now cast Seed of Corruption on packs of 3+ enemies as the AoE priority spell

### Hunter (all 3 specs)
- **Scorpid Sting** — applied in dungeon/raid mode when not already present (armor reduction debuff)
- **Viper Sting** — applied on mana-using targets when not active
- **Rapid Fire** — burst CD wired into all 3 Hunter rotations on combat start
- **Intimidation** — Beast Mastery only; wired after Kill Command in burst window
- **Aspect of the Viper** — automatic switch at <20% mana; reverts to Hawk at ≥90% mana

### Rogue (all 3 specs)
- **Shiv** — fires automatically when Deadly Poison has <2 seconds remaining on target, refreshing the poison without consuming a combo point (Combat and Assassination)

### Druid Balance
- **Hurricane** — fires on packs of 4+ enemies when mana ≥40% (AoE priority)
- **Adaptive nuke** — when mana drops below 30%, Wrath replaces Starfire as the filler (cheaper cost, maintains DPS). Pattern from tbc/ balance/rotation.go

### Druid Feral
- **Rake trick** — when energy is in the 35–55 window and Rake is not on target, Rake fires as an energy sink rather than waiting for the next tick. From tbc/ feral/rotation.go
- **Rip TTD gating** — Rip is skipped when TTD < 12s (fight ending, DoT won't tick fully)

### Shaman Enhancement
- **Totem Twist** — Windfury Totem re-dropped every 10 seconds for the proc, Wrath/Grace of Air maintained in between. Pattern from tbc/ enhancement/rotation.go
- **Strength of Earth Totem** — maintained automatically (throttled 30s)
- **Mana Spring Totem** — maintained automatically (throttled 30s)

### Priest Shadow
- **Vampiric Embrace** — buff maintained automatically before the DoT refresh cycle
- **Inner Fire** — buff maintained when menu toggle enabled
- **Shadow Word: Death** — fires at target ≤25% HP or TTD <4s as an execute spell

### Priest Discipline
- **Power Word: Shield** — maintained on self and party when HP <80% and Weakened Soul not active
- **Penance** — fires on targets <70% HP (talent-gated via spell resolution)

### Paladin Holy
- **Divine Plea** — fires automatically at <50% mana for mana recovery
- **Judgment of Wisdom** — applied to the target in dungeon/raid for mana return

### Paladin Protection
- **Hammer of Justice** — wired as interrupt backup when Shield Bash is on cooldown

### Mage (all 3 specs)
- **Frost Nova** — fires when a melee enemy is within 8 yards as a kite tool
- **Presence of Mind** — Arcane only; fires when Arcane Power is active

### interrupt_manager (shared)
- **Dangerous spell priority whitelist** — spells like Polymorph (80), Howl of Terror (75), Flash Heal (70) now have priority weights, enabling smarter interrupt targeting. Added `interrupt_manager.get_priority(target)`. Pattern from OpenWarrior2/core/interrupt_library.lua

## [1.5.0] - 2026-03-17

### New Shared Modules (`common/eax_shared/`)

**`ooc_manager.lua`** — Out-of-combat utility system, wired into all 27 specs
- **Auto-drink** — scans bags via `inventory_helper` for food/drink items and uses
  them when mana < threshold, OOC, not moving. Falls back to a hardcoded TBC
  consumable ID list. Throttled 3s to avoid double-use.
- **Auto-eat** — same logic for HP when below threshold
- **Party resurrection** — scans party for dead (non-ghost) members and casts
  the spec's rez spell. Prioritises healers then tanks by group role.
  Spec mapping: Druid → Rebirth (in-combat eligible), Priest → Resurrection,
  Paladin → Redemption, Shaman → Ancestral Spirit, others → none
- **Group buffs** — applies the spec's signature group buff to party members
  missing it, OOC only. Spec mapping: Mage → Arcane Intellect,
  Priest → Power Word: Fortitude, Paladin → Blessing (by role),
  Druid → Mark of the Wild, others → none
- All actions gated behind `menu.ooc_drink`, `menu.ooc_eat`, `menu.ooc_rez`,
  `menu.ooc_group_buff` toggles

**`esp_renderer.lua`** — In-world and on-screen visual overlay, wired into all 27 specs
- **Next-action HUD** (`menu.esp_show_hud`) — 2D panel drawn at a
  configurable screen position showing:
  - Spell icon (loaded by spell ID via `icons_helper:draw_spell_icon`,
    auto-downloaded from Wowhead CDN and disk-cached)
  - Spell name in the spec's colour
  - "Next action" sub-label
  - Proc indicator bars (registered per-spec via `esp_renderer.add_proc`)
- **Target ESP text** (`menu.esp_show_target`) — `"▶ Spell Name"` rendered
  as 3D world text floating 2.2 units above the current target's position,
  colour-coded by spell type
- **Notification wrapper** — `esp_renderer.notify(id, label, msg, dur, col)`
  used consistently across all specs instead of ad-hoc notification calls
- **`esp_renderer.on_cast(spell_id, name, color)`** — called from key try_
  functions so the HUD and ESP text update in real time as the rotation decides

### Spell additions (spells.lua)
Added resurrection and group buff spell IDs to all relevant specs:
Redemption (Paladin), Resurrection (Priest), Ancestral Spirit (Shaman),
Rebirth (Druid), Arcane Intellect (Mage), Power Word: Fortitude (Priest),
Blessing of Might / Sanctuary / Wisdom (Paladin), Mark of the Wild (Druid)

## [1.5.1] - 2026-03-17 (patch)

### Fixed — interrupt_manager.lua (TBC accuracy)
- **Shaman**: Replaced Wind Shear (57994, Wrath patch 3.1) with Earth Shock
  (all ranks 49→10414). Earth Shock is the correct TBC interrupt for Shaman.
- **Hunter**: Added Silencing Shot (34490) as a secondary interrupt for
  Marksmanship talent. Counter Shot remains the primary.
- **Warlock**: Added Spell Lock (24259) via Felhunter pet as an interrupt option.
- **Druid**: Replaced Skull Bash (80965, Cataclysm) with Bash (stun, all ranks)
  and Cyclone (last resort). Skull Bash did not exist in TBC.

### Fixed — defensive_manager.lua
- **Rogue**: Added Cloak of Shadows (31224) — dispels all magic debuffs.

### Fixed — WarlockAffliction
- Added `spells.AMPLIFY_CURSE = { 18288 }` to spells.lua (was wired in main.lua
  but the spell table entry was missing, so `resolve_spell_id` always returned nil).

### Added — menu.lua (all 27 specs)
OOC and ESP menu toggles added to every plugin's menu.lua:
- `ooc_drink` / `ooc_eat` — auto eat/drink toggles (default: on)
- `ooc_rez` — party resurrection toggle (default: on)
- `ooc_group_buff` — group buff toggle (default: on)
- `drink_threshold` / `eat_threshold` — mana/HP percentage sliders (default: 80%)
- `esp_show_hud` — next-action HUD panel (default: on)
- `esp_show_target` — 3D ESP text above target (default: on)
- `esp_hud_x` / `esp_hud_y` — HUD position sliders

### Fixed — esp_renderer on_cast wiring
- EAXPriestDiscipline: wired `on_cast` into `try_pw_shield` and `try_penance`
- EAXPriestHoly: wired into `try_greater_heal`, `try_prayer_of_healing`, `try_renew`
- EAXWarriorProtection: wired into Shield Slam / Revenge / Devastate log sites
- EAXPaladinProtection: wired into `try_avengers_shield` and `try_consecration`

## [1.6.0] - 2026-03-17

### Implemented — previously deferred hard items

**Druid Feral: Powershift energy economy**
- `try_powershift()` added to cat rotation as the last-resort low-energy action
- Wolfshead Helm (item 8345) detection: 30-energy threshold, 1.2s minimum interval
- Without Wolfshead: 15-energy threshold, 2.0s interval (smaller gain, less benefit)
- Shifts back to cat form automatically via the existing `try_cat_form` logic on the next tick
- Menu toggle: `menu.use_powershift`

**Warrior Arms: Berserker Rage**
- Wired as a rage-generation CD in the burst block alongside Death Wish / Recklessness
- Requires Berserker Stance (guards against accidental use in Battle Stance)

### Meta build gaps (from Icy Veins / Wowhead TBC audit)

**Paladin Retribution**
- **Consecration** — filler GCD after Crusader Strike when all primary CDs are on cooldown
- **Divine Favor** — pre-cast to guarantee Holy Shock crit; fires before Divine Storm
- **Exorcism** — wired for Undead and Demon targets only (TBC restriction)

**Rogue Combat + Assassination**
- **Garrote** — stealth opener: silences for 3s, applies a strong bleed, higher DPS
  than Ambush for both specs. Fires only when Stealth buff is active.
- **Riposte** (Combat only) — fires immediately after a parry; disarms target 6s

**Hunter (all 3 specs)**
- **Pre-combat opener sequence** — `try_execute_opener()`: sends pet, applies
  Hunter's Mark, starts Auto Shot; fires only when out of combat.
  Pattern from OpenHunter2/engines/shared.lua `execute_opener()`

### interrupt_manager — TBC accuracy (patch 1.5.1 additions confirmed)
- Earth Shock (all ranks) replaces Wind Shear for Shaman
- Silencing Shot (34490) added for Marksmanship Hunter
- Spell Lock (24259, Felhunter) added for Warlock
- Bash + Cyclone replaces Skull Bash for Druid (Skull Bash = Cataclysm)

## [1.6.1] - 2026-03-17 (bugfix patch)

### Fixed — Warrior Arms: Recklessness stance dance
- **Bug**: `try_recklessness` checked for `BUFF_BERSERKER_STANCE` but Arms
  home stance is Battle — meaning Recklessness would never fire in Arms.
- **Fix**: Arms now dances to Berserker Stance to cast Recklessness, then
  sets `pending_battle_stance_return` to swap back to Battle on the next tick.
  Pattern matches the tbc/ simulator's Recklessness handling for Arms.

### Fixed — Warrior Fury: Thunder Clap single-target maintenance dance
- **Bug**: TC only fired in the AoE lane during the Sweeping Strikes window
  (Battle Stance already active). Single-target had no TC dance at all.
- **Fix**: Added `try_thunder_clap_dance` — Battle → TC → return to home stance.
  `try_tc_dance_return` fires at the top of the core lane to resolve the stance
  swap immediately. Fires in dungeon/raid mode only (not worth the GCD in solo).
  Pattern from tbc/ warrior/dps/rotation.go `tryMaintainDebuffs`.

### Added — v1.6.0 recap

**Druid Feral: Powershift** — `try_powershift()` with Wolfshead Helm detection

**Warrior Arms: Berserker Rage** — rage gen CD during execute phase

**Paladin Retribution: Consecration + Divine Favor + Exorcism**
- Consecration as filler after Crusader Strike
- Divine Favor before Divine Storm for guaranteed crit
- Exorcism on Undead/Demon targets only (TBC restriction)

**Rogue Combat + Assassination: Garrote + Riposte**
- Garrote stealth opener (higher DPS than Ambush for both specs)
- Riposte (Combat only) after parry — disarms target 6s

**Hunter (all 3 specs): Pre-combat opener sequence**
- `try_execute_opener()`: pet → Hunter's Mark → Auto Shot, OOC only

### Confirmed working (audit verified)
- Paladin Retribution Seal Twist: Command → Blood → Righteousness → Command ✓
- Warrior Fury stance dance (Overpower, Rend, WW): ✓
- Warrior Protection home-stance (Defensive): ✓
- interrupt_manager TBC spell IDs (Earth Shock, Silencing Shot, Spell Lock, Bash): ✓

## [1.7.0] - 2026-03-17

### Fixed
- **header.lua (all 27 plugins)** — removed `require("common/enums")`.
  Sylvanas resolves paths relative to the plugin folder, not the API root.
  All headers now use raw TBC class IDs (no import needed):
  WARRIOR=1, PALADIN=2, HUNTER=3, ROGUE=4, PRIEST=5, SHAMAN=7, MAGE=8, WARLOCK=9, DRUID=11

### Added — Leveling system (1–70)
**New shared module: `common/eax_shared/leveling_manager.lua`** — wired into all 27 specs

- **Wand system** (Mage/Warlock/Priest/Druid Balance/Shaman Elemental):
  `try_wand()` starts wand via `auto_attack_helper:start_attack(WAND=5019)`;
  wands when mana < 25% (configurable) or target HP < 20% (configurable);
  detects active wanding via `core.spell_book.is_current_spell(5019)`
- **Mana conservation**: blocks rotation below `leveling_mana_floor` (default 20%);
  falls through to wand/melee fallback
- **Melee fallback** (all DPS specs): `ensure_melee()` via `auto_attack_helper:start_attack(MELEE=6603)`
- **Ranged fallback** (Hunter specs): `ensure_ranged()` via `auto_attack_helper:start_attack(RANGED=75)`
- **Spirit Tap** (Priest Shadow): wand-finishes targets < 25% HP when Spirit Tap buff is not active
- **Healers**: `try_wand()` called as fallback at enemy rather than melee
- **6 new menu toggles per spec**: use_wand, wand_mana_floor, wand_at_hp,
  leveling_mana_floor, leveling_conserve_mana, use_spirit_tap_wand

### Added — Encounter system (all TBC dungeons + raids)
**New shared module: `common/eax_shared/encounter_manager.lua`** — wired into all 27 specs

Boss database covering every TBC instance:
- Hellfire Citadel (Ramparts, Blood Furnace, Shattered Halls)
- Coilfang Reservoir (Slave Pens, Underbog, Steamvault)
- Auchindoun (Mana-Tombs, Auchenai Crypts, Sethekk Halls, Shadow Labyrinth)
- Caverns of Time (Old Hillsbrad, Black Morass)
- Tempest Keep dungeons (Mechanar, Botanica, Arcatraz)
- Magisters' Terrace
- Karazhan (all 11 bosses)
- Gruul's Lair + Magtheridon's Lair
- Serpentshrine Cavern (all 6 bosses)
- The Eye / Tempest Keep raid (all 4 bosses)
- Hyjal Summit (all 5 bosses)
- Black Temple (all 9 bosses)
- Zul'Aman (all 6 bosses)
- Sunwell Plateau (all 6 bosses)

**Encounter policy fields applied to rotations:**
- `hold_cooldowns` — gates burst CDs (Icy Veins, Arcane Power, Bestial Wrath, etc.)
  on 39 rotation functions across all specs
- `aoe_safe` — blocks AoE spells (Blizzard, Flamestrike, Volley, Hurricane, etc.)
  on bosses where AoE causes wipes (Blackheart the Inciter, Leotheras, Lady Vashj, etc.)
- `interrupt_priority` — signals that the current target has high-priority interruptable casts
- `force_decurse` / `force_dispel` — override threshold-based dispel to always dispel
- `avoid_close_range` / `min_range` — keep distance on knockback/cleave bosses
  (Gruul 18yd, Void Reaver 20yd, Murmur 15yd, Shade of Aran 18yd, Kael'thas 18yd)
- `tank_damage_heavy` / `raid_aoe_heavy` — healer specs adjust priority
- `pet_follow` / `disable_pet_attack` — pet control for MC/AoE bosses
- Detection via `unit:get_name()` + `unit:is_boss()` + `unit:get_classification()`;
  cached 2s; falls back to scanning all objects for elite+ units

## [1.8.0] - 2026-03-17

### Added — Animated menu system (eax_menu.lua)
**New shared module: `common/eax_shared/eax_menu.lua`** — "Void Drift" aesthetic

Spacey, minimalist, frosted-glass feel inspired by the Project Sylvanas developer
profile design language (deep void + violet/indigo/purple palette).

Visual elements (all drawn via documented `core.menu.window` API):
- **Deep space background** — near-black base (`#06041266`) with radial gradient corner
  accents in deep violet/indigo pulling from PS website colors (`#8b5cf6`, `#a855f7`,
  `#9333ea`). Semi-transparent frosted glass effect at 82% opacity.
- **Drifting dust particles** — 26 tiny purple motes (radius 0.4–1.8px) that slowly drift
  with sine-wave alpha pulsing. Very subtle — barely visible unless staring.
- **Twinkling stars** — 18 static points that twinkle at random speeds. Occasional
  larger bright stars with higher opacity.
- **Rare meteors** — up to 3 simultaneous meteors. ~0.3% spawn chance per frame, appear
  in the upper half, drift diagonally with a gradient trail that fades from
  `rgba(210,170,255)` to transparent. Brief bright head dot. Fade in/out on birth/death.
- **Header banner** — gradient strip with accent dot, title, version badge
- **Section separators** — `eax_menu.separator(win, "Label")` for named section breaks
- **Subsection styling** — `eax_menu.render_section(tree_node, label, fn)` prefixes ◆ bullet

API:
```lua
local eax_menu = require("common/eax_shared/eax_menu")
-- Full animated panel (replaces bare window usage):
eax_menu.render_panel(win, "Title", "v1.0", function(w)
    menu.main_tree:render("General", function() ... end)
    eax_menu.separator(w, "Leveling")
    ...
end)
-- Particle background for inline tree_node menus:
eax_menu.tick_background_particles(win, pos_offset, width, height)
```

### Added — creature_utils.lua
**New shared module: `common/eax_shared/creature_utils.lua`** — creature type gating

All checks use `unit:get_creature_type()` with `enums.creature_type.*`:

| Function | Returns true for |
|---|---|
| `is_bleed_immune(target)` | Undead, Elemental |
| `is_banishable(target)` | Demon, Elemental |
| `is_polymorphable(target)` | Humanoid, Beast, Critter |
| `is_beast(target)` | Beast |
| `is_hibernatable(target)` | Beast, Dragonkin |
| `is_undead(target)` | Undead |
| `is_turn_evailable(target)` | Undead, Demon |
| `is_demon(target)` | Demon |
| `is_elemental(target)` | Elemental |
| `get_name(target)` | string name of creature type |

Imported in: EAXDruidFeral/Balance/Restoration, all 3 Warlocks, all 3 Mages,
all 3 Hunters, all 3 Priests, all 3 Paladins (18 specs total)

### Changed — EAXDruidFeral: powershifting via `core.input.quick_cat`
`try_powershift()` now uses `core.input.quick_cat()` first.

This is the PS implementation of `/cast !Cat Form`:
- Casts Cat Form **while already in Cat Form** without dropping the form first
- Zero downtime — no brief caster-window between shifts
- Triggers Wolfshead Helm energy restore and on-shift talent procs
- Falls back to normal `cast_self()` on servers without `quick_cat` support

Energy thresholds preserved: Wolfshead threshold=30, plain threshold=15.
Interval limiter preserved: Wolfshead min_interval=1.2s, plain=2.0s.

### Changed — EAXDruidFeral: bleed immunity via creature_utils
`try_rip()` and `try_rake()` now gate on `creature_utils.is_bleed_immune()`.
Undead and Elemental targets are bleed-immune in TBC — Rip and Rake will not
be applied. Rotation falls through to Shred/Ferocious Bite as energy dump.
Real DPS improvement in Undead-heavy zones (Stratholme, Naxxramas, etc).

### Added — EAXWarlockDemonology: try_banish with creature_type gating
`try_banish()` added to the cat rotation. Banish only applied when:
- `creature_utils.is_banishable(target)` → true (Demon or Elemental)
- `menu.use_banish` is enabled
- Target not already banished
Checked before Shadowfury in the priority chain.

## [1.8.1] - 2026-03-17 — Hotfix: header.lua load failures

### Fixed — All 27 EAX header.lua files

**Root cause:** `require(".api/common/enums")` in header.lua resolves relative to the
*plugin folder*, landing at `scripts\EAXDruidBalance\.api\common\enums.lua` which does
not exist. This prevented all 27 EAX plugins from loading — headers failed before
main.lua could run.

Note: `require(".api/common/...")` in `main.lua` and `utils.lua` resolves from the
*scripts root* and correctly reaches `scripts\.api\common\...`. Only `header.lua`
uses plugin-relative resolution. This is a Sylvanas loader quirk.

**Fix:** Removed all `require(".api/common/enums")` from every `header.lua`.
Replaced `enums.class_id.*` references with raw TBC class integers:
- WARRIOR=1, PALADIN=2, HUNTER=3, ROGUE=4, PRIEST=5, SHAMAN=7, MAGE=8, WARLOCK=9, DRUID=11

Additionally fixed `utils.lua` files that used `enums.power_type.*` with the same
bad require — replaced with raw power type integers:
- MANA=0, RAGE=1, FOCUS=2, ENERGY=3

**Files changed:** 27 × header.lua, 13 × utils.lua

**Not our errors (separate platform issues):**
The error log also shows failures in BGBOT, core_lua, core_universal_*, dev_developer_tools,
EAXFishing, OpenNavNPC, SentinelGather, SentinelNavClient — these are third-party/platform
scripts not part of the EAX package.
