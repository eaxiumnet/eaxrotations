# Druid Restoration — Implementation Checklist

Created: 2026-05-19 | Job: 004 | Vetting: DB2 `wow_anniversary`

## DB2 Spell Rank Verification

| Spell | Status | Issue | DB2 max rank |
|---|---|---|---|
| HealingTouch | ✅ Present | 13 IDs, 13 levels — verified correct | 26979 (lvl 69) |
| Regrowth | ✅ Present | 10 IDs, 10 levels — verified correct | 26980 (lvl 65) |
| Lifebloom | ✅ Present | 1 ID, 1 level — verified correct | 33763 (lvl 64) |
| Rejuvenation | ✅ Present | 13 IDs, 13 levels — verified correct | 26982 (lvl 69) |
| Tranquility | ✅ Present | 5 IDs, 5 levels, cd=600 — verified correct | 26983 |
| Swiftmend | ✅ Present | cd=15 matches DB2 15000ms | 18562 |
| Nature's Swiftness | ✅ Present | cd=180 matches DB2 180000ms | 17116 |
| Innervate | ✅ Present | cd=360 matches DB2 360000ms | 29166 |
| Remove Curse | ✅ Present | ID 2782 | 2782 |
| Abolish Poison | ✅ Present | ID 2893 | 2893 |
| Barkskin | ✅ Present | CD=60s matches DB2 | 22812 |
| Nourish [50464] | ✅ Absent | DB2 absent — correctly not implemented | N/A |

## Research.md Behavioral Contract

| Requirement | Status | Evidence |
|---|---|---|
| Lifebloom refresh at 2-3s remaining | ✅ Present | `LIFEBLOOM_REFRESH = 2.5` |
| Swiftmend prefer Rejuvenation over Regrowth | ✅ Present | `choose_swiftmend_prefer_rejuv()` |
| Tree of Life maintain in combat | ✅ Present | Leaves Tree only for NS/HT/Cyclone emergencies |
| Innervate: healer > caster > self | ✅ Fixed | `find_priority_innervate()`: healers at ≤(resto_innervate_mana+5), self fallback at ≤resto_innervate_mana |
| NS + Healing Touch emergency path | ✅ Present | NS time-to-die gate ≤3.5s, then NS HT follow-through |
| Tranquility at 3+ targets (configurable) | ✅ Present | Configurable default 3; user can set 5 per Research preference |
| Mana conservation: Regrowth suppressed at ≤30% (conserve) | ✅ Fixed | `RegrowthSpotHeal` now gated on `not state.mana_conserve` |
| Mana conservation: Rejuvenation suppressed at ≤15% (emergency) | ✅ Fixed | `PriorityRejuvenation` + `MovingRejuvenation` both gated on `not state.mana_emergency` |
| Mana conservation critical at ≤5% | ✅ Present | `mana_critical` gates most non-tank spells |
| Clearcasting (Omen of Clarity [16870]) | ✅ Present | Tracked in `has_clearcasting`; `ClearcastRegrowth` strategy consumes it |
| Regrowth downrank | ✅ Present | `HealingTouchRank4` [5189] downrank at ≤45% mana |
| Dispel: Remove Curse + Abolish Poison | ✅ Present | `RemoveCurse` + `AbolishPoison` strategies with correct target resolution |
| Schema: Mana conservation sliders wired | ✅ Fixed | `resto_mana_conserve_pct` (30), `resto_mana_emergency_pct` (15), `resto_mana_critical_pct` (5) read from schema |
| Schema: Solo DPS settings | ✅ Fixed | `resto_dps_when_idle`, `resto_idle_hp`, `resto_dps_mana_floor` added |

## Schema Settings

| Setting | Status |
|---|---|
| `resto_lifebloom_targets` | ✅ Present |
| `resto_swiftmend_hp` | ✅ Present |
| `resto_ns_hp` | ✅ Present |
| `resto_innervate_mana` | ✅ Present |
| `resto_tranquility_hp` | ✅ Present |
| `resto_tranquility_count` | ✅ Present |
| `resto_auto_dispel` | ✅ Present |
| `resto_tol_enabled` | ✅ Present |
| `resto_mana_conserve_pct` | ✅ Fixed — wired to build_state |
| `resto_mana_emergency_pct` | ✅ Fixed — wired to build_state |
| `resto_mana_critical_pct` | ✅ Fixed — wired to build_state |
| `resto_dps_when_idle` | ✅ Fixed |
| `resto_idle_hp` | ✅ Fixed |
| `resto_dps_mana_floor` | ✅ Fixed |

## Changes Applied (2026-05-19 Run)

### `resto_sylvanas.lua` — 5 fixes:
1. **RegrowthSpotHeal**: mana gate `mana_critical`(5%) → `mana_conserve`(30%) per Research Angle 4
2. **PriorityRejuvenation**: mana gate `mana_critical`(5%) → `mana_emergency`(15%)
3. **MovingRejuvenation**: added `not state.mana_emergency` gate (was missing)
4. **Innervate healer threshold**: hardcoded 25% → `resto_innervate_mana + 5` from settings
5. **Mana conservation thresholds**: now read from schema settings (`resto_mana_conserve_pct`, etc.) with hardcoded constants as fallback

### `schema_sylvanas.lua` — 2 new sections:
- "Restoration — Mana Conservation": 3 sliders (conserve=30%, emergency=15%, critical=5%)
- "Restoration — Solo DPS": 3 settings (dps_when_idle, idle_hp=88, dps_mana_floor=35)

### Validation
- ✅ `luac -p` passes all modified files
- ✅ `test_restoration_healing_way` — 24 strategies, 2 FrostByte gaps closed

## Remaining Risk
- Tranquility default target count (3) is below Research-recommended 5 — intentionally configurable
- PvP Cyclone DR tracking is not implemented (framework concern)
- Boss encounter modifiers (Kara/Gruul/SSC/BT/Sunwell) are not yet wired
