-- main.lua
-- EAX Shaman Enhancement | Stormstrike-driven melee
-- APIs validated against core, object_manager, and spellbook docs

require("common/wow_api_clone")  -- exposes GetWeaponEnchantInfo for temp enchant detection
local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("enhance", "Shaman Enh")
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type key_helper
---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type color
local color = require("color")

local GCD_INTERVAL = 1.5  -- actual TBC GCD duration
local MODE_REFRESH_INTERVAL = 4.5
local PENDING_CAST_TIMEOUT_S = 2.5
local dev_id = "eax_shaman_enhancement_"

local MODE_PROFILE = {
    solo = { aoe_threshold = 2, mana_floor = 5, swing_clip_ms = 140 },
    dungeon = { aoe_threshold = 3, mana_floor = 10, swing_clip_ms = 160 },
    raid = { aoe_threshold = 4, mana_floor = 15, swing_clip_ms = 170 },
}

local runtime = {
    ancestral_spirit_id = nil,
    stormstrike_id = nil,
    shamanistic_rage_id = nil,
    earth_shock_id = nil,
    flame_shock_id = nil,
    frost_shock_id = nil,
    chain_lightning_id = nil,
    lightning_bolt_id = nil,
    totem_of_wrath_id = nil,
    windfury_totem_id = nil,
    lava_lash_id = nil,
    feral_spirit_id = nil,
    windfury_weapon_id = nil,
    water_shield_id      = nil,
    lightning_shield_id  = nil,
    healing_wave_id      = nil,
    lesser_hw_id         = nil,
    ghost_wolf_id        = nil,
    searing_totem_id = nil,
    magma_totem_id = nil,
    grace_of_air_id = nil,
    wrath_of_air_id = nil,
    strength_earth_id = nil,
    mana_spring_id = nil,
    last_windfury_drop = 0,
    flametongue_weapon_id = nil,
    last_windfury_at      = 0,
    last_flametongue_at   = 0,
    wind_shear_id = nil,
    set_multiplier = 1.0,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    last_stormstrike_at = 0,
    totem_last_apply = {},
}

local TOTEM_ROTATION = {
    { name = "wrath", id_field = "totem_of_wrath_id", toggle = menu.auto_totem_wrath, label = "Totem of Wrath" },
    { name = "windfury", id_field = "windfury_totem_id", toggle = menu.auto_totem_windfury, label = "Windfury Totem" },
}

local SHOCK_TABLE = {
    [1] = { id_field = "earth_shock_id", debuff = spells.EARTH_SHOCK, label = "Earth Shock" },
    [2] = { id_field = "flame_shock_id", debuff = spells.FLAME_SHOCK, label = "Flame Shock" },
    [3] = { id_field = "frost_shock_id", debuff = spells.FROST_SHOCK, label = "Frost Shock" },
}

local function resolve_spells()
    runtime.stormstrike_id = utils.resolve_spell_id(spells.STORMSTRIKE)
    runtime.shamanistic_rage_id = utils.resolve_spell_id(spells.SHAMANISTIC_RAGE)
    runtime.earth_shock_id = utils.resolve_spell_id(spells.EARTH_SHOCK)
    runtime.flame_shock_id = utils.resolve_spell_id(spells.FLAME_SHOCK)
    runtime.frost_shock_id = utils.resolve_spell_id(spells.FROST_SHOCK)
    runtime.chain_lightning_id = utils.resolve_spell_id(spells.CHAIN_LIGHTNING)
    runtime.lightning_bolt_id = utils.resolve_spell_id(spells.LIGHTNING_BOLT)
    runtime.totem_of_wrath_id = utils.resolve_spell_id(spells.TOTEM_OF_WRATH)
    runtime.windfury_totem_id      = utils.resolve_spell_id(spells.WINDFURY_TOTEM)
    runtime.lava_lash_id            = utils.resolve_spell_id(spells.LAVA_LASH)
    runtime.feral_spirit_id         = utils.resolve_spell_id(spells.FERAL_SPIRIT)
    runtime.windfury_weapon_id    = utils.resolve_spell_id(spells.WINDFURY_WEAPON)
    runtime.water_shield_id      = utils.resolve_spell_id(spells.WATER_SHIELD)
    runtime.lightning_shield_id  = utils.resolve_spell_id(spells.LIGHTNING_SHIELD)
    runtime.healing_wave_id      = utils.resolve_spell_id(spells.HEALING_WAVE)
    runtime.lesser_hw_id         = utils.resolve_spell_id(spells.LESSER_HEALING_WAVE)
    runtime.ghost_wolf_id        = utils.resolve_spell_id(spells.GHOST_WOLF)
    runtime.searing_totem_id   = utils.resolve_spell_id(spells.SEARING_TOTEM)
    runtime.magma_totem_id     = utils.resolve_spell_id(spells.MAGMA_TOTEM)
    runtime.grace_of_air_id    = utils.resolve_spell_id(spells.GRACE_OF_AIR_TOTEM)
    runtime.wrath_of_air_id    = utils.resolve_spell_id(spells.WRATH_OF_AIR_TOTEM)
    runtime.strength_earth_id  = utils.resolve_spell_id(spells.STRENGTH_OF_EARTH_TOTEM)
    runtime.mana_spring_id     = utils.resolve_spell_id(spells.MANA_SPRING_TOTEM)
    runtime.magma_totem_id         = utils.resolve_spell_id(spells.MAGMA_TOTEM)
    runtime.flametongue_weapon_id   = utils.resolve_spell_id(spells.FLAMETONGUE_WEAPON)
    runtime.wind_shear_id = utils.resolve_spell_id(spells.WINDSHEAR)
    runtime.ancestral_spirit_id  = utils.resolve_spell_id(spells.ANCESTRAL_SPIRIT)
end

local function log_resolved_spells()
    utils.log_debug(menu, "Resolved Stormstrike=" .. tostring(runtime.stormstrike_id))
    utils.log_debug(menu, "Resolved LavaLash=" .. tostring(runtime.lava_lash_id))
    utils.log_debug(menu, "Resolved FeralSpirit=" .. tostring(runtime.feral_spirit_id))
    -- Always log these so player can see what's available
    core.log("[EAX Enh] Stormstrike ID: " .. tostring(runtime.stormstrike_id)
        .. " | LavaLash: " .. tostring(runtime.lava_lash_id)
        .. " | FeralSpirit: " .. tostring(runtime.feral_spirit_id))
    -- Scan for Stormstrike/Lava Lash if not found by ID table
    if not runtime.stormstrike_id then
        -- Try scanning common TBC+custom server Stormstrike IDs
        local alt_ids = { 17364, 17423, 17424, 17425, 32175, 32176, 38967 }
        for _, id in ipairs(alt_ids) do
            if core.spell_book.is_spell_learned(id) then
                core.log("[EAX Enh] Found Stormstrike at alt ID: " .. id)
                runtime.stormstrike_id = id
                break
            end
        end
        if not runtime.stormstrike_id then
            core.log("[EAX Enh] Stormstrike not in spellbook - is Enhancement talent learned?")
        end
    end
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
    local selection = menu.mode:get()
    if selection == 2 then return "solo" end
    if selection == 3 then return "dungeon" end
    if selection == 4 then return "raid" end
    return runtime.cached_mode
end

local function get_mode_profile()
    local mode = get_effective_mode()
    return MODE_PROFILE[mode] or MODE_PROFILE.solo
end

local function mark_pending_cast(spell_id, timeout)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = {
        requested_at = core.time(),
        timeout_s = timeout or PENDING_CAST_TIMEOUT_S,
    }
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local pending = runtime.pending_casts[spell_id]
    if not pending then return false end
    if (core.time() - pending.requested_at) >= pending.timeout_s then
        runtime.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_INTERVAL then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function try_cast_target(me, target, spell_id, label)
    if not spell_id or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.is_valid_hostile(me, target) then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.cast_target(spell_id, target, nil) then
        return false
    end
    mark_pending_cast(spell_id)
    note_cast()
    local target_name = target:get_name() or "?"
    esp_renderer.on_cast(spell_id, label, color.cyan(220), target_name)
    utils.log_debug(menu, label .. " cast")
    return true
end

local function try_cast_self(me, spell_id, label)
    if not spell_id or not me or not me:is_valid() then return false end
    if is_pending_cast(spell_id) then return false end
    if not utils.can_cast_self(spell_id, me) then return false end
    if not utils.cast_self(spell_id, me) then return false end
    mark_pending_cast(spell_id)
    note_cast()
    esp_renderer.on_cast(spell_id, label, color.yellow(220), "Self")
    utils.log_debug(menu, label .. " cast")
    return true
end

local function ensure_totems(me)
    if not menu.auto_totems:get_state() then return end
    local now = core.time()
    for _, entry in ipairs(TOTEM_ROTATION) do
        if entry.toggle:get_state() then
            local spell_id = runtime[entry.id_field]
            if spell_id and utils.can_cast_self(spell_id, me) then
                local last = runtime.totem_last_apply[entry.name] or 0
                if (now - last) >= 30 then
                    if try_cast_self(me, spell_id, entry.label) then
                        runtime.totem_last_apply[entry.name] = now
                    end
                end
            end
        end
    end
end

local function try_shamanistic_rage(me)
    if not menu.use_cooldowns:get_state() or not runtime.shamanistic_rage_id then
        return false
    end
    local hp_pct = utils.get_health_pct(me)
    local mana_pct = utils.get_mana_pct(me)
    if hp_pct <= (menu.shamanistic_rage_hp:get() / 100) or mana_pct <= (menu.shamanistic_rage_mana:get() / 100) then
        return try_cast_self(me, runtime.shamanistic_rage_id, "Shamanistic Rage")
    end
    return false
end

local function try_stormstrike(me, target)
    if not runtime.stormstrike_id then
        utils.log_debug(menu, "Stormstrike: no spell ID resolved (not learned?)")
        return false
    end
    if not target then return false end
    if not utils.is_melee_target(me, target) then
        utils.log_debug(menu, "Stormstrike: target not in melee range")
        return false
    end
    local cd = core.spell_book.get_spell_cooldown(runtime.stormstrike_id)
    if cd > 0 then
        utils.log_debug(menu, "Stormstrike: on cooldown " .. string.format("%.1f", cd) .. "s")
        return false
    end
    if try_cast_target(me, target, runtime.stormstrike_id, "Stormstrike") then
        runtime.last_stormstrike_at = core.time()
        return true
    end
    return false
end

local function should_chain_lightning_weave()
    if runtime.last_stormstrike_at == 0 then
        return false
    end
    local profile = get_mode_profile()
    local now = core.time()
    local clip_window = math.max(menu.swing_clip_ms:get(), profile.swing_clip_ms) / 1000
    return (now - runtime.last_stormstrike_at) >= clip_window
end

local function try_chain_lightning_weave(me, target)
    if not menu.use_chain_lightning_weave:get_state() or not runtime.chain_lightning_id or not target then
        return false
    end
    if not should_chain_lightning_weave() then return false end
    local profile = get_mode_profile()
    local enemies = utils.count_enemies_in_range(me, spells.CHAIN_LIGHTNING_RADIUS)
    if enemies < profile.aoe_threshold then return false end
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct < (profile.mana_floor / 100) then return false end
    return try_cast_target(me, target, runtime.chain_lightning_id, "Chain Lightning")
end

local function try_shock(me, target)
    if not target or not utils.is_valid_hostile(me, target) then
        return false
    end
    local shock_index = menu.shock_mode:get()
    local shock_entry = SHOCK_TABLE[shock_index]
    if not shock_entry then return false end
    local spell_id = runtime[shock_entry.id_field]
    if not spell_id then return false end
    if utils.has_debuff(target, shock_entry.debuff) then return false end
    return try_cast_target(me, target, spell_id, shock_entry.label)
end


-- --- Weapon Imbue Maintenance (v1.1) --------------------------------------

local IMBUE_DURATION_S = 29 * 60    -- fallback timer

local function try_weapon_imbues(me)
    if not utils.throttle("weapon_imbue_check", 5.0) then return false end
    local bm = require("common/modules/buff_manager")

    -- Main hand: Windfury Weapon
    -- Check via time-based fallback: reapply every 25 minutes (buff lasts 30 min)
    if runtime.windfury_weapon_id then
        local wf_buff = bm:get_buff_data(me, spells.BUFF_WINDFURY_WEAPON)
        local has_wf = wf_buff and wf_buff.is_active
        local needs = not has_wf and (core.time() - runtime.last_windfury_at) >= IMBUE_DURATION_S
        if needs and utils.can_cast_self(runtime.windfury_weapon_id, me) then
            if utils.cast_self(runtime.windfury_weapon_id, me) then
                runtime.last_windfury_at = core.time()
                esp_renderer.on_cast(runtime.windfury_weapon_id, "Windfury Weapon", color.yellow(220), "Self")
                return true
            end
        end
    end
    -- Off hand: Flametongue Weapon
    if runtime.flametongue_weapon_id then
        local ft_buff = bm:get_buff_data(me, spells.BUFF_FLAMETONGUE_WEAPON)
        local has_ft = ft_buff and ft_buff.is_active
        local needs = not has_ft and (core.time() - runtime.last_flametongue_at) >= IMBUE_DURATION_S
        if needs and utils.can_cast_self(runtime.flametongue_weapon_id, me) then
            if utils.cast_self(runtime.flametongue_weapon_id, me) then
                runtime.last_flametongue_at = core.time()
                esp_renderer.on_cast(runtime.flametongue_weapon_id, "Flametongue Weapon", color.orange(220), "Self")
                return true
            end
        end
    end
    return false
end

-- --- Offensive CDs (v1.1) -------------------------------------------------

local function try_feral_spirit(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_feral_spirit or not menu.use_feral_spirit:get_state() then return false end
    if not runtime.feral_spirit_id then return false end   -- nil = talent not taken
    if not me:is_in_combat() then return false end
    return try_cast_self(me, runtime.feral_spirit_id, "Feral Spirit")
end

local function try_lava_lash(me, target)
    if not runtime.lava_lash_id then return false end      -- nil = talent not taken
    return try_cast_target(me, target, runtime.lava_lash_id, "Lava Lash")
end



-- --- Fire Totem maintenance (v1.3) ---------------------------------------
-- Maintain Searing Totem (single target) or Magma Totem (2+ enemies).
-- Totems have a 1-min duration; we re-drop when expired.

local FIRE_TOTEM_REFRESH_S = 55.0   -- re-drop 5s before expiry


-- --- Totem Twist (v1.4) ---------------------------------------------------
-- Pattern from tbc/ enhancement/rotation.go:
-- Drop Windfury Totem every 10s for the proc, then drop Grace/Wrath of Air
-- for the buff. In practice: WF first 1s, then default air totem for 9s.
-- Simple implementation: maintain WF + re-drop when expired.

local WF_TOTEM_DURATION_S   = 10.0
local AIR_TOTEM_DURATION_S  = 120.0
local TOTEM_EARLY_REFRESH_S = 5.0

local function try_totem_twist(me)
    if not menu.use_totem_twist or not menu.use_totem_twist:get_state() then return false end
    if not utils.throttle("totem_twist_check", 2.0) then return false end
    if me:is_moving() then return false end
    if not me:is_in_combat() then return false end

    local now = core.time()
    local time_since_wf = now - runtime.last_windfury_drop

    -- Drop Windfury Totem every 10 seconds
    if time_since_wf >= WF_TOTEM_DURATION_S and runtime.windfury_totem_id then
        if utils.can_cast_self(runtime.windfury_totem_id, me) then
            utils.cast_self(runtime.windfury_totem_id, me)
            runtime.last_windfury_drop = now
            utils.log_debug(menu, "Windfury Totem (twist)")
            esp_renderer.on_cast(runtime.windfury_totem_id, "Lava Lash", color.red(220), "Self")
        return true
        end
    end

    -- In between WF drops: maintain Grace/Wrath of Air if not active
    if time_since_wf < 1.5 then return false end  -- just dropped WF, wait

    -- Check for Grace of Air buff on party (simplified: check self)
    local has_air_buff = utils.has_buff(me, spells.BUFF_GRACE_OF_AIR)
        or utils.has_buff(me, spells.BUFF_WINDFURY_TOTEM)
    if not has_air_buff then
        local air_id = runtime.wrath_of_air_id or runtime.grace_of_air_id
        if air_id and utils.can_cast_self(air_id, me) then
            utils.cast_self(air_id, me)
            utils.log_debug(menu, "Air Totem (twist filler)")
            return true
        end
    end

    return false
end

-- --- Strength/Mana totem maintenance (v1.4) ------------------------------

local function try_earth_totem(me)
    if not menu.use_earth_totem or not menu.use_earth_totem:get_state() then return false end
    if not utils.throttle("earth_totem_check", 30.0) then return false end
    if me:is_moving() then return false end
    if runtime.strength_earth_id and utils.can_cast_self(runtime.strength_earth_id, me) then
        utils.cast_self(runtime.strength_earth_id, me)
        utils.log_debug(menu, "Strength of Earth Totem")
        return true
    end
    return false
end

local function try_water_totem(me)
    if not menu.use_water_totem or not menu.use_water_totem:get_state() then return false end
    if not utils.throttle("water_totem_check", 30.0) then return false end
    if me:is_moving() then return false end
    if runtime.mana_spring_id and utils.can_cast_self(runtime.mana_spring_id, me) then
        utils.cast_self(runtime.mana_spring_id, me)
        utils.log_debug(menu, "Mana Spring Totem")
        return true
    end
    return false
end


local function try_fire_totem(me, enemy_count)
    if not menu.use_fire_totem or not menu.use_fire_totem:get_state() then return false end
    if not utils.throttle("fire_totem_check", 5.0) then return false end
    -- Don't drop totems while moving
    if me and me.is_moving and me:is_moving() then return false end

    -- Choose totem type by enemy count
    local totem_id = (enemy_count and enemy_count >= 3)
        and runtime.magma_totem_id
        or runtime.searing_totem_id

    if not totem_id then return false end
    if not utils.can_cast_self(totem_id, me) then return false end
    -- Check if a fire totem is already active (simple CD check)
    if utils.is_spell_already_queued and utils.is_spell_already_queued(totem_id) then return false end

    if utils.cast_self(totem_id, me) then
        utils.log_debug(menu, "Fire Totem dropped")
        return true
    end
    return false
end



-- -- Shield maintenance --------------------------------------------------------
local function ensure_shield(me)
    local mode = menu.shield_mode and menu.shield_mode:get() or 3
    if mode == 0 then return false end
    -- Auto mode: Lightning Shield for Enhancement (melee DPS), Water at 60+
    local use_water
    if mode == 1 then use_water = false
    elseif mode == 2 then use_water = true
    else use_water = (me:get_level() or 0) >= 60 end

    if use_water and runtime.water_shield_id then
        if not utils.has_buff(me, spells.BUFF_WATER_SHIELD) then
            return try_cast_self(me, runtime.water_shield_id, "Water Shield")
        end
    elseif not use_water and runtime.lightning_shield_id then
        if not utils.has_buff(me, spells.BUFF_LIGHTNING_SHIELD) then
            return try_cast_self(me, runtime.lightning_shield_id, "Lightning Shield")
        end
    end
    return false
end

-- -- Self-healing --------------------------------------------------------------
local function try_self_heal(me)
    if not menu.use_healing_wave or not menu.use_healing_wave:get_state() then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = (menu.healing_wave_hp and menu.healing_wave_hp:get() or 40) / 100
    if hp_pct > threshold then return false end
    -- Prefer Lesser Healing Wave (faster cast, less mana) if available
    local prefer_lhw = menu.use_lesser_healing_wave and menu.use_lesser_healing_wave:get_state()
    if prefer_lhw and runtime.lesser_hw_id then
        return try_cast_self(me, runtime.lesser_hw_id, "Lesser Healing Wave")
    end
    if runtime.healing_wave_id then
        return try_cast_self(me, runtime.healing_wave_id, "Healing Wave")
    end
    return false
end

-- -- Ghost Wolf OOC ------------------------------------------------------------
local GHOST_WOLF_BUFF = { 2645 }
local function try_ghost_wolf(me)
    if not menu.use_ghost_wolf or not menu.use_ghost_wolf:get_state() then return false end
    if not runtime.ghost_wolf_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, GHOST_WOLF_BUFF) then return false end
    if eax_utils.is_eating_or_drinking(me) then return false end
    local ok, casting = pcall(function() return me:is_casting_spell() end)
    if ok and casting then return false end
    local ok2, channing = pcall(function() return me:is_channelling_spell() end)
    if ok2 and channing then return false end
    return try_cast_self(me, runtime.ghost_wolf_id, "Ghost Wolf")
end

-- -- Lightning Bolt ranged pull ------------------------------------------------
local function try_lb_pull(me, target)
    if not menu.use_lb_pull or not menu.use_lb_pull:get_state() then return false end
    if not runtime.lightning_bolt_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.is_valid_hostile(me, target) then return false end
    local pull_range = menu.lb_pull_range and menu.lb_pull_range:get() or 25
    local dist = utils.get_distance(me, target)
    if dist < pull_range then return false end  -- close enough to melee, skip
    return try_cast_target(me, target, runtime.lightning_bolt_id, "Lightning Bolt (Pull)")
end

local function do_rotation(me, target)
    -- Lazy re-resolve: spells may not be learned yet at plugin load time
    if not runtime.stormstrike_id then resolve_spells() end
    if not is_gcd_ready() then return false end
    -- Interrupt (Earth Shock / Wind Shear)
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "shaman", utils) then
            return true
        end
    end


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "shaman", utils) then
        return true
    end

    ensure_totems(me)
    -- Weapon imbues (out of combat / throttled)
    try_weapon_imbues(me)

    -- Totem maintenance
    local _enh_enemies = utils.enemy_count_in_radius and utils.enemy_count_in_radius(me, 10) or 1
    try_totem_twist(me)
    try_fire_totem(me, _enh_enemies)
    try_earth_totem(me)
    try_water_totem(me)

    -- TTD tracking
    ttd_tracker.update(target)

    -- Offensive CDs
    if try_feral_spirit(me, target) then return true end
    if try_shamanistic_rage(me) then return true end
    if try_stormstrike(me, target) then return true end
    if try_lava_lash(me, target) then return true end
    if try_chain_lightning_weave(me, target) then return true end
    if try_shock(me, target) then return true end
    -- Auto-attack fallback for leveling 1-70
    if me:is_in_combat() and target and target:is_valid() and not target:is_dead()
       and me:can_attack(target) then
        leveling_manager.ensure_melee(me, target)
    end

    return false
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local enabled = menu.enabled:get_state()
        menu.enabled:set(not enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not enabled))
    end
    runtime.prev_toggle_state = current
end

resolve_spells()
log_resolved_spells()

local function update_set_bonus()
    local me = core.object_manager.get_local_player()
    if not me then return end
    
    local cyclone_mult = utils.get_set_multiplier(me, "Cyclone")
    local cataclysm_mult = utils.get_set_multiplier(me, "Cataclysm")
    local skyshatter_mult = utils.get_set_multiplier(me, "Skyshatter")
    
    runtime.set_multiplier = cyclone_mult
    if cataclysm_mult > runtime.set_multiplier then
        runtime.set_multiplier = cataclysm_mult
    end
    if skyshatter_mult > runtime.set_multiplier then
        runtime.set_multiplier = skyshatter_mult
    end
    
    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end


local function on_render()
    esp_renderer.on_render(menu)
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", MODE_REFRESH_INTERVAL) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end
    handle_toggle()
    if not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        rez_spell_id = runtime.ancestral_spirit_id,
    })
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then return end
    if eax_utils.is_eating_or_drinking(me) then return end
    local focus_target = eax_utils.get_focus_target(menu)
    -- Validate focus target is hostile; if not, fall through to smart selector
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    -- Smart target selection: prioritize units actively fighting us/party
    local target = focus_target or utils.find_best_target(me)
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = utils.get_health_pct(me)
    if my_hp < self_threshold then
        -- Enhancement self-heal: use Lesser Healing Wave if learned, else skip
        -- (Shamanistic Rage handles mana-based self-sustain; NS is not in this rotation)
        local lhw_id = utils.resolve_spell_id({ 25420, 10468, 10467, 10466, 8010, 8008, 8004 })
        if lhw_id and utils.can_cast_self(lhw_id, me) then
            utils.cast_self(lhw_id, me)
        end
    end
    -- OOC: ghost wolf
    if not me:is_in_combat() then
        try_ghost_wolf(me)
    end

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxshamanenhancement_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(function()
    menu.render()
end)

if control_panel_utility then
    core.register_on_render_control_panel_callback(function()
        local elements = {}
        local function add_cb(label, item, uid)
            if not item then return end
            local cur = item:get_state()
            local nxt = control_panel_utility:insert_key_checkbox_(
                elements, label, cur, 0, false, uid)
            if nxt ~= cur then item:set(nxt) end
        end
        local toggle_key = menu.toggle_key:get_key_code()
        local label = "[EAX Shaman Enhancement] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        local function add_kb(lbl, kb)
            if not kb then return end
            control_panel_utility:insert_toggle_(elements, lbl, kb, false)
        end
        add_cb(label,                           menu.enabled,                   "eax_enh_enabled_cp")
        if menu.enabled:get_state() then
            add_cb("[EAX Enh] Use Cooldowns",       menu.use_cooldowns,             "eax_enh_cds_cp")
            add_cb("[EAX Enh] Auto Totems",         menu.auto_totems,               "eax_enh_totems_cp")
            add_cb("[EAX Enh] Windfury Totem",      menu.auto_totem_windfury,       "eax_enh_wf_cp")
            add_cb("[EAX Enh] Chain Lightning",     menu.use_chain_lightning_weave, "eax_enh_cl_cp")
            add_cb("[EAX Enh] Dual Wield Focus",    menu.dual_wield_focus,          "eax_enh_dw_cp")
            add_cb("[EAX Enh] Self-Heal",           menu.use_healing_wave,          "eax_enh_hw_cp")
            add_cb("[EAX Enh] LB Pull",             menu.use_lb_pull,               "eax_enh_lbpull_cp")
            add_cb("[EAX Enh] Ghost Wolf",          menu.use_ghost_wolf,            "eax_enh_gw_cp")
            add_cb("[EAX Enh] Focus Priority",      menu.focus_priority,            "eax_enh_focus_cp")
            add_cb("[EAX Enh] Use Racial",          menu.use_racial,                "eax_enh_racial_cp")
        end
        return elements
    end)
end



-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Shaman"
    local _eax_spec  = "Enhancement"
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
        local now = core.time()
        if (now - _conflict_last_warn) < 10 then return end
        _conflict_last_warn = now
        local names = table.concat(enabled_specs, " + ")
        core.log("[EAX WARNING] Multiple " .. _eax_class .. " specs enabled: "
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

core.log("[EAX Shaman Enhancement] Loaded")
