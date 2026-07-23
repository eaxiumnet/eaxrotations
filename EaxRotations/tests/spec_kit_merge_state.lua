-- spec_kit_merge_state.lua -- canonical merge_state for test mocks.
-- WHAT:  Provides the same merge_state behavior as shared/spec_kit_sylvanas
--        so test mocks that stub spec_kit can include it without duplicating
--        the implementation in every test file.
-- WHEN:  Used by any test that mocks shared/spec_kit_sylvanas.
-- WHY:   Keeps the merge_state implementation in one place while allowing
--        each test to keep its own safe_state/setting overrides.
-- SAFETY: No external dependencies; pure Lua helper.

local M = {}

-- Builds a fresh state from context, then layers an optional caller-provided
-- state override on top. The returned table keeps the safe_state schema
-- default-fallback (__index) but isolates writes so match functions cannot
-- mutate the shared raw_state table.
function M.merge_state(build_state, context, state_override)
    local s = build_state(context)
    if not state_override or next(state_override) == nil then return s end
    local merged = {}
    for k, v in pairs(s) do merged[k] = v end
    for k, v in pairs(state_override) do merged[k] = v end
    local mt = getmetatable(s)
    if mt then
        local mt_copy = {}
        for k, v in pairs(mt) do mt_copy[k] = v end
        mt_copy.__newindex = nil
        setmetatable(merged, mt_copy)
    end
    return merged
end

return M
