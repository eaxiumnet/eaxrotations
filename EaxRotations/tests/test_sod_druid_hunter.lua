-- test_sod_druid_hunter.lua -- Focused Druid and Hunter SoD rotation coverage.
-- WHAT: loads five native rotations and checks source-backed priorities and execution.
-- WHEN: Task 4 focused validation for pinned wowsims/sod commit 0e3f6eff.
-- WHY: proves forms, pets, healing, execute, phase, and rune gates through real modules.
-- SAFETY: deterministic API stubs; no game client, network, or persistent state.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local registered = {}
local cast_action
_G.EaxRotations = {
    is_sod = function() return true end,
    DruidSpells = { Starsurge = { legacy = true }, MangleCat = { legacy = true } },
    HunterSpells = { ChimeraShot = { legacy = true } },
    rotation_registry = {
        register = function(_, name, strategies, options)
            registered[name] = { strategies = strategies, options = options }
        end,
    },
    spell_action = function(ids, label)
        local id = type(ids) == "table" and ids[1] or ids
        return { _meta = { id = id, name = label } }
    end,
    spell_ready = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    try_cast = function(action)
        cast_action = action
        return true
    end,
}

local function load(path)
    package.loaded[path] = nil
    return assert(require(path), "module did not load: " .. path)
end

local function strategy(module, name)
    for i = 1, #module.strategies do
        if module.strategies[i].name == name then return module.strategies[i] end
    end
    error("missing strategy: " .. name, 2)
end

local function first_match(module, context, override)
    local state = module.build_state(context)
    for key, value in pairs(override or {}) do state[key] = value end
    for i = 1, #module.strategies do
        local current = module.strategies[i]
        if current.matches(context, state) then return current end
    end
    return nil
end

local runes = {
    [407995] = true, [407988] = true, [414644] = true, [417141] = true,
    [408120] = true, [408247] = true, [417157] = true, [414684] = true,
    [439748] = true, [409433] = true, [409593] = true,
}
local target = {}
local me = {}
local base = { is_sod = true, sod_phase = 7, sod_runes = runes, target = target, me = me, in_combat = true }

local balance = load("classes/druid/balance_sod")
local feral = load("classes/druid/feral_sod")
local tank = load("classes/druid/tank_sod")
local restoration = load("classes/druid/restoration_sod")
local hunter = load("classes/hunter/dps_hunter_sod")

assert_eq(balance.actions.Starsurge.action._meta.id, 417157, "pinned Starsurge beats legacy action")
assert_eq(feral.actions.Mangle.action._meta.id, 409828, "pinned cat Mangle beats legacy action")
assert_eq(hunter.actions.ChimeraShot.action._meta.id, 409433, "pinned Chimera beats legacy action")

for _, name in ipairs({ "balance", "feral", "tank", "restoration", "dps_hunter" }) do
    assert_eq(type(registered[name]), "table", name .. " registration")
end

assert_eq(first_match(balance, base, { has_starsurge_aura = false }).name, "Starsurge", "Balance opens Starsurge")
local moonfire = first_match(balance, base, { has_starsurge_aura = true, moonfire_remains = 0 })
assert_eq(moonfire.name, "Moonfire", "Balance maintains Moonfire before Sunfire")
local starfall = strategy(balance, "Starfall")
local phase_three = { is_sod = true, sod_phase = 3, sod_runes = runes, target = target, me = me, in_combat = true }
local phase_four = { is_sod = true, sod_phase = 4, sod_runes = runes, target = target, me = me, in_combat = true }
assert_eq(starfall.matches(phase_three, balance.build_state(phase_three)), false, "Starfall unavailable before phase 4")
assert_eq(starfall.matches(phase_four, balance.build_state(phase_four)), true, "Starfall available in phase 4")

assert_eq(first_match(feral, base, { in_cat_form = false }).name, "CatForm", "Feral enters Cat Form")
assert_eq(first_match(feral, base, { in_cat_form = true, savage_roar_remains = 0 }).name,
    "SavageRoar", "Feral maintains Savage Roar")
assert_eq(first_match(feral, base, {
    in_cat_form = true, savage_roar_remains = 12, mangle_remains = 12,
    combo_points = 5, rip_remains = 0, target_ttd = 30,
}).name, "Rip", "Feral uses five-point Rip")

assert_eq(first_match(tank, base, { hp_pct = 19, in_bear_form = true }).name,
    "Barkskin", "Tank defensive gate follows 20 percent source threshold")
assert_eq(first_match(tank, base, { hp_pct = 100, in_bear_form = false }).name,
    "BearForm", "Tank enters Bear Form")
assert_eq(first_match(tank, base, {
    hp_pct = 100, in_bear_form = true, lacerate_remains = 2, lacerate_stacks = 3,
}).name, "LacerateRefresh", "Tank refreshes Lacerate before Mangle")

local ally = {}
local heal_context = {
    is_sod = true, sod_phase = 7, sod_runes = runes, me = me, in_combat = true,
    heal_target = ally, heal_target_hp_pct = 45, injured_count = 4,
}
assert_eq(first_match(restoration, heal_context).name, "WildGrowth", "Restoration raid heal priority")
local nourish = first_match(restoration, heal_context, { injured_count = 1, heal_target_hp_pct = 45 })
assert_eq(nourish.name, "Nourish", "Restoration single-target heal priority")

local pet = {}
local hunter_context = {
    is_sod = true, sod_phase = 7, sod_runes = runes, target = target, me = me,
    in_combat = true, pet = pet, target_hp_pct = 18,
}
assert_eq(first_match(hunter, hunter_context, { pet_alive = true, pet_hp_pct = 20 }).name,
    "MendPet", "Hunter protects injured pet")
assert_eq(first_match(hunter, hunter_context, { pet_alive = true, pet_hp_pct = 100 }).name,
    "ChimeraShot", "Hunter refreshes sting with Chimera before Kill Shot")
assert_eq(first_match(hunter, hunter_context, {
    pet_alive = true, pet_hp_pct = 100, serpent_sting_remains = 8,
}).name, "KillShot", "Hunter uses Kill Shot in execute phase")
local call_context = { is_sod = true, sod_phase = 7, sod_runes = runes, me = me, in_combat = false }
assert_eq(first_match(hunter, call_context).name, "CallPet", "Hunter calls a missing pet out of combat")
call_context.pet_dead = true
assert_eq(first_match(hunter, call_context).name, "RevivePet", "Hunter revives a dead pet out of combat")

cast_action = nil
local kill = strategy(hunter, "KillShot")
assert_eq(kill.execute(hunter_context), true, "Hunter resolved action executes")
assert_eq(cast_action, hunter.actions.KillShot.action, "execute passes resolved action")

print("PASS test_sod_druid_hunter (5 registrations; source priorities/forms/pets/runes/phases)")
