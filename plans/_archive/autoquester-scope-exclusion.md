# Plan: EaxAutoQuester — Out of Scope (2026-06-22)

## Decision

**EaxAutoQuester is explicitly OUT OF SCOPE for the 2026-06-22 Sylvanas API
compliance task.** It is listed here so future agents do not re-litigate.

## Why

The original task brief was:

> debug, research, Fix and implement proper fixes for @EaxESP\
> @EaxRotations\ @EaxProfessions\

EaxAutoQuester was NOT in the three directories named. AGENTS.md Rule 6 (Never
edit reference-system clones) and the explicit task wording both point to
the three packages above as the deliverable surface.

Although Oracle flagged that EaxAutoQuester has 7/28 test failures and 14+
`math.sqrt` distance-comparison regressions, those are a SEPARATE cleanup
effort that should be planned on its own merits. Bundling it into the
2026-06-22 work risks:

1. **Scope creep** — the task was specifically scoped to the three named
   directories and "make them 100% complicant with project sylvanas api".
2. **Cross-module API coupling** — `EaxAutoQuester/loot_manager_sylvanas.lua`
   is `require`-d by `EaxProfessions/profession_state/loot_state.lua`. Any
   change to one affects the other.
3. **Test cascade** — the 7 failing EaxAutoQuester tests would require their
   own triage pass with separate Oracle verification.

## What this plan delivers

1. **Document the out-of-scope decision** in `plans/` (this file).
2. **Leave EaxAutoQuester untouched** in this commit.
3. **Track known EaxAutoQuester compliance debt** in this file so a future
   dedicated effort (`plans/autoquester-compliance.md`) can pick it up.

## Known EaxAutoQuester Compliance Debt (for future work)

### CRITICAL: QuayQuester test failures (7/28 as of 2026-06-22)

```
test_npc_db.lua
test_npc_manager.lua
test_pre_accept_all.lua
test_step_lookahead.lua
test_transport_helper.lua
test_vendor_bag_trigger.lua
```

### HIGH: math.sqrt distance comparisons (AGENTS.md Pattern 3 violations)

14+ occurrences across:
- `EaxAutoQuester/quest_state/dead_state.lua`
- `EaxAutoQuester/quest_state/nav_state.lua`
- `EaxAutoQuester/quest_state/idle_state.lua`
- `EaxAutoQuester/quest_state/do_action_state.lua`
- `EaxAutoQuester/quest_state/coordinator.lua`
- `EaxAutoQuester/shared/corpse_loot.lua`
- `EaxAutoQuester/npc_manager_sylvanas.lua:253`
- `EaxAutoQuester/quest_state_sylvanas.lua`
- `EaxAutoQuester/quest_interaction_sylvanas.lua`
- `EaxAutoQuester/loot_manager_sylvanas.lua`
- `EaxAutoQuester/equipment_compare_sylvanas.lua`
- `EaxAutoQuester/combat_helper_sylvanas.lua`
- `EaxAutoQuester/utils_sylvanas.lua`

### MEDIUM: likely ctx.deps.config stylistic issues

May have remaining `ctx.deps.config` references similar to the EaxProfessions
fix applied in this task. A targeted grep + fix pass is required before any
EaxAutoQuester deployment.

## Recommended next steps (separate plan)

When the project decides to tackle EaxAutoQuester compliance:

1. Create `plans/autoquester-compliance.md` with the same wave structure
   (CRITICAL → HIGH → MEDIUM).
2. Run Oracle round on EaxAutoQuester to identify scope.
3. Address test failures first (CRITICAL path).
4. Migrate `math.sqrt` distance compares to squared arithmetic in
   `quest_state/*.lua`.
5. Audit and fix any remaining `ctx.deps.config` references.
6. Verify EaxProfessions still works because it `require`s EaxAutoQuester
   modules.

## Verification of THIS plan

- This file exists at `plans/autoquester-scope-exclusion.md`
- No edits to anything under `EaxAutoQuester/` occurred in the
  2026-06-22 compliance work.
- EaxESP, EaxRotations, EaxProfessions: all tests green.

(End of plan)
