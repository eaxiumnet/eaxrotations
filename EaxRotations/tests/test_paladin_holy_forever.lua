-- test_paladin_holy_forever.lua -- unit pins for the first _forever delta spec.
-- WHAT:  holy_forever.lua contract: baseline capture + re-register splice,
--        lane set and ordering (healing-priority head, fillers above the
--        solo block), by-name dormancy on nil lookups, matcher
--        behavior, and the zero-numeric-literal audit contract.
-- WHEN:  standalone -- lua EaxRotations/tests/test_paladin_holy_forever.lua
--        or via run_rotation_tests.lua.
-- WHY:   the delta replaces the whole "holy" playstyle on Forever clients;
--        a lost baseline lane, a lane that fires while dormant-resolved, or
--        a hardcoded spell ID (which the forever audit must catch on beta
--        day) each silently break day-1 healing. Pin them here.
-- SAFETY: fully mocked NS + require (fake baseline module); no real spec
--         logic beyond the delta file itself.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local pass, fail = 0, 0
local function assert_true(v, label)
    if v then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. tostring(label)) end
end
local function assert_eq(a, b, label)
    if a == b then pass = pass + 1
    else fail = fail + 1; print("  FAIL: " .. tostring(label) .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")") end
end

-- ---------------------------------------------------------------------------
-- Mock NS + registry (records the final registration) and a fake baseline
-- module: holy_vanilla's registration shape (strategies + get_state) with a
-- splice anchor lane and an emergency lane.
-- ---------------------------------------------------------------------------
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
    PaladinSpells = {
        HolyLight = { ids = { 27136 } },
        HolyShock = { ids = { 20473 } },
    },
    has_player_buff = function() return false end,
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    cooldown_remains = function() return 0 end,
    should_use_long_cd = function() return true end,
    unit_distance = function() return 5 end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "holy",
    strategies = {
        { name = "FakeEmergencyLane", matches = function() return false end, execute = function() return false end },
        { name = "SealOfRighteousnessSolo", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/paladin/holy_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/paladin/holy_vanilla' not found", 0)
    end
    if path == "shared/spec_kit_sylvanas" then
        return { setting = function(_, key, default) return default end }
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    -- The delta pcall-requires the bridge module (Pattern 9 optional-module
    -- shape) instead of reading a never-assigned NS member; the intercepted
    -- require above hands it the three pending mirrors (closure captures --
    -- load_delta's parameters themselves would resolve as nil globals
    -- there). Distinct sentinels per mirror pin MIRROR SELECTION, not just
    -- resolution: a lane reading the wrong mirror sees a different id.
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/paladin/holy_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

-- A. Full kit: all three bridge names resolve in every mirror; splice +
-- registration shape.
do
    local combined = load_delta({
        ["Holy Strike"] = 19000,
        ["Light's Vigil"] = 19001,
        ["Infusion of Light"] = 19002,
    }, {
        ["Holy Strike"] = 19100,
        ["Light's Vigil"] = 19101,
    }, {
        ["Infusion of Light"] = 19202,
    })
    assert_eq(registered and registered.name, "holy", "A: re-registers the holy playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 4, "A: 4 delta lanes over 2 baseline lanes")
    assert_eq(find_lane(combined, "Forever_InfusionOfLightWeave"), 1, "A: IoL weave is lane #1 (healing priority)")
    assert_eq(find_lane(combined, "Forever_LightsVigilBurst"), 2, "A: Light's Vigil is lane #2")
    local solo = find_lane(combined, "SealOfRighteousnessSolo")
    assert_eq(find_lane(combined, "Forever_HolyShockCore"), solo - 2, "A: Holy Shock core sits just above the solo block")
    assert_eq(find_lane(combined, "Forever_HolyStrikeWeave"), solo - 1, "A: Holy Strike weave sits just above the solo block")
    assert_true(find_lane(combined, "FakeEmergencyLane") > 2, "A: baseline lanes preserved below the delta head")
end

-- B. Matcher behavior on the head + filler lanes.
do
    local combined = load_delta({
        ["Holy Strike"] = 19000,
        ["Light's Vigil"] = 19001,
        ["Infusion of Light"] = 19002,
    }, {
        ["Holy Strike"] = 19100,
        ["Light's Vigil"] = 19101,
    }, {
        ["Infusion of Light"] = 19202,
    })
    local state = { lowest = { unit = {}, hp = 60 }, mana_pct = 100, entries = {}, count = 0 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }

    local iol = combined[find_lane(combined, "Forever_InfusionOfLightWeave")]
    NS.has_player_buff = function() return true end
    assert_true(iol.matches(ctx, state), "B: IoL weave matches with buff + 40% deficit")
    NS.has_player_buff = function() return false end
    assert_true(not iol.matches(ctx, state), "B: IoL weave dormant without the buff")
    state.lowest.hp = 90 -- deficit 10 < 30
    NS.has_player_buff = function() return true end
    assert_true(not iol.matches(ctx, state), "B: IoL weave skips near-full targets")
    state.lowest.hp = 60

    local vigil = combined[find_lane(combined, "Forever_LightsVigilBurst")]
    NS.cooldown_remains = function(spell) return spell == NS.PaladinSpells.HolyShock and 6 or 0 end
    assert_true(vigil.matches(ctx, state), "B: Vigil fires inside the Holy Shock reset window")
    NS.cooldown_remains = function(spell) return spell == NS.PaladinSpells.HolyShock and 2 or 0 end
    assert_true(not vigil.matches(ctx, state), "B: Vigil holds while Holy Shock is nearly up")
    NS.cooldown_remains = function() return 0 end

    local core = combined[find_lane(combined, "Forever_HolyShockCore")]
    assert_true(core.matches(ctx, state), "B: Holy Shock core matches in combat")
    state.mana_pct = 10
    assert_true(not core.matches(ctx, state), "B: Holy Shock core respects the mana floor")
    state.mana_pct = 100

    local weave = combined[find_lane(combined, "Forever_HolyStrikeWeave")]
    state.lowest.hp = 96 -- healthy group: the weave may fire
    assert_true(weave.matches(ctx, state), "B: Holy Strike weave matches in melee range")
    NS.unit_distance = function() return 15 end
    assert_true(not weave.matches(ctx, state), "B: Holy Strike weave holds out of melee range")
    NS.unit_distance = function() return 5 end
    state.lowest.hp = 60 -- unhealthy group (healer-first veto)
    assert_true(not weave.matches(ctx, state), "B: Holy Strike weave never outranks healing")
end

-- C. Dormancy on nil lookups: empty mirrors leave lanes out, never guessed;
-- the always-resolvable Holy Shock core still splices in.
do
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "C: only the Holy Shock core delta exists on empty mirrors")
    assert_true(find_lane(combined, "Forever_HolyShockCore"), "C: core lane present")
    assert_true(not find_lane(combined, "Forever_HolyStrikeWeave"), "C: Holy Strike dormant")
    assert_true(not find_lane(combined, "Forever_LightsVigilBurst"), "C: Light's Vigil dormant")
    assert_true(not find_lane(combined, "Forever_InfusionOfLightWeave"), "C: IoL dormant")
    local solo = find_lane(combined, "SealOfRighteousnessSolo")
    assert_eq(find_lane(combined, "Forever_HolyShockCore"), solo - 1, "C: core still spliced above the solo block")
end

-- D. Splice fallback: no solo-block anchor means the fillers append.
do
    FAKE_BASELINE.strategies = {
        { name = "FakeEmergencyLane", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({ ["Holy Strike"] = 19000 }, { ["Holy Strike"] = 19100 }, {})
    assert_eq(find_lane(combined, "Forever_HolyStrikeWeave"), #combined, "D: weave appends when the anchor lane is absent")
    assert_eq(find_lane(combined, "Forever_HolyShockCore"), #combined - 1, "D: core appends before the weave")
end

-- G. Mirror selection: cast lanes resolve max-rank ids, the buff lane
-- resolves the buff-mirror id -- never the rank-1 baseline (distinct
-- sentinels per mirror prove which table each lane read).
do
    local combined = load_delta({
        ["Holy Strike"] = 19000,
        ["Light's Vigil"] = 19001,
        ["Infusion of Light"] = 19002,
    }, {
        ["Holy Strike"] = 19100,
        ["Light's Vigil"] = 19101,
    }, {
        ["Infusion of Light"] = 19202,
    })
    local state = { lowest = { unit = {}, hp = 60 }, mana_pct = 100, entries = {}, count = 0 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }

    local weave = combined[find_lane(combined, "Forever_HolyStrikeWeave")]
    state.lowest.hp = 96
    assert_true(weave.matches(ctx, state), "G: weave matches")
    cast_log = {}
    assert_true(weave.execute(ctx, state), "G: weave executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19100, "G: weave casts the maxrank sentinel (not the 19000 baseline)")

    local vigil = combined[find_lane(combined, "Forever_LightsVigilBurst")]
    state.lowest.hp = 60
    cast_log = {}
    assert_true(vigil.execute(ctx, state), "G: vigil executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19101, "G: vigil casts the maxrank sentinel")

    local iol = combined[find_lane(combined, "Forever_InfusionOfLightWeave")]
    NS.has_player_buff = function(id) return id == 19202 end
    assert_true(iol.matches(ctx, state), "G: IoL matches on the buff-mirror sentinel")
    NS.has_player_buff = function(id) return id == 19002 end
    assert_true(not iol.matches(ctx, state), "G: IoL ignores the rank-1 baseline sentinel")
    NS.has_player_buff = function() return false end
end

-- E. Zero numeric spell-ID literals (audit contract): no digits-only table
-- literal in non-comment code lines of the delta source.
do
    local f = io.open("EaxRotations/classes/paladin/holy_forever.lua", "r")
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

-- F. Baseline load failure is loud (no silently-missing playstyle).
do
    FAKE_BASELINE = nil
    local ok, err = pcall(load_delta, {})
    assert_true(not ok, "F: delta errors when the baseline cannot load")
    assert_true(tostring(err):find("baseline load failed", 1, true) ~= nil, "F: error names the baseline failure")
end

require = orig_require

print(string.format("test_paladin_holy_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS paladin_holy_forever")
