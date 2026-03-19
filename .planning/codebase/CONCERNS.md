# CONCERNS - Technical Debt & Issues

## High Priority

### 1. Set Bonus Detection (BLOCKING)
**Status**: Only truly missing feature per AGENTS.md

- Current `TBC_SETS` table in `utils.lua` is hardcoded
- Should use `ItemSetXxx.CharacterHasSetBonus()` from reference Go code
- No dynamic set detection from equipped gear

**Affected files**: All 27 `utils.lua` files

**Reference**: `/c/618497f1/scripts/tbc/sim/core/item_sets.go`

### 2. Combo Points for TBC (FIXED v2.1.0)
**Status**: Fixed

- Was calling `target:get_power()` which always returns 0
- Fixed to `me:get_power(enums.power_type.COMBOPOINTS_TBC)`
- Affected: All Rogue and Druid Feral specs

## Medium Priority

### 3. Shaman Totem Items
**Status**: Known limitation

- TBC requires core totem items in bag (Air Totem 5178, etc.)
- Spell resolution may fail if items not in bag
- May need `core.input.use_item()` instead of spell casting

**Affected specs**: EAXShamanElemental, EAXShamanEnhancement, EAXShamanRestoration

### 4. Spec Conflict Detection
**Status**: Runtime warning only

- Current: Warns if 2+ specs of same class enabled
- Should: Prevent simultaneous loading entirely
- No class-level mutex implementation

**Location**: Each `main.lua` has conflict detection block at bottom

### 5. Duplicate Spell Definitions
**Status**: Code duplication

- Many specs have identical `interrupt_manager.lua`, `defensive_manager.lua`, etc.
- Should be extracted to shared `common/` modules
- Currently 27 copies of each manager

**Examples**:
- `interrupt_manager.lua`: 27 identical copies
- `defensive_manager.lua`: 27 copies with class-specific sections
- `encounter_manager.lua`: 27 copies (could be shared)

## Low Priority

### 6. No Automated Testing
- No test framework exists
- All testing manual
- High risk of regressions

### 7. ESP/HUD Icon Caching
**Status**: Recently improved

- Added icons_helper integration with caching
- Icon loading could still be optimized

**Location**: All `esp_renderer.lua` files

### 8. Menu Default Changes (v2.1.0)
Multiple abilities changed from false→true by default:
- Tranquility (Balance Druid)
- Rupture (Rogue Assassination)
- Prepull Totems (Shaman specs)
- Bloodlust on pull
- Purge (Shaman Restoration)
- Seal Twisting (Paladin Retribution)

These may affect existing users who relied on disabled-by-default behavior.

## Resolved Issues

### Rank 1 Bug (FIXED)
- `resolve_spell_id` was iterating backwards
- Always returned rank 1 instead of highest learned
- Fixed to iterate forwards

### Target Range Cap (FIXED v2.1.0)
- No range limit on hostile engagement
- Fixed: 30 yard limit on non-attacking hostiles

### Form Management (FIXED v2.1.0)
- Travel Form now default OOC form
- Combat forms only engage when in combat

### Mark of the Wild (FIXED v2.1.0)
- `ooc_mark_of_the_wild_id` declared but never resolved
- Now properly wired

## Performance Considerations

- `refresh_missing_runtime_spell_ids()` called every tick when spells missing
- `update_set_bonus()` throttled to 5s intervals
- `mode_cache` refreshes every 5s
- OOC group buff scan throttled to 5s
- Encounter policy cached for 2s TTL

## Security

- No sensitive data in code
- No API keys or tokens
- No network calls
- Safe for public repository
