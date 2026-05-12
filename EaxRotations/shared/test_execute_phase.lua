-- Decision notes:
--   Tests use local stubs instead of a live Sylvanas client so API-bound behavior remains reproducible.
--   Each case protects one previous failure mode or role rule; keep assertions narrow and descriptive.
--   No test should call real input/cast APIs because regression runs must be safe outside the game.

-- Readability notes:
--   What: compatibility launcher for the execute-phase test.
--   When: older workflows run tests from the shared folder.
--   Why: avoids duplicate tests while preserving a familiar entry point.
--   Safety: delegates to the canonical test file.
return dofile('EaxRotations/tests/test_execute_phase.lua')
