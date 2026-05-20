# Source Query Notes

This pass checked both online guides and DB2/DBC-style data sources.

## Online Guide Cross-Checks

- Wowhead: guide hub, class guides, spell database pages, talent calculators, and the TBC raid consumables guide.
- Icy Veins: per-spec PvE guides with rotations, talents, gear, enchants, consumables, and role notes.
- Warcraft Tavern: consumables/tools, role overview, Paladin seal mechanics, Feral powershifting, and spec-specific guides.
- WOWTBC.GG: quick PvE class guide pages with rotation/talents/consumables/professions and BiS pages.
- WoWSims: simulator hub and source code for checking rotation logic against community sim behavior.
- TBC.TXT: compact PvE database hub for class/raid/heroic/attunement cross-checks.
- TBCBIS: gear progression and phase BiS cross-checks for every class/spec.
- Timeless Azeroth and Scarmonit: current TBC Anniversary guide hubs, useful for broad sanity checks but lower authority than DB2/Wowhead/Icy/WoWSims.

## DB2/DBC Cross-Checks

Wago Tools:

```text
https://wago.tools/db2/<TableName>/csv?branch=wow_anniversary
```

Tables pulled:

- `SkillLine`
- `SkillLineAbility`
- `Talent`
- `TalentTab`
- `SpellName`
- `SpellLevels`
- `SpellPower`
- `SpellCooldowns`
- `SpellCategories`
- `SpellClassOptions`
- `SpellEffect`

Other DB/DBC references:

- WoW.tools read-only DB browser and background page.
- wowdev `Spells` and `DB/SkillLineAbility` pages for table relationships.
- TrinityCore DB2 page for binary DB2 format background.
- AzerothCore SkillLine page for DBC field meaning cross-checks.
- TBCDB and WoWClassicDB for 2.4.3/TBC spell-page sanity checks.

## Result

The research folder now has guide-level notes plus DB2-backed CSVs for all TBC Anniversary class skill-line abilities and all talent rows. Use the spec research docs for gameplay intent, and the `DB2/` CSVs for exact spell/talent IDs and effect metadata.

