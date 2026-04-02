-- Eax Warrior Arms | main.lua
-- Minimal Arms rotation helper that prioritizes Overpower, Mortal Strike, Slam weaving,
-- Whirlwind stance dancing, and Execute while supporting Auto/Solo/Dungeon/Raid modes.

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local eax_utils = require("libraries/eax_utils")
local color     = require("libraries/color")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")

---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
local leveling_manager
local leveling_manager = require("libraries/leveling_manager")
---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
local pvp_manager = require("libraries/pvp_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil

-- BigWigs integration: check for upcoming boss abilities
local function is_bigwigs_danger_window()
    local ok, bw = pcall(function() return core.addons.bigwigs end)
    if not ok or not bw then return false end
    local bars = bw.get_bars and bw:get_bars() or {}
    for _, bar in ipairs(bars) do
        if bar and bar.remaining and bar.remaining < 3.0 then
            return true
        end
    end
    return false
end

-- Dynamic encounter detection from API
local function get_current_encounter_info()
    local ok, encounters = pcall(function() return core.world.get_encounters_on_map() end)
    if not ok or not encounters then return nil end
    return encounters
end


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("arms", "Warrior Arms")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("libraries/smart_cast_manager")

-- Phase 04 visual telemetry wiring
local dps_meter = require("libraries/dps_meter")
local cooldown_tracker = require("libraries/cooldown_tracker")
local visual_state = require("libraries/visual_state")
local reactive_runtime = require("libraries/reactive_runtime")
local dps_risk = require("libraries/dps_risk")
local dps_runtime = require("libraries/dps_runtime")

-- Hot-path local caching (performance critical)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

smart_cast_manager.init({
    core_time = _core_time,
    get_gcd = _get_gcd,
    get_spell_cd = _get_spell_cd,
})

local _visual_ttd_tracker = nil
local _visual_ttd_ok, _visual_ttd_mod = pcall(require, "libraries/ttd_tracker")
if _visual_ttd_ok and _visual_ttd_mod then
    _visual_ttd_tracker = _visual_ttd_mod
end

local _visual_runtime = {
    in_combat = false,
    last_me_hp_pct = nil,
    last_target_hp_pct = nil,
    reactive_state = {},
}

local reactive_adapter = {}

local _visual_on_cast = esp_renderer.on_cast
function esp_renderer.on_cast(spell_id, name, col, target_name)
    if spell_id and core and core.time and core.spell_book and core.spell_book.get_spell_cooldown then
        local now_s = _core_time()
        local cd_s = tonumber(_get_spell_cd(spell_id)) or 0
        cooldown_tracker.set_next_spell(spell_id, now_s, cd_s)
    end
    return _visual_on_cast(spell_id, name, col, target_name)
end

local function visual_get_ttd_seconds(target)
    if not _visual_ttd_tracker or not _visual_ttd_tracker.get then return "--" end
    local ok, value = pcall(function() return _visual_ttd_tracker.get(target) end)
    if not ok then return "--" end
    local ttd_value = tonumber(value)
    if not ttd_value then return "--" end
    return ttd_value
end

local _visual_tracked_auras = { n = 0 }

local function visual_build_tracked_auras(me, target)
    _visual_tracked_auras.n = 0
    if me and me:is_in_combat() then
        _visual_tracked_auras.n = _visual_tracked_auras.n + 1
        _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Combat", active = true }
    end
    if target and target:is_valid() and not target:is_dead() then
        if target:is_casting_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Cast", active = true }
        end
        if target:is_channelling_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Channel", active = true }
        end
    end
    for i = _visual_tracked_auras.n + 1, 4 do
        _visual_tracked_auras[i] = nil
    end
    return _visual_tracked_auras
end

local function visual_update_snapshot(me, target)
    if not me then return end
    local in_combat = me:is_in_combat()
    if in_combat and not _visual_runtime.in_combat then
        dps_meter.on_combat_start()
        _visual_runtime.in_combat = true
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.clear_all_pending()
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.reset()
    end

    local me_hp_pct = tonumber(me:get_health_percentage())
    if in_combat and _visual_runtime.last_me_hp_pct and me_hp_pct and me_hp_pct > _visual_runtime.last_me_hp_pct then
        dps_meter.on_heal(me_hp_pct - _visual_runtime.last_me_hp_pct)
    end
    _visual_runtime.last_me_hp_pct = me_hp_pct

    local target_hp_pct = nil
    if target and target:is_valid() and not target:is_dead() then
        target_hp_pct = tonumber(target:get_health_percentage())
    end
    if in_combat and _visual_runtime.last_target_hp_pct and target_hp_pct and target_hp_pct < _visual_runtime.last_target_hp_pct then
        dps_meter.on_damage(_visual_runtime.last_target_hp_pct - target_hp_pct)
    end
    _visual_runtime.last_target_hp_pct = target_hp_pct

    reactive_runtime.update_tick(me, target, {
        adapter = reactive_adapter,
        encounter_manager = encounter_manager,
        state = _visual_runtime.reactive_state,
        spec = "EAXWarriorArms",
    })

    local snapshot = visual_state.build_snapshot({
        now_s = _core_time(),
        ttd_seconds = visual_get_ttd_seconds(target),
        tracked_auras = visual_build_tracked_auras(me, target),
    })

    if esp_renderer.update_visual_snapshot then
        esp_renderer.update_visual_snapshot(snapshot)
    elseif esp_renderer.set_visual_snapshot then
        esp_renderer.set_visual_snapshot(snapshot)
    end
end

core.register_on_update_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    local me = _get_local_player()
    if not me or me:is_dead() then return end
    local target = me:get_target()
    visual_update_snapshot(me, target)
end)
---@type ttd_tracker
local ttd_tracker = require("libraries/ttd_tracker")
---@type racial_manager
local racial_manager = require("libraries/racial_manager")
---@type defensive_manager
local defensive_manager = require("libraries/defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type swing_timer
local swing_timer = require("libraries/swing_timer")

local MODE_REFRESH_INTERVAL_S = 5
local MISSING_SPELL_REFRESH_INTERVAL_S = 1.0
local MORTAL_STRIKE_COST = 30
local WHIRLWIND_COST = 25
local SLAM_COST = 15
local HEROIC_STRIKE_COST = 15
local CLEAVE_COST = 20
local DUMP_RAGE_RESERVE = 40
local THUNDER_CLAP_COST = 20
local REND_COST = 10
local EXECUTE_MIN_RAGE = 15
local EXECUTE_HP_THRESHOLD = 0.20
local STANCE_BUFFER_RAGE = 5
local ARMS_AOE_RADIUS = 8
local REND_REFRESH_MS = 4000
local SLAM_NOW_WINDOW_MS = 350
local SLAM_HOLD_REGION_MS = 250
local SLAM_SAFE_BUFFER_MS = 100

local should_hold_for_slam

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
    charge_id = nil,
    death_wish_id = nil,
    recklessness_id = nil,
    berserker_rage_id = nil,
    sweeping_strikes_id = nil,
    enraged_regen_id = nil,
    stance_swap_retention = 10,
    cached_mode = "solo",
    mode_cache_refreshed_at = 0,
    last_spell_refresh_at = 0,
    ww_pending_return = false,
    pending_battle_stance_return = false,
    prev_toggle_state = false,
    set_multiplier = 1.0,
    overpower_available = false,
    last_overpower_check = 0,
}

local function note_cast()
    runtime.last_cast_time = _core_time()
end

local ctx_cache = rotation_context.new({
    important_buffs = {},
    important_debuffs = {},
})

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
    { field = "berserker_stance_id",  ranks = spells.BERSERKER_STANCE },
    { field = "berserker_rage_id", ranks = spells.BERSERKER_RAGE },
    { field = "charge_id",            ranks = spells.CHARGE },
    { field = "death_wish_id",        ranks = spells.DEATH_WISH },
    { field = "recklessness_id",      ranks = spells.RECKLESSNESS },
    { field = "sweeping_strikes_id",  ranks = spells.SWEEPING_STRIKES },
    { field = "enraged_regen_id",     ranks = spells.ENRAGED_REGENERATION },
}

local function resolve_spells()
    for i = 1, #RUNTIME_SPELL_SPECS do
        local spec = RUNTIME_SPELL_SPECS[i]
        runtime[spec.field] = utils.resolve_spell_id(spec.ranks)
    end
    runtime.stance_swap_retention = utils.get_stance_swap_retention()
end

local function validate_arms_spec()
    if runtime.mortal_strike_id then
        return true
    end

    if menu and menu.enabled and menu.enabled:get_state() then
        menu.enabled:set(false)
    end

    core.log("[Eax Warrior Arms] Mortal Strike not found; disabling addon to avoid interfering with non-Arms warrior specs.")
    return false
end

local function has_missing_runtime_spell_ids()
    for i = 1, #RUNTIME_SPELL_SPECS do
        if not runtime[RUNTIME_SPELL_SPECS[i].field] then
            return true
        end
    end
    return false
end

local function refresh_missing_runtime_spell_ids()
    local now = _core_time()
    if (now - runtime.last_spell_refresh_at) < MISSING_SPELL_REFRESH_INTERVAL_S then
        return
    end
    runtime.last_spell_refresh_at = now
    if has_missing_runtime_spell_ids() then
        resolve_spells()
    end
end

local function is_gcd_ready()
    return smart_cast_manager.is_gcd_ready()
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    return smart_cast_manager.is_pending(spell_id)
end

local function mark_pending_cast(spell_id, timeout_s, options)
    if not spell_id then return end
    options = options or {}
    smart_cast_manager.on_cast_attempt(spell_id, options.action_key or "unknown", {
        triggers_gcd = true,
        category = options.category,
        cast_time = options.cast_time,
    })
end

-- Intelligent throttling for specific ability categories
local function should_throttle_dot(action_key)
    return smart_cast_manager.should_throttle(action_key, "dots")
end
local function should_throttle_filler(action_key)
    return smart_cast_manager.should_throttle(action_key, "filler")
end
local function should_throttle_aoe(action_key)
    return smart_cast_manager.should_throttle(action_key, "aoe")
end

local function refresh_mode_cache()
    local now = _core_time()
    if (now - runtime.mode_cache_refreshed_at) < MODE_REFRESH_INTERVAL_S and runtime.cached_mode then
        return
    end
    local me = _get_local_player()
    if not me then return end
    runtime.cached_mode = utils.detect_mode(me)
    runtime.mode_cache_refreshed_at = now
end

local function update_set_bonus(me)
    if not me then return end
    local best_multiplier = 1.0
    local set_names = { "Warbringer", "WarbringerBattlegear", "Ymirjar" }
    for _, set_name in ipairs(set_names) do
        local multiplier = utils.get_set_multiplier(me, set_name)
        if multiplier > best_multiplier then
            best_multiplier = multiplier
        end
    end
    runtime.set_multiplier = best_multiplier
end

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode or "solo"
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local next_state = not menu.enabled:get_state()
        menu.enabled:set(next_state)
        utils.log_debug(menu, "Toggle -> " .. tostring(next_state))
    end
    runtime.prev_toggle_state = current
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function find_valid_target(me)
    enc = encounter_manager.get_policy(me)
    -- Delegate to utils.find_best_target for priority-aware selection:
    -- prefers units attacking us/party over random hostiles
    return utils.find_best_target(me)
end

local function get_debuff_stack(target, id_table)
    if not target or not id_table then
        return 0
    end
    local data = buff_manager:get_debuff_data(target, id_table)
    if data and data.is_active then
        return data.count or 0
    end
    return 0
end

local function count_nearby_enemies(me)
    local ok_count, count = pcall(function()
        return utils.count_enemies_within_radius(me, ARMS_AOE_RADIUS)
    end)
    if ok_count and type(count) == "number" then
        return count
    end
    local ok_enemy_count, alt_count = pcall(function()
        return utils.enemy_count_in_radius(me, ARMS_AOE_RADIUS)
    end)
    if ok_enemy_count and type(alt_count) == "number" then
        return alt_count
    end
    return 1
end

local function try_battle_shout(me)
    if not menu.use_battle_shout:get_state() then
        return false
    end

    local shout_id = runtime.battle_shout_id
    local buff_table = spells.BUFF_BATTLE_SHOUT
    if menu.use_commanding_shout:get_state() and runtime.commanding_shout_id then
        shout_id = runtime.commanding_shout_id
        buff_table = spells.BUFF_COMMANDING_SHOUT
    end

    if not shout_id or utils.has_buff(me, buff_table) then
        return false
    end

    if utils.cast_self(shout_id, me) then
        utils.log_debug(menu, "Refreshing shout")
        return true
    end

    return false
end

local function try_demo_shout(me, target)
    if not menu.use_demo_shout:get_state() or not target or not runtime.demoralizing_shout_id then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    if utils.has_debuff(target, spells.DEBUFF_DEMORALIZING_SHOUT) then
        return false
    end

    if utils.cast_self(runtime.demoralizing_shout_id, me) then
        utils.log_debug(menu, "Demoralizing Shout")
        return true
    end

    return false
end

local function try_sunder(me, target, target_hp_pct)
    if not menu.use_sunder_armor:get_state()
        or not target
        or target_hp_pct <= EXECUTE_HP_THRESHOLD
        or not runtime.sunder_armor_id
    then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    local stacks = get_debuff_stack(target, spells.DEBUFF_SUNDER_ARMOR)
    if stacks >= menu.sunder_max_stacks:get() then
        return false
    end

    if utils.cast_target(runtime.sunder_armor_id, target) then
        utils.log_debug(menu, "Sunder Armor")
        return true
    end

    return false
end

local function try_hamstring(me, target, target_hp_pct)
    if not menu.use_hamstring:get_state() or not target or target_hp_pct <= EXECUTE_HP_THRESHOLD or not runtime.hamstring_id then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    if utils.cast_target(runtime.hamstring_id, target) then
        utils.log_debug(menu, "Hamstring")
        return true
    end

    return false
end

local function try_return_to_battle(me)
    if not runtime.ww_pending_return or not runtime.battle_stance_id then
        return false
    end

    if utils.get_current_stance(me) == "battle" then
        runtime.ww_pending_return = false
        return false
    end

    if utils.can_cast_self(runtime.battle_stance_id, me)
        and utils.cast_self(runtime.battle_stance_id, me)
    then
        runtime.ww_pending_return = false
        utils.set_tracked_stance("battle")
        utils.log_debug(menu, "Stance -> battle (return)")
        return true
    end

    return false
end

local function check_overpower_availability(me, target)
    if not runtime.overpower_id then return false end
    runtime.overpower_available = core.spell_book.is_usable_spell(runtime.overpower_id)
    return runtime.overpower_available
end

local function try_overpower(me, target, ctx)
    if not menu.use_overpower:get_state() or not target or not runtime.overpower_id then
        return false
    end

    -- Prioritize Overpower when it just becomes available
    if check_overpower_availability(me, target) then
        -- Use immediately, don't wait for Slam window
        if utils.cast_target(runtime.overpower_id, target) then
            utils.log_debug(menu, "Overpower (proc)")
            return true
        end
    end

    local can_cast = resource_gate.warrior.has_rage(ctx, 5)
    if not can_cast then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    if not utils.can_cast_hostile(runtime.overpower_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.overpower_id, target) then
        utils.log_debug(menu, "Overpower")
        return true
    end

    return false
end

local function try_dump(me, target, rage, ctx, target_hp_pct)
    -- Disable HS during execute phase — all rage goes to Execute
    if target_hp_pct and target_hp_pct < 0.20 then return false end

    if not target or target_hp_pct <= EXECUTE_HP_THRESHOLD then
        return false
    end

    if utils.get_current_stance(me) ~= "battle" then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    local nearby = count_nearby_enemies(me)
    local use_cleave = nearby >= 2 and runtime.cleave_id
    local dump_id = use_cleave and runtime.cleave_id or runtime.heroic_strike_id
    if not dump_id then
        return false
    end

    if utils.is_spell_already_queued(dump_id) then
        return false
    end

    local dump_cost = use_cleave and CLEAVE_COST or HEROIC_STRIKE_COST
    local reserve = DUMP_RAGE_RESERVE

    if runtime.mortal_strike_id then
        local ms_cd = _get_spell_cd(runtime.mortal_strike_id) or math.huge
        if ms_cd <= 1.5 then
            reserve = reserve + MORTAL_STRIKE_COST
        end
    end

    if rage < (dump_cost + reserve) then
        return false
    end

    if utils.can_cast_melee(dump_id, me) and utils.cast_target_fast(dump_id, target) then
        utils.log_debug(menu, use_cleave and "Cleave dump" or "Heroic Strike dump")
        return true
    end

    return false
end

local function try_rend(me, target, rage, target_hp_pct)
    if not menu.use_rend:get_state() or not target or not runtime.rend_id then
        return false
    end

    if target_hp_pct <= EXECUTE_HP_THRESHOLD then
        return false
    end

    if utils.get_current_stance(me) ~= "battle" then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    local rend_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_REND)
    if rend_remaining > REND_REFRESH_MS then
        return false
    end

    local ms_cd = runtime.mortal_strike_id and _get_spell_cd(runtime.mortal_strike_id) or math.huge
    if ms_cd <= 1.5 and rage < (MORTAL_STRIKE_COST + REND_COST) then
        return false
    end

    if menu.use_whirlwind:get_state() and runtime.whirlwind_id and count_nearby_enemies(me) >= 2 then
        local ww_cd = _get_spell_cd(runtime.whirlwind_id) or math.huge
        if ww_cd <= 1.5 and rage < (WHIRLWIND_COST + REND_COST) then
            return false
        end
    end

    if utils.can_cast_melee(runtime.rend_id, me) and utils.cast_target(runtime.rend_id, target) then
        utils.log_debug(menu, rend_remaining > 0 and "Rend refresh" or "Rend")
        esp_renderer.on_cast(runtime.rend_id, "Rend", color.red(220))
        return true
    end

    return false
end

local function try_mortal_strike(me, target, ctx)
    if not menu.use_mortal_strike:get_state()
        or not target
        or not runtime.mortal_strike_id
    then
        return false
    end

    local can_cast = resource_gate.warrior.has_rage(ctx, 20)
    if not can_cast then
        return false
    end

    if utils.is_spell_already_queued(runtime.mortal_strike_id) then
        return false
    end

    if should_hold_for_slam(me) then
        return false
    end

    if utils.cast_target(runtime.mortal_strike_id, target) then
        utils.log_debug(menu, "Mortal Strike")
                esp_renderer.on_cast(runtime.mortal_strike_id, "Mortal Strike", color.red(220))
        return true
    end

    return false
end

local function try_thunder_clap(me, target, ctx)
    if not runtime.thunder_clap_id or not target then
        return false
    end
    local can_cast = resource_gate.warrior.has_rage(ctx, THUNDER_CLAP_COST)
    if not can_cast then
        return false
    end
    if not utils.is_melee_target(me, target) then
        return false
    end
    if should_hold_for_slam(me) then
        return false
    end
    local mode = get_effective_mode()
    if nearby < 3 then
        if mode == "solo" then return false end
        -- Dungeon/raid: maintain TC debuff for attack speed reduction
        if utils.has_debuff(target, spells.DEBUFF_THUNDER_CLAP) then return false end
    end
    if nearby < 1 then
        return false
    end
    if not utils.can_cast_self(runtime.thunder_clap_id, me) then
        return false
    end
    if utils.cast_self(runtime.thunder_clap_id, me) then
        note_cast()
        utils.log_debug(menu, "Thunder Clap")
        esp_renderer.on_cast(runtime.thunder_clap_id, "Thunder Clap", color.blue(220))
        return true
    end
    return false
end

local function try_execute(me, target, ctx, target_hp_pct)
    if not menu.use_execute:get_state()
        or not target
        or not runtime.execute_id
        or target_hp_pct > EXECUTE_HP_THRESHOLD
    then
        return false
    end

    local can_cast = resource_gate.warrior.has_rage(ctx, EXECUTE_MIN_RAGE)
    if not can_cast then
        return false
    end

    local next_swing_ms = utils.get_next_swing_ms(me, 2)
    if next_swing_ms <= (SLAM_HOLD_REGION_MS + SLAM_SAFE_BUFFER_MS) then
        return false
    end

    if utils.cast_target(runtime.execute_id, target) then
        utils.log_debug(menu, "Execute")
        esp_renderer.on_cast(runtime.execute_id, "Execute", color.orange(220))
        return true
    end

    return false
end

should_hold_for_slam = function(me)
    if not menu.use_slam:get_state() then
        return false
    end
    local safety_buffer_ms = menu.slam_safety_buffer_ms:get() or SLAM_SAFE_BUFFER_MS
    local next_swing_ms = utils.get_next_swing_ms(me, 2)
    if next_swing_ms > 0 and next_swing_ms <= (SLAM_HOLD_REGION_MS + safety_buffer_ms) then
        -- Don't hold for Slam if MS or Overpower is available
        if runtime.mortal_strike_id and core.spell_book.is_usable_spell(runtime.mortal_strike_id) then
            return false
        end
        if runtime.overpower_id and core.spell_book.is_usable_spell(runtime.overpower_id) then
            return false
        end
        return true
    end
    return false
end

local function try_whirlwind(me, target, rage, ctx)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_whirlwind:get_state()
        or not target
        or not runtime.whirlwind_id
        or not runtime.berserker_stance_id
    then
        return false
    end

    local can_cast = resource_gate.warrior.has_rage(ctx, 25)
    if not can_cast then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    if count_nearby_enemies(me) < 2 then
        return false
    end

    if should_hold_for_slam(me) then
        return false
    end

    local ms_cd = runtime.mortal_strike_id and _get_spell_cd(runtime.mortal_strike_id) or 0
    if ms_cd <= 1.5 then
        return false
    end

    local current_stance = utils.get_current_stance(me)
    if current_stance ~= "berserker" then
        if utils.can_stance_dance_for_cost(rage, WHIRLWIND_COST, STANCE_BUFFER_RAGE, runtime.stance_swap_retention)
            and utils.can_cast_self(runtime.berserker_stance_id, me)
            and utils.cast_self(runtime.berserker_stance_id, me)
        then
            utils.set_tracked_stance("berserker")
            utils.log_debug(menu, "Stance -> berserker (WW)")
            return true
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

local function try_slam(me, target, ctx, target_hp_pct)
      if not menu.use_slam:get_state()
           or not target
           or not runtime.slam_id
       then
          return false
      end

     if target_hp_pct and target_hp_pct <= EXECUTE_HP_THRESHOLD then
         return false
     end

     local can_cast = resource_gate.warrior.has_rage(ctx, 20)
     if not can_cast then
         return false
     end

      if not utils.is_melee_target(me, target) then
          return false
      end

      local ms_cd = runtime.mortal_strike_id and _get_spell_cd(runtime.mortal_strike_id) or 0
      if ms_cd <= 1.5 then
          return false
      end

      local time_since_last_swing_ms = swing_timer.get_time_since_last_swing(me) * 1000
      if time_since_last_swing_ms > SLAM_NOW_WINDOW_MS then
          return false
      end

      local safety_buffer_ms = menu.slam_safety_buffer_ms:get() or SLAM_SAFE_BUFFER_MS
      if not utils.can_slam_without_clipping(me, runtime.slam_id, safety_buffer_ms) then
          return false
      end

      local next_swing_ms = utils.get_next_swing_ms(me, 2)
      if next_swing_ms > 0 and next_swing_ms <= (SLAM_HOLD_REGION_MS + safety_buffer_ms) then
          return false
      end

      if utils.cast_target(runtime.slam_id, target) then
          utils.log_debug(menu, "Slam weave")
          return true
      end

     return false
 end


-- --- Charge opener --------------------------------------------------------

local function try_charge(me, target)
    if not runtime.charge_id then return false end
    if me:is_in_combat() then return false end
    if not utils.can_cast_hostile(runtime.charge_id, me, target) then return false end
    if utils.cast_target_fast(runtime.charge_id, target, "Charge") then
        utils.log_debug(menu, "Charge")
        return true
    end
    return false
end

-- --- Offensive CDs --------------------------------------------------------


local function try_berserker_rage(me)
    if not menu.use_berserker_rage or not menu.use_berserker_rage:get_state() then return false end
    if not runtime.berserker_rage_id then return false end
    if not me:is_in_combat() then return false end
    if not utils.can_cast_self(runtime.berserker_rage_id, me) then return false end
    if utils.cast_self_fast(runtime.berserker_rage_id, me) then
        utils.log_debug(menu, "Berserker Rage")
        return true
    end
    return false
end


local function try_death_wish(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_death_wish or not menu.use_death_wish:get_state() then return false end
    if not runtime.death_wish_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_DEATH_WISH) then return false end
    if not utils.can_cast_self(runtime.death_wish_id, me) then return false end
    if utils.cast_self_fast(runtime.death_wish_id, me) then
        utils.log_debug(menu, "Death Wish")
        return true
    end
    return false
end

local function try_recklessness(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_recklessness or not menu.use_recklessness:get_state() then return false end
    if not runtime.recklessness_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_RECKLESSNESS) then return false end

    -- Recklessness requires Berserker Stance - dance there and back
    local in_berserker = utils.has_buff(me, spells.BUFF_BERSERKER_STANCE)
    if not in_berserker then
        -- Check we have enough rage to afford the stance swap cost
        local rage = utils.get_rage(me)
        if not utils.can_stance_dance_for_cost(rage, 0, 0, runtime.stance_swap_retention) then
            return false
        end
        if runtime.berserker_stance_id
           and utils.can_cast_self(runtime.berserker_stance_id, me)
        then
            utils.cast_self(runtime.berserker_stance_id, me)
            utils.log_debug(menu, "Stance -> Berserker (Recklessness)")
            note_cast()
            return true  -- next tick we'll be in Berserker and cast it
        end
        return false
    end

    if not utils.can_cast_self(runtime.recklessness_id, me) then return false end
    if utils.cast_self_fast(runtime.recklessness_id, me) then
        utils.log_debug(menu, "Recklessness")
        esp_renderer.on_cast(runtime.recklessness_id, "Recklessness", color.yellow(220))
        note_cast()
        -- Return to Battle Stance after casting
        if runtime.battle_stance_id and utils.can_cast_self(runtime.battle_stance_id, me) then
            -- Schedule return on next tick (can't double-cast same tick)
            runtime.pending_battle_stance_return = true
        end
        return true
    end
    return false
end


local function try_sweeping_strikes(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_sweeping_strikes or not menu.use_sweeping_strikes:get_state() then return false end
    if not runtime.sweeping_strikes_id then return false end
    if utils.has_buff(me, spells.BUFF_SWEEPING_STRIKES) then return false end
    if count_nearby_enemies(me) < 2 then return false end
    if not utils.can_cast_self(runtime.sweeping_strikes_id, me) then return false end
    if utils.cast_self_fast(runtime.sweeping_strikes_id, me) then
        utils.log_debug(menu, "Sweeping Strikes")
        return true
    end
    return false
end

local function try_enraged_regen(me)
    if not menu.use_enraged_regen or not menu.use_enraged_regen:get_state() then return false end
    if not runtime.enraged_regen_id then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.70 then return false end
    if not utils.can_cast_self(runtime.enraged_regen_id, me) then return false end
    if utils.cast_self(runtime.enraged_regen_id, me) then
        utils.log_debug(menu, "Enraged Regeneration")
        return true
    end
    return false
end


local function do_utility_lane(me, target, mode, target_hp_pct)
    -- Interrupt (Pummel)
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "warrior", utils) then
            return true
        end
    end

    -- Racial offensive CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        if racial_manager.try_offensive(me) then return true end
    end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end

    if try_battle_shout(me) then
        return true
    end

    if mode ~= "solo" then
        if try_demo_shout(me, target) then
            return true
        end
        if try_sunder(me, target, target_hp_pct) then
            return true
        end
    else
        if try_hamstring(me, target, target_hp_pct) then
            return true
        end
    end

    return false
end

local function do_core_lane(me, target, rage, target_hp_pct)
    utils.ensure_melee_auto_attack(me, target)

    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

    -- TTD tracking
    ttd_tracker.update(target)

    -- Burst cooldowns
    try_death_wish(me)
    try_berserker_rage(me)
    try_recklessness(me)
    -- Return to Battle Stance after Recklessness dance
    if runtime.pending_battle_stance_return and runtime.battle_stance_id then
        if utils.can_cast_self(runtime.battle_stance_id, me) then
            utils.cast_self(runtime.battle_stance_id, me)
            runtime.pending_battle_stance_return = false
            utils.log_debug(menu, "Stance -> Battle (after Recklessness)")
        end
    end
    try_sweeping_strikes(me)

    -- Execute phase: prioritize Execute over MS/Overpower
    if target_hp_pct and target_hp_pct < EXECUTE_HP_THRESHOLD then
        if try_execute(me, target, ctx, target_hp_pct) then
            invalidate_ctx()
            return true
        end
    end

    if try_overpower(me, target, ctx) then
        invalidate_ctx()
        return true
    end

    if try_rend(me, target, rage, target_hp_pct) then
        invalidate_ctx()
        return true
    end

    if try_mortal_strike(me, target, ctx) then
        invalidate_ctx()
        return true
    end

    if try_thunder_clap(me, target, ctx) then
        invalidate_ctx()
        return true
    end

    if try_whirlwind(me, target, rage, ctx) then
        invalidate_ctx()
        return true
    end

    -- Non-execute phase: Execute after other abilities
    if target_hp_pct and target_hp_pct >= EXECUTE_HP_THRESHOLD then
        if try_execute(me, target, ctx, target_hp_pct) then
            invalidate_ctx()
            return true
        end
    end

    if try_dump(me, target, rage, ctx, target_hp_pct) then
        invalidate_ctx()
        return true
    end

    if try_slam(me, target, ctx, target_hp_pct) then
        invalidate_ctx()
        return true
    end

    return false
end

local function on_update()
    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = _get_local_player()
    if not me or not me:is_valid() then
        return
    end
        ooc_manager.on_update(me, menu, utils, { show_enchant_warning = true })

    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    if me:is_in_combat() then
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        if menu.auto_flask and menu.auto_flask:get_state() then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if me:is_in_combat() and focus_target and focus_target:is_valid() then
        core.input.set_target(focus_target)
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_battle_shout(me) then return end
    end

    refresh_missing_runtime_spell_ids()
    refresh_mode_cache()

    if utils.throttle("update_set_bonus", 5.0) then
        update_set_bonus(me)
    end

    if try_return_to_battle(me) then
        return
    end

    local target = find_valid_target(me)
    -- PvP: prioritize enemy players in arena/BG/world PvP
    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            local priority = pvp_manager.priority_target(me, enemy_players)
            if priority then target = priority end
        end
    end
    local target_hp_pct = target and utils.get_health_pct(target) or 1.0
    local rage = utils.get_rage(me)
    local mode = get_effective_mode()

    -- Pre-combat charge
    if target and try_charge(me, target) then return end

    -- Enraged Regen (before offensive actions)
    if try_enraged_regen(me) then return end

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "warrior", utils) then
        return
    end

    if do_utility_lane(me, target, mode, target_hp_pct) then
        return
    end

    if target and do_core_lane(me, target, rage, target_hp_pct) then
        return
    end
end

local function cleanup()
end

local function on_control_panel()
    local elements = {}
    
    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[Eax Warrior Arms] Enable"
    if toggle_key_code ~= 7 then
        display_name = "[Eax Warrior Arms] Enable (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end
    control_panel_utility:insert_toggle_(elements, display_name, menu.toggle_key)
    
    return elements
end

resolve_spells()
validate_arms_spec()
refresh_mode_cache()


reactive_adapter = {
    spec = "EAXWarriorArms",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "warrior", utils)
            end,
        },
        life_save_ally = { noop = "unsupported" },
        interrupt_control = {
            handler = function(_, action_deps)
                local interrupt_target = action_deps.target or action_deps.current_target
                if not interrupt_target or not interrupt_target:is_valid() then
                    return false
                end

                if not interrupt_manager.should_interrupt(interrupt_target) then
                    return false
                end

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "warrior", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = { noop = "unsupported" },
        throughput_resume = { noop = "unsupported" },
    },
}

local function on_render()
    return
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(on_update)

-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxwarriorarms_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)

if control_panel_utility then
    core.register_on_render_control_panel_callback(function()
        local elements = {}
        local function add_cb(label, item, uid)
            if not item then return end
            local cur = item:get_state()
            local nxt = control_panel_utility:insert_key_checkbox_(elements, label, cur, 0, false, uid)
            if nxt ~= cur then item:set(nxt) end
        end
        local toggle_key = menu.toggle_key:get_key_code()
        local label = "Eax Warrior Arms] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxwarriorarms_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_war_cds = menu.use_cooldowns:get_state()
            local nxt_war_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[Eax WAr] Cooldowns", cur_war_cds, 0, false, "eax_war_cds_cp")
            if nxt_war_cds ~= cur_war_cds then menu.use_cooldowns:set(nxt_war_cds) end
        end
        if menu.focus_priority then
            local cur_war_focus = menu.focus_priority:get_state()
            local nxt_war_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[Eax WAr] Focus Priority", cur_war_focus, 0, false, "eax_war_focus_cp")
            if nxt_war_focus ~= cur_war_focus then menu.focus_priority:set(nxt_war_focus) end
        end
        if menu.use_racial then
            local cur_war_racial = menu.use_racial:get_state()
            local nxt_war_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[Eax WAr] Use Racial", cur_war_racial, 0, false, "eax_war_racial_cp")
            if nxt_war_racial ~= cur_war_racial then menu.use_racial:set(nxt_war_racial) end
        end
        end
        return elements
    end)
end

-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Warrior"
    local _eax_spec  = "Arms"
    -- Register this spec for its class (last-loaded wins for tracking)
    if not _G.__EAX_LOADED[_eax_class] then
        _G.__EAX_LOADED[_eax_class] = {}
    end
    _G.__EAX_LOADED[_eax_class][_eax_spec] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
    -- Runtime conflict check: fires on render, only warns when 2+ specs enabled
    local _conflict_last_warn = 0
    local _orig_render = on_render
    on_render = function()
        if _orig_render then _orig_render() end
        local specs = _G.__EAX_LOADED[_eax_class]
        if not specs then return end
        local enabled_specs = {}
        for spec_name, is_enabled_fn in pairs(specs) do
            if is_enabled_fn and is_enabled_fn() then
                table.insert(enabled_specs, spec_name)
            end
        end
        if #enabled_specs < 2 then return end
        local now = _core_time()
        if (now - _conflict_last_warn) < 10 then return end
        _conflict_last_warn = now
        local names = table.concat(enabled_specs, " + ")
        core.log("[Eax WARNING] Multiple " .. _eax_class .. " specs enabled: "
            .. names .. ". Disable all but one.")
        core.graphics.add_notification(
            "eax_conflict_" .. _eax_class,
            "[EAX] Conflict!",
            "Multiple " .. _eax_class .. " specs enabled: " .. names .. " - Disable all but one in the bot menu.",
            8.0,
            require("common/color").new(255, 80, 80, 255)
        )
    end
end

return { cleanup = cleanup }
