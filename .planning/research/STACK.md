# Stack Research

**Domain:** EAX TBC Classic Rotations - Druid reliability fixes (Resto policy + Feral finishers)
**Researched:** 2026-03-21
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Lua runtime in Sylvanas plugins | Lua 5.x (project constrained) | Runtime for all rotation logic | No runtime change is needed; reliability fixes should stay in-process and deterministic inside existing tick loop.
| Sylvanas `game_object` + `core` API surface | Local `.api` snapshot (current repo) | Authoritative combat/group/power reads | Current API already exposes `is_party_member`, `get_group_role`, `get_power`, and `get_combo_points_target`; these are sufficient to fix both milestone behaviors without new dependencies.
| `eax_shared` policy/runtime path | Current v2.1.0 codebase modules | Shared decision layer for specs | Existing `combat_context`, `role_policy`, `reactive_runtime`, and `encounter_manager` provide stable integration points; extend them rather than adding parallel logic in spec files.
| **New internal module:** `eax_shared/group_context_gate.lua` | New for this milestone | Reliable group-vs-solo classification and DPS lock state | Current spec-local mode detection scans objects and can drift; a single gate module prevents Resto DPS in any grouped/boss context and centralizes override rules.
| **New internal module:** `eax_shared/feral_finisher_state.lua` | New for this milestone | Combo-point/target/energy truth model for finisher decisions | Feral currently mixes API reads and cast-callback fallback paths; a dedicated state module prevents CP desync and incorrect finisher timing.

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `eax_shared/dps_risk.lua` | Existing | Safety gating for offensive casts based on threat/damage pressure | Use for **Resto solo-only DPS allow** checks (never for grouped contexts).
| `eax_shared/encounter_manager.lua` | Existing | Boss-context signal (`is_boss`, raid pressure flags) | Use as a hard lock input in `group_context_gate` so boss fights never enter solo-DPS path.
| `common/modules/spell_queue` | Existing | Cast request queue with dedupe timing | Keep for action dispatch, but treat it as transport only; do not use queue callbacks as primary CP truth.
| `eax_shared/dps_meter.lua` | Existing | Runtime counters/telemetry | Add milestone-specific counters (`resto_dps_suppressed_count`, `feral_cp_desync_count`, `feral_finisher_cast_at_cp`) to validate reliability before close.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Existing manual validation loop (`tools/rotation_validation.lua` + benchmark workflow) | Regression checks for milestone behavior | Extend checks for policy lock and finisher correctness; do not add a new test framework for this milestone.
| `.api` contract files (`.api/game_object.lua`, `.api/common/enums.lua`) | API compatibility guardrails | Treat as source of truth for allowed/expected API calls; avoid undocumented helpers in production path.

## Milestone Module Plan (Integration Points)

1. Add `eax_shared/group_context_gate.lua` and call it from `EAXDruidRestoration/main.lua` before `do_dps_fallback`.
2. Replace spec-local `detect_mode` as DPS authority with `group_context_gate.evaluate(...)`; keep menu mode as optional override input, not final source of truth.
3. Add `eax_shared/feral_finisher_state.lua`; wire into `EAXDruidFeral/main.lua` at:
   - pre-rotation sync (before finisher/builders),
   - finisher selection (`try_rip`, `try_ferocious_bite`),
   - cast callback reconciliation.
4. Use API-first CP reads (`get_power(COMBOPOINTS_TBC)` + `get_combo_points_target`) and only then fallback paths.
5. Emit telemetry counters through `eax_shared/dps_meter.lua` for milestone acceptance evidence.

## Installation

```bash
# No new external packages for this milestone.
# Keep deployment model unchanged: Lua files copied into Sylvanas scripts folder.

# New work is internal modules only:
# - eax_shared/group_context_gate.lua
# - eax_shared/feral_finisher_state.lua
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Shared `group_context_gate` module | Keep per-spec `detect_mode()` object-scan logic | Only acceptable as temporary fallback while migrating old specs; not reliable enough for this milestone's Resto lock guarantee.
| API-first CP state (`get_power` + CP target) | Cast-event-only combo tracking | Use only as emergency fallback when API read fails in a tick; never as primary source.
| Finisher policy based on exact TBC spell semantics | Generic "energy >= CP*35" bite heuristic | Do not use for TBC; bite has base 35 energy and extra-energy conversion behavior, so CP*35 gating is mechanically wrong.

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Any external Lua packages or sidecar runtimes | Violates project constraints and adds zero value for these two fixes | Internal `eax_shared` modules only.
| Resto DPS decision keyed only off `runtime.cached_mode` | Mode cache can be stale/incorrect in edge cases; risks DPS in grouped content | `group_context_gate` with party-member + encounter boss lock inputs.
| Undocumented `me:get_combo_points()` as primary logic | Not in authoritative `.api/game_object.lua`; behavior can vary | `me:get_power(enums.power_type.COMBOPOINTS_TBC)` + `me:get_combo_points_target()`.
| Feral Bite gate `energy >= combo_points * 35` | Not aligned with TBC Ferocious Bite cost model; causes missed/late finishers | Base-cost gate + explicit overcap and target-TTD rules in `feral_finisher_state`.
| New persistence/state DB for CP tracking | Adds complexity and failure modes for per-fight ephemeral state | Tick-local state + short-lived runtime cache only.

## Stack Patterns by Variant

**If Resto is in party/raid or boss context:**
- Use hard DPS suppression (heal/utility only).
- Because milestone requirement is a reliability guarantee, not a preference.

**If Resto is truly solo:**
- Allow offensive casts only when `dps_risk.should_hold_offense(...) == false` and self/party safety thresholds pass.
- Because solo uptime matters, but survivability must still dominate.

**If Feral has CPs and CP target mismatches current target:**
- Freeze finisher pipeline, resolve/retarget to CP holder or clear CP state explicitly.
- Because target drift is the top cause of finisher waste.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `Lua 5.x` rotation code | Sylvanas plugin runtime | Keep syntax/runtime assumptions unchanged for all new modules.
| `me:get_power(enums.power_type.COMBOPOINTS_TBC)` | `.api/common/enums.lua` + `.api/game_object.lua` | Primary TBC-safe CP source.
| `me:get_combo_points_target()` | `.api/game_object.lua` | Required to enforce CP target affinity and prevent finisher waste on target swaps.
| `group_context_gate` (new) | `encounter_manager.get_policy()` + `is_party_member` scans | Boss flag acts as hard lock against solo-DPS behavior.

## Sources

- `C:\newbot\scripts\.planning\PROJECT.md` - milestone scope, constraints, validated capabilities (HIGH)
- `C:\newbot\scripts\.api\game_object.lua` - authoritative available APIs (`is_party_member`, `get_group_role`, `get_power`, `get_combo_points_target`) (HIGH)
- `C:\newbot\scripts\.api\common\enums.lua` - `power_type.COMBOPOINTS_TBC` availability (HIGH)
- `C:\newbot\scripts\EAXDruidRestoration\main.lua` - current Resto mode detection and DPS fallback integration point (HIGH)
- `C:\newbot\scripts\EAXDruidFeral\main.lua` - current CP sync, finisher logic, and cast-callback fallback behavior (HIGH)
- `C:\newbot\scripts\eax_shared\dps_risk.lua` - existing offense safety gate module (HIGH)
- `C:\newbot\scripts\eax_shared\encounter_manager.lua` - boss-context policy inputs (HIGH)
- https://wowclassicdb.com/tbc/spell/24248 - TBC Ferocious Bite cost and extra-energy conversion semantics (MEDIUM)
- https://www.icy-veins.com/tbc-classic/feral-druid-dps-pve-rotation-cooldowns-abilities - current community finisher guidance and bite usage notes (MEDIUM)
- https://www.icy-veins.com/tbc-classic/restoration-druid-healer-pve-rotation-cooldowns-abilities - current Resto healing-priority framing in group PvE (MEDIUM)

---
*Stack research for: Druid reliability fixes (Resto group-vs-solo DPS policy + Feral finisher reliability)*
*Researched: 2026-03-21*
