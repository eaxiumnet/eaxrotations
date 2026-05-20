-- Shaman Enhancement rotation - FrostByte feature port v2.0.
-- Features: per-slot weapon buffs, smart shield auto-swap, totem twisting
-- with Fire Nova cycle, shock priority, randomized interrupts, Ghost Wolf OOC

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.ShamanSpells or {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { shaman = {} } } end
local TBC_SHAMAN = (TBC.SPELLS and TBC.SPELLS.shaman) or {}

local _core = (NS and NS.core) or rawget(_G, "core")
local _get_totem_info = _core and _core.spell_book and _core.spell_book.get_totem_info
local _get_visible_objects = _core and _core.object_manager and _core.object_manager.get_visible_objects

-- Expose GetWeaponEnchantInfo for weapon imbue detection
pcall(require, "common/wow_api_clone")
local _GetWeaponEnchantInfo = type(GetWeaponEnchantInfo) == "function" and GetWeaponEnchantInfo or nil
---@diagnostic disable-next-line: undefined-global
local _GetWeaponEnchant = type(GetWeaponEnchant) == "function" and GetWeaponEnchant or nil

-- Auto-attack helper
local auto_attack = require("common/utility/auto_attack_helper")

-- ============================================================================
-- Constants
-- ============================================================================
local AIR_TWIST_HOLD_MS = 9000
local AIR_TWIST_SWAP_DELAY_MS = 1300
local TOTEM_REFRESH_MS = 115000
local FIRE_TOTEM_DURATION_MS = 60000
local TOTEMIC_CALL_SPELL = { 36936 }
local TOTEM_CALL_DISTANCE = 20           -- yards
local TOTEM_CALL_MAGMA_DISTANCE = 8      -- yards (tighter for Magma)
local TOTEM_SCAN_INTERVAL_MS = 2000      -- throttle object scanning
local SHIELD_REFRESH_UNKNOWN_MS = 30000
local WEAPON_BUFF_REFRESH_MS = 1500000  -- 25 minutes
local FIRE_NOVA_TWIST_MS = 4000          -- Fire Nova -> Magma after 4s
local ENCOUNTER_COOLDOWN_MS = 3000       -- Throttle new-encounter detection
local TOTEM_RANGE_SCAN_MS = 1000          -- 1s throttle for totem range scan (v1.1.1)

local LIGHTNING_SHIELD_BUFF = TBC_SHAMAN.lightning_shield or { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local WATER_SHIELD_BUFF = TBC_SHAMAN.water_shield or { 57960, 33736, 24398, 24396, 23566, 23563, 23548, 16198, 16196, 16192, 10911 }
local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local WINDFURY_WEAPON_SPELLS = { 25505, 16362, 10486, 8235, 8232 }
local FLAMETONGUE_WEAPON_SPELLS = { 25489, 16342, 16341, 16339, 8030, 8027, 8024 }
local ROCKBITER_WEAPON_SPELLS = { 25485, 25479, 16316, 16315, 16314, 10399, 8019, 8018, 8017 }
local FROSTBRAND_WEAPON_SPELLS = { 25500, 16356, 16355, 10456, 8038, 8033 }
local FIRE_RESIST_TOTEM = { 25563, 10538, 10537, 10534, 8181 }
local FROST_RESIST_TOTEM = { 25560, 10542, 8185, 8184, 8182 }
local NATURE_RESIST_TOTEM = { 25574, 10548 }
local GHOST_WOLF_SPELL = { 2645 }
local TREMOR_TOTEM_SPELL = { 8143 }

-- ============================================================================
-- Totem state
-- ============================================================================
local totem_state = {
    -- Twisting
    next_air = "windfury",
    last_air_ms = -100000,
    last_windfury_ms = -100000,
    -- Earth
    last_strength_ms = -100000,
    last_stoneskin_ms = -100000,
    -- Water
    last_mana_ms = -100000,
    last_healing_stream_ms = -100000,
    -- Fire
    last_fire_ms = -100000,
    last_fire_nova_ms = -100000,
    last_fire_nova_swap_ms = -100000,
    fire_totem_type = "none",
    fire_nova_active = false,
    -- Shield
    last_lightning_shield_ms = -SHIELD_REFRESH_UNKNOWN_MS,
    last_water_shield_ms = -SHIELD_REFRESH_UNKNOWN_MS,
    -- Weapon buffs
    last_mh_buff_ms = -WEAPON_BUFF_REFRESH_MS,
    last_oh_buff_ms = -WEAPON_BUFF_REFRESH_MS,
    last_mh_buff_type = "none",
    last_oh_buff_type = "none",
    -- Encounter tracking
    last_encounter_ms = -ENCOUNTER_COOLDOWN_MS,
}

-- ============================================================================
-- State builder
-- ============================================================================
local enh_state = {
    now_ms = 0,
    -- Buffs
    has_lightning_shield = false,
    has_water_shield = false,
    has_windfury_weapon = false,
    has_flametongue_weapon = false,
    has_rockbiter_weapon = false,
    has_frostbrand_weapon = false,
    has_shamanistic_rage = false,
    has_bloodlust = false,
    has_ghost_wolf = false,
    -- Resources
    mana_pct = 100,
    hp_pct = 100,
    mana_low = false,
    mana_emergency = false,
    in_combat = false,
    enemy_count = 1,
    is_moving = false,
    target_is_casting = false,
    target_cast_pct = 0,
    -- Spell readiness
    lightning_shield_ready = false,
    lightning_shield_charges = 0,
    water_shield_ready = false,
    stormstrike_ready = false,
    flame_shock_ready = false,
    earth_shock_ready = false,
    frost_shock_ready = false,
    chain_lightning_ready = false,
    lightning_bolt_ready = false,
    windfury_totem_ready = false,
    grace_of_air_totem_ready = false,
    strength_of_earth_totem_ready = false,
    stoneskin_totem_ready = false,
    mana_spring_totem_ready = false,
    healing_stream_totem_ready = false,
    searing_totem_ready = false,
    magma_totem_ready = false,
    fire_nova_totem_ready = false,
    mana_tide_totem_ready = false,
    natures_swiftness_ready = false,
    lesser_healing_wave_ready = false,
    chain_heal_ready = false,
    tremor_totem_ready = false,
    grounding_totem_ready = false,
    ghost_wolf_ready = false,
    bloodlust_ready = false,
    -- Target debuffs
    target_has_flame_shock = false,
    flame_shock_remains = 0,
    target_is_interruptible = false,
    target_can_interrupt = false,
    -- Settings cache
    combat_mode = "auto",
    earth_shock_mode = "interrupts",
    shield_type = "auto",
    aoe_threshold = 3,
    self_heal_hp = 40,
    chain_heal_hp = 35,
    kick_min_pct = 40,
    kick_max_pct = 80,
    ghost_wolf_ooc = true,
    water_shield_mana = 60,
    lightning_shield_mana = 80,
    manage_totems = true,
    totem_twisting = true,
    -- Totemic call
    totemic_call_ready = false,
    last_totem_scan_ms = 0,
    last_totem_range_scan_ms = 0,
    totem_out_of_range_earth = false,
    totem_out_of_range_water = false,
    totem_out_of_range_fire = false,
    gift_of_the_naaru_ready = false,
}

---@diagnostic disable-next-line: duplicate-set-field
local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    totem_state.now_ms = NS.game_time_ms()
    enh_state.now_ms = totem_state.now_ms

    -- -- Settings cache
    local s = context.settings or {}
    enh_state.combat_mode = s.enhancement_combat_mode or "auto"
    enh_state.earth_shock_mode = s.enhancement_earth_shock_mode or "interrupts"
    enh_state.shield_type = s.enhancement_shield_type or "auto"
    enh_state.aoe_threshold = s.enhancement_aoe_threshold or 3
    enh_state.self_heal_hp = s.enhancement_self_heal_hp or 40
    enh_state.chain_heal_hp = s.enhancement_chain_heal_hp or 35
    enh_state.kick_min_pct = s.enhancement_interrupt_kick_min or 40
    enh_state.kick_max_pct = s.enhancement_interrupt_kick_max or 80
    enh_state.ghost_wolf_ooc = s.enhancement_ghost_wolf_ooc ~= false
    enh_state.water_shield_mana = s.enhancement_water_shield_mana or 60
    enh_state.lightning_shield_mana = s.enhancement_lightning_shield_mana or 80
    enh_state.manage_totems = s.enhancement_manage_totems ~= false
    enh_state.totem_twisting = s.enhancement_totem_twisting ~= false
    enh_state.interrupt_mode = s.enhancement_interrupt_mode or "target"
    enh_state.totem_range = s.enhancement_totem_range or 30
    enh_state.fs_multi_target = s.enhancement_fs_multi_target ~= false
    enh_state.hold_shocks_focus = s.enhancement_hold_shocks_focus == true
    enh_state.sr_melee_only = s.enhancement_sr_melee_only ~= false
    enh_state.weapon_buff_last_attempt = enh_state.weapon_buff_last_attempt or 0
    enh_state.last_totem_scan_ms = enh_state.last_totem_scan_ms or 0
    enh_state.auto_attack = s.enhancement_auto_attack ~= false
    enh_state.auto_totemic_call = s.enhancement_auto_totemic_call ~= false
    enh_state.gift_of_the_naaru_enabled = s.enhancement_cd_gift_of_the_naaru ~= false

    -- -- Resource state
    enh_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    enh_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    enh_state.mana_low = enh_state.mana_pct < (s.enhancement_mana_low_pct or 20)
    enh_state.mana_emergency = enh_state.mana_pct < (s.enhancement_mana_emergency_pct or 10)
    enh_state.in_combat = context.in_combat or false
    enh_state.enemy_count = context.enemy_count or context.enemies_count or 1
    enh_state.is_moving = me and me:is_moving() or false

    -- -- Determine combat mode from auto
    if enh_state.combat_mode == "auto" then
        local auto_aoe = enh_state.enemy_count >= enh_state.aoe_threshold
        enh_state.effective_mode = auto_aoe and "aoe" or "single"
    else
        enh_state.effective_mode = enh_state.combat_mode
    end

    -- -- Buff detection
    enh_state.has_lightning_shield = me and NS.buff_up(me, LIGHTNING_SHIELD_BUFF) or false
    enh_state.lightning_shield_charges = (me and enh_state.has_lightning_shield and NS.get_buff_stacks(me, LIGHTNING_SHIELD_BUFF)) or 0
    enh_state.has_water_shield = me and NS.buff_up(me, WATER_SHIELD_BUFF) or false
    enh_state.has_shamanistic_rage = me and NS.buff_up(me, { 30823 }) or false
    enh_state.has_bloodlust = me and NS.buff_up(me, { 2825 }) or false
    enh_state.has_ghost_wolf = me and NS.buff_up(me, GHOST_WOLF_SPELL) or false

    -- -- Weapon buff detection (separate MH/OH)
    if _GetWeaponEnchantInfo then
        local ok, hasMH, hasOH = pcall(function() return _GetWeaponEnchantInfo() end)
        enh_state.has_windfury_weapon = ok and hasMH or false
        enh_state.has_rockbiter_weapon = false
        enh_state.has_flametongue_weapon = false
        enh_state.has_frostbrand_weapon = false
        -- Use GetWeaponEnchant if available for precise detection
        if ok and _GetWeaponEnchant then
            local mh_ok, mh_id = pcall(_GetWeaponEnchant, 0)
            local oh_ok, oh_id = pcall(_GetWeaponEnchant, 1)
            if mh_ok and mh_id then
                enh_state.mh_enchant_id = mh_id
            end
            if oh_ok and oh_id then
                enh_state.oh_enchant_id = oh_id
            end
        end
    else
        enh_state.has_windfury_weapon = false
    end

    -- -- Target state
    enh_state.target_has_flame_shock = target and NS.debuff_up(target, FLAME_SHOCK_DEBUFF) or false
    enh_state.flame_shock_remains = target and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF) or 0
    if target and target.is_casting then
        enh_state.target_is_casting = target:is_casting()
        enh_state.target_cast_pct = target:get_casting_percent() or 0
        enh_state.target_can_interrupt = enh_state.target_is_casting
    else
        enh_state.target_is_casting = false
        enh_state.target_cast_pct = 0
        enh_state.target_can_interrupt = false
    end

    -- -- Spell readiness
    enh_state.lightning_shield_ready = me and NS.spell_ready(SPELLS.LightningShield, me, { skip_range = true }) or false
    enh_state.water_shield_ready = me and NS.spell_ready(SPELLS.WaterShield, me, { skip_range = true }) or false
    enh_state.stormstrike_ready = target and NS.spell_ready(SPELLS.Stormstrike, target, { expected_cooldown = 10 }) or false
    enh_state.flame_shock_ready = target and NS.spell_ready(SPELLS.FlameShock, target, { expected_cooldown = 6 }) or false
    enh_state.earth_shock_ready = target and NS.spell_ready(SPELLS.EarthShock, target, { expected_cooldown = 6 }) or false
    enh_state.frost_shock_ready = target and NS.spell_ready(SPELLS.FrostShock, target, { expected_cooldown = 6 }) or false
    enh_state.chain_lightning_ready = target and NS.spell_ready(SPELLS.ChainLightning, target, { expected_cooldown = 6 }) or false
    enh_state.lightning_bolt_ready = target and NS.spell_ready(SPELLS.LightningBolt, target, { expected_cooldown = 2.5 }) or false
    enh_state.windfury_totem_ready = me and NS.spell_ready(SPELLS.WindfuryTotem, me, { skip_range = true }) or false
    enh_state.grace_of_air_totem_ready = me and NS.spell_ready(SPELLS.GraceOfAirTotem, me, { skip_range = true }) or false
    enh_state.strength_of_earth_totem_ready = me and NS.spell_ready(SPELLS.StrengthOfEarthTotem, me, { skip_range = true }) or false
    enh_state.stoneskin_totem_ready = me and NS.spell_ready(SPELLS.StoneskinTotem, me, { skip_range = true }) or false
    enh_state.mana_spring_totem_ready = me and NS.spell_ready(SPELLS.ManaSpringTotem, me, { skip_range = true }) or false
    enh_state.healing_stream_totem_ready = me and NS.spell_ready(SPELLS.HealingStreamTotem, me, { skip_range = true }) or false
    enh_state.searing_totem_ready = me and NS.spell_ready(SPELLS.SearingTotem, me, { skip_range = true }) or false
    enh_state.magma_totem_ready = me and NS.spell_ready(SPELLS.MagmaTotem, me, { skip_range = true }) or false
    enh_state.fire_nova_totem_ready = me and NS.spell_ready(SPELLS.FireNovaTotem, me, { skip_range = true }) or false
    enh_state.mana_tide_totem_ready = me and NS.spell_ready(SPELLS.ManaTideTotem, me, { skip_range = true, expected_cooldown = 300 }) or false
    enh_state.natures_swiftness_ready = me and NS.spell_ready(SPELLS.NaturesSwiftness, me, { skip_range = true, expected_cooldown = 180 }) or false
    enh_state.lesser_healing_wave_ready = me and NS.spell_ready(SPELLS.LesserHealingWave, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    enh_state.chain_heal_ready = me and NS.spell_ready(SPELLS.ChainHeal, me, { skip_range = true }) or false
    enh_state.shadow_totem_ready = false
    enh_state.tremor_totem_ready = me and NS.spell_ready(TREMOR_TOTEM_SPELL, me, { skip_range = true }) or false
    enh_state.grounding_totem_ready = me and NS.spell_ready(SPELLS.GroundingTotem, me, { skip_range = true }) or false
    enh_state.ghost_wolf_ready = me and NS.spell_ready(GHOST_WOLF_SPELL, me, { skip_range = true }) or false
    enh_state.bloodlust_ready = me and NS.spell_ready(SPELLS.Bloodlust, me, { skip_range = true, expected_cooldown = 600 }) or false
    enh_state.totemic_call_ready = me and NS.spell_ready(SPELLS.TotemicCall, me, { skip_range = true, expected_cooldown = 120 }) or false
    enh_state.gift_of_the_naaru_ready = me and NS.spell_ready(SPELLS.GiftOfTheNaaru, me, { skip_range = true, expected_cooldown = 120 }) or false

    -- -- Throttled totem range scan (v1.1.1)
    local now_ms = NS.game_time_ms()
    if now_ms - enh_state.last_totem_range_scan_ms >= TOTEM_RANGE_SCAN_MS then
        enh_state.last_totem_range_scan_ms = now_ms
        enh_state.totem_out_of_range_earth = false
        enh_state.totem_out_of_range_water = false
        enh_state.totem_out_of_range_fire = false

        local my_pos = me and me:get_position()
        if my_pos then
            local range = enh_state.totem_range or 25
            local range_sq = range * range

            -- Check each totem slot via get_totem_info
            local earth_active = false
            local water_active = false
            local fire_active = false

            local info1 = _get_totem_info and _get_totem_info(1) or nil
            local info2 = _get_totem_info and _get_totem_info(2) or nil
            local info3 = _get_totem_info and _get_totem_info(3) or nil

            if info1 and info1.have_totem then earth_active = true end
            if info2 and info2.have_totem then water_active = true end
            if info3 and info3.have_totem then fire_active = true end

            -- Scan visible objects for owned totems
            if earth_active or water_active or fire_active then
                local objects = _get_visible_objects and _get_visible_objects() or nil
                if objects then
                    for _, obj in ipairs(objects) do
                        local owner = obj:get_owner()
                        if owner then
                            local obj_pos = obj:get_position()
                            if obj_pos then
                                local dx = obj_pos.x - my_pos.x
                                local dy = obj_pos.y - my_pos.y
                                local dist_sq = dx*dx + dy*dy
                                if dist_sq > range_sq then
                                    -- Out of range — mark all active slots as needing re-cast
                                    if earth_active then enh_state.totem_out_of_range_earth = true end
                                    if water_active then enh_state.totem_out_of_range_water = true end
                                    if fire_active then enh_state.totem_out_of_range_fire = true end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return enh_state
end

-- ============================================================================
-- Helpers
-- ============================================================================
local function can_manage_totems(ctx)
    return enh_state.manage_totems or enh_state.totem_twisting
end

local function can_drop_totem(ctx, spell)
    if not can_manage_totems(ctx) then return false end
    if enh_state.mana_low then return false end
    return NS.spell_ready(spell, NS.PLAYER_UNIT, { skip_range = true })
end

-- Throttled debug log (1s interval, gated by debug_mode setting)
local _last_debug_log = 0
local function debug_log(ctx, message)
    if not ctx.settings or ctx.settings.debug_mode ~= true then return end
    local now = NS.game_time_ms()
    if now - _last_debug_log < 1000 then return end
    _last_debug_log = now
    NS.log("[ENHANCEMENT DEBUG] " .. message)
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns ~= false
end

-- v1.2.1: racial match functions
local function blood_fury_matches(ctx)
    if ctx.settings and ctx.settings.enhancement_cd_blood_fury == false then return false end
    return NS.action_matches(ctx, BLOOD_FURY_ACTION)
end

local function berserking_matches(ctx)
    if ctx.settings and ctx.settings.enhancement_cd_berserking == false then return false end
    return NS.action_matches(ctx, BERSERKING_ACTION)
end

-- Tremor Totem (fear/charm/sleep break)
local function tremor_totem_matches(ctx)
    if not enh_state.tremor_totem_ready then return false end
    if not enh_state.in_combat then return false end
    if not ctx.fear_nearby then return false end
    return true
end

-- Grounding Totem (spell absorb for caster mobs / PvP)
local function grounding_totem_matches(ctx)
    if not enh_state.grounding_totem_ready then return false end
    if not enh_state.in_combat then return false end
    if not (ctx.is_pvp == true or enh_state.target_is_casting) then return false end
    return true
end

local function is_new_encounter()
    local now = totem_state.now_ms
    local elapsed = now - totem_state.last_encounter_ms
    if elapsed >= ENCOUNTER_COOLDOWN_MS then
        totem_state.last_encounter_ms = now
        return true
    end
    return false
end

local function should_interrupt_target(ctx)
    if enh_state.earth_shock_mode ~= "interrupts" then return false end
    if not enh_state.earth_shock_ready then return false end
    -- v1.2.4: Interrupt Mode — Target Only vs Any in Range
    local mode = enh_state.interrupt_mode or "target"
    if mode == "target" then
        -- Target Only: check current target's cast
        if not enh_state.target_can_interrupt then return false end
        local cast_pct = enh_state.target_cast_pct
        local min_pct = enh_state.kick_min_pct
        local max_pct = enh_state.kick_max_pct
        if min_pct >= max_pct then min_pct = max_pct - 10 end
        return cast_pct >= min_pct and cast_pct <= max_pct
    else
        -- Any in Range: accept if any nearby enemy is casting
        -- (detected via combat context; return true to let action_matches handle range)
        return true
    end
end

local function resolve_weapon_spell(settings_key)
    local choice = enh_state[settings_key] or "none"
    if choice == "windfury" then return WINDFURY_WEAPON_SPELLS, "windfury"
    elseif choice == "flametongue" then return FLAMETONGUE_WEAPON_SPELLS, "flametongue"
    elseif choice == "rockbiter" then return ROCKBITER_WEAPON_SPELLS, "rockbiter"
    elseif choice == "frostbrand" then return FROSTBRAND_WEAPON_SPELLS, "frostbrand"
    else return nil, "none" end
end

-- ============================================================================
-- Action definitions
-- ============================================================================
local LIGHTNING_SHIELD_ACTION = { name = "LightningShield", spell = SPELLS.LightningShield, target = "self", kind = "buff", buff = LIGHTNING_SHIELD_BUFF, requires_target = false }
local WATER_SHIELD_ACTION = { name = "WaterShield", spell = SPELLS.WaterShield, target = "self", kind = "buff", buff = WATER_SHIELD_BUFF, requires_target = false }
local STORMSTRIKE_ACTION = { name = "Stormstrike", spell = SPELLS.Stormstrike, cooldown = 10 }
local FLAME_SHOCK_ACTION = { name = "FlameShock", spell = SPELLS.FlameShock, debuff = FLAME_SHOCK_DEBUFF, refresh = 3, cooldown = 6 }
local EARTH_SHOCK_ACTION = { name = "EarthShock", spell = SPELLS.EarthShock, cooldown = 6 }
local FROST_SHOCK_ACTION = { name = "FrostShock", spell = SPELLS.FrostShock, cooldown = 6 }
local CHAIN_LIGHTNING_ACTION = { name = "ChainLightning", spell = SPELLS.ChainLightning, cooldown = 6 }
local LIGHTNING_BOLT_ACTION = { name = "LightningBolt", spell = SPELLS.LightningBolt, cooldown = 2.5 }
local LESSER_HEALING_WAVE_ACTION = { name = "LesserHealingWave", spell = SPELLS.LesserHealingWave, target = "self", requires_target = false }
local CHAIN_HEAL_ACTION = { name = "ChainHeal", spell = SPELLS.ChainHeal, target = "self", requires_target = false }
local MANA_TIDE_TOTEM_ACTION = { name = "ManaTideTotem", spell = SPELLS.ManaTideTotem, target = "self", cooldown = 300, requires_target = false }
local NATURES_SWIFTNESS_ACTION = { name = "NaturesSwiftness", spell = SPELLS.NaturesSwiftness, target = "self", cooldown = 180, requires_target = false }
local SHAMANISTIC_RAGE_ACTION = { name = "ShamanisticRage", spell = SPELLS.ShamanisticRage, target = "self", combat = true, cooldown = 120, requires_target = false }
local BLOODLUST_ACTION = { name = "Bloodlust", spell = SPELLS.Bloodlust, target = "self", combat = true, setting = "use_cooldowns", cooldown = 600, min_mana = 25, requires_target = false }
-- v1.2.1: racials
local BLOOD_FURY_ACTION = { name = "BloodFury", spell = { 33697, 20572 }, target = "self", combat = true, setting = "use_cooldowns", cooldown = 120, requires_target = false }
local BERSERKING_ACTION = { name = "Berserking", spell = { 20554, 26297 }, target = "self", combat = true, setting = "use_cooldowns", cooldown = 180, requires_target = false }

-- Totem actions
local STRENGTH_OF_EARTH_ACTION = { name = "StrengthOfEarthTotem", spell = SPELLS.StrengthOfEarthTotem, target = "self", requires_target = false }
local STONESKIN_TOTEM_ACTION = { name = "StoneskinTotem", spell = SPELLS.StoneskinTotem, target = "self", requires_target = false }
local MANA_SPRING_ACTION = { name = "ManaSpringTotem", spell = SPELLS.ManaSpringTotem, target = "self", requires_target = false }
local HEALING_STREAM_ACTION = { name = "HealingStreamTotem", spell = SPELLS.HealingStreamTotem, target = "self", requires_target = false }
local SEARING_TOTEM_ACTION = { name = "SearingTotem", spell = SPELLS.SearingTotem, target = "self", requires_target = false }
local MAGMA_TOTEM_ACTION = { name = "MagmaTotem", spell = SPELLS.MagmaTotem, target = "self", requires_target = false }
local FIRE_NOVA_TOTEM_ACTION = { name = "FireNovaTotem", spell = SPELLS.FireNovaTotem, target = "self", requires_target = false }
local WINDFURY_TOTEM_ACTION = { name = "WindfuryTotem", spell = SPELLS.WindfuryTotem, target = "self", requires_target = false }
local GRACE_OF_AIR_ACTION = { name = "GraceOfAirTotem", spell = SPELLS.GraceOfAirTotem, target = "self", requires_target = false }
local WINDFURY_TWIST_ACTION = { name = "WindfuryTotemTwist", spell = SPELLS.WindfuryTotem, target = "self", requires_target = false }
local GRACE_AIR_TWIST_ACTION = { name = "GraceOfAirTotemTwist", spell = SPELLS.GraceOfAirTotem, target = "self", requires_target = false }

-- Weapon buff actions
local function make_weapon_action(name, spell_list, slot_key)
    return { name = name, spell = spell_list, target = "self", kind = "buff", requires_target = false, slot = slot_key }
end

-- ============================================================================
-- Totem match functions
-- ============================================================================
local function earth_totem_matches(ctx, desired)
    if not can_manage_totems(ctx) then return false end
    if not desired or desired == "none" then return false end
    local now = enh_state.now_ms
    local range_override = enh_state.totem_out_of_range_earth
    if desired == "strength" then
        if not enh_state.strength_of_earth_totem_ready then return false end
        if now - totem_state.last_strength_ms < TOTEM_REFRESH_MS and not range_override then return false end
        return true
    elseif desired == "stoneskin" then
        if not enh_state.stoneskin_totem_ready then return false end
        if now - totem_state.last_stoneskin_ms < TOTEM_REFRESH_MS and not range_override then return false end
        return true
    end
    return false
end

local function water_totem_matches(ctx, desired)
    if not can_manage_totems(ctx) then return false end
    if not desired or desired == "none" then return false end
    local now = enh_state.now_ms
    local range_override = enh_state.totem_out_of_range_water
    if desired == "mana_spring" then
        if not enh_state.mana_spring_totem_ready then return false end
        if now - totem_state.last_mana_ms < TOTEM_REFRESH_MS and not range_override then return false end
        return true
    elseif desired == "healing_stream" then
        if not enh_state.healing_stream_totem_ready then return false end
        if now - totem_state.last_healing_stream_ms < TOTEM_REFRESH_MS and not range_override then return false end
        return true
    end
    return false
end

local function fire_totem_matches(ctx, desired)
    if not can_manage_totems(ctx) then return false end
    if not desired or desired == "none" then return false end
    local now = enh_state.now_ms
    local range_override = enh_state.totem_out_of_range_fire

    -- If Fire Nova was just placed, swap to Magma after 4s
    if totem_state.fire_nova_active then
        if now - totem_state.last_fire_nova_swap_ms >= FIRE_NOVA_TWIST_MS then
            -- Time to replace Fire Nova with Magma
            if desired ~= "fire_nova" and enh_state.magma_totem_ready then
                totem_state.fire_nova_active = false
                return false  -- Will be handled by fire_nova_replacement match
            end
        end
        return false  -- Fire Nova still active
    end

    if desired == "searing" then
        if not enh_state.searing_totem_ready then return false end
        if now - totem_state.last_fire_ms < TOTEM_REFRESH_MS and not range_override then return false end
        return true
    elseif desired == "magma" then
        if not enh_state.magma_totem_ready then return false end
        if now - totem_state.last_fire_ms < TOTEM_REFRESH_MS and not range_override then return false end
        return true
    elseif desired == "fire_nova" then
        if not enh_state.fire_nova_totem_ready then return false end
        if now - totem_state.last_fire_ms < TOTEM_REFRESH_MS then return false end
        return true
    end
    return false
end

-- Fire Nova replacement: after 4s, drop Magma to replace expired Fire Nova
local function fire_nova_replacement_matches(ctx)
    if not can_manage_totems(ctx) then return false end
    if not totem_state.fire_nova_active then return false end
    local now = enh_state.now_ms
    if now - totem_state.last_fire_nova_swap_ms < FIRE_NOVA_TWIST_MS then return false end
    if not enh_state.magma_totem_ready then return false end
    if now - totem_state.last_fire_ms < TOTEM_REFRESH_MS then return false end
    return true
end

local function windfury_maintain_matches(ctx)
    if not can_manage_totems(ctx) then return false end
    if not enh_state.windfury_totem_ready then return false end
    local now = enh_state.now_ms
    if now - totem_state.last_windfury_ms < TOTEM_REFRESH_MS then return false end
    return true
end

local function windfury_twist_matches(ctx)
    if not enh_state.totem_twisting then return false end
    if not enh_state.in_combat then return false end
    if enh_state.mana_low then return false end
    local mana_floor = (ctx.settings or {}).enhancement_totem_twist_mana_floor or 25
    if enh_state.mana_pct < mana_floor then return false end
    if not enh_state.windfury_totem_ready then return false end
    return totem_state.next_air == "windfury" and enh_state.now_ms - totem_state.last_air_ms >= AIR_TWIST_HOLD_MS
end

local function grace_air_twist_matches(ctx)
    if not enh_state.totem_twisting then return false end
    if not enh_state.in_combat then return false end
    if enh_state.mana_low then return false end
    local mana_floor = (ctx.settings or {}).enhancement_totem_twist_mana_floor or 25
    if enh_state.mana_pct < mana_floor then return false end
    if not enh_state.grace_of_air_totem_ready then return false end
    return totem_state.next_air == "grace" and enh_state.now_ms - totem_state.last_air_ms >= AIR_TWIST_SWAP_DELAY_MS
end

-- ============================================================================
-- Shield match functions
-- ============================================================================
local function lightning_shield_matches(ctx)
    if enh_state.shield_type == "water" then return false end
    if enh_state.has_lightning_shield and (enh_state.lightning_shield_charges or 0) > 1 then return false end
    if not enh_state.lightning_shield_ready then return false end
    if enh_state.now_ms - totem_state.last_lightning_shield_ms < SHIELD_REFRESH_UNKNOWN_MS then return false end
    -- Auto mode: only maintain Lightning Shield when mana is above threshold
    if enh_state.shield_type == "auto" and enh_state.mana_pct < enh_state.lightning_shield_mana then return false end
    return NS.action_matches(ctx, LIGHTNING_SHIELD_ACTION)
end

local function lightning_shield_execute(ctx)
    if NS.action_execute(ctx, LIGHTNING_SHIELD_ACTION, "[ENHANCEMENT]") then
        totem_state.last_lightning_shield_ms = enh_state.now_ms
        return true
    end
    return false
end

local function water_shield_matches(ctx)
    if enh_state.shield_type == "lightning" then return false end
    if enh_state.has_water_shield then return false end
    if not enh_state.water_shield_ready then return false end
    if enh_state.now_ms - totem_state.last_water_shield_ms < SHIELD_REFRESH_UNKNOWN_MS then return false end
    -- Auto mode: switch to Water Shield when mana is low
    if enh_state.shield_type == "auto" and enh_state.mana_pct >= enh_state.water_shield_mana then return false end
    return NS.action_matches(ctx, WATER_SHIELD_ACTION)
end

local function water_shield_execute(ctx)
    if NS.action_execute(ctx, WATER_SHIELD_ACTION, "[ENHANCEMENT]") then
        totem_state.last_water_shield_ms = enh_state.now_ms
        return true
    end
    return false
end

-- ============================================================================
-- Weapon buff match functions (per-slot)
-- ============================================================================
local function mh_weapon_matches(ctx)
    local s = ctx.settings or {}
    local choice = s.enhancement_main_hand_ench or "windfury"
    if choice == "none" then return false end
    if enh_state.in_combat then return false end
    local now = enh_state.now_ms
    if now - totem_state.last_mh_buff_ms < WEAPON_BUFF_REFRESH_MS and totem_state.last_mh_buff_type ~= "none" then return false end
    -- v1.3.9: 3s retry throttle on failed cast attempts
    if now - enh_state.weapon_buff_last_attempt < 3000 then return false end
    return true
end

local function oh_weapon_matches(ctx)
    local s = ctx.settings or {}
    local choice = s.enhancement_off_hand_ench or "flametongue"
    if choice == "none" then return false end
    if enh_state.in_combat then return false end
    local now = enh_state.now_ms
    if now - totem_state.last_oh_buff_ms < WEAPON_BUFF_REFRESH_MS and totem_state.last_oh_buff_type ~= "none" then return false end
    -- v1.3.9: 3s retry throttle on failed cast attempts
    if now - enh_state.weapon_buff_last_attempt < 3000 then return false end
    return true
end

-- ============================================================================
-- Spell match functions
-- ============================================================================
local function shamanistic_rage_matches(ctx)
    if not enh_state.in_combat then return false end
    if enh_state.has_shamanistic_rage then return false end
    if not enh_state.shamanistic_rage_ready then return false end
    -- v1.2.1: per-CD toggle
    if ctx.settings and ctx.settings.enhancement_cd_shamanistic_rage == false then return false end
    -- Gate: use when mana is low (Research) or during defensive need (hp < 40%); skip at high mana + high hp
    if enh_state.mana_pct > 40 and enh_state.hp_pct > 40 then return false end
    -- v1.2.4: SR melee range check — only fire if target within 8 yd
    if enh_state.sr_melee_only then
        local target = ctx.target
        if not target then return false end
        local dist = target.get_distance and target:get_distance(NS.PLAYER_UNIT or ctx.me)
        if dist and dist > 8 then return false end
    end
    return NS.action_matches(ctx, SHAMANISTIC_RAGE_ACTION)
end

local function bloodlust_matches(ctx)
    if not cooldowns_enabled(ctx) then return false end
    if ctx.settings and ctx.settings.enhancement_cd_bloodlust == false then return false end
    if not enh_state.in_combat then return false end
    if enh_state.has_bloodlust then return false end
    if not enh_state.bloodlust_ready then return false end
    return NS.action_matches(ctx, BLOODLUST_ACTION)
end

local function mana_tide_totem_matches(ctx)
    if not cooldowns_enabled(ctx) then return false end
    if ctx.settings and ctx.settings.enhancement_cd_mana_tide == false then return false end
    if not enh_state.mana_tide_totem_ready then return false end
    if (enh_state.mana_pct or 100) > 60 then return false end
    return NS.action_matches(ctx, MANA_TIDE_TOTEM_ACTION)
end

local function natures_swiftness_matches(ctx)
    if not enh_state.natures_swiftness_ready then return false end
    return NS.action_matches(ctx, NATURES_SWIFTNESS_ACTION)
end

--- Primary offensive matches
local function stormstrike_matches(ctx)
    if not enh_state.stormstrike_ready then return false end
    -- Research: Mana < 10%: all spells forbidden (auto-attack only)
    if enh_state.mana_emergency then return false end
    -- Research: Mana < 20%: Stormstrike still allowed, shocks gated separately
    return NS.action_matches(ctx, STORMSTRIKE_ACTION)
end

local function flame_shock_matches(ctx)
    if not enh_state.flame_shock_ready then return false end
    -- Hold shocks OOC when Shamanistic Focus proc is desired (mana efficiency)
    if enh_state.hold_shocks_focus and not enh_state.in_combat then return false end
    -- Skip shock spending at mana floor — auto-attack conservation (Research: Mana < 20%)
    if enh_state.mana_low then return false end
    -- Multi-target FS in AoE: when enabled, apply to any enemy without the DoT
    if enh_state.fs_multi_target and enh_state.effective_mode == "aoe" and enh_state.target_has_flame_shock then
        -- Current target already has FS — skip if there are other targets available (they'll get dotted on tab)
        return false
    end
    -- Refresh when <3s remaining or not active
    if enh_state.target_has_flame_shock and enh_state.flame_shock_remains > 3 then return false end
    return NS.action_matches(ctx, FLAME_SHOCK_ACTION)
end

local function earth_shock_matches(ctx)
    -- Interrupt mode
    if enh_state.earth_shock_mode == "interrupts" then
        if not should_interrupt_target(ctx) then return false end
        -- Validate range: Earth Shock has 20yd range; skip if target is out of range
        local target = ctx.target
        if not target then return false end
        local dist = target.get_distance and target:get_distance(NS.PLAYER_UNIT or ctx.me)
        if dist and dist > 20 then return false end
        return NS.spell_ready(SPELLS.EarthShock, target, { expected_cooldown = 6 })
    end
    -- DPS mode: only cast if Flame Shock DoT is active on target (FrostByte v2.0.1)
    if enh_state.earth_shock_mode == "dps" then
        if not enh_state.earth_shock_ready then return false end
        -- Hold shocks OOC when Shamanistic Focus proc is desired
        if enh_state.hold_shocks_focus and not enh_state.in_combat then return false end
        if enh_state.mana_low then return false end
        if not enh_state.target_has_flame_shock then return false end
        return NS.action_matches(ctx, EARTH_SHOCK_ACTION)
    end
    return false
end

local function frost_shock_matches(ctx)
    if not enh_state.frost_shock_ready then return false end
    -- Hold shocks OOC when Shamanistic Focus proc is desired
    if enh_state.hold_shocks_focus and not enh_state.in_combat then return false end
    if enh_state.mana_low then return false end
    return NS.action_matches(ctx, FROST_SHOCK_ACTION)
end

local function chain_lightning_matches(ctx)
    if not enh_state.chain_lightning_ready then return false end
    -- AoE mode: CL if enough enemies
    if enh_state.effective_mode == "single" and enh_state.enemy_count < 2 then return false end
    return NS.action_matches(ctx, CHAIN_LIGHTNING_ACTION)
end

local function lightning_bolt_matches(ctx)
    if not enh_state.lightning_bolt_ready then return false end
    -- v1.1.5: OOC ranged pulls only — once in combat, commit to melee rotation
    if enh_state.in_combat then return false end
    return NS.action_matches(ctx, LIGHTNING_BOLT_ACTION)
end

--- Self-heal matches
local function lesser_healing_wave_matches(ctx)
    if not enh_state.lesser_healing_wave_ready then return false end
    if (enh_state.hp_pct or 100) > enh_state.self_heal_hp then return false end
    return NS.action_matches(ctx, LESSER_HEALING_WAVE_ACTION)
end

local function chain_heal_matches(ctx)
    if not enh_state.chain_heal_ready then return false end
    if (enh_state.hp_pct or 100) > enh_state.chain_heal_hp then return false end
    return NS.action_matches(ctx, CHAIN_HEAL_ACTION)
end

--- Gift of the Naaru (v1.1.1: Draenei racial heal)
local function gift_of_the_naaru_matches(ctx)
    if not enh_state.gift_of_the_naaru_enabled then return false end
    if not enh_state.gift_of_the_naaru_ready then return false end
    if (enh_state.hp_pct or 100) > enh_state.self_heal_hp then return false end
    return true
end

local function gift_of_the_naaru_execute(ctx)
    return NS.try_cast(SPELLS.GiftOfTheNaaru, NS.PLAYER_UNIT, "[ENHANCEMENT] Gift of the Naaru")
end

--- Ghost Wolf OOC
local function ghost_wolf_matches(ctx)
    -- v1.2.1: respect global OOC Buffs toggle
    if ctx.settings and ctx.settings.use_ooc_buffs == false then return false end
    if not enh_state.ghost_wolf_ooc then return false end
    if enh_state.in_combat then return false end
    if enh_state.has_ghost_wolf then return false end
    if not enh_state.ghost_wolf_ready then return false end
    if ctx.is_mounted then return false end
    -- Don't shift if we have a target in range
    local target = ctx.target
    if target and target:is_valid() and target:get_distance() and target:get_distance() <= 30 then return false end
    return true
end

-- ============================================================================
-- Totem executes
-- ============================================================================
local function totem_try_cast(spell, label, state_field, state_val)
    if NS.try_cast(spell, NS.PLAYER_UNIT, label) then
        if state_field then
            totem_state[state_field] = enh_state.now_ms
        end
        if state_val then
            totem_state[state_field] = state_val
        end
        return true
    end
    return false
end

local function earth_totem_execute()
    local s = enh_state.earth_totem_desired or "strength"
    if s == "strength" then
        return totem_try_cast(SPELLS.StrengthOfEarthTotem, "[ENHANCEMENT] Strength of Earth Totem", "last_strength_ms", "enh_state.now_ms")
    elseif s == "stoneskin" then
        return totem_try_cast(SPELLS.StoneskinTotem, "[ENHANCEMENT] Stoneskin Totem", "last_stoneskin_ms", "enh_state.now_ms")
    end
    return false
end

local function water_totem_execute()
    local s = enh_state.water_totem_desired or "mana_spring"
    if s == "mana_spring" then
        return totem_try_cast(SPELLS.ManaSpringTotem, "[ENHANCEMENT] Mana Spring Totem", "last_mana_ms", "enh_state.now_ms")
    elseif s == "healing_stream" then
        return totem_try_cast(SPELLS.HealingStreamTotem, "[ENHANCEMENT] Healing Stream Totem", "last_healing_stream_ms", "enh_state.now_ms")
    end
    return false
end

local function fire_totem_execute()
    local s = enh_state.fire_totem_desired or "searing"
    if s == "searing" then
        if totem_try_cast(SPELLS.SearingTotem, "[ENHANCEMENT] Searing Totem", "last_fire_ms", "enh_state.now_ms") then
            totem_state.fire_nova_active = false
            totem_state.fire_totem_type = "searing"
            return true
        end
    elseif s == "magma" then
        if totem_try_cast(SPELLS.MagmaTotem, "[ENHANCEMENT] Magma Totem", "last_fire_ms", "enh_state.now_ms") then
            totem_state.fire_nova_active = false
            totem_state.fire_totem_type = "magma"
            return true
        end
    elseif s == "fire_nova" then
        if totem_try_cast(SPELLS.FireNovaTotem, "[ENHANCEMENT] Fire Nova Totem", "last_fire_ms", "enh_state.now_ms") then
            totem_state.fire_nova_active = true
            totem_state.fire_totem_type = "fire_nova"
            totem_state.last_fire_nova_swap_ms = enh_state.now_ms
            return true
        end
    end
    return false
end

local function fire_nova_replacement_execute()
    if totem_try_cast(SPELLS.MagmaTotem, "[ENHANCEMENT] Fire Nova -> Magma replacement", "last_fire_ms", "enh_state.now_ms") then
        totem_state.fire_nova_active = false
        totem_state.fire_totem_type = "magma"
        return true
    end
    return false
end

local function windfury_twist_execute()
    if NS.try_cast(SPELLS.WindfuryTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Windfury Totem twist") then
        totem_state.next_air = "grace"
        totem_state.last_air_ms = totem_state.now_ms
        totem_state.last_windfury_ms = totem_state.now_ms
        return true
    end
    return false
end

local function grace_air_twist_execute()
    if NS.try_cast(SPELLS.GraceOfAirTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Grace of Air Totem twist") then
        totem_state.next_air = "windfury"
        totem_state.last_air_ms = totem_state.now_ms
        return true
    end
    return false
end

local function windfury_maintain_execute()
    if NS.try_cast(SPELLS.WindfuryTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Windfury Totem") then
        totem_state.last_windfury_ms = totem_state.now_ms
        return true
    end
    return false
end

local function earth_totem_resolve(ctx)
    local s = ctx.settings or {}
    local desired = s.enhancement_earth_totem or "strength"
    debug_log(ctx, "Earth totem check: combobox=" .. desired .. ", matches=" .. tostring(earth_totem_matches(ctx, desired)))
    if earth_totem_matches(ctx, desired) then
        enh_state.earth_totem_desired = desired
        local result = earth_totem_execute()
        if result then
            local spell_id = (desired == "strength" and SPELLS.StrengthOfEarthTotem.ids[1]) or (desired == "stoneskin" and SPELLS.StoneskinTotem.ids[1]) or 0
            debug_log(ctx, "Earth totem queued: " .. desired .. " (spell_id=" .. spell_id .. ")")
        end
        return result
    end
    return false
end

local function water_totem_resolve(ctx)
    local s = ctx.settings or {}
    local desired = s.enhancement_water_totem or "mana_spring"
    debug_log(ctx, "Water totem check: combobox=" .. desired .. ", matches=" .. tostring(water_totem_matches(ctx, desired)))
    if water_totem_matches(ctx, desired) then
        enh_state.water_totem_desired = desired
        local result = water_totem_execute()
        if result then
            local spell_id = (desired == "mana_spring" and SPELLS.ManaSpringTotem.ids[1]) or (desired == "healing_stream" and SPELLS.HealingStreamTotem.ids[1]) or 0
            debug_log(ctx, "Water totem queued: " .. desired .. " (spell_id=" .. spell_id .. ")")
        end
        return result
    end
    return false
end

local function fire_totem_resolve(ctx)
    local s = ctx.settings or {}
    local desired = s.enhancement_fire_totem or "searing"

    debug_log(ctx, "Fire totem check: combobox=" .. desired)

    -- Check Fire Nova replacement first
    if fire_nova_replacement_matches(ctx) then
        debug_log(ctx, "Fire Nova -> Magma replacement triggered")
        local result = fire_nova_replacement_execute()
        if result then
            debug_log(ctx, "Fire Nova replacement queued: MagmaTotem (spell_id=" .. (SPELLS.MagmaTotem and tostring(SPELLS.MagmaTotem.ids[1]) or "nil") .. ")")
        end
        return result
    end

    if fire_totem_matches(ctx, desired) then
        enh_state.fire_totem_desired = desired
        local result = fire_totem_execute()
        if result then
            local spell_id = (desired == "searing" and SPELLS.SearingTotem.ids[1]) or (desired == "magma" and SPELLS.MagmaTotem.ids[1]) or (desired == "fire_nova" and SPELLS.FireNovaTotem.ids[1]) or 0
            debug_log(ctx, "Fire totem queued: " .. desired .. " (spell_id=" .. spell_id .. ")")
        end
        return result
    end
    return false
end

-- ============================================================================
-- Weapon buff executes
-- ============================================================================
local function mh_weapon_execute(ctx)
    local s = ctx.settings or {}
    local choice = s.enhancement_main_hand_ench or "windfury"
    local spell_list
    if choice == "windfury" then spell_list = WINDFURY_WEAPON_SPELLS
    elseif choice == "flametongue" then spell_list = FLAMETONGUE_WEAPON_SPELLS
    elseif choice == "rockbiter" then spell_list = ROCKBITER_WEAPON_SPELLS
    elseif choice == "frostbrand" then spell_list = FROSTBRAND_WEAPON_SPELLS
    else return false end

    enh_state.weapon_buff_last_attempt = enh_state.now_ms
    if NS.try_cast(spell_list, NS.PLAYER_UNIT, "[ENHANCEMENT] MH " .. choice) then
        totem_state.last_mh_buff_ms = enh_state.now_ms
        totem_state.last_mh_buff_type = choice
        return true
    end
    return false
end

local function oh_weapon_execute(ctx)
    local s = ctx.settings or {}
    local choice = s.enhancement_off_hand_ench or "flametongue"
    local spell_list
    if choice == "windfury" then spell_list = WINDFURY_WEAPON_SPELLS
    elseif choice == "flametongue" then spell_list = FLAMETONGUE_WEAPON_SPELLS
    elseif choice == "rockbiter" then spell_list = ROCKBITER_WEAPON_SPELLS
    elseif choice == "frostbrand" then spell_list = FROSTBRAND_WEAPON_SPELLS
    else return false end

    enh_state.weapon_buff_last_attempt = enh_state.now_ms
    if NS.try_cast(spell_list, NS.PLAYER_UNIT, "[ENHANCEMENT] OH " .. choice) then
        totem_state.last_oh_buff_ms = enh_state.now_ms
        totem_state.last_oh_buff_type = choice
        return true
    end
    return false
end

-- ============================================================================
-- Ghost Wolf execute
-- ============================================================================
local function ghost_wolf_execute()
    return NS.try_cast(GHOST_WOLF_SPELL, NS.PLAYER_UNIT, "[ENHANCEMENT] Ghost Wolf")
end

-- ============================================================================
-- ============================================================================
-- Auto-attack matches
-- ============================================================================

---@param ctx table
---@return boolean
local function auto_attack_matches(ctx)
    if ctx.settings and ctx.settings.enhancement_auto_attack == false then return false end
    if not ctx.in_combat then return false end
    local target = ctx.target
    if not target or not target:is_valid() or target:is_dead() then return false end
    if auto_attack:is_auto_attacking(ctx.me) then return false end
    return true
end

local function auto_attack_execute(ctx)
    local target = ctx.target
    if not target then return false end
    return auto_attack:start_attack(target, auto_attack.ATTACK_TYPE.MELEE)
end

-- ============================================================================
-- Totemic Call matches (object scanning)
-- ============================================================================

---@param ctx table
---@return boolean
local function totemic_call_matches(ctx)
    if ctx.settings and ctx.settings.enhancement_auto_totemic_call == false then return false end
    if not enh_state.totemic_call_ready then return false end

    -- Throttle object scanning
    local now_ms = NS.game_time_ms()
    if now_ms - enh_state.last_totem_scan_ms < TOTEM_SCAN_INTERVAL_MS then return false end
    enh_state.last_totem_scan_ms = now_ms

    local me = ctx.me
    if not me then return false end
    local my_pos = me:get_position()
    if not my_pos then return false end

    -- Fast check: any totem slot active?
    local has_totem = false
    for slot = 1, 4 do
        local info = _get_totem_info(slot)
        if info and info.have_totem then
            has_totem = true
            break
        end
    end
    if not has_totem then return false end

    -- Scan visible objects for distant totems
    -- Filter by get_owner(): only summoned creatures (totems, not players/NPCs) have owners
    -- Lua proxy references can't be compared with ==, so we just check existence (nil-safe)
    local objects = _get_visible_objects()
    if not objects then return false end

    local threshold_sq = TOTEM_CALL_DISTANCE * TOTEM_CALL_DISTANCE  -- 400 (20 yards)

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() then
            -- Skip objects without an owner (players, NPCs, critters)
            local owner = obj:get_owner()
            if owner then
                local obj_pos = obj:get_position()
                if obj_pos then
                    local dx = obj_pos.x - my_pos.x
                    local dy = obj_pos.y - my_pos.y
                    if dx*dx + dy*dy > threshold_sq then
                        return true  -- Totem too far, recall
                    end
                end
            end
        end
    end

    return false
end

local function totemic_call_execute(ctx)
    return NS.try_cast(SPELLS.TotemicCall, NS.PLAYER_UNIT, "[ENHANCEMENT] Totemic Call")
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- 0. Mana emergency: auto-attack only, all spells forbidden (Research: Mana < 10%)
    { name = "ManaEmergencyWand",
      matches = function(ctx)
          if not enh_state.in_combat then return false end
          if not enh_state.mana_emergency then return false end
          return true
      end,
      execute = function(ctx)
          debug_log(ctx, "Mana emergency — auto-attack only")
          local target = ctx.target
          if auto_attack and target and target:is_valid() and not target:is_dead() then
              if not auto_attack:is_auto_attacking(ctx.me) then
                  auto_attack:start_attack(target, auto_attack.ATTACK_TYPE.MELEE)
              end
          end
          return true
      end
    },

    -- 1. Auto-attack (enforce on combat start)
    { name = "AutoAttack", matches = auto_attack_matches, execute = auto_attack_execute },

    -- 2. Ghost Wolf OOC
    { name = "GhostWolf", matches = ghost_wolf_matches, execute = ghost_wolf_execute },

    -- 3. Totems (priority: Totemic Call -> Fire Nova -> Earth -> Water -> Fire -> Air)
    { name = "TotemicCall", matches = totemic_call_matches, execute = totemic_call_execute },
    { name = "FireNovaReplacement", matches = fire_nova_replacement_matches, execute = fire_nova_replacement_execute },
    { name = "EarthTotem", matches = function(ctx) return earth_totem_matches(ctx, (ctx.settings or {}).enhancement_earth_totem or "strength") end, execute = function(ctx) return earth_totem_resolve(ctx) end },
    { name = "WaterTotem", matches = function(ctx) return water_totem_matches(ctx, (ctx.settings or {}).enhancement_water_totem or "mana_spring") end, execute = function(ctx) return water_totem_resolve(ctx) end },
    { name = "FireTotem", matches = function(ctx) return fire_totem_matches(ctx, (ctx.settings or {}).enhancement_fire_totem or "searing") end, execute = function(ctx) return fire_totem_resolve(ctx) end },

    -- 4. Air totem (twisting or maintain)
    { name = "WindfuryTotemTwist", matches = windfury_twist_matches, execute = windfury_twist_execute },
    { name = "GraceOfAirTotemTwist", matches = grace_air_twist_matches, execute = grace_air_twist_execute },
    { name = "WindfuryTotemMaintain", matches = windfury_maintain_matches, execute = windfury_maintain_execute },

    -- 5. Weapon buffs (OOC, per-slot)
    { name = "MHWeaponBuff", matches = mh_weapon_matches, execute = mh_weapon_execute },
    { name = "OHWeaponBuff", matches = oh_weapon_matches, execute = oh_weapon_execute },

    -- 6. Shields (smart auto-swap)
    { name = "WaterShield", matches = water_shield_matches, execute = water_shield_execute },
    { name = "LightningShield", matches = lightning_shield_matches, execute = lightning_shield_execute },

    -- 7. Cooldowns
    { name = "ShamanisticRage", matches = shamanistic_rage_matches, execute = function(ctx) return NS.action_execute(ctx, SHAMANISTIC_RAGE_ACTION, "[ENHANCEMENT]") end },
    { name = "Bloodlust", matches = bloodlust_matches, execute = function(ctx) return NS.action_execute(ctx, BLOODLUST_ACTION, "[ENHANCEMENT]") end },
    { name = "ManaTideTotem", matches = mana_tide_totem_matches, execute = function(ctx) return NS.action_execute(ctx, MANA_TIDE_TOTEM_ACTION, "[ENHANCEMENT]") end },
    { name = "NaturesSwiftness", matches = natures_swiftness_matches, execute = function(ctx) return NS.action_execute(ctx, NATURES_SWIFTNESS_ACTION, "[ENHANCEMENT]") end },

    -- 7b. Utility totems (fear break, spell absorb)
    { name = "TremorTotem", matches = tremor_totem_matches, execute = function(ctx) return NS.try_cast(TREMOR_TOTEM_SPELL, NS.PLAYER_UNIT, "[ENHANCEMENT] Tremor Totem") end },
    { name = "GroundingTotem", matches = grounding_totem_matches, execute = function(ctx) return NS.try_cast(SPELLS.GroundingTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Grounding Totem") end },

    -- v1.2.1: racials
    { name = "BloodFury", matches = blood_fury_matches, execute = function(ctx) return NS.action_execute(ctx, BLOOD_FURY_ACTION, "[ENHANCEMENT]") end },
    { name = "Berserking", matches = berserking_matches, execute = function(ctx) return NS.action_execute(ctx, BERSERKING_ACTION, "[ENHANCEMENT]") end },

    -- 8. Self-heal
    { name = "GiftOfTheNaaru", matches = gift_of_the_naaru_matches, execute = gift_of_the_naaru_execute },
    { name = "LesserHealingWave", matches = lesser_healing_wave_matches, execute = function(ctx) return NS.action_execute(ctx, LESSER_HEALING_WAVE_ACTION, "[ENHANCEMENT]") end },
    { name = "ChainHeal", matches = chain_heal_matches, execute = function(ctx) return NS.action_execute(ctx, CHAIN_HEAL_ACTION, "[ENHANCEMENT]") end },

    -- 9. Offensive priority (FrostByte v2.0.1: Flame Shock first, Earth Shock only while FS active)
    { name = "Stormstrike", matches = stormstrike_matches, execute = function(ctx) return NS.action_execute(ctx, STORMSTRIKE_ACTION, "[ENHANCEMENT]") end },
    { name = "FlameShock", matches = flame_shock_matches, execute = function(ctx) return NS.action_execute(ctx, FLAME_SHOCK_ACTION, "[ENHANCEMENT]") end },
    { name = "EarthShock", matches = earth_shock_matches, execute = function(ctx) return NS.action_execute(ctx, EARTH_SHOCK_ACTION, "[ENHANCEMENT]") end },
    { name = "FrostShock", matches = frost_shock_matches, execute = function(ctx) return NS.action_execute(ctx, FROST_SHOCK_ACTION, "[ENHANCEMENT]") end },

    -- 10. AoE / filler
    { name = "ChainLightning", matches = chain_lightning_matches, execute = function(ctx) return NS.action_execute(ctx, CHAIN_LIGHTNING_ACTION, "[ENHANCEMENT]") end },
    { name = "LightningBolt", matches = lightning_bolt_matches, execute = function(ctx) return NS.action_execute(ctx, LIGHTNING_BOLT_ACTION, "[ENHANCEMENT]") end },
}

NS.rotation_registry:register("enhancement", strategies, { get_state = build_state })
NS.log("Shaman enhancement rotation registered (FrostByte v2.0 port)")
return strategies
