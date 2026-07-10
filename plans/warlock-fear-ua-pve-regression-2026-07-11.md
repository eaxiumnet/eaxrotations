# Plan: Warlock Fear UA PvE Regression (PR series) — 2026-07-11

**Date:** 2026-07-11
**Status:** In Progress (PR1 complete after commit)
**Related:** warlock-fear-ua-pve-regression-design-2026-07-11.md (design source)
**PR:** PR: plans entry + schema (early for menu + fallback) + context clarification (non-spec)

## Problem
- Warlocks casting Fear on every pack in groups/dungeons (scatters mobs, annoys tanks).
- DoTs applied (Corruption etc.) without ensuring UA first (priority regression).
- Root: recent is_group allowance for CC_Fear (and similar) in affliction/demonology/destruction; UA strategies not preceding Corruption* in table despite doc header claiming "UA > Corruption".

Bug affects Affliction (primary), Demonology, Destruction in group PvE content.

## Design Summary (condensed from design doc)
- **Fear gating:** use_fear_cc (new) + strict `context.is_pvp` (no `or is_group` for player Fear). Howl of Terror may retain group emergency use, but player Fear and Succubus Seduction strictly PvP.
- **PvE suppression:** When not is_pvp, or setting off, never Fear primary target (prevents scattering). Debuff check on primary only.
- **UA priority:** Move UA + UA Spread strategies *before* all Corruption* (DoT, Spread, Moving) in the strategies table for Affliction (and equivalent in other specs if applicable). Update header comment.
- **Settings:** All via `spec_kit.*` (setting_bool for use_fear_cc). Nil-guard all numeric state (Pattern 14).
- **Context:** Clarify is_pvp vs is_group (non-spec changes in main/context builders if needed for precision; is_pvp_zone + flagged detection).
- **Menu:** Early schema entry so widget + default available before any spec wires the check.
- **Safety:** Update all touched file headers (Pattern 15) with explicit SAFETY note on Fear gating + UA order.
- **Tests:** All 252+ rotation + 17 leveling must pass; luac -p; no api/ touches.
- **Rollout:** PR1 = plan + schema only (no behavior change). Later PRs consume setting (default true = no PvP regression), reorder UA, tighten Fear matches, update headers.
- **Verification after schema:** "menu checkbox appears under General/PvP and toggles correctly; default true preserves prior PvP behavior".

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
- Minor doc touch to EaxRotations/README.md or docs/ *if needed* (none required for this PR).
- Verify: schema entry present; `spec_kit.setting` (and setting_bool) falls back to the documented default.
- No spec file edits (affliction_*, demonology_*, etc.). Context clarification documented here (non-spec work deferred or minimal).
- Gates: luac -p on .lua; full `lua EaxRotations/tests/run_rotation_tests.lua` (252+) + `run_leveling_tests.lua` (17) green.

## Later PRs (outline)
- PR2+: wire use_fear_cc + is_pvp strict gate into Fear matches (affl/dem/destro + leveling?); reorder UA before Corruption*; update headers + SAFETY lines; possibly context tweaks in non-spec files if required for is_pvp clarity; tests + luac.
- Ensure menu ID stable ("eaxwarlock_use_fear_cc" or via middleware).

## Validation for PR1
- Schema entry + default visible in menu system.
- No runtime change (setting not yet read by rotation logic).
- Baseline tests remain green (schema-only).
- luac -p clean.
- Commit per instructions.

## References
- design doc (original)
- AGENTS.md (Pattern 14/15/16, spec_kit, test gates, luac)
- EaxRotations/classes/warlock/*_sylvanas.lua (current Fear matches use `is_pvp or is_group`; UA after some Corruptions)
- main_sylvanas.lua (context.is_pvp / is_group construction)
- shared/spec_kit_sylvanas.lua (for fallback behavior)
