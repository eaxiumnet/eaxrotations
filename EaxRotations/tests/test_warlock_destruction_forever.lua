-- test_warlock_destruction_forever.lua -- unit pins for the warlock destruction Forever delta.
-- WHAT:  destruction_forever.lua contract: baseline capture + re-register
--        splice (Bane of Havoc above the curses, the Shadow and Flame window
--        lane + Incinerate above Shadow Bolt), the learn gates, the
--        off-target Bane scan, the window school pick, by-name dormancy,
--        mirror selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Incinerate without the Immolate gate would be cast at a discount
--        damage (the +25% dummy misses) and without the learned gate a
--        mid-level character would stall on an unlearned max-rank id; the
--        Bane scan must respect the one-Bane limit and never bane the focus
--        target (damage to others is what mirrors).
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
local enemy_debuffs = {}
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    WarlockSpells = { ShadowBolt = { ids = { 27209, 11661, 686 }, name = "ShadowBolt" } },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    buff_up = function(unit, ids) return auras[ids] == true end,
    debuff_up = function(unit, ids) return enemy_debuffs[unit] == ids end,
    is_spell_learned = function(id) return learnt[id] == true end,
    same_unit = function(a, b) return a == b end,
}
_G.EaxRotations = NS

local FAKE_TARGET = { name = "focus" }
local FAKE_OFFTARGET = { name = "add" }

local FAKE_BASELINE = {
    name = "destruction",
    strategies = {
        { name = "DemonArmor", matches = function() return false end, execute = function() return false end },
        { name = "LifeTap", matches = function() return false end, execute = function() return false end },
        { name = "CurseOfDoom", matches = function() return false end, execute = function() return false end },
        { name = "CurseOfAgony", matches = function() return false end, execute = function() return false end },
        { name = "Corruption", matches = function() return false end, execute = function() return false end },
        { name = "Immolate", matches = function() return false end, execute = function() return false end },
        { name = "Conflagrate", matches = function() return false end, execute = function() return false end },
        { name = "Shadowburn", matches = function() return false end, execute = function() return false end },
        { name = "ShadowBolt", matches = function() return false end, execute = function() return false end },
        { name = "RainOfFire", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/warlock/destruction_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/warlock/destruction_vanilla' not found", 0)
    end
    if path == "shared/aoe_hit_volume_sylvanas" then
        return { install = function() end }
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/warlock/destruction_forever.lua")
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
    return { in_combat = true, target = FAKE_TARGET, has_valid_enemy_target = true,
             me = {}, settings = {}, enemy_count = 2, enemies = { FAKE_TARGET, FAKE_OFFTARGET } }
end

local INCINERATE = 19010
local INCINERATE_R1 = 19011
local BOH = 19012
local BOH_R1 = 19013
local FIRE_WINDOW = 19210
local SHADOW_WINDOW = 19211
local MIRRORS = { ["Incinerate"] = INCINERATE_R1, ["Bane of Havoc"] = BOH_R1 }
local MAXRANK = { ["Incinerate"] = INCINERATE, ["Bane of Havoc"] = BOH }
local BUFFS = { ["Flame"] = FIRE_WINDOW, ["Shadow"] = SHADOW_WINDOW }

-- A. All three lanes live (Incinerate learned): BoH above the curses, the
-- window lane then Incinerate above Shadow Bolt.
do
    learnt = { [INCINERATE] = true, [BOH] = true }
    auras = {}
    enemy_debuffs = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "destruction", "A: re-registers the destruction playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 3, "A: 3 delta lanes over 11 baseline lanes")
    assert_eq(find_lane(combined, "Forever_BaneOfHavoc"), find_lane(combined, "CurseOfDoom") - 1,
        "A: Bane of Havoc leads the curse block")
    assert_eq(find_lane(combined, "Forever_ShadowAndFlame"), find_lane(combined, "ShadowBolt") - 2,
        "A: the window lane sits two above Shadow Bolt")
    assert_eq(find_lane(combined, "Forever_Incinerate"), find_lane(combined, "ShadowBolt") - 1,
        "A: Incinerate sits directly above Shadow Bolt")
end

-- A2. Incinerate not learned: the fire lanes stay dormant, the Bane lane and
-- the window lane's shadow branch stay live.
do
    learnt = { [BOH] = true }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_Incinerate"), "A2: Incinerate dormant without the learn")
    assert_true(find_lane(combined, "Forever_ShadowAndFlame") ~= nil,
        "A2: the window lane keeps the shadow branch without Incinerate")
    assert_true(find_lane(combined, "Forever_BaneOfHavoc") ~= nil, "A2: Bane is learn-independent of Incinerate")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A2: Bane + window lane only")
    auras = { [FIRE_WINDOW] = true }
    learnt = { [BOH] = true }
    local window = combined[find_lane(combined, "Forever_ShadowAndFlame")]
    assert_true(not window.matches(fresh_ctx(), {}), "A2: the fire window cannot fire without Incinerate")
    auras = { [SHADOW_WINDOW] = true }
    assert_true(window.matches(fresh_ctx(), {}), "A2: the shadow window still fires")
end

-- B. Bane of Havoc matcher: 2+ enemies, banes the OFF-target, respects the
-- one-Bane limit.
do
    learnt = { [INCINERATE] = true, [BOH] = true }
    auras = {}
    enemy_debuffs = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local bane = combined[find_lane(combined, "Forever_BaneOfHavoc")]
    local ctx = fresh_ctx()
    assert_true(bane.matches(ctx, {}), "B: two enemies fires the Bane lane")
    cast_log = {}
    assert_true(bane.execute(ctx, {}), "B: the Bane lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, BOH, "B: the maxrank Bane id is cast")
    assert_eq(cast_log[1] and cast_log[1].target, FAKE_OFFTARGET, "B: the OFF-target is baned, not the focus")
    local solo = fresh_ctx()
    solo.enemy_count = 1
    solo.enemies = { FAKE_TARGET }
    assert_true(not bane.matches(solo, {}), "B: single target holds the Bane lane")
    enemy_debuffs = { [FAKE_OFFTARGET] = BOH }
    assert_true(not bane.matches(ctx, {}), "B: the one-Bane limit holds when the add is already baned")
end

-- B2. Shadow and Flame window: the boosted school outranks the plain filler.
do
    learnt = { [INCINERATE] = true, [BOH] = true }
    auras = {}
    enemy_debuffs = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local window = combined[find_lane(combined, "Forever_ShadowAndFlame")]
    local ctx = fresh_ctx()
    assert_true(not window.matches(ctx, {}), "B2: no window = no lane")
    auras = { [FIRE_WINDOW] = true }
    assert_true(window.matches(ctx, {}), "B2: the fire window fires the lane")
    cast_log = {}
    assert_true(window.execute(ctx, {}), "B2: the fire window executes")
    assert_eq(cast_log[1] and cast_log[1].spell, INCINERATE, "B2: the fire window casts Incinerate")
    auras = { [SHADOW_WINDOW] = true }
    assert_true(window.matches(ctx, {}), "B2: the shadow window fires the lane")
    cast_log = {}
    assert_true(window.execute(ctx, {}), "B2: the shadow window executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.WarlockSpells.ShadowBolt,
        "B2: the shadow window casts Shadow Bolt")
    local moving = fresh_ctx()
    moving.is_moving = true
    auras = { [FIRE_WINDOW] = true }
    assert_true(not window.matches(moving, {}), "B2: movement holds the stationary window lane")
end

-- B3. Incinerate matcher: the hard Immolate dependency.
do
    learnt = { [INCINERATE] = true }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local incinerate = combined[find_lane(combined, "Forever_Incinerate")]
    local ctx = fresh_ctx()
    assert_true(not incinerate.matches(ctx, { immolate_remains = 0 }), "B3: no Immolate = no Incinerate")
    assert_true(incinerate.matches(ctx, { immolate_remains = 8 }), "B3: Immolate ticking fires Incinerate")
    cast_log = {}
    assert_true(incinerate.execute(ctx, {}), "B3: Incinerate executes")
    assert_eq(cast_log[1] and cast_log[1].target, FAKE_TARGET, "B3: Incinerate lands on the focus target")
    local moving = fresh_ctx()
    moving.is_moving = true
    assert_true(not incinerate.matches(moving, { immolate_remains = 8 }), "B3: movement holds Incinerate")
end

-- C. Dormancy: empty mirrors leave every lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_BaneOfHavoc"), "C: Bane dormant")
    assert_true(not find_lane(combined, "Forever_Incinerate"), "C: Incinerate dormant")
    assert_true(not find_lane(combined, "Forever_ShadowAndFlame"), "C: window lane dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the primary anchors the lanes append.
do
    learnt = { [INCINERATE] = true, [BOH] = true }
    local shrunk = {
        name = "destruction",
        strategies = {
            { name = "Immolate", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 4, "D: the three lanes appended without anchors")
    assert_eq(find_lane(combined, "Forever_BaneOfHavoc"), 2, "D: Bane appended first")
    assert_eq(find_lane(combined, "Forever_ShadowAndFlame"), 3, "D: the window lane appended second")
    assert_eq(find_lane(combined, "Forever_Incinerate"), 4, "D: Incinerate appended last")
end

-- G. Mirror selection: casts read the maxrank mirror, windows the buff
-- mirror, learn gates both mirrors of the name.
do
    learnt = {}
    auras = { [FIRE_WINDOW] = true }
    local r1_only = load_delta(MIRRORS, MAXRANK, BUFFS)
    local window = r1_only[find_lane(r1_only, "Forever_ShadowAndFlame")]
    assert_true(window ~= nil, "G: the window lane is live on the class-less aura ids")
    -- The rank-1 learn gate alone (no maxrank entry) cannot build a cast lane.
    local no_max = load_delta(MIRRORS, {}, BUFFS)
    assert_true(not find_lane(no_max, "Forever_Incinerate"), "G: no maxrank = dormant Incinerate")
    assert_true(not find_lane(no_max, "Forever_BaneOfHavoc"), "G: no maxrank = dormant Bane")
    -- Without the buff mirror the windows are dormant even with casts present.
    local no_buff = load_delta(MIRRORS, MAXRANK, {})
    assert_true(not find_lane(no_buff, "Forever_ShadowAndFlame"), "G: no buff mirror = dormant window lane")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/warlock/destruction_forever.lua", "rb")
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

print("test_warlock_destruction_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS warlock_destruction_forever")
