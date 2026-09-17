-- test_mage_frost_forever.lua -- unit pins for the mage frost Forever delta.
-- WHAT:  frost_forever.lua contract: baseline capture + re-register splice
--        (Icy Veins above the cooldown block, Ice Lance above the damage
--        block, the Winter's Chill replacement in the baseline slot), the
--        engraving-known gate for Ice Lance, the Frozen-window debuff read,
--        the fixed Winter's Chill stack read, by-name dormancy, and the
--        zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Ice Lance is the kit's frozen-window payoff but is engraving-gated;
--        Icy Veins exists on the client while the class map's 12472 is COLD
--        SNAP there (a class-map lane would press the wrong cooldown); and
--        the baseline's Winter's Chill stack gate read the TALENT id, which
--        never stacks -- the replacement must read the applied debuff row.
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
    PLAYER_UNIT = {},
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    MageSpells = {
        Frostbolt = { ids = { 116 } },
        FrostNova = { _meta = { ids = { 10230, 6131, 865, 122 } } },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
    debuff_remains = function() return 0 end,
    debuff_stacks = function() return 0 end,
    should_use_long_cd = function() return true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "frost",
    strategies = {
        { name = "IceBarrier", matches = function() return false end, execute = function() return false end },
        { name = "ColdSnap", matches = function() return false end, execute = function() return false end },
        { name = "PresenceOfMind", matches = function() return false end, execute = function() return false end },
        { name = "Evocation", matches = function() return false end, execute = function() return false end },
        { name = "WintersChill", matches = function() return false end, execute = function() return false end },
        { name = "FrostNova", matches = function() return false end, execute = function() return false end },
        { name = "Blizzard", matches = function() return false end, execute = function() return false end },
        { name = "Frostbolt", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/mage/frost_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/mage/frost_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/mage/frost_forever.lua")
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

local function fresh_state(overrides)
    local s = { in_combat = true, is_moving = false, frostbolt_ready = true }
    if overrides then
        for k, v in pairs(overrides) do s[k] = v end
    end
    return s
end

-- A. Full kit: all three lanes land, the Winter's Chill replacement swaps in
-- place.
do
    learnt = {}
    learnt[19126] = true   -- Ice Lance engraving (rank-1 mirror sentinel)
    learnt[19128] = true   -- Icy Veins (trainer-taught)
    local combined = load_delta({ ["Ice Lance"] = 19126 },
        { ["Ice Lance"] = 19127, ["Icy Veins"] = 19128, ["Frost Nova"] = 19129 },
        { ["Winter's Chill"] = 19130 })
    assert_eq(registered and registered.name, "frost", "A: re-registers the frost playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: +2 lanes, 1 replaced (net +2)")
    assert_true(not find_lane(combined, "WintersChill"), "A: the baseline Winter's Chill lane is replaced")
    assert_eq(find_lane(combined, "Forever_WintersChill"), find_lane(combined, "FrostNova") - 1,
        "A: the replacement takes the baseline slot")
    assert_eq(find_lane(combined, "Forever_IcyVeins"), find_lane(combined, "PresenceOfMind") - 1,
        "A: Icy Veins leads the cooldown block")
    assert_eq(find_lane(combined, "Forever_IceLanceBurst"), find_lane(combined, "Blizzard") - 1,
        "A: the Ice Lance burst leads the damage block")
    assert_eq(find_lane(combined, "IceBarrier"), 1, "A: defensive head lanes untouched")
    learnt = {}
end

-- B. Learned gates: the Ice Lance lane is present but must not MATCH without
-- the engraving; the Icy Veins lane only splices once learned (trainer).
do
    learnt = {}
    local combined = load_delta({ ["Ice Lance"] = 19126 },
        { ["Ice Lance"] = 19127, ["Icy Veins"] = 19128, ["Frost Nova"] = 19129 },
        { ["Winter's Chill"] = 19130 })
    local lance = combined[find_lane(combined, "Forever_IceLanceBurst")]
    local ctx = fresh_ctx()
    local state = fresh_state()
    NS.debuff_remains = function() return 4 end
    assert_true(lance and not lance.matches(ctx, state), "B: Ice Lance never matches without the engraving")
    assert_true(not find_lane(combined, "Forever_IcyVeins"), "B: Icy Veins lane dormant until learned")
    NS.debuff_remains = function() return 0 end
    learnt = {}
    learnt[19128] = true
    local combined2 = load_delta({}, { ["Icy Veins"] = 19128 }, {})
    assert_true(find_lane(combined2, "Forever_IcyVeins"), "B: Icy Veins splices once learned")
    learnt = {}
end

-- B2. Ice Lance matcher: the Frozen window (Frost Nova root) + readiness.
do
    learnt = {}
    learnt[19126] = true
    local combined = load_delta({ ["Ice Lance"] = 19126 },
        { ["Ice Lance"] = 19127, ["Frost Nova"] = 19129 }, {})
    local lance = combined[find_lane(combined, "Forever_IceLanceBurst")]
    local ctx = fresh_ctx()
    local state = fresh_state()

    NS.debuff_remains = function() return 0 end
    assert_true(not lance.matches(ctx, state), "B2: Ice Lance holds without a Frozen window")
    local seen_ids = nil
    NS.debuff_remains = function(unit, ids) seen_ids = ids; return 4 end
    assert_true(lance.matches(ctx, state), "B2: Ice Lance fires inside the Frozen window")
    local has_nova_id = false
    for _, id in ipairs(seen_ids or {}) do
        if id == 10230 then has_nova_id = true end
    end
    assert_true(has_nova_id, "B2: the Frozen probe includes the class-map Frost Nova ranks")
    NS.spell_ready = function() return false end
    assert_true(not lance.matches(ctx, state), "B2: Ice Lance respects readiness")
    NS.spell_ready = function() return true end
    cast_log = {}
    assert_true(lance.execute(ctx, state), "B2: Ice Lance executes")
    learnt = {}
end

-- B3. Winter's Chill replacement: the APPLIED debuff row drives the hold.
do
    learnt = {}
    local combined = load_delta({}, {}, { ["Winter's Chill"] = 19130 })
    local wc = combined[find_lane(combined, "Forever_WintersChill")]
    local ctx = fresh_ctx()
    local state = fresh_state()

    local seen_ids = nil
    NS.debuff_stacks = function(unit, ids) seen_ids = ids; return 2 end
    NS.debuff_remains = function() return 12 end
    assert_true(wc.matches(ctx, state), "B3: Winter's Chill upkeep fires below the stack cap")
    assert_eq(seen_ids and seen_ids[1], 19130, "B3: the stack read uses the buff-mirror debuff id")
    NS.debuff_stacks = function() return 5 end
    assert_true(not wc.matches(ctx, state), "B3: upkeep holds at 5 fresh stacks")
    NS.debuff_remains = function() return 2 end
    assert_true(wc.matches(ctx, state), "B3: upkeep refreshes inside the expiry window")
    local moving = fresh_state({ is_moving = true })
    assert_true(not wc.matches(ctx, moving), "B3: upkeep holds while moving")
    local not_ready = fresh_state({ frostbolt_ready = false })
    assert_true(not wc.matches(ctx, not_ready), "B3: upkeep respects Frostbolt readiness")
    cast_log = {}
    assert_true(wc.execute(ctx, state), "B3: upkeep executes")
end

-- C. Dormancy: empty mirrors -> no delta lanes, baseline WintersChill kept.
do
    learnt = {}
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes on empty mirrors")
    assert_true(find_lane(combined, "WintersChill"), "C: baseline Winter's Chill kept")
    assert_true(not find_lane(combined, "Forever_IceLanceBurst"), "C: Ice Lance dormant")
    assert_true(not find_lane(combined, "Forever_IcyVeins"), "C: Icy Veins dormant")
    assert_true(not find_lane(combined, "Forever_WintersChill"), "C: WC replacement dormant")
end

-- D. Splice fallback: no anchors appends the delta lanes.
do
    FAKE_BASELINE.strategies = {
        { name = "IceBarrier", matches = function() return false end, execute = function() return false end },
    }
    learnt = {}
    learnt[19126] = true
    local combined = load_delta({ ["Ice Lance"] = 19126 },
        { ["Ice Lance"] = 19127, ["Icy Veins"] = 19128, ["Frost Nova"] = 19129 },
        { ["Winter's Chill"] = 19130 })
    assert_eq(find_lane(combined, "Forever_WintersChill"), #combined, "D: WC appends last when no anchor")
    learnt = {}
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/mage/frost_forever.lua", "r")
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

print(string.format("test_mage_frost_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS mage_frost_forever")
