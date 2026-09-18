-- test_priest_discipline_forever.lua -- unit pins for the priest discipline Forever delta.
-- WHAT:  discipline_forever.lua contract: baseline capture + re-register
--        splice (the Soul Warding shield above the shield block, Penance-heal
--        above the heal block, Penance-damage above the idle block), the
--        learn gates, the combined PW:S + Divine Aegis absorb accounting, the
--        Power in Light Holy Fire gate, by-name dormancy, mirror selection,
--        zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Penance is dual-mode (heal on allies, damage on enemies) and carries
--        a 12s category cooldown; the shield loop is only legitimate with
--        Soul Warding (PW:S's 4s category CD is what it removes), and the
--        shield decision must count BOTH absorbs or a fresh Aegis shield gets
--        overwritten by a redundant PW:S.
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
local aegis_points = nil
local pws_absorb = 0
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
        PowerWordShield = { ids = { 10901, 10899, 592 }, name = "PowerWordShield" },
        HolyFire = { _meta = { ids = { 15261, 15262, 14914 } }, name = "HolyFire" },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    debuff_up = function(unit, ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if hf_map[id] then return true end
            end
        end
        return false
    end,
    buff_points = function(unit, id) return aegis_points end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
NS.PriestHealing = {
    pws_absorb_remaining = function(unit) return pws_absorb end,
}
_G.EaxRotations = NS

local FAKE_TANK = { unit = { name = "tank" }, effective_hp = 70, has_weakened_soul = false }
local FAKE_LOWEST = { unit = { name = "lowest" }, effective_hp = 55, has_weakened_soul = false }

local FAKE_BASELINE = {
    name = "discipline",
    strategies = {
        { name = "PowerWordShieldTank", matches = function() return false end, execute = function() return false end },
        { name = "EmergencyPowerWordShield", matches = function() return false end, execute = function() return false end },
        { name = "EmergencyFlashHeal", matches = function() return false end, execute = function() return false end },
        { name = "FriendlyTarget", matches = function() return false end, execute = function() return false end },
        { name = "GreaterHeal", matches = function() return false end, execute = function() return false end },
        { name = "RenewLowest", matches = function() return false end, execute = function() return false end },
        { name = "IdleShadowWordPain", matches = function() return false end, execute = function() return false end },
        { name = "IdleSmite", matches = function() return false end, execute = function() return false end },
        { name = "HolyFire", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/priest/discipline_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/priest/discipline_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/priest/discipline_forever.lua")
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
             me = {}, settings = {}, mana_pct = 80 }
end

local function fresh_state(overrides)
    local s = {
        lowest = { unit = FAKE_LOWEST.unit, effective_hp = 55, has_weakened_soul = false },
        tank = { unit = FAKE_TANK.unit, effective_hp = 70, has_weakened_soul = false },
        pws_ready = true,
        mana_pct = 80,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local PENANCE = 19020
local PENANCE_R1 = 19021
local SOUL_WARDING = 19022
local AEGIS = 19023
local MIRRORS = { ["Penance"] = PENANCE_R1, ["Soul Warding"] = SOUL_WARDING }
local MAXRANK = { ["Penance"] = PENANCE }
local BUFFS = { ["Divine Aegis"] = AEGIS }

-- A. All three lanes live (Penance + Soul Warding learned).
do
    learnt = { [PENANCE] = true, [SOUL_WARDING] = true }
    hf_map = {}
    aegis_points = nil
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "discipline", "A: re-registers the discipline playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 3, "A: 3 delta lanes over 10 baseline lanes")
    assert_eq(find_lane(combined, "Forever_SoulWardingShield"), find_lane(combined, "PowerWordShieldTank") - 1,
        "A: the Soul Warding shield leads the shield block")
    assert_eq(find_lane(combined, "Forever_PenanceHeal"), find_lane(combined, "EmergencyFlashHeal") - 1,
        "A: Penance-heal leads the heal block")
    assert_eq(find_lane(combined, "Forever_PenanceDamage"), find_lane(combined, "IdleSmite") - 1,
        "A: Penance-damage leads the idle block")
end

-- A2. Nothing learned: every delta lane is dormant.
do
    learnt = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_SoulWardingShield"), "A2: shield dormant without Soul Warding")
    assert_true(not find_lane(combined, "Forever_PenanceHeal"), "A2: Penance-heal dormant without the learn")
    assert_true(not find_lane(combined, "Forever_PenanceDamage"), "A2: Penance-damage dormant without the learn")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Shield lane: the Soul Warding loop with combined absorb accounting.
do
    learnt = { [PENANCE] = true, [SOUL_WARDING] = true }
    aegis_points = nil
    pws_absorb = 0
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local shield = combined[find_lane(combined, "Forever_SoulWardingShield")]
    local ctx = fresh_ctx()
    assert_true(shield.matches(ctx, fresh_state()), "B: a hurt tank fires the shield lane")
    local healthy = fresh_state()
    healthy.tank = { unit = FAKE_TANK.unit, effective_hp = 95, has_weakened_soul = false }
    assert_true(not shield.matches(ctx, healthy), "B: a healthy tank holds the shield lane")
    local ws = fresh_state()
    ws.tank = { unit = FAKE_TANK.unit, effective_hp = 70, has_weakened_soul = true }
    assert_true(not shield.matches(ctx, ws), "B: Weakened Soul holds the shield lane")
    local cd = fresh_state()
    cd.pws_ready = false
    assert_true(not shield.matches(ctx, cd), "B: a PW:S on cooldown holds the shield lane")
    -- Combined absorb: a live PW:S (250) + a fresh Aegis (100) covers the
    -- target; either alone does not.
    pws_absorb = 250
    aegis_points = { 100 }
    assert_true(not shield.matches(ctx, fresh_state()), "B: combined absorb over the floor holds the lane")
    aegis_points = nil
    assert_true(shield.matches(ctx, fresh_state()), "B: PW:S absorb alone leaves the lane live")
    pws_absorb = 0
    aegis_points = { 120 }
    assert_true(shield.matches(ctx, fresh_state()), "B: a small Aegis alone leaves the lane live")
    cast_log = {}
    assert_true(shield.execute(ctx, fresh_state()), "B: the shield lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.PriestSpells.PowerWordShield, "B: it casts the class-map PW:S")
    assert_eq(cast_log[1] and cast_log[1].target, FAKE_TANK.unit, "B: the shield lands on the tank")
end

-- B2. Penance-heal: the moderate-damage core button.
do
    learnt = { [PENANCE] = true, [SOUL_WARDING] = true }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local heal = combined[find_lane(combined, "Forever_PenanceHeal")]
    local ctx = fresh_ctx()
    assert_true(heal.matches(ctx, fresh_state()), "B2: a 55% lowest fires Penance-heal")
    local light = fresh_state()
    light.lowest = { unit = FAKE_LOWEST.unit, effective_hp = 80, has_weakened_soul = false }
    assert_true(not heal.matches(ctx, light), "B2: an 80% lowest holds Penance-heal")
    local oom = fresh_state()
    oom.mana_pct = 10
    assert_true(not heal.matches(ctx, oom), "B2: the mana floor holds Penance-heal")
    local moving = fresh_ctx()
    moving.is_moving = true
    assert_true(not heal.matches(moving, fresh_state()), "B2: movement holds the channel")
    cast_log = {}
    assert_true(heal.execute(ctx, fresh_state()), "B2: Penance-heal executes")
    assert_eq(cast_log[1] and cast_log[1].spell, PENANCE, "B2: the maxrank Penance id is cast")
    assert_eq(cast_log[1] and cast_log[1].target, FAKE_LOWEST.unit, "B2: the heal lands on the lowest ally")
end

-- B3. Penance-damage: the Power in Light window in the idle block.
do
    learnt = { [PENANCE] = true, [SOUL_WARDING] = true }
    hf_map = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local dmg = combined[find_lane(combined, "Forever_PenanceDamage")]
    local ctx = fresh_ctx()
    local healthy_state = fresh_state()
    healthy_state.lowest = { unit = FAKE_LOWEST.unit, effective_hp = 100, has_weakened_soul = false }
    assert_true(not dmg.matches(ctx, healthy_state), "B3: no Holy Fire = no offensive Penance")
    hf_map = { [15261] = true }
    assert_true(dmg.matches(ctx, healthy_state), "B3: Holy Fire up fires the offensive lane")
    local hurt_group = fresh_state()
    assert_true(not dmg.matches(ctx, hurt_group), "B3: a hurt ally holds the offensive lane")
    local oom = fresh_state()
    oom.mana_pct = 20
    assert_true(not dmg.matches(ctx, oom), "B3: the idle mana floor holds the lane")
    cast_log = {}
    assert_true(dmg.execute(ctx, healthy_state), "B3: the offensive lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, PENANCE, "B3: the same cast row deals the damage")
    assert_eq(cast_log[1] and cast_log[1].target, ctx.target, "B3: the damage lands on the enemy")
end

-- C. Dormancy: empty mirrors leave every lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_SoulWardingShield"), "C: shield dormant")
    assert_true(not find_lane(combined, "Forever_PenanceHeal"), "C: Penance-heal dormant")
    assert_true(not find_lane(combined, "Forever_PenanceDamage"), "C: Penance-damage dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the primary anchors the lanes append.
do
    learnt = { [PENANCE] = true, [SOUL_WARDING] = true }
    local shrunk = {
        name = "discipline",
        strategies = {
            { name = "GreaterHeal", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 4, "D: the three lanes appended without anchors")
    assert_eq(find_lane(combined, "Forever_SoulWardingShield"), 2, "D: the shield lane appended first")
    assert_eq(find_lane(combined, "Forever_PenanceHeal"), 3, "D: Penance-heal appended second")
    assert_eq(find_lane(combined, "Forever_PenanceDamage"), 4, "D: Penance-damage appended last")
end

-- G. Mirror selection: the cast reads maxrank, the learn gate the rank-1
-- mirror, the Aegis absorb the buff mirror.
do
    learnt = { [PENANCE] = true, [SOUL_WARDING] = true }
    local no_max = load_delta(MIRRORS, {}, BUFFS)
    assert_true(not find_lane(no_max, "Forever_PenanceHeal"), "G: no maxrank = dormant Penance lanes")
    local no_buff = load_delta(MIRRORS, MAXRANK, {})
    assert_true(find_lane(no_buff, "Forever_SoulWardingShield") ~= nil,
        "G: the shield lane lives without the Aegis row (absorb accounting reads 0)")
    local rank1_learn = load_delta(MIRRORS, MAXRANK, BUFFS)
    local heal = rank1_learn[find_lane(rank1_learn, "Forever_PenanceHeal")]
    aegis_points = nil
    pws_absorb = 0
    cast_log = {}
    assert_true(heal.execute(fresh_ctx(), fresh_state()), "G: the rank-1 learn gate keeps the cast lane live")
    assert_eq(cast_log[1] and cast_log[1].spell, PENANCE, "G: the maxrank sentinel is the cast id")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/priest/discipline_forever.lua", "rb")
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

print("test_priest_discipline_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS priest_discipline_forever")
