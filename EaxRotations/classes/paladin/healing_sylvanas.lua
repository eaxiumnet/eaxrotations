-- ============================================================================
-- What: Compatibility wrapper for the Paladin healing helper.
-- When: Load time.
-- Why: Preserve the legacy import path without duplicating logic.
-- Safety: Single require; returns cleanly if the helper is unavailable.
-- ============================================================================
return require("classes/paladin/heal_helper_sylvanas")
