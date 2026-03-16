# EAX TBC Classic Rotations - Handover Document

**Last Updated**: 2026-03-16
**Repo**: https://github.com/eaxiumnet/eax-tbc-classic-rotations

## What Was Done

### ✅ Completed This Session

1. **Interrupts** - Added to 23 specs via `interrupt_manager`:
   - Warrior: Arms, Fury, Protection
   - Rogue: Combat, Assassination, Subtlety
   - Hunter: Survival, Beast Mastery, Marksmanship
   - Mage: Arcane, Fire, Frost
   - Paladin: Retribution, Holy, Protection
   - Priest: Shadow, Holy, Discipline
   - Druid: Balance, Feral, Restoration
   - Shaman: Enhancement, Elemental, Restoration
   - Warlock: Destruction, Demonology, Affliction

2. **Defensives** - Added to all 24 specs via `defensive_manager`:
   - Each class gets HP-threshold based defensive abilities
   - Fixed TBC spell IDs (Shield Wall 871, Vanish 1856, etc.)

3. **Fixed defensive_manager.lua** - Corrected TBC spell IDs

4. **Shared Modules** (in `common/eax_shared/`):
   - interrupt_manager.lua
   - defensive_manager.lua
   - spell_resolver.lua
   - mode_detector.lua
   - target_finder.lua
   - talents.lua
   - pet_manager.lua

---

## What Remains

### 1. Add ALL Missing Spells (~20-30 per spec)
- Copy spell IDs from `tbc/sim/` to each `spells.lua`
- Reference: `/c/618497f1/scripts/tbc/sim/warrior/warrior.go` etc.

### 2. Talent Detection
- Implement based on spell presence
- Enable/disable abilities based on talents

### 3. Set Bonus Detection
- Check gear for T4/T5/T6 bonuses
- Enable bonus effects when 2p/4p active

### 4. Pet Management (Hunter/Warlock)
- Mend Pet, Revive Pet, Pet Abilities
- Check existing implementations in Hunter specs

### 5. Racial Abilities
- Blood Fury (Orc), Berserking (Troll), Stoneform (Dwarf)
- Every Race (Human), Shadowmeld (Night Elf)

### 6. Trinket Management
- On-use trinkets with time-in-combat gating
- Check `utils.use_item_if_ready()` in existing specs

### 7. Interrupt Cast-Time Detection
- Current: Basic `is_casting_spell()` check
- Improve: Detect cast time remaining for better interrupts

### 8. Shaman Totems (Note)
- TBC requires core totem items in bag (Air Totem 5178, etc.)
- Current spell resolution may fail if items not in bag
- May need `core.input.use_item()` for totems

---

## Reference Files

| Purpose | Location |
|---------|----------|
| Complete spell lists | `/c/618497f1/scripts/tbc/sim/*/` |
| Rotation examples | `/c/618497f1/scripts/PublicGithubs/BRLite-main/` |
| Rotation examples | `/c/618497f1/scripts/PublicGithubs/ni-main/` |
| Sylvanas API docs | `/c/618497f1/scripts/sylvanas-dev-docs-llm/` |

---

## Commands

```bash
# Pull latest
cd /c/eax_clean && git pull

# Push changes
cd /c/eax_clean && git add -A && git commit -m "feat: description" && git push
```
