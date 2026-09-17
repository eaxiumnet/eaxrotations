-- test_hunter_beast_mastery_forever.lua -- unit pins for the hunter BM Forever delta.
-- WHAT:  beast_mastery_forever.lua contract: baseline capture + re-register
--        splice (hawk lane above the Arcane Shot filler), by-name dormancy,
--        matcher gates, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   the hawk is the shared-cooldown decision (hawk vs Arcane Shot); if
--        the lane loses its place above ArcaneShot, the shared 6s CD spends
--        on the filler and hawks never cycle; if it loses its dormancy
--        contract, a bridge miss would cast a guessed id.
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
    HunterSpells = {},
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "beast_mastery",
    strategies = {
        { name = "PetDefensive", matches = function() return false end, execute = function() return false end },
        { name = "MendPet", matches = function() return false end, execute = function() return false end },
        { name = "BestialWrath", matches = function() return false end, execute = function() return false end },
        { name = "AimedShot", matches = function() return false end, execute = function() return false end },
        { name = "MultiShot", matches = function() return false end, execute = function() return false end },
        { name = "ArcaneShot", matches = function() return false end, execute = function() return false end },
        { name = "SerpentSting", matches = function() return false end, execute = function() return false end },
        { name = "RaptorStrike", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/hunter/beast_mastery_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/hunter/beast_mastery_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/hunter/beast_mastery_forever.lua")
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

-- A. Full kit: hawk lane immediately above ArcaneShot; nothing else moved.
do
    local combined = load_delta({}, { ["Summon Hawk"] = 19117 }, {})
    assert_eq(registered and registered.name, "beast_mastery", "A: re-registers the beast_mastery playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 8 baseline lanes")
    assert_eq(find_lane(combined, "Forever_SummonHawk"), find_lane(combined, "ArcaneShot") - 1,
        "A: hawk sits just above the Arcane Shot filler it shares a cooldown with")
    assert_eq(find_lane(combined, "PetDefensive"), 1, "A: pet/utility head lanes untouched")
    assert_true(find_lane(combined, "AimedShot") < find_lane(combined, "Forever_SummonHawk"),
        "A: the shot lanes keep their priority above the hawk")
end

-- B. Matcher behavior: combat, valid enemy, mana floor, readiness.
do
    local combined = load_delta({}, { ["Summon Hawk"] = 19117 }, {})
    local state = { in_combat = true, mana_pct = 80 }
    local ctx = fresh_ctx()

    local hawk = combined[find_lane(combined, "Forever_SummonHawk")]
    assert_true(hawk.matches(ctx, state), "B: hawk fires in combat with a valid enemy")
    local ooc = { in_combat = false, mana_pct = 80 }
    assert_true(not hawk.matches(ctx, ooc), "B: hawk needs combat")
    local no_target = fresh_ctx()
    no_target.has_valid_enemy_target = false
    assert_true(not hawk.matches(no_target, state), "B: hawk needs a valid enemy")
    state.mana_pct = 5
    assert_true(not hawk.matches(ctx, state), "B: hawk respects the mana floor")
    state.mana_pct = 80
    local seen_opts = nil
    local orig_ready = NS.spell_ready
    NS.spell_ready = function(spell, target, opts) seen_opts = opts; return true end
    assert_true(hawk.matches(ctx, state), "B: hawk passes the readiness check")
    assert_eq(seen_opts and seen_opts.expected_cooldown, 6, "B: hawk declares the shared 6s cooldown")
    NS.spell_ready = orig_ready
    cast_log = {}
    assert_true(hawk.execute(ctx, state), "B: hawk executes")
end

-- C. Dormancy on nil lookups: no hawk lane on empty mirrors.
do
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes on empty mirrors")
    assert_true(not find_lane(combined, "Forever_SummonHawk"), "C: hawk dormant")
    assert_eq(find_lane(combined, "ArcaneShot"), 6, "C: baseline order unchanged")
end

-- D. Splice fallback: no ArcaneShot/SerpentSting anchor appends.
do
    FAKE_BASELINE.strategies = {
        { name = "PetDefensive", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({}, { ["Summon Hawk"] = 19117 }, {})
    assert_eq(find_lane(combined, "Forever_SummonHawk"), #combined, "D: hawk appends when anchors are absent")
end

-- G. Mirror selection: the hawk lane casts the maxrank sentinel.
do
    local combined = load_delta({}, { ["Summon Hawk"] = 19117 }, {})
    local state = { in_combat = true, mana_pct = 80 }
    local ctx = fresh_ctx()
    local hawk = combined[find_lane(combined, "Forever_SummonHawk")]
    cast_log = {}
    assert_true(hawk.execute(ctx, state), "G: hawk executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19117, "G: hawk casts the maxrank sentinel")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/hunter/beast_mastery_forever.lua", "r")
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

print(string.format("test_hunter_beast_mastery_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS hunter_beast_mastery_forever")
