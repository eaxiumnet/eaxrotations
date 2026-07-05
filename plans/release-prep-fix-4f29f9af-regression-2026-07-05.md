# Release Prep: Fix 4f29f9af Regression in EaxRotations

**Started:** 2026-07-05
**Goal:** Restore EaxRotations to a green, release-ready baseline (219/219 rotation + 13/13 leveling).
**Root cause:** Commit `4f29f9af` (EAXFishing v2.4.0 commit 6) used `SKIP_LUAC=1` and accidentally corrupted 25 EaxRotations Lua files. All 25 files have no commits after `4f29f9af`, so reverting each to `4f29f9af^` is safe.

## Phase 1 — Restore corrupted Lua files
- [ ] Checkout 25 files from `4f29f9af^` (pre-corruption state)
- [ ] Verify `luac -p` passes for every restored file
- [ ] Run full `lua EaxRotations/tests/run_rotation_tests.lua`
- [ ] Run full `lua EaxRotations/tests/run_leveling_tests.lua`
- [ ] If >2 repair loops on the same file, stop and write a sub-debug plan per R5

## Phase 2 — Restore accidentally deleted docs
- [ ] Checkout deleted `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `RELEASE.md`, release notes, research doc
- [ ] Confirm these are the intended release docs

## Phase 3 — Validate current-tree changes
- [ ] Review remaining working-tree modifications (`core_sylvanas.lua`, `retribution_sylvanas.lua`, shared modules changed in small diffs)
- [ ] Ensure they still pass `luac -p` and tests
- [ ] Validate binary blobs (`common`, `core_lua`, `core_universal_kicks`, `dev_developer_tools`) before release

## Phase 4 — Commit
- [ ] Stage fixes with conventional commit message describing the regression repair
- [ ] One concern per commit: restore Lua files, restore docs, then validate any intentional current work

## Notes
- `4f29f9af` commit message explicitly says `SKIP_LUAC=1` was used because of "conflict markers from an in-progress merge." That signature points directly to this commit as the corruption source.
- All 25 syntax-error files are unique to this commit; no later commits depend on their current corrupted state.
