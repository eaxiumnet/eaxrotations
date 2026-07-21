# HANDOFF — EaxRotations continuation guide

> **Read this first.** If you are a fresh AI agent (any model — Kimi, DeepSeek, GLM,
> Claude, etc.) picking up this project with no prior context, this single file
> tells you the current state and exactly how to continue safely. It is kept
> up to date after every work session. Last updated: **2026-07-21** (strategy DSL + lazy context landed 2026-07-19; 26 DSL adoptions committed — arms, fury, combat rogue, balance druid, protection paladin, restoration shaman, beast mastery hunter, shadow priest, frost mage, arcane mage, fire mage, enhancement shaman, destruction warlock, demonology warlock, bear druid, feral cat druid, assassination rogue, subtlety rogue, elemental shaman, retribution paladin, discipline priest, survival hunter, marksmanship hunter, affliction warlock, protection warrior, holy paladin; `tests/_staging/` debris cleaned; baseline re-verified 341 rotation + 21 leveling = 362 total suites green).

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
- **Baseline is GREEN:** **341 rotation suites + 21 leveling suites (362 total)** pass on
  **Lua 5.1**. Don't break this.
- **What's done (2026-06-27 → 2026-07-20, 288+ commits):**
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
  - **spec_kit migration** — **COMPLETE: all 29 specs** converted to `spec_kit.safe_state` +
    `define_action_for_class` (arms, fury, protection, kebab, balance, cat, bear, caster, resto, discipline, holy, shadow, fire, destruction, frost, restoration, affliction, combat, demonology, elemental, enhancement, assassination, marksmanship, retribution, subtlety, survival, protection, beast_mastery, holy).
  - **Vanilla APL audit** — 6 phases complete, all 31 vanilla spec files reviewed.
  - **567 vanilla nil-guard test cases** added across 9 new test files (38 specs).
  - **Plan cleanup** — 44 → 15 active plans (35 archived to `plans/_archive/`).
- **What's next:** (1) Continue spec_kit migration (only when already editing a
  spec — never big-bang) — ALL 29 specs done; now opportunistic. (1b) Continue
  strategy DSL adoption — 26 of 29 specs on DSL (arms, fury, combat rogue, balance
  druid, protection paladin, restoration shaman, beast mastery hunter, shadow priest, frost mage, arcane mage, fire mage, enhancement shaman, destruction warlock, demonology warlock, bear druid, feral cat druid, assassination rogue, subtlety rogue, elemental shaman, retribution paladin, discipline priest, survival hunter, marksmanship hunter, affliction warlock, protection warrior, holy paladin); a 27th spec
  from a new class (e.g. holy paladin, holy priest, caster druid, or resto druid) would continue expanding coverage. (2) `become-1-rotation-system`
  roadmap — ground every spec in wowsims/SimC/guides to be #1. (3)
  `spec-standardization` for open-source release. (4) EaxFishing v2.4.0–12
  features. (5) EaxAutoQuester verification (separate product, NOT covered by
  the rotation gate).
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
- **Commit style:** conventional commits, one concern per commit. The repo hasa **pre-commit hook**
  that runs: `luac -p` on all 617 Lua files → vanilla TBC
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
zipname="eaxrotations.zip"   # or dated name; this is what gets attached to release
# IMPORTANT: ONLY .lua and .md allowed in the zip (no .txt, no VERSION.txt, no other)
# Use git archive + strict python re-zip to strip EaxRotations/ prefix and filter:
git archive --format=zip -o tmp_eax.zip HEAD -- EaxRotations/
python -c '
import zipfile, os
with zipfile.ZipFile("tmp_eax.zip") as zin, zipfile.ZipFile("eaxrotations.zip", "w", zipfile.ZIP_DEFLATED) as zout:
    for it in zin.infolist():
        if not it.filename.startswith("EaxRotations/"): continue
        newname = it.filename[len("EaxRotations/"):]
        if not newname or newname.endswith("/"): 
            if newname.endswith("/"): zout.writestr(it)  # keep empty dirs if any
            continue
        if not (newname.endswith(".lua") or newname.endswith(".md")): continue
        zout.writestr(newname, zin.read(it))
print("strict zip created")
'
rm -f tmp_eax.zip
# Verify (MUST report 0):
python -c "
import zipfile
z=zipfile.ZipFile('eaxrotations.zip')
bad=[n for n in z.namelist() if not n.endswith('/') and not (n.endswith('.lua') or n.endswith('.md'))]
txt=[n for n in z.namelist() if n.endswith('.txt')]
print('Bad non-lua/md:', len(bad), 'Txt:', len(txt))
z.close()
"   # must be 0 bad, 0 txt
gh release upload v2.5.11 eaxrotations.zip --clobber || gh release upload TAG eaxrotations.zip --clobber
```
`*.zip` is gitignored. Always run the verify — .zip must contain **only lua and md files**. Past issue: accidental .txt (e.g. VERSION.txt) from loose archive commands was fixed by the strict filter above. Use `eaxrotations.zip` (lowercase) for the generic asset on the active release. NOTE: the rotation ships EaxRotations/ only (no EaxAutoQuester in current zips).

---

## Test gate (run before marking ANY task done)

```bash
cd /c/newbot/scripts
cmd.exe //c "validate.cmd"
```
Expected output ends with `ALL CHECKS PASSED`. It runs: `luac -p` on modified
files → rotation suite (324) → leveling suite (21) → spell audit. All on Lua
5.1. If it says `VALIDATION FAILED`, read the FAIL line and fix it.

For a quick single-file syntax check: `luac -p <file>` (uses the 5.1 luac).
For one test standalone: `"/c/Program Files (x86)/Lua/5.1/lua.exe" EaxRotations/tests/<test>.lua`

Or run the suites directly:
```bash
"/c/Program Files (x86)/Lua/5.1/lua.exe" EaxRotations/tests/run_rotation_tests.lua 2>&1 | tail -10
"/c/Program Files (x86)/Lua/5.1/lua.exe" EaxRotations/tests/run_leveling_tests.lua 2>&1 | tail -5
```

---

## CURRENT STATE (v2.5.15, HEAD current)

**Baseline:** 341 rotation + 21 leveling suites PASS / 0 fail on Lua 5.1.5.
Spell audit PASS. Pre-commit hooks green (luac + vanilla audit + DBC audit).
test_spec_layout_compliance.lua PASS (31 converted + shared + vanilla).
eaxrotations.zip re-verified: 490 entries, 0 bad, 0 .txt (only .lua/.md).
All 29 specs + leveling grounded in wowsims APLs/guides. Tier 3 complete.
Healer standardization + Warlock dispel + BT/SWP raid polish committed.
API standardization COMPLETE. Strategy DSL + lazy context landed (2026-07-19). Tree: only junk M/untracked left. Release zip clean on v2.5.11.

### Recent major work (2026-06-27 → 2026-07-20, 288+ commits)
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
| spec_kit | 23 specs migrated to safe_state + define_action_for_class | `1f752b30` (latest) | arms, fury, protection, kebab, balance, cat, bear, caster, resto, discipline, holy, shadow, fire, destruction, frost, restoration, affliction, combat, demonology, elemental, enhancement, assassination, marksmanship |
| Vanilla APL | 6-phase audit complete, all 31 vanilla files reviewed | `0ca3b349` | warrior/frost mage/bear fixes + 0-change reviews |
| Nil-guard tests | 567 vanilla nil-guard test cases across 9 new files | `4ecbcaaa` | 38 specs covered (all vanilla classes) |
| Plan cleanup | 44 → 15 active plans (35 archived) | `37c20d17`+`618cdcdf` | stale/completed plans moved to `plans/_archive/` |
| Tier 3 fidelity | All 29 specs + leveling audited vs wowsims APLs/guides; gaps fixed (Envenom, Conflagrate, etc.); core bugfix | multiple (e.g. `f5bd1843`, `644318d4`) | become-1 plan Phase 3 complete |
| API standardization | Pattern 2 caches + docs in core/main/shared; compliance test extended with core load-cache check; Phase 2/3 validated | `660d2923`, `5341285e` | api-audit Phase 1-3 progress; test_spec_layout_compliance enhanced; full audits green |
| Class standardization | Druid (bear swing timer, leveling/middleware/schema); Warrior (leveling/schema canonical); Hunter, Paladin, Priest, Rogue, Shaman (leveling/middleware/schema etc.) | `71302663`..`dc50b6b5` | progressive one-concern commits of dirty class infra changes under spec-standardization |
| Core/shared standardization | Updates to core_sylvanas, main_sylvanas, units, shared (auto_*, triage etc.) | `36bb720e`, `e378bbb8`, `3b899d9f` | api + standardization updates |
| Test standardization | holy_priest_feature_gaps | `8477393e` | |
| Release packaging | Clean eaxrotations.zip (lua+md only) recreated from HEAD + uploaded to GH release v2.5.11 (refreshed post-final commits) | (git archive + gh) | fulfills release zip update request; verified no bad entries; tree cleaned of source M |
| Healer standardization | Context-aware dispel/cure (control_risk/is_group early returns), dangerous debuff IDs, + Warlock Devour Magic in shared | `5c13bcf4`, `37eab941` | resto druid, holy pally, healing priest, resto shaman + dispel_manager; luac + 252+17 green |
| Dispel polish (cont) | Additional dungeon debuff IDs (Virulent Poison 39029, Initial Infection 39032) + will_die_soon priority in control_risk | `314f6c60` | shared + healing priest; more TBC dungeon support |
| Dispel raid polish | BT/SWP high-tier debuffs (Soul Drain 41303, Polymorph 46280, Flame Buffet 46279, hound poisons/disease) | `43abafd1`, `2e7a63ae` | healing priest + shared dispel_manager; verified in DBC |
| Healer bug fixes | Shaman rank helper (no undefined MID/LOW), priest player scope, druid indent clean + warlock DevourMagicFriendly | fb1a6675, b23fcdd8 | per fix-healer-bugs-and-polish plan; tests 252 green |
| Lazy context | Per-tick dependency-aware context proxy; expensive fields resolve on demand | `4c4ab694` (2026-07-19) | `shared/lazy_context_sylvanas.lua` + `main_sylvanas.lua` build_context conversion + test |
| Strategy DSL | Declarative `{conditions, action}` → `{name, matches, execute}` compiler; arms warrior first adoption (6 strategies) | `37f4bb01` (2026-07-19) | `shared/strategy_dsl_sylvanas.lua` + arms_sylvanas.lua + 2 tests (test_strategy_dsl, test_arms_dsl_priority) |
| Fury DSL | Second-spec DSL adoption (fury warrior, 7 strategies) — validates generality beyond arms | `33c77110` (2026-07-19) | fury_sylvanas.lua + test_fury_dsl_priority.lua; bumped rotation suites 316→317 |
| Combat rogue DSL | Third DSL adopter (first non-warrior) — 6 strategies, energy/combo resource model | `f280bd72` (2026-07-20) | combat_sylvanas.lua + test_combat_dsl_priority.lua; bumped 317→318 |
| Balance druid DSL | Fourth DSL adopter (first mana-based caster) — 6 strategies, mana resource model | `cbc60cfe` (2026-07-20) | balance_sylvanas.lua + test_balance_dsl_priority.lua; bumped 318→319 |
| Protection paladin DSL | Fifth DSL adopter (first tank spec) — 6 strategies, mana/tank resource model | `ccc60645` (2026-07-20) | protection_sylvanas.lua + test_protection_dsl_priority.lua; bumped 319→320 |
| Restoration shaman DSL | Sixth DSL adopter (first healer spec) — 6 strategies, mana/healer resource model | `e6ec9143` (2026-07-20) | restoration_sylvanas.lua + test_restoration_dsl_priority.lua; bumped 320→321 |
| Beast mastery hunter DSL | Seventh DSL adopter (first hunter/pet-management spec) — 6 strategies, focus/mana + pet management | `efa0abe4` (2026-07-20) | beast_mastery_sylvanas.lua + test_beast_mastery_dsl_priority.lua; bumped 321→322 |
| Shadow priest DSL | Eighth DSL adopter (first shadow priest/DoT-tracking spec) — 6 strategies, mana + DoT tracking | `d4172362` (2026-07-20) | shadow_sylvanas.lua + test_shadow_dsl_priority.lua; bumped 322→323 |
| Frost mage DSL | Ninth DSL adopter (first frost mage/proc-tracking spec) — 6 strategies, mana + proc tracking | `4c77806d` (2026-07-20) | frost_sylvanas.lua + test_frost_dsl_priority.lua; bumped 323→324 |
| Arcane mage DSL | Tenth DSL adopter (first arcane mage/mana-proc spec) — 6 strategies, mana + proc/phase state machine | `fd9e3dd1` (2026-07-20) | arcane_sylvanas.lua + test_arcane_dsl_priority.lua; bumped 324→325 |
| Fire mage DSL | Eleventh DSL adopter (first fire mage/debuff-stack spec) — 6 strategies, Scorch 5-stack maintenance + mana/proc | `e28be175` (2026-07-20) | fire_sylvanas.lua + test_fire_dsl_priority.lua; bumped 325→326 |
| Staging cleanup | Deleted untracked `tests/_staging/` debris (failing redundant test + empty dir); promoted WotLK max-level-80 gap into test_expansion_helpers.lua | (uncommitted, 2026-07-20) | gate 317+21 green; test_expansion_helpers now covers WotLK/TBC/Vanilla/Unknown |
| Validation | Full rotation (317) + leveling (21) suites + pre-commit audits | multiple | all green post-commits |

### spec_kit migration progress — COMPLETE (29 of 29 specs) 🎉
All specs migrated to canonical `spec_kit.safe_state` + `define_action_for_class` + guarded registration + return shape (per refactor-developer-experience and _active.md). Reference: arms_sylvanas.lua. See test_spec_layout_compliance.lua CONVERTED table and EaxRotations/README.md for details. No legacy remaining.

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
- **ALL 29 specs converted** (arms, fury, protection, kebab, balance, cat, bear, caster, resto, discipline, holy, shadow, fire, destruction, frost, restoration, affliction, combat, demonology, elemental, enhancement, assassination, marksmanship, retribution, subtlety, survival, protection, beast_mastery, holy). 🎉
- Next candidates: any spec already being edited. Never big-bang (AGENTS Rule 5).
- Pattern: add `spec_kit` require + `define_action_for_class(SPELLS)`, create
  ACTION table with rank IDs, add SCHEMA + `safe_state` in `build_state`,
  guard registration. Reference: `arms_sylvanas.lua`.

### 1b. Continue strategy DSL adoption (opportunistic — only when editing a spec)
- **26 of 29 specs on DSL** (arms `37f4bb01`, fury `33c77110`, combat rogue `f280bd72`,
  balance druid `cbc60cfe`, protection paladin `ccc60645`, restoration shaman `e6ec9143`,
  beast mastery hunter `efa0abe4`, shadow priest `d4172362`, frost mage `4c77806d`, arcane mage `fd9e3dd1`,
  fire mage `e28be175`, enhancement shaman `708796b1`, destruction warlock `3bc689ad`,
  demonology warlock `492481cb`, bear druid, feral cat druid, assassination rogue, subtlety rogue,
  elemental shaman, retribution paladin, discipline priest, survival hunter, marksmanship hunter,
  affliction warlock, protection warrior) — covers rage, energy/combo, mana (caster/tank/healer),
  focus/pet management, shadow DoT tracking, frost/arcane/fire proc/debuff models, melee/totem,
  warlock curse/execute, bear tank, feral cat powershift, assassination/subtlety burst,
  retribution melee, discipline healing, hunter shot weaving, and warrior tanking resource models
  across 10 classes.
- Next candidates: a spec from a remaining class to finish DSL coverage
  (e.g. holy paladin, holy priest, caster druid, or resto druid).
- Never big-bang (AGENTS Rule 5). One spec per commit, gated with `luac -p` + full 328+21 suite.
- Reference: `arms_sylvanas.lua` (first adopter), `shadow_sylvanas.lua` (latest — DoT-tracking pattern).
- Plans: `plans/strategy-dsl-lazy-context-2026-07-19.md` (COMPLETE) + `plans/fury-dsl-adoption-2026-07-19.md` (COMPLETE).

### 2. `integrate-advanced-modules` — Phase 1 complete (`plans/integrate-advanced-modules-2026-07-13.md`)
- All remaining TBC combat_forecast CD gates now implemented:
  - `warrior/protection_sylvanas.lua` — Shield Wall (1800s)
  - `shaman/enhancement_sylvanas.lua` — Bloodlust (600s)
- Verified at landing: 278 rotation + 18 leveling + 6 WotLK suites pass (2026-07-16); since then rotation suites grew to 317 via coverage validation + DSL/lazy-context + fury DSL work.

### 3. `become-1-rotation-system` roadmap (`plans/become-1-rotation-system-classic-tbc-2026-07-05.md`)
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
- `EaxRotations/tests/run_rotation_tests.lua` — rotation suite runner (339 suites).
- `EaxRotations/tests/run_leveling_tests.lua` — leveling suite runner (21 suites).
- `EaxRotations/shared/strategy_dsl_sylvanas.lua` — declarative strategy DSL compiler (24 specs adopted: arms, fury, combat, balance, protection, restoration, beast mastery, shadow, frost, arcane, fire, enhancement, destruction, demonology, bear, cat, assassination, elemental, retribution, discipline, survival, marksmanship, affliction, protection-warrior).
- `EaxRotations/shared/lazy_context_sylvanas.lua` — per-tick dependency-aware context proxy.
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
