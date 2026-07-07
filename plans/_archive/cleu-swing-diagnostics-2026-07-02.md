# CLEU Swing Diagnostics & Event-Driven Snap Threat

**Date:** 2026-07-02  
**Scope:** Retribution Paladin swing diagnostics, Protection Paladin snap threat, seal cast confirmation  
**Rationale:** `core.register_on_game_event_callback` exposes raw `COMBAT_LOG_EVENT_UNFILTERED` — gives exact server swing timestamps and instant combat-start detection, eliminating timer drift and frame-polling latency.

## Deliverables

1. **`shared/swing_diagnostics_sylvanas.lua`** (NEW)
   - Registers `register_on_game_event_callback` for `COMBAT_LOG_EVENT_UNFILTERED`
   - Tracks `SWING_DAMAGE` / `SWING_MISSED` for exact swing timestamps
   - Tracks `SPELL_CAST_SUCCESS` for seal cast confirmation
   - Categorizes twists: PERFECT / LATE / NO-TWIST / PHANTOM
   - Exposes API consumed by retribution_sylvanas.lua

2. **`shared/snap_threat_sylvanas.lua`** (MODIFY)
   - Add CLEU `PLAYER_REGEN_DISABLED` listener for instant snap threat
   - Prevent double-fire with frame-based fallback

3. **`classes/paladin/retribution_sylvanas.lua`** (MODIFY)
   - Consume `NS.SwingDiagnostics` for CLEU swing data
   - Use seal cast confirmation to avoid ghost-buff false positives
   - Populate `state.cleu_swing_remains` for more accurate twist window

4. **`classes/paladin/protection_sylvanas.lua`** (MODIFY)
   - Wire `PLAYER_REGEN_DISABLED` snap threat path

5. **Tests** (NEW)
   - `test_swing_diagnostics.lua` — unit tests for the shared module

## Safety
- Graceful fallback if `register_on_game_event_callback` unavailable
- `luac -p` on all modified files
- `lua EaxRotations/tests/run_rotation_tests.lua` — all 214 must pass
