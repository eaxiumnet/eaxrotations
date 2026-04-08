# EAX Menu Standardization Proposal

## Current Problems
1. **Inconsistent naming** - "OOC", "Out of Combat", "OOC Sustain" used interchangeably
2. **Inconsistent ordering** - Each spec has categories in different order
3. **Technical jargon** - "Middleware" means nothing to users
4. **Missing categories** - No clear "General" section in some specs
5. **Confusing splits** - "Defensive", "Guardian", "Shared / Utility" overlap

## Proposed Standard Structure (10 Categories)

### 1. **General**
- Enable/disable toggle
- Mode (Auto/PvE/PvP)
- Debug toggle
- Toggle keybind

### 2. **Rotation**
- Spec-specific abilities
- Spell priorities
- Form/stance management
- Opener settings

### 3. **Defensive**
- Survival cooldowns
- Self-healing
- Damage reduction
- Emergency heals

### 4. **Utility**
- Crowd control
- Mobility
- Interrupts
- Dispels

### 5. **Buffs**
- Self-buffs (OOC)
- Group buffs
- Form/stance buffs
- Blessings/Auras (Paladin)

### 6. **Consumables**
- Healthstones
- Healing potions
- Food & drink (OOC)
- Form-specific consumables

### 7. **PvP**
- Enable PvP features
- PvP trinket
- PvP-specific CC
- Defensive thresholds

### 8. **Automation**
- Burst cooldowns
- Trinket automation
- Auto-powershift (Druid)
- Auto-consumables

### 9. **Dashboard**
- Show/hide
- Opacity/scale
- Position
- Features (timers, history)

### 10. **Advanced**
- Targeting settings
- Racial abilities
- Leveling mode
- Mana conservation

## Naming Conventions

| Old Name | New Name |
|----------|----------|
| OOC / OOC Sustain | **Consumables** (for drink/eat) or **Buffs** (for group buffs) |
| Middleware / Consumables | **Consumables** |
| Shared / Utility | **Utility** |
| Form Management | **Rotation** |
| Group | **Buffs** |
| Automation (for burst) | Keep as **Automation** |
| Blessings / Auras | Move to **Buffs** |

## Render Order Priority

1. General (always first - enable/disable)
2. Rotation (core gameplay)
3. Defensive (survival)
4. Utility (CC/mobility)
5. Buffs (OOC preparation)
6. Consumables (emergency items)
7. PvP (optional feature)
8. Automation (advanced features)
9. Dashboard (UI preferences)
10. Advanced (misc settings)

## Implementation Example - Feral Druid

### Current (messy):
1. Controls (implicit)
2. Form Management
3. Cat Form
4. Bear Form
5. Guardian
6. Shared / Utility
7. Defensive
8. Middleware / Consumables
9. Dashboard
10. Burst / Trinket
11. PvP
12. Targeting
13. Racial
14. Out of Combat

### Proposed (clean):
1. **General**
2. **Rotation** (merge Form Management + Cat Form + Bear Form)
3. **Defensive** (merge Guardian + Defensive)
4. **Utility** (merge Shared / Utility)
5. **Buffs** (rename from Out of Combat, move Thorns here)
6. **Consumables** (rename from Middleware)
7. **PvP**
8. **Automation** (rename from Burst / Trinket)
9. **Dashboard**
10. **Advanced** (Targeting + Racial)

## Files to Update

- [ ] EAXDruidFeral/libraries/menu.lua
- [ ] EAXDruidBalance/libraries/menu.lua
- [ ] EAXDruidBear/libraries/menu.lua
- [ ] EAXDruidResto/libraries/menu.lua
- [ ] EAXPriestHoly/libraries/menu.lua
- [ ] EAXPriestDiscipline/libraries/menu.lua
- [ ] EAXPriestShadow/libraries/menu.lua
- [ ] EAXPriestSmite/libraries/menu.lua
- [ ] EAXPaladinHoly/libraries/menu.lua
- [ ] EAXPaladinProtection/libraries/menu.lua
- [ ] EAXPaladinRetribution/libraries/menu.lua
- [ ] EAXShamanElemental/libraries/menu.lua
- [ ] EAXShamanEnhancement/libraries/menu.lua
- [ ] EAXShamanRestoration/libraries/menu.lua
- [ ] EAXMageArcane/libraries/menu.lua
- [ ] EAXMageFire/libraries/menu.lua
- [ ] EAXMageFrost/libraries/menu.lua
- [ ] EAXWarlockAffliction/libraries/menu.lua
- [ ] EAXWarlockDemonology/libraries/menu.lua
- [ ] EAXWarlockDestruction/libraries/menu.lua
- [ ] EAXHunterBM/libraries/menu.lua
- [ ] EAXHunterMM/libraries/menu.lua
- [ ] EAXHunterSurvival/libraries/menu.lua
- [ ] EAXRogueAssassination/libraries/menu.lua
- [ ] EAXRogueCombat/libraries/menu.lua
- [ ] EAXRogueSubtlety/libraries/menu.lua
- [ ] EAXWarriorArms/libraries/menu.lua
- [ ] EAXWarriorFury/libraries/menu.lua
- [ ] EAXWarriorProtection/libraries/menu.lua

## Notes

- Keep backward compatibility with menu keybinds/settings
- Only reorganize render() order and tree names
- Don't change menu variable names (to preserve saved settings)
- Use consistent headers within each category
