-- test_priest_smite_forever.lua -- unit pins for the priest smite Forever delta.
-- WHAT:  smite_forever.lua contract: baseline capture + re-register (the
--        Penance lane above the MindBlast nuke, the Holy Fire upkeep lane
--        REPLACING the baseline's cast-on-cooldown HolyFire lane at its
--        position), the Power in Light talent gate, the Holy Fire window
--        read, by-name dormancy, mirror selection, zero-numeric-literal
--        contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Penance without the Holy Fire gate loses the +15% multiplier the
--        talent exists for; keeping the baseline's cast-on-cooldown Holy
--        Fire lane would waste the debuff-driven upkeep (the debuff, not
--        the cast, is the Smite multiplier now).
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
local hf_map = {}
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
        HolyFire = { _meta = { ids = { 25384, 15261, 15262, 14914 } }, name = "HolyFire" },
        Smite = { ids = { 25364, 10934, 585 }, name = "Smite" },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    debuff_up = function(unit, ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if hf_map[id] ~= nil then return true end
            end
        end
        return false
    end,
    debuff_remains = function(unit, ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if hf_map[id] ~= nil then return hf_map[id] end
            end
        end
        return 0
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "smite",
    strategies = {
        { name = "InnerFire", matches = function() return false end, execute = function() return false end },
        { name = "HolyFire", matches = function() return false end, execute = function() return false end },
        { name = "SurgeOfLightSmite", matches = function() return false end, execute = function() return false end },
        { name = "ShadowWordPain", matches = function() return false end, execute = function() return false end },
        { name = "MindBlast", matches = function() return false end, execute = function() return false end },
        { name = "SmiteFiller", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/priest/smite_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/priest/smite_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/priest/smite_forever.lua")
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
    local ctx = { in_combat = true, target = { name = "enemy" }, has_valid_enemy_target = true,
                  me = {}, settings = {} }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function fresh_state(overrides)
    local s = { mana_emergency = false }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local PIL = 19090
local PENANCE = 19091
local PENANCE_R1 = 19092
local MIRRORS = { ["Power in Light"] = PIL, ["Penance"] = PENANCE_R1 }
local MAXRANK = { ["Penance"] = PENANCE }
local BUFFS = {}

-- A. Both lanes live: Penance above MindBlast, the upkeep lane replacing
-- HolyFire at its position.
do
    learnt = { [PIL] = true, [PENANCE] = true }
    hf_map = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "smite", "A: re-registers the smite playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 2 lanes in, 1 lane replaced")
    assert_true(not find_lane(combined, "HolyFire"), "A: the baseline's cast-on-cooldown HolyFire lane is dropped")
    assert_eq(find_lane(combined, "Forever_HolyFireUpkeep"), 2, "A: the upkeep lane takes the HolyFire position")
    assert_eq(find_lane(combined, "Forever_Penance"), find_lane(combined, "MindBlast") - 1,
        "A: Penance leads the MindBlast nuke")
end

-- A2. Power in Light not learned: no delta lanes, the baseline lane kept.
do
    learnt = { [PENANCE] = true }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_Penance"), "A2: Penance dormant without the talent")
    assert_true(not find_lane(combined, "Forever_HolyFireUpkeep"), "A2: upkeep dormant without the talent")
    assert_true(find_lane(combined, "HolyFire") ~= nil, "A2: the baseline HolyFire lane is kept")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- A3. Penance not learned: the upkeep lane still ships.
do
    learnt = { [PIL] = true }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_Penance"), "A3: Penance dormant without the learn")
    assert_true(find_lane(combined, "Forever_HolyFireUpkeep") ~= nil, "A3: the upkeep lane is learn-independent")
    assert_true(not find_lane(combined, "HolyFire"), "A3: the replacement still drops the baseline lane")
end

-- B. Penance matcher: the Power in Light window.
do
    learnt = { [PIL] = true, [PENANCE] = true }
    hf_map = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local penance = combined[find_lane(combined, "Forever_Penance")]
    local ctx = fresh_ctx()
    assert_true(not penance.matches(ctx, fresh_state()), "B: no Holy Fire = no Penance")
    hf_map = { [15261] = 5 }
    assert_true(penance.matches(ctx, fresh_state()), "B: the Holy Fire window opens Penance")
    assert_true(not penance.matches(ctx, fresh_state({ mana_emergency = true })), "B: the mana emergency holds Penance")
    assert_true(not penance.matches(fresh_ctx({ is_moving = true }), fresh_state()), "B: movement holds the cast")
    cast_log = {}
    assert_true(penance.execute(ctx, fresh_state()), "B: Penance executes")
    assert_eq(cast_log[1] and cast_log[1].spell, PENANCE, "B: the maxrank Penance id is cast")
    assert_eq(cast_log[1] and cast_log[1].target, ctx.target, "B: Penance lands on the target")
end

-- B2. Upkeep matcher: the debuff-driven refresh.
do
    learnt = { [PIL] = true, [PENANCE] = true }
    hf_map = { [15261] = 8 }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local upkeep = combined[find_lane(combined, "Forever_HolyFireUpkeep")]
    local ctx = fresh_ctx()
    assert_true(not upkeep.matches(ctx, fresh_state()), "B2: a fresh debuff holds the upkeep")
    hf_map = { [15261] = 1.5 }
    assert_true(upkeep.matches(ctx, fresh_state()), "B2: an expiring debuff refreshes")
    hf_map = {}
    assert_true(upkeep.matches(ctx, fresh_state()), "B2: a missing debuff re-applies")
    cast_log = {}
    assert_true(upkeep.execute(ctx, fresh_state()), "B2: the upkeep executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.PriestSpells.HolyFire, "B2: it casts the class-map Holy Fire")
    assert_true(not upkeep.matches(fresh_ctx({ is_moving = true }), fresh_state()), "B2: movement holds the upkeep")
end

-- C. Dormancy: empty mirrors leave the delta out and keep the baseline lane.
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_Penance"), "C: Penance dormant")
    assert_true(not find_lane(combined, "Forever_HolyFireUpkeep"), "C: upkeep dormant")
    assert_true(find_lane(combined, "HolyFire") ~= nil, "C: the baseline HolyFire lane is kept")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the anchors the Penance lane appends.
do
    learnt = { [PIL] = true, [PENANCE] = true }
    local shrunk = {
        name = "smite",
        strategies = {
            { name = "InnerFire", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 3, "D: Penance + upkeep appended without anchors")
    assert_eq(find_lane(combined, "Forever_Penance"), 2, "D: Penance appended first")
    assert_eq(find_lane(combined, "Forever_HolyFireUpkeep"), 3, "D: the upkeep lane appended second")
end

-- G. Mirror selection: the cast reads maxrank, the learn gates both mirrors,
-- the talent the rank-1 mirror.
do
    learnt = { [PIL] = true, [PENANCE] = true }
    hf_map = { [15261] = 5 }
    local no_max = load_delta(MIRRORS, {}, BUFFS)
    assert_true(not find_lane(no_max, "Forever_Penance"), "G: no maxrank = dormant Penance")
    assert_true(find_lane(no_max, "Forever_HolyFireUpkeep") ~= nil, "G: the upkeep lane is cast-free")
    local live = load_delta(MIRRORS, MAXRANK, BUFFS)
    local penance = live[find_lane(live, "Forever_Penance")]
    cast_log = {}
    assert_true(penance.execute(fresh_ctx(), fresh_state()), "G: the rank-1 learn gate keeps the cast live")
    assert_eq(cast_log[1] and cast_log[1].spell, PENANCE, "G: the maxrank sentinel is the cast id")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/priest/smite_forever.lua", "rb")
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

print("test_priest_smite_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS priest_smite_forever")
