-- Warrior shared middleware.

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { DEFENSIVE = 2 }
local BATTLE_SHOUT_BUFFS = CONSTANTS.BATTLE_SHOUT_IDS or { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local HAMSTRING_DEBUFF = { 25212, 7373, 7372, 1715 }

local function player_unit(context)
    return context.me or NS.GetPlayer()
end

local function defensive_spell_ready(spell, context)
    local me = player_unit(context)
    return spell and me and NS.spell_ready(spell, me, { skip_range = true }) == true
end

local function should_use_warrior_defensive(context)
    local settings = context.settings or {}
    local threshold = settings.defensive_hp_threshold or 30
    if settings.use_defensives == false then return false end
    return context.in_combat == true and (context.hp or 100) < threshold
end

local function defensive_stance_ready(context)
    return context.stance == STANCE.DEFENSIVE or defensive_spell_ready(SPELLS.DefensiveStance, context)
end

local function cast_defensive_stance(context)
    if context.stance == STANCE.DEFENSIVE then return false end
    return NS.try_cast(SPELLS.DefensiveStance, player_unit(context), "[WARRIOR] Defensive Stance", { skip_range = true }) == true
end

local function cast_warrior_defensive(context, spell, reason)
    if context.stance ~= STANCE.DEFENSIVE and cast_defensive_stance(context) then return true end
    if context.stance ~= STANCE.DEFENSIVE then return false end
    return NS.try_cast(spell, player_unit(context), reason, { skip_range = true }) == true
end

local function unit_is_moving(unit)
    local is_moving = NS.safe_field and NS.safe_field(unit, "is_moving") or nil
    if type(is_moving) ~= "function" then return false end
    local ok, moving = pcall(is_moving, unit)
    return ok and moving == true
end

local strategies = {

    interrupt_manager.register_interrupt_spell("warrior", "Pummel", SPELLS, 3),

    {
        name = "Defensive",
        matches = function(context)
            if not should_use_warrior_defensive(context) then return false end
            local settings = context.settings or {}
            if context.stance ~= STANCE.DEFENSIVE and not defensive_stance_ready(context) then return false end
            return (settings.use_last_stand ~= false and defensive_spell_ready(SPELLS.LastStand, context))
                or (settings.use_shield_wall ~= false and defensive_spell_ready(SPELLS.ShieldWall, context))
        end,
        execute = function(context)
            local settings = context.settings or {}
            if settings.use_last_stand ~= false and defensive_spell_ready(SPELLS.LastStand, context) then
                return cast_warrior_defensive(context, SPELLS.LastStand, "[WARRIOR] Last Stand")
            end
            if settings.use_shield_wall ~= false and defensive_spell_ready(SPELLS.ShieldWall, context) then
                return cast_warrior_defensive(context, SPELLS.ShieldWall, "[WARRIOR] Shield Wall")
            end
            return false
        end,
    },

    {
        name = "SelfBuff",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_self_buffs == false or settings.use_battle_shout == false then return false end
            if NS.has_player_buff(BATTLE_SHOUT_BUFFS) then return false end
            if context.in_combat and NS.has_player_buff(BATTLE_SHOUT_BUFFS) then return false end
            return defensive_spell_ready(SPELLS.BattleShout, context)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.BattleShout, player_unit(context), "[WARRIOR] Battle Shout", { skip_range = true }) == true
        end,
    },

    {
        name = "PvPIntercept",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_defensives == false then return false end
            if not NS.should_kite(context) then return false end
            return NS.action_matches(context, { name = "PvPIntercept", spell = SPELLS.Intercept, cooldown = 15 })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "PvPIntercept", spell = SPELLS.Intercept, cooldown = 15 }, "[WARRIOR]")
        end,
    },

{
        name = "PvPHamstring",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_defensives == false then return false end
            local target = context.target
            if not (target and NS.is_melee_target and NS.is_melee_target(target, context.me)) then return false end
            if not unit_is_moving(target) then return false end
            if NS.debuff_up(target, HAMSTRING_DEBUFF) then return false end
            return NS.action_matches(context, { name = "PvPHamstring", spell = SPELLS.Hamstring, debuff = HAMSTRING_DEBUFF, refresh = 2 })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "PvPHamstring", spell = SPELLS.Hamstring }, "[WARRIOR]")
        end,
    },

    -- ============================================================================
    -- SMART HS DEQUEUE (Three-condition dequeue for Fury dual-wield)
    -- a) Dequeue before MH swing if rage insufficient for HS cost
    -- b) Hold rage for Pummel if enemy casting interruptible spell
    -- c) Dequeue in Execute phase (Execute is better DPS than HS queue)
    -- ============================================================================
    {
        name = "SmartHSDequeue",
        matches = function(context)
            if not context.in_combat then return false end
            local settings = context.settings or {}
            if settings.hs_trick == false then return false end
            if not context.has_valid_enemy_target then return false end
            -- Only meaningful when dual-wielding (Fury with OH weapon)
            if not context.has_offhand then return false end
            -- Check if HeroicStrike or Cleave is currently queued
            if not NS.is_current_spell then return false end
            local hs_id = SPELLS.HeroicStrike and SPELLS.HeroicStrike.id and SPELLS.HeroicStrike:id() or nil
            local cleave_id = SPELLS.Cleave and SPELLS.Cleave.id and SPELLS.Cleave:id() or nil
            if not (hs_id and NS.is_current_spell(hs_id)) and not (cleave_id and NS.is_current_spell(cleave_id)) then return false end
            return true
        end,
        execute = function(context)
            local should_dequeue = false
            local reason = ""
            local mh_remaining = NS.get_time_until_swing()
            local target = context.target
            local rage = context.rage or 0

            -- Condition a: MH swing landing soon and not enough rage for HS cost
            -- Keep queued if OH lands first (we want the yellow OH hit)
            if mh_remaining and mh_remaining > 0 and mh_remaining <= 0.4 then
                local hs_cost = 15
                if rage < hs_cost then
                    local oh_remaining = context.oh_remain or 999
                    if oh_remaining <= 0 then oh_remaining = 999 end
                    -- Only dequeue if MH lands before OH (preserve yellow OH hit)
                    if mh_remaining <= oh_remaining then
                        should_dequeue = true
                        reason = "Low rage (" .. tostring(rage) .. ")"
                    end
                end
            end

            -- Condition b: Target casting a kickable spell — hold rage for Pummel
            if not should_dequeue and target then
                local is_casting = NS.safe_field and NS.safe_field(target, "is_casting")
                local cast_ok, casting = is_casting and pcall(is_casting, target) or false, false
                if cast_ok and casting then
                    local get_casting_spell_id = NS.safe_field and NS.safe_field(target, "get_casting_spell_id")
                    local spell_id = get_casting_spell_id and pcall(get_casting_spell_id, target) or nil
                    if spell_id then
                        local hs_cost = 15
                        local pummel_cost = 10
                        if rage < (hs_cost + pummel_cost) then
                            should_dequeue = true
                            reason = "Hold for interrupt (rage: " .. tostring(rage) .. ")"
                        end
                    end
                end
            end

            -- Condition c: Target entered execute phase — Execute is better DPS
            if not should_dequeue then
                local target_hp = context.target_hp or 100
                if target_hp <= 20 then
                    local playstyle = context.settings and context.settings.playstyle or "fury"
                    local exec_key = playstyle .. "_execute_phase"
                    local hs_exec_key = playstyle .. "_hs_during_execute"
                    local settings = context.settings or {}
                    if settings[exec_key] and not settings[hs_exec_key] then
                        should_dequeue = true
                        reason = "Execute phase"
                    end
                end
            end

            if should_dequeue then
                if NS.cancel_spells then NS.cancel_spells() end
                local debug = NS.get_setting and NS.get_setting("debug_system", false) or false
                if debug then NS.log("[WARRIOR] HS Dequeue - " .. reason) end
                return true
            end

            return false
        end,
    },

    -- ============================================================================
    -- Spell Reflection (Tier 2 Gap Feature)
    -- ============================================================================
    {
        name = "SpellReflection",
        matches = function(context)
            local settings = context.settings or {}
            if settings.warrior_use_spell_reflection == false then return false end
            if not context.target then return false end
            
            -- PvP only mode check
            local pvp_only = settings.warrior_reflect_pvp_only ~= false
            if pvp_only and not (context.is_pvp or false) then return false end
            
            -- Spell Reflection spell ID
            local sr_id = 23920
            if not (NS.is_spell_learned and NS.is_spell_learned(sr_id)) then return false end
            if not (NS.spell_ready and NS.spell_ready(sr_id)) then return false end
            
            -- Check if Spell Reflection buff already active
            if NS.has_buff and context.me then
                if NS.has_buff(context.me, sr_id) then return false end
            end
            
            -- Check if target is casting
            local is_casting = false
            local casting_spell_id = nil
            if context.target then
                local ok1, val1 = pcall(function() return context.target:is_casting() end)
                if ok1 then is_casting = val1 end
                
                local ok2, val2 = pcall(function() return context.target:get_casting_spell_id() end)
                if ok2 then casting_spell_id = val2 end
            end
            
            if not is_casting then return false end
            
            -- Whitelist of dangerous spells to reflect in PvP
            local REFLECT_WHITELIST = {
                -- Mage
                [118] = true, [12824] = true, [12825] = true, [12826] = true, -- Polymorph
                [133] = true, [143] = true, [145] = true, [3140] = true, [8400] = true, [8401] = true, [8402] = true,
                [10148] = true, [10149] = true, [10150] = true, [10151] = true, [25306] = true, [27070] = true, -- Fireball
                [116] = true, [205] = true, [837] = true, [7322] = true, [8406] = true, [8407] = true, [8408] = true,
                [10179] = true, [10180] = true, [10181] = true, [25304] = true, [27072] = true, -- Frostbolt
                [2139] = true, -- Counterspell
                -- Warlock
                [5782] = true, [6213] = true, [6215] = true, -- Fear
                [686] = true, [695] = true, [705] = true, [1088] = true, [1106] = true, [7641] = true,
                [11659] = true, [11660] = true, [11661] = true, [25307] = true, [27209] = true, -- Shadow Bolt
                [6789] = true, -- Death Coil
                -- Priest
                [8122] = true, [8124] = true, [10888] = true, [10890] = true, -- Psychic Scream
                [585] = true, [591] = true, [598] = true, [984] = true, [1004] = true, [6060] = true,
                [10933] = true, [10934] = true, [25363] = true, [25364] = true, -- Smite
                -- Druid
                [33786] = true, -- Cyclone
                [339] = true, [1062] = true, [5195] = true, [5196] = true, [9852] = true, [9853] = true, [26989] = true, -- Entangling Roots
            }
            
            if pvp_only and casting_spell_id then
                if not REFLECT_WHITELIST[casting_spell_id] then return false end
            end
            
            -- Check if in defensive stance or can switch
            if context.stance ~= STANCE.DEFENSIVE then
                if not defensive_stance_ready(context) then return false end
            end
            
            return true
        end,
        execute = function(context)
            local sr_id = 23920
            
            -- Switch to defensive stance if needed
            if context.stance ~= STANCE.DEFENSIVE then
                if cast_defensive_stance(context) then
                    return true
                end
            end
            
            if context.stance ~= STANCE.DEFENSIVE then return false end
            
            return NS.try_cast(sr_id, context.me, "[WARRIOR] Spell Reflection", { skip_range = true })
        end,
    },

    -- ============================================================================
    -- Cancel External Buff (Tier 2 Gap Feature - requires API verification)
    -- ============================================================================
    -- NOTE: Requires buff cancellation API verification
    -- If not available, this strategy will simply not trigger
    {
        name = "CancelExternalBuff",
        matches = function(context)
            local settings = context.settings or {}
            if settings.warrior_cancel_external_buff == false then return false end
            if not context.me then return false end
            
            -- Check if we have Power Word: Shield (blocks rage generation)
            local PWS_IDS = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218, 27623 }
            for _, id in ipairs(PWS_IDS) do
                if NS.has_buff and NS.has_buff(context.me, id) then
                    -- Cancel PW:S if we're low rage and need to attack
                    local rage = context.rage or 0
                    if rage < 20 then
                        return true
                    end
                end
            end
            
            -- Check for Blessing of Protection (prevents attacks)
            local BOP_IDS = { 1022, 5599, 10278 }
            for _, id in ipairs(BOP_IDS) do
                if NS.has_buff and NS.has_buff(context.me, id) then
                    -- Cancel BoP if we need to attack and HP is safe
                    local hp = context.hp or 100
                    if hp > 60 then
                        return true
                    end
                end
            end
            
            return false
        end,
        execute = function(context)
            local debug = NS.get_setting and NS.get_setting("debug_system", false) or false
            
            local PWS_IDS = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218, 27623 }
            local BOP_IDS = { 1022, 5599, 10278 }
            
            -- Try to cancel PW:S first
            for _, id in ipairs(PWS_IDS) do
                if NS.has_buff and context.me and NS.has_buff(context.me, id) then
                    if NS.cancel_buff and NS.cancel_buff(id) then
                        if debug then NS.log("[WARRIOR] Cancelled PW:S") end
                        return true
                    end
                end
            end
            
            -- Try to cancel BoP
            for _, id in ipairs(BOP_IDS) do
                if NS.has_buff and context.me and NS.has_buff(context.me, id) then
                    if NS.cancel_buff and NS.cancel_buff(id) then
                        if debug then NS.log("[WARRIOR] Cancelled BoP") end
                        return true
                    end
                end
            end
            
            return false
        end,
    },

    -- ============================================================================
    -- PvP Defensive Stance at Range (Tier 2 Gap Feature)
    -- ============================================================================
    {
        name = "PvPDefensiveStance",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_defensives == false then return false end
            if not context.is_pvp then return false end
            if not context.target then return false end
            if context.in_melee_range then return false end  -- Already in range
            
            -- Not already in defensive stance
            if context.stance == STANCE.DEFENSIVE then return false end
            
            -- Check if Defensive Stance is available
            if not defensive_stance_ready(context) then return false end
            
            -- Check if Intercept/Charge is unavailable
            local intercept_ready = false
            local charge_ready = false
            
            if SPELLS.Intercept and NS.spell_ready then
                local int_id = type(SPELLS.Intercept) == "table" and SPELLS.Intercept.id or SPELLS.Intercept
                intercept_ready = NS.spell_ready(int_id)
            end
            
            if SPELLS.Charge and NS.spell_ready then
                local chg_id = type(SPELLS.Charge) == "table" and SPELLS.Charge.id or SPELLS.Charge
                charge_ready = NS.spell_ready(chg_id)
            end
            
            -- If gap closer is ready, don't switch stance
            if intercept_ready or charge_ready then return false end
            
            -- Don't switch if we're tanking in PvE unless enabled
            if not context.is_pvp and settings.warrior_defensive_stance_pve ~= true then
                return false
            end
            
            return true
        end,
        execute = function(context)
            return cast_defensive_stance(context)
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return context.in_combat end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("warrior", strategies)
return strategies
