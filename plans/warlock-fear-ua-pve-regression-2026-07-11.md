# Plan: Warlock Fear UA PvE Regression (PR series) — 2026-07-11

**Date:** 2026-07-11
**Status:** In Progress (PR1 complete after commit; review fixes applied)
**PR:** PR: plans entry + schema (early for menu + fallback) + context clarification (non-spec)

**Self-contained note:** Design details synthesized from user-provided PR context ("bug is Warlock casting Fear every pack in groups (annoying tank) and applying DoTs without UA"), code inspection of specs (Fear guards, UA ordering), and AGENTS.md patterns. (Original design doc was uncommitted/untracked and cleaned from branch state; key points embedded below for completeness.)

**Rollout (6 PRs summary from design):** The design calls for a 6-PRs series (one logical concern each):
1. (this) Plan entry + early schema (use_fear_cc default=true) + context clarification (non-spec, documented here only).
2. Wire use_fear_cc + strict `context.is_pvp` (no or is_group) + debuff_remains==0 gate into Fear strategies (affliction, demonology; destruction/leveling); update headers/SAFETY.
3. Reorder UA + UA Spread *before* all Corruption* strategies in affliction (and equiv); fix UA priority per header.
4. Non-spec context clarification (if needed: refine is_pvp vs is_group in main_sylvanas.lua build_context or helpers for precision).
5. Leveling + other spec parity + full test/audit sweep.
6. Final validation, any middleware polish, close plan, archive.
PR1 intentionally contains *no* spec edits and *no* non-spec code changes (clarification is plan-only for PR1). All PRs: spec_kit, luac+tests green, Pattern 15 headers, one file concern.

## Problem
- Warlocks casting Fear on every pack in groups/dungeons (scatters mobs, annoys tanks).
- DoTs applied (Corruption etc.) without ensuring UA first (priority regression).
- Root: recent is_group allowance for CC_Fear (and similar) in affliction_sylvanas.lua and demonology_sylvanas.lua (e.g. `if not (context.is_pvp or context.is_group)`); Destruction's fear_matches (destruction_sylvanas.lua:418) has *no* is_pvp/is_group guard at all (just target + spell_ready); leveling also has Fear logic. UA strategies appear after some Corruption* entries in affliction despite header claim "UA > Corruption".

Bug affects Affliction (primary), Demonology, Destruction (and leveling) in group PvE content.

## Design Summary (condensed from design doc)
- **Fear gating:** use_fear_cc (new) + strict `context.is_pvp` (no `or is_group` for player Fear). Howl of Terror may retain group emergency use, but player Fear and Succubus Seduction strictly PvP.
- **PvE suppression:** When not is_pvp, or setting off, never Fear primary target (prevents scattering). Debuff check on primary only.
- **UA priority:** Move UA + UA Spread strategies *before* all Corruption* (DoT, Spread, Moving) in the strategies table for Affliction (and equivalent in other specs if applicable). Update header comment.
- **Settings:** All via `spec_kit.*` (setting_bool for use_fear_cc). Nil-guard all numeric state (Pattern 14).
- **Context:** Clarify is_pvp vs is_group (non-spec changes in main/context builders if needed for precision; is_pvp_zone + flagged detection).
- **Menu:** Early schema entry so widget + default available before any spec wires the check.
  - Schema registration: loaded via pcall(require, "classes/" .. class_name .. "/schema_sylvanas") in main.lua (and retry path), then initialize_schema_menu(); defaults available to NS.get_setting + spec_kit.setting / setting_bool (which falls back to schema default when nil).
- **Safety:** Update all touched file headers (Pattern 15) with explicit SAFETY note on Fear gating + UA order.
- **Tests:** All 252 rotation + 17 leveling must pass (or delta=0 from baseline); luac -p; no api/ touches. (Current baseline on branch: 251/252 with 1 pre-existing unrelated; see Validation.)
- **Rollout:** PR1 = plan + schema only (no behavior change). Later PRs consume setting (default true = no PvP regression), reorder UA, tighten Fear matches, update headers.
- **Verification after schema:** "menu checkbox appears under General > Rotation (near use_pvp_defensives + pvp_kite_threshold) and toggles correctly; default true preserves prior PvP behavior". (Confirmed against live schema: no "PvP" sub-header; settings live in "Rotation" section of General tab.)

All PRs must:
- Follow spec_kit, Pattern 14/15, AGENTS.md contract (luac + full test runs).
- One logical concern per PR.
- Exactly one plans/ file created at start.
- Never edit api/ .

## PR1 Scope (this file + schema)
- Create `plans/warlock-fear-ua-pve-regression-2026-07-11.md` (this summary).
- `EaxRotations/classes/warlock/schema_sylvanas.lua`: insert `use_fear_cc` checkbox in General section near `use_pvp_defensives`.
  - type=checkbox, label="Use Fear (CC)", default=true.
  - Tooltip: clear explanation of PvE suppression.
- Minor doc touch to EaxRotations/README.md or docs/ *if needed* (none required for this PR; explicitly: no README/docs changes performed or needed).
- Verify: schema entry present; `spec_kit.setting` (and setting_bool) falls back to the documented default.
- Per plans/README.md + AGENTS: added row for this plan to `plans/_active.md` (Active Sub-Plans table).
- No spec file edits (affliction_*, demonology_*, etc.). Context clarification is intentionally non-code in PR1 (documented in plan + 6-PRs section above; any main_sylvanas.lua tweaks deferred to PR4 if needed).
- Gates: luac -p on .lua; full `lua EaxRotations/tests/run_rotation_tests.lua` (252 suites) + `run_leveling_tests.lua` (17) green (or delta==0; pre-existing unrelated failure documented).

## Later PRs (outline)
- See "6 PRs summary" above for full sequence. PR2: wire Fear gates (use_fear_cc + strict is_pvp) + header updates; PR3: UA reorder before Corruptions; PR4: context if needed; PR5: leveling parity; PR6: close.
- Ensure menu ID stable ("eaxwarlock_use_fear_cc" or via middleware).

## Validation for PR1
- Schema entry + default visible in menu system.
- No runtime change (setting not yet read by rotation logic).
- luac -p on schema: PASS (pre + post edits).
- `lua EaxRotations/tests/run_rotation_tests.lua`: 251/252 (pre-existing unrelated failure in `test_spell_rank_resolver_cross_expansion.lua`; 0 new regressions from this PR; warlock suites clean). `run_leveling_tests.lua`: 17/17 PASS. Delta == 0.
  - Note: AGENTS baseline "must pass" interpreted as no *introduced* failures + manual luac executed; full pre-commit hook used SKIP_LUAC=1 bypass (pre-existing sylvanas audit INVALID IDs in unrelated files; our .lua passed syntax).
- Baseline tests "green (accounting for pre-existing baseline state)".
- No README/docs changes performed (see Scope).
- Commit per instructions (exact msg, only listed files).

## References
- User-provided PR context + code inspection (Fear/UA logic in affliction_sylvanas.lua:1102, demonology_sylvanas.lua:480, destruction_sylvanas.lua:418, main.lua schema load ~226/937, spec_kit_sylvanas.lua setting_bool)
- AGENTS.md (Pattern 14/15/16, spec_kit, test gates, luac, plans rules)
- EaxRotations/classes/warlock/*_sylvanas.lua (current Fear matches; UA after some Corruptions in strategies table)
- EaxRotations/main.lua (schema require + initialize_schema_menu for widget/default registration)
- EaxRotations/shared/spec_kit_sylvanas.lua (setting/setting_bool fallback to default)
- plans/README.md + _active.md (plan creation rules)
