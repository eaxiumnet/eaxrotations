-- Decision notes:
--   Shared helpers stay pure or dependency-injected where practical so class files can reuse them safely.
--   Inputs are plain tables/numbers instead of live game objects unless a caller explicitly passes adapters.
--   Keeping this logic outside playstyles makes edge cases testable without a Sylvanas runtime.

-- Readability notes:
--   What: compatibility require for Mind Flay tick computation.
--   When: code asks for the Sylvanas-suffixed helper name.
--   Why: keeps one implementation for channel tick math while preserving require paths.
--   Safety: no API calls occur in this wrapper.
return require("shared/mf_tick_compute")
