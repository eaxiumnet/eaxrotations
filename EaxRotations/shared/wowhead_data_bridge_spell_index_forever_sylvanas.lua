-- wowhead_data_bridge_spell_index_forever_sylvanas.lua -- Forever-era spell index (STUB).
-- WHAT:  placeholder bridge for the WoW Forever era (beta 2026-09-17).
-- WHEN:  required by tests/run_forever_audit_tests.lua and by _forever spec
--        files, which resolve Forever-new spells BY NAME (never by guessed
--        ID) via spell_index_by_name_forever until the beta DBC lands.
-- WHY:   the forever audit must load cleanly on a tracked file (clean-checkout
--        probe rule) BEFORE the beta client exists; the real index replaces
--        this stub the day the Forever DBC is extracted
--        (docs/forever/dbc_runbook.md).
-- SAFETY: pure data table; empty index keeps the audit in scaffold mode
--         (scanner self-test only) — never claim spell knowledge we lack.

local M = {}

-- True while the real DBC-derived index has not been generated. The audit
-- asserts on this flag: with it set, only scanner self-tests run; with it
-- absent, the audit enforces the full _forever-file spell-ID scan.
M.__forever_stub = true

-- id -> { name = "...", ... } once generated from the Forever client DBC.
M.spell_index_forever = {}

-- name -> spell_id mirror of spell_index_forever (generated alongside it by
-- tools/build_forever_bridge.py). Spec files look up Forever-new spells by
-- their EXACT client name; a nil lookup must leave the lane dormant —
-- resolve_names() callers skip the lane rather than guess an ID.
M.spell_index_by_name_forever = {}

return M
