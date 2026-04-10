-- Eax Warrior Protection  main.lua
--  Protection rotation with Shield Slam priority, Revenge procs, Sunder maintenance.

-- Load header first to check if we should load at all
local header = require("header")
if not header.load then
    return
end

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local swing_manager = require("libraries/swing_manager")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type racial_manager
local racial_manager = require("libraries/racial_manager")
---@type middleware_manager
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local ooc_manager = require("libraries/ooc_manager")

-- NEW: Advanced tanking libraries from Flux port
---@type context_builder
local context_builder = require("libraries/context_builder")
---@type threat_tab_manager
local threat_tab_manager = require("libraries/threat_tab_manager")
---@type smart_defensive
local smart_defensive = require("libraries/smart_defensive")

-- NEW: Trinket manager for defensive trinket mode
local trinket_manager = require("libraries/trinket_manager")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- Constants
local SHIELD_SLAM_COST = 20
local REVENGE_COST = 5
local DEVASTATE_COST = 15
local HEROIC_STRIKE_COST = 15
local THUNDER_CLAP_COST = 20
local HAMSTRING_COST = 10
local SHIELD_BLOCK_COST = 10
local EXECUTE_HP_THRESHOLD = 20
local PROT_AOE_RADIUS = 8
local SUNDER_MAX_STACKS = 5
local SUNDER_REFRESH_WINDOW_MS = 3000
local TC_REFRESH_WINDOW_MS = 2000

local runtime = {
    shield_slam_id = nil,
    revenge_id = nil,
    devastate_id = nil,
    heroic_strike_id = nil,
    cleave_id = nil,
    execute_id = nil,
    thunder_clap_id = nil,
    shield_block_id = nil,
    last_stand_id = nil,
    shield_wall_id = nil,
    spell_reflection_id = nil,
    shield_bash_id = nil,
    pummel_id = nil,
    battle_shout_id = nil,
    commanding_shout_id = nil,
    demoralizing_shout_id = nil,
    taunt_id = nil,
    challenging_shout_id = nil,
    mocking_blow_id = nil,
    sunder_armor_id = nil,
    hamstring_id = nil,
    defensive_stance_id = nil,
    battle_stance_id = nil,
    berserker_stance_id = nil,
    charge_id = nil,
    intercept_id = nil,
    stance_swap_retention = 10,
    prev_toggle_state = false,
}

-- Swing manager state
local _next_swing_time = 0
local _should_queue_hs = false

local RUNTIME_SPELL_SPECS = {
    { field = "shield_slam_id", ranks = spells.SHIELD_SLAM },
    { field = "revenge_id", ranks = spells.REVENGE },
    { field = "devastate_id", ranks = spells.DEVASTATE },
    { field = "heroic_strike_id", ranks = spells.HEROIC_STRIKE },
    { field = "cleave_id", ranks = spells.CLEAVE },
    { field = "execute_id", ranks = spells.EXECUTE },
    { field = "thunder_clap_id", ranks = spells.THUNDER_CLAP },
    { field = "shield_block_id", ranks = spells.SHIELD_BLOCK },
    { field = "last_stand_id", ranks = spells.LAST_STAND },
    { field = "shield_wall_id", ranks = spells.SHIELD_WALL },
    { field = "spell_reflection_id", ranks = spells.SPELL_REFLECTION },
    { field = "shield_bash_id", ranks = spells.SHIELD_BASH },
    { field = "pummel_id", ranks = spells.PUMMEL },
    { field = "battle_shout_id", ranks = spells.BATTLE_SHOUT },
    { field = "commanding_shout_id", ranks = spells.COMMANDING_SHOUT },
    { field = "demoralizing_shout_id", ranks = spells.DEMORALIZING_SHOUT },
    { field = "taunt_id", ranks = spells.TAUNT },
    { field = "challenging_shout_id", ranks = spells.CHALLENGING_SHOUT },
    { field = "mocking_blow_id", ranks = spells.MOCKING_BLOW },
    { field = "sunder_armor_id", ranks = spells.SUNDER_ARMOR },
    { field = "hamstring_id", ranks = spells.HAMSTRING },
    { field = "defensive_stance_id", ranks = spells.DEFENSIVE_STANCE },
    { field = "battle_stance_id", ranks = spells.BATTLE_STANCE },
    { field = "berserker_stance_id", ranks = spells.BERSERKER_STANCE },
    { field = "charge_id", ranks = spells.CHARGE },
    { field = "intercept_id", ranks = spells.INTERCEPT },
}

local function resolve_spells()
    for i = 1, #RUNTIME_SPELL_SPECS do
        local spec = RUNTIME_SPELL_SPECS[i]
        runtime[spec.field] = utils.resolve_spell_id(spec.ranks)
    end
    runtime.stance_swap_retention = utils.get_stance_swap_retention()
end

local function get_rage(me)
    return utils.get_rage(me)
end

local function count_nearby_enemies(me)
    return utils.enemy_count_in_radius(me, PROT_AOE_RADIUS)
end

-- : Threat lead check
local function has_threat_lead(threat_pct, threshold)
    if threshold <= 0 then return true end
    return threat_pct >= threshold
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
    local ok_combat, in_combat = pcall(function() return me:is_in_combat() end)
    if not (ok_combat and in_combat) then return false end
    local ok_hp, hp = pcall(function() return me:get_health() end)
local ok_max, max_hp = pcall(function() return me:get_max_health() end)
local hp_pct = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    local threshold = (menu.cancelaura_hp_threshold and menu.cancelaura_hp_threshold:get()) or 80
    if menu.cancel_pws:get_state() then
        local buff_data = buff_manager:get_buff_data(me, {17})
        if buff_data.is_active then
            local rage = get_rage(me)
            if rage < 30 and hp_pct > threshold then
                local ok_buffs, buffs = pcall(function() return me:get_buffs() end)
                if not ok_buffs then buffs = {} end
                for _, buff in ipairs(buffs) do
                    if buff.buff_id == 17 then
                        local ok = pcall(function() core.input.cancel_buff(buff) end)
                        if ok then utils.log_debug(menu, "Cancelaura: PW:S"); return true end
                        break
                    end
                end
            end
        end
    end
    if menu.cancel_bop:get_state() then
        local buff_data = buff_manager:get_buff_data(me, {1022})
        if buff_data.is_active then
            if hp_pct > threshold then
                local ok_buffs, buffs = pcall(function() return me:get_buffs() end)
                if not ok_buffs then buffs = {} end
                for _, buff in ipairs(buffs) do
                    if buff.buff_id == 1022 then
                        local ok = pcall(function() core.input.cancel_buff(buff) end)
                        if ok then utils.log_debug(menu, "Cancelaura: BoP"); return true end
                        break
                    end
                end
            end
        end
    end
    return false
end

local function try_shield_block(me, threat_pct)
    if not menu.use_shield_block:get_state() or not runtime.shield_block_id then return false end
    if utils.has_buff(me, spells.BUFF_SHIELD_BLOCK) then return false end
    local threshold = (menu.shield_block_threat_lead and menu.shield_block_threat_lead:get()) or 50
    if not has_threat_lead(threat_pct, threshold) then return false end
    if utils.cast_self(runtime.shield_block_id, me) then
        utils.log_debug(menu, "Shield Block")
        return true
    end
    return false
end

local function try_shield_slam(me, target)
    if not menu.use_shield_slam:get_state() or not target or not runtime.shield_slam_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.cast_target(runtime.shield_slam_id, target) then
        utils.log_debug(menu, "Shield Slam")
        return true
    end
    return false
end

local function try_revenge(me, target)
    if not menu.use_revenge:get_state() or not target or not runtime.revenge_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not core.spell_book.is_usable_spell(runtime.revenge_id) then return false end
    if utils.cast_target(runtime.revenge_id, target) then
        utils.log_debug(menu, "Revenge")
        return true
    end
    return false
end

local function try_devastate(me, target)
    if not menu.use_devastate:get_state() or not target or not runtime.devastate_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.cast_target(runtime.devastate_id, target) then
        utils.log_debug(menu, "Devastate")
        return true
    end
    return false
end

local function try_sunder_armor(me, target)
    if not menu.use_sunder_armor:get_state() or not target or not runtime.sunder_armor_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not utils.should_maintain_sunder(target, (menu.sunder_max_stacks and menu.sunder_max_stacks:get()) or 5) then return false end
    if runtime.devastate_id and core.spell_book.is_spell_learned(runtime.devastate_id) then return false end
    if utils.cast_target(runtime.sunder_armor_id, target) then
        utils.log_debug(menu, "Sunder Armor")
        return true
    end
    return false
end

local function try_thunder_clap(me, target, threat_pct)
    if not menu.use_thunder_clap:get_state() or not target or not runtime.thunder_clap_id then return false end
    if menu.pvp_cc_break_check:get_state() and utils.has_breakable_cc_nearby(me, 10) then return false end
    local nearby = count_nearby_enemies(me)
    local min_mobs = (menu.tc_min_mobs and menu.tc_min_mobs:get()) or 3
    if nearby < min_mobs then return false end
    local threshold = (menu.tc_threat_lead and menu.tc_threat_lead:get()) or 20
    if not has_threat_lead(threat_pct, threshold) and nearby < 3 then return false end
    local remaining_ms = utils.get_debuff_remaining_ms(target, spells.DEBUFF_THUNDER_CLAP)
    if remaining_ms > TC_REFRESH_WINDOW_MS then return false end
    if utils.get_current_stance(me) ~= "battle" then
        if runtime.battle_stance_id and utils.can_cast_self(runtime.battle_stance_id, me) then
            utils.cast_self(runtime.battle_stance_id, me)
            utils.set_tracked_stance("battle")
            utils.log_debug(menu, "Stance -> Battle (Thunder Clap)")
            return true
        end
        return false
    end
    if utils.cast_self(runtime.thunder_clap_id, me) then
        utils.log_debug(menu, "Thunder Clap")
        return true
    end
    return false
end

local function try_demo_shout(me, target, threat_pct)
    if not menu.use_demo_shout:get_state() or not target or not runtime.demoralizing_shout_id then return false end
    if menu.pvp_cc_break_check:get_state() and utils.has_breakable_cc_nearby(me, 10) then return false end
    local nearby = count_nearby_enemies(me)
    local min_mobs = (menu.demo_min_mobs and menu.demo_min_mobs:get()) or 2
    if nearby < min_mobs then return false end
    local threshold = (menu.demo_threat_lead and menu.demo_threat_lead:get()) or 10
    if not has_threat_lead(threat_pct, threshold) then return false end
    if utils.has_debuff(target, spells.DEBUFF_DEMORALIZING_SHOUT) then return false end
    if utils.cast_self(runtime.demoralizing_shout_id, me) then
        utils.log_debug(menu, "Demoralizing Shout")
        return true
    end
    return false
end

local function try_execute(me, target, target_hp_pct)
    if not menu.use_execute:get_state() or not target or not runtime.execute_id then return false end
    if target_hp_pct > EXECUTE_HP_THRESHOLD then return false end
    if utils.cast_target(runtime.execute_id, target) then
        utils.log_debug(menu, "Execute")
        return true
    end
    return false
end

local function try_heroic_strike(me, target, rage)
    if not menu.use_heroic_strike:get_state() or not utils.is_melee_target(me, target) then return false end
    if utils.is_spell_already_queued(runtime.heroic_strike_id or runtime.cleave_id) then return false end
    local nearby = count_nearby_enemies(me)
    local use_cleave = nearby >= 2 and runtime.cleave_id
    local dump_id = use_cleave and runtime.cleave_id or runtime.heroic_strike_id
    if not dump_id then return false end
    local threshold = (menu.hs_rage_threshold and menu.hs_rage_threshold:get()) or 40
    if rage < threshold then return false end
    if utils.can_cast_melee(dump_id, me) and utils.cast_target_fast(dump_id, target) then
        utils.log_debug(menu, use_cleave and "Cleave" or "Heroic Strike")
        return true
    end
    return false
end

local function try_taunt(me, target)
    if menu.no_taunt:get_state() then return false end
    if not menu.use_taunt:get_state() or not target or not runtime.taunt_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.has_target_aggro(target, me) then return false end
    local ok_player, is_player = pcall(function() return target:is_player() end)
    if ok_player and is_player then return false end
    local ok_class, classification = pcall(function() return target:get_classification() end)
    if not ok_class then classification = nil end
    if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then return false end
    if utils.cast_target(runtime.taunt_id, target) then
        utils.log_debug(menu, "Taunt")
        return true
    end
    return false
end

local function try_challenging_shout(me)
    if menu.no_taunt:get_state() then return false end
    if not menu.use_challenging_shout:get_state() or not runtime.challenging_shout_id then return false end
    local elites, bosses, trash = utils.count_nearby_enemies_by_class(me, 10)
    local min_bosses = (menu.cshout_min_bosses and menu.cshout_min_bosses:get()) or 1
    local min_elites = (menu.cshout_min_elites and menu.cshout_min_elites:get()) or 1
    local min_trash = (menu.cshout_min_trash and menu.cshout_min_trash:get()) or 3
    if bosses >= min_bosses or elites >= min_elites or trash >= min_trash then
        if utils.cast_self(runtime.challenging_shout_id, me) then
            utils.log_debug(menu, "Challenging Shout (EMERGENCY)")
            return true
        end
    end
    return false
end

local function try_last_stand(me, ctx)
    if not menu.use_last_stand:get_state() or not runtime.last_stand_id then return false end
    local ok_combat, in_combat = pcall(function() return me:is_in_combat() end)
    if not (ok_combat and in_combat) then return false end
    
    -- Use smart_defensive for predictive mitigation
    local settings = {
        last_stand_hp = (menu.last_stand_hp and menu.last_stand_hp:get()) or 30,
    }
    local should_use, reason = smart_defensive.should_use(me, "last_stand", ctx or {}, settings)
    
    if not should_use then return false end
    if utils.has_buff(me, spells.BUFF_LAST_STAND) then return false end
    
    if utils.cast_self(runtime.last_stand_id, me) then
        utils.log_debug(menu, "Last Stand (" .. (reason or "hp_threshold") .. ")")
        return true
    end
    return false
end

local function try_shield_wall(me, ctx)
    if not menu.use_shield_wall:get_state() or not runtime.shield_wall_id then return false end
    local ok_combat, in_combat = pcall(function() return me:is_in_combat() end)
    if not (ok_combat and in_combat) then return false end
    
    -- Check stance first (Shield Wall requires Defensive)
    if utils.get_current_stance(me) ~= "defensive" then return false end
    
    -- Use smart_defensive for predictive mitigation
    local settings = {
        shield_wall_hp = (menu.shield_wall_hp and menu.shield_wall_hp:get()) or 20,
    }
    local should_use, reason = smart_defensive.should_use(me, "shield_wall", ctx or {}, settings)
    
    if not should_use then return false end
    
    if utils.cast_self(runtime.shield_wall_id, me) then
        utils.log_debug(menu, "Shield Wall (" .. (reason or "hp_threshold") .. ")")
        return true
    end
    return false
end

local function try_charge(me, target)
    if not runtime.charge_id then return false end
    local ok_combat, in_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and in_combat then return false end
    if not utils.can_cast_hostile(runtime.charge_id, me, target) then return false end
    if utils.cast_target_fast(runtime.charge_id, target) then
        utils.log_debug(menu, "Charge")
        return true
    end
    return false
end

-- PvP-specific rotation functions
local pvp_context_cache = nil
local pvp_context_last_update = 0
local PVP_CONTEXT_THROTTLE_S = 1.0

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

-- PvP: Spell Reflection for casters
local function try_pvp_spell_reflection(me, target, ctx)
    if not ctx.is_pvp then return false end
    if not utils.is_pvp_setting_enabled(menu, "pvp_spell_reflection") then return false end
    if not runtime.spell_reflection_id then return false end
    if not target or not target.is_casting then return false end
    if not target:is_casting_spell() then return false end
    
    -- Check cast progress
    local cast_progress = 0
    if target.get_active_spell_cast_end_time and target.get_active_spell_cast_start_time then
        local ok_end, cast_end = pcall(function() return target:get_active_spell_cast_end_time() end)
    if not ok_end then cast_end = nil end
        local ok_start, cast_start = pcall(function() return target:get_active_spell_cast_start_time() end)
    if not ok_start then cast_start = nil end
        local now = core.game_time()
        if cast_end and cast_start and now then
            cast_progress = (now - cast_start) / (cast_end - cast_start)
        end
    end
    local threshold = (menu.spell_reflection_progress_pct and menu.spell_reflection_progress_pct:get()) or 50
    if cast_progress < (threshold / 100) then return false end
    
    if utils.cast_self(runtime.spell_reflection_id, me) then
        utils.log_debug(menu, "PvP Spell Reflection")
        return true
    end
    return false
end

-- PvP: Disarm enemy melee
local function try_pvp_disarm(me, target, ctx)
    if not ctx.target_is_player then return false end
    if not utils.is_pvp_setting_enabled(menu, "pvp_disarm") then return false end
    if not runtime.disarm_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    
    -- Check if target is a melee class
    local ok_class, target_class = pcall(function() return target:get_class() end)
    if not ok_class then target_class = nil end
    if not target_class then return false end
    local is_melee = target_class == 1 or target_class == 4 or target_class == 6  -- Warrior, Rogue, Death Knight
    if not is_melee then return false end
    
    -- Skip if already disarmed
    if utils.has_debuff(target, spells.DEBUFF_DISARM) then return false end
    
    if utils.cast_target(runtime.disarm_id, target) then
        utils.log_debug(menu, "PvP Disarm")
        return true
    end
    return false
end

-- PvP: Concussion Blow as CC
local function try_pvp_concussion_blow(me, target, ctx)
    if not ctx.target_is_player then return false end
    if not utils.is_pvp_setting_enabled(menu, "pvp_concussion_blow") then return false end
    if not runtime.concussion_blow_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    
    -- Use on low health targets or when bursting
    local ok_hp, hp = pcall(function() return target:get_health() end)
local ok_max, max_hp = pcall(function() return target:get_max_health() end)
local target_hp = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    if target_hp > 50 then return false end
    
    if utils.cast_target(runtime.concussion_blow_id, target) then
        utils.log_debug(menu, "PvP Concussion Blow")
        return true
    end
    return false
end

-- PvP: Intercept for gap closing
local function try_pvp_intercept(me, target, ctx)
    if not ctx.is_pvp then return false end
    if not utils.is_pvp_setting_enabled(menu, "pvp_intercept") then return false end
    if not runtime.intercept_id then return false end
    
    -- Check distance (must be 8-25 yards)
    local dist_sq = utils.dist_squared(me, target)
    if dist_sq < 64 or dist_sq > 625 then return false end  -- 8-25 yards squared
    
    -- Must be in Berserker Stance
    if utils.get_current_stance(me) ~= "berserker" then
        if runtime.berserker_stance_id and utils.can_cast_self(runtime.berserker_stance_id, me) then
            utils.cast_self(runtime.berserker_stance_id, me)
            utils.set_tracked_stance("berserker")
            utils.log_debug(menu, "Stance -> Berserker (Intercept)")
            return true
        end
        return false
    end
    
    if utils.cast_target(runtime.intercept_id, target) then
        utils.log_debug(menu, "PvP Intercept")
        return true
    end
    return false
end

-- PvP: Intimidating Shout as peel/escape
local function try_pvp_intimidating_shout(me, target, ctx)
    if not ctx.is_pvp then return false end
    if not utils.is_pvp_setting_enabled(menu, "pvp_intimidating_shout") then return false end
    if not runtime.intimidating_shout_id then return false end
    
    local ok_hp, hp = pcall(function() return me:get_health() end)
local ok_max, max_hp = pcall(function() return me:get_max_health() end)
local my_hp = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    local threshold = (menu.pvp_intimidating_shout_hp and menu.pvp_intimidating_shout_hp:get()) or 30
    if my_hp > threshold then return false end
    
    -- Check if 2+ enemies nearby
    local nearby = count_nearby_enemies(me)
    if nearby < 2 then return false end
    
    if utils.cast_self(runtime.intimidating_shout_id, me) then
        utils.log_debug(menu, "PvP Intimidating Shout (Emergency)")
        return true
    end
    return false
end

-- PvP: Shield Bash / Pummel interrupt priority
local function try_pvp_interrupt(me, target, ctx)
    if not ctx.target_is_player then return false end
    if not interrupt_manager.should_interrupt(target) then return false end
    
    -- Try Shield Bash first (if sword/board)
    if runtime.shield_bash_id and utils.can_cast_target(runtime.shield_bash_id, target) then
        if utils.cast_target(runtime.shield_bash_id, target) then
            utils.log_debug(menu, "PvP Shield Bash Interrupt")
            return true
        end
    end
    
    -- Try Pummel as fallback
    if runtime.pummel_id and utils.can_cast_target(runtime.pummel_id, target) then
        if utils.cast_target(runtime.pummel_id, target) then
            utils.log_debug(menu, "PvP Pummel Interrupt")
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
    
    -- OOC self-buffing
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = runtime.battle_shout_id,
                    buff_ids = spells.BUFF_BATTLE_SHOUT,
                    name = "Battle Shout",
                    toggle = menu.use_battle_shout
                },
                {
                    spell_id = runtime.commanding_shout_id,
                    buff_ids = spells.BUFF_COMMANDING_SHOUT,
                    name = "Commanding Shout",
                    toggle = menu.use_commanding_shout
                },
            }
        })
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
    
    local target = utils.find_best_target(me)
    if not target then return end
    
    -- NEW: Build rotation context once per frame
    local ctx = context_builder.build(me, target, menu)
    local target_hp_pct = ctx.target_hp or 0
    local rage = ctx.rage or 0
    local threat_pct = ctx.threat_pct or 100
    
    -- NEW: Update manual target detection for threat_tab_manager
    threat_tab_manager.update_manual_target(target)
    
    -- NEW: Threat-aware tab targeting
    local should_tab, tab_reason, new_target = threat_tab_manager.should_tab(me, target, menu)
    if should_tab and new_target then
        if threat_tab_manager.execute_tab(me) then
            utils.log_debug(menu, "Tab target: " .. tab_reason)
            -- Update target to new one
            target = new_target
            ctx = context_builder.build(me, target, menu)
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
    
    -- PvP: Spell Reflection
    if pvp_active and try_pvp_spell_reflection(me, target, pvp_ctx) then return end
    
    utils.ensure_melee_auto_attack(me, target)
    if try_charge(me, target) then return end
    if try_cancelaura_buffs(me) then return end
    
    -- PvP: Interrupt priority
    if pvp_active and try_pvp_interrupt(me, target, pvp_ctx) then return end
    
    -- Normal interrupt
    if target and interrupt_manager.should_interrupt(target) then
        if menu.use_interrupt:get_state() then
            if interrupt_manager.try_interrupt(me, target, "warrior", utils) then return end
        end
    end
    
    -- PvP: Disarm enemy melee
    if pvp_active and try_pvp_disarm(me, target, pvp_ctx) then return end
    
    -- PvP: Concussion Blow as CC
    if pvp_active and try_pvp_concussion_blow(me, target, pvp_ctx) then return end
    
    -- PvP: Intercept for gap closing
    if pvp_active and try_pvp_intercept(me, target, pvp_ctx) then return end
    
    -- PvP: Intimidating Shout emergency
    if pvp_active and try_pvp_intimidating_shout(me, target, pvp_ctx) then return end
    
    -- Note: Defensive racials (Stoneform) now handled by middleware
    -- Enhanced defensive cooldowns with smart_defensive
    if try_last_stand(me, ctx) then return end
    if try_shield_wall(me, ctx) then return end
    if try_challenging_shout(me) then return end
    if try_taunt(me, target) then return end
    if try_battle_shout(me) then return end
    if try_shield_block(me, threat_pct) then return end
    if try_thunder_clap(me, target, threat_pct) then return end
    if try_demo_shout(me, target, threat_pct) then return end
    if try_shield_slam(me, target) then return end
    if try_revenge(me, target) then return end
    if try_execute(me, target, target_hp_pct) then return end
    if try_devastate(me, target) then return end
    if try_sunder_armor(me, target) then return end
    if try_heroic_strike(me, target, rage) then return end

    -- Swing manager: HS/Cleave queue for rage dump between swings
    local use_swing_mgr = (menu.use_swing_manager and menu.use_swing_manager:get()) or false
    if use_swing_mgr then
        local threshold = (menu.swing_queue_threshold and menu.swing_queue_threshold:get()) or 50
        local gcd_remains = _get_gcd()
        local should_queue = rage >= threshold and gcd_remains > 1.0
        
        if should_queue and not _should_queue_hs then
            swing_manager.queue_next_swing(true, false)
            _should_queue_hs = true
        elseif not should_queue and _should_queue_hs then
            swing_manager.dequeue_next_swing()
            _should_queue_hs = false
        end
    end

    -- Defensive trinket check (tank mode - not burst)
    trinket_manager.check_trinkets(me, false, menu)
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

core.register_on_update_callback(on_update)
core.register_on_render_menu_callback(menu.on_menu_render)
core.register_on_render_control_panel_callback(on_control_panel)

-- Initialize dashboard
local dashboard_config = require("libraries/dashboard_config")
dashboard.init(dashboard_config)
dashboard.set_enabled((menu.show_dashboard and menu.show_dashboard:get_state()) or true)
if dashboard.register_render_callback then
    dashboard.register_render_callback()
end

-- Export toggle settings for external access (only when fully loaded)
if header.load then
    local NS = _G.EAXWarriorProtection and _G.EAXWarriorProtection.NS or {}
    _G.EAXWarriorProtection = _G.EAXWarriorProtection or {}
    _G.EAXWarriorProtection.NS = NS
    NS.toggle_menu = menu.toggle_menu
end

