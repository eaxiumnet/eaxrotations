-- main.lua
-- EAX Shaman Restoration | TBC 2.4.3 - Full autonomous healer
--
-- Covers: healing, mana management, totems, dispels, weapon buff,
-- auto-attack, drinking, mana potions, reincarnation, DPS filler,
-- pre-pull prep, OOC recovery. Supports leveling 1-70, dungeons, raids.
--
-- In-combat priority:
--  1. Reincarnation          (auto self-rez when dead)
--  2. Nature's Swiftness+HW  (emergency tank save, off-GCD)
--  3. Mana Potion            (combat mana emergency)
--  4. Earth Shield on tank   (always up)
--  5. Bloodlust / Heroism    (on execute or pull)
--  6. Proactive Mana Tide    (before going OOM)
--  7. Chain Heal             (main AoE filler)
--  8. Healing Wave on tank   (single target tank)
--  9. Dispels                (Cure Poison > Cure Disease)
-- 10. Lesser Healing Wave    (fast single target fill)
-- 11. Totems                 (end of list - never steal a heal GCD)
-- 12. PvP utilities
-- 13. DPS filler             (Earth Shock interrupt > CL > LB)
--
-- Always-on (no GCD gate):
--  - Water Shield upkeep
--  - Flametongue Weapon upkeep
--  - Auto-attack management
--  - OOC: drink, self-heal, prepull totems, totemic recall

require("common/wow_api_clone")  -- exposes GetWeaponEnchantInfo for temp enchant detection
local menu   = require("menu")
local spells = require("spells")
local utils  = require("utils")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("encounter_manager")


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("sresto", "Shaman Resto")
---@type color
local color = require("color")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type mana_conservator
local mana_conservator = require("mana_conservator")

---@type key_helper
---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type unit_helper
local unit_helper = require("common/utility/unit_helper")
---@type circle
local circle = require("common/geometry/circle")
local heal_engine = require("heal_engine")
---@type eax_utils
local eax_utils = require("eax_utils")
---@type auto_attack_helper
local auto_attack_helper = require("common/utility/auto_attack_helper")

---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")

-- --- Constants ---------------------------------------------------------------

local GCD_INTERVAL           = 1.5  -- actual TBC GCD duration
local MODE_REFRESH_INTERVAL  = 4.5
local PENDING_CAST_TIMEOUT_S = 2.5
local TOTEMIC_RECALL_CD      = 120.0
local NS_COOLDOWN_MIN        = 3.0
local PREPULL_ENEMY_RANGE    = 50.0
local BLOODLUST_CD           = 600.0   -- 10 min

-- Flametongue Weapon: mainhand slot 16, offhand slot 17
-- Duration 30 min. item_enchant_expiration() returns seconds until expiry.
local MAINHAND_SLOT = 16
local FT_REFRESH_S  = 60.0  -- re-apply when < 60 seconds remain

-- Drinking: buff 430 ("Drink" generic channel). Moving cancels it.
-- Only drink when fully OOC, not moving.
local DRINK_BUFF_ID = { 430, 2639, 1133, 10250, 22734, 27089, 29007 }

-- TBC mana potion item IDs (highest rank first - inventory_helper finds whichever we have)
local MANA_POTION_IDS = { 33447, 22832, 13444, 6149, 3827 }
-- Super Mana Potion=22832, Major=13444, Greater=6149, Mana=3827, Fel Mana=33447

-- Reincarnation: self-rez spell when dead
local REINCARNATION_ID = 21169

-- TBC dispel buff_type enum (Sylvanas): DISEASE=3, POISON=4
local CURE_DISEASE_TYPE = 3
local CURE_POISON_TYPE  = 4

-- Sated / Exhaustion debuff IDs (prevent double-lusting)
local SATED_IDS = { 57724, 57723 }

local MODE_PROFILE = {
    solo    = { enable_dps = true,  mana_floor = 20, heal_party_hp = 70, heal_tank_hp = 75, chain_heal_targets = 2 },
    dungeon = { enable_dps = true,  mana_floor = 25, heal_party_hp = 78, heal_tank_hp = 82, chain_heal_targets = 3 },
    raid    = { enable_dps = false, mana_floor = 30, heal_party_hp = 82, heal_tank_hp = 88, chain_heal_targets = 4 },
}

-- --- Runtime state -----------------------------------------------------------

local rt = {
    -- Healing
    chain_heal_id          = nil,
    healing_wave_id        = nil,
    lesser_healing_wave_id = nil,
    earth_shield_id        = nil,
    water_shield_id        = nil,
    nature_s_swift_id      = nil,
    -- Totems
    mana_tide_id           = nil,
    healing_stream_id      = nil,
    totem_of_wrath_id      = nil,
    wrath_of_air_id        = nil,
    grounding_totem_id     = nil,
    tremor_totem_id        = nil,
    totemic_recall_id      = nil,
    -- Dispels
    cure_poison_id         = nil,
    cure_disease_id        = nil,
    purge_id               = nil,
    -- DPS
    chain_lightning_id     = nil,
    lightning_bolt_id      = nil,
    wind_shear_id          = nil,
    earth_shock_id         = nil,
    -- DPS cooldowns
    last_dps_at            = 0,
    -- Cooldowns
    bloodlust_id           = nil,
    heroism_id             = nil,
    -- Weapon buff
    flametongue_id         = nil,
    last_flametongue_at    = 0,  -- core.time() when last cast
    -- Timing
    last_cast_time         = 0,
    last_ns_at             = 0,
    last_totemic_recall_at = 0,
    last_bloodlust_at      = 0,
    last_prepull_totem_at  = 0,
    last_drink_attempt_at  = 0,
    last_potion_at         = 0,
    totem_last_apply       = {},
    -- State
    prev_toggle_state      = false,
    cached_mode            = "solo",
    pending_casts          = {},
    set_multiplier         = 1.0,
}

-- --- Totem table -------------------------------------------------------------

local TOTEM_ROTATION = nil
local function build_totem_rotation()
    TOTEM_ROTATION = {
        { name = "mana_tide",      id_field = "mana_tide_id",      toggle = menu.auto_totem_mana_tide,      label = "Mana Tide Totem",      cooldown = 300 },
        { name = "healing_stream", id_field = "healing_stream_id", toggle = menu.auto_totem_healing_stream, label = "Healing Stream Totem", cooldown = 30  },
        { name = "totem_of_wrath", id_field = "totem_of_wrath_id", toggle = menu.auto_totem_wrath,          label = "Totem of Wrath",       cooldown = 120 },
        { name = "wrath_of_air",   id_field = "wrath_of_air_id",   toggle = menu.auto_totem_wrath_of_air,   label = "Wrath of Air Totem",   cooldown = 120 },
    }
end

-- --- Spell resolution --------------------------------------------------------

local function resolve_spells()
    rt.chain_heal_id          = utils.resolve_spell_id(spells.CHAIN_HEAL)
    rt.healing_wave_id        = utils.resolve_spell_id(spells.HEALING_WAVE)
    rt.lesser_healing_wave_id = utils.resolve_spell_id(spells.LESSER_HEALING_WAVE)
    rt.earth_shield_id        = utils.resolve_spell_id(spells.EARTH_SHIELD)
    rt.water_shield_id        = utils.resolve_spell_id(spells.WATER_SHIELD)
    rt.nature_s_swift_id      = utils.resolve_spell_id(spells.NATURES_SWIFTNESS)
    rt.mana_tide_id           = utils.resolve_spell_id(spells.MANA_TIDE_TOTEM)
    rt.healing_stream_id      = utils.resolve_spell_id(spells.HEALING_STREAM_TOTEM)
    rt.totem_of_wrath_id      = utils.resolve_spell_id(spells.TOTEM_OF_WRATH)
    rt.wrath_of_air_id        = utils.resolve_spell_id(spells.WRATH_OF_AIR_TOTEM)
    rt.grounding_totem_id     = utils.resolve_spell_id(spells.GROUNDING_TOTEM)
    rt.tremor_totem_id        = utils.resolve_spell_id(spells.TREMOR_TOTEM)
    rt.totemic_recall_id      = utils.resolve_spell_id(spells.TOTEMIC_RECALL)
    rt.cure_poison_id         = utils.resolve_spell_id(spells.CURE_POISON)
    rt.cure_disease_id        = utils.resolve_spell_id(spells.CURE_DISEASE)
    rt.purge_id               = utils.resolve_spell_id(spells.PURGE)
    rt.chain_lightning_id     = utils.resolve_spell_id(spells.CHAIN_LIGHTNING)
    rt.lightning_bolt_id      = utils.resolve_spell_id(spells.LIGHTNING_BOLT)
    rt.wind_shear_id          = utils.resolve_spell_id(spells.WINDSHEAR)
    rt.earth_shock_id         = utils.resolve_spell_id(spells.EARTH_SHOCK)
    rt.bloodlust_id           = utils.resolve_spell_id(spells.BLOODLUST)
    rt.heroism_id             = utils.resolve_spell_id(spells.HEROISM)
    rt.flametongue_id         = utils.resolve_spell_id(spells.FLAMETONGUE_WEAPON)
end

local function update_set_bonus()
    local me = core.object_manager.get_local_player()
    if not me then return end
    
    local cyclone_mult = utils.get_set_multiplier(me, "Cyclone")
    local cataclysm_mult = utils.get_set_multiplier(me, "Cataclysm")
    local skyshatter_mult = utils.get_set_multiplier(me, "Skyshatter")
    
    rt.set_multiplier = cyclone_mult
    if cataclysm_mult > rt.set_multiplier then
        rt.set_multiplier = cataclysm_mult
    end
    if skyshatter_mult > rt.set_multiplier then
        rt.set_multiplier = skyshatter_mult
    end
    
    if rt.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(rt.set_multiplier))
    end
end

-- --- Mode detection ----------------------------------------------------------

local function detect_mode(me)
    local allies = unit_helper:get_ally_list_around(me:get_position(), 100.0, true, true)
    local n = #allies
    if n == 0 then return "solo"
    elseif n <= 4 then return "dungeon"
    else return "raid" end
end

local function get_effective_mode()
    local sel = menu.mode:get()
    if sel == 2 then return "solo" end
    if sel == 3 then return "dungeon" end
    if sel == 4 then return "raid" end
    return rt.cached_mode
end

local function get_mode_profile()
    return MODE_PROFILE[get_effective_mode()] or MODE_PROFILE.solo
end

-- --- Pending cast tracking ---------------------------------------------------

local function mark_pending(spell_id, timeout_s)
    if not spell_id then return end
    rt.pending_casts[spell_id] = { requested_at = core.time(), timeout_s = timeout_s or PENDING_CAST_TIMEOUT_S }
end

local function is_pending(spell_id)
    if not spell_id then return false end
    local p = rt.pending_casts[spell_id]
    if not p then return false end
    if (core.time() - p.requested_at) >= p.timeout_s then
        rt.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function note_cast()
    rt.last_cast_time = core.time()
end

-- --- GCD check ---------------------------------------------------------------

local function is_gcd_ready()
    if (core.time() - rt.last_cast_time) < GCD_INTERVAL then return false end
    return core.spell_book.get_global_cooldown() <= 0
end

-- --- Cast wrappers -----------------------------------------------------------

local function try_cast_ally(me, target, spell_id, label)
    if not spell_id or not target or not target:is_valid() or target:is_dead() then return false end
    if is_pending(spell_id) then return false end
    if not utils.cast_target(spell_id, me, target) then return false end
    mark_pending(spell_id)
    note_cast()
    local target_name = target:get_name() or "?"
    esp_renderer.on_cast(spell_id, label, color.green(220), target_name)
    utils.log_debug(menu, label .. " -> " .. target_name)
    return true
end

local function try_cast_self(me, spell_id, label)
    if not spell_id or not me or not me:is_valid() then return false end
    if is_pending(spell_id) then return false end
    if not utils.cast_self(spell_id, me) then return false end
    mark_pending(spell_id)
    note_cast()
    esp_renderer.on_cast(spell_id, label, color.green(220), "Self")
    utils.log_debug(menu, label .. " (self)")
    return true
end

local function try_cast_self_fast(me, spell_id, label)
    if not spell_id or not me or not me:is_valid() then return false end
    if is_pending(spell_id) then return false end
    if not utils.cast_self_fast(spell_id, me) then return false end
    mark_pending(spell_id, 0.5)
    esp_renderer.on_cast(spell_id, label, color.green(220), "Self")
    utils.log_debug(menu, label .. " (off-GCD)")
    return true
end

local function try_cast_hostile(me, target, spell_id, label)
    if not spell_id or not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.is_valid_hostile(me, target) then return false end
    if is_pending(spell_id) then return false end
    if not utils.cast_target(spell_id, me, target) then return false end
    mark_pending(spell_id)
    note_cast()
    local target_name = target:get_name() or "?"
    esp_renderer.on_cast(spell_id, label, color.red(220), target_name)
    utils.log_debug(menu, label .. " (hostile)")
    return true
end

-- --- Reincarnation (auto self-rez) -------------------------------------------
-- Fires immediately when we are dead and the ankh CD is ready.
-- This runs before do_rotation since we need it even when "dead".

local function try_reincarnation(me)
    if not menu.use_reincarnation:get_state() then return false end
    if not me:is_dead() then return false end
    if not core.spell_book.is_spell_learned(REINCARNATION_ID) then return false end
    if core.spell_book.get_spell_cooldown(REINCARNATION_ID) > 0 then return false end
    -- Cast the self-rez directly (no GCD, no target needed)
    if core.spell_book.is_usable_spell(REINCARNATION_ID) then
        spell_queue:queue_spell_target(REINCARNATION_ID, me, 1)
        utils.log_debug(menu, "Reincarnation")
        return true
    end
    return false
end

-- --- Water Shield ------------------------------------------------------------

local function ensure_water_shield(me)
    if not menu.use_water_shield:get_state() then return false end
    if not rt.water_shield_id then return false end
    if utils.has_buff(me, spells.WATER_SHIELD_BUFF) then return false end
    -- Earth Shield shares the weapon-imbue slot - never overwrite it
    if utils.has_buff(me, spells.EARTH_SHIELD_BUFF) then return false end
    return try_cast_self(me, rt.water_shield_id, "Water Shield")
end

-- --- Flametongue Weapon ------------------------------------------------------
-- TBC Resto mainhand buff. Provides spell power scaling.
-- Uses item_enchant_expiration() to check remaining duration.
-- Applies when: missing, or under FT_REFRESH_S seconds remain.

local FT_REFRESH_REMAINING_MS = 60 * 1000   -- reapply when < 60 sec remain
local FT_DURATION_S           = 29 * 60     -- 30 min imbue; fallback timer

local function ensure_flametongue(me)
    if not menu.use_flametongue:get_state() then return false end
    if not rt.flametongue_id then return false end
    if is_pending(rt.flametongue_id) then return false end
    -- Primary: GetWeaponEnchantInfo detects temporary weapon enchants
    local hasMain, mainExpMs = GetWeaponEnchantInfo()
    if hasMain == true then
        -- API working: check remaining time
        if mainExpMs and mainExpMs > FT_REFRESH_REMAINING_MS then return false end
    else
        -- Fallback: time-based tracking (in case GetWeaponEnchantInfo is not implemented)
        if (core.time() - rt.last_flametongue_at) < FT_DURATION_S then return false end
    end
    if try_cast_self(me, rt.flametongue_id, "Flametongue Weapon") then
        rt.last_flametongue_at = core.time()
        return true
    end
    return false
end

-- --- Auto-attack -------------------------------------------------------------
-- Start melee auto-attacks when we have a hostile target in melee range.
-- Uses auto_attack_helper - doesn't consume a GCD.

local function ensure_auto_attack(me)
    if not menu.use_auto_attack:get_state() then return end
    if not me:is_in_combat() then return end
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then return end
    if not utils.is_valid_hostile(me, target) then return end
    
    local dist = me:get_position():dist_to(target:get_position())
    local reach = 5.0 + (target:get_bounding_radius() or 0)
    if dist > reach then return end
    
    -- Always show Basic Attack in HUD when in melee range
    local target_name = target:get_name()
    if target_name then
        esp_renderer.on_cast(6603, "Basic Attack", color.yellow(220), target_name)
    end
    
    -- Start attacking if not already
    if not auto_attack_helper:is_auto_attacking(me) then
        auto_attack_helper:start_attack(target, auto_attack_helper.ATTACK_TYPE.MELEE)
    end
end

-- --- Drinking OOC ------------------------------------------------------------
-- Use a drink from bags when OOC, below the mana threshold, not moving,
-- and not already drinking.

local function try_drink(me)
    if not menu.use_drink:get_state() then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    -- Already drinking? (generic drink channel buff)
    if utils.has_buff(me, DRINK_BUFF_ID) then return false end
    local threshold = menu.drink_mana_pct:get() / 100.0
    if utils.get_mana_pct(me) >= threshold then return false end
    -- HP must be full enough that we don't need to self-heal instead
    if utils.get_health_pct(me) < 0.50 then return false end
    local now = core.time()
    if (now - rt.last_drink_attempt_at) < 3.0 then return false end
    rt.last_drink_attempt_at = now
    -- Find a drink in bags using inventory consumables
    -- We scan for a food_or_drink item and use it
    local inv = require("common/utility/inventory_helper")
    inv:update_consumables_list()
    local consumables = inv:get_current_consumables_list()
    for _, c in ipairs(consumables) do
        if c.is_food_or_drink and c.item then
            local item_id = c.item:get_item_id()
            if item_id and item_id > 0 then
                local cd = me:get_item_cooldown(item_id)
                if cd <= 0 then
                    if core.input.use_item(item_id) then
                        utils.log_debug(menu, "Drinking (item " .. tostring(item_id) .. ")")
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- --- Mana Potion -------------------------------------------------------------
-- Use highest-rank mana potion available when in-combat mana is critically low.
-- Potions share a 2-min cooldown in TBC (item cooldown, not spell CD).

local function try_mana_potion(me)
    if not menu.use_mana_potion:get_state() then return false end
    if not me:is_in_combat() then return false end
    local threshold = menu.mana_potion_pct:get() / 100.0
    if utils.get_mana_pct(me) >= threshold then return false end
    local now = core.time()
    if (now - rt.last_potion_at) < 120.0 then return false end
    for _, item_id in ipairs(MANA_POTION_IDS) do
        local cd = me:get_item_cooldown(item_id)
        if cd <= 0 then
            -- Check we actually have it
            local found = false
            for bag = 0, 4 do
                local items = core.inventory.get_items_in_bag(bag)
                for _, item in ipairs(items) do
                    if item and item:get_item_id() == item_id then
                        found = true
                        break
                    end
                end
                if found then break end
            end
            if found then
                if core.input.use_item(item_id) then
                    rt.last_potion_at = now
                    utils.log_debug(menu, "Mana Potion (" .. tostring(item_id) .. ")")
                    return true
                end
            end
        end
    end
    return false
end

-- --- Totemic Recall ----------------------------------------------------------

local function try_totemic_recall(me)
    if not menu.use_totemic_recall:get_state() then return false end
    if not rt.totemic_recall_id then return false end
    if me:is_in_combat() then return false end
    local now = core.time()
    if (now - rt.last_totemic_recall_at) < TOTEMIC_RECALL_CD then return false end
    for i = 1, 4 do
        local totem = core.spell_book.get_totem_info(i)
        if totem and totem.have_totem then
            if utils.cast_self(rt.totemic_recall_id, me) then
                rt.last_totemic_recall_at = now
                return true
            end
            return false
        end
    end
    return false
end

-- --- Totem placement ---------------------------------------------------------
-- Checks both the spell cooldown AND the actual in-game totem slot.
-- get_totem_info(slot) returns have_totem=false if the totem was destroyed early
-- (AoE, PvP, mob proximity), so we catch that and re-place immediately.
-- Slot mapping: 1=Fire, 2=Earth, 3=Water, 4=Air

local TOTEM_SLOTS = {
    mana_tide      = 3,   -- Water slot
    healing_stream = 3,   -- Water slot
    totem_of_wrath = 1,   -- Fire slot
    wrath_of_air   = 4,   -- Air slot
}

local function ensure_totems(me)
    if not menu.auto_totems:get_state() then return end
    if not TOTEM_ROTATION then return end
    local now = core.time()
    for _, entry in ipairs(TOTEM_ROTATION) do
        if entry.toggle and entry.toggle:get_state() then
            local spell_id = rt[entry.id_field]
            if spell_id then
                local cd = core.spell_book.get_spell_cooldown(spell_id)
                if cd <= 0 then
                    local last = rt.totem_last_apply[entry.name] or 0
                    local slot = TOTEM_SLOTS[entry.name]
                    -- Check if totem was destroyed (slot empty before timer expired)
                    local slot_empty = false
                    if slot then
                        local info = core.spell_book.get_totem_info(slot)
                        slot_empty = not (info and info.have_totem)
                    end
                    local timer_expired = (now - last) >= (entry.cooldown or 30)
                    if timer_expired or slot_empty then
                        if try_cast_self(me, spell_id, entry.label) then
                            rt.totem_last_apply[entry.name] = now
                            return  -- one totem per pass
                        end
                    end
                end
            end
        end
    end
end

-- --- Pre-pull totems ---------------------------------------------------------

local function try_prepull_totems(me)
    if not menu.prepull_totems:get_state() then return false end
    if me:is_in_combat() then return false end
    local now = core.time()
    if (now - rt.last_prepull_totem_at) < 5.0 then return false end
    local enemies = unit_helper:get_enemy_list_around(me:get_position(), PREPULL_ENEMY_RANGE, false)
    if not enemies or #enemies == 0 then return false end
    local placed = false
    local candidates = {
        { name = "healing_stream", id = rt.healing_stream_id, label = "Healing Stream (pre-pull)", cd = 30  },
        { name = "totem_of_wrath", id = rt.totem_of_wrath_id, label = "Totem of Wrath (pre-pull)", cd = 120 },
    }
    for _, c in ipairs(candidates) do
        if c.id then
            local slot  = TOTEM_SLOTS[c.name]
            local empty = true
            if slot then
                local info = core.spell_book.get_totem_info(slot)
                empty = not (info and info.have_totem)
            end
            local last = rt.totem_last_apply[c.name] or 0
            if empty and (now - last) >= c.cd then
                if try_cast_self(me, c.id, c.label) then
                    rt.totem_last_apply[c.name] = now
                    rt.last_prepull_totem_at = now
                    placed = true
                    break
                end
            end
        end
    end
    return placed
end

-- --- OOC self-heal -----------------------------------------------------------

local function try_ooc_self_heal(me)
    if not menu.ooc_self_heal:get_state() then return false end
    if me:is_in_combat() then return false end
    if not is_gcd_ready() then return false end
    if utils.get_health_pct(me) >= (menu.ooc_self_hp:get() / 100.0) then return false end
    local spell_id = rt.lesser_healing_wave_id or rt.healing_wave_id
    if not spell_id then return false end
    return try_cast_ally(me, me, spell_id, "OOC Self-heal")
end

-- --- Nature's Swiftness ------------------------------------------------------

local function try_natures_swiftness(me, tank)
    if not menu.use_cooldowns:get_state() then return false end
    if not menu.use_natures_swiftness:get_state() then return false end
    if not rt.nature_s_swift_id or not rt.healing_wave_id then return false end
    if not tank then return false end
    local now = core.time()
    if (now - rt.last_ns_at) < NS_COOLDOWN_MIN then return false end
    if core.spell_book.get_spell_cooldown(rt.nature_s_swift_id) > 0 then return false end
    local emergency = eax_utils.get_self_heal_threshold(me, menu.ns_emergency_hp:get() / 100.0, menu)
    if heal_engine.get_eff_pct(tank) > emergency then return false end
    if not try_cast_self_fast(me, rt.nature_s_swift_id, "Nature's Swiftness") then return false end
    rt.last_ns_at = now
    if utils.cast_target(rt.healing_wave_id, me, tank) then
        mark_pending(rt.healing_wave_id)
        note_cast()
        utils.log_debug(menu, "HW (instant via NS) -> " .. (tank:get_name() or "?"))
    end
    return true
end

-- --- Bloodlust / Heroism -----------------------------------------------------

local function try_bloodlust(me)
    if not menu.use_cooldowns:get_state() then return false end
    if not menu.use_bloodlust:get_state() then return false end
    local spell_id = rt.bloodlust_id or rt.heroism_id
    if not spell_id then return false end
    if is_pending(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    local now = core.time()
    if (now - rt.last_bloodlust_at) < BLOODLUST_CD then return false end
    -- Don't lust if we (or raid) already have Sated/Exhaustion
    if utils.has_buff(me, SATED_IDS) then return false end
    -- Determine if we should lust
    local should_lust = false
    if menu.bloodlust_on_pull:get_state() and me:is_in_combat() then
        should_lust = true
    end
    local target = me:get_target()
    if target and target:is_valid() and not target:is_dead() and me:can_attack(target) then
        local boss_hp = unit_helper:get_health_percentage_inc(target, 3.0)
        if boss_hp <= (menu.bloodlust_hp:get() / 100.0) then should_lust = true end
    end
    if not should_lust then return false end
    if try_cast_self(me, spell_id, "Bloodlust/Heroism") then
        rt.last_bloodlust_at = now
        return true
    end
    return false
end

-- --- Proactive Mana Tide -----------------------------------------------------

local function try_proactive_mana_tide(me)
    if not menu.mana_tide_timing:get_state() then return false end
    if not rt.mana_tide_id then return false end
    if is_pending(rt.mana_tide_id) then return false end
    if core.spell_book.get_spell_cooldown(rt.mana_tide_id) > 0 then return false end
    local threshold = menu.mana_tide_mana_pct:get() / 100.0
    if utils.get_mana_pct(me) > threshold then return false end
    if utils.get_mana_pct(me) > 0.40 then
        if not eax_utils.should_use_mana_tide(me, menu) then return false end
    end
    if try_cast_self(me, rt.mana_tide_id, "Mana Tide (proactive)") then
        rt.totem_last_apply["mana_tide"] = core.time()
        return true
    end
    return false
end

-- --- Earth Shield ------------------------------------------------------------

local function try_earth_shield(me, tank)
    if not rt.earth_shield_id or not tank then return false end
    if tank == me then return false end
    if utils.has_buff(tank, spells.EARTH_SHIELD_BUFF) then return false end
    return try_cast_ally(me, tank, rt.earth_shield_id, "Earth Shield")
end

-- --- Chain Heal --------------------------------------------------------------

local function score_chain_heal_candidate(entry, party_threshold)
    local bounce_circle = circle:create(entry.pos, spells.CHAIN_HEAL_JUMP_RANGE)
    local nearby = bounce_circle:get_allies_inside()
    local score = 0
    for _, ally in ipairs(nearby) do
        if ally and ally:is_valid() and not ally:is_dead() then
            local eff = heal_engine.get_eff_pct(ally)
            if eff <= party_threshold then
                local weight = (eff < 0.30) and 1.5 or 1.0
                score = score + weight * (1.0 - eff) * 100
            end
        end
    end
    return score
end

local function try_chain_heal(me)
    if not rt.chain_heal_id then return false end
    local profile = get_mode_profile()
    local party_threshold = math.min(menu.heal_party_hp:get(), profile.heal_party_hp) / 100.0
    local min_targets     = math.min(menu.chain_heal_targets:get(), profile.chain_heal_targets)
    local mana_floor      = math.max(menu.mana_floor:get(), profile.mana_floor) / 100.0
    if heal_engine.count_below(party_threshold) < min_targets then return false end
    if utils.get_mana_pct(me) < mana_floor then return false end
    local best_target, best_score = nil, 0
    for _, entry in ipairs(heal_engine.friends) do
        if entry.eff_pct > party_threshold then break end
        local score = score_chain_heal_candidate(entry, party_threshold)
        if score > best_score then best_score = score; best_target = entry.unit end
    end
    if not best_target then return false end
    return try_cast_ally(me, best_target, rt.chain_heal_id, "Chain Heal")
end

-- --- Healing Wave ------------------------------------------------------------

local function try_healing_wave(me, tank)
    if not rt.healing_wave_id or not tank then return false end
    local profile = get_mode_profile()
    local tank_threshold = math.min(menu.heal_tank_hp:get(), profile.heal_tank_hp) / 100.0
    if heal_engine.get_eff_pct(tank) > tank_threshold then return false end
    return try_cast_ally(me, tank, rt.healing_wave_id, "Healing Wave")
end

-- --- Dispels -----------------------------------------------------------------

local function try_dispel(me)
    if not menu.use_dispels:get_state() then return false end
    local emergency = menu.heal_emergency_hp:get() / 100.0
    local best_target, best_eff, best_spell, best_label = nil, 1.0, nil, nil
    for _, entry in ipairs(heal_engine.friends) do
        local ally = entry.unit
        if ally and ally:is_valid() and not ally:is_dead() and entry.eff_pct >= emergency then
            local debuffs = ally:get_debuffs()
            if debuffs then
                for _, d in ipairs(debuffs) do
                    local sid, lbl
                    if d.type == CURE_POISON_TYPE  and rt.cure_poison_id  then sid = rt.cure_poison_id;  lbl = "Cure Poison"  end
                    if d.type == CURE_DISEASE_TYPE and rt.cure_disease_id then sid = rt.cure_disease_id; lbl = "Cure Disease" end
                    if sid and not is_pending(sid) and entry.eff_pct < best_eff then
                        best_eff = entry.eff_pct; best_target = ally; best_spell = sid; best_label = lbl
                        break
                    end
                end
            end
        end
    end
    if best_target then return try_cast_ally(me, best_target, best_spell, best_label) end
    return false
end

-- --- Lesser Healing Wave -----------------------------------------------------

local function try_lesser_healing_wave(me)
    if not rt.lesser_healing_wave_id then return false end
    local threshold = menu.heal_party_hp:get() / 100.0
    local entry = heal_engine.friends[1]
    if not entry or entry.eff_pct > threshold then return false end
    return try_cast_ally(me, entry.unit, rt.lesser_healing_wave_id, "Lesser Healing Wave")
end

-- --- PvP utilities -----------------------------------------------------------

local function try_pvp_utilities(me)
    if not menu.pvp_mode:get_state() then return false end
    if menu.pvp_use_grounding:get_state() and rt.grounding_totem_id then
        local cd = core.spell_book.get_spell_cooldown(rt.grounding_totem_id)
        local last = rt.totem_last_apply["grounding"] or 0
        if cd <= 0 and (core.time() - last) >= 15 then
            if try_cast_self(me, rt.grounding_totem_id, "Grounding Totem") then
                rt.totem_last_apply["grounding"] = core.time();         esp_renderer.on_cast(nil, "Chain Heal", color.green(220))
                esp_renderer.on_cast(nil, "Healing Wave", color.cyan(220))
        return true
            end
        end
    end
    if menu.pvp_use_tremor:get_state() and rt.tremor_totem_id then
        local FEAR_IDS = { 5782, 8983, 8122, 5484, 20511 }
        for _, entry in ipairs(heal_engine.friends) do
            for _, fid in ipairs(FEAR_IDS) do
                local d = entry.buff_manager:get_debuff_data(unit, { fid })
                if d and d.is_active then
                    local last = rt.totem_last_apply["tremor"] or 0
                    if (core.time() - last) >= 30 then
                        if try_cast_self(me, rt.tremor_totem_id, "Tremor Totem") then
                            rt.totem_last_apply["tremor"] = core.time(); return true
                        end
                    end
                    break
                end
            end
        end
    end
    if menu.pvp_use_purge:get_state() and rt.purge_id then
        local target = me:get_target()
        if target and target:is_valid() and not target:is_dead() and utils.is_valid_hostile(me, target) then
            local buffs = target:get_buffs()
            if buffs and #buffs > 0 then return try_cast_hostile(me, target, rt.purge_id, "Purge") end
        end
    end
    return false
end

-- --- DPS filler --------------------------------------------------------------
local DPS_COOLDOWN_S = 1.5  -- Minimum time between DPS casts

local function try_dps_filler(me, target)
    local profile = get_mode_profile()
    if not menu.enable_dps:get_state() then return false end
    if not menu.use_dps_filler:get_state() then return false end
    if not profile.enable_dps then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.is_valid_hostile(me, target) then return false end
    if utils.get_mana_pct(me) < (math.max(menu.mana_floor:get(), profile.mana_floor) / 100.0) then return false end
    
    -- Cooldown check - prevent spam
    local now = core.time()
    if (now - rt.last_dps_at) < DPS_COOLDOWN_S then return false end
    
    -- Earth Shock: interrupt on cast
    if menu.use_interrupt:get_state() and rt.earth_shock_id then
        if target:is_casting_spell() then
            if try_cast_hostile(me, target, rt.earth_shock_id, "Earth Shock (interrupt)") then 
                rt.last_dps_at = now
                return true 
            end
        end
    end
    -- Purge
    if menu.use_purge:get_state() and rt.purge_id then
        local buffs = target:get_buffs()
        if buffs and #buffs > 0 then
            if try_cast_hostile(me, target, rt.purge_id, "Purge") then 
                rt.last_dps_at = now
                return true 
            end
        end
    end
    -- AoE vs single target
    local near = unit_helper:get_enemy_list_around(me:get_position(), 12.0, true)
    local n = near and #near or 0
    if n >= 3 and rt.chain_lightning_id then
        if try_cast_hostile(me, target, rt.chain_lightning_id, "Chain Lightning") then 
            rt.last_dps_at = now
            return true 
        end
    end
    if rt.lightning_bolt_id then
        if try_cast_hostile(me, target, rt.lightning_bolt_id, "Lightning Bolt") then 
            rt.last_dps_at = now
            return true 
        end
    end
    if rt.chain_lightning_id then
        if try_cast_hostile(me, target, rt.chain_lightning_id, "Chain Lightning") then 
            rt.last_dps_at = now
            return true 
        end
    end
    return false
end

-- --- Main rotation -----------------------------------------------------------

local function do_rotation(me)
    -- Lazy re-resolve: spells may not be learned yet at plugin load time
    if not rt.chain_heal_id then resolve_spells() end
    -- -- Always-on (no GCD) ------------------------------------------------
    ensure_water_shield(me)
    ensure_flametongue(me)
    ensure_auto_attack(me)
    try_totemic_recall(me)

    -- -- Dead path ---------------------------------------------------------
    if me:is_dead() then
        try_reincarnation(me)
        return
    end

    -- -- OOC path ----------------------------------------------------------
    if not me:is_in_combat() then
        try_drink(me)
        try_prepull_totems(me)
        try_ooc_self_heal(me)
        return
    end

    -- -- Overheal protection -----------------------------------------------
    if eax_utils.should_stopcasting(me, menu) then
        if SpellStopCasting then SpellStopCasting() end
    end

    -- -- heal_engine update ------------------------------------------------
    heal_engine.update(me)

    -- -- Mana potion (no GCD) ----------------------------------------------
    try_mana_potion(me)

    if not is_gcd_ready() then return end

    -- -- Interrupt (PVP) -------------------------------------------------------
    local target = me:get_target()
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "shaman", utils) then
            return
        end
    end

    -- -- Defensive abilities -------------------------------------------------
    if defensive_manager.try_defensive(me, "shaman", utils) then
        return
    end

    ttd_tracker.update(target)

    -- -- Focus target priority ---------------------------------------------
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target then
        local fhp = heal_engine.get_eff_pct(focus_target)
        if fhp < (menu.heal_tank_hp:get() / 100.0) then
            local fs = rt.lesser_healing_wave_id or rt.healing_wave_id
            if try_cast_ally(me, focus_target, fs, "Focus Heal") then return end
        end
    end

    -- -- Self emergency ----------------------------------------------------
    local self_thr = eax_utils.get_self_heal_threshold(me, menu.ns_emergency_hp:get() / 100.0, menu)
    if heal_engine.get_eff_pct(me) < self_thr then
        if try_cast_ally(me, me, rt.healing_wave_id, "Self Heal (emergency)") then return end
    end

    local tank = heal_engine.lowest_tank()

    -- 1. Nature's Swiftness + instant HW
    if try_natures_swiftness(me, tank) then return end
    -- 2. Earth Shield on tank
    if try_earth_shield(me, tank) then return end
    -- 3. Bloodlust / Heroism
    if try_bloodlust(me) then return end
    -- 4. Proactive Mana Tide
    if try_proactive_mana_tide(me) then return end
    -- 5. Chain Heal
    if try_chain_heal(me) then return end
    -- 6. Healing Wave on tank
    if try_healing_wave(me, tank) then return end
    -- 7. Dispels
    if try_dispel(me) then return end
    -- 8. Lesser Healing Wave
    if try_lesser_healing_wave(me) then return end
    -- 9. Totems (last - never steal a heal GCD)
    ensure_totems(me)
    -- 10. PvP
    if try_pvp_utilities(me) then return end
    -- 11. DPS filler
    try_dps_filler(me, me:get_target())
end

-- --- Toggle ------------------------------------------------------------------

local function detect_toggle()
    local current = menu.toggle_key:get_state()
    if current and not rt.prev_toggle_state then
        local enabled = menu.enabled:get_state()
        menu.enabled:set(not enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not enabled))
    end
    rt.prev_toggle_state = current
end

-- --- Boot --------------------------------------------------------------------

---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

resolve_spells()
build_totem_rotation()


-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Shaman"
    local _eax_spec  = "Restoration"
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

core.log("[EAX Shaman Restoration TBC] Loaded")
core.log("  CH=" .. tostring(rt.chain_heal_id)
    .. " HW="   .. tostring(rt.healing_wave_id)
    .. " NS="   .. tostring(rt.nature_s_swift_id)
    .. " ToW="  .. tostring(rt.totem_of_wrath_id)
    .. " FT="   .. tostring(rt.flametongue_id)
    .. " BL="   .. tostring(rt.bloodlust_id or rt.heroism_id))

-- --- Callbacks ---------------------------------------------------------------


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
    local me = core.object_manager.get_local_player()

    if utils.throttle("mode_refresh", MODE_REFRESH_INTERVAL) then
        if me then
            rt.cached_mode = detect_mode(me)
            heal_engine.set_tank_priority(menu.tank_priority_weight:get())
        end
    end

    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end

    if control_panel_utility then control_panel_utility:on_update(menu) end
    detect_toggle()

    if not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        rez_spell_id = rt.ancestral_spirit_id,
    })
    if not me then return end
    if eax_utils.is_eating_or_drinking(me) then return end

    heal_engine.update(me)
    do_rotation(me)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxshamanrestoration_space_win")
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
        local label = "[EAX Shaman Restoration] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        local function add_kb(lbl, kb)
            if not kb then return end
            control_panel_utility:insert_toggle_(elements, lbl, kb, false)
        end
        add_cb(label,                               menu.enabled,            "eax_resto_enabled_cp")
        if menu.enabled:get_state() then
            add_cb("[EAX RSham] Cooldowns",             menu.use_cooldowns,      "eax_resto_cds_cp")
            add_kb("[EAX RSham] Cooldowns Key",         menu.cooldowns_key)
            add_cb("[EAX RSham] Nature's Swiftness",    menu.use_natures_swiftness,"eax_resto_ns_cp")
            add_cb("[EAX RSham] Bloodlust",             menu.use_bloodlust,      "eax_resto_bl_cp")
            add_cb("[EAX RSham] Enable DPS",            menu.enable_dps,         "eax_resto_dps_cp")
            add_kb("[EAX RSham] DPS Key",               menu.dps_key)
            add_cb("[EAX RSham] Dispels",               menu.use_dispels,        "eax_resto_disp_cp")
            add_cb("[EAX RSham] Purge",                 menu.use_purge,          "eax_resto_purge_cp")
            add_cb("[EAX RSham] Interrupt",             menu.use_interrupt,      "eax_resto_int_cp")
            add_cb("[EAX RSham] Focus Priority",        menu.focus_priority,     "eax_resto_focus_cp")
            add_cb("[EAX RSham] Use Racial",            menu.use_racial,         "eax_resto_racial_cp")
        end
        return elements
    end)
end
