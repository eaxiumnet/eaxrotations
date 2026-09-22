-- shared/goal_names.lua — the world names a Zygor goal target string stands for.
-- WHAT:  expand("Stonevault Shaman,  Stonevault Bonesnapper") -> the comma-separated names, each
--        with the plural variants Zygor writes ("Lesser Rock Elementals") mapped to the singular
--        names the world units carry ("Lesser Rock Elemental"). matches() is the case-insensitive
--        substring test callers do against a unit's name.
-- WHEN:  everywhere the bot asks "is my objective here?" — idle_state's objective-first scan and
--        its respawn wait, do_action_state's area name scan, spawn_patrol's NPC-id resolution.
-- WHY:   Zygor's goal targets are human strings: comma-separated for multi-mob objectives and
--        pluralized while the spawned units are singular. That translation was copy-pasted into
--        two state files; the respawn search needed the same answer from a third caller, and a
--        third copy of a pluralizer is a third chance for them to disagree about what the
--        objective is called.
-- SAFETY: pure string work on a caller-supplied string; nil/empty in -> empty list out. Results
--        are cached per input string and returned as the SAME table, so a caller on the per-tick
--        path (a goal's target string does not change while the step does) allocates nothing.
-- DECISION: shared module rather than a per-caller helper. Callers must treat the returned list
--        as read-only: it is shared state, not a per-call copy.
-- NOTE:   Expansion is deliberately literal, matching what the two state files did — split on
--        commas, trim, then add (a) the first word with a trailing 's' stripped and (b) the whole
--        string with a trailing 's' stripped. It is a name-guessing heuristic, not grammar.

local M = {}

-- Empty result for nil/empty input. One shared table: callers only iterate.
local EMPTY = {}

-- Cache of expansion per target string. Goals change at most once per step, so this stays tiny;
-- the cap exists so a pathological caller cannot grow it without bound.
local MAX_CACHE = 64
local _cache = {}
local _cache_count = 0

local function expand_uncached(target)
    local names = {}
    for name in target:gmatch("[^,]+") do
        local trimmed = name:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            names[#names + 1] = trimmed
        end
    end

    -- Variants are appended while iterating only the comma-separated originals above, so a variant
    -- can never be expanded again (which would produce "Rock Elemental" -> "Rock Elementa").
    local base_count = #names
    for i = 1, base_count do
        local name = names[i]
        local first_word = name:match("^(%S+)")
        if first_word and first_word:sub(-1) == "s" then
            names[#names + 1] = name:gsub("^" .. first_word, first_word:sub(1, -2), 1)
        end
        if name:sub(-1) == "s" then
            local singular = name:sub(1, -2)
            if singular ~= "" then
                names[#names + 1] = singular
            end
        end
    end

    return names
end

--- The names a goal target string stands for. The returned table is shared: do not mutate it.
--- @param target string|nil Zygor goal target ("Lesser Rock Elementals")
--- @return string[] Names to try, or an empty list
function M.expand(target)
    if not target or target == "" then return EMPTY end
    local cached = _cache[target]
    if cached then return cached end

    local names = expand_uncached(target)
    if _cache_count >= MAX_CACHE then
        _cache = {}
        _cache_count = 0
    end
    _cache[target] = names
    _cache_count = _cache_count + 1
    return names
end

--- Does a unit's name match any of these? Case-insensitive substring, which is how the callers
--- have always matched (a goal target is "a" name, the world name carries suffixes).
--- Allocates once, for the lowercasing — call it from throttled scans, not every tick.
--- @param world_name string|nil A unit's get_name()
--- @param names string[] From M.expand()
--- @return boolean
function M.matches(world_name, names)
    if not world_name or not names then return false end
    local lower = world_name:lower()
    for i = 1, #names do
        local candidate = names[i]:lower()
        if candidate ~= "" and lower:find(candidate, 1, true) then return true end
    end
    return false
end

--- Drop the cache. Only for tests that need a cold start; production never calls it.
function M.clear_cache()
    _cache = {}
    _cache_count = 0
end

return M
