# Debugging Note: RALPH LOOP 2/500 — blocked, task list truncated

**Date:** 2026-06-19
**Source trigger:** Autonomous Ralph-loop directive at iteration 2/500
(`[SYSTEM DIRECTIVE: OH-MY-OPENCODE - RALPH LOOP 2/500]`)
**Status:** BLOCKED — cannot proceed with autonomous implementation safely.
**Rule invoked:** Agent Contract rule 5 (loop breaker; debugging note in `plans/`).

---

## What happened

The directive arrived with the eight non-negotiable guardrails intact, then
ended mid-sentence inside the second guardrail:

> `2. GATE EVERY TASK: luac -p <changed files> AND`
> `   lua EaxRotations/tests/run_rotation_tests.lua must both pass before commit.`
> `   If either fails → fix or REVERT (git reset`

Everything after `git reset` — including the actual enumeration of the
"4 tracks" the directive told me to "work END TO END" — was not present in
the message I received.

I exhaustively searched the repository for the missing content:

- `grep` for `4 track|four track|TRACK 1|TRACK 2|TRACK 3|TRACK 4` across the
  whole tree → 0 matches.
- `grep` for `[Tt]rack\s+[1-4]|[Rr]alph|continue from` → 0 matches.
- Listed `plans/`, `plans/_active.md`, `plans/_archive/<tool>/`, `.opencode/`,
  `.claude/`, `.openclaude/`, `.agents/`. No scratch file or hand-off note
  contained the lost task list.
- `git stash list` → 2 stashes (`stash@{0}` = `refactor: remove force_command
  system and add buff upgrade + APL registry`; `stash@{1}` = `fix(audit):
  add ScatterShot, fix nil-guards, clean 11958 residue`). Neither is tagged
  with a track list.
- `git log --oneline --all -20` and `git reflog` → standard refactor /
  docs / spec-kit history. No track-list commit.

The 4 tracks were never delivered to this loop iteration in any form I can
find, so I will not invent them. Per the hard block in the operating
charter ("Speculate about unread code — Never") plus Agent Contract rule 5
("If a task loops more than 2 attempts, STOP. Write a debugging note in
`plans/` describing the failure instead of retrying"), I stop here.

---

## Evidence collected (in case this note is what the next iteration needs)

### Active plans in `plans/_active.md`

| Plan | Status | Next step (per file) |
|------|--------|---------------------|
| `refactor-developer-experience-2026-06.md` | in-progress | Phase 1 mostly done in repo history. Phase 2 (split `core_sylvanas.lua`) partly done — see git commits below. Phase 3 + 4 not started. |
| `api-integration-2026-06.md` | stale — review | 8 Sylvanas API integrations. Many of the deliverable files are untracked in the working tree (see below). Verify landing. |
| `eaxrotations-cross-class-robustness-sweep.md` | stale — review | 4 bug classes across 9 classes; partially addressed. Needs audit run. |

### "Likely complete" plans listed in `_active.md` (9)

`01-performance-optimization.md`, `02-shaman-tbc-rotation.md`,
`apl_lua_diff_2026_06_13.md`, `apl_to_lua_mapping_2026_06_13.md`,
`eaxrotations-bugfix-2026-06-13.md`, `flux-import-hunter-adaptive.md`,
`flux-import-warrior-rage-pooling.md`, `hardcoded-to-api-migration.md`,
`rake-claw-pve-builder.md`, `remaining-gaps-2026-06.md`,
`tier1-simplification.md`. Dated Jun 9–15, probably already landed.

### Branch state

- `master`, **76 commits ahead** of origin/master.
- Recent commits (latest first):
  `dc42bee5 docs(rogue): add Pattern 15 readability headers…`
  `bdf23742 docs(hunter): add Pattern 15 readability headers…`
  `836a8698 refactor(core): extract cooldown registry to core/cooldowns.lua`
  `64c5a26b refactor(core): extract items/equipment domain to core/items.lua`
  `be3bda86 refactor(core): extract GetPlayer/GetPet/has_pet/get_pet_hp to core/units.lua`
  `e275b699 refactor(core): extract settings domain to core/settings.lua`
  `9dad5877 feat(shared): port spec_kit to shared/spec_kit_sylvanas.lua`
  `940bd97b refactor(shared): consolidate get_player() into player_helpers_sylvanas`
  `a9a05d1d refactor(shared): consolidate safe/safe_field helpers via safe_helpers_sylvanas`
  `f723522e refactor(warrior): convert arms_sylvanas.lua boilerplate to spec_kit`

### Working-tree state

**Modified (tracked):**
- `AGENTS.md`, `EaxRotations/main_sylvanas.lua`,
  `EaxRotations/classes/druid/schema_sylvanas.lua`,
  `EaxRotations/tests/run_rotation_tests.lua`,
  `EaxRotations/tests/test_bear_custom_matches.lua`,
  `EaxRotations/tests/test_cat_custom_matches.lua`,
  `EaxRotations/tests/test_cat_snapshot_upgrade.lua`,
  `EaxRotations/tests/test_state_field_nil_guards_2026_06.lua`.

**Untracked files that align to `api-integration-2026-06.md`:**

| Plan task reference | Untracked artifact |
|---------------------|--------------------|
| `los_to` | `EaxRotations/shared/los_guard_sylvanas.lua`, `EaxRotations/tests/test_los_guard.lua` |
| `get_all_missiles` | `EaxRotations/shared/missile_tracker_sylvanas.lua`, `EaxRotations/tests/test_missile_tracker.lua` |
| `get_override_spell_id` / `get_base_spell_id` | `EaxRotations/shared/spell_resolver_sylvanas.lua`, `EaxRotations/tests/test_override_spell.lua`, `tests/test_spell_resolver_cache.lua` |
| `get_spell_range_data` | `EaxRotations/tests/test_spell_range_data.lua` |
| `get_pet_happiness` | `EaxRotations/tests/test_pet_happiness.lua` |
| `is_tap_denied` | `EaxRotations/tests/test_tap_denied.lua` |
| `get_boss_count` | `EaxRotations/tests/test_boss_count.lua` |
| `get_talent_info` | `EaxRotations/tests/test_talent_context.lua` |
| (adjacent) | `EaxRotations/tests/test_match_helpers_sylvanas.lua`, `test_stealth_helper.lua`, `test_hunter_dead_zone.lua`, `test_hunter_dead_zone.lua`, `test_protection_paladin_custom_matches.lua`, `test_pvp_ooc_target_block.lua`, `test_runtime_orphan_modules.lua`, all `test_*_custom_matches.lua` updates, `EaxRotations/shared/hunter_adaptive_sylvanas.lua`, `EaxRotations/shared/stealth_helper_sylvanas.lua`, `EaxRotations/shared/match_helpers_sylvanas.lua`, `EaxRotations/shared/wowhead_data_bridge_*_sylvanas.lua` (3) |

**Reference clones (out of scope):** `_flux_tbc_explore/`, `tbc-main/`,
`tbc_roblox/`, `EaxESP/`, `tbc-new/`, `ClassResearchTBC/` — these are
GGL-platform reference clones, untracked, not ours to refactor.

**Out-of-tree products:** `EaxAutoQuester/` (tracked additions aligned to
EaxAutoQuester plans; not in scope of `EaxRotations/`-focused plans),
`EaxESP/`, `EaxProfessions/`, `telemetry_addon/`, `telemetry_server/`,
`eax_refactor/` (sandbox, see AGENTS.md).

---

## What I would do if the directive is re-issued with explicit tracks

Without the explicit list, I see four plausible axes of work in the
working tree, each track being a sequence of atomic commits gated by
`luac -p` + `lua EaxRotations/tests/run_rotation_tests.lua`:

1. **Track A — complete `api-integration-2026-06.md`.** Verify each of the
   8 untracked deliverable pairs (shared module + test), wire tests into
   `run_rotation_tests.lua`, register modules in `main_sylvanas.lua` if
   not auto-loaded, and commit one concern per API.
2. **Track B — finish `refactor-developer-experience-2026-06.md` Phase 2/3/4.**
   Phase 2 has 4 of ~7 extractions committed (settings, units, items,
   cooldowns auditing core_sylvanas.lua size). Remaining extractions:
   `casting.lua`, `ttd.lua`, `talents.lua`, `diagnostics.lua`, then
   `scripts/validate.cmd` (Phase 3.1, must land BEFORE Phase 2 finishes
   per the plan's "Critical ordering rule"), then `spec_kit` prove-on-arms
   (Phase 4).
3. **Track C — execute `eaxrotations-cross-class-robustness-sweep.md`.**
   Audit `EaxRotations/classes/` for raw `unit == me` / `unit ~= target`
   comparisons; the plan lists 7 sites across Warrior Prot (4), Paladin
   Prot (2), Priest Disc (1). Plus `get_power` power-type audit and
   unthrottled build_state scans.
4. **Track D — bookkeeping.** Archive the 9 likely-complete plans after
   `git log` confirms each landed; update `_active.md` accordingly.

If you want me to run any subset as the "4 tracks," re-issue the directive
naming them (e.g. "Track A: api-integration. Track B: refactor Phase 2/3.
Track C: cross-class robustness. Track D: archive pass.") and I will
execute them as atomic commits.

---

## To unblock

Re-issue the Ralph-loop directive with the explicit enumerated task list,
or correct this note by telling me which 4 axes you meant. Until one of
those happens, `_active.md` does not list this as an active effort (this
note lives in `_archive/`, not `_active/`).

— Loop iteration 2 terminated; awaiting directive.
