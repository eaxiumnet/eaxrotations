-- test_priest_shadow_forever.lua -- unit pins for the priest shadow Forever delta.
-- WHAT:  shadow_forever.lua contract: baseline capture + re-register splice
--        (Shadow Word: Death above the nuke block, the Devouring Contagion
--        maintenance lane above the baseline DP lane), the execute HP gate,
--        the cleave/aoe + refresh gating, the channel discipline, by-name
--        dormancy, mirror selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   SW:D without the execute gate pays backlash health for nothing; the
--        Contagion lane without the cleave gate would spend DP on single
--        targets (the baseline's snapshot lane is the single-target answer),
--        and both must never clip a live Mind Flay channel.
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
local learnt = {}
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    PriestSpells = {
        DevouringPlague = { ids = { 25467, 19280, 19276, 2944 }, name = "DevouringPlague" },
        MindBlast = { ids = { 25375, 10947, 8092 }, name = "MindBlast" },
        MindFlay = { ids = { 25387, 18807, 15407 }, name = "MindFlay" },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "shadow",
    strategies = {
        { name = "Shadowform", matches = function() return false end, execute = function() return false end },
        { name = "ShadowWordPain", matches = function() return false end, execute = function() return false end },
        { name = "DevouringPlague", matches = function() return false end, execute = function() return false end },
        { name = "MindBlast", matches = function() return false end, execute = function() return false end },
        { name = "MindFlay", matches = function() return false end, execute = function() return false end },
        { name = "Fade", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/priest/shadow_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/priest/shadow_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/priest/shadow_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function fresh_ctx()
    return { in_combat = true, target = { name = "enemy" }, has_valid_enemy_target = true,
             me = {}, settings = {}, target_hp = 20 }
end

local function fresh_state(overrides)
    local s = {
        mf_channeling = false,
        should_clip_mf = false,
        mana_emergency = false,
        dp_remaining = 0,
        devouring_plague_known = true,
        combat_mode = "st",
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local SWD = 19050
local SWD_R1 = 19051
local CONTAGION = 19052
local MIRRORS = { ["Shadow Word: Death"] = SWD_R1, ["Devouring Contagion"] = CONTAGION }
local MAXRANK = { ["Shadow Word: Death"] = SWD }

-- A. Both lanes live.
do
    learnt = { [SWD] = true, [CONTAGION] = true }
    local combined = load_delta(MIRRORS, MAXRANK, {})
    assert_eq(registered and registered.name, "shadow", "A: re-registers the shadow playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: 2 delta lanes over 6 baseline lanes")
    assert_eq(find_lane(combined, "Forever_ShadowWordDeath"), find_lane(combined, "MindBlast") - 1,
        "A: SW:D leads the nuke block")
    assert_eq(find_lane(combined, "Forever_DevouringContagion"), find_lane(combined, "ShadowWordPain") - 1,
        "A: the Contagion lane leads the dot block")
end

-- A2. Gates off: SW:D dormant without the learn, Contagion without the talent.
do
    learnt = {}
    local combined = load_delta(MIRRORS, MAXRANK, {})
    assert_true(not find_lane(combined, "Forever_ShadowWordDeath"), "A2: SW:D dormant without the learn")
    assert_true(not find_lane(combined, "Forever_DevouringContagion"), "A2: Contagion dormant without the talent")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. SW:D matcher: the Early Demise window + the channel discipline.
do
    learnt = { [SWD] = true, [CONTAGION] = true }
    local combined = load_delta(MIRRORS, MAXRANK, {})
    local swd = combined[find_lane(combined, "Forever_ShadowWordDeath")]
    local ctx = fresh_ctx()
    assert_true(swd.matches(ctx, fresh_state()), "B: a 20% target fires the execute")
    ctx.target_hp = 30
    assert_true(not swd.matches(ctx, fresh_state()), "B: a 30% target holds the execute")
    ctx.target_hp = 20
    assert_true(not swd.matches(ctx, fresh_state({ mana_emergency = true })), "B: the mana emergency holds SW:D")
    assert_true(not swd.matches(ctx, fresh_state({ mf_channeling = true })), "B: a live channel holds SW:D")
    assert_true(swd.matches(ctx, fresh_state({ mf_channeling = true, should_clip_mf = true })),
        "B: the clip decision opens the channel")
    cast_log = {}
    assert_true(swd.execute(ctx, fresh_state()), "B: SW:D executes")
    assert_eq(cast_log[1] and cast_log[1].spell, SWD, "B: the maxrank SW:D id is cast")
    assert_eq(cast_log[1] and cast_log[1].target, ctx.target, "B: SW:D lands on the target")
end

-- B2. Contagion matcher: cleave/aoe + the wider DP refresh window.
do
    learnt = { [SWD] = true, [CONTAGION] = true }
    local combined = load_delta(MIRRORS, MAXRANK, {})
    local contagion = combined[find_lane(combined, "Forever_DevouringContagion")]
    local ctx = fresh_ctx()
    assert_true(not contagion.matches(ctx, fresh_state()), "B2: single target holds the Contagion lane")
    assert_true(contagion.matches(ctx, fresh_state({ combat_mode = "cleave" })),
        "B2: cleave fires the Contagion lane")
    assert_true(contagion.matches(ctx, fresh_state({ combat_mode = "aoe" })),
        "B2: aoe fires the Contagion lane")
    assert_true(not contagion.matches(ctx, fresh_state({ combat_mode = "cleave", dp_remaining = 10 })),
        "B2: a fresh DP holds the lane")
    assert_true(contagion.matches(ctx, fresh_state({ combat_mode = "cleave", dp_remaining = 4 })),
        "B2: an expiring DP refreshes inside the wider window")
    assert_true(not contagion.matches(ctx, fresh_state({ combat_mode = "cleave", devouring_plague_known = false })),
        "B2: an unknown DP holds the lane")
    assert_true(not contagion.matches(ctx, fresh_state({ combat_mode = "cleave", mf_channeling = true })),
        "B2: a live channel holds the Contagion lane")
    cast_log = {}
    assert_true(contagion.execute(ctx, fresh_state({ combat_mode = "cleave" })), "B2: the lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.PriestSpells.DevouringPlague,
        "B2: the class-map Devouring Plague is cast")
end

-- C. Dormancy: empty mirrors leave both lanes out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_ShadowWordDeath"), "C: SW:D dormant")
    assert_true(not find_lane(combined, "Forever_DevouringContagion"), "C: Contagion dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the primary anchors the lanes append.
do
    learnt = { [SWD] = true, [CONTAGION] = true }
    local shrunk = {
        name = "shadow",
        strategies = {
            { name = "Shadowform", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, {})
    FAKE_BASELINE = saved
    assert_eq(#combined, 3, "D: both lanes appended without anchors")
    assert_eq(find_lane(combined, "Forever_ShadowWordDeath"), 2, "D: SW:D appended first")
    assert_eq(find_lane(combined, "Forever_DevouringContagion"), 3, "D: Contagion appended second")
end

-- G. Mirror selection: the SW:D cast reads maxrank + the rank-1 learn gate;
-- the Contagion talent the rank-1 mirror.
do
    learnt = { [SWD] = true, [CONTAGION] = true }
    local no_max = load_delta(MIRRORS, {}, {})
    assert_true(not find_lane(no_max, "Forever_ShadowWordDeath"), "G: no maxrank = dormant SW:D")
    assert_true(find_lane(no_max, "Forever_DevouringContagion") ~= nil, "G: Contagion is learn-gated, not cast-gated")
    local no_name = load_delta({ ["Shadow Word: Death"] = SWD_R1 }, MAXRANK, {})
    assert_true(not find_lane(no_name, "Forever_DevouringContagion"), "G: no talent row = dormant Contagion")
    local live = load_delta(MIRRORS, MAXRANK, {})
    local swd = live[find_lane(live, "Forever_ShadowWordDeath")]
    cast_log = {}
    assert_true(swd.execute(fresh_ctx(), fresh_state()), "G: the rank-1 learn gate keeps the cast live")
    assert_eq(cast_log[1] and cast_log[1].spell, SWD, "G: the maxrank sentinel is the cast id")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/priest/shadow_forever.lua", "rb")
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

print("test_priest_shadow_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS priest_shadow_forever")
