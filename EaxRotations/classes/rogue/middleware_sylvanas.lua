-- Rogue shared middleware.

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.RogueSpells or {}
local CCBreakDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local CCGateDB = CCBreakDB  -- Same module for CC break + CC gate

-- Spell IDs by rank (newest first) for TBC
local EVASION_IDS = { 26669, 5277 }      -- Evasion
local CLOAK_IDS = { 31224 }               -- Cloak of Shadows
local VANISH_IDS = { 26889, 1857, 1856 } -- Vanish
local THISTLE_TEA_ID = 7676              -- Thistle Tea (item-based energy restore)
local _last_rogue_cc_scan = 0

-- Check if unit is melee attacker
local function is_melee_attacker(context)
    if not context or not context.target then return false end
    local target = context.target
    local class = nil
    local ok, val = pcall(function() return target:get_class() end)
    if ok then class = val end
    
    local MELEE_CLASSES = { WARRIOR = true, ROGUE = true, PALADIN = true, DRUID = true, SHAMAN = true }
    if class and MELEE_CLASSES[class] then return true end
    
    return false
end

-- Check if unit has magic debuff
local function has_magic_debuff()
    if not NS.has_debuff then return false end
    local me = NS.PLAYER_UNIT
    if not me then return false end
    
    -- Common magic debuff IDs in TBC (curses, magic dots, CC)
    local MAGIC_DEBUFFS = {
        -- Curses
        [1010] = true, [1014] = true, [1022] = true,
        -- Magic DoTs
        [589] = true, [594] = true, [6074] = true,
        -- Magic CC
        [118] = true, [12824] = true, [12825] = true, [12826] = true,
    }
    
    for id, _ in pairs(MAGIC_DEBUFFS) do
        if NS.has_debuff(me, id) then return true end
    end
    return false
end

-- Get highest known spell ID
local function get_known_spell_id(ids)
    if not NS or not NS.is_spell_learned then return nil end
    for _, id in ipairs(ids) do
        if NS.is_spell_learned(id) then return id end
    end
    return nil
end

-- AoE/cleave spell IDs for PvP CC gating (any rank learned = gate active)
local ROGUE_AOE_IDS = { 13877 }  -- Blade Flurry

local strategies = {

    interrupt_manager.register_interrupt_spell("rogue", "Kick", SPELLS),

    -- ============================================================================
    -- PvP: SHIV PURGE — dispel 1 magic buff via Wound Poison (BoP, PW:S, Ice Barrier)
    -- Shared warrior ShieldSlamPurge dispel pattern.
    -- Shiv is a 20-energy off-hand attack with 10s cooldown — no stance requirement.
    -- Requires off-hand weapon with Wound Poison applied for the dispel effect.
    -- ============================================================================
    {
        name = "RogueShivPurge",
        matches = function(context)
            if spec_kit.setting_bool(context, "use_shiv_purge", true) == false then return false end
            -- Skip entirely if Shiv not learned (level < 28)
            if not (NS.is_spell_learned and NS.is_spell_learned(5938)) then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not context.target then return false end
            if not (context.is_pvp or false) then return false end
            -- Shiv is a melee off-hand attack — must be in range
            if not context.in_melee_range then return false end
            -- Target must be a player (PvP only — Shiv purge is niche in PvE)
            if spec_kit.setting_bool(context, "shiv_purge_pvp_only", true) ~= false then
                local ok, is_player = pcall(function() return context.target:is_player() end)
                if not (ok and is_player) then return false end
            end
            -- Check if target has a priority dispellable buff
            local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(context.target, NS)
            if not best_id then return false end
            context._shiv_purge_name = best_name
            return true
        end,
        execute = function(context)
            local name = context._shiv_purge_name or "buff"
            return NS.try_cast(SPELLS.Shiv, context.target, "[ROGUE] Shiv purge → " .. name, { expected_cooldown = 10 })
        end,
    },

    -- ============================================================================
    -- CC Break: preemptively Cloak or Vanish when enemy casts CC at us
    -- ============================================================================
    {
        name = "RogueCCBreak",
        matches = function(context)
            if spec_kit.setting_bool(context, "use_cc_break", true) == false then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Throttle: expensive enemy iteration
            local now = NS.time_now and NS.time_now() or 0
            if now - _last_rogue_cc_scan < 0.3 then return false end
            _last_rogue_cc_scan = now
            -- Preemptive scan: enemy casting CC at us → Cloak (magic immunity) or Vanish (escape)
            local cloak_id = get_known_spell_id(CLOAK_IDS)
            local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    local is_casting_cc = CCBreakDB.is_casting_preemptive_cc(enemy)
                    if is_casting_cc then
                        local ok, etarget = pcall(function() return enemy:get_target() end)
                        if ok and etarget and NS.same_unit and NS.same_unit(etarget, me) then
                            if cloak_id and NS.spell_ready and NS.spell_ready(cloak_id) then
                                return true
                            end
                            -- Vanish: escape everything (emergency option)
                            local vanish_id = get_known_spell_id(VANISH_IDS)
                            if vanish_id and NS.spell_ready and NS.spell_ready(vanish_id) then
                                return true
                            end
                            break
                        end
                    end
                end
            end
            -- Fallback: player is already under breakable CC — Cloak to dispel, Vanish to escape
            local has_cc = CCBreakDB.is_breakable_cc_active(me, NS)
            if has_cc then
                if cloak_id and NS.spell_ready and NS.spell_ready(cloak_id) then return true end
                local vanish_id = get_known_spell_id(VANISH_IDS)
                if vanish_id and NS.spell_ready and NS.spell_ready(vanish_id) then return true end
            end
            return false
        end,
        execute = function(context)
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Prefer Cloak of Shadows (magic immunity)
            local cloak_id = get_known_spell_id(CLOAK_IDS)
            if cloak_id and NS.spell_ready and NS.spell_ready(cloak_id) then
                return NS.try_cast(cloak_id, me, "[ROGUE] Cloak → CC Break", { skip_range = true })
            end
            -- Fallback: Vanish
            local vanish_id = get_known_spell_id(VANISH_IDS)
            if vanish_id and NS.spell_ready and NS.spell_ready(vanish_id) then
                return NS.try_cast(vanish_id, me, "[ROGUE] Vanish → CC Break", { skip_range = true })
            end
            return false
        end,
    },

    {
        name = "ThreatDrop",
        matches = function(context)
            if not context.in_combat then return false end
            if spec_kit.setting_bool(context, "use_threat_drop", true) == false then return false end
            return true
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Feint, context.me, "[ROGUE] Feint", { skip_range = true })
        end,
    },

    -- ============================================================================
    -- Emergency Toolkit (Tier 2 Gap Feature)
    -- ============================================================================

    -- Cloak of Shadows: for dangerous magic debuffs / caster burst
    {
        name = "CloakOfShadows",
        matches = function(context)
            if spec_kit.setting_bool(context, "rogue_use_cloak", true) == false then return false end
            
            local hp_threshold = spec_kit.setting_number(context, "rogue_cloak_hp", 45)
            local hp = context.player_hp or 100
            if hp > hp_threshold then return false end
            
            -- Only if magic debuff present or against caster
            if not has_magic_debuff() then
                if not context.target then return false end
                local class = nil
                local ok, val = pcall(function() return context.target:get_class() end)
                if ok then class = val end
                if class ~= "MAGE" and class ~= "WARLOCK" and class ~= "PRIEST" then
                    return false
                end
            end
            
            local cloak_id = get_known_spell_id(CLOAK_IDS)
            if not cloak_id then return false end
            if not (NS.spell_ready and NS.spell_ready(cloak_id)) then return false end
            
            return true
        end,
        execute = function(context)
            local cloak_id = get_known_spell_id(CLOAK_IDS)
            if not cloak_id then return false end
            return NS.try_cast(cloak_id, context.me, "[ROGUE] Cloak of Shadows", { skip_range = true })
        end,
    },

    -- Evasion: at low HP vs melee
    {
        name = "Evasion",
        matches = function(context)
            if spec_kit.setting_bool(context, "rogue_use_evasion", true) == false then return false end
            
            local hp_threshold = spec_kit.setting_number(context, "rogue_evasion_hp", 35)
            local hp = context.player_hp or 100
            if hp > hp_threshold then return false end
            
            -- Only vs melee attackers
            if not is_melee_attacker(context) then return false end
            
            local evasion_id = get_known_spell_id(EVASION_IDS)
            if not evasion_id then return false end
            if not (NS.spell_ready and NS.spell_ready(evasion_id)) then return false end
            
            -- Check if Evasion buff already active
            if NS.has_buff and context.me then
                if NS.has_buff(context.me, evasion_id) then return false end
            end
            
            return true
        end,
        execute = function(context)
            local evasion_id = get_known_spell_id(EVASION_IDS)
            if not evasion_id then return false end
            return NS.try_cast(evasion_id, context.me, "[ROGUE] Evasion", { skip_range = true })
        end,
    },

    -- Vanish: emergency defensive at very low HP
    {
        name = "VanishDefensive",
        matches = function(context)
            if spec_kit.setting_bool(context, "rogue_use_vanish_defensive", true) == false then return false end
            
            local hp_threshold = spec_kit.setting_number(context, "rogue_vanish_hp", 20)
            local hp = context.player_hp or 100
            if hp > hp_threshold then return false end
            
            -- Only in combat
            if not context.in_combat then return false end
            
            -- Don't vanish in raid boss fights unless explicitly enabled
            if (context.is_raid_boss or false) and spec_kit.setting_bool(context, "rogue_vanish_in_raid", false) ~= true then
                return false
            end
            
            local vanish_id = get_known_spell_id(VANISH_IDS)
            if not vanish_id then return false end
            if not (NS.spell_ready and NS.spell_ready(vanish_id)) then return false end
            
            return true
        end,
        execute = function(context)
            local vanish_id = get_known_spell_id(VANISH_IDS)
            if not vanish_id then return false end
            return NS.try_cast(vanish_id, context.me, "[ROGUE] Vanish (Emergency)", { skip_range = true })
        end,
    },

    -- Thistle Tea: energy recovery during burst
    {
        name = "ThistleTea",
        matches = function(context)
            if spec_kit.setting_bool(context, "rogue_use_thistle_tea", true) == false then return false end
            if not context.in_combat then return false end
            
            -- Check energy (low energy during burst)
            local energy = context.energy or 100
            local threshold = spec_kit.setting_number(context, "rogue_thistle_tea_energy", 30)
            if energy > threshold then return false end
            
            -- Check if Thistle Tea item is available
            -- This is item-based, need to check inventory
            if NS.has_item then
                if not NS.has_item(THISTLE_TEA_ID) then return false end
            end
            
            -- Only use during burst or when we need energy
            if not context.should_burst and energy > 20 then return false end
            
            return true
        end,
        execute = function(context)
            if NS.use_item then
                return NS.use_item(THISTLE_TEA_ID, context.me, "[ROGUE] Thistle Tea")
            end
            return false
        end,
    },

    -- ============================================================================
    -- PvP CC Gate: placed at END of middleware so defensives (Evasion, Vanish, Cloak) still fire.
    -- Only gates spec-level AoE/cleave (Blade Flurry).
    -- ============================================================================
    {
        name = "PvPCCGate",
        matches = function(context)
            if spec_kit.setting_bool(context, "use_pvp_cc_gating", true) == false then return false end
            if not context.in_combat then return false end
            local has_aoe = false
            for _, id in ipairs(ROGUE_AOE_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then
                    has_aoe = true
                    break
                end
            end
            if not has_aoe then return false end
            return CCGateDB.is_any_nearby_enemy_under_cc(NS, 15)
        end,
        execute = function() return true end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return consumable_manager.should_check(context) end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("rogue", strategies)
return strategies
