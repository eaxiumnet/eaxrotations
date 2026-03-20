# Plan 02 Summary — Threat Estimation & Fade Protection

**Plan**: 02-core-combat-02
**Completed**: 2026-03-20
**Wave**: 2 (depends on 02-core-combat-01)

## Deliverables

### `eax_shared/threat_manager.lua` (362 lines)
- Combat log handler registration via `core.combat_log.add_event_handler()`
- Party/raid tank detection (Warrior, Paladin, Druid Bear form, Death Knight WotLK-safe)
- Threat tracking per guid with class-based multipliers
- Exports: `init`, `should_fade`, `get_tank_threat`, `get_player_threat`, `get_tank_guid`, `reset`, `on_combat_log_event`
- `THREAT_MULTIPLIERS` table for major tank abilities (Heroic Strike, Shield Slam, Mangle, etc.)
- Fade logic: returns true when player threat ≥ 90% of tank threat
- All API calls wrapped in pcall for safety
- `try_fade()` helper that issues `/cast Fade` via Sylvanas API

### Integration into all 27 spec main.lua files
- **threat_manager.init(me)** called in all 27 specs (at startup)
- **threat_manager.should_fade(me, target)** checked in **15 non-tank specs** before main damage rotation:
  - **Included**: Warrior Arms/Fury, Hunter BM/MM/Survival, Mage Arcane/Fire/Frost, Warlock Aff/Demo/Destro, Priest Shadow, Druid Balance/Restoration
  - **Excluded**: Warrior Prot, Paladin Prot (tank specs), Druid Feral (Feral Tank), Priest Disc/Holy (healers - still check threat but prioritize healing), Shaman specs (hybrid threat profile), Rogue specs
- All requires use proper `---@type threat_manager` annotations
- Fade check placed after OOC/defensive/interrupt checks, before main damage rotation
- All API calls wrapped in pcall

## Verification
- `luac -p` passes on all modified main.lua files and eax_shared/threat_manager.lua
- threat_manager.init called in 27/27 specs
- threat_manager.should_fade checked in 15/27 specs (appropriate exclusions for tanks/healers/hybrids)
- Tank specs (Warrior Prot, Paladin Prot, Druid Feral) do NOT call should_fade
- No syntax errors introduced

## Notes
- Uses combat log events to estimate threat when Sylvanas API doesn't provide direct threat values
- Fallback to unit:get_threat(_) when available from Sylvanas
- Priority-based tank detection: looks for tank classes with aggro on player's target first
- Fade threshold configurable via threat_manager.DEFAULT_FADE_THRESHOLD (0.90)
