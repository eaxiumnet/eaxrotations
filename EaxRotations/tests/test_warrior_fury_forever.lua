-- test_warrior_fury_forever.lua -- unit pins for the warrior fury Forever delta.
-- WHAT:  fury_forever.lua contract: baseline capture + re-register splice
--        (Recklessness above the DeathWish burst lane), the matcher gates
--        (combat, valid enemy, long-CD gate with the DBC 1800s value),
--        class-map (not bridge) resolution so the lane always splices, and
--        the zero-numeric-literal audit contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   the CD split is what makes Recklessness pressable at all (no shared
--        interlock); a lane that loses its long-CD gate would burn a
--        30-minute cooldown at random, and a lane that silently went dormant
--        (bridge-style) would leave fury without the burst it was split for.
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
local long_cd_arg = nil
local PLAYER_UNIT_REF = {}
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = PLAYER_UNIT_REF,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    WarriorSpells = {
        Recklessness = { ids = { 1719 } },
        DeathWish = { ids = { 12328 } },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    should_use_long_cd = function(_, cd) long_cd_arg = cd; return true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "fury",
    strategies = {
        { name = "Pummel", matches = function() return false end, execute = function() return false end },
        { name = "Execute", matches = function() return false end, execute = function() return false end },
        { name = "DeathWish", matches = function() return false end, execute = function() return false end },
        { name = "Bloodthirst", matches = function() return false end, execute = function() return false end },
        { name = "Whirlwind", matches = function() return false end, execute = function() return false end },
        { name = "HeroicStrike", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/warrior/fury_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/warrior/fury_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/warrior/fury_forever.lua")
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
    return { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }
end

-- A. Splice shape: Recklessness above DeathWish, nothing else moved.
do
    local combined = load_delta({}, {}, {})
    assert_eq(registered and registered.name, "fury", "A: re-registers the fury playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 6 baseline lanes")
    local dw = find_lane(combined, "DeathWish")
    assert_eq(find_lane(combined, "Forever_RecklessnessBurst"), dw - 1, "A: Recklessness sits just above DeathWish")
    assert_true(find_lane(combined, "Execute") < find_lane(combined, "Forever_RecklessnessBurst"),
        "A: Execute keeps first refusal")
    assert_true(find_lane(combined, "HeroicStrike") > find_lane(combined, "Forever_RecklessnessBurst"),
        "A: baseline damage lanes stay below")
end

-- B. Matcher behavior: the burst gates + the DBC long-CD value.
do
    local combined = load_delta({}, {}, {})
    local ctx = fresh_ctx()
    local state = { rage = 50 }
    local burst = combined[find_lane(combined, "Forever_RecklessnessBurst")]

    long_cd_arg = nil
    assert_true(burst.matches(ctx, state), "B: Recklessness fires in combat with a valid enemy")
    assert_eq(long_cd_arg, 1800, "B: the long-CD gate receives the DBC 1800s cooldown")

    local ooc = fresh_ctx()
    ooc.in_combat = false
    assert_true(not burst.matches(ooc, state), "B: Recklessness needs combat")
    local no_target = fresh_ctx()
    no_target.has_valid_enemy_target = false
    assert_true(not burst.matches(no_target, state), "B: Recklessness needs a valid enemy")
    NS.should_use_long_cd = function() return false end
    assert_true(not burst.matches(ctx, state), "B: Recklessness respects the long-CD gate")
    NS.should_use_long_cd = function(_, cd) long_cd_arg = cd; return true end
    NS.spell_ready = function() return false end
    assert_true(not burst.matches(ctx, state), "B: Recklessness respects readiness")
    NS.spell_ready = function() return true end
    cast_log = {}
    assert_true(burst.execute(ctx, state), "B: Recklessness executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.WarriorSpells.Recklessness, "B: casts the class-map action")
end

-- C. Resolution contract: the lane is CLASS-MAP based (no bridge lookup), so
-- it must still splice with empty mirrors -- unlike the bridge-gated deltas.
do
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "C: lane present on empty mirrors (class-map action)")
    assert_true(find_lane(combined, "Forever_RecklessnessBurst"), "C: Recklessness not dormant")
end

-- D. Splice fallback: no DeathWish/Bloodthirst anchor appends.
do
    FAKE_BASELINE.strategies = {
        { name = "Pummel", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({}, {}, {})
    assert_eq(find_lane(combined, "Forever_RecklessnessBurst"), #combined, "D: Recklessness appends when anchors are absent")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/warrior/fury_forever.lua", "r")
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

print(string.format("test_warrior_fury_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS warrior_fury_forever")
