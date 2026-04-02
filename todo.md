# EAX Healer Enhancement Todo

Last updated: 2026-03-29

## Guardrails

- [x] Confirm scope is `scripts/` only
- [x] Confirm `.api/` is read-only and must not be modified
- [x] Treat `scripts/ni-main/docs/api/**` as read-only reference only
- [x] Treat `scripts/NAG/**` as read-only concept/reference only
- [x] Verify every imported concept maps to a Project Sylvanas API or existing EAX helper before implementation
- [x] Verify no changes are made outside approved EAX paths used by this healer pass

## Writable Scope

- `scripts/libraries/**`
- `scripts/EAXDruidRestoration/main.lua`
- `scripts/EAXShamanRestoration/main.lua`
- `scripts/EAXPaladinHoly/main.lua`
- `scripts/EAXPriestHoly/main.lua`
- `scripts/EAXPriestDiscipline/main.lua`

## Reference Inputs

- `scripts/ni-main/docs/api/**`
- `scripts/NAG/**`
- existing EAX healer/tank modules under `scripts/libraries/**`

## Phase 0 - Planning and Mapping

- [x] Review current EAX healer/tank state
- [x] Compare EAX healer behavior against NAG concepts at a high level
- [x] Identify Sylvanas-native equivalents already used in EAX (`get_incoming_heals`, combat context, helper modules)
- [x] Decide orchestration path: shared healer core first, spec tuning second, verification after each phase

## Phase 1 - Shared Healer Core

### 1.1 Shared healing engine
- [x] Decide whether to generalize from `EAXShamanRestoration/heal_engine.lua` into `libraries/heal_engine.lua`
- [x] Build a Sylvanas-native effective HP model using only supported APIs
- [x] Keep incoming-heal-aware friend sorting cached and reusable
- [x] Preserve TBC-safe tank priority rules
- [x] Route `EAXShamanRestoration/heal_engine.lua` to the shared module

### 1.2 Shared triage improvements
- [x] Update `libraries/healer_triage.lua` to use effective HP / incoming-heal-aware decisions
- [x] Improve tank-save vs triage-save vs group-stabilize branching
- [x] Centralize conservative covered-target hold logic
- [x] Route the 5 healer specs to shared `libraries/healer_triage.lua`

### 1.3 Shared mana and overheal rules
- [x] Define shared mana-floor rules for healers
- [x] Define shared affordability rules for cast selection
- [x] Define shared stopcast / overheal-cancel rules using Sylvanas data only

### 1.4 Shared context validation
- [x] Confirm `libraries/combat_context.lua` already exposes everything needed
- [x] Extend shared context only if required by healer logic
- [x] Avoid adding non-Sylvanas abstractions copied from NAG

## Phase 2 - Healer Spec Integration

### 2.1 Druid Restoration
- [x] Wire shared healer core into `EAXDruidRestoration/main.lua`
- [x] Tune HoT maintenance around TBC resto priorities
- [x] Tune Swiftmend and Nature's Swiftness emergency logic
- [x] Re-check mana pacing and DPS fallback behavior

### 2.2 Shaman Restoration
- [x] Wire shared healer core into `EAXShamanRestoration/main.lua`
- [x] Keep or refactor existing `heal_engine.lua` if shared engine supersedes it
- [x] Tune Chain Heal, Earth Shield, and emergency direct heal rules
- [x] Re-check totem/healing interaction edge cases

### 2.3 Paladin Holy
- [x] Wire shared healer core into `EAXPaladinHoly/main.lua`
- [x] Tune Holy Light / Flash of Light / Holy Shock thresholds
- [x] Tune Divine Illumination and Avenging Wrath emergency usage
- [x] Re-check blessing and cleanse behavior under full auto

### 2.4 Priest Holy
- [x] Wire shared healer core into `EAXPriestHoly/main.lua`
- [x] Tune Renew / Prayer of Mending / Circle of Healing / Prayer of Healing priorities
- [x] Re-check raid-healing windows vs tank-save windows

### 2.5 Priest Discipline
- [x] Wire shared healer core into `EAXPriestDiscipline/main.lua`
- [x] Tune Power Word: Shield priority and emergency response behavior
- [x] Tune Pain Suppression and throughput cooldown conditions

## Phase 3 - Tank/Healer Coordination

- [x] Review `libraries/tank_recovery.lua` interaction with healer triage decisions
- [x] Ensure tank-collapse windows are respected in dungeon and raid automation
- [x] Confirm healer automation does not over-prioritize raid padding over tank survival

## Phase 4 - Verification

- [ ] Run `lsp_diagnostics` on every touched file after each phase
- [x] Run Lua syntax validation on touched healer/shared files
- [ ] Re-check final touched paths to ensure `.api`, docs, and `NAG` stayed untouched
- [x] Validate logic against Sylvanas docs/reference, not NAG implementation details
- [x] Inspect available runtime artifacts/logs if behavior needs confirmation

## Progress Notes

- 2026-03-29: Created shared `libraries/heal_engine.lua`
- 2026-03-29: Routed the five healer specs to shared `libraries/healer_triage.lua`
- 2026-03-29: Routed `EAXShamanRestoration/heal_engine.lua` to shared `libraries/heal_engine.lua`
- 2026-03-29: Updated shared triage to understand raw HP, effective HP, priority HP, and incoming-heal-aware cancel rules
- 2026-03-29: Added shared `heal_engine.make_member()` / `make_snapshot()` helpers and wired Druid / Holy Paladin / Holy Priest / Discipline Priest to them
- 2026-03-29: Added shared mana-floor hooks to `libraries/spell_downrank.lua` and applied them to Restoration Shaman downranking
- 2026-03-29: Switched Paladin / Holy Priest / Discipline Priest target-selection, dispel priority, and direct-heal decisions further toward effective HP instead of raw HP
- 2026-03-29: Switched Druid healing-activation, dispel priority, and reactive self-save checks toward effective HP where safe
- 2026-03-29: Removed the remaining Priest Holy / Discipline `utils.find_low_health_ally(...)` fallbacks in main healing paths in favor of effective-HP ally selection
- 2026-03-29: Improved Discipline tank picking to prefer the lowest effective-HP tank candidate; switched Shaman OOC self-heal threshold to effective HP
- 2026-03-29: Tuned Shaman direct-heal and Chain Heal selection, Paladin HL/FoL/HS thresholds, Priest Holy spell ordering, Priest Discipline tank-bias cooldown routing, and Druid tank-shell HoT maintenance
- 2026-03-29: Finished Phase 2 healer tuning: Druid Swiftmend/NS emergency gates + mana pacing, Shaman totem/heal safety, Paladin cooldown/blessing combat guards, and Holy Priest raid-heal windows vs direct saves
- 2026-03-29: Finished Phase 3 shared coordination: tank_save now outranks group_stabilize when the tank is the highest-risk target; reviewed `tank_recovery.lua` and kept it unchanged as the current logic was already conservative
- 2026-03-29: `lsp_diagnostics` could not run because Lua LSP is not installed in this environment; `luac -p` syntax validation passed on touched files

## Notes

- Copy NAG intent, not NAG code
- Prefer existing EAX shared modules over new abstractions unless reuse clearly improves reliability
- Keep changes surgical and TBC-specific
- Treat `scripts_data/benchmarks/**` as stale/broken legacy data; do not use it for current validation
- Repo-wide `git status` is already dirty in many unrelated paths, so final path auditing must be scoped to this healer pass rather than assumed from a clean tree
- Update this file as work completes
