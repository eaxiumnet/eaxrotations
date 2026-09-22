-- What: shared/objective_match.lua — which mob a goal is really about, and whether a unit is it.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Live: on the guide's step `kill Rock Elemental##92+` / `collect 3 Large Stone Slab##4627
--      |q 711/1`, the bot killed LESSER Rock Elementals. The cMaNGOS creature_loot_template has
--      item 4627 under creature 92 "Rock Elemental" and nothing else, and 2735 "Lesser Rock
--      Elemental" is a different, weaker, nearer mob — the guide's own `##92` is the identity that
--      distinguishes them. The plugin dropped that id (it read goal.npc_id/goal.target_id, and
--      `goal.npc_id or goal.target_id` returns 0 whenever the bridge leaves npc_id at 0 — 0 is
--      truthy in Lua) and matched the pluralised name with a substring test, which "Lesser Rock
--      Elemental" satisfies because it contains "Rock Elemental". Each scenario here pins one rule
--      of the replacement:
--        O1 the id decides: the wrong id is never the objective, whatever the unit is called
--        O2 every spelling of the id is read, and a multi-target goal contributes all of its ids
--        O3 with no id the name decides, and it is the WHOLE name (Lesser is not Rock)
--        O4 a unit that cannot be asked for its id still resolves by whole name
--        O5 only() keeps the objective, in place, and says "none" as nil
--        O6 a shared name family is not a shared objective (Greater is not Rock either)
-- Safety: pure module + stubs; no client, no network, no file writes.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local objective_match = require("shared/objective_match")

-- ============================================================================
-- Fixtures — the real entries from this objective
-- ============================================================================

local ROCK = 92             -- "Rock Elemental", level 39-40, drops Large Stone Slab (4627)
local LESSER = 2735         -- "Lesser Rock Elemental", level 37-39, drops nothing of the sort
local GREATER = 2736        -- "Greater Rock Elemental", level 42-44, a different mob again

--- A unit, as the client exposes it: a name and an NPC id.
local function unit(name, npc_id)
    return {
        get_name = function() return name end,
        get_npc_id = function() return npc_id end,
    }
end

--- A unit that cannot answer get_npc_id at all (a game object, or an API failure).
local function nameless_id_unit(name)
    return {
        get_name = function() return name end,
        get_npc_id = function() error("no id") end,
    }
end

-- Zygor's raw shape for `kill Rock Elemental##92+`, as Goal.lua parses it: the trailing '+' marks
-- the name plural, so target is "Rock Elementals" while the id stays 92.
local STEP_GOAL = { action = "kill", target = "Rock Elementals", targetid = ROCK }

-- ============================================================================
-- O1 — the id decides
-- ============================================================================
do
    assert(objective_match.is_objective(STEP_GOAL, unit("Rock Elemental", ROCK)) == true,
        "O1a FAIL: the mob the goal names must be its objective")
    assert(objective_match.is_objective(STEP_GOAL, unit("Lesser Rock Elemental", LESSER)) == false,
        "O1b FAIL: a different id is a different mob, whatever it is called")
    -- The name is a decoy: id 2735 renamed to the goal's name is still not the objective.
    assert(objective_match.is_objective(STEP_GOAL, unit("Rock Elemental", LESSER)) == false,
        "O1c FAIL: the id is the identity, not the name")
    assert(objective_match.goal_id(STEP_GOAL) == ROCK,
        "O1d FAIL: goal_id must read Zygor's targetid, got " ..
        tostring(objective_match.goal_id(STEP_GOAL)))
    print("  O1 PASS: the goal's id decides — the Lesser Rock Elemental is not the objective")
end

-- ============================================================================
-- O2 — every spelling of the id, and multi-target goals carry all of theirs
-- ============================================================================
do
    local spellings = {
        { action = "kill", targetid = ROCK },
        { action = "kill", target_id = ROCK },
        { action = "kill", npc_id = ROCK },
        { action = "kill", id = ROCK },
    }
    for i = 1, #spellings do
        assert(objective_match.goal_id(spellings[i]) == ROCK,
            "O2a FAIL: id spelling " .. tostring(i) .. " not read")
        assert(objective_match.is_objective(spellings[i], unit("Lesser Rock Elemental", LESSER)) == false,
            "O2b FAIL: id spelling " .. tostring(i) .. " must still reject the Lesser mob")
    end

    -- The bridge's own shape: npc_id present but ZERO, the id in target_id. `npc_id or target_id`
    -- returns 0 here (0 is truthy in Lua) — the defect this module exists to remove.
    local zero_npc = { action = "kill", target = "Rock Elementals", npc_id = 0, target_id = ROCK }
    assert(objective_match.goal_id(zero_npc) == ROCK,
        "O2c FAIL: a zero npc_id must not hide target_id, got " ..
        tostring(objective_match.goal_id(zero_npc)))

    -- The shards step: `kill Lesser Rock Elemental##2735, Rock Elemental##92` — Zygor keeps the
    -- pairs in goal.targets, and both mobs are the objective.
    local both = {
        action = "kill",
        target = "Lesser Rock Elemental, Rock Elemental",
        targetid = LESSER,
        targets = { { "Lesser Rock Elemental", LESSER }, { "Rock Elemental", ROCK } },
    }
    assert(objective_match.is_objective(both, unit("Lesser Rock Elemental", LESSER)) == true,
        "O2d FAIL: the first of a multi-target goal must be its objective")
    assert(objective_match.is_objective(both, unit("Rock Elemental", ROCK)) == true,
        "O2e FAIL: the second of a multi-target goal must be its objective too")
    assert(objective_match.is_objective(both, unit("Greater Rock Elemental", GREATER)) == false,
        "O2f FAIL: a mob the goal does not name is not its objective")
    print("  O2 PASS: one id or several, in every spelling the bridge and the addon use")
end

-- ============================================================================
-- O3 — with no id, the name decides, as a whole name
-- ============================================================================
do
    local name_only = { action = "kill", target = "Rock Elementals" }      -- no id at all
    assert(objective_match.is_objective(name_only, unit("Rock Elemental", 0)) == true,
        "O3a FAIL: the singular world name must satisfy the plural goal name")
    assert(objective_match.is_objective(name_only, unit("Lesser Rock Elemental", 0)) == false,
        "O3b FAIL: 'Lesser Rock Elemental' is not 'Rock Elemental' — a substring is not a name")
    assert(objective_match.is_objective(name_only, unit("Greater Rock Elemental", 0)) == false,
        "O3c FAIL: 'Greater Rock Elemental' is not 'Rock Elemental' either")
    -- Case does not matter; the goal's plural does not need to match the world's singular exactly.
    assert(objective_match.is_objective(name_only, unit("ROCK ELEMENTAL", 0)) == true,
        "O3d FAIL: names compare case-insensitively")
    -- A comma-listed goal (the live goal[34] shape) matches each of its names.
    local listed = { action = "kill", target = "Stonevault Shaman,  Stonevault Bonesnapper" }
    assert(objective_match.is_objective(listed, unit("Stonevault Bonesnapper", 0)) == true,
        "O3e FAIL: every name in a comma-listed target must match")
    print("  O3 PASS: without an id the whole name decides, never a substring")
end

-- ============================================================================
-- O4 — a unit that cannot be asked for its id still resolves by whole name
-- ============================================================================
do
    -- An id-carrying goal, a unit that cannot answer get_npc_id: the name is the only evidence.
    assert(objective_match.is_objective(STEP_GOAL, nameless_id_unit("Rock Elemental")) == true,
        "O4a FAIL: a unit without an id must fall back to its name")
    assert(objective_match.is_objective(STEP_GOAL, nameless_id_unit("Lesser Rock Elemental")) == false,
        "O4b FAIL: the whole-name rule applies to the fallback too")
    -- A quest object with a loose name still resolves: the guide's plural against the world's.
    local obj_goal = { action = "get", target = "Bundles of Wood" }
    assert(objective_match.is_objective(obj_goal, nameless_id_unit("Bundle of Wood")) == true,
        "O4c FAIL: a plural goal name must resolve its singular world object")
    assert(objective_match.goal_id(obj_goal) == nil,
        "O4d FAIL: a goal with no id must report none")
    print("  O4 PASS: units and objects without an id are decided by whole name")
end

-- ============================================================================
-- O5 — only() keeps the objective, in place, and says "none" as nil
-- ============================================================================
do
    local lesser = unit("Lesser Rock Elemental", LESSER)
    local rock = unit("Rock Elemental", ROCK)
    local greater = unit("Greater Rock Elemental", GREATER)

    local list = { lesser, rock, greater }
    local kept = objective_match.only(STEP_GOAL, list)
    assert(#kept == 1 and kept[1] == rock,
        "O5a FAIL: only() must keep exactly the goal's mob, got " .. tostring(#kept))
    assert(#list == 3 and list[1] == lesser,
        "O5b FAIL: only() must not write to the list it was given")

    -- A list that is already all matches is handed back as it is (the common case: no copy, so a
    -- per-tick caller allocates nothing).
    local all = { rock, unit("Rock Elemental", ROCK) }
    local before = #all
    assert(objective_match.only(STEP_GOAL, all) == all and #all == before,
        "O5c FAIL: an all-matching list must be returned as it is")

    -- Nothing matches: nil, the same shape the manager uses for "found nothing".
    assert(objective_match.only(STEP_GOAL, { lesser, greater }) == nil,
        "O5d FAIL: a list with no objective in it must answer nil")
    assert(objective_match.only(STEP_GOAL, nil) == nil,
        "O5e FAIL: a nil list must answer nil")
    assert(objective_match.only(STEP_GOAL, {}) == nil,
        "O5f FAIL: an empty list must answer nil")
    print("  O5 PASS: only() keeps the objective in place and answers nil when there is none")
end

-- ============================================================================
-- O6 — a shared name family is not a shared objective
-- ============================================================================
do
    -- Every Rock Elemental variant is called a Rock Elemental; only 92 is this objective. The id
    -- is the only thing that separates them, which is why the id must come first.
    local variants = {
        { "Lesser Rock Elemental", LESSER },
        { "Enraged Rock Elemental", 2791 },
        { "Greater Rock Elemental", GREATER },
    }
    for i = 1, #variants do
        assert(objective_match.is_objective(STEP_GOAL, unit(variants[i][1], variants[i][2])) == false,
            "O6 FAIL: " .. variants[i][1] .. " must not satisfy the Rock Elemental objective")
    end
    -- And the id list does not leak across goals: the shards goal accepts the Lesser one that the
    -- slab goal rejected.
    local shards = {
        action = "kill",
        target = "Lesser Rock Elemental, Rock Elemental",
        targets = { { "Lesser Rock Elemental", LESSER }, { "Rock Elemental", ROCK } },
    }
    assert(objective_match.is_objective(shards, unit("Lesser Rock Elemental", LESSER)) == true,
        "O6b FAIL: the other goal's ids must not leak into this decision")
    assert(objective_match.goal_id(STEP_GOAL) == ROCK,
        "O6c FAIL: asking about a second goal must not disturb the first")
    print("  O6 PASS: the id list belongs to the goal it was read from")
end

print("PASS test_objective_match")
os.exit(0)
