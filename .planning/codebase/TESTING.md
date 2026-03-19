# TESTING - Test Structure & Practices

## Testing Approach

**Manual testing only** - no automated test framework exists.

### Manual Verification Methods

1. **Toggle On/Off**: Enable/disable via menu toggle
2. **Debug Logging**: `menu.debug` checkbox enables logging
3. **ESP Overlay**: Visual feedback for casts and state
4. **Notifications**: `core.graphics.add_notification()` for alerts

### Debug Pattern
```lua
function utils.log_debug(menu_ref, msg)
    if menu_ref.debug:get_state() then
        core.log("[EAX Warrior Arms] " .. msg)
    end
end
```

### Runtime Validation

Spell resolution validated at runtime:
```lua
function utils.resolve_spell_id(rank_table)
    for i = 1, #rank_table do
        if core.spell_book.is_spell_learned(rank_table[i]) then
            return rank_table[i]
        end
    end
    return nil
end
```

If spell not learned, returns nil - spec handles gracefully.

## No Test Framework

- No Lua test libraries (busted, luaunit, etc.)
- No CI/CD pipeline
- No automated test execution
- No test coverage tracking

## Validation Checklist (Manual)

When testing a spec:

- [ ] Spell resolution works for all ranks
- [ ] All menu toggles function correctly
- [ ] Mode detection (solo/dungeon/raid) works
- [ ] Interrupt system targets correct spells
- [ ] Defensive cooldowns trigger at right HP thresholds
- [ ] Encounter policies apply for boss fights
- [ ] OOC functions (drink/eat/buff) work
- [ ] Leveling rotation functions 1-70
- [ ] ESP overlay displays correctly
- [ ] Multiple specs of same class don't conflict
- [ ] Racial abilities function
- [ ] Pet management (hunter specs) works

## Bug Fix History

From CHANGELOG.md - recent fixes:

### v2.1.0 (2026-03-19)
- **Combo points fix**: Changed from `target:get_power()` to `me:get_power(COMBOPOINTS_TBC)` on player
- **Target range cap**: 30 yard limit on hostile engagement
- **Menu defaults**: Multiple abilities changed from false→true
- **Form management**: Travel Form as default OOC
- **Mark of the Wild**: Fixed nil resolution bug
- **Forward declaration**: Fixed `try_claw` nil error

### Previous Sessions
- **Rank 1 bug**: Fixed resolve_spell_id iterating backwards
- **ESP isolation**: Added state_by_spec for multi-spec safety

## Known Testing Gaps

- No unit tests for utility functions
- No integration tests for manager modules
- No performance benchmarking
- No load testing with multiple specs

## Test Environment

- TBC Classic private servers (version 2.4.3)
- Project Sylvanas bot
- Manual gameplay testing
