# Warlock Demonology — Implementation Checklist

**Created**: 2026-05-20 | **Job**: 025 | **Status**: ✅ Complete

## DB2 Spell Verification

| Spell | Current IDs | Current Levels | DB2 IDs | DB2 Levels | Status |
|---|---|---|---|---|---|
| SummonFelguard | 30146 | 50 | 30146 | 50 | ✅ Present |
| FelDomination | 18708 | — | 18708 | — | ✅ FIXED (cooldown 900→900000) |
| HealthFunnel | 27259,11695,11694,11693,3700,3699,3698,755 | 67,60,52,44,36,28,20,12 | Same | Same | ✅ Present |
| ShadowWard | {28610} | — | 28610,11740,11739,6229 | 60,52,42,32 | ✅ FIXED |
| FelArmor | {28189,28176} | shorthand | 28189,28176 | 69,62 | ✅ FIXED |
| Incinerate | {32231,29722} | shorthand | 32231,29722 | 70,64 | ✅ FIXED |
| HowlofTerror | {17928,5484} | shorthand | 17928,5484 | 54,40 | ✅ FIXED |
| ShadowBolt | verified | verified | verified | verified | ✅ Present (Affliction job) |
| Corruption | verified | verified | verified | verified | ✅ Present (Affliction job) |
| Immolate | verified | verified | verified | verified | ✅ Present (Affliction job) |
| LifeTap | verified | verified | verified | verified | ✅ Present (Affliction job) |
| DeathCoil | verified | verified | verified | verified | ✅ Present (Affliction job) |
| SeedOfCorruption | verified | verified | verified | verified | ✅ Present (Affliction job) |
| SiphonLife | verified | verified | verified | verified | ✅ Present (Affliction job) |
| Soulshatter | verified | verified | verified | verified | ✅ Present (Affliction job) |
| CurseOfDoom | verified | verified | verified | verified | ✅ Present (Affliction job) |

## Behavioral Verification (Research.md Contract)

| Requirement | Research Source | Status | Evidence |
|---|---|---|---|
| Keep Felguard summoned | S+ priority #1: "Keep Felguard alive and attacking" | ✅ Present | SummonFelguard + needs_felguard OOC check |
| Fel Domination fast resummon | FelDomination strategy OOC | ✅ FIXED (cooldown 900ms→900000ms) |
| Health Funnel pet healing | pet_needs_healing at 30% HP | ✅ Present |
| Assigned curse (Curse of Doom) | Single-target priority #2 | ✅ Present (60s CD, min_ttd=62) |
| Corruption/Immolate DoTs | Priority #3: "if worth the GCD" | ✅ Present |
| Shadow Bolt filler | Priority #4 | ✅ Present |
| Life Tap mana recovery | Priority #5: "safely" | ✅ Present (mana<65%, HP>55%) |
| Seed of Corruption AoE | Multi-target 4+: "Seed if available" | ✅ Present (3+ enemies) |
| Death Coil defensive | PvP/utility | ✅ Present (HP<40%) |
| Shadow Ward defensive | Schema: use_shadow_ward | ✅ Present |
| Howl of Terror AoE CC | Multi-target panic | ✅ Present (3+ enemies, combat) |
| Soulshatter threat drop | Threat Management | ✅ Present (combat only) |
| Incinerate filler | Fire filler for fire builds | ✅ FIXED (moved after ShadowBolt) |
| Fel Armor buff | Always maintain | ✅ Present |
| No Demonic Empowerment [47193] | DB2 absent — hard block | ✅ Absent |
| No Metamorphosis [47241] | DB2 absent — hard block | ✅ Absent |
| No Demon Soul [77801] | DB2 absent — hard block | ✅ Absent |
| No Demonic Pact [47236] | DB2 absent — hard block | ✅ Absent |
| No Fel Intelligence [54424] | DB2 absent — hard block | ✅ Absent |
