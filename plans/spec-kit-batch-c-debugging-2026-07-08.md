# spec_kit Batch C — debugging note (2026-07-08)

## Status: ✅ COMPLETED (2026-07-08 session)

The migrate_spec_kit_batch_c.py script in repo root was the third iteration
attempt to automate Batch C (78 legacy local settings = context.settings or {}
blocks remaining across 6 class middleware files + 3 leveling specs).

After the automated pply mode failed (luac errors + 11 test failures),
files were reverted. Per AGENTS.md Rule 5, automation was abandoned and the
remaining blocks were **manually migrated** one file at a time, following the
proven Batch A/B pattern. All 9 files are now complete.

## What works (script remains useful)
- scan mode — every local settings = ... block is found and classified
  as matched / unmatched with line numbers and a sample of unmatched reads.
- pply --dry-run — applies transformations in memory and reports what
  would change, without writing to disk.
- Idempotency — re-running on already-migrated files is a no-op.

## What failed (historical)
1. **ensure_spec_kit_require() inserts at a wrong location** for the
   3 leveling_sylvanas.lua files (different header shape).
2. **16 reads were [UNMATCHED]** under the TRANSFORM_PATTERNS regex set
   (compound conditionals, truthy checks, string defaults).
3. **Block-scope detection is fragile** for nested closures.

## Manual migration results (2026-07-08)

| # | File | Blocks | Unmatched | Status |
|---|------|--------|-----------|--------|
| 1 | warrior/middleware_sylvanas.lua | 14 | 0 | ✅ Migrated (1 dynamic-key block intentionally preserved) |
| 2 | hunter/middleware_sylvanas.lua | 12 | 0 | ✅ Migrated |
| 3 | priest/middleware_sylvanas.lua | 14 | 0 | ✅ Migrated |
| 4 | shaman/middleware_sylvanas.lua | 7 | 0 | ✅ Migrated |
| 5 | druid/middleware_sylvanas.lua | 11 | 1 | ✅ Migrated (compound block manually handled) |
| 6 | paladin/middleware_sylvanas.lua | 17 | 2 | ✅ Migrated (2 truthy-check blocks manually handled) |
| 7 | paladin/leveling_sylvanas.lua | 1 | 0 | ✅ Migrated (empty block removed) |
| 8 | hunter/leveling_sylvanas.lua | 1 | 0 | ✅ Migrated |
| 9 | shaman/leveling_sylvanas.lua | 1 | 13 | ✅ Migrated (all simple patterns, regex just missed them) |

**Commits (8 atomic commits on master):**
1. c06f1c61 — refactor(warrior/middleware): migrate settings blocks to spec_kit.setting_*()
2. 9ea88b8c — refactor(hunter/middleware): migrate settings blocks to spec_kit.setting_*()
3. 9c763a87 — refactor(priest/middleware): migrate settings blocks to spec_kit.setting_*()
4. cb296799 — refactor(shaman/middleware): migrate settings blocks to spec_kit.setting_*()
5. 36eb074b — refactor(druid/middleware): migrate settings blocks to spec_kit.setting_*()
6. c7b4a5e3 — refactor(paladin/middleware): migrate settings blocks to spec_kit.setting_*()
7. c9cc7ca5 — refactor(paladin/hunter/leveling): migrate settings blocks to spec_kit.setting_*()
8. e9c92cf — refactor(shaman/leveling): migrate settings blocks to spec_kit.setting_*()

## Verification
- luac -p on all 469 Lua files: ✅ PASS
- Rotation tests: 245/245 ✅ PASS
- Leveling tests: 13/13 ✅ PASS
- Vanilla audit: 31/31 clean ✅ PASS
- Sylvanas audit: 61/61 clean ✅ PASS
- **Zero unmatched reads** across all 9 files (scan mode confirms)

## Remaining intentional legacy block
- warrior/middleware_sylvanas.lua L239: local settings = context.settings or {}
  inside SmartHSDequeue execute function. Uses **dynamic key reads**
  (settings[exec_key], settings[hs_exec_key]) that cannot be mapped to
  static spec_kit.setting_*() calls. This is by design and preserved.

## Origin/master state
- Last push: e9c92cf (Batch C complete, all green)
- Working tree clean.
- origin/master at 42042e66 — local branch is 8 commits ahead.
