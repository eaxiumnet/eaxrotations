# EaxRotations Status Audit Plan

## TL;DR
> **Summary**: Produce a complete offline status audit of EaxRotations across primary TBC specs, adjunct rotations, class support files, shared modules, healing behavior, local Sylvanas API usage, test coverage, missing work, and improvement opportunities.
> **Deliverables**:
> - `EaxRotations/docs/status_audit.md` with class/spec/function/healing/API/test status matrices.
> - `EaxRotations/docs/status_audit_index.json` with machine-readable rows for specs, support files, shared modules, and findings.
> - `evidence/eaxrotations-status-audit/` containing command transcripts and inventories.
> **Effort**: Large
> **Parallel**: YES - 5 waves
> **Critical Path**: Scope/schema lock -> inventories -> class/shared/API/test audits -> synthesis -> verification

## Context
### Original Request
`$omo:ulw-plan EaxRotations Is a large rotation system for project sylvanas built around @api and @apidocs - I want a full status of each class, function, healing, etc and see whats missing and what could be improved upon.`

### Interview Summary
- No further user interview is required. The user asked for a full status audit and invoked planning mode.
- Default decision: this plan produces an audit/report only. It must not change rotation behavior, add spells, add menus, refactor source, or normalize unrelated changes.
- Default decision: the primary status matrix covers the 29 TBC Sylvanas rotations described in `AGENTS.md`; adjunct registered rotations (`druid/caster_sylvanas.lua`, `warrior/kebab_sylvanas.lua`), leveling files, healing helpers, class middleware/schema files, vanilla files, and shared modules are audited in separate sections.
- Default decision: live Project Sylvanas client QA is out of scope. Runtime-only uncertainties must be marked `requires client verification`.

### Metis Review
Gaps addressed:
- Fixed report schema is required before auditing.
- Separate 29 primary specs from support, leveling, adjunct rotations, and vanilla regression surfaces.
- Validate report completeness directly; existing Lua tests do not prove audit completeness.
- Cross-check against `api/` and `apidocs/`; do not use skill-default `.api/` or `sylvanas-dev-docs-llm` paths.
- Avoid scope creep by ranking improvements and banning behavior changes.
- Capture fresh git status at execution start because the worktree may contain unrelated changes.

## Work Objectives
### Core Objective
Create an evidence-backed offline audit that tells the user the current status of every EaxRotations class/spec surface, important function/strategy surface, healing surface, shared module, API dependency, test coverage area, missing capability, and improvement opportunity.

### Deliverables
- `EaxRotations/docs/status_audit.md`
- `EaxRotations/docs/status_audit_index.json`
- Evidence files under `evidence/eaxrotations-status-audit/`:
  - `00-git-status.txt`
  - `01-source-inventory.txt`
  - `02-function-inventory.txt`
  - `03-api-docs-inventory.txt`
  - `04-test-inventory.txt`
  - `05-validation-transcript.txt`
  - `06-report-completeness.txt`

### Definition Of Done
- `EaxRotations/docs/status_audit.md` exists and includes all required sections from the schema below.
- `EaxRotations/docs/status_audit_index.json` is valid JSON and includes every status row from the markdown report.
- All 29 primary specs have a status row.
- Both adjunct registered rotations have status rows: `druid/caster_sylvanas.lua` and `warrior/kebab_sylvanas.lua`.
- Every class folder has support-file rows for `class_sylvanas.lua`, `middleware_sylvanas.lua`, `schema_sylvanas.lua`, and present class helper/healing/leveling files.
- Every `EaxRotations/shared/*.lua` module has a classification row.
- Healing has a dedicated matrix covering healer specs, class healing helpers, self-healing, absorbs, HoTs, triage, predictive deficit, incoming heals, overheal gates, cleanse/dispel, and emergency cooldowns.
- API usage is cross-referenced against local `api/` and `apidocs/`.
- Test coverage maps each class/spec and shared critical module to existing tests or an explicit `missing test coverage` finding.
- Findings are ranked by severity and category, with evidence path for each finding.
- Commands below exit 0 unless a pre-existing source/test failure is explicitly captured in the report:
  - `rtk powershell -NoProfile -Command "Get-Content EaxRotations/docs/status_audit_index.json -Raw | ConvertFrom-Json | Out-Null"`
  - `rtk powershell -NoProfile -Command "Select-String -Path EaxRotations/docs/status_audit.md -Pattern '## Primary 29 Spec Status','## Healing Status','## Missing Work','## Improvement Backlog'"`
  - `rtk lua EaxRotations/tests/run_rotation_tests.lua`
  - `rtk lua EaxRotations/tests/run_leveling_tests.lua`
  - `rtk lua EaxRotations/tests/run_vanilla_audit_tests.lua`

### Must Have
- Use only repo-local sources: `EaxRotations/`, `api/`, `apidocs/`, tests, and git history.
- Preserve TBC-era constraints from `AGENTS.md`: no WotLK/Cata recommendations as implementation items, nil-guard menu/state risks, hot-path API caching, squared distance, static table reuse.
- Include a `Status Rating` for each row: `Complete`, `Partial`, `Needs Review`, `Missing`, or `Runtime Verification Needed`.
- Include `Evidence` for each status row: file path plus line references or command transcript.
- Include `Recommendation Priority`: `P0 correctness`, `P1 crash/safety`, `P2 coverage`, `P3 maintainability`, `P4 runtime polish`.

### Must NOT Have
- No source code changes outside audit artifacts.
- No new shared modules.
- No new menu items.
- No spell additions.
- No external platform/API assumptions.
- No live client claims unless backed by a captured client run in a later separate task.
- No generated audit scripts committed to the repo. Use shell commands and manual report synthesis only.
- Do not revert or modify unrelated worktree changes. At plan time, unrelated untracked `EaxRotations/shared/pvp_trinket_tracker_sylvanas.lua`, `wowhead_data/`, and `wowhead_download.sh` were present; execution must exclude them from audit commits unless the user explicitly authorizes cleanup.

## Report Schema
`EaxRotations/docs/status_audit.md` must use this structure exactly:

1. `# EaxRotations Status Audit`
2. `## Executive Summary`
3. `## Scope And Method`
4. `## Primary 29 Spec Status`
5. `## Adjunct Registered Rotations`
6. `## Leveling Status`
7. `## Class Support Status`
8. `## Function And Strategy Inventory`
9. `## Healing Status`
10. `## Shared Module Status`
11. `## Project Sylvanas API Usage`
12. `## Test Coverage Map`
13. `## Missing Work`
14. `## Improvement Backlog`
15. `## Runtime Verification Needed`
16. `## Evidence Index`

Each primary/adjunct/leveling row must include:
- Class
- Spec/playstyle
- Role category: damage, tank, healer, hybrid, leveling, support
- Source file
- Registry key
- Strategy count
- Function count
- State builder status
- Offensive coverage
- Defensive coverage
- Utility coverage
- Healing/self-sustain coverage
- Interrupt/dispel/CC coverage
- PvE/PvP awareness
- API dependency notes
- Test coverage
- Status rating
- Missing work
- Improvement priority
- Evidence

Function inventory rule:
- Enumerate every local/public function declaration from audited class/spec/shared files.
- For the main body of the report, summarize behavior-relevant functions and all strategy `matches`/`execute` paths.
- Put exhaustive function rows in `status_audit_index.json` under `functions`.

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: tests-after/report-validation. This is an audit/report task, not a production behavior change. If execution unexpectedly adds executable audit tooling, add a failing validation test for that tooling before implementation.
- QA policy: Every task has CLI evidence. Existing Lua tests validate source health; separate report completeness checks validate the audit artifact.
- Evidence root: `evidence/eaxrotations-status-audit/`

## Execution Strategy
### Parallel Execution Waves
Wave 1: Task 1, Task 2
Wave 2: Task 3, Task 4, Task 5
Wave 3: Task 6, Task 7, Task 8
Wave 4: Task 9, Task 10
Wave 5: Final verification wave

### Dependency Matrix
| Task | Depends On | Blocks |
| --- | --- | --- |
| 1. Preflight And Scope Lock | none | 2, 3, 4, 5, 6, 7, 8, 9, 10 |
| 2. Build Source And Function Inventory | 1 | 3, 4, 5, 6, 8, 9 |
| 3. Audit Primary And Adjunct Rotations | 1, 2 | 9 |
| 4. Audit Healing Surfaces | 1, 2 | 9 |
| 5. Audit Shared Modules | 1, 2 | 9 |
| 6. Audit Dispatcher Core Registry API | 1, 2 | 9 |
| 7. Audit Local API And Docs Alignment | 1 | 9 |
| 8. Audit Tests And Coverage | 1, 2 | 9, 10 |
| 9. Synthesize Report And JSON Index | 3, 4, 5, 6, 7, 8 | 10 |
| 10. Validate Audit Completeness | 9 | final verification |

## TODOs
- [ ] 1. Preflight And Scope Lock

  **What to do**:
  - Capture fresh git state and recent commits.
  - Confirm the worktree contains no planned source edits.
  - Create `EaxRotations/docs/` and `evidence/eaxrotations-status-audit/` if absent.
  - Write an initial report skeleton with the exact schema above and no status claims yet.
  - Treat any existing source modifications as user-owned.

  **Must NOT do**:
  - Do not edit Lua source files.
  - Do not overwrite unrelated evidence from another run; if files exist, append timestamped notes or replace only files under `evidence/eaxrotations-status-audit/`.

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 2-10 | Blocked By: none

  **References**:
  - `AGENTS.md` project context in session: hard constraints, test commands, 29-spec scope.
  - `.omo/drafts/eaxrotations-status-audit.md` - planning defaults and research findings.
  - `EaxRotations/README.md:106` - rotation test count reference.
  - `EaxRotations/CONTRIBUTING.md:23` - `luac -p` validation requirement.

  **Acceptance Criteria**:
  - [ ] `evidence/eaxrotations-status-audit/00-git-status.txt` contains `rtk git status --short --branch` and `rtk git log --oneline -5` output.
  - [ ] `EaxRotations/docs/status_audit.md` contains all 16 required headings and explicitly marks the audit as `Draft - inventories pending`.
  - [ ] No Lua source file changes are introduced by this task.

  **QA Scenarios**:
  ```text
  Scenario: Preflight evidence exists
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Test-Path evidence/eaxrotations-status-audit/00-git-status.txt; Select-String -Path EaxRotations/docs/status_audit.md -Pattern '## Primary 29 Spec Status'"
    Expected: First output is True and Select-String returns the required heading.
    Evidence: evidence/eaxrotations-status-audit/task-1-preflight.txt

  Scenario: No source mutation
    Tool: powershell
    Steps: rtk git diff -- EaxRotations/classes EaxRotations/shared EaxRotations/main_sylvanas.lua EaxRotations/core_sylvanas.lua
    Expected: Empty diff except pre-existing user-owned changes recorded in 00-git-status.txt.
    Evidence: evidence/eaxrotations-status-audit/task-1-no-source-mutation.txt
  ```

  **Commit**: YES | Message: `docs(audit): scaffold rotation status audit` | Files: `EaxRotations/docs/status_audit.md`, `evidence/eaxrotations-status-audit/00-git-status.txt`

- [ ] 2. Build Source And Function Inventory

  **What to do**:
  - Inventory all files under `EaxRotations/classes`, `EaxRotations/shared`, `api`, and `apidocs`.
  - Produce the canonical primary 29 spec allowlist:
    - Druid: `balance`, `bear`, `cat`, `resto`
    - Hunter: `beast_mastery`, `marksmanship`, `survival`
    - Mage: `arcane`, `fire`, `frost`
    - Paladin: `holy`, `protection`, `retribution`
    - Priest: `discipline`, `holy`, `shadow`, `smite`
    - Rogue: `assassination`, `combat`, `subtlety`
    - Shaman: `elemental`, `enhancement`, `restoration`
    - Warlock: `affliction`, `demonology`, `destruction`
    - Warrior: `arms`, `fury`, `protection`
  - Classify adjunct registered rotations separately: `druid/caster_sylvanas.lua`, `warrior/kebab_sylvanas.lua`.
  - Extract function declarations and registry lines.
  - Save raw inventory to evidence and structured inventory to `status_audit_index.json`.

  **Must NOT do**:
  - Do not infer missing specs from filenames alone; registry key evidence is required where a file registers a rotation.

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 3, 4, 5, 6, 8, 9 | Blocked By: 1

  **References**:
  - `EaxRotations/classes/druid/balance_sylvanas.lua:426` - registration pattern.
  - `EaxRotations/classes/warrior/protection_sylvanas.lua:653` - registration pattern.
  - `EaxRotations/tests/test_rotation_static_compliance.lua` - current spec file allowlist pattern.
  - `EaxRotations/tests/test_rotation_strategy_compliance.lua` - current strategy compliance allowlist pattern.

  **Acceptance Criteria**:
  - [ ] `evidence/eaxrotations-status-audit/01-source-inventory.txt` lists class file counts by class, shared module count, API/docs files, and all `rotation_registry:register` hits.
  - [ ] `evidence/eaxrotations-status-audit/02-function-inventory.txt` lists function declarations from class/spec/shared files.
  - [ ] `status_audit_index.json` has arrays named `primary_specs`, `adjunct_rotations`, `leveling`, `class_support`, `shared_modules`, and `functions`.
  - [ ] `primary_specs` length is exactly 29.

  **QA Scenarios**:
  ```text
  Scenario: Primary spec count is exact
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command '$j=Get-Content EaxRotations/docs/status_audit_index.json -Raw | ConvertFrom-Json; $j.primary_specs.Count'
    Expected: Output is 29.
    Evidence: evidence/eaxrotations-status-audit/task-2-primary-count.txt

  Scenario: Function inventory is non-empty
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path evidence/eaxrotations-status-audit/02-function-inventory.txt -Pattern 'local function|function ' | Select-Object -First 5"
    Expected: At least one function declaration line is returned.
    Evidence: evidence/eaxrotations-status-audit/task-2-function-inventory.txt
  ```

  **Commit**: YES | Message: `docs(audit): inventory rotation surfaces` | Files: `EaxRotations/docs/status_audit.md`, `EaxRotations/docs/status_audit_index.json`, `evidence/eaxrotations-status-audit/01-source-inventory.txt`, `evidence/eaxrotations-status-audit/02-function-inventory.txt`

- [ ] 3. Audit Primary And Adjunct Rotations

  **What to do**:
  - Fill `## Primary 29 Spec Status` and `## Adjunct Registered Rotations`.
  - For each primary/adjunct rotation, inspect source file, strategies, state builder, spell tables, `setting()`/`NS.get_setting` access, `matches` and `execute` paths, and shared module requires.
  - Assign a status rating and missing/improvement notes using the fixed schema.
  - Use class workers in parallel groups:
    - Group A: druid, hunter, mage
    - Group B: paladin, priest, shaman
    - Group C: rogue, warlock, warrior

  **Must NOT do**:
  - Do not fix discovered issues.
  - Do not count leveling rows as primary spec rows.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 9 | Blocked By: 1, 2

  **References**:
  - `EaxRotations/classes/*/*_sylvanas.lua` - primary audited files.
  - `EaxRotations/main_sylvanas.lua` - active playstyle and strategy category gates.
  - `EaxRotations/core_sylvanas.lua` - action/spell/aura helper contracts.
  - `EaxRotations/tests/test_*_custom_matches.lua` - representative class/spec strategy tests.

  **Acceptance Criteria**:
  - [ ] Markdown primary spec table has 29 rows.
  - [ ] Adjunct table has exactly `druid caster` and `warrior kebab` rows.
  - [ ] Every row has a status rating, evidence path, tests mapped, and missing/improvement note.
  - [ ] No row uses `TBD`, `TODO`, or blank evidence.

  **QA Scenarios**:
  ```text
  Scenario: Primary and adjunct headings are populated
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path EaxRotations/docs/status_audit.md -Pattern '^\\| Druid \\| balance','^\\| Warrior \\| protection','^\\| Druid \\| caster','^\\| Warrior \\| kebab'"
    Expected: Four matching table rows are returned.
    Evidence: evidence/eaxrotations-status-audit/task-3-rotation-rows.txt

  Scenario: No unresolved placeholders in rotation sections
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command '$s=Get-Content EaxRotations/docs/status_audit.md -Raw; if ($s -match "TBD|TODO|unknown evidence") { exit 1 }'
    Expected: Exit code 0.
    Evidence: evidence/eaxrotations-status-audit/task-3-no-placeholders.txt
  ```

  **Commit**: YES | Message: `docs(audit): assess primary rotations` | Files: `EaxRotations/docs/status_audit.md`, `EaxRotations/docs/status_audit_index.json`, `evidence/eaxrotations-status-audit/*`

- [ ] 4. Audit Healing Surfaces

  **What to do**:
  - Fill `## Healing Status`.
  - Audit healer specs: druid resto, paladin holy, priest discipline, priest holy, shaman restoration.
  - Audit healing support files: `classes/druid/healing_sylvanas.lua`, `classes/paladin/healing_sylvanas.lua`, `classes/paladin/heal_helper_sylvanas.lua`, `classes/priest/healing_sylvanas.lua`, `classes/shaman/healing_sylvanas.lua`.
  - Audit shared healing modules: `shared/healer_engine_sylvanas.lua`, `shared/healer_deficit_sylvanas.lua`, `shared/aoe_heal_sylvanas.lua`, `shared/incoming_heal_predictor_sylvanas.lua`, `shared/hot_tick_tracker_sylvanas.lua`, `shared/triage_sylvanas.lua`.
  - Include non-healer self-sustain in a subsection: healthstones, health potions, self-heals, absorbs, emergency defensives, threat drops, and healer damage blocking.

  **Must NOT do**:
  - Do not claim group-healing behavior is live-validated unless a Project Sylvanas client run exists.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 9 | Blocked By: 1, 2

  **References**:
  - `EaxRotations/classes/druid/resto_sylvanas.lua:146` - HealerDeficit gate usage.
  - `EaxRotations/classes/paladin/holy_sylvanas.lua:407` - lowest/tank target selection.
  - `EaxRotations/classes/priest/discipline_sylvanas.lua:150` - ranked lowest fallback.
  - `EaxRotations/classes/shaman/healing_sylvanas.lua:136` - overheal gate usage.
  - `EaxRotations/tests/test_healer_engine_nil_guard.lua` - nil/dead/invalid healing target regression.
  - `EaxRotations/tests/test_healer_deficit.lua` - predictive deficit behavior tests.

  **Acceptance Criteria**:
  - [ ] Healing matrix includes healer specs, class healing helpers, shared healing modules, and self-sustain coverage.
  - [ ] Each healing finding identifies target selection, overheal/prediction, spell choice, emergency behavior, and tests.
  - [ ] Runtime-only group/raid assertions are marked `requires client verification`.

  **QA Scenarios**:
  ```text
  Scenario: Healing matrix has all healer classes
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path EaxRotations/docs/status_audit.md -Pattern 'Druid.*resto','Paladin.*holy','Priest.*discipline','Priest.*holy','Shaman.*restoration'"
    Expected: All five healer rows are returned.
    Evidence: evidence/eaxrotations-status-audit/task-4-healer-rows.txt

  Scenario: Healing tests are mapped
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path EaxRotations/docs/status_audit.md -Pattern 'test_healer_engine_nil_guard.lua','test_healer_deficit.lua'"
    Expected: Both test names are present.
    Evidence: evidence/eaxrotations-status-audit/task-4-healing-tests.txt
  ```

  **Commit**: YES | Message: `docs(audit): assess healing coverage` | Files: `EaxRotations/docs/status_audit.md`, `EaxRotations/docs/status_audit_index.json`, `evidence/eaxrotations-status-audit/*`

- [ ] 5. Audit Shared Modules

  **What to do**:
  - Fill `## Shared Module Status`.
  - Classify every `EaxRotations/shared/*.lua` file into one category: healing, targeting, combat utility, PvP/CC, consumables/items, class core, telemetry/debug, leveling, data/validation, rendering/HUD, or unclear.
  - For critical shared modules, inspect public API shape, consumers, tests, hot-path risks, nil-guard posture, and stale/unused status.
  - Mark unclear or unused modules as findings only when supported by `rg` evidence.

  **Must NOT do**:
  - Do not delete or rename unused-looking modules.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 9 | Blocked By: 1, 2

  **References**:
  - `EaxRotations/shared/healer_engine_sylvanas.lua`
  - `EaxRotations/shared/targeting_sylvanas.lua`
  - `EaxRotations/shared/interrupt_manager_sylvanas.lua`
  - `EaxRotations/shared/trinket_manager_sylvanas.lua`
  - `EaxRotations/shared/dr_tracker_sylvanas.lua`
  - `EaxRotations/shared/ttd_tracker_sylvanas.lua`
  - `EaxRotations/shared/warlock_core_sylvanas.lua` - warlock-class shared logic; read-only audit.

  **Acceptance Criteria**:
  - [ ] Shared module table row count equals the number of `EaxRotations/shared/*.lua` files from Task 2.
  - [ ] Every critical module has consumers/tests/status/improvement fields populated.
  - [ ] Any `unused` claim includes an `rg` no-consumer evidence transcript.

  **QA Scenarios**:
  ```text
  Scenario: Shared module count matches inventory
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command '$actual=(Get-ChildItem EaxRotations/shared -Filter *.lua).Count; $j=Get-Content EaxRotations/docs/status_audit_index.json -Raw | ConvertFrom-Json; if ($j.shared_modules.Count -ne $actual) { exit 1 }; $actual'
    Expected: Exit code 0 and printed count equals shared module count.
    Evidence: evidence/eaxrotations-status-audit/task-5-shared-count.txt

  Scenario: Critical shared modules are present
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path EaxRotations/docs/status_audit.md -Pattern 'healer_engine_sylvanas.lua','targeting_sylvanas.lua','interrupt_manager_sylvanas.lua','dr_tracker_sylvanas.lua'"
    Expected: All four module names are present.
    Evidence: evidence/eaxrotations-status-audit/task-5-critical-modules.txt
  ```

  **Commit**: YES | Message: `docs(audit): classify shared modules` | Files: `EaxRotations/docs/status_audit.md`, `EaxRotations/docs/status_audit_index.json`, `evidence/eaxrotations-status-audit/*`

- [ ] 6. Audit Dispatcher Core Registry API

  **What to do**:
  - Fill dispatcher/core subsection inside `## Function And Strategy Inventory`.
  - Audit `main_sylvanas.lua` for context construction, target choice, OOC behavior, reaction delay, auto-AoE, strategy category gating, middleware order, active playstyle normalization, and unified dispatcher status.
  - Audit `core_sylvanas.lua` for expansion helpers, settings cache, spell resolution, `NS.try_cast`, `NS.action_matches`, `NS.action_execute`, aura helpers, healer helpers, registry helpers, API health fallback, and TBC/vanilla spell guardrails.
  - Record improvement candidates as report findings, not code changes.

  **Must NOT do**:
  - Do not propose replacing dispatcher/core patterns without evidence of user-facing risk.

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: 9 | Blocked By: 1, 2

  **References**:
  - `EaxRotations/main_sylvanas.lua`
  - `EaxRotations/core_sylvanas.lua`
  - `EaxRotations/tests/test_dispatcher_tick.lua`
  - `EaxRotations/tests/test_context_completeness.lua`
  - `EaxRotations/tests/test_unified_registry.lua`
  - `EaxRotations/tests/test_try_cast_izi_primary.lua`

  **Acceptance Criteria**:
  - [ ] Dispatcher/core section identifies current status, risks, missing tests, and improvement priorities.
  - [ ] All public `NS.*` functions relevant to rotation execution are represented in `status_audit_index.json.functions`.
  - [ ] Any high-risk finding cites exact source evidence and an existing or missing test.

  **QA Scenarios**:
  ```text
  Scenario: Core execution functions are indexed
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command '$j=Get-Content EaxRotations/docs/status_audit_index.json -Raw | ConvertFrom-Json; ($j.functions | Where-Object { $_.name -in @("NS.action_matches","NS.action_execute","M.on_rotation_update") }).Count'
    Expected: Output is 3.
    Evidence: evidence/eaxrotations-status-audit/task-6-core-functions.txt

  Scenario: Dispatcher risks are evidence-backed
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path EaxRotations/docs/status_audit.md -Pattern 'main_sylvanas.lua','core_sylvanas.lua','test_dispatcher_tick.lua'"
    Expected: All three references are present.
    Evidence: evidence/eaxrotations-status-audit/task-6-dispatcher-evidence.txt
  ```

  **Commit**: YES | Message: `docs(audit): assess dispatcher core` | Files: `EaxRotations/docs/status_audit.md`, `EaxRotations/docs/status_audit_index.json`, `evidence/eaxrotations-status-audit/*`

- [ ] 7. Audit Local API And Docs Alignment

  **What to do**:
  - Fill `## Project Sylvanas API Usage`.
  - Inventory API stubs/docs from `api/` and `apidocs/`.
  - Cross-reference rotation API calls against local stubs/docs:
    - `core.object_manager`
    - `core.spell_book`
    - `core.input`
    - `core.menu`
    - unit/game_object methods
    - `common/izi_sdk`
    - `common/modules/*`
    - `common/utility/*`
  - Mark undocumented or fallback-only calls as `needs API confirmation`.

  **Must NOT do**:
  - Do not cite external docs unless local docs are missing and the report clearly labels the source as external.

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: 9 | Blocked By: 1

  **References**:
  - `api/core.lua`
  - `api/game_object.lua`
  - `api/menu.lua`
  - `api/common/izi_sdk.lua`
  - `apidocs/README.md`
  - `apidocs/pages/dev/api/core.md`
  - `apidocs/pages/dev/api/game-object.md`
  - `apidocs/pages/dev/api/spellbook.md` if present; otherwise record docs gap.

  **Acceptance Criteria**:
  - [ ] `evidence/eaxrotations-status-audit/03-api-docs-inventory.txt` lists local API/docs files used.
  - [ ] Report lists API calls by namespace and identifies undocumented/mismatched calls.
  - [ ] Skill-layout mismatch is documented: this repo uses `api/` and `apidocs/`.

  **QA Scenarios**:
  ```text
  Scenario: API inventory captured
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path evidence/eaxrotations-status-audit/03-api-docs-inventory.txt -Pattern 'api\\\\core.lua','api\\\\game_object.lua','apidocs\\\\README.md'"
    Expected: All three paths are present.
    Evidence: evidence/eaxrotations-status-audit/task-7-api-inventory.txt

  Scenario: API docs gaps are explicit
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path EaxRotations/docs/status_audit.md -Pattern 'needs API confirmation|No local docs gap found'"
    Expected: At least one of the two allowed outcomes appears.
    Evidence: evidence/eaxrotations-status-audit/task-7-api-gap-policy.txt
  ```

  **Commit**: YES | Message: `docs(audit): map sylvanas api usage` | Files: `EaxRotations/docs/status_audit.md`, `EaxRotations/docs/status_audit_index.json`, `evidence/eaxrotations-status-audit/03-api-docs-inventory.txt`

- [ ] 8. Audit Tests And Coverage

  **What to do**:
  - Fill `## Test Coverage Map`.
  - Inventory runners and all tests under `EaxRotations/tests`.
  - Map existing tests to primary specs, adjunct rotations, leveling, shared modules, dispatcher/core, API/static compliance, and healing.
  - Run the three canonical suites after report-only edits are complete enough to ensure the source baseline still passes.
  - Mark gaps where behavior exists without direct tests.

  **Must NOT do**:
  - Do not add, delete, skip, or weaken tests as part of this audit.

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: 9, 10 | Blocked By: 1, 2

  **References**:
  - `EaxRotations/tests/run_rotation_tests.lua`
  - `EaxRotations/tests/run_leveling_tests.lua`
  - `EaxRotations/tests/run_vanilla_audit_tests.lua`
  - `EaxRotations/tests/test_rotation_static_compliance.lua`
  - `EaxRotations/tests/test_rotation_strategy_compliance.lua`
  - `EaxRotations/tests/test_healer_engine_nil_guard.lua`
  - `EaxRotations/tests/test_healer_deficit.lua`

  **Acceptance Criteria**:
  - [ ] `evidence/eaxrotations-status-audit/04-test-inventory.txt` lists all tests and runner membership.
  - [ ] Report maps every primary spec to at least one direct, shared, or missing-test status.
  - [ ] The three canonical suite outputs are captured or pre-existing failures are explicitly named.

  **QA Scenarios**:
  ```text
  Scenario: Test inventory includes runners
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path evidence/eaxrotations-status-audit/04-test-inventory.txt -Pattern 'run_rotation_tests.lua','run_leveling_tests.lua','run_vanilla_audit_tests.lua'"
    Expected: All three runner names are present.
    Evidence: evidence/eaxrotations-status-audit/task-8-test-inventory.txt

  Scenario: Test coverage map has no blank spec rows
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command '$j=Get-Content EaxRotations/docs/status_audit_index.json -Raw | ConvertFrom-Json; if (($j.primary_specs | Where-Object { -not $_.test_coverage }).Count -gt 0) { exit 1 }'
    Expected: Exit code 0.
    Evidence: evidence/eaxrotations-status-audit/task-8-no-blank-coverage.txt
  ```

  **Commit**: YES | Message: `docs(audit): map test coverage` | Files: `EaxRotations/docs/status_audit.md`, `EaxRotations/docs/status_audit_index.json`, `evidence/eaxrotations-status-audit/04-test-inventory.txt`, `evidence/eaxrotations-status-audit/05-validation-transcript.txt`

- [ ] 9. Synthesize Report And JSON Index

  **What to do**:
  - Convert all task findings into the final report.
  - Fill `## Executive Summary`, `## Missing Work`, `## Improvement Backlog`, `## Runtime Verification Needed`, and `## Evidence Index`.
  - Ensure every finding has severity, category, source evidence, affected files/specs, recommended next action, and whether it requires code change, test addition, docs update, or client verification.
  - Ensure `status_audit_index.json` mirrors markdown data.

  **Must NOT do**:
  - Do not hide uncertainty. Use `Runtime Verification Needed` or `needs API confirmation` where evidence is offline-only.

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: 10 | Blocked By: 3, 4, 5, 6, 7, 8

  **References**:
  - All evidence files from Tasks 1-8.
  - `AGENTS.md` constraints from session.
  - `EaxRotations/docs/status_audit.md` schema.

  **Acceptance Criteria**:
  - [ ] No required report section is empty.
  - [ ] Every `Missing Work` entry has priority, evidence, and next action.
  - [ ] Every `Improvement Backlog` entry is ranked P0-P4.
  - [ ] `status_audit_index.json` parses with `ConvertFrom-Json`.

  **QA Scenarios**:
  ```text
  Scenario: JSON parses
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Get-Content EaxRotations/docs/status_audit_index.json -Raw | ConvertFrom-Json | Out-Null"
    Expected: Exit code 0.
    Evidence: evidence/eaxrotations-status-audit/task-9-json-parse.txt

  Scenario: Required findings sections populated
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path EaxRotations/docs/status_audit.md -Pattern '## Missing Work','## Improvement Backlog','P0 correctness|P1 crash/safety|P2 coverage|P3 maintainability|P4 runtime polish'"
    Expected: Headings and at least one priority marker are present.
    Evidence: evidence/eaxrotations-status-audit/task-9-findings-populated.txt
  ```

  **Commit**: YES | Message: `docs(audit): synthesize status findings` | Files: `EaxRotations/docs/status_audit.md`, `EaxRotations/docs/status_audit_index.json`, `evidence/eaxrotations-status-audit/*`

- [ ] 10. Validate Audit Completeness

  **What to do**:
  - Validate report schema, row counts, JSON parse, evidence links, and no unresolved placeholders.
  - Run canonical Lua suites and record results.
  - If a suite fails due to pre-existing source state, record failing suite and first failure line in the report; do not modify tests/source.
  - Update evidence index with validation commands and outcomes.

  **Must NOT do**:
  - Do not mark the audit complete if primary spec count, shared module count, or JSON parse fails.

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: final verification | Blocked By: 9

  **References**:
  - `EaxRotations/CONTRIBUTING.md:61`
  - `EaxRotations/CONTRIBUTING.md:64`
  - `EaxRotations/CONTRIBUTING.md:67`
  - `EaxRotations/tests/run_rotation_tests.lua`
  - `EaxRotations/tests/run_leveling_tests.lua`
  - `EaxRotations/tests/run_vanilla_audit_tests.lua`

  **Acceptance Criteria**:
  - [ ] `evidence/eaxrotations-status-audit/06-report-completeness.txt` contains all completeness checks.
  - [ ] `evidence/eaxrotations-status-audit/05-validation-transcript.txt` contains the three canonical suite results.
  - [ ] Final report explicitly states whether suites passed or names pre-existing failures.

  **QA Scenarios**:
  ```text
  Scenario: Report completeness gate
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command '$j=Get-Content EaxRotations/docs/status_audit_index.json -Raw | ConvertFrom-Json; if ($j.primary_specs.Count -ne 29) { exit 1 }; if (-not (Test-Path evidence/eaxrotations-status-audit/06-report-completeness.txt)) { exit 1 }'
    Expected: Exit code 0.
    Evidence: evidence/eaxrotations-status-audit/task-10-completeness.txt

  Scenario: Canonical validation captured
    Tool: powershell
    Steps: rtk powershell -NoProfile -Command "Select-String -Path evidence/eaxrotations-status-audit/05-validation-transcript.txt -Pattern 'run_rotation_tests.lua','run_leveling_tests.lua','run_vanilla_audit_tests.lua'"
    Expected: All three command names are present.
    Evidence: evidence/eaxrotations-status-audit/task-10-validation-captured.txt
  ```

  **Commit**: YES | Message: `docs(audit): validate status audit` | Files: `EaxRotations/docs/status_audit.md`, `EaxRotations/docs/status_audit_index.json`, `evidence/eaxrotations-status-audit/*`

## Final Verification Wave
> ALL must APPROVE. Present consolidated results to user and get explicit approval before completing any later implementation/execution task.

- [ ] F1. Plan Compliance Audit
  - Verify every task above has acceptance criteria, QA scenarios, references, and commit guidance.
  - Command: `rtk powershell -NoProfile -Command "Select-String -Path plans/eaxrotations-status-audit.md -Pattern 'Acceptance Criteria','QA Scenarios','References','Commit'"`

- [ ] F2. Artifact Completeness Audit
  - Verify final report and JSON index exist, parse, and contain required row counts.
  - Command: `rtk powershell -NoProfile -Command '$j=Get-Content EaxRotations/docs/status_audit_index.json -Raw | ConvertFrom-Json; if ($j.primary_specs.Count -ne 29) { exit 1 }; if (-not (Test-Path EaxRotations/docs/status_audit.md)) { exit 1 }'`

- [ ] F3. Source Health Regression Check
  - Run:
    - `rtk lua EaxRotations/tests/run_rotation_tests.lua`
    - `rtk lua EaxRotations/tests/run_leveling_tests.lua`
    - `rtk lua EaxRotations/tests/run_vanilla_audit_tests.lua`
  - Record pass/fail and first failing suite line in `EaxRotations/docs/status_audit.md`.

- [ ] F4. Scope Fidelity Check
  - Verify no Lua source files were changed by the audit execution.
  - Command: `rtk git diff -- EaxRotations/classes EaxRotations/shared EaxRotations/main_sylvanas.lua EaxRotations/core_sylvanas.lua`

## Commit Strategy
- Do not auto-commit unless the user explicitly requests it.
- If committing later, use one commit per logical report increment as listed in task commit guidance.
- Final commit should be: `docs(audit): complete rotation status audit`
- Do not amend existing commits.
- Do not stage or commit unrelated worktree changes, especially pre-existing untracked `EaxRotations/shared/pvp_trinket_tracker_sylvanas.lua`, `wowhead_data/`, or `wowhead_download.sh`.

## Success Criteria
- The user can open `EaxRotations/docs/status_audit.md` and see a complete, evidence-backed status of classes, specs, functions, healing, shared modules, API usage, tests, missing work, and improvements.
- The JSON index is machine-readable and agrees with the markdown report.
- Report validation proves exact coverage of 29 primary specs, adjunct rotations, shared modules, healing surfaces, API docs, and tests.
- Source health checks are green, or failures are explicitly captured as pre-existing and not hidden.
- No behavior-changing code was modified during audit execution.
