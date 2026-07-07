# Stash Investigation — 2026-07-03

## Context
User asked if any unpublished EaxRotations work needs to be published. Found 3 git stashes.

## Method
Created branch `stash-investigation`, attempted to pop each stash, ran tests where applicable.

## Results

### Stash 2 (oldest): `refactor: remove force_command system and add buff upgrade + APL registry`
- **Base:** `3e74e198` (old)
- **Size:** 19 files, +16 / −228 lines
- **Result:** ❌ 18 merge conflicts in core engine files (`main.lua`, `main_sylvanas.lua`) and spec files
- **Verdict:** ABANDONED — based on old master, conflicts with current hotfixes

### Stash 1: `fix(audit): add ScatterShot, fix nil-guards, clean 11958 residue`
- **Base:** `8874a070` (old)
- **Size:** 991 files, +53,695 / −29,823 lines (mostly wowhead_data JSON refresh)
- **Result:** ❌ Untracked file overwrites in `wowhead_data/spells/tbc/*.json`
- **Verdict:** ABANDONED — wowhead data refresh superseded by newer extractions

### Stash 0 (newest): `fix(trace): suppress AutoConsumable matched=true,executed=false spam`
- **Base:** `3f60e4f5` (old)
- **Size:** 137 files, +558 / −706 lines
- **Result:** ❌ 100+ merge conflicts across all specs and core files
- **Verdict:** ABANDONED — massive refactor that conflicts with all post-v2.3.0 hotfixes

## Conclusion
**None of the 3 stashes are safe to publish.** All are based on versions of master that predate the v2.3.x hotfix series. The codebase has moved forward with:
- v2.3.2: Priest/Warrior nil-guard + dispel spam fix
- v2.3.3: Settings nil-guard sweep
- v2.3.4: Warrior Pummel + Priest/Druid crash fixes
- v2.3.5: Missing Shadowfiend/DivineProtection + totem nil-guard

Publishing any stash would undo these critical fixes.

## If Features Are Still Wanted
The *ideas* in the stashes can be re-implemented fresh on current master:
- **Stash 2:** Remove `force_command` system (engine cleanup)
- **Stash 1:** ScatterShot for Hunters, nil-guard fixes (already done in v2.3.x)
- **Stash 0:** Trace suppression, menu theme integration, core refactoring

## Action
- [x] Investigated all 3 stashes
- [x] Confirmed none are recoverable
- [x] Documented findings
- [ ] Push current master to origin (9 commits ahead)
