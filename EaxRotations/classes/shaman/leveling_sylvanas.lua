-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/shaman/leveling_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Shaman leveling rotation.
-- ============================================================================
-- What: TBC Shaman leveling rotation for solo questing with shields, imbues, totems,
--        Stormstrike (40+), Shamanistic Rage (50+), and smart shield-swapping
-- When: Per tick
-- Why: Leveling needs shared context guards, safe maintenance logic for weak gear states,
--        and Enhancement melee abilities for post-40 efficiency
-- Safety: Context guard required; pcall-safe spell checks; nil-guarded lookups; conservative fallback timers
-- ============================================================================
-- Auto-activates in solo/leveling context or when playstyle = "leveling".
-- Uses shared leveling module for context guard, wand, and common helpers.

local NS = _G.EaxRotations
if not NS then return nil end

local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { shaman = {} } } end
local TBC_SHAMAN = (TBC.SPELLS and TBC.SPELLS.shaman) or {}

-- ============================================================================
-- Module table
-- ============================================================================
local shaman_leveling = {}

-- ============================================================================
-- Context guard
-- ============================================================================
local is_leveling_context = leveling.create_context_guard()

-- ============================================================================
-- Constants
-- ============================================================================
local SPELLS = NS.ShamanSpells or NS.SPELLS or {}
local LIGHTNING_SHIELD_BUFF = TBC_SHAMAN.lightning_shield or { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local WATER_SHIELD_BUFF = TBC_SHAMAN.water_shield or { 33736, 24398, 23575 }
local SHAMANISTIC_RAGE_BUFF = { 30823 }

local MAIN_HAND_SLOT = 16
local OFF_HAND_SLOT = 17 -- for future off-hand support
local TOTEM_SLOT = {
    fire = 1,
    earth = 2,
    water = 3,
    air = 4,
}

local runtime = {}

local IMBUE_PRIORITY_AUTO = {
    SPELLS.WindfuryWeapon,
    SPELLS.RockbiterWeapon,
    SPELLS.FlametongueWeapon,
}

local IMBUE_BY_SETTING = {
    windfury = SPELLS.WindfuryWeapon,
    rockbiter = SPELLS.RockbiterWeapon,
    flametongue = SPELLS.FlametongueWeapon,
    frostbrand = SPELLS.FrostbrandWeapon,
}

-- ============================================================================
-- Strategy helpers
-- ============================================================================

local function now_ms()
    local game_time_ms = NS.game_time_ms
    if type(game_time_ms) == "function" then
        local ok, value = pcall(game_time_ms)
        if ok and type(value) == "number" then return value end
    end
    return ((NS.time_now and NS.time_now()) or 0) * 1000
end

local function get_player()
    return (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
end

local function spell_ready(spell_action, target, opts)
    if not spell_action then return false end
    if not NS.spell_ready then return false end
    local ok, result = pcall(NS.spell_ready, spell_action, target, opts)
    return ok and result == true
end

local function try_cast(spell_action, target, label, opts)
    if not spell_action then return false end
    local ok, result = pcall(NS.try_cast, spell_action, target, label or "", opts)
    return ok and result == true
end

local function has_buff(buff_ids)
    if not buff_ids then return false end
    local me = get_player()
    if not me then return false end
    if NS.buff_up then
        local ok, result = pcall(NS.buff_up, me, buff_ids)
        if ok and result then return true end
    end
    return false
end

local function has_totem(totem_id)
    -- Check if a totem is active by checking for the totem buff
    return has_buff(totem_id)
end

local function safe_debuff_remains(unit, debuff_ids)
    if not unit or not NS.debuff_remains then return 0 end
    local ok, remains = pcall(NS.debuff_remains, unit, debuff_ids)
    if not ok or not remains then return 0 end
    return remains
end

local function get_totem_info(slot)
    return NS.get_totem_info and NS.get_totem_info(slot) or nil
end

local function totem_active(element)
    local info = get_totem_info(TOTEM_SLOT[element])
    if not info then return false end
    return info.have_totem == true
end

local function get_equipped_item(slot)
    local me = get_player()
    if not me or not me.get_item_at_inventory_slot then return nil end
    local ok, item_slot = pcall(function() return me:get_item_at_inventory_slot(slot) end)
    if not ok or type(item_slot) ~= "table" then return nil end
    return item_slot.object or item_slot.item or item_slot[1]
end

local function mainhand_has_imbue()
    local item = get_equipped_item(MAIN_HAND_SLOT)
    if not item then
        if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] mainhand: NO item in slot 16") end
        return false, false
    end
    if item.item_has_enchant then
        local ok, result = pcall(function() return item:item_has_enchant() end)
        local ench_id, ench_exp, ench_charges = "?", "?", "?"
        if ok and result then
            local id_ok, id_v = pcall(function() return item:item_enchant_id() end)
            local ex_ok, ex_v = pcall(function() return item:item_enchant_expiration() end)
            local ch_ok, ch_v = pcall(function() return item:item_enchant_charges() end)
            ench_id = id_ok and tostring(id_v) or "err"
            ench_exp = ex_ok and tostring(ex_v) or "err"
            ench_charges = ch_ok and tostring(ch_v) or "err"
        end
        if NS.get_setting and NS.get_setting("debug_system", false) then
            NS.log("[IMBUEDIAG] mainhand: api_ok=" .. tostring(ok) .. " has_ench=" .. tostring(result) .. " ench_id=" .. ench_id .. " exp=" .. ench_exp .. " charges=" .. ench_charges)
        end
        if ok then return result == true, true end
    else
        if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] mainhand: item_has_enchant API MISSING on item object") end
    end
    return false, false
end

local function select_weapon_imbue(setting)
    local explicit = IMBUE_BY_SETTING[setting or ""]
    if explicit then return explicit end
    for i = 1, #IMBUE_PRIORITY_AUTO do
        local spell = IMBUE_PRIORITY_AUTO[i]
        if spell_ready(spell, get_player(), { skip_range = true }) then return spell end
    end
    return nil
end

local function can_retry_unknown_imbue(state)
    return true
end

local function can_drop_totem(state, element, last_ms)
    if (state.mana_pct or 100) < 20 then return false end
    if totem_active(element) then return false end
    return true
end

-- ============================================================================
-- State builder
-- ============================================================================

function shaman_leveling.build_state(context)
    if not context then return nil end

    local state = {}

    -- Common state
    leveling.build_common_state(context, state)
    state.now_ms = now_ms()

    -- Shaman-specific spell readiness
    local me = get_player()
    state.lightning_bolt_ready = spell_ready(SPELLS.LightningBolt, state.target)
    state.earth_shock_ready = spell_ready(SPELLS.EarthShock, state.target)
    state.flame_shock_ready = spell_ready(SPELLS.FlameShock, state.target)
    state.frost_shock_ready = spell_ready(SPELLS.FrostShock, state.target)
    state.chain_lightning_ready = spell_ready(SPELLS.ChainLightning, state.target)
    state.lightning_shield_ready = spell_ready(SPELLS.LightningShield, me, { skip_range = true })
    state.water_shield_ready = spell_ready(SPELLS.WaterShield, me, { skip_range = true })
    state.stormstrike_ready = spell_ready(SPELLS.Stormstrike, state.target, { expected_cooldown = 10 })
    state.shamanistic_rage_ready = spell_ready(SPELLS.ShamanisticRage, me, { skip_range = true, expected_cooldown = 120 })
    state.healing_wave_ready = spell_ready(SPELLS.HealingWave, me, { skip_range = true })
    state.lesser_healing_wave_ready = spell_ready(SPELLS.LesserHealingWave, me, { skip_range = true })
    state.ghost_wolf_ready = spell_ready(SPELLS.GhostWolf, me, { skip_range = true })
    state.purge_ready = spell_ready(SPELLS.Purge, state.target)
    state.earthbind_totem_ready = spell_ready(SPELLS.EarthbindTotem, me, { skip_range = true })
    state.stoneclaw_totem_ready = SPELLS.StoneclawTotem and spell_ready(SPELLS.StoneclawTotem, me, { skip_range = true }) or false
    state.fire_nova_totem_ready = spell_ready(SPELLS.FireNovaTotem, me, { skip_range = true })
    state.searing_totem_ready = SPELLS.SearingTotem and spell_ready(SPELLS.SearingTotem, me, { skip_range = true }) or false
    state.strength_of_earth_ready = spell_ready(SPELLS.StrengthOfEarthTotem, me, { skip_range = true })
    state.grace_of_air_ready = spell_ready(SPELLS.GraceOfAirTotem, me, { skip_range = true })
    state.mana_spring_ready = spell_ready(SPELLS.ManaSpringTotem, me, { skip_range = true })
    state.healing_stream_ready = SPELLS.HealingStreamTotem and spell_ready(SPELLS.HealingStreamTotem, me, { skip_range = true }) or false
    state.grounding_totem_ready = spell_ready(SPELLS.GroundingTotem, me, { skip_range = true })
    state.windfury_totem_ready = spell_ready(SPELLS.WindfuryTotem, me, { skip_range = true })
    state.tremor_totem_ready = spell_ready(SPELLS.TremorTotem, me, { skip_range = true })
    state.shield_slot = nil  -- Will be set from game query

    -- Buff checks
    state.has_lightning_shield = has_buff(LIGHTNING_SHIELD_BUFF)
    state.has_water_shield = has_buff(WATER_SHIELD_BUFF)
    state.has_shamanistic_rage = has_buff(SHAMANISTIC_RAGE_BUFF)
    -- In melee range check for Stormstrike
    state.in_melee_range = state.target and state.target.get_distance and state.target:get_distance(me) and state.target:get_distance(me) <= 5 or false
    -- Weapon imbue detection — use WeaponImbueManager API instead of direct item probe.
    -- The shared WeaponImbueManager handles both GetWeaponEnchantInfo() and item:item_has_enchant().
    local imbue = NS.WeaponImbueManager
    if imbue and type(imbue.mainhand_has_imbue) == "function" then
        state.has_mainhand_imbue = imbue.mainhand_has_imbue()
        state.weapon_imbue_api_known = true
    else
        state.has_mainhand_imbue, state.weapon_imbue_api_known = mainhand_has_imbue()
    end

    -- Off-hand detection logging (for enhancement dual-wield diagnosis)
    if NS.get_setting and NS.get_setting("debug_system", false) then
        if imbue and type(imbue.offhand_has_imbue) == "function" then
            NS.log("[IMBUEDIAG] offhand: WeaponImbueManager reports has_imbue=" .. tostring(imbue.offhand_has_imbue()))
        else
            local oh_item = get_equipped_item(OFF_HAND_SLOT)
            if oh_item then
                local oh_has, oh_id, oh_exp = "?", "?", "?"
                if oh_item.item_has_enchant then
                    local ok1, r1 = pcall(function() return oh_item:item_has_enchant() end)
                    oh_has = ok1 and tostring(r1) or "err"
                    if ok1 and r1 then
                        local ok2, r2 = pcall(function() return oh_item:item_enchant_id() end)
                        local ok3, r3 = pcall(function() return oh_item:item_enchant_expiration() end)
                        oh_id = ok2 and tostring(r2) or "err"
                        oh_exp = ok3 and tostring(r3) or "err"
                    end
                end
                NS.log("[IMBUEDIAG] offhand: item_exists=true has_enchant=" .. oh_has .. " ench_id=" .. oh_id .. " exp=" .. oh_exp)
            else
                NS.log("[IMBUEDIAG] offhand: NO item in slot 17")
            end
        end
    end

    -- Settings
    local settings = context.settings or {}
    state.wand_threshold = settings.leveling_wand_threshold or 30
    state.heal_hp = settings.leveling_heal_hp or 50
    state.use_shocks = settings.leveling_use_shocks ~= false
    state.default_shock = settings.leveling_default_shock or "flame"  -- "flame", "earth", "frost"
    state.use_weapon_imbue = settings.leveling_use_weapon_imbue ~= false
    state.weapon_imbue = select_weapon_imbue(settings.leveling_weapon_imbue)
    state.use_totems = settings.leveling_use_totems ~= false
    state.use_searing_totem = settings.leveling_use_searing_totem ~= false
    state.use_strength_totem = settings.leveling_use_strength_totem ~= false
    state.use_water_totem = settings.leveling_use_water_totem ~= false
    state.use_stormstrike = settings.leveling_use_stormstrike ~= false
    state.water_shield_mana = settings.leveling_water_shield_mana or 40
    state.shamanistic_rage_mana = settings.leveling_shamanistic_rage_mana or 30

    return state
end

-- ============================================================================
-- Match functions
-- ============================================================================

local function has_enemy_target(context, state)
    if not context then return false end
    return state.in_combat == true or context.has_valid_enemy_target == true
end

--- Main-hand weapon imbue - maintain OOC
local weapon_imbue_matches = function(context, state)
    if not state then
        if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] match: no state") end
        return false
    end
    if state.in_combat then
        if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] match: in_combat=" .. tostring(state.in_combat) .. " -> skip") end
        return false
    end
    if not state.use_weapon_imbue then
        if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] match: use_weapon_imbue=false -> skip") end
        return false
    end
    if not state.weapon_imbue then
        if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] match: no weapon_imbue selected -> skip") end
        return false
    end
    if state.has_mainhand_imbue then
        if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] match: has_mainhand_imbue=true -> already OK, skip") end
        return false
    end
    if not state.weapon_imbue_api_known then
        local retry_ok = can_retry_unknown_imbue(state)
        if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] match: api_known=false retry_ok=" .. tostring(retry_ok) .. " retry_ms=" .. tostring(1500000)) end
        if not retry_ok then return false end
    end
    local ready = spell_ready(state.weapon_imbue, get_player(), { skip_range = true })
    if NS.get_setting and NS.get_setting("debug_system", false) then
        local spell_name = (state.weapon_imbue and state.weapon_imbue.name) or "nil"
        local ids_raw = (state.weapon_imbue and state.weapon_imbue.ids) or nil
        local spell_ids = (ids_raw and type(ids_raw) == "table" and table.concat(ids_raw, ",")) or "nil"
        NS.log("[IMBUEDIAG] match: ready=" .. tostring(ready) .. " spell=" .. tostring(spell_name) .. " ids={" .. spell_ids .. "}")
    end
    return ready
end

--- Lightning Shield - maintain OOC
local lightning_shield_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_lightning_shield then return false end
    if not state.lightning_shield_ready then return false end
    if NS.buff_remains and NS.buff_remains(NS.PLAYER_UNIT, LIGHTNING_SHIELD_BUFF) > 2 then return false end
    return true
end

--- Healing Wave - emergency heal
local healing_wave_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.healing_wave_ready then return false end
    if (state.hp or 100) > state.heal_hp then return false end
    return true
end

--- Earth Shock - interrupt
local earth_shock_interrupt_matches = function(context, state)
    if not state then return false end
    if not state.use_interrupt then return false end
    if not state.earth_shock_ready then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    return ok and casting
end

--- Searing Totem - single target damage assist
local searing_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_totems or not state.use_searing_totem then return false end
    if not state.searing_totem_ready then return false end
    if not state.target then return false end
    return can_drop_totem(state, "fire", 0)
end

--- Strength of Earth Totem - melee leveling support
local strength_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_totems or not state.use_strength_totem then return false end
    if not state.strength_of_earth_ready then return false end
    return can_drop_totem(state, "earth", 0)
end

--- Mana/Healing Stream - water totem sustain
local water_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_totems or not state.use_water_totem then return false end
    if state.mana_spring_ready and (state.mana_pct or 100) <= 85 then
        return can_drop_totem(state, "water", 0)
    end
    if state.healing_stream_ready and (state.hp or 100) <= 85 then
        return can_drop_totem(state, "water", 0)
    end
    return false
end

--- Flame Shock - DoT
local flame_shock_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.flame_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    -- Check if DoT is already up
    local remains = safe_debuff_remains(state.target, SPELLS.FlameShock)
    if remains > 4 then return false end
    if state.default_shock ~= "flame" then return false end
    return true
end

--- Earth Shock - DPS
local earth_shock_dps_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.earth_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    if state.default_shock ~= "earth" then return false end
    return true
end

--- Frost Shock - slow
local frost_shock_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.frost_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    if state.default_shock ~= "frost" then return false end
    return true
end

--- Chain Lightning - AoE (3+ enemies)
local chain_lightning_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.chain_lightning_ready then return false end
    if not state.target then return false end
    if (state.enemies or 0) < 2 then return false end  -- CL on 2+ (splash)
    return true
end

--- Lightning Bolt - primary filler
local lightning_bolt_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.lightning_bolt_ready then return false end
    if not state.target then return false end
    if state.is_moving then return false end
    return true
end

--- Earthbind Totem - kite when overwhelmed
local earthbind_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.earthbind_totem_ready then return false end
    if (state.enemies or 0) < 3 then return false end
    if (state.hp or 100) > 50 then return false end
    return true
end

--- Water Shield - OOC mana sustain (when mana below threshold, swap from Lightning Shield)
local water_shield_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_water_shield then return false end
    if not state.water_shield_ready then return false end
    if (state.mana_pct or 100) > state.water_shield_mana then return false end
    -- Remove Lightning Shield before applying Water Shield (mutually exclusive in TBC)
    return true
end

--- Shamanistic Rage - combat mana recovery (level 50+)
local shamanistic_rage_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if state.has_shamanistic_rage then return false end
    if not state.shamanistic_rage_ready then return false end
    if (state.mana_pct or 100) > state.shamanistic_rage_mana then return false end
    return true
end

--- Stormstrike - melee DPS (level 40+)
local stormstrike_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_stormstrike then return false end
    if not state.stormstrike_ready then return false end
    if not state.target then return false end
    if not state.in_melee_range then return false end
    -- Gate: skip if mana emergency (Shamanistic Rage not learned yet or on CD)
    if (state.mana_pct or 100) < 10 then return false end
    return true
end

--- Lesser Healing Wave - fast cheap heal (leveling priority over big heal)
local lesser_healing_wave_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.lesser_healing_wave_ready then return false end
    if (state.hp or 100) > 40 then return false end
    return true
end

--- Stoneclaw Totem - aggro redirect when overwhelmed
local stoneclaw_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.stoneclaw_totem_ready then return false end
    if (state.enemies or 0) < 3 then return false end
    if (state.hp or 100) > 50 then return false end
    return true
end

--- Grounding Totem - absorb incoming spells (PvP + caster mobs)
local grounding_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.grounding_totem_ready then return false end
    if (state.enemies or 0) < 2 then return false end
    return can_drop_totem(state, "air", 0)
end

--- Tremor Totem - break fear/charm/sleep effects
local tremor_totem_matches = function(context, state)
    if not state then return false end
    if not state.tremor_totem_ready then return false end
    -- Always drop Tremor when in PvP combat (counters fear classes)
    if not state.in_combat then return false end
    return can_drop_totem(state, "earth", 0)
end

--- Purge - dispel 2 magic buffs from enemy
local purge_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.purge_ready then return false end
    if not state.target then return false end
    -- Gate: only purge in PvP or vs buffed mobs (healer/caster type)
    if not state.is_pvp then return false end
    return true
end

--- Ghost Wolf - OOC travel
local ghost_wolf_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.ghost_wolf_ready then return false end
    if not context.target then return false end
    -- Only shift to wolf if target is far
    local dist = NS.get_distance and NS.get_distance(context.target)
    if dist and dist < 20 then return false end
    return true
end

-- ============================================================================
-- Strategies table
-- ============================================================================

local strategies = {
    -- OOC: Weapon imbue
    { name = "WeaponImbue",
      matches = weapon_imbue_matches,
      execute = function(context, state)
          if not state then
              if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] execute: no state -> skip") end
              return false
          end
          local spell_name = (state.weapon_imbue and state.weapon_imbue.name) or "nil"
          local cast_ok = try_cast(state.weapon_imbue, nil, "[LEVELING] Weapon Imbue", { skip_range = true })
          if NS.get_setting and NS.get_setting("debug_system", false) then
              NS.log("[IMBUEDIAG] execute: try_cast(" .. spell_name .. ")=" .. tostring(cast_ok) .. " target=nil")
          end
          if cast_ok then
              return true
          end
          if NS.get_setting and NS.get_setting("debug_system", false) then NS.log("[IMBUEDIAG] execute: try_cast FAILED") end
          return false
      end },

    -- OOC: Lightning Shield
    { name = "LightningShield",
      matches = lightning_shield_matches,
      execute = function(context, state)
          if not state then return false end
          if try_cast(SPELLS.LightningShield, nil, "[LEVELING] Lightning Shield", { skip_range = true }) then
              return true
          end
          return false
      end },

    -- OOC: Water Shield (mana sustain, swaps from Lightning Shield)
    { name = "WaterShield",
      matches = water_shield_matches,
      execute = function(context, state)
          if not state then return false end
          -- Cancel Lightning Shield first (mutually exclusive in TBC)
          if state.has_lightning_shield and NS.cancel_buff then
              pcall(NS.cancel_buff, LIGHTNING_SHIELD_BUFF)
          end
          if try_cast(SPELLS.WaterShield, nil, "[LEVELING] Water Shield", { skip_range = true }) then
              return true
          end
          return false
      end },

    -- Interrupt: Earth Shock
    { name = "EarthShockInterrupt",
      matches = earth_shock_interrupt_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.EarthShock, context.target, "[LEVELING] Earth Shock") end },

    -- Mana Recovery: Shamanistic Rage (level 50+)
    { name = "ShamanisticRage",
      matches = shamanistic_rage_matches,
      execute = function(context)
          return try_cast(SPELLS.ShamanisticRage, nil, "[LEVELING] Shamanistic Rage", { skip_range = true })
      end },

    -- Survival: Healing Wave
    { name = "HealingWave",
      matches = healing_wave_matches,
      execute = function(context) return try_cast(SPELLS.HealingWave, nil, "[LEVELING] Healing Wave", { skip_range = true }) end },

    -- Survival: Lesser Healing Wave (fast cheap heal)
    { name = "LesserHealingWave",
      matches = lesser_healing_wave_matches,
      execute = function(context) return try_cast(SPELLS.LesserHealingWave, nil, "[LEVELING] Lesser Healing Wave", { skip_range = true }) end },

    -- Totems: combat support
    { name = "SearingTotem",
      matches = searing_totem_matches,
      execute = function(context, state)
          if not state then return false end
          if try_cast(SPELLS.SearingTotem, nil, "[LEVELING] Searing Totem", { skip_range = true }) then
              return true
          end
          return false
      end },

    { name = "StrengthOfEarthTotem",
      matches = strength_totem_matches,
      execute = function(context, state)
          if not state then return false end
          if try_cast(SPELLS.StrengthOfEarthTotem, nil, "[LEVELING] Strength of Earth Totem", { skip_range = true }) then
              return true
          end
          return false
      end },

    { name = "WaterTotem",
      matches = water_totem_matches,
      execute = function(context, state)
          if not state then return false end
          local spell = (state.mana_spring_ready and (state.mana_pct or 100) <= 85) and SPELLS.ManaSpringTotem or SPELLS.HealingStreamTotem
          if try_cast(spell, nil, "[LEVELING] Water Totem", { skip_range = true }) then
              return true
          end
          return false
      end },

    -- Defense: Grounding Totem (spell absorb)
    { name = "GroundingTotem",
      matches = grounding_totem_matches,
      execute = function(context) return try_cast(SPELLS.GroundingTotem, nil, "[LEVELING] Grounding Totem", { skip_range = true }) end },

    -- Defense: Tremor Totem (fear/charm/sleep break)
    { name = "TremorTotem",
      matches = tremor_totem_matches,
      execute = function(context) return try_cast(SPELLS.TremorTotem, nil, "[LEVELING] Tremor Totem", { skip_range = true }) end },

    -- Melee DPS: Stormstrike (level 40+)
    { name = "Stormstrike",
      matches = stormstrike_matches,
      execute = function(context)
          if not context then return false end
          return try_cast(SPELLS.Stormstrike, context.target, "[LEVELING] Stormstrike")
      end },

    -- AoE: Chain Lightning
    { name = "ChainLightning",
      matches = chain_lightning_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.ChainLightning, context.target, "[LEVELING] Chain Lightning") end },

    -- DoT: Flame Shock
    { name = "FlameShock",
      matches = flame_shock_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.FlameShock, context.target, "[LEVELING] Flame Shock") end },

    -- DPS: Earth Shock
    { name = "EarthShock",
      matches = earth_shock_dps_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.EarthShock, context.target, "[LEVELING] Earth Shock") end },

    -- PvP: Purge (dispel 2 magic buffs)
    { name = "Purge",
      matches = purge_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.Purge, context.target, "[LEVELING] Purge") end },

    -- Slow: Frost Shock
    { name = "FrostShock",
      matches = frost_shock_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.FrostShock, context.target, "[LEVELING] Frost Shock") end },    -- Kite: Earthbind Totem
    { name = "EarthbindTotem",
      matches = earthbind_totem_matches,
      execute = function(context) return try_cast(SPELLS.EarthbindTotem, nil, "[LEVELING] Earthbind Totem") end },

    -- Defense: Stoneclaw Totem (aggro redirect when overwhelmed)
    { name = "StoneclawTotem",
      matches = stoneclaw_totem_matches,
      execute = function(context) return try_cast(SPELLS.StoneclawTotem, nil, "[LEVELING] Stoneclaw Totem", { skip_range = true }) end },

    -- Filler: LightningBolt
    { name = "LightningBolt",
      matches = lightning_bolt_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.LightningBolt, context.target, "[LEVELING] Lightning Bolt") end },

    -- OOC Travel: Ghost Wolf
    { name = "GhostWolf",
      matches = ghost_wolf_matches,
      execute = function(context, state)
          return try_cast(SPELLS.GhostWolf, nil, "[LEVELING] Ghost Wolf", { skip_range = true })
      end },

    -- Wand fallback (when low mana)
    { name = "Wand",
      matches = leveling.create_wand_matches("leveling_wand_threshold", 30),
      execute = function(context) return leveling.execute_wand(context) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = shaman_leveling.build_state })
end

-- ============================================================================
-- Rotation entry point
-- ============================================================================

function shaman_leveling.on_update(context)
    if not context then return false end
    if not is_leveling_context(context) then return false end

    local state = shaman_leveling.build_state(context)
    if not state then return false end

    -- Evaluate strategies in priority order
    for i = 1, #strategies do
        local strategy = strategies[i]
        local ok, should_execute = pcall(strategy.matches, context, state)
        if ok and should_execute then
            local ok2, result = pcall(strategy.execute, context, state)
            if ok2 and result then
                return true
            end
        end
    end

    return false
end

NS.log("[Shaman] Leveling rotation loaded")
return shaman_leveling
