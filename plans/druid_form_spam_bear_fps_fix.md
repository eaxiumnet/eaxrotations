# Fix: Druid Travel Form Spam + Bear FPS Drop/Crash

## Issues
1. **Cat spec rapid Travel↔Cat form switching loop when OOC** — `travel_form_matches` lacks "already in travel form" guard
2. **Bear spec FPS drop / crash on form switch** — middleware enemy scans every frame, `build_state` rebuilt per strategy match function, `scan_pack` over-frequent

## Changes

### cat_sylvanas.lua
- Add `NS.has_form("travel")` guard to `travel_form_matches`
- Add shared `last_form_shift_time` throttle (2s cooldown between any form switches)
- Cache `build_state` by timestamp (once per frame max)

### bear_sylvanas.lua
- Cache `build_state` by timestamp (once per frame max)
- Reduce `scan_pack` frequency from 0.2s to 0.5s

### middleware_sylvanas.lua
- Throttle `DruidCCBreak` enemy scan to 0.3s intervals
- Cache `is_rooted_or_snared` result with 0.2s TTL
- Add `last_form_shift_time` gate to prevent rapid middleware form shifts

## Validation
- `luac -p` on all 3 files ✅
- `lua EaxRotations/tests/run_rotation_tests.lua` — all 171 suites ✅
- `lua EaxRotations/tests/run_leveling_tests.lua` — all 11 suites ✅
