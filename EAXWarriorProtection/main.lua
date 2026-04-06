-- Eax Warrior Protection  main.lua
--  Protection rotation with Shield Slam priority, Revenge procs, Sunder maintenance.

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type racial_manager
local racial_manager = require("libraries/racial_manager")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_spell_cd = core.spell_book.get_spell_cooldown

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

local function try_shield_block(me, threat_pct)
    if not menu.use_shield_block:get_state() or not runtime.shield_block_id then return false end
    if utils.has_buff(me, spells.BUFF_SHIELD_BLOCK) then return false end
    local threshold = menu.shield_block_threat_lead:get()
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
    if not utils.should_maintain_sunder(target, menu.sunder_max_stacks:get()) then return false end
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
    local min_mobs = menu.tc_min_mobs:get()
    if nearby < min_mobs then return false end
    local threshold = menu.tc_threat_lead:get()
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
    local min_mobs = menu.demo_min_mobs:get()
    if nearby < min_mobs then return false end
    local threshold = menu.demo_threat_lead:get()
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
    local threshold = menu.hs_rage_threshold:get()
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
    if target:is_player() then return false end
    local classification = target:get_classification()
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
    local min_bosses = menu.cshout_min_bosses:get()
    local min_elites = menu.cshout_min_elites:get()
    local min_trash = menu.cshout_min_trash:get()
    if bosses >= min_bosses or elites >= min_elites or trash >= min_trash then
        if utils.cast_self(runtime.challenging_shout_id, me) then
            utils.log_debug(menu, "Challenging Shout (EMERGENCY)")
            return true
        end
    end
    return false
end

local function try_last_stand(me)
    if not menu.use_last_stand:get_state() or not runtime.last_stand_id then return false end
    if not me:is_in_combat() then return false end
    local hp_pct = me:get_health_percentage()
    local threshold = menu.last_stand_hp:get()
    if hp_pct > threshold then return false end
    if utils.has_buff(me, spells.BUFF_LAST_STAND) then return false end
    if utils.cast_self(runtime.last_stand_id, me) then
        utils.log_debug(menu, "Last Stand")
        return true
    end
    return false
end

local function try_shield_wall(me)
    if not menu.use_shield_wall:get_state() or not runtime.shield_wall_id then return false end
    if not me:is_in_combat() then return false end
    local hp_pct = me:get_health_percentage()
    local threshold = menu.shield_wall_hp:get()
    if hp_pct > threshold then return false end
    if utils.get_current_stance(me) ~= "defensive" then return false end
    if utils.cast_self(runtime.shield_wall_id, me) then
        utils.log_debug(menu, "Shield Wall")
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

local function on_update()
    if not menu.is_enabled() then return end
    local me = _get_local_player()
    if not me or not me:is_valid() then return end
    resolve_spells()
    local target = utils.find_best_target(me)
    if not target then return end
    local target_hp_pct = target:get_health_percentage()
    local rage = get_rage(me)
    local threat_pct = 100
    utils.ensure_melee_auto_attack(me, target)
    if try_charge(me, target) then return end
    if try_cancelaura_buffs(me) then return end
    if try_last_stand(me) then return end
    if try_shield_wall(me) then return end
    if target and interrupt_manager.should_interrupt(target) then
        if menu.use_interrupt:get_state() then
            if interrupt_manager.try_interrupt(me, target, "warrior", utils) then return end
        end
    end
    if racial_manager.try_defensive(me) then return end
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
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)
core.register_on_render_control_panel_callback(on_control_panel)

-- Export toggle settings for external access
local NS = _G.EAXWarriorProtection and _G.EAXWarriorProtection.NS or {}
_G.EAXWarriorProtection = _G.EAXWarriorProtection or {}
_G.EAXWarriorProtection.NS = NS
NS.toggle_menu = menu.toggle_menu