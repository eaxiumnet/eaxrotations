# Sonah vs EaxRotations Gap Analysis

**Goal**: Merge best features from Sonah into EaxRotations to create #1 WoW TBC Classic rotation system.

## API References (USE ONLY THESE)
- `C:\newbot\scripts\apidocs\pages\dev\api\spell-helper.md` - Spell validation (cooldown, range, LOS, facing)
- `C:\newbot\scripts\apidocs\pages\dev\api\buffs.md` - Buff manager for tracking buffs/debuffs
- `C:\newbot\scripts\apidocs\pages\dev\api\cooldown-tracker.md` - Enemy cooldown tracking

---

## KEY FINDINGS

### Sonah Advantages (What to Copy)

1. **Sticky Spell System**
   - Prevents double-casting same spell
   - Tracks setTime, minDuration, priority
   - Implementation: Add `lastCastSpell` variable, check before casting same spell

2. **Proactive Buff Refresh**
   - Checks expiring buffs BEFORE they fall off
   - Uses `GetMostUrgentRebuff()` function
   - Shows colored urgency (green/yellow/red)

3. **Full PvP Mode**
   - Separate GetNextSpellPvP() function
   - Trinket usage, defensives, interrupts, CC awareness
   - Target type checking (pet, player, healer)

4. **Talent-Aware Rotation**
   - Checks specific talents (HasMortalStrike, HasConflagrate, etc.)
   - Different behavior based on talent availability

5. **Configurable Settings**
   - Reads from SonahDB for user preferences
   - Default fallback values

6. **Stance Dancing (Warrior)**
   - NeedsStanceChange(), NeedsStanceForAbility()
   - Automatic stance switching for abilities

7. **Slam Weaving (Arms Warrior)**
   - CanWeaveSlam(), GetMainHandRemaining()
   - Timing-based swing weapon weaving

---

## SPECIFIC IMPROVEMENTS BY CLASS

### ARMS WARRIOR
| Sonah Does | EaxRotations Missing | How to Add |
|------------|---------------------|------------|
| PvP rotation with intercept, disarm, spell reflect | No PvP mode | Add GetNextSpellPvP() with situational checks |
| Slam weaving with swing timer | No swing timing | Use auto-attack-helper API to track swing |
| Stance dancing for abilities | Basic stance check | Expand stance logic with NeedsStanceForAbility() |
| Proactive Battle Shout refresh | Reactive only | Add buff check before combat |
| Victory Rush detection | Missing | Add HasVictoryRush() check |

### DESTRUCTION WARLOCK
| Sonah Does | EaxRotations Missing | How to Add |
|------------|---------------------|------------|
| Backlash proc handling | No proc tracking | Check for Backlash buff, use instant cast |
| Curse of Doom management | Basic CoD | Add CoD refresh logic with TTD check |
| Immolate pandemic window | Basic refresh | Add refresh at 3.5s for 100% uptime |
| Execute phase (Shadowburn) | Basic execute | Add target health check <20% for Shadowburn |
| Life Tap mana management | Missing | Add mana threshold check for Life Tap |

### BEAST MASTERY HUNTER
| Sonah Does | EaxRotations Missing | How to Add |
|------------|---------------------|------------|
| Aspect switching (Hawk vs Viper) | Basic aspect | Add aspect management based on mana |
| Pet emergency mend | Basic mend | Add pet health threshold check |
| Kill Command ready detection | Basic KC | Track pet crit for Kill Command ready |
| PvP mode with intimidation | No PvP | Add PvP rotation with pet stuns |

---

## GAP ANALYSIS SUMMARY

- **Lines of Code**: Sonah averages 500-650 lines/spec vs EaxRotations 30-80 lines/spec
- **Complexity**: Sonah has 5-10x more conditional logic
- **Missing Features**:
  1. PvP mode (all specs)
  2. Sticky spell system
  3. Proactive buff refresh
  4. Talent-aware rotation
  5. Configurable settings
  6. Complex mechanic handling (slam weaving, stance dancing)

---

## RECOMMENDED MERGE PRIORITY

### Phase 1: Infrastructure (High Impact)
1. Add sticky spell system to core
2. Add proactive buff refresh function
3. Add talent detection helper

### Phase 2: PvP Support (Medium Impact)
1. Add PvP mode routing
2. Add target type detection (pet, player, healer)
3. Add defensive cooldown usage

### Phase 3: Advanced Mechanics (Lower Impact)
1. Stance dancing for Warrior
2. Swing timer for Hunter/Warrior
3. Proc tracking (Backlash, Victory Rush, etc.)

---

## API FUNCTIONS TO USE

From apidocs, these are the equivalent functions to implement Sonah features:

```lua
-- Buff checking (equivalent to Sonah:HasBuff)
local buff_manager = require("common/modules/buff_manager")
local buff_info = buff_manager:get_buff_data(target, { buff_id })

-- Spell castable (equivalent to Sonah:IsSpellReady)
local spell_helper = require("common/utility/spell_helper")
local can_cast = spell_helper:is_spell_castable(spell_id, caster, target, false, false)

-- Cooldown check (equivalent to Sonah:GetSpellCooldownRemaining)
local tracker = require("common/utility/cooldown_tracker")
local cd = tracker:get_remaining_cooldown(unit, spell_id)

-- Target selection
local target_selector = require("common/modules/target_selector")
local targets = target_selector:get_targets()
```

---

*Generated from code comparison using apidocs only.*