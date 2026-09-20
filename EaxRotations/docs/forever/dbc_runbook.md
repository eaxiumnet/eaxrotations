# Forever DBC Extraction Runbook (beta day: 2026-09-17)

> Repo law (AGENTS.md): the **DBC is the authoritative source of truth**.
> A spell does not exist — and nothing is removed — until it resolves in the
> client DBC. Wowhead/Icy Veins data is supplementary detail. This runbook
> clones the existing TBC pipeline for the Forever beta client.

## Status (updated 2026-09-20: re-extracted at 1.60.1.69913 — data unchanged, settings now reproducible)

**2026-09-20 refresh (69913):** the client patched to **1.60.1.69913** on
2026-09-18 while the package still described 69893. The re-extraction ran
clean (119 tables) and the two builds are **identical everywhere the pipeline
reads**: `tools/forever_dbc_diff.py` reports 0 lane-surface deltas (1,696
player spells / 1,646 names either way), all 119 tables have equal row counts,
and the 12 core tables hash identical. The patch was client code, not data.

Three fixes came out of the refresh:

- **The settings file is generated now.** `tools/build_forever_settings.py
  --tool-dir <copy>` writes `appsettings.forever_world.json` (119 tables =
  `CORE13` + `WORLD_TABLES`), so step 1 is reproducible from the repo instead
  of depending on a hand-written file inside a throwaway tool copy. `--check`
  compares an existing file against the canonical list.
- **A stale `DBDCache/` breaks a re-extraction.** The DBD provider trusts any
  cached `.dbd` younger than a day, so a tool copy carrying another build's
  cache dies mid-run with `No definition found for this file` — which reads
  like a missing table but is a missing *definition*. Clear `DBDCache/`
  before extracting; upstream WoWDBDefs already carries 1.60.1.69913, so a
  fresh fetch resolves every table.
- **Two gates called a live bridge a stub.** `build_forever_bridge.py --check`
  and `check_forever_client.py` tested `"__forever_stub" in content`, which
  matches the generated header's own prose; both now use the structural test
  (`M.__forever_stub = true`) owned by
  `build_forever_bridge.bridge_is_stub`. The client scan also could not see the
  beta at all (it keyed on the word "forever", while the product is
  `wow_classic_beta`); it now reports the installed build and whether the built
  package matches it (`UP TO DATE` / `STALE`).

## Status (updated 2026-09-17: 119-table extraction, icons + mounts, world/NPC/item package)

**2026-09-17 icons + mounts extension:** the extraction is now **119 tables**
(the 13 spell/talent core + 106 world/NPC/item/appearance/file-manifest
tables, incl. `Mount*`, `ItemAppearance`, `ItemModifiedAppearance`,
`ItemSearchName`, `ModelFileData`, `TextureFileData`). Icons were exported
from CASC by FDID with a small TACTSharp-based dumper (same reference-DLL
pattern as DB2ToSqlite; source kept at `tools/forever_export_cs/`), decoded
by `tools/build_forever_icons.py` (4,047 icons -> `icons.png` + `icons.json`
in the package). 24 exported icons are zero-byte encrypted placeholders.
`ModelFileData` (121k rows) + `TextureFileData` (58.5k) are the client's own
file manifests -- the foundation for the model/3D export step.

**2026-09-17 world/NPC extension:** the extraction grew from 13 to **109
tables** — the 13 spell/talent core plus 96 probe-confirmed world/NPC/item/
spell-meta tables (creature displays/models/families/types/speeds,
factions, `AreaTable`/`Map`/`UiMap*`/`AreaPOI`/`AreaTrigger`, the `Taxi*`
network, `TransportAnimation`, the full `Item*` family, `SpellPower`/
`SpellTargetRestrictions`/`SpellCategories`/`SpellRange`/..., `ChrClasses`/
`ChrSpecialization`, `ExpectedStat`). Settings file:
`appsettings.forever_world.json`; the authoritative table list is
`WORLD_TABLES` in `tools/build_forever_database.py`. The probe recipe and
the bisect driver live in `tools/probe_forever_tables.py` (a missing table
dies with `File not found in root` *before* the DB is written; the crash
never names the table — bisect by list order). The community package now
mirrors all 95 world tables verbatim and adds the curated world artifacts
(`items.jsonl`, `zones.json`, `points.json`, `taxi.json`, `creatures.json`,
`spell_meta.json`) — see `docs/forever/datamine/README.md`. Key absence
notes: spawns/drops/health are server-side (not client data); `WorldMapArea`
is gone in favour of `UiMap`; `Gt*` game tables and `ItemRandomProperties`
are not shippable on this client build.

## Status (updated 2026-09-17: beta DBC extracted, bridge LIVE)

**2026-09-17 beta-day execution:** the beta arrived as the `wow_classic_beta`
product (folder `_classic_beta_`, **no** `_forever_` folder — the runbook's
third shape), version **1.60.1.69893** per `.build.info` (anniversary sits at
2.5.6.69795). Identity confirmed by DBC signatures, not by folder name:
Holy Strike / Seal of Fury / Touch of the Grave (1260189+) / Infusion of
Light / Twist of Light (1310735) / Light's Vigil (1310909+) / Voice of Truth
/ Reverence / Templar's Bulwark / Iron Creed / Sacred Arbiter all resolve in
the extracted `SpellName`; Skyborne resolves in `ChrRaces` (95/96).
Extraction used a pristine copy of the DB2ToSqlite backup tree with a custom
settings file (`BaseDir: C:\Program Files (x86)\World of Warcraft`,
`Product: wow_classic_beta`) — the backup tree itself was never mutated.
Two adaptations were required for this classic-line client (both documented
in `tools/build_forever_bridge.py` with DBC evidence): (1) the extraction
`TargetDirectory` must stay `dbfilesclient` (the tool resolves
`{TargetDirectory}/{table}.db2` against listfile FDIDs); (2) `Tables` must
exclude `ItemRandomProperties` (deterministic "File not found in root" crash
on this client — retry recipe: bisect the table list, keep the Spell* core).
The unified `wowsims_forever.db` now carries 13 tables (7 Spell* + Talent,
TalentTab, SkillLineAbility, SkillLine, ChrRaces, SpellAuraOptions).
`tools/build_forever_bridge.py` emits **1,696** player spells; the audit is
LIVE (`--check-bridge` exit 0; full audit 0 invalid; self-test green).
The 1.60 `SpellEffect` schema has no `EffectBasePoints`/`EffectDieSides`
columns (base points live in `EffectBasePointsF`), and two 2.5.5
calibrations do NOT carry over: heal effects are `{10}` only (2 = direct
damage, 62 = power burn, 77 = damage-side here), and `SpellClassSet` uses
the classic family enum (3 Mage / 4 Warrior / 5 Warlock / 6 Priest / 7 Druid
/ 8 Rogue / 9 Hunter / 10 Paladin / 11 Shaman).

**2026-09-17 beta-day attempt (morning):** client not yet installed on the ops
machine (anniversary client self-updated to 2.5.6.69795 on 09-13, no
forever product on any Battle.net surface); `EaxRotations/tools/check_forever_client.py`
added as the re-runnable step-0 gate. (Superseded by the execution entry
above once `wow_classic_beta` 1.60.1.69893 was found installed.)

**Rehearsal 2026-09-16 (synthetic DBC, fresh worktree):** fixture build, bridge
build, `--check-bridge` exit 1 (fixture-sized), fail-closed negative scan, and
the full step-4 matrix all behave exactly as documented. Two corrections landed
from it: the forever audit now scans NESTED numeric tables (`b5116fdca` -- a
scratch file with a nested bogus ID previously passed silently), and step 1
below was corrected -- the DB2ToSqlite source tree exists only in the
2026-06-30 backup, not in the checkout.
## Status (updated 2026-09-15: pipeline built and proven offline)

| Step | Tool | Status |
|---|---|---|
| 1. DBC extraction from beta client | `tbc-new/tools/DB2ToSqlite` (backup copy at `C:\newbot\scripts-backup-20260630-095300\tbc-new\tools\DB2ToSqlite\`, .NET 9 SDK present) | **BLOCKED — beta client not installable before 2026-09-17** (Battle.net registers no `wow_forever` product yet) |
| 2. Bridge builder | `tools/build_forever_bridge.py` | **DONE — proven end-to-end on a synthetic DBC** |
| 2b. Fixture (offline proof) | `tools/build_forever_bridge_fixture.py` | **DONE — synthetic DB local-only, never committed** |
| 3. Audit live-mode switch | `EaxRotations/tests/run_forever_audit_tests.lua` | **DONE — automatic** the moment the bridge stops carrying `__forever_stub`; `--check-bridge` mode added |
| 3b. By-name spell resolution | `spell_index_by_name_forever` (bridge) | **DONE — zero-literal spec design**: `_forever` files resolve Forever-new spells BY NAME; a nil lookup leaves the lane dormant (never a guessed ID). Generator emits the mirror; audit self-test pins its presence |
| 4. Lexxer cross-check | `GET https://lexxer.org/api/v1/spells/{id}?game=forever` | Blocked on lexxer gaining the flavor |
| 5. Version-string tighten | `core_sylvanas.lua::_resolve_expansion_key()` | Blocked on real `get_game_version()` output |
| 6. Full matrix re-run | gate + verify_all | Wired |

## Beta-day execution (exact commands)

Run from the repo root (or the forever worktree):

```bash
# 0. Install the Forever beta via Battle.net, then locate the client:
#    expect "C:\Program Files (x86)\World of Warcraft\_forever_\" (folder
#    name unconfirmed) and a new product line in .build.info.

# 1. Extract the DBC (DB2ToSqlite lives in the tbc-new backup; .NET 9
#    required). Work on a COPY of that tree, never on the backup itself:
#      cp -r <backup>/DB2ToSqlite <work>/_tool_DB2ToSqlite
#    a) generate the settings (119 tables = CORE13 + WORLD_TABLES; the file
#       used to be hand-written inside a throwaway copy, i.e. unreproducible):
#      python tools/build_forever_settings.py --tool-dir <work>/_tool_DB2ToSqlite
#    b) CLEAR <work>/_tool_DB2ToSqlite/DBDCache/ -- the DBD provider trusts
#       any cache younger than a day, so a copy carrying another build's cache
#       dies with "No definition found for this file" (reads like a missing
#       table; it is a missing definition). Upstream WoWDBDefs has 1.60.1.69913.
#    c) run with cwd = the tool copy root: the DLL sits in bin/Debug/net9.0,
#       and the relative paths (dbfilesclient/, DBDCache/, cache/) hang off it:
cd <work>/_tool_DB2ToSqlite && dotnet bin/Debug/net9.0/DB2ToSqliteTool.dll \
    -s appsettings.forever_world.json \
    -o <repo>/wowheadScrape/dbc_extract/wowsims_forever.db
#    Then diff the new extraction against the last one before rebuilding:
#      python tools/forever_dbc_diff.py --old <prev db> --new <new db>
#    The table list = 13 core + WORLD_TABLES (tools/build_forever_database.py).
#    New/unstable tables: probe with tools/probe_forever_tables.py first --
#    a missing table aborts the run with "File not found in root" and the DB
#    is only written after every table loads.
#    (NOTE, verified 2026-09-16: tbc-new/tools/DB2ToSqlite does NOT exist in the
#    checkout -- only the backup copy above does. The tool has prebuilt net9.0
#    binaries and dotnet 9.0.318 is installed. Its appsettings.json points BaseDir
#    at F:\World of Warcraft -- confirm the real install drive at step 0.)
#    Target DB2s at minimum: Spell*, Talent, TalentTab, Item* (the tool's
#    manifest names what it found on the new client).

# 2. Build the bridge (replaces the tracked stub; audit flips to live):
python tools/build_forever_bridge.py

# 3. Verify the bridge + audit are live:
lua EaxRotations/tests/run_forever_audit_tests.lua --check-bridge
#    exit 0  = real bridge (>=1000 entries); exit 1 = still fixture-sized.

# 4. Re-run the full matrix:
luac -p EaxRotations/core_sylvanas.lua
lua EaxRotations/tests/run_forever_audit_tests.lua
lua EaxRotations/tests/run_forever_audit_tests.lua --self-test
lua EaxRotations/tests/run_rotation_tests.lua --quiet
lua EaxRotations/tests/run_verify_all.lua

# 5. Cross-check first kit IDs against lexxer once it gains the flavor
#    (cross-check only — the DBC is the authority):
#    curl -s "https://lexxer.org/api/v1/spells/<id>?game=forever"
```

## Beta-day diff (new-build triage)

When Blizzard pushes a new beta build, the diff harness flags every
change on the surface the rotations resolve through BEFORE any lane is
touched (audit green no longer hides a silent re-rank or rename):

```bash
# 1. Extract the new build to a NEW path (keep the old extraction):
#    <DB2ToSqlite> -o .../dbc_extract/wowsims_forever_<build>.db

# 2. Diff old -> new on the lane surface (rows, mirrors, overrides):
python tools/forever_dbc_diff.py \
    --old wowheadScrape/dbc_extract/wowsims_forever.db \
    --new wowheadScrape/dbc_extract/wowsims_forever_<build>.db \
    --exit-on-action
#    exit 0 = lane surface identical; exit 1 = action findings (removed
#    / renamed / re-ranked rows, cooldown/gcd moves, override flips)
#    with the impacted _forever lanes named; JSON report lands at
#    tools/forever_dbc_diff_report.json.

# 3. On findings: verify/fix the named lanes, then rebuild the bridge
#    from the NEW DB and re-run the gates:
python tools/build_forever_bridge.py
lua EaxRotations/tests/run_forever_audit_tests.lua --check-bridge
lua EaxRotations/tests/run_rotation_tests.lua --quiet

# Harness self-test (synthetic old/new DBs in TEMP -- never the
# canonical fixture path -- plus a real-DBC self-diff = 0):
python tools/forever_dbc_diff.py --self-test

# Committed-fixture gate (the synthetic pair in
# EaxRotations/tests/fixtures/forever_dbc/ through the real end-to-end
# path incl. the lane-impact scan over the live call sites; also a
# verify_all component + a named CI step):
python tools/forever_dbc_diff.py --check-fixtures
# Regenerate the pair (provenance = the harness's own seed rows) when
# the seeded shapes move:
python tools/forever_dbc_diff.py --write-fixtures
```

The diff extracts through `tools/build_forever_bridge.py`'s own
`load_forever_spells`, so what it reports is exactly what the bridge
would emit -- there is no second extraction implementation to drift.

## What the builder extracts (calibrated on the 2.5.5 DBC)

- **Player filter**: `SpellClassOptions.SpellClassSet ∈ {1..9,11}` (class map in
  the script), name non-empty and non-degenerate (QA/DEBUG/PLACEHOLDER/TEST…),
  `BaseLevel/SpellLevel ∈ [0,255]`, `RecoveryTime ≤ 20min`, `StartRecoveryTime ≤ 60s`.
- **Per (class, name) rank-1 baseline**: lowest spell ID wins (rank ladders share a name).
- **Fields**: name, class, level (BaseLevel), school (SchoolMask→physical/holy/
  fire/nature/frost/shadow/arcane), `is_heal` (Effect ∈ {2,10,62,77} — 2.5.5
  client uses 10 for Flash Heal, 77 for Holy Light), `aoe` (Effect ∈ {27,124} or
  area ImplicitTarget buckets), cast-time index, gcd (StartRecoveryTime/1000),
  cooldown (RecoveryTime/1000).
- **Known calibration cases**: Consecration r1 → aoe ✓, Arcane Explosion r1 →
  aoe ✓, Flash Heal r1 → is_heal ✓ (effect 10), Holy Light r2 → is_heal ✓
  (effect 77), Fireball/Holy Strike-style weapon strikes → neither ✓.
- **ID threshold**: spell IDs `< 100` are never emitted (rank-literal guard,
  repo-wide audit convention — e.g. Heroic Strike 78 stays out).

## Synthetic-DBC proof (offline, no beta needed)

```bash
# Copy the tracked-at-source 2.5.5 DBC next to the fixture first (it is
# gitignored):  mkdir -p wowheadScrape/dbc_extract && cp /c/newbot/scripts/wowheadScrape/dbc_extract/wowsims.db wowheadScrape/dbc_extract/
python tools/build_forever_bridge_fixture.py   # writes wowsims_forever.db (SYNTHETIC)
python tools/build_forever_bridge.py           # extracts from the synthetic DB
lua EaxRotations/tests/run_forever_audit_tests.lua --check-bridge   # exit 1 = fixture-sized (expected)
```

The fixture proves: 6 real 2.5.5 grounding rows extract with correct
fields, 4 synthetic Forever-new rows (Holy Strike/Seal of Fury/Skyfury/
Molten Blast) extract, and all negative cases are filtered (QA DEBUG,
PLACEHOLDER, BaseLevel 300, NPC spell, 25-min cooldown). The audit's
negative-scan test (a scratch `_forever` file with invalid IDs must exit 1)
was run and passed during the 2026-09-15 proof.

**The synthetic bridge must NEVER be committed**: regenerate the DB from the
real client on beta day and rebuild before the first `_forever` spec PR.

## Live-mode audit behavior (from 2026-09-15)

- The audit now counts bridge entries and reports them on every run.
- `--check-bridge`: exit 0 = live+populated (≥1000), exit 1 = fixture-sized
  (warning printed), exit 2 = stub remains.
- File discovery: GNU `find` primary; `git ls-files EaxRotations/classes`
  filtered in Lua as the Windows fallback (cmd.exe has no GNU find). **Commit
  before auditing** — the fallback only sees tracked files (deliberate,
  mirroring the clean-checkout probe's contract).
- Enforcement stays fail-closed in every mode: with the fixture bridge loaded,
  real-era IDs in a `_forever` file still flag `INVALID` /
  `VANILLA_ID_IN_FOREVER`.
- Verified 2026-09-16: the scanner also catches ids inside NESTED numeric
  tables (gmatch(%b{}) previously skipped them -- fixed in `b5116fdca`); ids
  above 999999 are outside the plausibility ceiling and never flagged.

## Why this gate exists

Forever launches with new spells (Holy Strike, Seal of Fury, reworked racial
actives) and reworked ranks. Until the beta client's DBC is extracted, **no
spell ID may be written into a `_forever` spec file** — spell IDs from panel
footage, Wowhead previews, or datamined rumors are not verifiable and the
audit would (correctly) reject them. Pre-beta work is therefore limited to
era plumbing, research docs, and this pipeline.

## First-day checklist (beta)

- [ ] On any NEW beta build: run the beta-day diff (section above) before
      touching any lane or rebuilding the bridge.
- [ ] Install beta → extract DBC → commit `wowsims_forever.db` (or the Lua
      tables if the DB is too large for git — AGENTS.md tolerates 36 MB,
      follow precedent).
- [ ] **Probe checklist**: run docs/forever/beta_day1_probes.md (P0-P3 same
      day; it consolidates every flagged claim across the nine kit docs
       into one execution-ordered pass).
- [ ] **Addon-policy recon (MMORPG.com interview 2026-09-16): the client
      "takes cues from modern WoW" on add-ons — on first beta login check for
      any new client integrity/error-reporting surface before running ANY
      external tooling** (the DBC extraction reads files only; verify before
      anything that touches a live client process).
- [ ] Confirm exact version string (`get_game_version()` output) → tighten the
      `s:find("forever")` branch in `core_sylvanas.lua::_resolve_expansion_key()`
      and update `test_forever_runtime_bootstrap.lua`.
- [ ] `python tools/build_forever_bridge.py` + commit the real bridge;
      verify `run_forever_audit_tests.lua --check-bridge` exits 0.
- [ ] Verify Holy Strike / Seal of Fury / reworked racial IDs exist; record
      them in `kits/paladin.md` and `kits/racials.md` **with DBC evidence**.
- [ ] Legacy-perk spell IDs (docs/forever/legacy_perks.md checklist) → add to
      the bridge scope + audit scope once identified.
- [ ] Confirm talent-table shape (16-point milestone) if the Talent DB2 exposes
      it; note in `kits/talents.md`.
- [ ] Only then open the first `_forever` spec PR (paladin, per the plan).
