# wowsims APL fixtures — provenance manifest

Pinned reference APL JSONs used by `shared/apl_parser.lua` and
`tests/test_apl_conformance.lua` (Phase 2 APL conformance).

| Local fixture | Upstream source | Commit |
|---|---|---|
| `fire_wotlk.apl.json` | `wowsims/wotlk` `ui/mage/apls/fire.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `affliction_wotlk.apl.json` | `wowsims/wotlk` `ui/warlock/apls/affliction.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `feralcat_wotlk.apl.json` | `wowsims/wotlk` `ui/feral_druid/apls/default.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |

- **Repo:** github.com/wowsims/wotlk, branch `master`.
- **Commit:** `563e4a08cb15729f1fdcbcf68e6d68224553bfef` (2025-12-22).
- **Fetched:** 2026-08-09 via the GitHub raw endpoint.
- **Format:** wowsims `TypeAPL` JSON (`priorityList` of actions).
- **Update policy:** re-fetch only on an intentional conformance re-baseline;
  update this table + the commit ref in `shared/apl_parser.lua` together.

## Why feralcat is special

`ui/feral_druid/apls/default.apl.json` delegates the rotation to the Go
`catOptimalRotationAction` black box — the JSON carries only prepull actions and
one `catOptimalRotationAction` node, no steady-state spell list. The reference
order for feral cat is therefore pinned **from the Go source** at the same
commit, `sim/druid/feral/rotation.go` → `doRotation()` dispatch order:

```
FaerieFireFeral  (ffNow)
SavageRoar       (roarNow)
Rip              (ripNow)
FerociousBite    (biteNow)
MangleCat        (mangleNow)
Rake             (rakeNow)
Shred            (filler)
```

(`Berserk` is a CD handled outside the loop; `Ravage` is a stealth opener only.)

The pin lives in `tests/test_apl_conformance.lua` with the Go dispatch-order
comment; the JSON fixture is still tracked so the loader path stays uniform.
