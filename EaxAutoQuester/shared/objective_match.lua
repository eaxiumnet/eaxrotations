-- shared/objective_match.lua — the mob a goal is really about, and whether a unit is it.
-- WHAT:  mob_ids(goal) -> the goal's NPC ids; goal_id(goal) -> the first one; is_objective(goal, unit)
--        -> is this unit the goal's objective. Ids first, whole-name second, never similarity.
-- WHEN:  every "is my objective here?" decision: idle_state's objective scan and its respawn wait,
--        do_action_state's kill targeting, spawn_patrol's spawn-point resolution.
-- WHY:   The guide's step for `collect 3 Large Stone Slab##4627 |q 711/1` is
--        `kill Rock Elemental##92+`, and 92 is the only creature that drops the slab — the
--        cMaNGOS creature_loot_template lists item 4627 under creature 92 "Rock Elemental" and
--        under nothing else. The plugin discarded the id (it read goal.npc_id / goal.target_id,
--        while Zygor's own field is `targetid`, and a multi-target goal keeps its `{name, id}`
--        pairs in goal.targets) and matched the pluralised name ("Rock Elementals") with a
--        substring test. "Lesser Rock Elemental" contains "Rock Elemental", so the bot pulled the
--        level 37-39 Lesser ones — nearer, weaker, and not one of them drops the item — and the
--        objective never advanced. Identity, not similarity.
-- SAFETY: pure reads, no writes to game state. The id list is one reused table (like
--        goal_names.expand's result) and the name comparison walks bytes without lowercasing, so
--        the per-tick callers allocate nothing. Every unit probe is pcall-guarded: a unit that
--        cannot be asked for its id is decided by name, not by assumption.
-- DECISION: when the goal carries an id, an id is the ONLY test for a unit that has an id — a unit
--        named "Lesser Rock Elemental" must never satisfy a goal for "Rock Elemental", and a mob
--        the goal does not name must not be killed just because it is nearby. Names are compared
--        as WHOLE names (case-insensitively) for units whose id is unavailable and for goals that
--        carry no id at all (quest objects, name-only goals), which is where similarity was only
--        ever a guess.
-- NOTE:   The id fields are probed in the spellings the bridge and the addon use — npc_id,
--        target_id, targetid, id — because the plugin has never been able to read Zygor's raw
--        goal table and a single spelling would silently be zero again.

local M = {}

-- ============================================================================
-- The goal's NPC ids — one reused table, rebuilt only when the goal changes
-- ============================================================================

local MAX_IDS = 8          -- a multi-target kill goal names a handful of mobs, not a camp

local _ids = {}
local _ids_n = 0
local _ids_goal = nil

--- Add one candidate id, ignoring anything that is not a positive integer. No allocation.
local function add_id(raw)
    if type(raw) ~= "number" or raw <= 0 or raw ~= math.floor(raw) then return end
    for i = 1, _ids_n do
        if _ids[i] == raw then return end
    end
    if _ids_n >= MAX_IDS then return end
    _ids_n = _ids_n + 1
    _ids[_ids_n] = raw
end

--- Zygor's multi-target goals keep every `Name##Id` pair (an array of { name, id }). Older and
--- newer shapes carry the id under different keys, so every spelling is accepted.
local function add_pairs(list)
    if type(list) ~= "table" then return end
    for i = 1, #list do
        local entry = list[i]
        if type(entry) == "table" then
            add_id(entry[2])            -- Zygor's targets shape: { name, id }
            add_id(entry.id)
            add_id(entry.npcid)
            add_id(entry.npc_id)
        end
    end
end

--- The goal's NPC ids, as a reused array. Do not hold on to the table: the next goal replaces it.
--- @param goal table|nil A Zygor goal
--- @return table ids, number count
function M.mob_ids(goal)
    if goal ~= _ids_goal then
        _ids_goal = goal
        _ids_n = 0
        if type(goal) == "table" then
            add_id(goal.npc_id)
            add_id(goal.target_id)
            add_id(goal.targetid)
            add_id(goal.id)
            add_pairs(goal.targets)
            add_pairs(goal.mobs)
        end
    end
    return _ids, _ids_n
end

--- The goal's primary NPC id, or nil. The common case, without touching the id table.
--- @param goal table|nil
--- @return number|nil
function M.goal_id(goal)
    local _, n = M.mob_ids(goal)
    if n == 0 then return nil end
    return _ids[1]
end

-- ============================================================================
-- Unit identity
-- ============================================================================

-- Hoisted: the tick path must not build closures per unit (see tests/test_tick_allocation.lua).
local function unit_npc_id(u) return u:get_npc_id() end

--- A unit's NPC id, or nil when it cannot be asked (a game object, a mock, an API failure).
--- @param unit game_object|nil
--- @return number|nil
function M.unit_id(unit)
    if not unit then return nil end
    local ok, id = pcall(unit_npc_id, unit)
    if ok and type(id) == "number" and id > 0 and id == math.floor(id) then return id end
    return nil
end

-- ============================================================================
-- Names — the fallback, compared as whole names
-- ============================================================================

--- Case-insensitive equality without allocating a lowercase copy of either string.
--- ASCII case folding: unit names in this client are ASCII.
local function same_name(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    local n = #a
    if n == 0 or n ~= #b then return false end
    for i = 1, n do
        local ca, cb = a:byte(i), b:byte(i)
        if ca ~= cb then
            if ca >= 65 and ca <= 90 then ca = ca + 32 end
            if cb >= 65 and cb <= 90 then cb = cb + 32 end
            if ca ~= cb then return false end
        end
    end
    return true
end

--- The names a goal's target string stands for (shared/goal_names.lua owns that translation).
--- @param goal table|nil
--- @return string[] names (shared table: do not mutate)
local function goal_names_for(goal)
    if type(goal) ~= "table" then return nil end
    local target = goal.target or goal.npc or goal.name
    if type(target) ~= "string" or target == "" then return nil end
    local goal_names = package.loaded["shared/goal_names"]
    if not goal_names then
        local ok, mod = pcall(require, "shared/goal_names")
        if ok then goal_names = mod end
    end
    if not goal_names then return nil end
    return goal_names.expand(target)
end

--- Is this unit's name one of the names the goal stands for? Whole-name, case-insensitive.
--- @param goal table|nil
--- @param unit game_object
--- @return boolean
function M.name_is_objective(goal, unit)
    local names = goal_names_for(goal)
    if not names then return false end
    local ok, world_name = pcall(function() return unit:get_name() end)
    if not ok or type(world_name) ~= "string" then return false end
    for i = 1, #names do
        if same_name(world_name, names[i]) then return true end
    end
    return false
end

-- ============================================================================
-- The decision
-- ============================================================================

--- Is this unit the objective of this goal?
--- Ids decide whenever both sides have one; otherwise the name does, as a whole name.
--- @param goal table|nil
--- @param unit game_object|nil
--- @return boolean
function M.is_objective(goal, unit)
    if type(goal) ~= "table" or not unit then return false end

    local _, goal_count = M.mob_ids(goal)
    if goal_count > 0 then
        local id = M.unit_id(unit)
        if id then
            for i = 1, goal_count do
                if _ids[i] == id then return true end
            end
            -- The goal names its mobs by id: a different id is a different mob, whatever it is
            -- called. This is the check that keeps "Lesser Rock Elemental" out of a
            -- "Rock Elemental" objective.
            return false
        end
    end

    return M.name_is_objective(goal, unit)
end

--- Keep only the goal's own units.
--- A list that is already all matches is handed back as it is — the common case, and the reason a
--- per-tick caller allocates nothing. Only a list that has to lose something is copied, and the
--- caller's table is never written to (callers pass the manager's fresh list, but a stub or a
--- second caller may pass a list it still needs).
--- A nil or empty list, or one with no objective in it, comes back as nil — the same shape the
--- manager uses for "found nothing".
--- @param goal table|nil
--- @param objects table[]|nil Units the manager matched by name
--- @return table[]|nil The goal's own units, or nil when there are none
function M.only(goal, objects)
    if type(objects) ~= "table" then return nil end
    local n = #objects
    if n == 0 then return nil end

    local first_out = nil
    for i = 1, n do
        if not M.is_objective(goal, objects[i]) then
            first_out = i
            break
        end
    end
    if not first_out then return objects end

    local kept = {}
    for i = 1, first_out - 1 do
        kept[i] = objects[i]
    end
    for i = first_out + 1, n do
        if M.is_objective(goal, objects[i]) then
            kept[#kept + 1] = objects[i]
        end
    end
    if #kept == 0 then return nil end
    return kept
end

return M
