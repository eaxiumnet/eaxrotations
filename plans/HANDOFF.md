# HANDOFF — EaxRotations continuation guide

> **Read this first.** If you are a fresh AI agent (any model — Kimi, DeepSeek,
> Claude, etc.) picking up this project with no prior context, this single file
> tells you the current state and exactly how to continue safely. It is kept
> up to date after every work session. Last updated: **2026-06-27** (EaxAutoQuester P0 sprint complete + Druid perf fixes; HEAD `3167dd44`, pushed to origin).

**This file is the always-current "where are we / what's next" doc.**
The detailed task matrix lives in `plans/finish-what-i-started.md` — read it
second. The hard rules live in `AGENTS.md` (repo root) — read it first per
its own contract, but the critical bits are summarized below so you don't
have to context-switch.

---

## TL;DR (start here)

- **Project:** 29 WoW TBC Classic Anniversary (2.5.5.x) + Vanilla Anniversary
  rotation plugins for **Project Sylvanas**, in Lua 5.1/LuaJIT. Repo:
  `https://github.com/eaxiumnet/eaxrotations`. Work dir: `C:\newbot\scripts`.
- **Baseline is GREEN:** 171 rotation suites + 11 leveling suites pass on
  **Lua 5.1**. Don't break this.
- **What's done:** Tracks A–D (cleanup + native-API features + core refactor +
  data cleanup), B1–B6 (friendly-target healing for ALL 5 healers + vanilla),
  APL optimization COMPLETE for all 29 specs, EaxAutoQuester P0 sprint.
  All committed & pushed to origin.
  APL optimization COMPLETE for all 29 specs: **8 guide-based fixes** committed
  (Fury `014e81c7`, Destruction `f9b8a60f`, Elemental `6c88a6d8`, Assassination
  `23e5496d`, Demonology `cddd6393`, Drain Soul shard-capture `c3565364`,
  Prot Paladin Holy Shield>Consecration `6b1ec84b`, Prot Warrior Demo+TC>Devastate
  `a31d1fe5`) + Disc header fix `df1c7ed6` + **Holy Paladin Avenging Wrath gap
  fix `9b14c93e`** (the one missing-spell gap the research surfaced) + **all 21
  remaining specs VERIFIED** no-change vs guides (incl. all 5 healers + Bear tank).
  See `plans/apl-guide-optimization-2026-06.md`. **10 GitHub releases** exist
  (latest v2026-06-26.f5c95e4f — Holy Paladin Avenging Wrath; APL round fully shipped).
- **What's next:** APL optimization COMPLETE + shipped for all 29 TBC specs.
  Remaining (all lower priority / new scope): (1) Vanilla Anniversary variant
  audit (`*_vanilla.lua` — different game version 1.15.x; the vanilla
  spell-contamination audit already passes, but the APL *priorities* haven't
  been guide-reviewed for Vanilla). (2) B6.2 (per-spec predictive threshold
  sliders — design-first, don't over-engineer). (3) Opportunistic polish
  (migrate specs to `spec_kit.safe_state` only when already editing them).
  (4) EaxAutoQuester verification (separate product, NOT covered by the rotation
  gate; last known 21/28 tests pass / 7 fail).
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
   `_flux_tbc_explore/`, `eax_refactor/`, `EaxESP/`, `EaxProfessions/`,
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
  a **pre-commit spell-ID audit hook** that runs automatically — if it fails,
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
`*.zip` is gitignored, so the zip won't pollute the repo. **10 releases** exist
(latest `v2026-06-26.f5c95e4f`). NOTE: include `EaxAutoQuester/` in the archive
path too (the rotation product ships both): `git archive ... HEAD -- EaxRotations/ EaxAutoQuester/`. Verify the zip with a python zipfile check that no entry is
outside `.lua`/`.md`/`VERSION.txt` and no external-repo dir leaked in.

---

## Test gate (run before marking ANY task done)

```bash
cd /c/newbot/scripts
cmd.exe //c "validate.cmd"
```
Expected output ends with `ALL CHECKS PASSED`. It runs: `luac -p` on modified
files → rotation suite (171) → leveling suite (11) → spell audit. All on Lua
5.1. If it says `VALIDATION FAILED`, read the FAIL line and fix it.

For a quick single-file syntax check: `luac -p <file>` (uses the 5.1 luac).
For one test standalone: `"/c/Program Files (x86)/Lua/5.1/lua.exe" EaxRotations/tests/<test>.lua`

---

## CURRENT STATE (verified 2026-06-26, HEAD 9b14c93e)

**Baseline:** 171 rotation + 11 leveling suites PASS / 0 fail on Lua 5.1.5.
Spell audit PASS. `validate.cmd` green.

### Done this effort (commits live on GitHub master)
| Track | Item | Commit | One-line |
|-------|------|--------|----------|
| A1 | validate.cmd Lua 5.1 pin | `f487c7ce` | gate reliability foundation |
| A2 | hysteresis `configure()` timer-reset bug | `666252d0` | drop-hold now works per-frame |
| A3 | dead-ref cleanup (missile_tracker, swing_timer, reagent_guard×5, spell_flag_checker) | `c811a99f` + `b60d2fe6` | zero behavior change |
| B1 | ret seal-twist test coverage (9 contracts, was 6-line stub) | `aa021e39` | infra already native-backed |
| B2 | ability weaving — verified native `auto_attack_helper` wired | — (no change needed) | hunter model kept (wowsims-parity) |
| B3 | heal shield absorb via native `get_total_shield()` | — (already done + tested) | `healer_deficit` + `preemptive_heal` |
| B4 | "others' heals" via native `get_incoming_heals()` | — (already done + tested) | `test_healer_deficit_overheal` T7 |
| B5 | pvp_burst dangling `reasons` ref fixed | `f487c7ce` | `M.reason()` now populated |
| B6 | friendly-target healing ALL 5 healers | `c4f535df`+`de8d9145`+`3181e7a9` | manual-target control, emergency-safe |
| B6v | vanilla healer variants (5 specs) | `931cd9ee`+`818707a8` | port of B6 to Vanilla Anniversary |
| D1 | generator DEBUG filter | `16c3d05d` | 54 DEBUG spells removed from bridge |
| C1 | core/ttd | — (already in `shared/ttd_tracker_sylvanas.lua`) | nothing to move |
| C2 | core/talents | — (already in `shared/spell_resolver_sylvanas.lua`) | nothing to move |
| C3 | core/diagnostics.lua extracted | `80128541` | core_sylvanas 5965→5857 lines |
| D2 | spell 28176 = Fel Armor (DBC), NOTE corrected | `c377750f` | no Spellstone conflict |
| A4 | pvp_burst DR/EnemyCD stubs | — (option b: documented in-code) | lines 93, 128 of pvp_burst |
| — | gitignore external repos | `5d2a2fed` | prevents accidental mass-commit |
| — | delete 10 dead modules + 7 orphan tests | `b60d2fe6` | post-audit Task 1.3 |
| — | EaxAutoQuester persisted (separate product, ungated) | `f6d93cb9` | luac clean; run own suite |
| APL | Demonology: Corruption before Immolate (guide fix #5) | `cddd6393` | APL order swap; match fns unchanged |
| APL | Drain Soul TBC shard-capture (Affliction + Demonology) | `c3565364` | TTD-gated, not a Wrath sub-25% execute; tests rewritten |
| APL | Prot Paladin: Holy Shield above Consecration (crush-cap) | `6b1ec84b` | survival > threat per Wowhead 2.5.5 |
| APL | Disc Priest Pattern 15 header fixed (Wrath refs removed) | `df1c7ed6` | code was already TBC-correct; header only |
| APL | Prot Warrior: Demo+TC above Devastate (survival debuff uptime) | `a31d1fe5` | guide: Demo/TC 'always up' > filler |
| APL | Holy Paladin: Avenging Wrath burst CD added (heavy-healing window) | `9b14c93e` | guide-noted missing-spell gap; +20% healing; test added |
| APL | 21 remaining specs VERIFIED vs guides (no change) | `9c0fd382`+`d90b602d`+later | all 5 healers + Balance/Cat/Bear/Subtlety/Survival/Ret/Enhancement/Smite/Shadow + Arms/BM/MM/Arcane/Fire/Frost/Combat |

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

### 1. B6.2 — Per-spec predictive threshold sliders
The B6 friendly_target_threshold sliders are HP-based. A separate predictive
(damage-rate-aware) threshold layer (post-audit 3.2) would use
`HealerDeficit.predicted_deficit` to fire FriendlyTarget when damage is
incoming even if current HP is above the static threshold. Smaller, tuning-
level work. Design first — don't over-engineer.

### 2. Opportunistic polish (only when already editing a file)
- Migrate specs to `spec_kit.safe_state` (AGENTS Pattern 16) — `arms_sylvanas.lua`
  is the proof (done). Convert a spec only when already editing it; never
  schedule a "convert all 29" effort (that's what causes loops).
- The `test_fury_custom_matches.lua` has a stale `package.preload["shared/swing_timer_sylvanas"]`
  mock (tab-indented, harmless). Prune only if already editing that test.
- C4 (extract core/casting.lua) remains deferred — 8 functions scattered across
  a 4200-line span, loop-trap. Revisit only as part of a whole-file reorg.

### 3. Verify the EaxAutoQuester suite (separate product)
`EaxAutoQuester/` is committed but NOT covered by the rotation gate. Run
`"/c/Program Files (x86)/Lua/5.1/lua.exe" EaxAutoQuester/tests/run_quester_tests.lua`
at some point to see its real status. Sibling product — its own concern.

---

## READ ORDER for a fresh agent
1. **This file** (`plans/HANDOFF.md`).
2. `AGENTS.md` (repo root) — hard rules, patterns, boundaries. **The single
   source of truth for agent instructions.** Ignore stale `CLAUDE.md`/cursorrules.
3. `plans/finish-what-i-started.md` — full task matrix with done/in-flight/out-of-scope.
4. The target file(s) for your task + relevant `apidocs/pages/dev/api/*.md`.
5. Run `validate.cmd` to confirm green before starting.

## KEY FILES
- `EaxRotations/core_sylvanas.lua` — main NS namespace (5857 lines; 5 domains
  extracted to `EaxRotations/core/{settings,units,items,cooldowns,diagnostics}.lua`).
- `EaxRotations/main_sylvanas.lua` — dispatcher, per-frame context build
  (feeds `context.enemy_count_smoothed` via `EnemyCountHysteresis`).
- `EaxRotations/classes/<class>/<spec>_sylvanas.lua` — 29 spec files (flat).
- `EaxRotations/shared/` — ~50 shared modules (healer_deficit, preemptive_heal,
  aura_cache, enemy_count_hysteresis, pvp_burst_window, offensive_dispel, …).
- `EaxRotations/tests/run_rotation_tests.lua` — rotation suite runner (171 suites).
- `EaxRotations/tests/run_leveling_tests.lua` — leveling suite runner (11 suites).
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
