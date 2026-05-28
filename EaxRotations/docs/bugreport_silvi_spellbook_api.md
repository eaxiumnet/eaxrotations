# Bug Report: `core.spell_book.is_spell_learned` Returns False for All Spells

**Reporter:** EaxRotations Dev  
**Date:** 2026-05-26  
**Severity:** Medium (API inaccuracy; addon handles gracefully with fallback)  
**Component:** core.spell_book  

## Environment

- **Client:** Project Sylvanas Core Version 1.939
- **Server:** TBC Classic Private Server
- **Character:** Level 70 Protection Paladin
- **Addon:** EaxRotations v1.1.0

## Summary

`core.spell_book.is_spell_learned(spell_id)` returns `false` for **every** spell ID queried, including the universal Auto Attack (6603) and guaranteed-known class spells like Blessing of Wisdom Rank 7 (27142). `is_spell_known` and `has_spell` aliases also affected.

## Diagnostic Evidence

1. **Auto Attack (6603)** — universal, every character has it:
```
[DEBUG] spell_id_is_known(6603)=false
[DEBUG] spell_id_is_known(6603)=false
```

2. **Blessing of Wisdom (27142)** — known in spellbook, confirmed by user:
```
[MISSING] BlessingOfWisdom  (ids={27142,25290,...})
```

3. **Full Paladin dump** — every spell shows `[MISSING]`, including abilities learned at level 1:
```
[MISSING] RighteousFury      (id=25780, learned at lv16)
[MISSING] Consecration       (id=27173, learned at lv70)
[MISSING] HolyShield         (id=27179, learned at lv70)
[MISSING] DevotionAura       (id=27149, learned at lv70)
[MISSING] Judgement          (id=20271, learned at lv4)
```

4. **API Probe** reports functions exist, but they always return false:
```
[PROBE] spell_book present | is_spell_learned=yes is_spell_known=yes has_spell=yes
API probe complete: PASS 45 / FAIL 0 / SKIP 3
```

## Impact

Add-ons relying on `is_spell_learned` for spell availability detection will incorrectly hide or disable all rotation spells. EaxRotations works around this via a fallback path: after 12 consecutive `false` responses, it switches to level-based ID resolution. However, other add-ons and custom rotations may not implement this guard.

## Reproduction Steps

1. Log into any character on the server.
2. Open Lua console or load any addon calling `core.spell_book.is_spell_learned(id)`.
3. Query `is_spell_learned(6603)` (Auto Attack) or any known class spell.
4. Observe result is `false`.

## Minimal Repro

```lua
local sb = core.spell_book
local id = 6603 -- Auto Attack (everyone has this)
local ok, result = pcall(sb.is_spell_learned, id)
print("id=", id, "ok=", ok, "result=", result) -- Expected true, actual false
```

## Suggested Fix

Investigate `core.spell_book.is_spell_learned` backend. Possible causes:
- Server-side data mismatch between `spell_book` cache and actual known spells.
- Client build version mismatch (API expecting WotLK/Cata spell IDs?)
- Internal cache corruption (spell book cache not initialized at player login).

## Workaround in EaxRotations

Added `NS.reset_api_health()` and level-based fallback:
```
if _api_health_broken then return true end  -- trust IDs when API is unreliable
```

This is robust for our use case but masks the underlying API issue.
