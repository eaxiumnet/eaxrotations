-- main.lua
-- EAX Warlock Affliction | Rotation logic

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    unstable_affliction_id = nil,
    corruption_id = nil,
    siphon_life_id = nil,
    curse_agony_id = nil,
    curse_doom_id = nil,
    drain_soul_id = nil,
    shadow_bolt_id = nil,
    life_tap_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
}

local GCD_INTERVAL_S = 0.05
local PENDING_CAST_TIMEOUT_S = 1.25
local DOT_REFRESH_MS = 3000
local CURSE_REFRESH_MS = 2000
local LIFE_TAP_MANA_PCT = 0.45
local DRAIN_SOUL_HP_PCT = 0.25

local function resolve_spells()
    runtime.unstable_affliction_id = utils.resolve_spell_id(spells.UNSTABLE_AFFLICTION)
    runtime.corruption_id = utils.resolve_spell_id(spells.CORRUPTION)
    runtime.siphon_life_id = utils.resolve_spell_id(spells.SIPHON_LIFE)
    runtime.curse_agony_id = utils.resolve_spell_id(spells.CURSE_OF_AGONY)
    runtime.curse_doom_id = utils.resolve_spell_id(spells.CURSE_OF_DOOM)
    runtime.drain_soul_id = utils.resolve_spell_id(spells.DRAIN_SOUL)
    runtime.shadow_bolt_id = utils.resolve_spell_id(spells.SHADOW_BOLT)
    runtime.life_tap_id = utils.resolve_spell_id(spells.LIFE_TAP)
end

local function log_spells()
    core.log("[EAX Warlock Affliction] Resolved spells: UA=" .. tostring(runtime.unstable_affliction_id)
        .. " CORR=" .. tostring(runtime.corruption_id)
        .. " SL=" .. tostring(runtime.siphon_life_id)
        .. " Curse=" .. tostring(runtime.curse_agony_id or runtime.curse_doom_id)
        .. " DS=" .. tostring(runtime.drain_soul_id)
        .. " SB=" .. tostring(runtime.shadow_bolt_id))
end

resolve_spells()
log_spells()

local function is_pending_cast(spell_id)
    if not spell_id then
        return false
    end
    local pending = runtime.pending_casts[spell_id]
    if not pending then
        return false
    end
    if (core.time() - pending) >= PENDING_CAST_TIMEOUT_S then
        runtime.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id)
    if not spell_id then
        return
    end
    runtime.pending_casts[spell_id] = core.time()
end

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_INTERVAL_S then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function detect_mode()
    local objects = core.object_manager.get_all_objects()
    local party_count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() 
           and obj:is_party_member() then
            party_count = party_count + 1
        end
    end
    if party_count == 0 then
        return "solo"
    elseif party_count <= 4 then
        return "dungeon"
    end
    return "raid"
end

local function refresh_mode_cache()
    runtime.cached_mode = detect_mode()
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

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
        utils.log_debug(menu, "Toggle -> " .. tostring(menu.enabled:get_state()))
    end
    runtime.prev_toggle_state = current
end

local function is_valid_target(me, target)
    if not me or not target then
        return false
    end
    if not target:is_valid() or target:is_dead() then
        return false
    end
    return me:can_attack(target)
end

local function should_refresh_debuff(target, debuff_ids, threshold_ms)
    if not target or not debuff_ids then
        return true
    end
    local remaining = utils.get_debuff_remaining_ms(target, debuff_ids)
    return remaining <= threshold_ms
end

local function try_cast_spell(me, spell_id, target, label)
    if not spell_id then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.can_cast_target(spell_id, me, target) then
        return false
    end
    if utils.cast_target(spell_id, me, target) then
        mark_pending_cast(spell_id)
        note_cast()
        utils.log_debug(menu, label .. " -> cast")
        return true
    end
    return false
end

local function try_refresh_dots(me, target)
    if menu.use_unstable_affliction:get_state() and should_refresh_debuff(target, spells.UNSTABLE_AFFLICTION, DOT_REFRESH_MS) then
        if try_cast_spell(me, runtime.unstable_affliction_id, target, "Unstable Affliction") then
            return true
        end
    end
    if menu.use_corruption:get_state() and should_refresh_debuff(target, spells.CORRUPTION, DOT_REFRESH_MS) then
        if try_cast_spell(me, runtime.corruption_id, target, "Corruption") then
            return true
        end
    end
    if menu.use_siphon_life:get_state() and should_refresh_debuff(target, spells.SIPHON_LIFE, DOT_REFRESH_MS) then
        if try_cast_spell(me, runtime.siphon_life_id, target, "Siphon Life") then
            return true
        end
    end
    return false
end

local function try_apply_curse(target)
    if not menu.use_curse:get_state() then
        return false
    end
    local curse_id = menu.prefer_doom:get_state() and runtime.curse_doom_id or runtime.curse_agony_id
    if not curse_id then
        curse_id = runtime.curse_agony_id or runtime.curse_doom_id
    end
    if not curse_id then
        return false
    end
    if utils.has_debuff(target, spells.CURSE_OF_DOOM) or utils.has_debuff(target, spells.CURSE_OF_AGONY) then
        return false
    end
    return try_cast_spell(me, curse_id, target, "Curse")
end

local function try_execute(me, target)
    local hp_pct = utils.get_health_pct(target)
    if hp_pct > DRAIN_SOUL_HP_PCT then
        return false
    end
    if not menu.use_drain_soul:get_state() then
        return false
    end
    return try_cast_spell(me, runtime.drain_soul_id, target, "Drain Soul")
end

local function try_filler(me, target)
    if not menu.use_shadow_bolt:get_state() then
        return false
    end
    return try_cast_spell(me, runtime.shadow_bolt_id, target, "Shadow Bolt")
end

local function try_life_tap(me)
    if not menu.use_life_tap:get_state() or not runtime.life_tap_id then
        return false
    end
    local mana_pct = utils.get_mana_pct(me)
    local hp_pct = utils.get_health_pct(me)
    local threshold = menu.life_tap_threshold:get() / 100
    if mana_pct >= LIFE_TAP_MANA_PCT then
        return false
    end
    if hp_pct < threshold then
        return false
    end
    if not utils.can_cast_self(runtime.life_tap_id, me) then
        return false
    end
    if utils.cast_self(runtime.life_tap_id, me) then
        runtime.last_cast_time = core.time()
        utils.log_debug(menu, "Life Tap")
        return true
    end
    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then
        return
    end
    if not try_refresh_dots(me, target) then
        if try_apply_curse(target) then
            return
        end
    else
        return
    end
    if try_execute(me, target) then
        return
    end
    if try_filler(me, target) then
        return
    end
    try_life_tap(me)
end

core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end
    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end
    local target = me:get_target()
    if not is_valid_target(me, target) then
        return
    end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        target = focus_target
    end

    do_rotation(me, target)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local control_panel_elements = {}
    local enable_name = "[EAX Warlock Affliction] Enabled (" .. key_helper:get_key_name(menu.toggle_key:get_key_code()) .. ")"
    control_panel_utility:insert_toggle_(control_panel_elements, enable_name, menu.toggle_key)
    return control_panel_elements
end)

core.log("[EAX Warlock Affliction] Loaded v1.0.0")
