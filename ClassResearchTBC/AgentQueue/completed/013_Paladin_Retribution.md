```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Paladin Retribution

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Paladin\Retribution\Research.md
- C:\newbot\scripts\ClassResearchTBC\Paladin\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Paladin\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\paladin\retribution_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\schema_sylvanas.lua

Task:
Compare Retribution implementation to the Research.md contract and patch missing vetted behavior only. Focus on seal twisting, Crusader Strike, Vengeance, Judgement of Command, Avenging Wrath, Sanctity Aura, faction seal gating.

Hard rules:
- Seal of Blood [31892] is Horde-only; Seal of the Martyr [348700] is Alliance-only in TBC.
- No WotLK mechanics (Divine Storm, Sacred Shield, etc.).
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for correct signatures and semantics.
================================================================================
```

## Run 1 — 2026-05-20 (Pass 1)

### DB2 Fixes
1. **SEAL_WISDOM_BUFF**: Removed ID 20355 (Judgement of Wisdom, not Seal of Wisdom). Fixed in both local fallback and buff table.
   - Old: `{27166,20357,20356,20355,20166}` → New: `{27166,20357,20356,20166}`

### Behavioral Additions
2. **Avenging Wrath strategy** (priority 780): New burst CD strategy gated on `use_avenging_wrath`/`retri_aw_enabled` setting, checks `state.has_forbearance` before casting, 180s cooldown.
3. **Sanctity Aura strategy** (priority 940): New self-buff maintain strategy gated on `sanctity_aura_enabled`/`retri_aura_enabled` setting.
4. **Retribution schema tab**: New "Retribution" tab with 4 sections (Seals & Rotation, Cooldowns, AoE & Utility, PvP) and 16 settings.

### Validation
- ✅ `luac -p` passes on all 3 Paladin files
- ✅ Code review: 25/25 Research.md requirements verified (23 Present, 2 N/A)

## Run 2 — 2026-05-20 (Pass 2 — Code Review Fixes)

### Schema Key Mismatches Fixed
Aligned 7 schema keys to match code's `get_setting` calls:
- `retri_consecration_single` → `consecration_single_target`
- `retri_command_cleave` → `command_cleave_min_targets`
- `retri_bless_kings` → `blessing_of_kings_self`
- `retri_bless_freedom_self` → `blessing_of_freedom_self`
- `retri_bless_freedom_allies` → `blessing_of_freedom_allies`
- `retri_cleanse_allies` → `cleanse_allies`
- `retri_repentance_pvp` → `repentance_pvp_usage`

Also: removed duplicate `retri_repentance_pvp` from Cooldowns section (now only in PvP).

### Unwired Settings Fixed
- `retri_twist_mana_floor` now wired into `can_twist` (was hardcoded 20)
- `retri_judge_wisdom_mana` now wired into `JudgementWisdom_LowMana` (was hardcoded 45)

### Priority Fix
- Sanctity Aura moved from 940 (above emergency ally saves) to 550 (consistent with other buffs at 530-540)

### Final Validation
- ✅ `luac -p` passes on all 3 Paladin files (both passes)
- ✅ Code review cleared (both passes)
- ✅ All schema keys aligned with code
- ✅ **Job 013 complete — moved to completed/**

## Status: COMPLETE ✅
