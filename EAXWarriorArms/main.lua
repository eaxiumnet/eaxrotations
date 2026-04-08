-- Eax Warrior Arms  main.lua
--  Arms rotation with Slam weaving, Overpower on dodge, stance dancing.

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local ooc_manager = require("libraries/ooc_manager")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type anti_fake_manager
local anti_fake_manager = require("libraries/anti_fake_manager")
---@type racial_manager
local racial_manager = require("libraries/racial_manager")
---@type middleware_manager
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")

-- Flux Feature Integration
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")
local swing_manager = require("libraries/swing_manager")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- Constants
local MORTAL_STRIKE_COST = 30
local WHIRLWIND_COST = 25
local SLAM_COST = 15
local HEROIC_STRIKE_COST = 15
local CLEAVE_COST = 20
local OVERPOWER_COST = 5
local REND_COST = 10
local EXECUTE_MIN_RAGE = 15
local EXECUTE_HP_THRESHOLD = 20
local STANCE_BUFFER_RAGE = 5
local ARMS_AOE_RADIUS = 8
local REND_REFRESH_MS = 4000
local SLAM_NOW_WINDOW_MS = 350
local SLAM_HOLD_REGION_MS = 250
local SLAM_SAFE_BUFFER_MS = 100
local FILLER_HOLD_WINDOW = 2.0

local runtime = {
    mortal_strike_id = nil,
    slam_id = nil,
    whirlwind_id = nil,
    execute_id = nil,
    heroic_strike_id = nil,
    cleave_id = nil,
    overpower_id = nil,
    rend_id = nil,
    thunder_clap_id = nil,
    battle_shout_id = nil,
    commanding_shout_id = nil,
    demoralizing_shout_id = nil,
    sunder_armor_id = nil,
    hamstring_id = nil,
    battle_stance_id = nil,
    berserker_stance_id = nil,
    defensive_stance_id = nil,
    charge_id = nil,
    intercept_id = nil,
    death_wish_id = nil,
    recklessness_id = nil,
    berserker_rage_id = nil,
    sweeping_strikes_id = nil,
    stance_swap_retention = 10,
    ww_pending_return = false,
    pending_battle_stance_return = false,
    pending_recklessness_berserker = false,
    prev_toggle_state = false,
}

local RUNTIME_SPELL_SPECS = {
    { field = "mortal_strike_id", ranks = spells.MORTAL_STRIKE },
    { field = "slam_id", ranks = spells.SLAM },
    { field = "whirlwind_id", ranks = spells.WHIRLWIND },
    { field = "execute_id", ranks = spells.EXECUTE },
    { field = "heroic_strike_id", ranks = spells.HEROIC_STRIKE },
    { field = "cleave_id", ranks = spells.CLEAVE },
    { field = "overpower_id", ranks = spells.OVERPOWER },
    { field = "rend_id", ranks = spells.REND },
    { field = "thunder_clap_id", ranks = spells.THUNDER_CLAP },
    { field = "battle_shout_id", ranks = spells.BATTLE_SHOUT },
    { field = "commanding_shout_id", ranks = spells.COMMANDING_SHOUT },
    { field = "demoralizing_shout_id", ranks = spells.DEMORALIZING_SHOUT },
    { field = "sunder_armor_id", ranks = spells.SUNDER_ARMOR },
    { field = "hamstring_id", ranks = spells.HAMSTRING },
    { field = "battle_stance_id", ranks = spells.BATTLE_STANCE },
    { field = "berserker_stance_id", ranks = spells.BERSERKER_STANCE },
    { field = "defensive_stance_id", ranks = spells.DEFENSIVE_STANCE },
    { field = "charge_id", ranks = spells.CHARGE },
    { field = "intercept_id", ranks = spells.INTERCEPT },
    { field = "death_wish_id", ranks = spells.DEATH_WISH },
    { field = "recklessness_id", ranks = spells.RECKLESSNESS },
    { field = "berserker_rage_id", ranks = spells.BERSERKER_RAGE },
    { field = "sweeping_strikes_id", ranks = spells.SWEEPING_STRIKES },
}

local function resolve_spells()
    for i = 1, #RUNTIME_SPELL_SPECS do
        local spec = RUNTIME_SPELL_SPECS[i]
        runtime[spec.field] = utils.resolve_spell_id(spec.ranks)
    end
    runtime.stance_swap_retention = utils.get_stance_swap_retention()
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function find_valid_target(me)
    return utils.find_best_target(me)
end

local function get_rage(me)
    return utils.get_rage(me)
end

local function count_nearby_enemies(me)
    return utils.enemy_count_in_radius(me, ARMS_AOE_RADIUS)
end

-- : Check if we should pool for core abilities
local function should_pool_for_core(rage, ms_cd, ww_cd)
    if ms_cd > 0 and ms_cd <= FILLER_HOLD_WINDOW then
        if (rage - SLAM_COST) < MORTAL_STRIKE_COST then return true end
    end
    if ww_cd > 0 and ww_cd <= FILLER_HOLD_WINDOW then
        if (rage - SLAM_COST) < WHIRLWIND_COST then return true end
    end
    return false
end

-- : Smart Overpower evaluation
local function should_use_overpower(me, target, rage, ms_cd, ww_cd, target_hp_pct)
    return utils.should_use_overpower_smart(me, target, rage, ms_cd, ww_cd, target_hp_pct)
end

local function try_battle_shout(me)
    if not menu.use_battle_shout:get_state() then return false end
    local shout_id = runtime.battle_shout_id
    local buff_table = spells.BUFF_BATTLE_SHOUT
    if menu.use_commanding_shout:get_state() and runtime.commanding_shout_id then
        shout_id = runtime.commanding_shout_id
        buff_table = spells.BUFF_COMMANDING_SHOUT
    end
    if not shout_id or utils.has_buff(me, buff_table) then return false end
    if utils.cast_self(shout_id, me) then
        utils.log_debug(menu, "Refreshing shout")
        return true
    end
    return false
end

local function try_cancelaura_buffs(me)
    if not me:is_in_combat() then return false end
    local hp_pct = me:get_health_percentage()
    local threshold = menu.cancelaura_hp_threshold:get()
    if menu.cancel_pws:get_state() then
        if me:has_buff(17) then
            local rage = get_rage(me)
            if rage < 30 and hp_pct > threshold then
                local ok = pcall(function() core.input.cancel_aura("Power Word: Shield") end)
                if ok then utils.log_debug(menu, "Cancelaura: PW:S"); return true end
            end
        end
    end
    if menu.cancel_bop:get_state() then
        if me:has_buff(1022) then
            if hp_pct > threshold then
                local ok = pcall(function() core.input.cancel_aura("Blessing of Protection") end)
                if ok then utils.log_debug(menu, "Cancelaura: BoP"); return true end
            end
        end
    end
    return false
end

local function try_demo_shout(me, target)
    if not menu.use_demo_shout:get_state() or not target or not runtime.demoralizing_shout_id then return false end
    if menu.pvp_cc_break_check:get_state() and utils.has_breakable_cc_nearby(me, 10) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.has_debuff(target, spells.DEBUFF_DEMORALIZING_SHOUT) then return false end
    if utils.cast_self(runtime.demoralizing_shout_id, me) then
        utils.log_debug(menu, "Demoralizing Shout")
        return true
    end
    return false
end

local function try_thunder_clap(me, target)
    if not menu.use_thunder_clap:get_state() or not target or not runtime.thunder_clap_id then return false end
    if menu.pvp_cc_break_check:get_state() and utils.has_breakable_cc_nearby(me, 10) then return false end
    if not utils.is_melee_target(me, target) then return false end
    local remaining_ms = utils.get_debuff_remaining_ms(target, spells.DEBUFF_THUNDER_CLAP)
    if remaining_ms > 2000 then return false end
    local nearby = count_nearby_enemies(me)
    if nearby < 1 then return false end
    if utils.cast_self(runtime.thunder_clap_id, me) then
        utils.log_debug(menu, "Thunder Clap")
        return true
    end
    return false
end

local function try_rend(me, target, rage, target_hp_pct)
    if not menu.use_rend:get_state() or not target or not runtime.rend_id then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD then return false end
    if utils.get_current_stance(me) ~= "battle" then return false end
    if not utils.is_melee_target(me, target) then return false end
    local rend_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_REND)
    if rend_remaining > REND_REFRESH_MS then return false end
    local ms_cd = runtime.mortal_strike_id and core.spell_book.get_spell_cooldown(runtime.mortal_strike_id) or math.huge
    if ms_cd <= 1.5 and rage < (MORTAL_STRIKE_COST + REND_COST) then return false end
    if utils.can_cast_melee(runtime.rend_id, me) and utils.cast_target(runtime.rend_id, target) then
        utils.log_debug(menu, rend_remaining > 0 and "Rend refresh" or "Rend")
        return true
    end
    return false
end

local function try_overpower(me, target, rage, target_hp_pct)
    if not menu.use_overpower:get_state() or not target or not runtime.overpower_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not core.spell_book.is_usable_spell(runtime.overpower_id) then return false end
    local ms_cd = runtime.mortal_strike_id and core.spell_book.get_spell_cooldown(runtime.mortal_strike_id) or math.huge
    local ww_cd = runtime.whirlwind_id and core.spell_book.get_spell_cooldown(runtime.whirlwind_id) or math.huge
    if not should_use_overpower(me, target, rage, ms_cd, ww_cd, target_hp_pct) then return false end
    if utils.get_current_stance(me) ~= "battle" then
        if runtime.battle_stance_id and utils.can_cast_self(runtime.battle_stance_id, me) then
            utils.cast_self(runtime.battle_stance_id, me)
            utils.set_tracked_stance("battle")
            utils.log_debug(menu, "Stance -> Battle (Overpower)")
            return true
        end
        return false
    end
    if utils.cast_target(runtime.overpower_id, target) then
        utils.log_debug(menu, "Overpower")
        return true
    end
    return false
end

local function try_mortal_strike(me, target, rage, target_hp_pct)
    if not menu.use_mortal_strike:get_state() or not target or not runtime.mortal_strike_id then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD and not menu.execute_use_ms:get_state() then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.is_spell_already_queued(runtime.mortal_strike_id) then return false end
    if utils.get_current_stance(me) ~= "battle" then
        if runtime.battle_stance_id and utils.can_stance_dance_for_cost(rage, MORTAL_STRIKE_COST, 0, runtime.stance_swap_retention) then
            if utils.can_cast_self(runtime.battle_stance_id, me) then
                utils.cast_self(runtime.battle_stance_id, me)
                utils.set_tracked_stance("battle")
                utils.log_debug(menu, "Stance -> Battle (MS)")
                return true
            end
        end
    end
    if utils.cast_target(runtime.mortal_strike_id, target) then
        utils.log_debug(menu, "Mortal Strike")
        return true
    end
    return false
end

local function try_whirlwind(me, target, rage, target_hp_pct)
    if not menu.use_whirlwind:get_state() or not target or not runtime.whirlwind_id then return false end
    if menu.pvp_cc_break_check:get_state() and utils.has_breakable_cc_nearby(me, 10) then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD and not menu.execute_use_ww:get_state() then return false end
    if not utils.is_melee_target(me, target) then return false end
    if count_nearby_enemies(me) < 2 then return false end
    if rage < WHIRLWIND_COST then return false end
    local current_stance = utils.get_current_stance(me)
    if current_stance ~= "berserker" then
        if utils.can_stance_dance_for_cost(rage, WHIRLWIND_COST, STANCE_BUFFER_RAGE, runtime.stance_swap_retention) then
            if runtime.berserker_stance_id and utils.can_cast_self(runtime.berserker_stance_id, me) then
                utils.cast_self(runtime.berserker_stance_id, me)
                utils.set_tracked_stance("berserker")
                utils.log_debug(menu, "Stance -> Berserker (WW)")
                return true
            end
        end
        return false
    end
    if utils.cast_target(runtime.whirlwind_id, target) then
        runtime.ww_pending_return = true
        utils.log_debug(menu, "Whirlwind")
        return true
    end
    return false
end

local function try_return_to_battle(me)
    if not runtime.ww_pending_return or not runtime.battle_stance_id then return false end
    if utils.get_current_stance(me) == "battle" then
        runtime.ww_pending_return = false
        return false
    end
    if utils.can_cast_self(runtime.battle_stance_id, me) and utils.cast_self(runtime.battle_stance_id, me) then
        runtime.ww_pending_return = false
        utils.set_tracked_stance("battle")
        utils.log_debug(menu, "Stance -> Battle (return)")
        return true
    end
    return false
end

local function try_slam(me, target, rage, target_hp_pct)
    if not menu.use_slam:get_state() or not target or not runtime.slam_id then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD then return false end
    if not utils.is_melee_target(me, target) then return false end
    local ms_cd = runtime.mortal_strike_id and core.spell_book.get_spell_cooldown(runtime.mortal_strike_id) or math.huge
    local ww_cd = runtime.whirlwind_id and core.spell_book.get_spell_cooldown(runtime.whirlwind_id) or math.huge
    if should_pool_for_core(rage, ms_cd, ww_cd) then return false end
    local safety_buffer_ms = menu.slam_safety_buffer_ms:get() or SLAM_SAFE_BUFFER_MS
    if not utils.can_slam_without_clipping(me, runtime.slam_id, safety_buffer_ms) then return false end
    if utils.cast_target(runtime.slam_id, target) then
        utils.log_debug(menu, "Slam")
        return true
    end
    return false
end

local function try_execute(me, target, rage, target_hp_pct)
    if not menu.use_execute:get_state() or not target or not runtime.execute_id then return false end
    if target_hp_pct > EXECUTE_HP_THRESHOLD then return false end
    if rage < EXECUTE_MIN_RAGE then return false end
    if utils.cast_target(runtime.execute_id, target) then
        utils.log_debug(menu, "Execute")
        return true
    end
    return false
end

local function try_heroic_strike(me, target, rage, target_hp_pct)
    if not utils.is_melee_target(me, target) then return false end
    if target_hp_pct <= EXECUTE_HP_THRESHOLD and not menu.execute_use_hs:get_state() then return false end
    if utils.is_spell_already_queued(runtime.heroic_strike_id or runtime.cleave_id) then return false end
    local nearby = count_nearby_enemies(me)
    local use_cleave = nearby >= 2 and runtime.cleave_id
    local dump_id = use_cleave and runtime.cleave_id or runtime.heroic_strike_id
    if not dump_id then return false end
    local dump_cost = use_cleave and CLEAVE_COST or HEROIC_STRIKE_COST
    local threshold = menu.hs_rage_threshold:get()
    if menu.hs_trick:get_state() then
        threshold = 30
    end
    if rage < (threshold + dump_cost) then return false end
    if utils.can_cast_melee(dump_id, me) and utils.cast_target_fast(dump_id, target) then
        utils.log_debug(menu, use_cleave and "Cleave" or "Heroic Strike")
        return true
    end
    return false
end

local function try_charge(me, target)
    if not runtime.charge_id then return false end
    if me:is_in_combat() then return false end
    if not utils.can_cast_hostile(runtime.charge_id, me, target) then return false end
    if utils.cast_target_fast(runtime.charge_id, target) then
        utils.log_debug(menu, "Charge")
        return true
    end
    return false
end

local function try_death_wish(me, target)
    if not menu.use_death_wish:get_state() or not runtime.death_wish_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_DEATH_WISH) then return false end
    if not utils.can_cast_self(runtime.death_wish_id, me) then return false end
    -- TTD gating
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and target then
        ---@type combat_forecast
        local forecast = require("libraries/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false -- Target dies too soon, don't waste CD
        end
    end
    if utils.cast_self_fast(runtime.death_wish_id, me) then
        utils.log_debug(menu, "Death Wish")
        return true
    end
    return false
end

local function try_berserker_rage(me, target)
    if not menu.use_berserker_rage:get_state() or not runtime.berserker_rage_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_BERSERKER_RAGE) then return false end
    if utils.get_current_stance(me) ~= "berserker" then return false end
    if not utils.can_cast_self(runtime.berserker_rage_id, me) then return false end
    -- TTD gating
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and target then
        ---@type combat_forecast
        local forecast = require("libraries/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false -- Target dies too soon, don't waste CD
        end
    end
    if utils.cast_self_fast(runtime.berserker_rage_id, me) then
        utils.log_debug(menu, "Berserker Rage")
        return true
    end
    return false
end

local function try_recklessness(me, target)
    if not menu.use_recklessness:get_state() or not runtime.recklessness_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_RECKLESSNESS) then return false end
    -- TTD gating
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and target then
        ---@type combat_forecast
        local forecast = require("libraries/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false -- Target dies too soon, don't waste CD
        end
    end
    local in_berserker = utils.get_current_stance(me) == "berserker"
    if not in_berserker and not runtime.pending_recklessness_berserker then
        local rage = get_rage(me)
        if not utils.can_stance_dance_for_cost(rage, 0, 0, runtime.stance_swap_retention) then return false end
        if runtime.berserker_stance_id and utils.can_cast_self(runtime.berserker_stance_id, me) then
            utils.cast_self(runtime.berserker_stance_id, me)
            utils.set_tracked_stance("berserker")
            utils.log_debug(menu, "Stance -> Berserker (Recklessness)")
            runtime.pending_recklessness_berserker = true
            return true
        end
        return false
    end
    if not in_berserker and runtime.pending_recklessness_berserker then return false end
    if not utils.can_cast_self(runtime.recklessness_id, me) then return false end
    if utils.cast_self_fast(runtime.recklessness_id, me) then
        utils.log_debug(menu, "Recklessness")
        runtime.pending_battle_stance_return = true
        return true
    end
    return false
end

local function try_sweeping_strikes(me, target)
    if not menu.use_sweeping_strikes:get_state() or not runtime.sweeping_strikes_id then return false end
    if utils.has_buff(me, spells.BUFF_SWEEPING_STRIKES) then return false end
    if count_nearby_enemies(me) < 2 then return false end
    -- TTD gating
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and target then
        ---@type combat_forecast
        local forecast = require("libraries/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false -- Target dies too soon, don't waste CD
        end
    end
    if not utils.can_cast_self(runtime.sweeping_strikes_id, me) then return false end
    if utils.cast_self_fast(runtime.sweeping_strikes_id, me) then
        utils.log_debug(menu, "Sweeping Strikes")
        return true
    end
    return false
end

-- PvP-specific rotation functions
local pvp_context_cache = nil
local pvp_context_last_update = 0
local PVP_CONTEXT_THROTTLE_S = 1.0

-- Anti-fake cast tracking
local _cast_tracking = {
    target_guid = nil,
    cast_start_time = 0,
    is_tracking = false,
}

local function get_pvp_context(me, target)
    local now = _core_time()
    if not pvp_context_cache or (now - pvp_context_last_update) >= PVP_CONTEXT_THROTTLE_S then
        pvp_context_cache = utils.detect_pvp_context(me, target)
        pvp_context_last_update = now
    end
    return pvp_context_cache
end

local function is_pvp_active(ctx)
    return utils.is_pvp_active(menu, ctx)
end

-- Maintain Hamstring on enemy players in PvP
local function try_pvp_hamstring(me, target, rage, ctx)
    if not ctx.target_is_player then return false end
    if not utils.is_pvp_setting_enabled(menu, "pvp_hamstring") then return false end
    if not runtime.hamstring_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if rage < HAMSTRING_COST then return false end
    -- Skip if target already has hamstring debuff
    if utils.has_debuff(target, spells.DEBUFF_HAMSTRING) then return false end
    if utils.cast_target(runtime.hamstring_id, target) then
        utils.log_debug(menu, "PvP Hamstring")
        return true
    end
    return false
end

-- Piercing Howl for AoE snare in PvP
local function try_pvp_piercing_howl(me, target, rage, ctx)
    if not utils.is_pvp_setting_enabled(menu, "pvp_piercing_howl") then return false end
    if not runtime.piercing_howl_id then return false end
    if rage < 10 then return false end  -- Piercing Howl costs 10 rage
    -- Only use if 2+ enemies nearby and we're in PvP
    if not ctx.is_pvp then return false end
    local nearby = count_nearby_enemies(me)
    if nearby < 2 then return false end
    if utils.cast_self(runtime.piercing_howl_id, me) then
        utils.log_debug(menu, "PvP Piercing Howl")
        return true
    end
    return false
end

-- Rend anti-stealth for Rogues/Druids
local function try_pvp_rend_stealth(me, target, rage, ctx)
    if not ctx.target_is_player then return false end
    if not utils.is_pvp_setting_enabled(menu, "pvp_rend_stealth") then return false end
    if not menu.use_rend:get_state() then return false end
    if not runtime.rend_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if rage < 10 then return false end  -- Rend costs 10 rage
    -- Check if target is Rogue or Druid (can stealth)
    local target_class = target.get_class and target:get_class() or nil
    if not target_class or not utils.can_stealth(target_class) then return false end
    -- Skip if target already has rend
    if utils.has_debuff(target, spells.DEBUFF_REND) then return false end
    -- Must be in Battle Stance or Berserker Stance for Rend in TBC
    local stance = utils.get_stance_name()
    if stance ~= "Battle" and stance ~= "Berserker" then return false end
    if utils.cast_target(runtime.rend_id, target) then
        utils.log_debug(menu, "PvP Rend (Anti-Stealth)")
        return true
    end
    return false
end

-- Defensive Stance when out of melee range in PvP
local function try_pvp_defensive_stance(me, target, ctx)
    if not ctx.is_pvp then return false end
    if not utils.is_pvp_setting_enabled(menu, "pvp_def_stance_range") then return false end
    if not runtime.defensive_stance_id then return false end
    -- Check if we're out of melee range
    local dist_sq = utils.dist_squared(me, target)
    if dist_sq < 36 then return false end  -- 6 yards squared = 36
    -- Check if already in defensive stance
    if utils.get_stance_name() == "Defensive" then return false end
    -- Switch to defensive stance
    if utils.cast_self(runtime.defensive_stance_id, me) then
        utils.log_debug(menu, "PvP Defensive Stance (Out of Range)")
        return true
    end
    return false
end

-- PvP Interrupt with CC fallback and anti-fake protection
local function try_pvp_interrupt(me, target, ctx)
    if not ctx.target_is_player then return false end
    if not utils.is_pvp_setting_enabled(menu, "pvp_interrupt_cc_fallback") then return false end
    if not interrupt_manager.should_interrupt(target) then return false end
    
    -- Anti-fake: Record cast start for tracking
    local target_guid = target:get_guid()
    if target_guid and target:is_casting_spell() then
        if _cast_tracking.target_guid ~= target_guid or not _cast_tracking.is_tracking then
            anti_fake_manager.record_cast_start(target)
            _cast_tracking.target_guid = target_guid
            _cast_tracking.cast_start_time = _core_time()
            _cast_tracking.is_tracking = true
        end
    end
    
    -- Anti-fake: Check if this is likely a fake cast
    if anti_fake_manager.is_likely_fake(target) then
        -- Add randomized delay to catch real casts after fake
        local delay = anti_fake_manager.get_interrupt_delay(target, true)
        if delay > 0 then
            local cast_time_remaining = 0
            local ok_rem, rem = pcall(function() return target:get_spell_cast_time_remaining() end)
            if ok_rem and rem then cast_time_remaining = rem end
            
            -- Only delay if we have enough time remaining
            if cast_time_remaining > (delay * 1000 + 200) then
                utils.log_debug(menu, string.format("Anti-fake: Delaying interrupt by %.0fms", delay * 1000))
                return false  -- Skip this tick, will retry with delay
            end
        end
    end
    
    -- Try normal interrupt first
    if menu.use_interrupt:get_state() then
        if interrupt_manager.try_interrupt(me, target, "warrior", utils) then
            anti_fake_manager.record_cast_end(target, true)
            _cast_tracking.is_tracking = false
            return true
        end
    end
    -- CC fallback: use Intimidating Shout if interrupt is on CD
    if runtime.intimidating_shout_id and utils.can_cast_self(runtime.intimidating_shout_id, me) then
        if utils.cast_self(runtime.intimidating_shout_id, me) then
            utils.log_debug(menu, "PvP CC Interrupt Fallback (Intimidating Shout)")
            anti_fake_manager.record_cast_end(target, false)
            _cast_tracking.is_tracking = false
            return true
        end
    end
    return false
end

local function on_update()
    if not (menu.enabled and menu.enabled:get_state()) then return end
    local me = _get_local_player()
    if not me or not me:is_valid() then return end
    
    -- Crowd Control check - return early if stunned/silenced/feared etc.
    if utils.is_cced and utils.is_cced(me) then return end
    
    resolve_spells()
    
    -- OOC handling via shared ooc_manager
    if not me:is_in_combat() then
        local ooc_result = ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = runtime.battle_shout_id,
                    buff_ids = spells.BUFF_BATTLE_SHOUT,
                    name = "Battle Shout",
                    toggle = menu.use_battle_shout
                },
            }
        })
        if ooc_result then return end
    end
    
    -- Initialize middleware on first run
    if not middleware_manager.is_initialized() then
        middleware_manager.initialize(menu)
    end
    
    -- Sync dashboard settings (safe pcall for uninitialized menu items)
    local ok_show, show_dashboard = pcall(function() return menu.show_dashboard:get_state() end)
    if ok_show then
        dashboard.set_enabled(show_dashboard)
    end
    
    local ok_opacity, opacity = pcall(function() return menu.dashboard_opacity:get() end)
    if ok_opacity then
        dashboard.set_opacity(opacity)
    end
    
    local ok_scale, scale = pcall(function() return menu.dashboard_scale:get() end)
    if ok_scale then
        dashboard.set_scale(scale)
    end
    
    local ok_x, pos_x = pcall(function() return menu.dashboard_x:get() end)
    local ok_y, pos_y = pcall(function() return menu.dashboard_y:get() end)
    if ok_x and ok_y then
        dashboard.set_position(pos_x, pos_y)
    end
    
    local target = find_valid_target(me)
    if not target then return end
    local target_hp_pct = target:get_health_percentage()
    local rage = get_rage(me)
    
    -- Flux: Update swing manager
    swing_manager:update_swing(me)
    
    -- Flux: Sample combat forecast
    if combat_forecast and target and target:is_valid() then
        combat_forecast:sample(target)
    end
    
    -- Flux: Check swing delay (don't clip auto attacks)
    if swing_manager:is_swing_landing_soon(0.15) then return end
    
    -- Burst & Trinket Automation (ported from Flux)
    local combat_time = _core_time() - (ctx.combat_start_time or _core_time())
    local is_burst_window = burst_manager.should_auto_burst(me, target, combat_time, menu)
    if is_burst_window then
        -- Arms burst CDs: Sweeping Strikes, Retaliation
        if (menu.use_sweeping_strikes and menu.use_sweeping_strikes:get_state()) then
            if try_sweeping_strikes(me, target) then return end
        end
    end
    
    -- Flux: Trinkets V2
    trinket_manager.check_trinkets_v2(me, target, is_burst_window, force_commands, combat_forecast, menu)
    
    -- Swing Manager: Queue Heroic Strike or Cleave optimally
    if (menu.use_swing_manager and menu.use_swing_manager:get_state()) and
       (menu.use_heroic_strike and menu.use_heroic_strike:get_state()) then
        local nearby = count_nearby_enemies(me)
        local use_cleave = nearby >= 2 and runtime.cleave_id
        local threshold = use_cleave and 
            ((menu.swing_cleave_threshold and menu.swing_cleave_threshold:get()) or 60) or
            ((menu.swing_queue_threshold and menu.swing_queue_threshold:get()) or 50)
        
        if target_hp_pct > EXECUTE_HP_THRESHOLD then
            swing_manager.queue_next_swing(me, runtime.heroic_strike_id, runtime.cleave_id, threshold, use_cleave, target)
        end
    end
    
    -- PvP context detection
    local pvp_ctx = get_pvp_context(me, target)
    local pvp_active = is_pvp_active(pvp_ctx)
    
    -- Build middleware context
    local settings = {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or false,
        use_healing_potion = (menu.use_health_potion and menu.use_health_potion:get_state()) or false,
        use_blood_fury = (menu.use_blood_fury and menu.use_blood_fury:get_state()) or false,
        use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false,
        use_stoneform = (menu.use_stoneform and menu.use_stoneform:get_state()) or false,
    }
    local ctx = middleware_manager.build_context(me, target, settings)
    
    -- Execute middleware BEFORE rotation (handles healthstones, potions, racials)
    local mw_result, mw_msg = middleware_manager.execute(nil, ctx)
    if mw_result then
        return
    end
    
    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    -- Warrior special: Try Berserker Rage for fear before stopping
    if should_stop and cc_reason == "FEAR" then
        if utils.try_berserker_rage_fear_break(me, menu) then
            return  -- Successfully broke fear
        end
    end

    if should_stop then
        return  -- Stop rotation while CC'd
    end
    
    -- PvP: Defensive stance when out of range
    if pvp_active and try_pvp_defensive_stance(me, target, pvp_ctx) then return end
    
    utils.ensure_melee_auto_attack(me, target)
    if try_charge(me, target) then return end
    if try_cancelaura_buffs(me) then return end
    if try_return_to_battle(me) then return end
    if runtime.pending_battle_stance_return and runtime.battle_stance_id then
        if utils.can_cast_self(runtime.battle_stance_id, me) then
            utils.cast_self(runtime.battle_stance_id, me)
            runtime.pending_battle_stance_return = false
            utils.set_tracked_stance("battle")
            utils.log_debug(menu, "Stance -> Battle (after Recklessness)")
        end
    end
    
    -- PvP: Interrupt with CC fallback
    if pvp_active and try_pvp_interrupt(me, target, pvp_ctx) then return end
    
    -- Normal interrupt
    if target and interrupt_manager.should_interrupt(target) then
        if menu.use_interrupt:get_state() then
            if interrupt_manager.try_interrupt(me, target, "warrior", utils) then
                anti_fake_manager.record_cast_end(target, true)
                _cast_tracking.is_tracking = false
                return
            end
        end
    end
    
    -- Note: Offensive racials (Blood Fury, Berserking) now handled by middleware
    if try_battle_shout(me) then return end
    if try_demo_shout(me, target) then return end
    if try_thunder_clap(me, target) then return end
    
    -- PvP: Piercing Howl for AoE snare
    if pvp_active and try_pvp_piercing_howl(me, target, rage, pvp_ctx) then return end
    
    if try_death_wish(me, target) then return end
    if try_berserker_rage(me, target) then return end
    if try_recklessness(me, target) then return end
    if try_sweeping_strikes(me, target) then return end
    
    -- PvP: Rend anti-stealth (high priority vs Rogues/Druids)
    if pvp_active and try_pvp_rend_stealth(me, target, rage, pvp_ctx) then return end
    
    if try_execute(me, target, rage, target_hp_pct) then return end
    if try_overpower(me, target, rage, target_hp_pct) then return end
    if try_rend(me, target, rage, target_hp_pct) then return end
    if try_mortal_strike(me, target, rage, target_hp_pct) then return end
    if try_whirlwind(me, target, rage, target_hp_pct) then return end
    if try_slam(me, target, rage, target_hp_pct) then return end
    
    -- PvP: Maintain Hamstring on players
    if pvp_active and try_pvp_hamstring(me, target, rage, pvp_ctx) then return end
    
    if try_heroic_strike(me, target, rage, target_hp_pct) then return end
end

local function on_control_panel()
    local elements = {}
    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[EAX] Enable"
    table.insert(elements, {
        type = "checkbox",
        id = "enabled",
        label = display_name,
        value = menu.enabled:get_state(),
        on_change = function(new_val) menu.enabled:set(new_val) end,
    })
    table.insert(elements, {
        type = "keybind",
        id = "toggle_key",
        label = "Toggle Key",
        value = toggle_key_code,
        on_change = function(new_val) menu.toggle_key:set_key_code(new_val) end,
    })
    return elements
end

resolve_spells()

-- Initialize Flux force_commands
force_commands:init()

core.register_on_update_callback(on_update)
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)
core.register_on_render_control_panel_callback(on_control_panel)

-- Initialize dashboard
local dashboard_config = require("libraries/dashboard_config")
dashboard.init(dashboard_config)
dashboard.set_enabled((menu.show_dashboard and menu.show_dashboard:get_state()) or true)
if dashboard.register_render_callback then
    dashboard.register_render_callback()
end

-- Export toggle settings for external access
local NS = _G.EAXWarriorArms and _G.EAXWarriorArms.NS or {}
_G.EAXWarriorArms = _G.EAXWarriorArms or {}
_G.EAXWarriorArms.NS = NS
NS.toggle_menu = menu.toggle_menu

