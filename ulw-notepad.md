# Ultrawork Notepad — Expansion-aware leveling gate
Started: 2026-05-28T02.31.13

## Plan
Phase 1 MVP: add expansion helpers, fix leveling gate from hardcoded 70.

## Scenarios
1. Classic level 60 → not leveling (was broken: treated as leveling because <70)
2. Classic level 59 → still leveling
3. TBC level 69 → still leveling
4. TBC level 70 → not leveling
5. Unknown version default → 70 (TBC safe)

## Now
Task 1: Write RED test first.

## Todo
- [] 1. Write test_expansion_helpers.lua (RED)
- [] 2. Add NS helpers in core_sylvanas.lua
- [] 3. Fix leveling gate in main_sylvanas.lua
- [] 4. Wire tests
- [] 5. Verify syntax + all tests

## Findings
- core_sylvanas.lua:38-55 already caches _cached_game_version
- main_sylvanas.lua:254-266 hardcodes player_level < 70
- test_context_completeness.lua:108-110 asserts below-70 leveling

## Learnings

## RED Evidence (2026-05-28)
lua EaxRotations/tests/test_expansion_helpers.lua
ERROR: NS.get_expansion_max_level should exist
Line 36: assert_true(type(core_mod.get_expansion_max_level) == 'function')
-> Helper missing. Correct RED.


## GREEN Evidence (2026-05-28)
lua EaxRotations/tests/test_expansion_helpers.lua
PASS expansion_helpers
-> All helpers correct. TBC=70, Vanilla=60, unknown=70.

