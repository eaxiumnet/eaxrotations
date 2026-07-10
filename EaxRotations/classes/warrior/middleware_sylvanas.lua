-- warrior/middleware_sylvanas.lua — Warrior rotation middleware (stance, rage, battle shout).
-- WHAT:  pre-strategy middleware that enriches context with stance state, rage level, and shout coverage.
-- WHEN:  every tick before strategy evaluation.
-- WHY:   centralizes warrior-specific context enrichment so specs stay focused on rotation logic.
-- SAFETY: nil-guards on all menu references; no allocations in on_update path.

-- Warrior shared middleware.

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { DEFENSIVE = 2 }
local BATTLE_SHOUT_BUFFS = CONSTANTS.BATTLE_SHOUT_IDS or { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local HAMSTRING_DEBUFF = { 25212, 7373, 7372, 1715 }

local function defensive_spell_ready(spell, context)
    local me = context.me or NS.GetPlayer()
    if not NS.spell_ready then return false end
    return spell and me and NS.spell_ready(spell, me, { skip_range = true }) == true
end

local function should_use_warrior_defensive(context)
    local threshold = spec_kit.setting_number(context, "defensive_hp_threshold", 30)
    if not spec_kit.setting_bool(context, "use_defensives", true) then return false end
    return context.in_combat == true and (context.hp or 100) < threshold
end

local function defensive_stance_ready(context)
    return context.stance == STANCE.DEFENSIVE or defensive_spell_ready(SPELLS.DefensiveStance, context)
end

local function cast_defensive_stance(context)
    if context.stance == STANCE.DEFENSIVE then return false end
    return NS.try_cast(SPELLS.DefensiveStance, context.me or NS.GetPlayer(), "[WARRIOR] Defensive Stance", { skip_range = true }) == true
end

local function cast_warrior_defensive(context, spell, reason)
    if context.stance ~= STANCE.DEFENSIVE and cast_defensive_stance(context) then return true end
    if context.stance ~= STANCE.DEFENSIVE then return false end
    return NS.try_cast(spell, context.me or NS.GetPlayer(), reason, { skip_range = true }) == true
end

local function unit_is_moving(unit)
    local is_moving = NS.safe_field and NS.safe_field(unit, "is_moving") or nil
    if type(is_moving) ~= "function" then return false end
    local ok, moving = pcall(is_moving, unit)
    return ok and moving == true
end

-- AoE/cleave spell IDs for PvP CC gating (any rank learned = gate active)
local WARRIOR_AOE_IDS = { 845, 1680, 12328 }  -- Cleave, Whirlwind, Sweeping Strikes

-- Disarm target classes: melee classes that lose weapon-based damage when disarmed
local DISARM_CLASS_IDS = CONSTANTS.DISARM_CLASS_IDS or { [1] = true, [2] = true, [4] = true, [7] = true }

-- Pre-allocated tables for hot-path match/execute functions (avoid per-frame allocation)
local PWS_IDS = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218, 27623 }
local BOP_IDS = { 1022, 5599, 10278 }

-- Throttled CC-nearby scan for AoE gating (avoids a 50-enemy scan every frame).
-- The PvPCCGate middleware strategy stashes the result on
-- context.warrior_aoe_cc_nearby; spec-level AoE matches
-- (Cleave/Whirlwind/Sweeping Strikes/Thunder Clap) consult that flag so the
-- rotation is NOT short-circuited (the old `return true` froze the entire spec
-- rotation whenever a sheeped/sapped mob was within 15yd, even in PvE).
local _cc_scan_last = -1
local _cc_scan_result = false
local function cc_nearby_throttled(range, interval)
    local now = (NS.time_now and NS.time_now()) or 0
    if now - _cc_scan_last >= (interval or 0.5) then
        _cc_scan_last = now
        _cc_scan_result = CCGateDB.is_any_nearby_enemy_under_cc(NS, range or 15) and true or false
    end
    return _cc_scan_result
end

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
    [46561] = true, -- Fear (SWP Sunblade Dusk Priest)
    [34984] = true, -- Psychic Horror (Underbog Fen Ray)
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

local strategies = {

    interrupt_manager.register_interrupt_spell("warrior", "Pummel", SPELLS, 3),

    {
        name = "Defensive",
        matches = function(context)
            if not should_use_warrior_defensive(context) then return false end
            if context.stance ~= STANCE.DEFENSIVE and not defensive_stance_ready(context) then return false end
            return (spec_kit.setting_bool(context, "use_last_stand", true) and defensive_spell_ready(SPELLS.LastStand, context))
                or (spec_kit.setting_bool(context, "use_shield_wall", true) and defensive_spell_ready(SPELLS.ShieldWall, context))
        end,
        execute = function(context)
            if spec_kit.setting_bool(context, "use_last_stand", true) and defensive_spell_ready(SPELLS.LastStand, context) then
                return cast_warrior_defensive(context, SPELLS.LastStand, "[WARRIOR] Last Stand")
            end
            if spec_kit.setting_bool(context, "use_shield_wall", true) and defensive_spell_ready(SPELLS.ShieldWall, context) then
                return cast_warrior_defensive(context, SPELLS.ShieldWall, "[WARRIOR] Shield Wall")
            end
            return false
        end,
    },

    {
        name = "SelfBuff",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_self_buffs", true) or not spec_kit.setting_bool(context, "use_battle_shout", true) then return false end
            -- BUGFIX (2026-06-29): previously this called ``NS.has_player_buff``
            -- without nil-guarding the API.  On PS builds where the function
            -- is missing, every tick would crash the dispatcher.  Now we check
            -- the function exists; if it doesn't, we skip the buff-state gate
            -- and let the throttled broken_api path decide (next line).
            if NS.has_player_buff and NS.has_player_buff(BATTLE_SHOUT_BUFFS) then return false end
            -- Throttle on PS builds where aura API is broken and has_player_buff always returns false
            if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.BattleShout, 10.0) then return false end
            return defensive_spell_ready(SPELLS.BattleShout, context)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.BattleShout, context.me or NS.GetPlayer(), "[WARRIOR] Battle Shout", { skip_range = true }) == true
        end,
    },

    {
        name = "PvPIntercept",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_pvp_defensives", true) then return false end
            if not (context.is_pvp or (context.settings and context.settings.pvp_mode)) then return false end
            if not context.in_combat then return false end
            -- Intercept is a gap-closer: fire when the target is OUT of melee range
            -- but inside Intercept's 8-25yd band (i.e. we are being kited).
            -- (Previously this gated on NS.should_kite, which requires the target to
            -- be IN melee range + low HP — the exact opposite of when to Intercept.)
            local dist = context.target_distance or context.target_range or context.distance or 0
            if dist < 8 or dist > 25 then return false end
            return true
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Intercept, context.target, "[WARRIOR] Intercept", { expected_cooldown = 15 })
        end,
    },

{
        name = "PvPHamstring",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_pvp_defensives", true) then return false end
            local target = context.target
            if not (target and NS.is_melee_target and NS.is_melee_target(target, context.me)) then return false end
            if not unit_is_moving(target) then return false end
            if NS.debuff_up(target, HAMSTRING_DEBUFF) then return false end
            return true
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Hamstring, context.target, "[WARRIOR] Hamstring")
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
            if not spec_kit.setting_bool(context, "hs_trick", true) then return false end
            if not context.has_valid_enemy_target then return false end
            local me = context.me
            if not me then return false end
            local mh_until = NS.swing_time_until and NS.swing_time_until(me) or 999
            if mh_until >= 1.5 then return false end
            if not NS.is_current_spell then return false end
            local hs_id = SPELLS.HeroicStrike and SPELLS.HeroicStrike.id and SPELLS.HeroicStrike:id() or nil
            local cleave_id = SPELLS.Cleave and SPELLS.Cleave.id and SPELLS.Cleave:id() or nil
            if not (hs_id and NS.is_current_spell(hs_id)) and not (cleave_id and NS.is_current_spell(cleave_id)) then return false end
            return true
        end,
        execute = function(context)
            local should_dequeue = false
            local reason = ""
            local me = context.me
            local mh_remaining = NS.swing_time_until and me and NS.swing_time_until(me) or 999
            local target = context.target
            local rage = context.rage or 0

            if mh_remaining > 0 and mh_remaining <= 0.4 then
                local hs_cost = 15
                if rage < hs_cost then
                    should_dequeue = true
                    reason = "Low rage (" .. tostring(rage) .. ")"
                end
            end

            if not should_dequeue and target then
                -- Hold rage for Pummel if the target is casting an interruptible spell.
                local is_casting = NS.safe_field and NS.safe_field(target, "is_casting")
                local cast_ok, casting = false, false
                if is_casting then cast_ok, casting = pcall(is_casting, target) end
                if cast_ok and casting then
                    local get_casting_spell_id = NS.safe_field and NS.safe_field(target, "get_casting_spell_id")
                    local ok_sid, spell_id = false, nil
                    if get_casting_spell_id then ok_sid, spell_id = pcall(get_casting_spell_id, target) end
                    if ok_sid and spell_id then
                        local hs_cost = 15
                        local pummel_cost = 10
                        if rage < (hs_cost + pummel_cost) then
                            should_dequeue = true
                            reason = "Hold for interrupt (rage: " .. tostring(rage) .. ")"
                        end
                    end
                end
            end

            if not should_dequeue then
                local target_hp = context.target_hp or 100
                if target_hp <= 20 then
                    local playstyle = context.settings and context.settings.playstyle or "fury"
                    local exec_key = playstyle .. "_execute_phase"
                    local hs_exec_key = playstyle .. "_hs_during_execute"
                    local s = context.settings
                    if s and s[exec_key] and not (s[hs_exec_key] == false) then
                        should_dequeue = true
                        reason = "Execute phase"
                    end
                end
            end

            if should_dequeue then
                if NS.cancel_spells then NS.cancel_spells() end
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
            if not spec_kit.setting_bool(context, "warrior_use_spell_reflection", true) then return false end
            if not context.target then return false end
            
            -- PvP only mode check
            local pvp_only = spec_kit.setting_bool(context, "warrior_reflect_pvp_only", true)
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
                local ok1, val1 = pcall(function()
                    if context.target.is_casting_spell then return context.target:is_casting_spell() end
                    return false
                end)
                if ok1 then is_casting = val1 end

                local ok2, val2 = pcall(function()
                    if context.target.get_active_spell_id then return context.target:get_active_spell_id() end
                    return nil
                end)
                if ok2 then casting_spell_id = val2 end
            end
            
            if not is_casting then return false end
            
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
            if not spec_kit.setting_bool(context, "warrior_cancel_external_buff", true) then return false end
            if not context.me then return false end
            
            -- Check if we have Power Word: Shield (blocks rage generation)
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
        end,        execute = function(context)
            -- Try to cancel PW:S first
            for _, id in ipairs(PWS_IDS) do
                if NS.has_buff and context.me and NS.has_buff(context.me, id) then
                    if NS.cancel_buff and NS.cancel_buff(id) then
                        return true
                    end
                end
            end

            -- Try to cancel BoP
            for _, id in ipairs(BOP_IDS) do
                if NS.has_buff and context.me and NS.has_buff(context.me, id) then
                    if NS.cancel_buff and NS.cancel_buff(id) then
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
            if not spec_kit.setting_bool(context, "use_pvp_defensives", true) then return false end
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
            if not context.is_pvp and not spec_kit.setting_bool(context, "warrior_defensive_stance_pve", false) then
                return false
            end
            
            return true
        end,
        execute = function(context)
            return cast_defensive_stance(context)
        end,
    },

    -- ============================================================================
    -- PvP: SHIELD SLAM PURGE — dispel 1 magic buff (BoP, PW:S, Ice Barrier, etc.)
    -- Shared warrior offensive dispel pattern.
    -- Requires Defensive Stance + shield equipped. Stance dances if needed.
    -- ============================================================================
    {
        name = "ShieldSlamPurge",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_shield_slam_purge", true) then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not context.target then return false end
            if not (context.is_pvp or false) then return false end
            -- Shield Slam is a melee attack — must be in range
            if not context.in_melee_range then return false end
            -- Target must be a player (PvP only — Shield Slam purge is niche in PvE)
            if spec_kit.setting_bool(context, "shield_slam_purge_pvp_only", true) then
                local ok, is_player = pcall(function() return context.target:is_player() end)
                if not (ok and is_player) then return false end
            end
            -- Check if target has a priority dispellable buff
            local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(context.target, NS)
            if not best_id then return false end
            context._ss_purge_name = best_name
            return true
        end,
        execute = function(context)
            -- Shield Slam requires Defensive Stance
            if context.stance ~= STANCE.DEFENSIVE then
                -- Stance dance: swap to Defensive if we can afford the rage loss
                if defensive_stance_ready(context) then
                    return cast_defensive_stance(context)
                end
                return false
            end
            local name = context._ss_purge_name or "buff"
            return NS.try_cast(SPELLS.ShieldSlam, context.target, "[WARRIOR] Shield Slam purge → " .. name, { expected_cooldown = 6 })
        end,
    },

    -- ============================================================================
    -- PvP: DISARM — remove enemy melee weapon (10s, Defensive Stance required)
    -- Uses offensive dispel priority DB for on_burst trigger mode:
    -- disarms when target has priority buffs.
    -- NOTE: Does not check disarm immunity/DR (API not exposed in EaxRotations).
    --       NS.spell_ready + try_cast will fail gracefully on immune targets.
    -- ============================================================================
    {
        name = "WarriorDisarm",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_disarm", true) then return false end
            -- Skip entirely if Disarm not learned (level < 22)
            if not (NS.is_spell_learned and NS.is_spell_learned(676)) then return false end
            if not context.in_combat then return false end
            if not (context.is_pvp or false) then return false end
            if not context.has_valid_enemy_target then return false end
            if not context.target then return false end
            if not context.in_melee_range then return false end
            -- Target must be a player
            if spec_kit.setting_bool(context, "disarm_pvp_only", true) then
                local ok, is_player = pcall(function() return context.target:is_player() end)
                if not (ok and is_player) then return false end
            end
            -- Check target class is melee (Warrior/Rogue/Paladin/Shaman)
            local ok, class_id = pcall(function() return context.target:get_class() end)
            if not (ok and type(class_id) == "number") then return false end
            if not DISARM_CLASS_IDS[class_id] then return false end
            -- Trigger mode: on_burst requires target has priority dispellable buffs
            local trigger = spec_kit.setting(context, "disarm_trigger", "on_burst")
            if trigger == "on_burst" then
                local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(context.target, NS)
                if not best_id or (best_priority or 0) < 3 then return false end  -- High+ tier only
                context._disarm_buff_name = best_name
            end
            return true
        end,
        execute = function(context)
            -- Disarm requires Defensive Stance — stance dance if rage-safe
            if context.stance ~= STANCE.DEFENSIVE then
                -- Conservative rage gate: don't swap if high rage with no TM
                if (context.rage or 0) > 25 then return false end
                if defensive_stance_ready(context) then
                    return cast_defensive_stance(context)
                end
                return false
            end
            local label = context._disarm_buff_name
                and ("[WARRIOR] Disarm → " .. context._disarm_buff_name)
                or "[WARRIOR] Disarm"
            return NS.try_cast(SPELLS.Disarm, context.target, label, { expected_cooldown = 60 })
        end,
    },

    -- ============================================================================
    -- PvP CC Gate: placed at END of middleware so defensives still fire.
    -- Only gates spec-level AoE/cleave (Whirlwind, Cleave, Sweeping Strikes).
    -- ============================================================================
    {
        name = "PvPCCGate",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_pvp_cc_gating", true) then return false end
            if not context.in_combat then return false end
            -- Only worth scanning when the warrior actually has an AoE ability learned.
            for _, id in ipairs(WARRIOR_AOE_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then return true end
            end
            return false
        end,
        execute = function(context)
            -- Refresh the CC-nearby flag (throttled). Deliberately return false so the
            -- spec rotation still runs; only AoE abilities gate themselves on the flag.
            context.warrior_aoe_cc_nearby = cc_nearby_throttled(15, 0.5)
            return false
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return consumable_manager.should_check(context) end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("warrior", strategies)
return strategies
