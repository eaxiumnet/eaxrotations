-- main.lua
-- Eax Warlock Demonology | Rotation logic

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local spell_downrank = require("libraries/spell_downrank")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("libraries/eax_utils")
local color     = require("libraries/color")

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")

---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")

---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
local pull_optimizer = require("libraries/pull_optimizer")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
local pvp_manager = require("libraries/pvp_manager")
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

-- CC awareness: check if target can be CC'd (Fear, Banish)
local function can_cc_target(target)
    local ok, cc = pcall(function() return require("common/utility/cc_data_helper") end)
    if not ok or not cc then return false end
    return cc.can_cc and cc.can_cc(target) or false
end

---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("demo", "Warlock Demo")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("libraries/smart_cast_manager")
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
        spec = "EAXWarlockDemonology",
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

---@type mana_conservator
local mana_conservator = require("libraries/mana_conservator")
---@type dot_manager
local dot_manager = require("libraries/dot_manager")
---@type mana_manager
local mana_manager = require("libraries/mana_manager")
---@type threat_manager
local threat_manager = require("libraries/threat_manager")

local threat_initialized = false

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    fel_armor_id = nil,
    soul_link_id = nil,
    soul_fire_id = nil,
    shadow_bolt_id = nil,
    shadow_burn_id = nil,
    drain_soul_id = nil,
    drain_life_id = nil,
    shadowfury_id = nil,
    felguard_id = nil,
    health_funnel_id = nil,
    fel_domination_id = nil,
    life_tap_id = nil,
    immolate_id = nil,
    corruption_id = nil,
    unstable_affliction_id = nil,
    curse_of_agony_id = nil,
    curse_of_elements_id = nil,
    curse_of_weakness_id = nil,
    curse_of_tongues_id = nil,
    torment_id = nil,
    suffering_id = nil,
    banish_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    last_felguard_attempt = 0,
    pet_autocast_configured = false,
    set_multiplier = 1.0,
    -- Warlock utility
    soulstone_id = nil,
    create_healthstone_id = nil,
    create_soulstone_id = nil,
    last_healthstone_create = 0,
    last_soulstone_apply = 0,
}

local ctx_cache = rotation_context.new({})

local GCD_INTERVAL_S = 0.05
local PENDING_CAST_TIMEOUT_S = 2.5
local DRAIN_SOUL_HP_PCT = 0.25
local SHADOW_BURN_HP_PCT = 0.20
local EXECUTE_TTD_BUFFER_S = 0.35

local function get_target_ttd_seconds(target)
    if not target or not ttd_tracker or not ttd_tracker.get then
        return nil
    end
    local ok, value = pcall(function()
        return ttd_tracker.get(target)
    end)
    if not ok then
        return nil
    end
    return tonumber(value)
end

local function get_spell_cast_time_seconds(spell_id)
    if not spell_id then
        return nil
    end
    local cast_time_ms = nil
    if mana_manager and mana_manager.get_spell_cast_time_ms then
        cast_time_ms = mana_manager.get_spell_cast_time_ms(spell_id)
    end
    cast_time_ms = tonumber(cast_time_ms)
    if not cast_time_ms or cast_time_ms <= 0 then
        return nil
    end
    return cast_time_ms / 1000
end

local function resolve_spells()
    runtime.fel_armor_id = utils.resolve_spell_id(spells.FEL_ARMOR)
    runtime.soul_link_id = utils.resolve_spell_id(spells.SOUL_LINK)
    runtime.soul_fire_id = utils.resolve_spell_id(spells.SOUL_FIRE)
    runtime.shadow_bolt_id = utils.resolve_spell_id(spells.SHADOW_BOLT)
    runtime.shadow_burn_id = utils.resolve_spell_id(spells.SHADOW_BURN)
    runtime.drain_soul_id = utils.resolve_spell_id(spells.DRAIN_SOUL)
    runtime.drain_life_id = utils.resolve_spell_id(spells.DRAIN_LIFE)
    runtime.shadowfury_id = utils.resolve_spell_id(spells.SHADOWFURY)
    runtime.felguard_id = utils.resolve_spell_id(spells.SUMMON_FELGUARD)
    runtime.health_funnel_id = utils.resolve_spell_id(spells.HEALTH_FUNNEL)
    runtime.fel_domination_id = utils.resolve_spell_id(spells.FEL_DOMINATION)
    runtime.life_tap_id = utils.resolve_spell_id(spells.LIFE_TAP)
    runtime.immolate_id = utils.resolve_spell_id(spells.IMMOLATE)
    runtime.corruption_id = utils.resolve_spell_id(spells.CORRUPTION)
    runtime.unstable_affliction_id = utils.resolve_spell_id(spells.UNSTABLE_AFFLICTION)
    runtime.curse_of_agony_id = utils.resolve_spell_id(spells.CURSE_OF_AGONY)
    runtime.curse_of_elements_id = utils.resolve_spell_id(spells.CURSE_OF_ELEMENTS)
    runtime.curse_of_weakness_id = utils.resolve_spell_id(spells.CURSE_OF_WEAKNESS)
    runtime.curse_of_tongues_id = utils.resolve_spell_id(spells.CURSE_OF_TONGUES)
    runtime.torment_id = utils.resolve_spell_id(spells.TORMENT)
    runtime.suffering_id = utils.resolve_spell_id(spells.SUFFERING)
    runtime.banish_id = utils.resolve_spell_id(spells.BANISH)
    runtime.soulstone_id = utils.resolve_spell_id(spells.SOULSTONE)
    runtime.create_healthstone_id = utils.resolve_spell_id(spells.CREATE_HEALTHSTONE)
    runtime.create_soulstone_id = utils.resolve_spell_id(spells.CREATE_SOULSTONE)
end

local function log_spells()
    core.log("[Eax Warlock Demonology] Resolved spells: Curse=" .. tostring(runtime.curse_of_agony_id or runtime.curse_of_elements_id)
        .. " Immolate=" .. tostring(runtime.immolate_id)
        .. " Corruption=" .. tostring(runtime.corruption_id)
        .. " UA=" .. tostring(runtime.unstable_affliction_id)
        .. " SB=" .. tostring(runtime.shadow_bolt_id)
        .. " Felguard=" .. tostring(runtime.felguard_id)
        .. " Funnel=" .. tostring(runtime.health_funnel_id)
        .. " FelDom=" .. tostring(runtime.fel_domination_id))
end

resolve_spells()
log_spells()

local function update_set_bonus()
    local me = _get_local_player()
    if not me then return end

    local voidheart_mult = utils.get_set_multiplier(me, "Voidheart")
    local voidheart_regalia_mult = utils.get_set_multiplier(me, "VoidheartRegalia")
    local malefic_mult = utils.get_set_multiplier(me, "Malefic")

    runtime.set_multiplier = voidheart_mult
    if voidheart_regalia_mult > runtime.set_multiplier then
        runtime.set_multiplier = voidheart_regalia_mult
    end
    if malefic_mult > runtime.set_multiplier then
        runtime.set_multiplier = malefic_mult
    end

    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end

local function note_cast()
    runtime.last_cast_time = _core_time()
    rotation_context.invalidate(ctx_cache)
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local function is_gcd_ready()
    return smart_cast_manager.is_gcd_ready()
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

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then
        return "solo"
    elseif idx == 3 then
        return "dungeon"
    elseif idx == 4 then
        return "raid"
    end
    return runtime.cached_mode
end

local function refresh_mode_cache()
    local me = _get_local_player()
    if not me then
        return
    end
    runtime.cached_mode = utils.detect_mode(me) or runtime.cached_mode or "solo"
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
        runtime.prev_toggle_state = current
        utils.log_debug(menu, "Toggle -> " .. tostring(menu.enabled:get_state()))
        return
    end
    runtime.prev_toggle_state = current
end

local function try_cast_spell(me, spell_id, target, label)
    if not spell_id or not target then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.can_cast_hostile(spell_id, me, target) then
        return false
    end
    if utils.cast_target(spell_id, target) then
        mark_pending_cast(spell_id)
        note_cast()
        utils.log_debug(menu, label .. " cast")
        return true
    end
    return false
end

local function try_cast_self(me, spell_id, label)
    if not spell_id or not me then
        return false
    end
    if not utils.can_cast_self(spell_id, me) then
        return false
    end
    if utils.cast_self(spell_id, me) then
        note_cast()
        utils.log_debug(menu, label .. " cast")
        return true
    end
    return false
end

local function should_refresh_debuff(target, debuff_ids, spell_id)
    return dot_manager.can_refresh_dot(target, debuff_ids, spell_id, utils.get_debuff_remaining_ms)
end

local function try_fel_armor(me)
    if not menu.use_fel_armor:get_state() or not runtime.fel_armor_id then
        return false
    end
    if utils.has_buff(me, spells.BUFF_FEL_ARMOR) then
        return false
    end
    return try_cast_self(me, runtime.fel_armor_id, "Fel Armor")
end

local function try_health_funnel(me)
    if not menu.use_health_funnel:get_state() or not runtime.health_funnel_id then
        return false
    end
    local pet = me and me.get_pet and me:get_pet() or nil
    if not pet or not pet:is_valid() or pet:is_dead() then
        return false
    end
    local pet_hp = tonumber(pet.get_health_percentage and pet:get_health_percentage() or nil)
    local me_hp = tonumber(me:get_health_percentage())
    -- Proactive at 70% in combat, reactive at lower HP otherwise
    if not pet_hp or pet_hp > 70 then
        return false
    end
    -- If not in combat, allow lower threshold
    if not me:is_in_combat() and pet_hp > 50 then
        return false
    end
    if me_hp and me_hp < 50 then
        return false
    end
    if utils.cast_target(runtime.health_funnel_id, pet) then
        note_cast()
        utils.log_debug(menu, "Health Funnel cast")
        return true
    end
    return false
end

local function try_felguard_felstorm(me, target)
    if not runtime.felguard_id then
        return false
    end
    local pet = me and me.get_pet and me:get_pet() or nil
    if not pet or not pet:is_valid() or pet:is_dead() then
        return false
    end
    -- Only cast Felstorm if pet is engaged on target
    local pet_target = pet.get_target and pet:get_target() or nil
    if not pet_target or not pet_target:is_valid() then
        return false
    end
    -- Try to cast Felstorm via pet action
    core.input.pet_cast_target_spell(runtime.felguard_id, target)
    return true
end

local function try_fel_domination(me)
    if not menu.use_fel_domination:get_state() or not runtime.fel_domination_id then
        return false
    end
    if me:is_in_combat() then
        return false
    end
    if me:get_pet() then
        return false
    end
    return try_cast_self(me, runtime.fel_domination_id, "Fel Domination")
end

local function ensure_soul_link(me)
    if not menu.maintain_soul_link:get_state() or not runtime.soul_link_id then
        return false
    end
    if utils.has_buff(me, spells.BUFF_SOUL_LINK) then
        return false
    end
    return try_cast_self(me, runtime.soul_link_id, "Soul Link")
end

local PET_NPC_IDS = {
    imp = 416,
    voidwalker = 1860,
    succubus = 1863,
    felhunter = 417,
    felguard = 17252,
}

local SUMMON_SPELLS = {
    imp = spells.SUMMON_IMP,
    voidwalker = spells.SUMMON_VOIDWALKER,
    succubus = spells.SUMMON_SUCCUBUS,
    felhunter = spells.SUMMON_FELHUNTER,
    felguard = spells.SUMMON_FELGUARD,
}

local PET_REQUIRES_SHARD = {
    imp = false,
    voidwalker = true,
    succubus = true,
    felhunter = true,
    felguard = true,
}

local function get_pet_npc_id()
    local me = _get_local_player()
    if not me then return 0 end
    local pet = me.get_pet and me:get_pet() or nil
    if not pet or not pet:is_valid() or pet:is_dead() then return 0 end
    return pet.get_npc_id and pet:get_npc_id() or 0
end

local function current_pet_name()
    local npc = get_pet_npc_id()
    for name, id in pairs(PET_NPC_IDS) do
        if npc == id then return name end
    end
    return "none"
end

local function count_soul_shards()
    if not core or not core.inventory or not core.inventory.get_items_in_bag then
        return 0
    end

    local total = 0
    for bag = 0, 4 do
        local ok, items = pcall(function()
            return core.inventory.get_items_in_bag(bag)
        end)
        if ok and items then
            for _, slot in ipairs(items) do
                local item = slot and slot.object
                if item and item.is_valid and item:is_valid() and item.get_item_id and item:get_item_id() == 6265 then
                    if item.get_item_stack_count then
                        total = total + (item:get_item_stack_count() or 1)
                    else
                        total = total + 1
                    end
                end
            end
        end
    end

    return total
end

local function desired_pet_name(mode)
    local pet_mode = menu.preferred_pet and menu.preferred_pet:get() or 1
    if pet_mode == 2 then return "imp" end
    if pet_mode == 3 then return "voidwalker" end
    if pet_mode == 4 then return "succubus" end
    if pet_mode == 5 then return "felhunter" end
    if pet_mode == 6 and runtime.felguard_id then return "felguard" end
    return nil
end

local function try_summon_correct_pet(me, mode)
    if me:is_in_combat() then return false end

    local now = _core_time()
    local interval = menu.pet_check_interval:get()
    if (now - runtime.last_felguard_attempt) < interval then
        return false
    end
    runtime.last_felguard_attempt = now

    local current = current_pet_name()
    local desired = desired_pet_name(mode)
    if not desired then return false end
    if current == desired then return false end

    if current == "none" and try_fel_domination(me) then
        return true
    end

    local spell_table = SUMMON_SPELLS[desired]
    local spell_id = spell_table and utils.resolve_spell_id(spell_table) or nil
    if PET_REQUIRES_SHARD[desired] and count_soul_shards() < 1 then
        if utils.throttle("eax_demonology_pet_shard_warning", 10.0) then
            core.log("[Eax Warlock Demonology] Cannot summon " .. desired .. ": need at least 1 Soul Shard.")
            core.graphics.add_notification(
                "eax_demonology_pet_shard_warning",
                "[EAX] Pet Summon Blocked",
                "Cannot summon " .. desired .. ": need at least 1 Soul Shard.",
                6.0,
                require("common/color").new(255, 180, 80, 255)
            )
        end
        return false
    end
    if not spell_id or not utils.can_cast_self(spell_id, me) then
        return false
    end

    if utils.cast_self(spell_id, me) then
        note_cast()
        utils.log_debug(menu, "Summoning " .. desired)
        return true
    end
    return false
end

local function is_within_range(a, b, max_range)
    if not a or not b or not max_range then
        return false
    end

    local ok_a, pos_a = pcall(function() return a:get_position() end)
    local ok_b, pos_b = pcall(function() return b:get_position() end)
    if not ok_a or not ok_b or not pos_a or not pos_b then
        return false
    end

    local dx = pos_a.x - pos_b.x
    local dy = pos_a.y - pos_b.y
    local dz = pos_a.z - pos_b.z
    return (dx * dx + dy * dy + dz * dz) <= (max_range * max_range)
end

local function try_banish(me, target)
    if not menu.use_banish or not menu.use_banish:get_state() then return false end
    if not creature_utils.is_banishable(target) then return false end
    if not runtime.banish_id then return false end
    if utils.has_debuff(target, spells.BANISH) then return false end
    return try_cast_spell(me, runtime.banish_id, target, "Banish")
end

local function count_close_hostiles(me, radius)
    local count = 0
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) then
            if is_within_range(me, obj, radius) then
                count = count + 1
            end
        end
    end
    return count
end

local function try_shadowfury(me, target)
    if not menu.use_shadowfury:get_state() or not runtime.shadowfury_id or not target then
        return false
    end
    local clustered = count_close_hostiles(me, 10) >= 3
    if not target:is_casting_spell() and not clustered then
        return false
    end
    return try_cast_spell(me, runtime.shadowfury_id, target, "Shadowfury")
end

local function target_prefers_caster_curse(target)
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if target.is_casting_spell and target:is_casting_spell() then
        return true
    end
    if target.is_channelling_spell and target:is_channelling_spell() then
        return true
    end
    if target.get_max_power then
        local ok, max_mana = pcall(function() return target:get_max_power(0) end)
        if ok and type(max_mana) == "number" and max_mana > 0 then
            return true
        end
    end
    return false
end

local function get_selected_curse(me, target, mode)
    local idx = menu.curse_mode:get()
    if idx == 1 then
        local in_group_content = mode == "dungeon" or mode == "raid"
        if in_group_content then
            if target_prefers_caster_curse(target) and runtime.curse_of_tongues_id then
                return runtime.curse_of_tongues_id, spells.DEBUFF_CURSE_OF_TONGUES, "Curse of Tongues"
            end
            if runtime.curse_of_elements_id then
                return runtime.curse_of_elements_id, spells.DEBUFF_CURSE_OF_ELEMENTS, "Curse of Elements"
            end
            if runtime.curse_of_weakness_id and utils.is_melee_target(me, target) then
                return runtime.curse_of_weakness_id, spells.DEBUFF_CURSE_OF_WEAKNESS, "Curse of Weakness"
            end
        end
        return runtime.curse_of_agony_id, spells.DEBUFF_CURSE_OF_AGONY, "Curse of Agony"
    elseif idx == 2 then
        return runtime.curse_of_elements_id, spells.DEBUFF_CURSE_OF_ELEMENTS, "Curse of Elements"
    elseif idx == 3 then
        return runtime.curse_of_weakness_id, spells.DEBUFF_CURSE_OF_WEAKNESS, "Curse of Weakness"
    elseif idx == 4 then
        return runtime.curse_of_tongues_id, spells.DEBUFF_CURSE_OF_TONGUES, "Curse of Tongues"
    end
    return runtime.curse_of_agony_id, spells.DEBUFF_CURSE_OF_AGONY, "Curse of Agony"
end

local function try_apply_curse(me, target, mode)
    if not menu.use_curse:get_state() then
        return false
    end
    local curse_id, curse_debuffs, label = get_selected_curse(me, target, mode)
    if not curse_id then
        return false
    end
    local selected_is_utility = curse_debuffs ~= spells.DEBUFF_CURSE_OF_AGONY and curse_debuffs ~= spells.DEBUFF_CURSE_OF_DOOM
    if selected_is_utility and target_has_utility_curse(target) and not utils.has_debuff(target, curse_debuffs) then
        return false
    end
    if (not selected_is_utility) and target_has_utility_curse(target) then
        return false
    end
    if not should_refresh_debuff(target, curse_debuffs, curse_id) then
        return false
    end
    return try_cast_spell(me, curse_id, target, label)
end

local function target_has_utility_curse(target)
    return target and (
        utils.has_debuff(target, spells.DEBUFF_CURSE_OF_ELEMENTS)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_WEAKNESS)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_TONGUES)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_RECKLESSNESS)
    )
end

local function try_refresh_dots(me, target)
    if menu.use_immolate:get_state() and runtime.immolate_id
        and should_refresh_debuff(target, spells.DEBUFF_IMMOLATE, runtime.immolate_id) then
        if try_cast_spell(me, runtime.immolate_id, target, "Immolate") then
            return true
        end
    end

    if menu.use_corruption:get_state() and runtime.corruption_id
        and should_refresh_debuff(target, spells.DEBUFF_CORRUPTION, runtime.corruption_id) then
        if try_cast_spell(me, runtime.corruption_id, target, "Corruption") then
            esp_renderer.on_cast(runtime.corruption_id, "Corruption", color.purple(220))
            return true
        end
    end

    if menu.use_unstable_affliction:get_state() and runtime.unstable_affliction_id
        and should_refresh_debuff(target, spells.DEBUFF_UNSTABLE_AFFLICTION, runtime.unstable_affliction_id) then
        if try_cast_spell(me, runtime.unstable_affliction_id, target, "Unstable Affliction") then
            return true
        end
    end

    return false
end

local function try_shadow_burn(me, target)
    if not menu.use_shadow_burn:get_state() or not runtime.shadow_burn_id then
        return false
    end
    if utils.get_health_pct(target) > SHADOW_BURN_HP_PCT then
        return false
    end
    local ttd_s = get_target_ttd_seconds(target)
    local filler_id = runtime.shadow_bolt_id
    if ttd_s and filler_id then
        local filler_cast_s = get_spell_cast_time_seconds(filler_id)
        if filler_cast_s and ttd_s > (filler_cast_s + EXECUTE_TTD_BUFFER_S) then
            return false
        end
    end
    return try_cast_spell(me, runtime.shadow_burn_id, target, "Shadowburn")
end

local function try_drain_soul(me, target)
    if not menu.use_drain_soul:get_state() or not runtime.drain_soul_id then
        return false
    end
    if utils.get_health_pct(target) > DRAIN_SOUL_HP_PCT then
        return false
    end
    local ttd_s = get_target_ttd_seconds(target)
    local drain_soul_cast_s = get_spell_cast_time_seconds(runtime.drain_soul_id)
    if ttd_s and drain_soul_cast_s and ttd_s < (drain_soul_cast_s + EXECUTE_TTD_BUFFER_S) then
        return false
    end
    return try_cast_spell(me, runtime.drain_soul_id, target, "Drain Soul")
end

local function try_soul_fire(me, target)
    if not menu.use_soul_fire:get_state() or not runtime.soul_fire_id then
        return false
    end
    if utils.get_health_pct(target) <= DRAIN_SOUL_HP_PCT then
        return false
    end
    local ttd_s = get_target_ttd_seconds(target)
    local soul_fire_cast_s = get_spell_cast_time_seconds(runtime.soul_fire_id)
    if ttd_s and soul_fire_cast_s and ttd_s < (soul_fire_cast_s + EXECUTE_TTD_BUFFER_S) then
        return false
    end
    return try_cast_spell(me, runtime.soul_fire_id, target, "Soul Fire")
end

local function try_shadow_bolt(me, target)
    if not menu.use_shadow_bolt:get_state() or not runtime.shadow_bolt_id then
        return false
    end
    -- Leveling: use appropriate spell rank
    local shadow_bolt_id = runtime.shadow_bolt_id
    if menu.leveling_conserve_mana and menu.leveling_conserve_mana:get_state() then
        local player_level = me.get_level and me:get_level() or 70
        local target_level = target.get_level and target:get_level() or 70
        local mana_pct = utils.get_mana_pct(me)
        shadow_bolt_id = spell_downrank.select_dps_rank(spells.SHADOW_BOLT, target_level, player_level, mana_pct) or shadow_bolt_id
    end
    local cast_time_ms = mana_manager.get_spell_cast_time_ms(shadow_bolt_id)
    local cast_time_s = cast_time_ms / 1000
    local ttd_s = nil
    if ttd_tracker and ttd_tracker.get then
        local ok, value = pcall(function() return ttd_tracker.get(target) end)
        if ok then ttd_s = tonumber(value) end
    end
    if ttd_s and ttd_s > 0 and ttd_s < (cast_time_s + 0.5) then
        return false
    end
    -- More aggressive SB when Soul Link is active
    local soul_link_active = utils.has_buff(me, spells.BUFF_SOUL_LINK)
    if soul_link_active then
        -- Lower mana threshold for SB when Soul Link is active
        if utils.get_mana_pct(me) < 0.15 then return false end
    else
        if utils.get_mana_pct(me) < 0.20 then return false end
    end
    return try_cast_spell(me, shadow_bolt_id, target, "Shadow Bolt")
end

local function try_life_tap(me, mode)
    if not menu.use_life_tap:get_state() or not runtime.life_tap_id then
        return false
    end
    local mana_pct = utils.get_mana_pct(me)
    local pre_regen_needed = mana_pct < 0.50
    if not mana_manager.should_life_tap(me, menu) and not pre_regen_needed then
        return false
    end

    local threshold = menu.life_tap_threshold:get() / 100
    local health_pct = utils.get_health_pct(me)
    if mode == "raid" then
        threshold = math.max(threshold, 0.55)
    elseif mode == "dungeon" then
        threshold = math.max(threshold, 0.50)
    end
    if health_pct < threshold then
        return false
    end

    return try_cast_self(me, runtime.life_tap_id, "Life Tap")
end

local function try_drain_life_defensive(me, target)
    if not menu.use_drain_life_def or not menu.use_drain_life_def:get_state() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local hp = me:get_health_percentage() / 100
    local threshold = menu.use_drain_life_def_hp_pct and (menu.use_drain_life_def_hp_pct:get() / 100) or 0.35
    if hp > threshold then return false end
    if runtime.drain_life_id and utils.can_cast_hostile(runtime.drain_life_id, me, target) then
        if utils.cast_target(runtime.drain_life_id, target) then
            note_cast()
            utils.log_debug(menu, "Drain Life (defensive)")
            return true
        end
    end
    return false
end

-- --- Warlock Utility: Soulstone, Healthstone, Self-Soulstone (v1.0) --------

local SOULSTONE_COOLDOWN_S = 1800
local HEALTHSTONE_COOLDOWN_S = 120
local HEALTHSTONE_USE_HP = 0.50

local function try_create_healthstone(me)
    if not menu.use_create_healthstone or not menu.use_create_healthstone:get_state() then return false end
    if not runtime.create_healthstone_id then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    local now = _core_time()
    if (now - runtime.last_healthstone_create) < HEALTHSTONE_COOLDOWN_S then return false end
    local has_healthstone = false
    for _, item_id in ipairs(spells.HEALTHSTONE_ITEMS) do
        if core.inventory and core.inventory.get_item_count then
            local count = core.inventory.get_item_count(item_id)
            if count and count > 0 then has_healthstone = true; break end
        end
    end
    if has_healthstone then return false end
    if not utils.can_cast_self(runtime.create_healthstone_id, me) then return false end
    if utils.cast_self(runtime.create_healthstone_id, me) then
        runtime.last_healthstone_create = now
        utils.log_debug(menu, "Create Healthstone")
        return true
    end
    return false
end

local function try_use_healthstone(me)
    if not menu.use_create_healthstone or not menu.use_create_healthstone:get_state() then return false end
    if not me:is_in_combat() then return false end
    local hp = utils.get_health_pct(me)
    if hp > HEALTHSTONE_USE_HP then return false end
    for _, item_id in ipairs(spells.HEALTHSTONE_ITEMS) do
        if core.inventory and core.inventory.get_item_count then
            local count = core.inventory.get_item_count(item_id)
            if count and count > 0 then
                if core.input.use_item(item_id) then
                    utils.log_debug(menu, "Use Healthstone (HP=" .. math.floor(hp * 100) .. "%)")
                    return true
                end
            end
        end
    end
    return false
end

local function try_soulstone_dead_ally(me)
    if not menu.use_soulstone or not menu.use_soulstone:get_state() then return false end
    if not runtime.soulstone_id then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    local now = _core_time()
    if (now - runtime.last_soulstone_apply) < 30 then return false end
    local objects = core.object_manager.get_all_objects()
    for _, obj in ipairs(objects) do
        if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
            and obj:is_party_member() and obj:is_dead() and not obj:is_ghost() then
            if not utils.has_buff(obj, spells.SOULSTONE) then
                if utils.can_cast_target(runtime.soulstone_id, me, obj) then
                    if utils.cast_target(runtime.soulstone_id, obj, "Soulstone") then
                        runtime.last_soulstone_apply = now
                        utils.log_debug(menu, "Soulstone on " .. (obj.get_name and obj:get_name() or "party member"))
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function try_self_soulstone(me)
    if not menu.use_soulstone or not menu.use_soulstone:get_state() then return false end
    if not runtime.soulstone_id then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    if utils.has_buff(me, spells.SOULSTONE) then return false end
    local now = _core_time()
    if (now - runtime.last_soulstone_apply) < 30 then return false end
    if not utils.can_cast_self(runtime.soulstone_id, me) then return false end
    if utils.cast_self(runtime.soulstone_id, me) then
        runtime.last_soulstone_apply = now
        utils.log_debug(menu, "Soulstone (self)")
        return true
    end
    return false
end

local function do_rotation(me, target)
    if mana_conservator.on_update(me, target, menu, utils) then return end
    if not is_gcd_ready() then return end

    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "warlock", utils) then
            return
        end
    end

    if leveling_manager.try_wand(me, target, menu) then return true end
    enc = encounter_manager.get_policy(me)

    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        if racial_manager.try_offensive(me) then return true end
    end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end

    ttd_tracker.update(target)

    if (me:is_casting_spell() or me:is_channelling_spell()) and dps_risk.should_abort_commit(
        dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker),
        {
            kind = me:is_channelling_spell() and "channel" or "cast",
            progress_pct = 0.20,
            remaining_s = 1.0,
            projected_damage_pct = 0.06,
        }
    ) then
        if SpellStopCasting then
            SpellStopCasting()
            return true
        end
    end

    if try_drain_life_defensive(me, target) then return true end
    if defensive_manager.try_defensive(me, "warlock", utils) then return end
    if try_health_funnel(me) then return true end
    if try_felguard_felstorm(me, target) then return true end

    if me:is_in_combat() then
        local current_target = me:get_target()
        local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
        if ok and should_fade and dps_risk.should_drop_threat(dps_runtime.build_snapshot(me, current_target, encounter_manager, ttd_tracker)) then
            pcall(function() threat_manager.try_fade(me) end)
            return
        end
    end

    if mana_manager.should_use_mana_potion(me, 30) then
        if mana_manager.use_mana_potion() then
            return
        end
    end

    local effective_mode = get_effective_mode()

    if try_summon_correct_pet(me, effective_mode) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.04) and try_fel_armor(me) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.04) and ensure_soul_link(me) then return end
    if try_banish(me, target) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_shadowfury(me, target) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) then
        if ctx.self and ctx.self.soul_shards and ctx.self.soul_shards < 1 then return false end
        if try_shadow_burn(me, target) then return end
        if try_drain_soul(me, target) then return end
        if try_soul_fire(me, target) then return end
    end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_shadow_bolt(me, target) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_apply_curse(me, target, effective_mode) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_refresh_dots(me, target) then return end
    try_life_tap(me, effective_mode)
end

reactive_adapter = {
    spec = "EAXWarlockDemonology",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "warlock", utils)
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "warlock", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(_, action_deps)
                local snapshot = dps_runtime.build_snapshot(action_deps.me, action_deps.current_target, encounter_manager, ttd_tracker)
                if not dps_risk.should_drop_threat(snapshot) then
                    return false
                end
                local ok, faded = pcall(function()
                    return threat_manager.try_fade(action_deps.me)
                end)
                if not ok then
                    return false
                end
                return faded ~= false
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

local function on_render()
    return
end

core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)

core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end
    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end
    local me = _get_local_player()
    if not me or me:is_dead() then
        return
    end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
    ooc_manager.on_update(me, menu, utils)

    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    -- Warlock utility: healthstone, soulstone
    if try_create_healthstone(me) then return end
    if try_soulstone_dead_ally(me) then return end
    if try_self_soulstone(me) then return end
    if try_use_healthstone(me) then return end

    if me:is_in_combat() then
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        if menu.auto_flask and menu.auto_flask:get_state() then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    local effective_mode = get_effective_mode()
    if not focus_target and try_summon_correct_pet(me, effective_mode) then return end
    local target = focus_target or utils.find_best_target(me)
    -- PvP: prioritize enemy players in arena/BG/world PvP
    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            local priority = pvp_manager.priority_target(me, enemy_players)
            if priority then target = priority end
        end
    end
    if not target then return end

    if focus_target and focus_target:is_valid() then
        target = focus_target
    end

    do_rotation(me, target)
end)

local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxwarlockdemonology_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)

core.register_on_render_menu_callback(function()
    menu.render()
end)

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
        local label = "Eax Warlock Demo] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxwarlockdemonology_enabled_cp")
        return elements
    end)
end

do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Warlock"
    local _eax_spec  = "Demonology"
    if not _G.__EAX_LOADED[_eax_class] then
        _G.__EAX_LOADED[_eax_class] = {}
    end
    _G.__EAX_LOADED[_eax_class][_eax_spec] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
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

local _pi = pcall(require, "plugin_info") and require("plugin_info") or nil
core.log("[Eax Warlock Demonology] Loaded " .. (_pi and _pi.plugin_version or "?"))
