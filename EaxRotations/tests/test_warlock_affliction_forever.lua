-- test_warlock_affliction_forever.lua -- unit pins for the warlock affliction Forever delta.
-- WHAT:  affliction_forever.lua contract: baseline capture + re-register
--        splice (Wrack/Haunt/Unstable Affliction above the baseline's dot
--        block), the engraving-known gating, the UA/Immolate slot drop,
--        by-name dormancy, matcher gates, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Wrack is the beta client's amplify DoT (the kit's "Drain Hope" does
--        not exist); Haunt/UA are engraving-granted — a lane that fires
--        without the engraving would cast an unlearned spell, and a UA lane
--        that leaves the baseline Immolate lane live churns the shared
--        one-per-warlock slot.
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
    WarlockSpells = {},
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    debuff_remains = function() return 0 end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "affliction",
    strategies = {
        { name = "PetDefensive", matches = function() return false end, execute = function() return false end },
        { name = "Healthstone", matches = function() return false end, execute = function() return false end },
        { name = "DrainLife", matches = function() return false end, execute = function() return false end },
        { name = "CorruptionDoT", matches = function() return false end, execute = function() return false end },
        { name = "SiphonLife", matches = function() return false end, execute = function() return false end },
        { name = "ImmolateDoT", matches = function() return false end, execute = function() return false end },
        { name = "DrainSoulExecute", matches = function() return false end, execute = function() return false end },
        { name = "ShadowBoltFiller", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/warlock/affliction_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/warlock/affliction_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/warlock/affliction_forever.lua")
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

-- A. Wrack only (no engravings learned): one delta lane above the dot block.
do
    learnt = {}
    local combined = load_delta({}, { ["Wrack"] = 19120 }, {})
    assert_eq(registered and registered.name, "affliction", "A: re-registers the affliction playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: Wrack only (no engraving-gated lanes)")
    assert_eq(find_lane(combined, "Forever_Wrack"), find_lane(combined, "CorruptionDoT") - 1,
        "A: Wrack leads the dot block")
    assert_true(not find_lane(combined, "Forever_Haunt"), "A: Haunt dormant without the engraving")
    assert_true(not find_lane(combined, "Forever_UnstableAffliction"), "A: UA dormant without the engraving")
    assert_true(find_lane(combined, "ImmolateDoT"), "A: Immolate kept while UA is not learned")
end

-- A2. Engravings learned: Haunt + UA splice in, the UA/Immolate slot drops
-- the baseline Immolate lane.
do
    learnt = {}
    learnt[19121] = true
    learnt[19122] = true
    local combined = load_delta({}, { ["Wrack"] = 19120, ["Haunt"] = 19121, ["Unstable Affliction"] = 19122 }, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies + 3 - 1, "A2: 3 delta lanes, 1 baseline lane dropped")
    assert_true(not find_lane(combined, "ImmolateDoT"), "A2: ImmolateDoT dropped under UA (shared slot)")
    assert_eq(find_lane(combined, "Forever_Wrack"), find_lane(combined, "CorruptionDoT") - 3,
        "A2: Wrack leads the delta block")
    assert_eq(find_lane(combined, "Forever_Haunt"), find_lane(combined, "Forever_Wrack") + 1,
        "A2: Haunt follows Wrack")
    assert_eq(find_lane(combined, "Forever_UnstableAffliction"), find_lane(combined, "Forever_Wrack") + 2,
        "A2: UA follows Haunt, then the baseline dots")
    learnt = {}
end

-- B. Matcher behavior: dot refresh windows + the Haunt cooldown declaration.
do
    local combined = load_delta({}, { ["Wrack"] = 19120 }, {})
    local state = { in_combat = true }
    local ctx = fresh_ctx()

    local wrack = combined[find_lane(combined, "Forever_Wrack")]
    NS.debuff_remains = function() return 0 end
    assert_true(wrack.matches(ctx, state), "B: Wrack fires when the dot is missing")
    NS.debuff_remains = function() return 8 end
    assert_true(not wrack.matches(ctx, state), "B: Wrack holds while the dot is fresh")
    NS.debuff_remains = function() return 1 end
    assert_true(wrack.matches(ctx, state), "B: Wrack refreshes inside the window")
    NS.debuff_remains = function() return 0 end
    local no_target = fresh_ctx()
    no_target.has_valid_enemy_target = false
    assert_true(not wrack.matches(no_target, state), "B: Wrack needs a valid enemy")
    cast_log = {}
    assert_true(wrack.execute(ctx, state), "B: Wrack executes")
end

-- B2. Haunt matcher: engraving gate + the 15s cooldown declaration.
do
    learnt = {}
    learnt[19121] = true
    local combined = load_delta({}, { ["Haunt"] = 19121 }, {})
    local state = { in_combat = true }
    local ctx = fresh_ctx()
    local haunt = combined[find_lane(combined, "Forever_Haunt")]

    local seen_opts = nil
    local orig_ready = NS.spell_ready
    NS.spell_ready = function(spell, target, opts) seen_opts = opts; return true end
    assert_true(haunt.matches(ctx, state), "B2: Haunt fires with the engraving learned")
    assert_eq(seen_opts and seen_opts.expected_cooldown, 15, "B2: Haunt declares the 15s cooldown")
    NS.spell_ready = orig_ready
    cast_log = {}
    assert_true(haunt.execute(ctx, state), "B2: Haunt executes")
    learnt = {}
end

-- C. Dormancy: no delta lanes on empty mirrors; no drop either.
do
    learnt = {}
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes on empty mirrors")
    assert_true(not find_lane(combined, "Forever_Wrack"), "C: Wrack dormant")
    assert_true(find_lane(combined, "ImmolateDoT"), "C: Immolate kept with no UA lookup")
    assert_eq(find_lane(combined, "CorruptionDoT"), 4, "C: baseline order unchanged")
end

-- D. Splice fallback: no CorruptionDoT/SiphonLife anchor appends.
do
    FAKE_BASELINE.strategies = {
        { name = "PetDefensive", matches = function() return false end, execute = function() return false end },
    }
    learnt = {}
    local combined = load_delta({}, { ["Wrack"] = 19120 }, {})
    assert_eq(find_lane(combined, "Forever_Wrack"), #combined, "D: Wrack appends when anchors are absent")
end

-- G. Mirror selection: Wrack casts the maxrank sentinel; the engraving gate
-- reads both mirror ids (a rank-1 engraving grants the rank-1 row).
do
    learnt = {}
    learnt[19122] = true
    local combined = load_delta({ ["Unstable Affliction"] = 19022 },
        { ["Wrack"] = 19120, ["Unstable Affliction"] = 19122 }, {})
    local state = { in_combat = true }
    local ctx = fresh_ctx()

    local wrack = combined[find_lane(combined, "Forever_Wrack")]
    cast_log = {}
    assert_true(wrack.execute(ctx, state), "G: Wrack executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19120, "G: Wrack casts the maxrank sentinel")

    local ua = combined[find_lane(combined, "Forever_UnstableAffliction")]
    assert_true(ua ~= nil, "G: UA lane live on the rank-1 engraving id (by_name mirror)")
    cast_log = {}
    assert_true(ua.execute(ctx, state), "G: UA executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19122, "G: UA casts the maxrank sentinel")
    learnt = {}
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/warlock/affliction_forever.lua", "r")
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

print(string.format("test_warlock_affliction_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS warlock_affliction_forever")
