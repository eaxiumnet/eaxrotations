-- test_rogue_assassination_forever.lua -- unit pins for the rogue assassination Forever delta.
-- WHAT:  assassination_forever.lua contract: baseline capture + re-register
--        splice (Mutilate above the builder, Venom above the finisher block,
--        Improved Expose Armor above the baseline's ExposeArmor), the dagger
--        eligibility gate, the poison label read, the Venom CP/refresh
--        window, the assignment/refund gates, by-name dormancy, mirror
--        selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Mutilate without the dagger gate would fail every cast (both
--        weapons required) and stall the builder; Venom without the CP gate
--        would burn finishers at low duration; Improved Expose Armor without
--        the 5-CP refund condition would pay full price for the debuff the
--        talent exists to make cheap.
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
local player_buffs = {}
local target_debuffs = {}
local equipped = { main = 0, off = 0 }
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = { name = "me" },
    EQUIPMENT_SLOTS = { MAIN_HAND = 16, OFF_HAND = 17 },
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    RogueSpells = {
        ExposeArmor = { _meta = { ids = { 11198, 11197, 8650, 8647 } }, name = "ExposeArmor" },
        SinisterStrike = { ids = { 26862, 11294, 1752 }, name = "SinisterStrike" },
        SliceAndDice = { ids = { 6774, 5171 }, name = "SliceAndDice" },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    has_player_buff = function(id) return player_buffs[id] ~= nil end,
    buff_remains = function(unit, id) return player_buffs[id] or 0 end,
    debuff_up = function(unit, ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if target_debuffs[id] ~= nil then return true end
            end
        elseif type(ids) == "number" then
            return target_debuffs[ids] ~= nil
        end
        return false
    end,
    debuff_remains = function(unit, ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if target_debuffs[id] then return target_debuffs[id] end
            end
        elseif type(ids) == "number" then
            return target_debuffs[ids] or 0
        end
        return 0
    end,
    get_equipped_item_id = function(slot)
        -- literal slot ids (the local NS is not yet in scope inside its own
        -- table constructor): 16 = MAIN_HAND, 17 = OFF_HAND.
        if slot == 16 then return equipped.main end
        if slot == 17 then return equipped.off end
        return 0
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "assassination",
    strategies = {
        { name = "ColdBloodEviscerate", matches = function() return false end, execute = function() return false end },
        { name = "SliceAndDice", matches = function() return false end, execute = function() return false end },
        { name = "RuptureBleed", matches = function() return false end, execute = function() return false end },
        { name = "KidneyShotCC", matches = function() return false end, execute = function() return false end },
        { name = "LevelingSinisterStrike", matches = function() return false end, execute = function() return false end },
        { name = "EviscerateFallback", matches = function() return false end, execute = function() return false end },
        { name = "ExposeArmor", matches = function() return false end, execute = function() return false end },
        { name = "Stealth", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/rogue/assassination_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/rogue/assassination_vanilla' not found", 0)
    end
    if path == "shared/dagger_set_sylvanas" then
        return { is_dagger = { [100] = true, [101] = true } }
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/rogue/assassination_forever.lua")
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
             me = {}, settings = {}, target_armor = 1000 }
end

local function fresh_state(overrides)
    local s = {
        stealth_active = false,
        combo = 5,
        energy = 100,
        energy_pool_finisher = false,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local MUTILATE = 19030
local MUTILATE_R1 = 19031
local VENOM = 19032
local IEA = 19033
local EA = 19034
local DEADLY = 19035
local VENOM_BUFF = 19036
local MIRRORS = { ["Mutilate"] = MUTILATE_R1, ["Improved Expose Armor"] = IEA }
local MAXRANK = { ["Mutilate"] = MUTILATE, ["Venom"] = VENOM, ["Expose Armor"] = EA }
local BUFFS = { ["Venom"] = VENOM_BUFF, ["Deadly Poison"] = DEADLY }

-- A. All three lanes live.
do
    learnt = { [MUTILATE] = true, [IEA] = true }
    player_buffs = {}
    target_debuffs = {}
    equipped = { main = 100, off = 101 }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "assassination", "A: re-registers the assassination playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 3, "A: 3 delta lanes over 8 baseline lanes")
    assert_eq(find_lane(combined, "Forever_Mutilate"), find_lane(combined, "LevelingSinisterStrike") - 1,
        "A: Mutilate leads the builder")
    assert_eq(find_lane(combined, "Forever_Venom"), find_lane(combined, "SliceAndDice") - 1,
        "A: Venom leads the finisher block")
    assert_eq(find_lane(combined, "Forever_ImprovedExposeArmor"), find_lane(combined, "ExposeArmor") - 1,
        "A: Improved Expose Armor leads the armor lane")
end

-- A2. Nothing learned: every delta lane is dormant.
do
    learnt = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_Mutilate"), "A2: Mutilate dormant without the learn")
    assert_true(not find_lane(combined, "Forever_ImprovedExposeArmor"), "A2: IEA dormant without the talent")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A2: Venom is learn-independent (trainer row)")
end

-- B. Mutilate matcher: daggers + energy + the builder window; the poison
-- state is reported, not gated.
do
    learnt = { [MUTILATE] = true, [IEA] = true }
    player_buffs = {}
    target_debuffs = {}
    equipped = { main = 100, off = 101 }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local mutilate = combined[find_lane(combined, "Forever_Mutilate")]
    local ctx = fresh_ctx()
    assert_true(mutilate.matches(ctx, fresh_state({ combo = 0 })), "B: 2 daggers + energy fires Mutilate")
    equipped = { main = 100, off = 0 }
    assert_true(not mutilate.matches(ctx, fresh_state({ combo = 0 })), "B: a missing off-hand dagger holds the lane")
    equipped = { main = 0, off = 101 }
    assert_true(not mutilate.matches(ctx, fresh_state({ combo = 0 })), "B: a missing main-hand dagger holds the lane")
    equipped = { main = 100, off = 101 }
    assert_true(not mutilate.matches(ctx, fresh_state({ combo = 0, energy = 50 })), "B: the energy cost gate holds")
    assert_true(not mutilate.matches(ctx, fresh_state({ combo = 5 })), "B: never overbuild past a finisher")
    assert_true(not mutilate.matches(ctx, fresh_state({ combo = 0, stealth_active = true })), "B: stealth prefers the opener")
    cast_log = {}
    assert_true(mutilate.execute(ctx, fresh_state({ combo = 0 })), "B: Mutilate executes")
    assert_eq(cast_log[1] and cast_log[1].spell, MUTILATE, "B: the maxrank Mutilate id is cast")
    assert_true(cast_log[1] and cast_log[1].reason:find("Mutilate", 1, true) ~= nil, "B: the cast is labelled")
    target_debuffs = { [DEADLY] = 3 }
    cast_log = {}
    assert_true(mutilate.execute(ctx, fresh_state({ combo = 0 })), "B: the poisoned branch executes")
    assert_true(cast_log[1] and cast_log[1].reason:find("poisoned", 1, true) ~= nil, "B: the poisoned tag is reported")
end

-- B2. Venom matcher: the CP-scaled window.
do
    learnt = { [MUTILATE] = true, [IEA] = true }
    player_buffs = {}
    target_debuffs = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local venom = combined[find_lane(combined, "Forever_Venom")]
    local ctx = fresh_ctx()
    assert_true(venom.matches(ctx, fresh_state()), "B2: 5 cp + no window fires Venom")
    assert_true(not venom.matches(ctx, fresh_state({ combo = 3 })), "B2: the CP gate holds")
    assert_true(not venom.matches(ctx, fresh_state({ energy_pool_finisher = true })), "B2: energy pooling holds Venom")
    player_buffs = { [VENOM_BUFF] = 10 }
    assert_true(not venom.matches(ctx, fresh_state()), "B2: a fresh window holds Venom")
    player_buffs = { [VENOM_BUFF] = 2 }
    assert_true(venom.matches(ctx, fresh_state()), "B2: an expiring window refreshes Venom")
    cast_log = {}
    player_buffs = {}
    assert_true(venom.execute(ctx, fresh_state()), "B2: Venom executes")
    assert_eq(cast_log[1] and cast_log[1].spell, VENOM, "B2: the maxrank Venom id is cast")
    assert_eq(cast_log[1] and cast_log[1].target, ctx.target, "B2: Venom is a target finisher")
end

-- B3. Improved Expose Armor: the assignment + refund gates.
do
    learnt = { [MUTILATE] = true, [IEA] = true }
    player_buffs = {}
    target_debuffs = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local iea = combined[find_lane(combined, "Forever_ImprovedExposeArmor")]
    local ctx = fresh_ctx()
    assert_true(not iea.matches(ctx, fresh_state()), "B3: the assignment gate holds")
    ctx.settings = { assassin_expose_assigned = true }
    assert_true(iea.matches(ctx, fresh_state()), "B3: assigned + 5 cp fires the cheap Expose Armor")
    assert_true(not iea.matches(ctx, fresh_state({ combo = 4 })), "B3: the 5-cp refund condition holds")
    ctx.has_sunder = true
    assert_true(not iea.matches(ctx, fresh_state()), "B3: a Sunder Armor conflicts")
    ctx.has_sunder = false
    ctx.target_armor = 0
    assert_true(not iea.matches(ctx, fresh_state()), "B3: an armor-less target holds")
    ctx.target_armor = 1000
    target_debuffs = { [11198] = 10 }
    assert_true(not iea.matches(ctx, fresh_state()), "B3: a fresh Expose Armor holds")
    target_debuffs = { [11198] = 2 }
    cast_log = {}
    assert_true(iea.matches(ctx, fresh_state()), "B3: an expiring Expose Armor refreshes")
    assert_true(iea.execute(ctx, fresh_state()), "B3: IEA executes")
    assert_eq(cast_log[1] and cast_log[1].spell, EA, "B3: the maxrank Expose Armor id is cast")
end

-- C. Dormancy: empty mirrors leave every lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_Mutilate"), "C: Mutilate dormant")
    assert_true(not find_lane(combined, "Forever_Venom"), "C: Venom dormant")
    assert_true(not find_lane(combined, "Forever_ImprovedExposeArmor"), "C: IEA dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the primary anchors the lanes append.
do
    learnt = { [MUTILATE] = true, [IEA] = true }
    local shrunk = {
        name = "assassination",
        strategies = {
            { name = "Stealth", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 4, "D: the three lanes appended without anchors")
    assert_eq(find_lane(combined, "Forever_Mutilate"), 2, "D: Mutilate appended first")
    assert_eq(find_lane(combined, "Forever_Venom"), 3, "D: Venom appended second")
    assert_eq(find_lane(combined, "Forever_ImprovedExposeArmor"), 4, "D: IEA appended last")
end

-- G. Mirror selection: casts read the maxrank mirror, learn gates the
-- rank-1 mirror, the Venom window the buff mirror.
do
    learnt = { [MUTILATE] = true, [IEA] = true }
    equipped = { main = 100, off = 101 }
    local no_max = load_delta(MIRRORS, {}, BUFFS)
    assert_true(not find_lane(no_max, "Forever_Mutilate"), "G: no maxrank = dormant Mutilate")
    assert_true(not find_lane(no_max, "Forever_Venom"), "G: no maxrank = dormant Venom")
    assert_true(not find_lane(no_max, "Forever_ImprovedExposeArmor"), "G: no maxrank = dormant IEA")
    local no_buff = load_delta(MIRRORS, MAXRANK, {})
    assert_true(not find_lane(no_buff, "Forever_Venom"), "G: no buff mirror = dormant Venom")
    local live = load_delta(MIRRORS, MAXRANK, BUFFS)
    local mutilate = live[find_lane(live, "Forever_Mutilate")]
    cast_log = {}
    assert_true(mutilate.execute(fresh_ctx(), fresh_state({ combo = 0 })), "G: the rank-1 learn gate keeps the cast live")
    assert_eq(cast_log[1] and cast_log[1].spell, MUTILATE, "G: the maxrank sentinel is the cast id")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/rogue/assassination_forever.lua", "rb")
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

print("test_rogue_assassination_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS rogue_assassination_forever")
