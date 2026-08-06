-- test_sod_rogue_shaman_adversarial.lua -- Fail-closed SoD role and manual-QA probes.
-- WHAT: probes nil/stale/misleading inputs plus poison, totem, and weapon-imbue boundaries.
-- WHEN: run with the Task 6 source-priority suite.
-- WHY: prevents role actions from leaking across runtimes or firing on unverified equipment state.
-- SAFETY: deterministic mocks; malformed inputs must return false without throwing.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local registry = { playstyles = {} }
function registry:register(name, strategies) self.playstyles[name] = strategies end
_G.EaxRotations = {
    is_sod = function() return true end,
    RogueSpells = {}, ShamanSpells = {}, rotation_registry = registry,
    spell_action = function(ids, label)
        local id = type(ids) == "table" and ids[1] or ids
        return { _meta = { id = id, label = label } }
    end,
    try_cast = function() return true end,
}

local function load_role(path)
    package.loaded[path] = nil
    return require(path)
end

local function strategy(role, name)
    for _, candidate in ipairs(role.strategies) do
        if candidate.name == name then return candidate end
    end
    error("missing strategy " .. name, 2)
end

local rogue = load_role("classes/rogue/combat_sod")
local warden = load_role("classes/shaman/warden_sod")
local elemental = load_role("classes/shaman/elemental_sod")

local envenom = strategy(rogue, "Envenom")
local no_poison = {
    is_sod = true, sod_phase = 8, target = {}, combo_points = 5, poison_stacks = 0,
    sod_runes = { [399963] = true },
}
assert_eq(envenom.matches(no_poison, rogue.build_state(no_poison)), false,
    "Envenom requires poison doses")

local molten = strategy(warden, "MoltenBlast")
local wrong_imbue = {
    is_sod = true, sod_phase = 8, target = {}, enemy_count = 5, mainhand_imbue = "windfury",
    sod_runes = { [408531] = true, [425339] = true },
}
assert_eq(molten.matches(wrong_imbue, warden.build_state(wrong_imbue)), false,
    "Way of Earth tanking requires Rockbiter")

local magma = strategy(warden, "MagmaTotem")
local active_totem = {
    is_sod = true, sod_phase = 8, target = {}, enemy_count = 3, mainhand_imbue = "rockbiter",
    fire_totem_active = true, sod_runes = { [408531] = true },
}
assert_eq(magma.matches(active_totem, warden.build_state(active_totem)), false,
    "active fire totem is not overwritten")

local lava_burst = strategy(elemental, "LavaBurst")
for label, context in pairs({
    nil_like = {},
    stale_phase = { is_sod = true, sod_phase = "phase-8", target = {}, flame_shock_remains = 8,
        sod_runes = { [408490] = true } },
    misleading_rune = { is_sod = true, sod_phase = 8, target = {}, flame_shock_remains = 8,
        sod_runes = { [408490] = "equipped" } },
    legacy = { is_sod = false, sod_phase = 8, target = {}, flame_shock_remains = 8,
        sod_runes = { [408490] = true } },
}) do
    local ok, result = pcall(lava_burst.matches, context, elemental.build_state(context))
    assert_eq(ok, true, label .. " does not throw")
    assert_eq(result, false, label .. " fails closed")
end

print("PASS test_sod_rogue_shaman_adversarial (nil/stale/misleading/poison/totem/imbue)")
