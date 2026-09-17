-- test_hunter_survival_forever.lua -- unit pins for the hunter survival Forever delta.
-- WHAT:  survival_forever.lua contract: baseline capture + re-register splice
--        (melee block above RaptorStrike; MultiShot re-emitted above
--        AimedShot), by-name dormancy for the bridge-resolved lane, matcher
--        gates (melee range, combat, readiness), zero-numeric-literal
--        contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   the whole delta is (a) Mongoose Bite + Strider Kick entering the
--        melee block and (b) the DBC-confirmed shared Aimed/Multi cooldown
--        picking the right shot for the target count -- if the reorder is
--        lost, Multi-Shot starves again on every multi-pull; if the melee
--        gates are lost, the melee lanes fire from range and waste the
--        react windows.
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
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    HunterSpells = {
        MongooseBite = { ids = { 14271, 1495 } },
        AimedShot = { ids = { 19434 } },
        MultiShot = { ids = { 2643 } },
        RaptorStrike = { ids = { 2973 } },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "survival",
    strategies = {
        { name = "PetDefensive", matches = function() return false end, execute = function() return false end },
        { name = "AspectOfTheHawk", matches = function() return false end, execute = function() return false end },
        { name = "RaptorStrike", matches = function() return false end, execute = function() return false end },
        { name = "WingClip", matches = function() return false end, execute = function() return false end },
        { name = "LevelingArcaneShot", matches = function() return false end, execute = function() return false end },
        { name = "AimedShot", matches = function() return false end, execute = function() return false end },
        { name = "MultiShot", matches = function() return false end, execute = function() return false end },
        { name = "ArcaneShot", matches = function() return false end, execute = function() return false end },
        { name = "SerpentSting", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/hunter/survival_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/hunter/survival_vanilla' not found", 0)
    end
    if path == "shared/spec_kit_sylvanas" then
        return { setting = function(_, key, default) return default end }
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/hunter/survival_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function count_lane(list, name)
    local n = 0
    for _, st in ipairs(list) do
        if type(st) == "table" and st.name == name then n = n + 1 end
    end
    return n
end

local function fresh_ctx(dist)
    return { in_combat = true, target = {}, has_valid_enemy_target = true, me = {},
             distance = dist or 5, settings = {} }
end

-- A. Full kit: melee block above RaptorStrike; MultiShot re-emitted above
-- AimedShot (exactly one MultiShot lane in the list).
do
    local combined = load_delta({}, { ["Strider Kick"] = 19116 }, {})
    assert_eq(registered and registered.name, "survival", "A: re-registers the survival playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: 2 delta lanes, reorder is count-neutral")
    local raptor = find_lane(combined, "RaptorStrike")
    assert_eq(find_lane(combined, "Forever_MongooseBite"), raptor - 2, "A: Mongoose leads the melee block")
    assert_eq(find_lane(combined, "Forever_StriderKick"), raptor - 1, "A: Strider Kick follows")
    assert_eq(count_lane(combined, "MultiShot"), 1, "A: exactly one MultiShot lane remains")
    assert_eq(find_lane(combined, "MultiShot"), find_lane(combined, "AimedShot") - 1,
        "A: MultiShot now sits just above AimedShot (shared CD picks the shot)")
    assert_true(find_lane(combined, "ArcaneShot") > find_lane(combined, "AimedShot"),
        "A: the rest of the shot block is untouched")
    assert_eq(find_lane(combined, "PetDefensive"), 1, "A: pet/utility head lanes untouched")
end

-- B. Matcher behavior: melee range + readiness gates.
do
    local combined = load_delta({}, { ["Strider Kick"] = 19116 }, {})
    local state = { in_combat = true }
    local ctx = fresh_ctx(5)

    local mongo = combined[find_lane(combined, "Forever_MongooseBite")]
    assert_true(mongo.matches(ctx, state), "B: Mongoose Bite fires in melee range")
    local ranged = fresh_ctx(20)
    assert_true(not mongo.matches(ranged, state), "B: Mongoose Bite holds out of melee range")
    local ooc = fresh_ctx(5)
    ooc.in_combat = false
    local ooc_state = { in_combat = false }
    assert_true(not mongo.matches(ooc, ooc_state), "B: Mongoose Bite needs combat")
    NS.spell_ready = function() return false end
    assert_true(not mongo.matches(ctx, state), "B: Mongoose Bite respects the react window (readiness)")
    NS.spell_ready = function() return true end

    local strider = combined[find_lane(combined, "Forever_StriderKick")]
    assert_true(strider.matches(ctx, state), "B: Strider Kick fires in melee range")
    assert_true(not strider.matches(ranged, state), "B: Strider Kick holds out of melee range")
    assert_true(not strider.matches(ooc, ooc_state), "B: Strider Kick needs combat")
    cast_log = {}
    assert_true(strider.execute(ctx, state), "B: Strider Kick executes")
end

-- C. Dormancy: without the bridge name only the class-map Mongoose lane
-- exists; the shot reorder still applies.
do
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "C: only the class-map melee lane splices")
    assert_true(find_lane(combined, "Forever_MongooseBite"), "C: Mongoose present (class map)")
    assert_true(not find_lane(combined, "Forever_StriderKick"), "C: Strider Kick dormant")
    assert_eq(find_lane(combined, "MultiShot"), find_lane(combined, "AimedShot") - 1, "C: reorder still applies")
end

-- D. Splice fallback: no RaptorStrike/AimedShot anchors -> melee block
-- appends and the captured MultiShot lane still lands at the tail.
do
    FAKE_BASELINE.strategies = {
        { name = "PetDefensive", matches = function() return false end, execute = function() return false end },
        { name = "MultiShot", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({}, { ["Strider Kick"] = 19116 }, {})
    assert_eq(count_lane(combined, "MultiShot"), 1, "D: MultiShot still present exactly once")
    assert_eq(find_lane(combined, "Forever_MongooseBite"), #combined - 2, "D: melee block lands above the shot")
    assert_eq(find_lane(combined, "Forever_StriderKick"), #combined - 1, "D: Strider follows Mongoose")
    assert_eq(find_lane(combined, "MultiShot"), #combined, "D: MultiShot keeps its position at the tail")
end

-- G. Mirror selection: Strider Kick casts the maxrank sentinel; Mongoose
-- Bite casts the class-map action (never a bridge id).
do
    local combined = load_delta({}, { ["Strider Kick"] = 19116 }, {})
    local state = { in_combat = true }
    local ctx = fresh_ctx(5)

    local strider = combined[find_lane(combined, "Forever_StriderKick")]
    cast_log = {}
    assert_true(strider.execute(ctx, state), "G: Strider Kick executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19116, "G: Strider Kick casts the maxrank sentinel")

    local mongo = combined[find_lane(combined, "Forever_MongooseBite")]
    cast_log = {}
    assert_true(mongo.execute(ctx, state), "G: Mongoose Bite executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.HunterSpells.MongooseBite,
        "G: Mongoose Bite casts the class-map action")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/hunter/survival_forever.lua", "r")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    assert_true(#content > 0, "E: delta source readable")
    local bad = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if line:match("^%s*%-%-") ~= nil then
            -- comment line: exempt
        else
            for table_part in line:gmatch("(%b{})") do
                local inner = table_part:sub(2, -2)
                if inner:match("^[%s%d,]*$") then
                    for num in inner:gmatch("%d+") do
                        if tonumber(num) >= 100 then bad[#bad + 1] = line_no .. ":" .. num end
                    end
                end
            end
        end
    end
    assert_eq(#bad, 0, "E: zero numeric ID literals in code (found: " .. table.concat(bad, ", ") .. ")")
end

-- F. Baseline load failure is loud.
do
    FAKE_BASELINE = nil
    local ok, err = pcall(load_delta, {})
    assert_true(not ok, "F: delta errors when the baseline cannot load")
    assert_true(tostring(err):find("baseline load failed", 1, true) ~= nil, "F: error names the baseline failure")
end

require = orig_require

print(string.format("test_hunter_survival_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS hunter_survival_forever")
