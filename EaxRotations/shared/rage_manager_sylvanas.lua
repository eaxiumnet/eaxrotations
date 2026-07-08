-- rage_manager_sylvanas.lua — Smart rage dump management for Warrior DPS specs.
-- WHAT:  Intelligently queue Heroic Strike / Cleave to prevent rage capping.
-- WHEN:  Arms and Fury Warrior (Protection uses its own rage dump logic).
-- WHY:   Rage capping is DPS loss; rage starving is also DPS loss.
-- SAFETY: Nil-guarded settings; starvation checks prevent blocking core abilities.
-- DECISION: Warrior rage dump (HS/Cleave) with starvation guard.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local M = {}
NS.RageManager = M

local spec_kit = require("shared/spec_kit_sylvanas")

-- ---------------------------------------------------------------------------
-- Core ability reservation constants (avoid starving core rotation)
-- ---------------------------------------------------------------------------
local CORE_RAGE_RESERVE = {
    arms = {
        mortal_strike = 30,
        overpower = 5,
        execute = 15,
        slam = 15,
    },
    fury = {
        bloodthirst = 30,
        whirlwind = 25,
        execute = 15,
        pummel = 10,
    },
}

-- ---------------------------------------------------------------------------
-- Check if the next core ability is imminent and we should reserve rage.
-- ---------------------------------------------------------------------------
local function would_starve_core(context, state, cost, spec)
    spec = spec or "arms"
    local reserve = CORE_RAGE_RESERVE[spec] or CORE_RAGE_RESERVE.arms
    local rage = state.rage or context.rage or 0
    local rage_after = rage - cost

    if spec == "arms" then
        -- MS imminent
        if (state.ms_cd or 99) <= 1.5 and rage_after < reserve.mortal_strike then return true end
        -- Overpower ready
        if state.overpower_ready and rage_after < reserve.overpower then return true end
        -- Execute phase
        if state.execute_phase and rage_after < reserve.execute then return true end
        -- Slam window
        if (state.mh_until or 999) <= 1.5 and rage_after < reserve.slam then return true end
    elseif spec == "fury" then
        -- BT imminent
        if (state.bt_cd or 99) <= 1.5 and rage_after < reserve.bloodthirst then return true end
        -- WW imminent
        if (state.ww_cd or 99) <= 1.5 and rage_after < reserve.whirlwind then return true end
        -- Execute phase
        if state.execute_phase and rage_after < reserve.execute then return true end
        -- Interrupt reserve
        if state.target_casting_interruptible and state.pummel_ready and rage_after < reserve.pummel then return true end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Determine if Heroic Strike should be queued.
-- @param spec  string  "arms" or "fury"
-- ---------------------------------------------------------------------------
function M.should_heroic_strike(context, state, spec)
    context = context or {}
    state = state or {}
    spec = spec or "arms"

    local dump_mode = spec_kit.setting(context, "rage_dump_ability", "auto")
    if dump_mode == "cleave" then return false end

    local threshold = spec_kit.setting_number(context, "rage_dump_threshold", 80)
    local rage = state.rage or context.rage or 0
    if rage < threshold then return false end

    -- Don't starve core abilities
    if would_starve_core(context, state, 15, spec) then return false end

    -- Fury-specific: HS trick — queue when OH swing is imminent
    if spec == "fury" then
        if spec_kit.setting_bool(context, "hs_trick", true) then
            local me = context.me or NS.GetPlayer and NS.GetPlayer()
            if me and NS.swing_time_until then
                local oh_remaining = NS.swing_time_until(me, 2) or 999
                local mh_remaining = NS.swing_time_until(me) or 999
                if oh_remaining > 0 and oh_remaining <= 0.4 and mh_remaining > oh_remaining + 0.3 then
                    return true
                end
            end
        end
        -- If MH is about to swing, avoid HS (it replaces the MH auto-attack)
        local mh_until = state.mh_until or 999
        if mh_until <= 0.5 then
            -- MH imminent: skip HS unless we're rage-capped
            if rage < 95 then return false end
        end
    end

    -- AoE check: if 2+ enemies and dump mode is auto, prefer Cleave
    local enemy_count = state.enemy_count or context.enemy_count or 1
    if enemy_count >= 2 and dump_mode == "auto" then return false end

    return true
end

-- ---------------------------------------------------------------------------
-- Determine if Cleave should be queued.
-- ---------------------------------------------------------------------------
function M.should_cleave(context, state, enemy_count, spec)
    context = context or {}
    state = state or {}
    spec = spec or "arms"

    local dump_mode = spec_kit.setting(context, "rage_dump_ability", "auto")
    if dump_mode == "heroic_strike" then return false end

    enemy_count = enemy_count or state.enemy_count or context.enemy_count or 1
    if enemy_count < 2 then return false end

    local threshold = spec_kit.setting_number(context, "rage_dump_threshold", 80)
    local rage = state.rage or context.rage or 0
    if rage < threshold then return false end

    -- Don't starve core abilities
    if would_starve_core(context, state, 20, spec) then return false end

    return true
end

-- ---------------------------------------------------------------------------
-- Get the recommended dump ability for current state.
-- Returns: "heroic_strike", "cleave", or nil
-- ---------------------------------------------------------------------------
function M.recommend_dump(context, state, spec)
    spec = spec or "arms"
    local enemy_count = state.enemy_count or context.enemy_count or 1

    if M.should_cleave(context, state, enemy_count, spec) then
        return "cleave"
    end
    if M.should_heroic_strike(context, state, spec) then
        return "heroic_strike"
    end
    return nil
end

-- module initialized
return M
