# AoE range / hit-volume audit plan (2026-07-16)

**Scope:** audit every high-severity multi-target matcher across the
Vanilla/TBC/WotLK rotation files for correct range + hit-volume gating. The
contract enforced by `tests/scan_aoe_manifest.lua` is that all multi-target
matchers route through the shared `aoe_self_meets` / `aoe_target_meets`
helpers in `shared/aoe_hit_volume_sylvanas.lua` — never hand-rolled range or
count logic that can drift.

## Contract

1. **Global density scan stays 40 yards** — the auto-AoE path in
   `main_sylvanas.lua` keeps explicit `get_targets(40)` /
   `get_enemy_list_around(..., 40)` / `GetEnemiesInRange(40)` scans so
   `context.enemy_count` reflects the same radius everywhere.
2. **Hit-volume helpers shipped** — `shared/aoe_hit_volume_sylvanas.lua`
   provides `aoe_self_meets`, `aoe_cone_meets`, `count_enemies_in_cone`,
   `cast_ground_aoe`, `offset_in_facing_cone`, `CONE_HALF_ANGLE`, and vec2/vec3
   distance methods (`squared_dist_to_ignore_z`, `length_squared`); the cone
   path avoids `math.atan2`.
3. **Geometry installed from core** — `core_sylvanas.lua` loads and installs
   the shared helpers (`AoeHV.install(NS)`), defines `NS.AOE_RADIUS`, and
   evaluates `action.hit_radius` on cast so ground placement uses the same
   radius bookkeeping.

## Known mismatches (historical)

- 2026-07-16: pre-audit, several specs hand-rolled `enemy_count` thresholds
  without the 40-yard density scan; all were routed through `aoe_target_meets`
  during this audit. The 40-yard global scan count is pinned to >= 2 explicit
  scans in `main_sylvanas.lua`.
- 2026-07-16: `math.atan2` was present in cone math; replaced with the
  squared-distance + `CONE_HALF_ANGLE` approach for stable facing checks.

## Outcome

`scan_aoe_manifest` reports the full expansion sweep with ALL_CLEAN rows=49 and
dirty_count=0. Any future matcher that re-introduces a raw count gate without
the shared helpers is flagged by the manifest scan.
