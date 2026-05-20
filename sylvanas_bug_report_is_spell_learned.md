# Bug Report: `core.spell_book.is_spell_learned()` Returns False for All Spells

## Environment
- **Sylvanas Core Version**: 1.934
- **Game Version**: TBC Classic (`wow_tbc_*`)
- **Client Region**: (West/China — unknown, happens on both)
- **Plugin**: EaxRotations (Warlock — confirmed on all 3 specs: Affliction, Destruction, Demonology)

## Summary

`core.spell_book.is_spell_learned(spell_id)` always returns `false` when called with any actual spell ID, even though the player clearly has those spells learned (they are actively being cast and producing visible effects in-game).

The probe system confirms the function **exists** (`type(core.spell_book.is_spell_learned) == "function"` is true), but runtime calls return the wrong value.

## Impact

Rotation plugins that use `is_spell_learned()` as a gating check cannot distinguish learned from unlearned spells. Affected code must bypass the API entirely and trust spell IDs blindly, losing the ability to gracefully handle unlearned spells.

## Reproduction

```lua
-- During probe (load time): PASS
local exists = type(core.spell_book.is_spell_learned) == "function"
-- exists = true  ✓

-- Runtime call with any known spell: FAIL
local ok, result = pcall(core.spell_book.is_spell_learned, 687)  -- Demon Skin
-- ok = true, result = false  ✗

local ok, result = pcall(core.spell_book.is_spell_learned, 28176) -- Fel Armor
-- ok = true, result = false  ✗

local ok, result = pcall(core.spell_book.is_spell_learned, 27216) -- Corruption (Rank 2)
-- ok = true, result = false  ✗
```

The pcall does NOT error — it succeeds cleanly but returns `false` every time.

## Fallback Functions Also Fail

The two alternative spell-check APIs have the same behavior:

```lua
type(core.spell_book.is_spell_known) == "function"  -- true
core.spell_book.is_spell_known(687)                  -- false (wrong)

type(core.spell_book.has_spell) == "function"        -- true
core.spell_book.has_spell(687)                       -- false (wrong)
```

All three functions exist, all pcall successfully, all return `false` for every spell ID tested.

## Tested Spell IDs (All Return False)

| Spell | ID | Notes |
|-------|----|-------|
| Demon Skin | 687 | Starter spell, rank 1 |
| Fel Armor | 28176 | TBC spell, currently applied as aura |
| Corruption (R2) | 27216 | Actively being cast in rotation |
| Shadow Bolt (R10) | 27209 | Actively being cast in rotation |
| Immolate (R9) | 27215 | Actively being cast in rotation |
| Soul Fire (R1) | 6353 | Actively being cast in rotation |
| Amplify Curse | 18220 | Learned at level 60 |
| Soulshatter | 29858 | Learned at level 66 |
| Unstable Affliction (R3) | 30405 | Actively being cast in rotation |

## Our Health-Check Heuristic

Since this bug is common enough to expect, we implemented a heuristic watchdog:

```lua
if _api_health_calls >= 12 and _api_health_hits == 0 then
    _api_health_broken = true
    -- skip is_spell_learned entirely; trust the spell ID
end
```

After 12 consecutive false returns with zero true returns, we mark the API as broken and bypass it. This is our best effort, but it means we lose the ability to gracefully handle unlearned spells.

## Additional Observation: Spec Detection API

`core.character.get_specialization()` returns a non-positive value (0 or nil) on TBC builds. We handle this gracefully (it's expected for TBC), but documenting whether this is intended behavior would help plugin authors.

## Request

1. Can `is_spell_learned()` (and `is_spell_known()` / `has_spell()`) be fixed to return correct values on TBC builds?
2. If a fix in the runtime is not immediately possible, is there a recommended alternative API for spell existence checks on TBC?
3. For `get_specialization()` on TBC — is returning 0/nil expected behavior, or is this also a bug?

We're happy to help test any fix. The plugin is at `C:\newbot\scripts\EaxRotations\` and we can reload/reproduce on demand.
