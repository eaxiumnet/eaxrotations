# Hunter Survival — Implementation Checklist

**Created**: 2026-05-20 | **Job**: 007 | **Status**: ✅ Complete

## DB2 Spell Verification

| Spell | Current IDs | Current Levels | DB2 IDs | DB2 Levels | Status |
|---|---|---|---|---|---|
| ExplosiveTrap | 27025,14317,14316,13813 | 70,60,50,40 | 27025,14317,14316,13813 | 61,54,44,34 | ✅ FIXED |
| ScorpidSting | 27013,19320,19319,19318,19317,19316,19315 | 70,62,56,48,40,30,20 | 3043 | 22 | ✅ FIXED (7→1 rank) |
| RaptorStrike | ... | ... | 27014,14266,14265,14264,14263,14262,14261,14260,2973 | 63,56,48,40,32,24,16,8,1 | ✅ FIXED (all IDs wrong) |
| WingClip | ... | ... | 14268,14267,2974 | 60,38,12 | ✅ FIXED (6→3 ranks, all IDs wrong) |
| Volley | ... | ... | 27022,14295,14294,1510 | 67,58,50,40 | ✅ FIXED (all IDs wrong) |
| WyvernSting | MISSING | — | 27068,24133,24132,19386 | 70,60,50,40 | ✅ ADDED |
| FeignDeath | 5384 | 30 | 5384 | 30 | ✅ Present |
| FreezingTrap | 14311,14310,1499 | 60,40,20 | 14311,14310,1499 | 60,40,20 | ✅ Present |
| ViperSting | 27018,14280,14279,3034 | 66,56,46,36 | 27018,14280,14279,3034 | 66,56,46,36 | ✅ Present |

## Behavioral Verification (Research.md Contract)

| Requirement | Research Source | Status | Evidence |
|---|---|---|---|
| Maintain Hunter's Mark | Single-target priority #1 | ✅ Present | hunters_mark_matches checks debuff |
| Keep Expose Weakness uptime | Role duty | ⚠️ Passive (talent proc, no code gate) |
| Serpent Sting refresh <1.5s | Angle 4: "clip only <1.5s" | ✅ FIXED (was 3.0) |
| Multi-Shot CC-safe gate | Multi-target: "do not cleave controlled mobs" | ✅ FIXED |
| Arcane Shot mana gate <10% | Angle 4: "All special shots forbidden" | ✅ FIXED |
| Steady Shot between Auto Shots | Single-target priority #5 | ✅ Present (can_cast_steady) |
| Rapid Fire/trinkets in burn windows | Cooldown Usage | ✅ Present |
| Aspect swap for mana | Resource Management | ✅ FIXED (schema mana_pct>20) |
| Wyvern Sting with DoT check | Angle 1: "DoT breaks sleep"; Angle 5: "check target debuffs" | ✅ ADDED (wyvern_sting_matches) |
| Explosive Trap for multi-target | Multi-target matrix | ✅ FIXED (enemy_count 7→3) |
| Volley 4+ targets | Multi-target: "4+ targets: Volley only after stable threat" | ✅ FIXED (was 3+) |
| Feign Death threat drop | Threat Management: "mandatory around burst" | ✅ Present |
| Misdirection for threat | Threat Management | ✅ Present |
| Viper Sting PvP utility | PvP section | ✅ Present |
| Scorpid Sting debuff | Utility section | ✅ Present (post-DB2 fix) |
| Melee weaving (Raptor Strike/Wing Clip) | Advanced section | ✅ Present |
| Freezing Trap utility | Utility section | ✅ Present |
| No Black Arrow [19434] | Hard rule: "19434 is Aimed Shot" | ✅ Absent |
| No Explosive Shot [53209] | Hard rule: "DB2 absent" | ✅ Absent |
| No Trap Launcher [77769] | Hard rule: "DB2 absent" | ✅ Absent |
