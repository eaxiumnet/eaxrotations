-- test_mage_leveling_forever.lua -- unit pins for the mage leveling Forever delta.
-- WHAT:  leveling_forever.lua contract: baseline capture + re-register splice
--        (the Hot Streak spend above Fireball), the buff presence gate, the
--        3-stack cap (with the fail-open 0/nil read), the leveling fire-nuke
--        gates (target, combat, movement, mana floor), dormancy, mirror
--        selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Hot Streak without the stack gate throws the cast-cut window away
--        early; without the fail-open read a degraded aura API would stall
--        the finisher.
-- SAFETY: fully mocked NS + require (fake baseline module).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local pass, fail = 0, 0
local function assert_true(v, label)
    if v then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. tostring(label)) end
end
local function assert_eq(a, b, label)
    if a == b then pass = pass + 1
    else fail = fail + 1; print("  FAIL: " .. tostring(label) .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")") end
end

local registered = nil
local cast_log = {}
local hs_up = false
local hs_stacks = 0
local HS = 19160
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = { name = "me" },
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    MageSpells = {
        Pyroblast = { ids = { 33938, 18809, 12505 }, name = "Pyroblast" },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    has_player_buff = function(id) return hs_up and id == HS end,
    buff_stacks = function(unit, ids) return hs_stacks end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "leveling",
    strategies = {
        { name = "FrostArmor", matches = function() return false end, execute = function() return false end },
        { name = "FireBlast", matches = function() return false end, execute = function() return false end },
        { name = "Fireball", matches = function() return false end, execute = function() return false end },
        { name = "Frostbolt", matches = function() return false end, execute = function() return false end },
        { name = "Scorch", matches = function() return false end, execute = function() return false end },
        { name = "Wand", matches = function() return false end, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
local pending_by_name, pending_maxrank, pending_buff = {}, {}, {}
function require(path)
    if path == "shared/wowhead_data_bridge_spell_index_forever_sylvanas" then
        return { spell_index_by_name_forever = pending_by_name,
                 spell_maxrank_by_name_forever = pending_maxrank,
                 spell_buff_by_name_forever = pending_buff }
    end
    if path == "classes/mage/leveling_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/mage/leveling_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/mage/leveling_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function fresh_ctx(overrides)
    local ctx = { is_leveling = true, in_combat = true, target = { name = "enemy" },
                  has_valid_enemy_target = true, me = {}, settings = {} }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function fresh_state(overrides)
    local s = {
        in_combat = true,
        target = { name = "enemy" },
        is_moving = false,
        mana_pct = 80,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local MIRRORS = {}
local MAXRANK = {}
local BUFFS = { ["Hot Streak"] = HS }

-- A. The lane is live and leads the Fireball nuke.
do
    hs_up = false
    hs_stacks = 0
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "leveling", "A: re-registers the leveling playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 6 baseline lanes")
    assert_eq(find_lane(combined, "Forever_HotStreakPyro"), find_lane(combined, "Fireball") - 1,
        "A: the spend lane leads the Fireball nuke")
end

-- A2. No buff mirror: the lane is dormant (fail closed).
do
    local combined = load_delta(MIRRORS, MAXRANK, {})
    assert_true(not find_lane(combined, "Forever_HotStreakPyro"), "A2: dormant without the buff row")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Matcher: the presence + stack gates and the leveling fire gates.
do
    hs_up = false
    hs_stacks = 0
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local pyro = combined[find_lane(combined, "Forever_HotStreakPyro")]
    local ctx = fresh_ctx()
    assert_true(not pyro.matches(ctx, fresh_state()), "B: no proc = no spend")
    hs_up = true
    assert_true(pyro.matches(ctx, fresh_state()), "B: the proc at zero stacks fails open and fires")
    hs_stacks = 1
    assert_true(not pyro.matches(ctx, fresh_state()), "B: 1 stack holds below the 3-stack cap")
    hs_stacks = 3
    assert_true(pyro.matches(ctx, fresh_state()), "B: the 3-stack cap fires")
    assert_true(not pyro.matches(ctx, fresh_state({ is_moving = true })), "B: movement holds")
    assert_true(not pyro.matches(ctx, fresh_state({ in_combat = false })), "B: out of combat holds")
    assert_true(not pyro.matches(ctx, fresh_state({ mana_pct = 5 })), "B: the mana floor holds")
    local no_target = fresh_state()
    no_target.target = nil
    assert_true(not pyro.matches(ctx, no_target), "B: no target holds")
    cast_log = {}
    local state = fresh_state()
    assert_true(pyro.execute(ctx, state), "B: the spend executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.MageSpells.Pyroblast, "B: it casts the class-map Pyroblast")
    assert_eq(cast_log[1] and cast_log[1].target, state.target, "B: it lands on the target")
end

-- C. Dormancy: empty mirrors leave the lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_HotStreakPyro"), "C: dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the anchors the lane appends.
do
    local shrunk = {
        name = "leveling",
        strategies = {
            { name = "FrostArmor", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 2, "D: the lane appended without anchors")
    assert_eq(find_lane(combined, "Forever_HotStreakPyro"), 2, "D: appended last")
end

-- G. Mirror selection: the buff mirror id drives the presence read.
do
    hs_up = true
    hs_stacks = 3
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local pyro = combined[find_lane(combined, "Forever_HotStreakPyro")]
    cast_log = {}
    assert_true(pyro.execute(fresh_ctx(), fresh_state()), "G: the buff sentinel drives the lane")
    assert_true(cast_log[1] ~= nil, "G: a cast was logged")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/mage/leveling_forever.lua", "rb")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    assert_true(#content > 0, "E: delta source readable")
    local body = content:gsub("%-%-[^\n]*", "")
    local found = nil
    for line in body:gmatch("([^\n]*)") do
        local digits = line:match("%f[%d]%d%f[^%d]")
        if digits and #digits >= 4 then
            found = found or line
        end
    end
    assert_true(found == nil, "E: no numeric spell-ID literals (found: " .. tostring(found) .. ")")
end

print("test_mage_leveling_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS mage_leveling_forever")
