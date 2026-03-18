# EAX TBC Classic Rotations - Handover Document

**Last Updated**: 2026-03-17
**Repo**: https://github.com/eaxiumnet/eax-tbc-classic-rotations

## What Was Done

### ✅ Completed This Session

1. **Rank 1 Bug Fix** - Fixed `resolve_spell_id` in ALL 27 specs:
   - Was iterating backwards (`for i = #rank_table, 1, -1`) returning rank 1 first
   - Fixed to iterate forwards (`for i = 1, #rank_table`) to get highest learned rank

2. **ESP/HUD Improvements** - Updated all 27 esp_renderer.lua files:
   - Spec isolation (state_by_spec table) - multiple loaded specs don't interfere
   - Target name display in HUD
   - Basic attack icon (spell ID 6603)
   - icons_helper integration with caching
   - Added `esp_renderer.init("specname")` to all main.lua files

3. **Shared Modules** (in `common/eax_shared/`):
   - interrupt_manager.lua
   - defensive_manager.lua
   - spell_resolver.lua
   - mode_detector.lua
   - target_finder.lua
   - talents.lua
   - pet_manager.lua

4. **Already Implemented** (from previous work):
   - Talent detection via spell resolution (nil = not learned)
   - Racial abilities (27 specs have racial_manager.lua)
   - Pet management (Hunter specs have mend/revive/attack)
   - Trinket management (via `get_self_cast_trinket_ids`)
   - Interrupts via interrupt_manager.lua
   - Defensives via defensive_manager.lua

---

## What Remains

### 1. Set Bonus Detection (ONLY TRULY MISSING)
- Check gear for T4/T5/T6 set bonuses
- Apply damage multipliers when 2p/4p active
- Reference: `/c/618497f1/scripts/tbc/sim/core/item_sets.go`
- Pattern: `ItemSetXxx.CharacterHasSetBonus(&character, 2)` or `4`

### 2. Shaman Totems (Note)
- TBC requires core totem items in bag (Air Totem 5178, etc.)
- Current spell resolution may fail if items not in bag
- May need `core.input.use_item()` for totems

---

## Reference Files

| Purpose | Location |
|---------|----------|
| Complete spell lists | `/c/618497f1/scripts/tbc/sim/*/` |
| Set bonus implementation | `/c/618497f1/scripts/tbc/sim/core/item_sets.go` |
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
