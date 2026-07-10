-- shared/warlock_interrupt_sylvanas.lua -- Warlock pet interrupt strategies.
-- WHAT:   registers pet interrupt strategies (e.g., Felhunter Spell Lock).
-- WHEN:   required by warlock middleware; evaluated every tick before spec strategies.
-- WHY:    centralizes pet interrupt logic so it can be reused across specs/middleware.
-- SAFETY: nil-guarded API calls; gated by use_interrupt and active pet type.
-- DECISION: consumed via require(); no on_update side-effects.

local NS = _G.EaxRotations
if not NS then return nil end

local pet_manager = require("shared/pet_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")

local SPELLS = NS.WarlockSpells or {}

local M = {}

-- ============================================================================
-- Pet interrupt definitions
-- ============================================================================
-- Each entry maps a detected pet type to its interrupt spell(s).
-- id    = preferred rank (highest)
-- rank1 = lower rank fallback
-- aura_ids = spell IDs that are debuffs/auras and must NOT be cast directly
local PET_INTERRUPTS = {
    felhunter = {
        name = "FelhunterSpellLock",
        id = 19647,   -- Spell Lock (Rank 2)
        rank1 = 19244, -- Spell Lock (Rank 1)
        aura_ids = { 24259 },
    },
}

-- ============================================================================
-- Helpers
-- ============================================================================

-- Returns true if the active pet matches the given type and is alive.
local function is_pet_type_active(type_name)
    local me = NS.GetPlayer and NS.GetPlayer()
    if not me then return false end
    local pet = pet_manager.get_pet(me)
    if not pet or not pet_manager.pet_alive(pet) then return false end
    return pet_manager.get_pet_type(pet) == type_name
end

-- Returns true if the target is currently casting or channeling.
local function target_is_casting(target)
    if not target then return false end
    local ok, casting = pcall(function() return target:is_casting() end)
    if ok and casting then return true end
    ok, casting = pcall(function() return target:is_channeling() end)
    return ok and casting or false
end

-- Resolve the best castable interrupt spell ID for a pet type.
-- Prefers the highest known rank and avoids aura-only IDs.
local function get_interrupt_spell_id(pet_type)
    local entry = PET_INTERRUPTS[pet_type]
    if not entry then return nil end

    local function is_learned(id)
        return id and NS.is_spell_learned and NS.is_spell_learned(id)
    end

    if is_learned(entry.id) then return entry.id end
    if is_learned(entry.rank1) then return entry.rank1 end

    -- Fallback to the class spell table if it resolves to a real castable ID.
    if pet_type == "felhunter" and SPELLS.SpellLock then
        local id = NS.get_spell_id(SPELLS.SpellLock)
        if id then
            for _, aura_id in ipairs(entry.aura_ids or {}) do
                if id == aura_id then id = nil; break end
            end
            if id then return id end
        end
    end

    -- Final hard fallback to the preferred ID.
    return entry.id
end

-- ============================================================================
-- Strategy factory
-- ============================================================================

-- Create an interrupt strategy for the given warlock pet type.
-- Returns nil if no interrupt is defined for that pet type.
function M.create_strategy(pet_type)
    local entry = PET_INTERRUPTS[pet_type]
    if not entry then return nil end

    return {
        name = entry.name,
        matches = function(context)
            if not context.in_combat then return false end
            if spec_kit.setting_bool(context, "use_interrupt", true) == false then return false end
            if not context.target then return false end
            if not target_is_casting(context.target) then return false end
            if not is_pet_type_active(pet_type) then return false end

            local id = get_interrupt_spell_id(pet_type)
            if not id then return false end
            if not (NS.is_spell_learned and NS.is_spell_learned(id)) then return false end

            -- Cooldown check
            local cd = 0
            if core and core.spell_book and core.spell_book.get_spell_cooldown then
                local ok, cd_val = pcall(core.spell_book.get_spell_cooldown, id)
                if ok and cd_val then cd = cd_val end
            end
            if cd > 0 then return false end

            -- Respect interrupt window / humanization when available
            if interrupt_manager.cast_has_interrupt_window then
                if not interrupt_manager.cast_has_interrupt_window(context.target, context.settings) then return false end
            end
            if interrupt_manager.humanize_interrupt_elapsed then
                if not interrupt_manager.humanize_interrupt_elapsed(context.target, context.settings) then return false end
            end

            return true
        end,
        execute = function(context)
            local id = get_interrupt_spell_id(pet_type)
            if not id then return false end
            local ok = pet_manager.try_cast(id, context.target)
            if ok and interrupt_manager.record_school_lock then
                interrupt_manager.record_school_lock(context.target, id)
            end
            return ok
        end,
    }
end

-- Register all defined pet interrupt strategies into the provided strategy table.
-- Usage: warlock_interrupt.register_all(strategies)
function M.register_all(strategies)
    if type(strategies) ~= "table" then return end
    for pet_type, _ in pairs(PET_INTERRUPTS) do
        local strategy = M.create_strategy(pet_type)
        if strategy then
            strategies[#strategies + 1] = strategy
        end
    end
end

return M
