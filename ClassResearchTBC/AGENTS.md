# ClassResearchTBC — Agent Context

**Project:** TBC Classic rotation research for Project Sylvanas plugins.
**Branch target:** `wow_anniversary` (build 2.5.5.67511, DB2 snapshot 2026-05-14).
**Purpose:** Extend the existing S+ research base with five new research angles across all 29 specs. Output must be actionable as rotation code — conditions, thresholds, state machine inputs, priority tables. Descriptive prose has zero value.

## File Layout

```
ClassResearchTBC/
├── AGENTS.md                        ← you are here
├── TASK.md                          ← Sisyphus reads this first; contains the full job spec
├── NEW_FINDINGS_LOG.md              ← append every [NEW FINDING] here (auto-created)
├── VERIFY_LIST.md                   ← append every [VERIFY] item here (auto-created)
├── Sources.md                       ← master source index with all URLs
├── Source-Conflict-Register.md      ← conflict resolution policy
├── Shared/                          ← cross-class mechanics, PvP, consumables
├── DB2/                             ← Wago Tools CSV exports (wow_anniversary branch)
├── <Class>/
│   ├── DB2-Spells.md
│   ├── DB2-Talents.md
│   ├── DB2-Rotation-Relevant-Effects.md
│   ├── Gear-and-Sets.md
│   ├── Implementation-Notes.md
│   └── <Spec>/Research.md           ← S+ baseline; Hephaestus reads this before writing
└── Encounters/
    ├── All-Raids-Deep-Matrix.md
    └── All-Dungeons-Deep-Matrix.md
```

## Hard Rules — Every Agent Must Follow

1. **TBC Classic `wow_anniversary` only.** Never import WotLK, Cata, or retail mechanics.
2. **Forbidden abilities** (do not reference): Beacon of Light, Holy Power, Sacred Shield, Divine Plea, Lava Burst, Riptide, Hex, Wind Shear, Feral Spirit, Maelstrom Weapon, Mind Sear, Cat Swipe (Feral AoE), Savage Roar, Berserk, Titan's Grip, Shockwave, Bladestorm, Sword and Board proc, Heroic Throw, any Death Knight ability.
3. **Spell IDs required.** Every spell reference: `Spell Name [ID]`. Multi-rank: `Spell Name [ID1/ID2/ID3]`. Unverifiable ID → write `[VERIFY]`, never invent.
4. **Paladin seals are faction-gated.** Seal of Blood [31892/31893] = Horde. Seal of the Martyr [348700/348701] = Alliance in the local `wow_anniversary` DB2 snapshot. All seal logic must gate on faction detection.
5. **Tag discipline:** `[VERIFY]` on anything unconfirmed against Tier 1/2 sources. `[NEW FINDING]` on anything not in the spec's existing Research.md.
6. **Output format:** markdown tables only for priority lists, state machines, decision matrices. Columns: `Condition | Action | Stop condition` minimum.
7. **Write findings to disk.** Each Hephaestus worker appends its output to the spec's Research.md under a clearly marked new section, and appends its `[NEW FINDING]` and `[VERIFY]` items to the root log files.

## Source Authority

**Tier 1 (spell IDs, base values):**
- Wago Tools DB2: https://wago.tools/db2/?branch=wow_anniversary
- Wowhead TBC: https://www.wowhead.com/tbc/spells/abilities/<class>
- TBCDB: https://www.tbcdb.com/?spells=0

**Tier 2 (rotation, priority, sim values):**
- Icy Veins TBC: https://www.icy-veins.com/tbc-classic/class-guides
- Wowhead guides: https://www.wowhead.com/tbc/guides/classes
- WoWSims TBC: https://wowsims.github.io/tbc/
- Warcraft Tavern: https://www.warcrafttavern.com/tbc/guides/

**Local refs (implementation signal only, not game-data authority):**
- `../flux/docs/<CLASS>_RESEARCH.md`
- `../Sonah/Classes/**`
- `../SlyRotate/SlyRotate_<Class>.lua`

## Spec → File Map

| Spec | Research.md path |
|---|---|
| Druid Balance | Druid/Balance/Research.md |
| Druid Feral DPS | Druid/Feral-DPS/Research.md |
| Druid Bear Tank | Druid/Bear-Tank/Research.md |
| Druid Restoration | Druid/Restoration/Research.md |
| Hunter Beast Mastery | Hunter/Beast-Mastery/Research.md |
| Hunter Marksmanship | Hunter/Marksmanship/Research.md |
| Hunter Survival | Hunter/Survival/Research.md |
| Mage Arcane | Mage/Arcane/Research.md |
| Mage Fire | Mage/Fire/Research.md |
| Mage Frost | Mage/Frost/Research.md |
| Paladin Holy | Paladin/Holy/Research.md |
| Paladin Protection | Paladin/Protection/Research.md |
| Paladin Retribution | Paladin/Retribution/Research.md |
| Priest Discipline | Priest/Discipline/Research.md |
| Priest Holy | Priest/Holy/Research.md |
| Priest Shadow | Priest/Shadow/Research.md |
| Priest Smite | Priest/Smite/Research.md |
| Rogue Assassination | Rogue/Assassination/Research.md |
| Rogue Combat | Rogue/Combat/Research.md |
| Rogue Subtlety | Rogue/Subtlety/Research.md |
| Shaman Elemental | Shaman/Elemental/Research.md |
| Shaman Enhancement | Shaman/Enhancement/Research.md |
| Shaman Restoration | Shaman/Restoration/Research.md |
| Warlock Affliction | Warlock/Affliction/Research.md |
| Warlock Demonology | Warlock/Demonology/Research.md |
| Warlock Destruction | Warlock/Destruction/Research.md |
| Warrior Arms | Warrior/Arms/Research.md |
| Warrior Fury | Warrior/Fury/Research.md |
| Warrior Protection | Warrior/Protection/Research.md |
