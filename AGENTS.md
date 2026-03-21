# EAX TBC Classic Rotations - Handover Document

**Last Updated**: 2026-03-21
**Repo**: https://github.com/eaxiumnet/eax-tbc-classic-rotations
**Local Path**: `C:\newbot\scripts`

## What Was Done

### ✅ Completed This Session (2026-03-21)

1. **Git Recovery** - Restored 174 uncommitted commits, cleaned up git state
2. **Critical Bug Fix** - Fixed broken `require` paths: `common/eax_shared/` → `eax_shared/` across all 27 specs (all stubs were referencing non-existent paths)
3. **Performance: Spell Resolution Cache** - Created `eax_shared/spell_resolver.lua` with persistent caching
   - Previously: ~810+ `is_spell_learned()` API calls/sec across 27 specs
   - Now: cached after first resolve, invalidated on talent change
4. **Performance: Combat Context Throttle** - Throttled `combat_context.build()` to 2-second refresh
   - Previously: 20+ pcall API calls per frame × 27 specs
   - Now: cached for 2 seconds
5. **Performance: Target Finder** - Optimized `find_best_target()` in all 27 specs
   - Early exit for existing current target
   - Distance culling with squared-distance checks
   - Limited scan to 50 objects
6. **Performance: Mode Detector** - Moved `detect_mode()` to shared `utils.detect_mode(me)` with 5s throttle
   - Previously: per-spec inline O(n) scan every frame
   - Now: 5-second throttle, cached result
7. **Performance: ESP Renderer** - Static `_tracked_auras` table reuse in all 27 specs
   - Previously: `{}` allocated every frame
   - Now: static table reused, zero allocations
8. **Performance: Local API Caching** - Added `_core_time`, `_get_local_player`, `_get_gcd`, `_get_spell_cd` aliases in all 27 main.lua files
9. **Performance: Pet Manager** - Removed unused `me_to_target` and `pet_to_me` distance calculations; replaced sqrt with squared-distance comparisons
10. **.gitignore** - Added build artifacts (luac.out, nul, .tmp_wfu_luac.txt, EaxFishing_v2_0_1/)

### ✅ Already Implemented (from previous work)

- **Set Bonus Detection** - `eax_shared/set_bonus.lua` (443 lines, 60+ T4/T5/T6 sets)
- **ESP/HUD** - Per-spec `esp_renderer.lua` with spec isolation (state_by_spec)
- **Interrupt Manager** - `eax_shared/interrupt_manager.lua` (262 lines, priority-based)
- **Defensive Manager** - `eax_shared/defensive_manager.lua` (73 lines, HP-threshold tiers)
- **Racial Manager** - `eax_shared/racial_manager.lua` (129 lines, all TBC races)
- **Pet AI** - `EAXHunterBeastMastery/pet_manager.lua` (342 lines, state machine)
- **Shaman Totems** - `eax_shared/totem_manager.lua` (111 lines, bag scanning)
- **Spell Resolution** - `eax_shared/spell_resolver.lua` (85 lines, persistent cache)
- **Combat Context** - `eax_shared/combat_context.lua` (431 lines, throttled to 2s)
- **Reactive Runtime** - `eax_shared/reactive_runtime.lua` (350 lines, cached context)

---

## What Remains

### New API Additions (2026-03-21)
The following Sylvanas API features are now available and could be integrated:

| API | Description | Specs Affected |
|-----|-------------|---------------|
| `core.input.enable_pet_autocast(name)` | Enable pet autocast ability | Hunter (all 3) |
| `core.input.disable_pet_autocast(name)` | Disable pet autocast ability | Hunter (all 3) |
| `core.spell_book.get_pet_action_info()` | Get pet action name, texture, autocast state, range | Hunter (all 3) |
| `core.input.quick_cat()` | Quick cat form (Druid) | Druid (all 3) |
| `obj:get_armor()` | Get unit armor value | Tank specs |
| `core.character.get_combat_rating_bonus()` | Combat rating bonus lookup | All |
| `core.world.is_flyable_area()` | Check if area is flyable | All outdoor |
| `core.world.get_encounters_on_map()` | Boss encounter tracking | Dungeon/Raid |
| `core.game_ui.get_all_completed_quest_ids()` | Quest completion data | Questing |
| `core.game_ui.reset_instances()` | Reset dungeon instances | Group content |
| `core.quests.*` | Full quest log, gossip, trainer, accept/complete API | Questing |
| `core.auction_house.*` | Full AH API: scans, posting, bidding, commodities | Economy |

### Low Priority / Future

- **Shaman Totem Items** - May need `core.input.use_item()` for core totem items in bag
- **Buff Manager** - `common/modules/buff_manager` require may fail (path doesn't exist on disk)

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
# Clone (if not already)
git clone https://github.com/eaxiumnet/eax-tbc-classic-rotations.git
cd eax-tbc-classic-rotations

# Pull latest
git pull

# Push changes
git add -A && git commit -m "feat: description" && git push
```
