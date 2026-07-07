# HANDOFF — EaxRotations continuation guide

> **Read this first.** If you are a fresh AI agent (any model — Kimi, DeepSeek, GLM,
> Claude, etc.) picking up this project with no prior context, this single file
> tells you the current state and exactly how to continue safely. It is kept
> up to date after every work session. Last updated: **2026-07-07** (spec_kit migration #14 complete; HEAD `87ffb7aa`, pushed to origin).

**This file is the always-current "where are we / what's next" doc.**
The detailed task matrix lives in `plans/_active.md` and
> `plans/become-1-rotation-system-classic-tbc-2026-07-05.md` — read them
second. The hard rules live in `AGENTS.md` (repo root) — read it first per
its own contract, but the critical bits are summarized below so you don't
have to context-switch.

---

## TL;DR (start here)

- **Project:** 29 WoW TBC Classic Anniversary (2.5.5.x) + Vanilla Anniversary
  rotation plugins for **Project Sylvanas**, in Lua 5.1/LuaJIT. Repo:
  `https://github.com/eaxiumnet/eaxrotations`. Work dir: `C:\newbot\scripts`.
- **Baseline is GREEN:** **234 rotation suites + 13 leveling suites** pass on
  **Lua 5.1**. Don't break this.
- **What's done (2026-06-27 → 2026-07-07, 284 commits):**
  - **wowsims APL alignment** for all 29 TBC specs (priority orders grounded in
    SimulationCraft / wowsims APLs + TBC community guides). Multiple releases shipped.
  - **Swing mechanics overhaul** — CLEU-backed swing timer, parry-haste, enemy
    swing timer, Overpower dodge proc detection (`shared/swing_diagnostics_sylvanas.lua`).
  - **DoT/finisher snapshot module** — shared `snapshot_sylvanas.lua` for Rip/Rake
    AP snapshot upgrade gating (cat + balance).
  - **Combat mode override** — ST/AoE/Auto switch aligned with wowsims APL.
  - **Engineering bomb support** — wowsims APL Engineering group for all specs.
  - **Bear Druid clean rebuild** — pure bear-form tank rotation, no in-combat form shifting.
  - **Warrior full audit** — PvP CC gate, stance dance, Execute priority, Rampage
    buff IDs, berserker rage fear break.
  - **EaxFishing v2.5.1** — debug throttling, stealth suspicion decay/reset, verbose
    status logging.
  - **spec_kit migration** — 19 of 29 specs converted to `spec_kit.safe_state` +
    `define_action_for_class` (arms, fury, protection, kebab, balance, cat, bear, caster, resto, discipline, holy, shadow, fire, destruction, frost, restoration, affliction, combat, demonology).
  - **Vanilla APL audit** — 6 phases complete, all 31 vanilla spec files reviewed.
  - **567 vanilla nil-guard test cases** added across 9 new test files (38 specs).
  - **Plan cleanup** — 44 → 15 active plans (35 archived to `plans/_archive/`).
- **What's next:** (1) Continue spec_kit migration (only when already editing a
  spec — never big-bang). (2) `become-1-rotation-system` roadmap — ground every
  spec in wowsims/SimC/guides to be #1. (3) `spec-standardization` for
  open-source release. (4) EaxFishing v2.4.0–12 features. (5) EaxAutoQuester
  verification (separate product, NOT covered by the rotation gate).
- **Golden rule:** one concern per commit; run `validate.cmd` (at repo root)
  before marking anything done; if a task loops >2 attempts, STOP and write a
  debugging note in `plans/` instead of retrying.

---

## CRITICAL environment gotchas (these cost real time — heed them)

1. **Two `lua` binaries exist; only one is correct.**
   - WRONG: `lua` on PATH → **Lua 5.4.5** (WinGet). Silently runs, may give
     false-green or no output. **Do not use it for tests.**
   - CORRECT: `C:\Program Files (x86)\Lua\5.1\lua.exe` → **Lua 5.1.5**. This is
     the project's runtime. Use this for all test runs.
   - `luac` (PATH) IS the 5.1 compiler — fine for `luac -p` syntax checks.
   - `validate.cmd` was **moved to the repo root** (`C:\newbot\scripts\validate.cmd`)
     during the repo-cleanup session. Run it as `cmd.exe //c "validate.cmd"` from
     the repo root. It is gitignored (local-only); release zips ship clean.
     `EaxRotations\validate.cmd` no longer exists — use the root one. It is pinned
     to Lua 5.1 — prefer running the gate over hand-invoking `lua`.

2. **`validate.cmd` parens bug (already fixed, don't reintroduce).** The Lua
   5.1 path contains `(x86)` parens that **break multi-line `if (...) else (...)`
   blocks in cmd.exe**. Use single-line `if not exist "..." set ...` form only.

3. **No concurrent agents.** This repo was being edited by multiple AI tools
   at once (OpenCode/OMO/GLM/etc.), causing files to change mid-session. If
   you see a file change under you, STOP and check git status — another agent
   may be active. Coordinate / serialize before editing.

4. **Never commit external reference repos.** `tbc-main/`, `tbc-new/`,
   `Sonah/`, `HealPredict/`, `LibHealComm-4.0.lua`, `NAG/`, `NextActionTBC/`,
   `_external_tbc_explore/`, `eax_refactor/`, `EaxESP/`, `EaxProfessions/`,
   `wowheadScrape/`, `scraped_docs*/`, `scripts_data/`, `.agents/`,
   `.openclaude/`, `.playwright-mcp/`, `__pycache__/` are **local-only
   inspiration sources, explicitly out of scope per AGENTS.md.** They are
   gitignored (commit `5d2a2fed`). A careless `git add -A` would commit
   hundreds of MB of external code. Stage explicit paths, never `git add -A`.

5. **Native Sylvanas APIs usually supersede reference-repo "ports."** Before
   porting anything from Sonah/NAG/HealPredict/LibHealComm, check the native
   API first:
   - Swing timer → `require("common/utility/auto_attack_helper")`
     (`get_next_attack_game_time`, `get_next_attack_core_time`) → already
     bridged as `NS.get_time_until_swing()`.
   - Incoming heals → `unit:get_incoming_heals()`, `unit:get_incoming_heals_from(source)`.
   - Shield absorb → `unit:get_total_shield()`, `unit:get_total_heal_absorbs()`.
   - Auras → `unit:get_buffs()` / `get_debuffs()`; cached via `NS.AuraCache`
     (50ms TTL).
   Mine references for **strategy/APL logic** (priority lists, twist windows),
   NOT infrastructure.

6. **`common`, `core_lua`, `core_universal_kicks`** (top-level, 7.7MB+ blobs)
   are stale vendored junk NOT loaded by EaxRotations. They stay dirty/untracked
   by design — do not commit them.

7. **DBC is authoritative for spell IDs.** Verify any spell against
   `wowheadScrape/dbc_extract/wowsims.db` (SQLite) before adding/removing.
   Some Wrath-era spells were backported to the 2.5.5 client (Ice Lance 30455,
   Seal of Blood 31892, Seal of the Martyr 348700) and ARE valid — never strip
   a spell as "WotLK" without DBC proof.

---

## Git workflow (commit / push / release / zip)

- **Remote:** `origin` = `https://github.com/eaxiumnet/eaxrotations.git`, branch `master`.
- **gh auth:** `gh` is authenticated as **eaxiumnet** (keyring). Can create
  releases and push.
- **Author config:** `Support <support@eaxrotations.local>` (already set).
- **Commit style:** conventional commits, one concern per commit. The repo has
  a **pre-commit hook** that runs: `luac -p` on all 457 Lua files → vanilla TBC
  spell audit (31 files) → Sylvanas DBC spell audit (296 files). If it fails,
  a spell ID in your change doesn't exist in the DBC; fix it, don't bypass it.
- **Push:** `git push origin master` (fast-forwards; repo is usually 0 ahead
  after a clean session).
- **Restore-deleted-metadata caution:** a prior session deleted `README.md`,
  `CHANGELOG.md`, `CONTRIBUTING.md`, `.github/workflows/ci.yml`, `.luarc.json`.
  These were restored (commit session 2026-06-25). Don't let them get deleted
  again — they're customer-facing repo essentials.

### Make a versioned release with zip (user wants this after major work)
```bash
cd /c/newbot/scripts
sha=$(git rev-parse --short HEAD)
date=$(git show -s --format=%ci HEAD | cut -d' ' -f1)
zipname="EaxRotations-${date}-${sha}.zip"
# Write VERSION.txt manifest (commit, date, test status) — see an existing
# release's VERSION.txt or the 2026-06-25 session log for the template.
git archive --format=zip --add-file=VERSION.txt -o "$zipname" HEAD -- EaxRotations/
# Verify: python -c "import zipfile; z=zipfile.ZipFile('$zipname'); ..." (check
# no external-repo leak, VERSION.txt + new files present)
gh release create "v${date}.${sha}" "$zipname" --title "..." --notes "..."
```
`*.zip` is gitignored, so the zip won't pollute the repo. **10+ releases** exist
(latest `v2026-06-28.f802211b`). NOTE: include `EaxAutoQuester/` in the archive
path too (the rotation product ships both): `git archive ... HEAD -- EaxRotations/ EaxAutoQuester/`. Verify the zip with a python zipfile check that no entry is
outside `.lua`/`.md`/`VERSION.txt` and no external-repo dir leaked in.

---

## Test gate (run before marking ANY task done)

```bash
cd /c/newbot/scripts
cmd.exe //c "validate.cmd"
```
Expected output ends with `ALL CHECKS PASSED`. It runs: `luac -p` on modified
files → rotation suite (234) → leveling suite (13) → spell audit. All on Lua
5.1. If it says `VALIDATION FAILED`, read the FAIL line and fix it.

For a quick single-file syntax check: `luac -p <file>` (uses the 5.1 luac).
For one test standalone: `"/c/Program Files (x86)/Lua/5.1/lua.exe" EaxRotations/tests/<test>.lua`

Or run the suites directly:
```bash
"/c/Program Files (x86)/Lua/5.1/lua.exe" EaxRotations/tests/run_rotation_tests.lua 2>&1 | tail -10
"/c/Program Files (x86)/Lua/5.1/lua.exe" EaxRotations/tests/run_leveling_tests.lua 2>&1 | tail -5
```

---

## CURRENT STATE (verified 2026-07-07, HEAD 87ffb7aa)

**Baseline:** 234 rotation + 13 leveling suites PASS / 0 fail on Lua 5.1.5.
Spell audit PASS. Pre-commit hooks green (luac + vanilla audit + DBC audit).
Repo is 0 commits ahead of origin/master.

### Recent major work (2026-06-27 → 2026-07-07, 284 commits)
| Category | Item | Commit | One-line |
|----------|------|--------|----------|
| wowsims APL | All 29 TBC specs aligned to wowsims/SimC APLs | multiple | priority orders grounded in simulation data |
| Swing mechanics | CLEU-backed swing timer + parry-haste + Overpower proc | `1a54671f` | `shared/swing_diagnostics_sylvanas.lua` |
| Snapshot module | Shared DoT/finisher snapshot upgrade gating | `eec85aa7` | `shared/snapshot_sylvanas.lua` (cat Rip/Rake) |
| Combat mode | ST/AoE/Auto override (wowsims-aligned) | multiple | `shared/combat_mode_sylvanas.lua` |
| Engineering | Bomb support (wowsims APL Engineering group) | multiple | all specs with engineering helper |
| Bear Druid | Clean rebuild — pure bear-form tank, no form shifting | `c671ce73` | stripped cat/caster spells, wowsims tank APL |
| Warrior audit | PvP CC gate, stance dance, Execute, Rampage, fear break | `08629117` | comprehensive warrior audit |
| EaxFishing | v2.5.1 debug throttling + stealth suspicion decay | `691daee9` | fixes bot freezing from maxed suspicion |
| spec_kit | 18 specs migrated to safe_state + define_action_for_class | `be68a0e2` (latest) | arms, fury, protection, kebab, balance, cat, bear, caster, resto, discipline, holy, shadow, fire, destruction, frost, restoration, affliction, combat |
| Vanilla APL | 6-phase audit complete, all 31 vanilla files reviewed | `0ca3b349` | warrior/frost mage/bear fixes + 0-change reviews |
| Nil-guard tests | 567 vanilla nil-guard test cases across 9 new files | `4ecbcaaa` | 38 specs covered (all vanilla classes) |
| Plan cleanup | 44 → 15 active plans (35 archived) | `37c20d17`+`618cdcdf` | stale/completed plans moved to `plans/_archive/` |

### spec_kit migration progress (19 of 29 specs)
| Spec | Status | Key change |
|------|--------|------------|
| arms | ✅ Done (reference) | first conversion, `ARMS_SCHEMA` + `safe_state` |
| fury | ✅ Done | 27 ACTION entries via `define()` with rank IDs |
| protection | ✅ Done | safe_state + guarded registration |
| kebab | ✅ Done | safe_state + canonical return |
| balance | ✅ Done | safe_state + define_action_for_class |
| cat | ✅ Done | 19 ACTION entries, `CAT_SCHEMA`, 31 ACTIONS converted |
| bear | ✅ Done | 17 ACTION entries, `BEAR_SCHEMA`, test-env nil-guards |
| caster | ✅ Done | 6 ACTION entries, `CASTER_SCHEMA`, THORNS_BUFF moved |
| resto | ✅ Done | 23 ACTION entries, `RESTO_SCHEMA`, merged LOCAL_SPELLS into ACTION |
| discipline | ✅ Done | 25 ACTION entries, `DISC_SCHEMA`, 59 SPELLS.X refs converted |
| holy | ✅ Done | 20 ACTION entries, `HOLY_SCHEMA`, 48 SPELLS.X refs converted |
| shadow | ✅ Done | 23 ACTION entries, `SHADOW_SCHEMA`, 61 SPELLS.X refs converted |
| fire | ✅ Done | 18 ACTION entries, `FIRE_SCHEMA`, 42 SPELLS.X refs converted |
| destruction | ✅ Done (latest) | 15 ACTION entries, `DESTRO_SCHEMA`, 24 SPELLS.X refs converted |
| (15 remaining) | Not started | Convert only when already editing a spec |

### Deferred / out of scope (with reasons — don't relitigate)
- **C4 (extract core/casting.lua):** the 8 casting functions span lines
  1254–5475 (~4200 lines), interleaved with other domains. Not a clean
  extract; would be god-file surgery risking loops (AGENTS Rule 5).
- **Active Blood↔Command seal-swap twist (ret):** current twist logic is the
  suppress-variant. The classic active double-proc swap needs in-game tuning.
- **LibHealComm / Sonah / NAG infrastructure ports:** superseded by native
  Sylvanas APIs (see gotcha #5).

### Deferred / out of scope (with reasons — don't relitigate)
- **C4 (extract core/casting.lua):** the 8 casting functions span lines
  1254–5475 (~4200 lines), interleaved with other domains. Not a clean
  extract; would be god-file surgery risking loops (AGENTS Rule 5). Revisit
  only as part of a whole-file reorg.
- **D1 (strip DEBUG entries from data bridge):** the bridge is a ~66K-line
  **generated** file (from DBC via `build_tools/json_to_lua_data.py`).
  Hand-edits get overwritten on regeneration. Fix belongs in the **generator
  filter** (build_tools scope, outside the rotation gate). DEBUG spells are
  real Blizzard QA spells in the DBC; no rotation code references them.
- **Active Blood↔Command seal-swap twist (ret):** current twist logic is the
  suppress-variant (suppress off-GCD near swing), native-backed + tested.
  The *classic active* double-proc swap is a bigger behavior change needing
  in-game mana/GCD tuning — deferred.
- **LibHealComm / Sonah / NAG infrastructure ports:** superseded by native
  Sylvanas APIs (see gotcha #5).
- **B6:** friendly-target healing — see WHAT'S NEXT.

---

## WHAT'S NEXT (prioritized)

### 1. Continue spec_kit migration (opportunistic — only when editing a spec)
- 18 of 29 specs converted (arms, fury, protection, kebab, balance, cat, bear, caster, resto, discipline, holy, shadow, fire, destruction, frost, restoration, affliction, combat).
- Next candidates: any spec already being edited. Never big-bang (AGENTS Rule 5).
- Pattern: add `spec_kit` require + `define_action_for_class(SPELLS)`, create
  ACTION table with rank IDs, add SCHEMA + `safe_state` in `build_state`,
  guard registration. Reference: `arms_sylvanas.lua`.

### 2. `become-1-rotation-system` roadmap (`plans/become-1-rotation-system-classic-tbc-2026-07-05.md`)
- Ground every spec in wowsims/SimC/guides to be the #1 rotation system.
- Current active roadmap with competitor analysis.

### 3. `spec-standardization` for open-source release (`plans/spec-standardization-2026-06-30.md`)
- Schema/spec/leveling standardization.
- Enforced by `tests/test_spec_layout_compliance.lua`.

### 4. EaxFishing v2.4.0–12 features (`plans/eaxfishing-v2.4.0-12-features-2026-07-05.md`)
- In-progress feature list for the fishing bot.

### 5. Verify the EaxAutoQuester suite (separate product)
`EaxAutoQuester/` is committed but NOT covered by the rotation gate. Run
`"/c/Program Files (x86)/Lua/5.1/lua.exe" EaxAutoQuester/tests/run_quester_tests.lua`
at some point to see its real status. Sibling product — its own concern.

### 6. Open bug reports
- `plans/bug-report-sylvanas-attachment-api-crash.md` — attachment API crash.
- `plans/skeleton-esp-attachment-api-crash-2026-07-04.md` — ESP skeleton crash.

---

## READ ORDER for a fresh agent
1. **This file** (`plans/HANDOFF.md`).
2. `AGENTS.md` (repo root) — hard rules, patterns, boundaries. **The single
   source of truth for agent instructions.** Ignore stale `CLAUDE.md`/cursorrules.
3. `plans/_active.md` — current active plan tracker.
4. `plans/become-1-rotation-system-classic-tbc-2026-07-05.md` — current roadmap.
5. The target file(s) for your task + relevant `apidocs/pages/dev/api/*.md`.
6. Run `validate.cmd` to confirm green before starting.

## KEY FILES
- `EaxRotations/core_sylvanas.lua` — main NS namespace (5857 lines; 5 domains
  extracted to `EaxRotations/core/{settings,units,items,cooldowns,diagnostics}.lua`).
- `EaxRotations/main_sylvanas.lua` — dispatcher, per-frame context build
  (feeds `context.enemy_count_smoothed` via `EnemyCountHysteresis`).
- `EaxRotations/classes/<class>/<spec>_sylvanas.lua` — 29 spec files (flat).
- `EaxRotations/shared/` — ~50 shared modules (healer_deficit, preemptive_heal,
  aura_cache, enemy_count_hysteresis, pvp_burst_window, offensive_dispel, …).
- `EaxRotations/tests/run_rotation_tests.lua` — rotation suite runner (234 suites).
- `EaxRotations/tests/run_leveling_tests.lua` — leveling suite runner (13 suites).
- `EaxRotations/shared/spec_kit_sylvanas.lua` — spec_kit boilerplate + nil-guard kit.
- `EaxRotations/shared/swing_diagnostics_sylvanas.lua` — CLEU swing timer.
- `EaxRotations/shared/snapshot_sylvanas.lua` — DoT/finisher snapshot upgrade gating.
- `EaxRotations/shared/combat_mode_sylvanas.lua` — ST/AoE/Auto override.
- `validate.cmd` — the gate (Lua 5.1 pinned).
- `apidocs/pages/dev/api/` — API docs (game-object.md, buffs.md, spellbook.md, …).
- `wowheadScrape/dbc_extract/wowsims.db` — DBC (authoritative spell IDs).

## THE 5 AGENT CONTRACT RULES (from AGENTS.md — non-negotiable)
1. Read `AGENTS.md` first; ignore stale `CLAUDE.md`/cursorrules beyond their pointer.
2. Plans live in `plans/`; one active plan per effort; check `plans/_active.md`.
3. **One concern per commit.** Never bundle unrelated changes.
4. **Before marking any task complete:** `luac -p` on changed files AND
   `validate.cmd`. Both must pass.
5. **If a task loops >2 attempts, STOP.** Write a debugging note in `plans/`
   describing the failure instead of retrying. Looping is the failure mode
   this contract exists to prevent.

---

*Update this file at the end of every work session: bump the "Last updated"
date + HEAD, move done items to CURRENT STATE, refresh WHAT'S NEXT. A fresh
model should be able to continue from this file alone.*
