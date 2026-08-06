# Season of Discovery Rotations

This page is the support and provenance manifest for the native Season of Discovery (SoD) rotations. SoD is a separate runtime mode from TBC, Vanilla, and WotLK. In SoD mode the class loader attempts the `_sod.lua` module path exclusively; it does not fall back to a legacy rotation when an SoD module is unavailable.

## Supported Rotations

The production manifest in `shared/class_loader_sylvanas.lua` contains exactly 20 entries across nine classes. The EAX module is the runtime-owned Lua file. The source package is the pinned simulator package used for behavior and action-map provenance.

| # | Class | Role | EAX module | Source package |
|---:|---|---|---|---|
| 1 | Druid | Balance | `classes/druid/balance_sod.lua` | `druid/balance` |
| 2 | Druid | Feral | `classes/druid/feral_sod.lua` | `druid/feral` |
| 3 | Druid | Restoration | `classes/druid/restoration_sod.lua` | `druid/_restoration` |
| 4 | Druid | Tank | `classes/druid/tank_sod.lua` | `druid/tank` |
| 5 | Hunter | DPS | `classes/hunter/dps_hunter_sod.lua` | `hunter/dps_hunter` |
| 6 | Mage | DPS | `classes/mage/dps_mage_sod.lua` | `mage/dps_mage` |
| 7 | Paladin | Protection | `classes/paladin/protection_sod.lua` | `paladin/protection` |
| 8 | Paladin | Retribution | `classes/paladin/retribution_sod.lua` | `paladin/retribution` |
| 9 | Priest | Healing | `classes/priest/healing_sod.lua` | `priest/healing` |
| 10 | Priest | Shadow | `classes/priest/shadow_sod.lua` | `priest/shadow` |
| 11 | Rogue | Combat DPS | `classes/rogue/combat_sod.lua` | `rogue/dps_rogue` |
| 12 | Rogue | Tank | `classes/rogue/tank_sod.lua` | `rogue/tank_rogue` |
| 13 | Shaman | Elemental | `classes/shaman/elemental_sod.lua` | `shaman/elemental` |
| 14 | Shaman | Enhancement | `classes/shaman/enhancement_sod.lua` | `shaman/enhancement` |
| 15 | Shaman | Restoration | `classes/shaman/restoration_sod.lua` | `shaman/_restoration` |
| 16 | Shaman | Warden | `classes/shaman/warden_sod.lua` | `shaman/warden` |
| 17 | Warlock | DPS | `classes/warlock/dps_sod.lua` | `warlock/dps` |
| 18 | Warlock | Tank | `classes/warlock/tank_sod.lua` | `warlock/tank` |
| 19 | Warrior | DPS | `classes/warrior/dps_warrior_sod.lua` | `warrior/dps_warrior` |
| 20 | Warrior | Tank | `classes/warrior/tank_warrior_sod.lua` | `warrior/tank_warrior` |

This is the current supported inventory. It does not imply that every Classic class/spec combination has a separate SoD implementation.

## Runtime Contract

- The canonical SoD mode selects the SoD class manifest and exposes `sod_phase` plus normalized rune availability through the existing context boundary.
- Phase- and rune-dependent actions fail closed when the required value is absent, malformed, below the action minimum, or outside the action's supported range.
- Class-wide registration is owned by `shared/class_loader_sylvanas.lua`; class-specific loader files own settings/schema integration; the 20 files above own rotation priorities.
- Existing legacy expansion paths remain separate. This page does not claim SoD support for TBC, Vanilla, or WotLK modules.

## Source Provenance

| Field | Pinned value |
|---|---|
| Simulator source | `wowsims/sod` |
| Source commit | `0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e` |
| Source checkout | `C:\temp\wowsims-sod-plan-20260730\sim` |
| Proto checkout | `C:\temp\wowsims-sod-plan-20260730\proto` |
| Client/DBC artifact | `C:\newbot\scripts\wowheadScrape\dbc_extract\wowsims.db` |
| DBC SHA-256 | `8a2659b4f60b685187a988cc349002c20f09b7261e9089624c15b72d985b8239` |
| Action-map schema | `eax.sod.action-map.v2` |
| Source package count | `20` |
| Resolved executable references | `816` |
| Unresolved executable references | `0` |

The simulator source and proto directories are provenance inputs only. Go, protobuf, and other simulator build artifacts are not copied into EaxRotations. The local DBC is the client data source used by the action-map audit; the JSONL map and its manifest are evidence artifacts, not runtime substitutes for Sylvanas APIs.

## Refresh and Audit

Run these commands from `C:\newbot\scripts` after intentionally refreshing the pinned source evidence:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File EaxRotations/.omo/evidence/task-1-sod-action-map-audit.ps1 -OutputDir EaxRotations/.omo/evidence
lua EaxRotations/tests/test_sod_source_audit.lua
lua EaxRotations/tests/test_sod_registry_manifest.lua
lua EaxRotations/tests/test_sod_class_loader_integration.lua
```

The source audit must report the pinned commit match, a green DBC quick check, all 20 source packages, and zero unresolved executable references. A source refresh is not complete until the commit, DBC path/hash, action-map manifest, and focused audit output are updated together.

## Ownership and Non-Goals

- `classes/*/*_sod.lua`: native rotation priorities and role-specific state.
- `shared/class_loader_sylvanas.lua`: the nine-class, 20-entry SoD manifest and exclusive SoD module loading.
- `main.lua` and `main_sylvanas.lua`: mode selection, schema injection, and phase/rune context normalization.
- `.omo/evidence/task-1-sod-action-map.jsonl` and `.omo/evidence/task-1-sod-action-map-manifest.json`: pinned source/action-ID evidence.
- `wowheadScrape/dbc_extract/wowsims.db`: local client/DBC input for validation; do not edit API stubs or fabricate missing IDs.

This documentation does not authorize edits to `api/`, `.api/`, reference-system clones, the pinned source checkout, tests, or unrelated expansion rotations. It also does not claim live-client support for a phase, rune, class, or role that is absent from the 20-entry manifest.
