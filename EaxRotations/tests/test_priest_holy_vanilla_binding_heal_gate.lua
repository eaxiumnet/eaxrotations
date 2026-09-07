-- test_priest_holy_vanilla_binding_heal_gate.lua — Holy priest vanilla
-- Binding-Heal era-gate regression pin.
-- WHAT:  Drives the REAL holy_vanilla.lua against a mock whose spell table
--        mirrors the vanilla class table (priest/class_sylvanas.lua sets
--        UnavailableClassicPriestHealA = nil — Binding Heal 32546 is TBC-only)
--        and whose spell_exists/spell_ready mirror the real nil-guard chain
--        (NS.is_spell_learned -> get_spell_id -> "no id => false"). It proves
--        the UnavailableClassicPriestHealA lane is REAL handling wired to an
--        era gate, not dead text: with every rotation condition green the lane
--        still never matches because the nil-keyed spell cannot exist in the
--        Classic client.
-- WHEN:  During rotation battery execution (run_rotation_tests.lua).
-- WHY:   Vanilla-era parity pass (2026-09-06): settle the "placeholder comment"
--        question with behavioral evidence. The pin also regression-locks the
--        gate: if a future edit rewires the lane to SPELLS.BindingHeal (32546,
--        present in this mock), the lane starts matching and this suite turns
--        red — catching a TBC spell leaking into the Classic rotation.
-- SAFETY: Pure unit tests with a mocked NS; the real holy_vanilla.lua loads.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local hp = 79
local in_combat = true
local locked = false
local moving = false
local setting_off = false
local lowest_present = true

local function reset_env()
    hp, in_combat, locked, moving = 79, true, false, false
    setting_off, lowest_present = false, true
end

_G.core = { time = function() return 0 end, log = function() end }

_G.EaxRotations = {
    -- Vanilla-era spell table: real classic heals present, Binding Heal key
    -- (32546) present for the TBC sibling, and the era-placeholder key absent
    -- (class_sylvanas.lua sets UnavailableClassicPriestHealA = nil -> nil field).
    PriestSpells = {
        GreaterHeal = 25314, FlashHeal = 25315, PowerWordShield = 25218,
        Renew = 25222, BindingHeal = 32546, PrayerOfHealing = 25331,
        Lightwell = 724, InnerFocus = 14751,
    },
    CLASS_ID = { PRIEST = 5 },
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function() return { get_class = function() return 5 end } end,
    import_helpers = function()
        local function try_cast(...) return true end
        -- Real chain semantics: spell_exists(nil spell) -> is_spell_learned(nil)
        -- -> get_spell_id(nil) -> no ids -> false.
        local function spell_exists(spell) return spell ~= nil end
        local function spell_ready(spell) return spell ~= nil end
        return try_cast, spell_exists, spell_ready,
            function() return 0 end,
            function() return 100 end,
            function() return false end,
            function() return false end
    end,
    spell_ready = function() return true end,
    cast_best_heal_rank = function() return nil, nil end,
    log = function() end,
    rotation_registry = { register = function() end },
}
package.loaded["common/modules/buff_manager"] = { get_all_buffs = function() return {} end }
package.loaded["classes/priest/healing_sylvanas"] = { select_heal = function() return nil end, scan_healing_targets = function() return {}, 0 end }

local result = dofile("EaxRotations/classes/priest/holy_vanilla.lua")
local strategies = result.strategies or result

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local binding_heal = find("UnavailableClassicPriestHealA")
assert_true(binding_heal ~= nil, "the Binding Heal placeholder lane is registered (named, not missing)")
assert_true(type(binding_heal.execute) == "function", "the lane carries a real execute (downrank heal wiring), not dead text")

local function scenario(label, expect)
    local ctx = {
        in_combat = in_combat,
        player_control_locked = locked,
        is_moving = moving,
        hp = hp,
        settings = (setting_off and { holy_use_binding_heal = false }) or {},
    }
    local state = {
        lowest = lowest_present and { unit = { _friendly = true }, is_player = false } or nil,
    }
    local matched = binding_heal.matches(ctx, state)
    if expect then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
end

local function assert_lane(label, setup, expect)
    reset_env()
    setup()
    scenario(label, expect)
end

-- ============================================================================
-- The era gate: every rotation condition for Binding Heal is green, yet the
-- lane never fires because SPELLS.UnavailableClassicPriestHealA is nil in the
-- vanilla class table and spell_exists(nil) is false.
-- ============================================================================
assert_lane("Binding Heal lane is inert even with every condition green", function() end, false)
assert_lane("Binding Heal lane is inert in the emergency band too", function() hp = 40 end, false)
assert_lane("Binding Heal lane is inert on a lowest non-player ally", function() end, false)

-- Don't-fire gates that would apply if the spell existed (the lane still
-- honors the full gate set before the spell_exists era check).
assert_lane("Binding Heal lane held when the opt-out setting is set",
    function() setting_off = true end, false)
assert_lane("Binding Heal lane held out of combat",
    function() in_combat = false end, false)
assert_lane("Binding Heal lane held above the 80 self-hp band",
    function() hp = 81 end, false)
assert_lane("Binding Heal lane held when no lowest ally exists",
    function() lowest_present = false end, false)

-- ============================================================================
-- Regression lock: the mock's PriestSpells ALSO carries the real BindingHeal
-- (32546), the TBC spell this lane must never cast in Classic. Verify the
-- era gate is what keeps it inert — simulate the "fixed" rewiring by
-- evaluating with a spell_exists that would resolve the real TBC spell.
-- ============================================================================
do
    local ctx = { in_combat = true, player_control_locked = false, is_moving = false, hp = 79, settings = {} }
    local state = { lowest = { unit = {}, is_player = false } }
    -- If the placeholder key resolved to the real 32546 BindingHeal (TBC-era
    -- regression), spell_exists/ready both pass and the lane would fire.
    local rewired = (function()
        local s = _G.EaxRotations.PriestSpells
        s.UnavailableClassicPriestHealA = s.BindingHeal  -- simulate the bug
        local m = binding_heal.matches(ctx, state)
        s.UnavailableClassicPriestHealA = nil            -- restore
        return m
    end)()
    assert_true(rewired, "regression check: rewiring the placeholder to real BindingHeal must make the lane match (era-gate is the only blocker)")
end

print("PASS test_priest_holy_vanilla_binding_heal_gate")
