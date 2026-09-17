-- test_warlock_demonology_forever.lua -- unit pins for the warlock demonology Forever delta.
-- WHAT:  demonology_forever.lua contract: baseline capture + re-register
--        splice (the Demonic Pact partner lane above FelDomination, the
--        Decimation lane above ShadowBoltFiller), the pact-learned gate, the
--        sacrifice-aura -> summon mapping, by-name dormancy, matcher gates,
--        zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Demonic Pact's persistence rule (client text) is the only thing
--        making a fighting pet + sacrifice aura coexist; a partner lane that
--        guessed the summon would either cancel the buff (the sacrificed
--        pet) or cast an unlearned spell. Decimation's applied proc (440873)
--        differs from its talent row (440870) — reading the wrong id would
--        leave the Soul Fire lane permanently dormant.
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
local auras = {}
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    WarlockSpells = { SoulFire = { ids = { 30545, 17924, 6353 }, name = "SoulFire" } },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    buff_up = function(unit, ids) return auras[ids] == true end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "demonology",
    strategies = {
        { name = "PetDefensive", matches = function() return false end, execute = function() return false end },
        { name = "Healthstone", matches = function() return false end, execute = function() return false end },
        { name = "FelDomination", matches = function() return false end, execute = function() return false end },
        { name = "HealthFunnel", matches = function() return false end, execute = function() return false end },
        { name = "CorruptionDoT", matches = function() return false end, execute = function() return false end },
        { name = "DrainSoulExecute", matches = function() return false end, execute = function() return false end },
        { name = "ShadowBoltFiller", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/warlock/demonology_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/warlock/demonology_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/warlock/demonology_forever.lua")
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

local PACT = 90033
local DECIMATION = 90034
local BURNING_SHADOW = 90035
local TOUCH_OF_FIRE = 90036
local SUMMON_IMP = 90037
local SUMMON_SUCCUBUS = 90038
local MIRRORS = { ["Demonic Pact"] = PACT }
local BUFFS = { ["Burning Shadow"] = BURNING_SHADOW, ["Touch of Fire"] = TOUCH_OF_FIRE,
                ["Decimation"] = DECIMATION }
local SUMMONS = { ["Summon Imp"] = SUMMON_IMP, ["Summon Succubus"] = SUMMON_SUCCUBUS }

-- A. Both lanes live (pact learned): the partner above FelDomination, the
-- Decimation lane above ShadowBoltFiller.
do
    learnt = { [PACT] = true }
    auras = {}
    local combined = load_delta(MIRRORS, SUMMONS, BUFFS)
    assert_eq(registered and registered.name, "demonology", "A: re-registers the demonology playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: 2 delta lanes over 8 baseline lanes")
    assert_eq(find_lane(combined, "Forever_DemonicPactPartner"), find_lane(combined, "FelDomination") - 1,
        "A: the partner lane leads the pet block")
    assert_eq(find_lane(combined, "Forever_Decimation"), find_lane(combined, "ShadowBoltFiller") - 1,
        "A: Decimation sits above the Shadow Bolt filler")
end

-- A2. Pact not learned: the partner lane is dormant, Decimation stays live.
do
    learnt = {}
    local combined = load_delta(MIRRORS, SUMMONS, BUFFS)
    assert_true(not find_lane(combined, "Forever_DemonicPactPartner"), "A2: partner dormant without the talent")
    assert_true(find_lane(combined, "Forever_Decimation") ~= nil, "A2: Decimation is talent-independent")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A2: one delta lane only")
end

-- B. Partner matcher: petless + sacrifice aura -> the OTHER demon.
do
    learnt = { [PACT] = true }
    auras = {}
    local combined = load_delta(MIRRORS, SUMMONS, BUFFS)
    local partner = combined[find_lane(combined, "Forever_DemonicPactPartner")]
    local ctx = fresh_ctx()
    assert_true(not partner.matches(ctx, { has_pet = false }), "B: no aura = no partner lane")
    auras = { [BURNING_SHADOW] = true }
    assert_true(not partner.matches(ctx, { has_pet = true }), "B: a living demon holds the lane")
    assert_true(partner.matches(ctx, { has_pet = false }), "B: Burning Shadow + no pet fires the lane")
    cast_log = {}
    assert_true(partner.execute(ctx, { has_pet = false }), "B: the partner lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, SUMMON_SUCCUBUS,
        "B: sacrificed Imp (+Shadow) summons the Succubus")
    assert_eq(cast_log[1] and cast_log[1].target, ctx.me, "B: the summon targets the warlock")
    auras = { [TOUCH_OF_FIRE] = true }
    cast_log = {}
    assert_true(partner.matches(ctx, { has_pet = false }), "B: Touch of Fire + no pet fires the lane")
    assert_true(partner.execute(ctx, { has_pet = false }), "B: the partner lane executes (fire branch)")
    assert_eq(cast_log[1] and cast_log[1].spell, SUMMON_IMP,
        "B: sacrificed Succubus (+Fire) summons the Imp")
end

-- B2. Decimation matcher: the proc buff gates Soul Fire.
do
    auras = {}
    local combined = load_delta(MIRRORS, SUMMONS, BUFFS)
    local decimation = combined[find_lane(combined, "Forever_Decimation")]
    local ctx = fresh_ctx()
    assert_true(not decimation.matches(ctx, {}), "B2: no proc = no Soul Fire lane")
    assert_true(not decimation.matches({ has_valid_enemy_target = false }, {}), "B2: needs a valid enemy")
    auras = { [DECIMATION] = true }
    assert_true(decimation.matches(ctx, {}), "B2: proc up + target fires the lane")
    cast_log = {}
    assert_true(decimation.execute(ctx, {}), "B2: the Decimation lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.WarlockSpells.SoulFire,
        "B2: the lane spends the window with Soul Fire")
    assert_eq(cast_log[1] and cast_log[1].target, ctx.target, "B2: Soul Fire lands on the target")
end

-- C. Dormancy: empty mirrors leave both lanes out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_DemonicPactPartner"), "C: partner dormant")
    assert_true(not find_lane(combined, "Forever_Decimation"), "C: Decimation dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the primary anchors the lanes append.
do
    learnt = { [PACT] = true }
    local shrunk = {
        name = "demonology",
        strategies = {
            { name = "CorruptionDoT", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, SUMMONS, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 3, "D: both lanes appended without anchors")
    assert_eq(find_lane(combined, "Forever_DemonicPactPartner"), 2, "D: partner appended first")
    assert_eq(find_lane(combined, "Forever_Decimation"), 3, "D: Decimation appended second")
end

-- G. Mirror selection: the summon casts read the maxrank mirror, the aura
-- gates read the buff mirror, the talent gate reads the rank-1 mirror.
do
    learnt = { [PACT] = true }
    auras = { [BURNING_SHADOW] = true }
    local rank1_only = load_delta(MIRRORS, SUMMONS, BUFFS)
    local partner = rank1_only[find_lane(rank1_only, "Forever_DemonicPactPartner")]
    cast_log = {}
    assert_true(partner.execute(fresh_ctx(), { has_pet = false }), "G: partner executes on sentinel ids")
    assert_eq(cast_log[1] and cast_log[1].spell, SUMMON_SUCCUBUS, "G: the maxrank mirror id is cast")
    -- Without the maxrank summon entry the lane stays dormant.
    local no_summon = load_delta(MIRRORS, {}, BUFFS)
    assert_true(not find_lane(no_summon, "Forever_DemonicPactPartner"),
        "G: no maxrank summon = dormant partner (no rank-1 fallback guess)")
    -- Without the buff mirror entry Decimation is dormant.
    local no_buff = load_delta(MIRRORS, SUMMONS, { ["Burning Shadow"] = BURNING_SHADOW, ["Touch of Fire"] = TOUCH_OF_FIRE })
    assert_true(not find_lane(no_buff, "Forever_Decimation"), "G: no buff mirror entry = dormant Decimation")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/warlock/demonology_forever.lua", "rb")
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

print("test_warlock_demonology_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS warlock_demonology_forever")
