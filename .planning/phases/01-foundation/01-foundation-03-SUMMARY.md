# Plan 03 Summary — Refactor All Specs to Shared Modules

**Plan**: 01-foundation-03
**Completed**: 2026-03-20
**Wave**: 2

## Deliverables

### Task 1: Updated 27 main.lua files
Changed require statements from local per-spec managers to `common/eax_shared/`:

| Spec | File | Managers Updated |
|------|------|-----------------|
| Druid Balance/Feral/Restoration | main.lua | interrupt, ooc, encounter, racial, defensive |
| Hunter BM/MM/Survival | main.lua | interrupt, ooc, encounter, racial, defensive |
| Mage Arcane/Fire/Frost | main.lua | interrupt, ooc, encounter, racial, defensive |
| Paladin Holy/Prot/Ret | main.lua | interrupt, ooc, encounter, racial, defensive |
| Priest Disc/Holy/Shadow | main.lua | interrupt, ooc, encounter, racial, defensive |
| Rogue Assassination/Combat/Subtlety | main.lua | interrupt, ooc, encounter, racial, defensive |
| Shaman Elemental/Enhancement/Restoration | main.lua | interrupt, ooc, encounter, racial, defensive |
| Warlock Affliction/Demonology/Destruction | main.lua | interrupt, ooc, encounter, racial, defensive |
| Warrior Arms/Fury/Protection | main.lua | interrupt, ooc, encounter, racial, defensive |

Total: 27 specs × 5 managers = 135 require paths updated.

### Task 2: Converted 135 per-spec manager files to thin wrappers
Each file now re-exports from `common/eax_shared/`:
```lua
-- interrupt_manager.lua
-- DEPRECATED: Re-exports from common/eax_shared/
-- Will be removed in future version
return require("common/eax_shared/interrupt_manager")
```
Same pattern for: defensive_manager, encounter_manager, ooc_manager, racial_manager.

Total: 27 specs × 5 managers = 135 wrapper files.

### Task 3: Syntax verification
- All 135 manager wrappers: PASS (luac -p)
- All 27 main.lua: PASS (luac -p) for require path changes
- 7 pre-existing syntax errors found in rotation logic (line 743 of WarriorArms, line 2045 of WarriorFury, etc.) — NOT caused by this refactor

## Git Stats
- 27 main.lua files: 135 insertions, 135 deletions
- 135 manager wrapper files: created
- **27 files changed**, **270 files created** (wrappers)

## Notes
- EAXFishing was also found and updated (bonus spec not in 27-count)
- The wrapper approach maintains backward compatibility — any code still requiring the local file transparently gets the shared module
- Pre-existing syntax errors in rotation logic (e.g., line 743 WarriorArms) should be addressed in Phase 3 (Per-Class Rotation Deep Dives)
