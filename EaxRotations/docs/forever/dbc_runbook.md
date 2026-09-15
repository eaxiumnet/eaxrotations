# Forever DBC Extraction Runbook (beta day: 2026-09-17)

> Repo law (AGENTS.md): the **DBC is the authoritative source of truth**.
> A spell does not exist — and nothing is removed — until it resolves in the
> client DBC. Wowhead/Icy Veins data is supplementary detail. This runbook
> clones the existing TBC pipeline for the Forever beta client.

## Why this gate exists

Forever launches with new spells (Holy Strike, Seal of Fury, reworked racial
actives) and reworked ranks. Until the beta client's DBC is extracted, **no
spell ID may be written into a `_forever` spec file** — spell IDs from panel
footage, Wowhead previews, or datamined rumors are not verifiable and the
audit would (correctly) reject them. Pre-beta work is therefore limited to
era plumbing, research docs, and this pipeline.

## Pipeline (mirrors AGENTS.md "Refresh pipeline", Forever flavor)

1. **DBC extraction from the beta client** (requires the Forever beta install):
   ```bash
   cd tbc-new/tools/DB2ToSqlite && dotnet run -- -o wowheadScrape/dbc_extract/wowsims_forever.db
   ```
   Target DB2s at minimum: Spell*, Talent, TalentTab, Item* (names/dbcs may
   differ on the new client — the tool's manifest will say).

2. **Convert DBC to Lua** (adapt `convert_db_to_lua_v4.py` with a
   `--flavor forever` mode; keep the TBC output untouched):
   ```bash
   python wowheadScrape/convert_db_to_lua_v4.py --flavor forever
   ```

3. **Build the bridge** (extend `build_tools/json_to_lua_data.py` with a
   forever mode merging the Forever DBC names/schools with scraped detail):
   emits `EaxRotations/shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua`
   exposing `spell_index_forever` (id → { name, ... }), matching the shape the
   wotlk/vanilla bridge files use (`tests/run_wotlk_audit_tests.lua:19-26`
   documents the two shapes in the wild — named-key and returned-map).

4. **Verify against lexxer** once it gains the flavor:
   `GET https://lexxer.org/api/v1/spells/{id}?game=forever` — cross-check, not
   authority.

5. **Wire the audit**: `EaxRotations/tests/run_forever_audit_tests.lua`
   (shipped pre-beta as a scaffold that exits 0 while the bridge is a stub)
   starts enforcing the moment the bridge lands. Gate + verify_all steps for it
   are already wired (tools/pre-commit, run_verify_all.lua).

6. **Re-run the full matrix**: `luac -p` on changed files,
   `run_rotation_tests.lua`, `run_leveling_tests.lua`, `run_wotlk_tests.lua`,
   `behavioral_audit.lua forever`, `run_verify_all.lua`.

## First-day checklist (beta)

- [ ] Extract DBC → commit `wowsims_forever.db` (or the Lua tables if the DB
      is too large for git — AGENTS.md tolerates 36 MB, follow precedent).
- [ ] Confirm exact version string (`get_game_version()` output) → tighten the
      `s:find("forever")` branch in `core_sylvanas.lua::_resolve_expansion_key()`
      and update `test_forever_runtime_bootstrap.lua`.
- [ ] Generate + commit the Forever bridge; verify `run_forever_audit_tests.lua`
      still exits 0 with the real index loaded.
- [ ] Verify Holy Strike / Seal of Fury / reworked racial IDs exist; record
      them in `kits/paladin.md` and `kits/racials.md` **with DBC evidence**.
- [ ] Confirm talent-table shape (16-point milestone) if the Talent DB2 exposes
      it; note in `kits/talents.md`.
- [ ] Only then open the first `_forever` spec PR (paladin, per the plan).
