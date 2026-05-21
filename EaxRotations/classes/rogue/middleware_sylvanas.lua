-- Rogue shared middleware.
-- ============================================================================
-- What: Rogue shared middleware for emergency defensives and consumables
-- When: Per tick
-- Why: Keeps survivability tools and Thistle Tea separate from spec priorities
-- Safety: Settings nil-guards, pcall on class/spell lookups, item availability checks
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local SPELLS = NS.RogueSpells or {}

-- Spell IDs by rank (newest first) for TBC
local EVASION_IDS = { 26669, 5277 }      -- Evasion
local CLOAK_IDS = { 31224 }               -- Cloak of Shadows
local VANISH_IDS = { 26889, 1857, 1856 } -- Vanish
local THISTLE_TEA_ID = 7676              -- Thistle Tea (item-based energy restore)

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

local strategies = {

    interrupt_manager.register_interrupt_spell("rogue", "Kick", SPELLS),

    {
        name = "ThreatDrop",
        matches = function(context)
            if context.settings.use_threat_drop == false then return false end
            return NS.action_matches(context, { name = "ThreatDrop", spell = SPELLS.Feint, target = "self", kind = "threat_drop", requires_target = false })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "ThreatDrop", spell = SPELLS.Feint, target = "self", requires_target = false }, "[ROGUE]")
        end,
    },

    -- ============================================================================
    -- Emergency Toolkit (Tier 2 Gap Feature)
    -- ============================================================================

    -- Cloak of Shadows: for dangerous magic debuffs / caster burst
    {
        name = "CloakOfShadows",
        matches = function(context)
            local settings = context.settings or {}
            if settings.rogue_use_cloak == false then return false end
            
            local hp_threshold = settings.rogue_cloak_hp or 45
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
            local settings = context.settings or {}
            if settings.rogue_use_evasion == false then return false end
            
            local hp_threshold = settings.rogue_evasion_hp or 35
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
            local settings = context.settings or {}
            if settings.rogue_use_vanish_defensive == false then return false end
            
            local hp_threshold = settings.rogue_vanish_hp or 20
            local hp = context.player_hp or 100
            if hp > hp_threshold then return false end
            
            -- Only in combat
            if not context.in_combat then return false end
            
            -- Don't vanish in raid boss fights unless explicitly enabled
            if context.is_raid_boss and settings.rogue_vanish_in_raid ~= true then
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
            local settings = context.settings or {}
            if settings.rogue_use_thistle_tea == false then return false end
            if not context.in_combat then return false end
            
            -- Check energy (low energy during burst)
            local energy = context.energy or 100
            local threshold = settings.rogue_thistle_tea_energy or 30
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

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return context.in_combat end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("rogue", strategies)
return strategies
