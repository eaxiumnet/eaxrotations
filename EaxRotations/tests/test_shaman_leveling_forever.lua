-- test_shaman_leveling_forever.lua -- unit pins for the shaman leveling Forever delta.
-- WHAT:  leveling_forever.lua contract: baseline capture + re-register splice
--        (the Improved Ghost Wolf escape lane above the baseline's travel
--        lane), the talent gate, the HP threshold, the already-a-wolf check,
--        by-name dormancy, mirror selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Ghost Wolf without the talent gate is a 2.0s cast (not an escape);
--        without the already-a-wolf check the lane would re-shift every
--        frame at low HP.
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
local wolf = false
local WOLF = 19150
local WOLF_R1 = 19151
local TALENT = 19152
local WOLF_BUFF = 19153
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
    ShamanSpells = {},
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    buff_up = function(unit, ids)
        if type(ids) == "number" then return wolf and ids == WOLF_BUFF end
        return false
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "leveling",
    strategies = {
        { name = "LightningShield", matches = function() return false end, execute = function() return false end },
        { name = "Stormstrike", matches = function() return false end, execute = function() return false end },
        { name = "LightningBolt", matches = function() return false end, execute = function() return false end },
        { name = "GhostWolf", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/shaman/leveling_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/shaman/leveling_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/shaman/leveling_forever.lua")
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
        hp = 30,
        target = { name = "enemy" },
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local MIRRORS = { ["Ghost Wolf"] = WOLF_R1, ["Improved Ghost Wolf"] = TALENT }
local MAXRANK = { ["Ghost Wolf"] = WOLF }
local BUFFS = { ["Ghost Wolf"] = WOLF_BUFF }

-- A. The lane is live and leads the travel lane.
do
    learnt = { [TALENT] = true }
    wolf = false
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "leveling", "A: re-registers the leveling playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 5 baseline lanes")
    assert_eq(find_lane(combined, "Forever_GhostWolfEscape"), find_lane(combined, "GhostWolf") - 1,
        "A: the escape lane leads the travel lane")
end

-- A2. Gates off: dormant without the talent or the mirrors.
do
    learnt = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_GhostWolfEscape"), "A2: dormant without the talent")
    learnt = { [TALENT] = true }
    local no_mirrors = load_delta({}, {}, {})
    assert_true(not find_lane(no_mirrors, "Forever_GhostWolfEscape"), "A2: dormant without the name resolution")
    assert_eq(#no_mirrors, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Matcher: the escape gates.
do
    learnt = { [TALENT] = true }
    wolf = false
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local escape = combined[find_lane(combined, "Forever_GhostWolfEscape")]
    local ctx = fresh_ctx()
    assert_true(escape.matches(ctx, fresh_state()), "B: low HP in combat fires the escape")
    assert_true(not escape.matches(ctx, fresh_state({ hp = 80 })), "B: a healthy shaman holds")
    assert_true(not escape.matches(ctx, fresh_state({ in_combat = false })), "B: out of combat holds (the travel lane owns it)")
    wolf = true
    assert_true(not escape.matches(ctx, fresh_state()), "B: already a wolf holds")
    wolf = false
    cast_log = {}
    assert_true(escape.execute(ctx, fresh_state()), "B: the escape executes")
    assert_eq(cast_log[1] and cast_log[1].spell, WOLF, "B: the maxrank Ghost Wolf is cast")
    assert_eq(cast_log[1] and cast_log[1].target, NS.PLAYER_UNIT, "B: it shifts the shaman")
end

-- C. Dormancy: empty mirrors leave the lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_GhostWolfEscape"), "C: dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the anchors the lane appends.
do
    learnt = { [TALENT] = true }
    local shrunk = {
        name = "leveling",
        strategies = {
            { name = "LightningShield", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 2, "D: the lane appended without anchors")
    assert_eq(find_lane(combined, "Forever_GhostWolfEscape"), 2, "D: appended last")
end

-- G. Mirror selection: the talent gate reads the rank-1 mirror, the wolf
-- form the buff mirror.
do
    learnt = { [TALENT] = true }
    wolf = true
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local escape = combined[find_lane(combined, "Forever_GhostWolfEscape")]
    assert_true(not escape.matches(fresh_ctx(), fresh_state()),
        "G: the buff-mirror form read holds the lane")
    wolf = false
    local no_buff = load_delta(MIRRORS, MAXRANK, {})
    assert_true(no_buff and find_lane(no_buff, "Forever_GhostWolfEscape") ~= nil,
        "G: the lane lives without the buff pin (form check reads false)")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/shaman/leveling_forever.lua", "rb")
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

print("test_shaman_leveling_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS shaman_leveling_forever")
