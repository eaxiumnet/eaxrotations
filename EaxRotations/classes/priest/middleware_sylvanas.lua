-- Priest shared middleware.

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local SPELLS = NS.PriestSpells or {}

-- Dispel Magic IDs by rank
local DISPEL_MAGIC_IDS = { 988, 527 }
-- Abolish Disease IDs by rank
local ABOLISH_DISEASE_IDS = { 552, 552, 552 }  -- Same ID in TBC

-- Check if debuff is magic type
local function has_magic_debuff_on_unit(unit)
    if not NS.has_debuff then return false end
    if not unit then return false end
    
    -- Common magic debuff IDs in TBC
    local MAGIC_DEBUFFS = {
        -- Curses
        [1010] = true, [1014] = true, [1022] = true,
        -- Magic DoTs
        [589] = true, [594] = true, [6074] = true,
        -- Magic CC
        [118] = true, [12824] = true, [12825] = true, [12826] = true,
        -- Magic debuffs from bosses
        [27819] = true, -- Mana Detonation (KT)
    }
    
    for id, _ in pairs(MAGIC_DEBUFFS) do
        if NS.has_debuff(unit, id) then return true end
    end
    return false
end

-- Check if debuff is disease type
local function has_disease_debuff_on_unit(unit)
    if not NS.has_debuff then return false end
    if not unit then return false end
    
    -- Common disease debuff IDs in TBC
    local DISEASE_IDS = {
        [3237] = true, [3238] = true, [3240] = true, [3242] = true,
        [3243] = true, [3245] = true, [3246] = true, [3247] = true, [3248] = true,
    }
    
    for id, _ in pairs(DISEASE_IDS) do
        if NS.has_debuff(unit, id) then return true end
    end
    return false
end

-- Get party members
local function get_party_members()
    if not NS.GetPartyMembers then return {} end
    return NS.GetPartyMembers() or {}
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

    interrupt_manager.register_interrupt_spell("priest", "Silence", SPELLS),
    interrupt_manager.register_interrupt_spell("priest", "PsychicScream", SPELLS),

    {
        name = "PvPPsychicScream",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_defensives == false then return false end
            if not NS.should_kite(context) then return false end
            if (NS.GetEnemiesCount and NS.GetEnemiesCount(8) or 0) < 2 then return false end
            return NS.action_matches(context, { name = "PvPPsychicScream", spell = SPELLS.PsychicScream, target = "self", requires_target = false })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "PvPPsychicScream", spell = SPELLS.PsychicScream, target = "self", requires_target = false }, "[PRIEST]")
        end,
    },

    {
        name = "ThreatDrop",
        matches = function(context)
            if context.settings.use_threat_drop == false then return false end
            return NS.action_matches(context, { name = "ThreatDrop", spell = SPELLS.Fade, target = "self", kind = "threat_drop", requires_target = false })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "ThreatDrop", spell = SPELLS.Fade, target = "self", requires_target = false }, "[PRIEST]")
        end,
    },

    -- ============================================================================
    -- Party Dispel: Dispel Magic (Tier 2 Gap Feature)
    -- ============================================================================
    {
        name = "PartyDispelMagic",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_party_dispel == false then return false end
            if not context.in_combat then return false end
            
            -- Mana check
            local mana_pct = context.mana_pct or 100
            local min_mana = settings.party_dispel_mana_floor or 30
            if mana_pct < min_mana then return false end
            
            -- Check if Dispel Magic is available
            local dispel_id = get_known_spell_id(DISPEL_MAGIC_IDS)
            if not dispel_id then return false end
            if not (NS.spell_ready and NS.spell_ready(dispel_id)) then return false end
            
            -- Check if anyone in party needs dispel
            local party = get_party_members()
            for _, member in ipairs(party) do
                if has_magic_debuff_on_unit(member) then
                    return true
                end
            end
            
            -- Check self
            if has_magic_debuff_on_unit(context.me) then
                return true
            end
            
            return false
        end,
        execute = function(context)
            local dispel_id = get_known_spell_id(DISPEL_MAGIC_IDS)
            if not dispel_id then return false end
            
            -- Priority: self first, then party
            if has_magic_debuff_on_unit(context.me) then
                return NS.try_cast(dispel_id, context.me, "[PRIEST] Dispel Magic (Self)", { skip_range = true })
            end
            
            -- Then party members
            local party = get_party_members()
            for _, member in ipairs(party) do
                if has_magic_debuff_on_unit(member) then
                    return NS.try_cast(dispel_id, member, "[PRIEST] Dispel Magic (Party)", { skip_range = true })
                end
            end
            
            return false
        end,
    },

    -- ============================================================================
    -- Self Dispel: Abolish Disease (Tier 2 Gap Feature)
    -- ============================================================================
    {
        name = "AbolishDisease",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_self_dispel == false then return false end
            if not context.in_combat then return false end
            if not context.me then return false end
            
            -- Check if disease debuff present
            if not has_disease_debuff_on_unit(context.me) then return false end
            
            -- Check if Abolish Disease is available
            local abolish_id = get_known_spell_id(ABOLISH_DISEASE_IDS)
            if not abolish_id then return false end
            if not (NS.spell_ready and NS.spell_ready(abolish_id)) then return false end
            
            -- Check mana
            local mana_pct = context.mana_pct or 100
            local min_mana = settings.party_dispel_mana_floor or 30
            if mana_pct < min_mana then return false end
            
            return true
        end,
        execute = function(context)
            local abolish_id = get_known_spell_id(ABOLISH_DISEASE_IDS)
            if not abolish_id then return false end
            return NS.try_cast(abolish_id, context.me, "[PRIEST] Abolish Disease", { skip_range = true })
        end,
    },

    -- ============================================================================
    -- Party Abolish Disease (Tier 2 Gap Feature)
    -- ============================================================================
    {
        name = "PartyAbolishDisease",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_party_dispel == false then return false end
            if not context.in_combat then return false end
            
            -- Check mana
            local mana_pct = context.mana_pct or 100
            local min_mana = settings.party_dispel_mana_floor or 30
            if mana_pct < min_mana then return false end
            
            -- Check if Abolish Disease is available
            local abolish_id = get_known_spell_id(ABOLISH_DISEASE_IDS)
            if not abolish_id then return false end
            if not (NS.spell_ready and NS.spell_ready(abolish_id)) then return false end
            
            -- Check if any party member has disease
            local party = get_party_members()
            for _, member in ipairs(party) do
                if has_disease_debuff_on_unit(member) then
                    return true
                end
            end
            
            return false
        end,
        execute = function(context)
            local abolish_id = get_known_spell_id(ABOLISH_DISEASE_IDS)
            if not abolish_id then return false end
            
            -- Cast on first party member with disease
            local party = get_party_members()
            for _, member in ipairs(party) do
                if has_disease_debuff_on_unit(member) then
                    return NS.try_cast(abolish_id, member, "[PRIEST] Abolish Disease (Party)", { skip_range = true })
                end
            end
            
            return false
        end,
    },

    -- ============================================================================
    -- Shadowfiend (Tier 2 Gap Feature)
    -- ============================================================================
    {
        name = "Shadowfiend",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_shadowfiend == false then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            
            -- Mana threshold check
            local mana_pct = context.mana_pct or 100
            local mana_threshold = settings.shadowfiend_mana_threshold or 30
            if mana_pct > mana_threshold then return false end
            
            -- Shadowfiend spell ID
            local sf_id = 34433
            if not (NS.is_spell_learned and NS.is_spell_learned(sf_id)) then return false end
            if not (NS.spell_ready and NS.spell_ready(sf_id)) then return false end
            
            -- Don't use on trivial/low-TTD targets
            local ttd = context.target_ttd or 999
            if ttd < 10 then return false end
            
            return true
        end,
        execute = function(context)
            local sf_id = 34433
            local target = context.target
            if not target then return false end
            return NS.try_cast(sf_id, target, "[PRIEST] Shadowfiend", { skip_range = true })
        end,
    },

    -- ============================================================================
    -- Enhanced Fade: When visible enemy is targeting player (Tier 2 Gap Feature)
    -- ============================================================================
    {
        name = "EnhancedFade",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_enhanced_fade == false then return false end
            if not context.in_combat then return false end
            
            -- Check if Fade is ready
            local fade_id = 586  -- Fade
            if not (NS.is_spell_learned and NS.is_spell_learned(fade_id)) then return false end
            if not (NS.spell_ready and NS.spell_ready(fade_id)) then return false end
            
            -- Check if Fade buff already active
            if NS.has_buff and context.me then
                if NS.has_buff(context.me, 586) then return false end
            end
            
            -- Check if any visible enemy is targeting player
            -- This is a simplified check - in practice might need more sophisticated threat detection
            local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(40) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    -- Check if this enemy is targeting us
                    local target_of_enemy = nil
                    local ok, val = pcall(function() return enemy:get_target() end)
                    if ok then target_of_enemy = val end
                    
                    if target_of_enemy and target_of_enemy == context.me then
                        return true
                    end
                end
            end
            
            return false
        end,
        execute = function(context)
            local fade_id = 586
            return NS.try_cast(fade_id, context.me, "[PRIEST] Fade (Enhanced)", { skip_range = true })
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return context.in_combat end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("priest", strategies)
return strategies
