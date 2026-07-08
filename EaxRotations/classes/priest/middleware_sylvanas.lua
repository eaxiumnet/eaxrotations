-- Priest shared middleware.
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PriestSpells or {}
local OffensiveDispelDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")

-- Dispel Magic IDs by rank
local DISPEL_MAGIC_IDS = { 988, 527 }
-- Abolish Disease IDs by rank
local ABOLISH_DISEASE_IDS = { 552, 552, 552 }  -- Same ID in TBC

-- Throttle shared state for expensive enemy scans
local _last_priest_md_scan = 0
local _last_priest_threat_fade_scan = 0
local _last_priest_enhanced_fade_scan = 0

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

-- ============================================================================
-- Helper: scan nearby enemies and return the highest-priority dispel target
-- Caches result per tick to avoid double-scan (matches + execute).
-- ============================================================================
local _cached_dispel_unit = nil
local _cached_dispel_priority = 0
local _cached_dispel_fresh = false
local function get_offensive_dispel_target(context)
    if _cached_dispel_fresh then
        return _cached_dispel_unit, _cached_dispel_priority
    end
    _cached_dispel_unit = nil
    _cached_dispel_priority = 0
    local min_mana = spec_kit.setting_number(context, "offensive_dispel_mana_floor", 30)
    if (context.mana_pct or 100) < min_mana then return nil, 0 end
    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
    local best_unit, best_priority = nil, 0
    for _, enemy in ipairs(enemies) do
        if enemy then
            local id, priority = OffensiveDispelDB.find_best_dispel_target(enemy, NS)
            if id and priority and priority > best_priority then
                best_unit, best_priority = enemy, priority
                if best_priority >= OffensiveDispelDB.PRIORITY_CRITICAL then break end
            end
        end
    end
    _cached_dispel_unit = best_unit
    _cached_dispel_priority = best_priority
    _cached_dispel_fresh = true
    return best_unit, best_priority
end

-- ============================================================================
-- Helper: find the best Mana Burn target (enemy healer with most mana)
-- ============================================================================
local function find_mana_burn_target(context)
    local min_mana = spec_kit.setting_number(context, "mana_burn_mana_floor", 40)
    if (context.mana_pct or 100) < min_mana then return nil end
    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
    local best_target, best_mana = nil, 0
    for _, enemy in ipairs(enemies) do
        if enemy and OffensiveDispelDB.is_healer_class(enemy) then
            -- NS.unit_mana_pct does not exist; use raw game_object API with pcall
            local ok, power, max_power = pcall(function()
                local p = enemy.get_power and enemy:get_power(0) or 0
                local m = enemy.get_max_power and enemy:get_max_power(0) or 0
                return p, m
            end)
            local mana = (ok and max_power and max_power > 0) and (power / max_power * 100) or 0
            if mana > best_mana then
                best_target, best_mana = enemy, mana
            end
        end
    end
    return best_target, best_mana
end

local strategies = {

    interrupt_manager.register_interrupt_spell("priest", "Silence", SPELLS),
    interrupt_manager.register_interrupt_spell("priest", "PsychicScream", SPELLS),

    -- ============================================================================
    -- Mass Dispel: purge Divine Shield / Ice Block (PvP fight-winning purge)
    -- ============================================================================
    {
        name = "MassDispel",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_mass_dispel", true) then return false end
            if not context.in_combat then return false end
            -- Mana check: Mass Dispel costs ~36% base mana
            local mana_pct = context.mana_pct or 100
            local min_mana = spec_kit.setting_number(context, "mass_dispel_mana_floor", 50)
            if mana_pct < min_mana then return false end
            -- Spell check
            if not (NS.is_spell_learned and NS.is_spell_learned(SPELLS.MassDispel)) then return false end
            if not (NS.spell_ready and NS.spell_ready(SPELLS.MassDispel)) then return false end
            -- Throttle: expensive enemy iteration
            local now = NS.time_now and NS.time_now() or 0
            if now - (_last_priest_md_scan or 0) < 0.3 then return false end
            _last_priest_md_scan = now
            -- Scan enemies for Divine Shield / Ice Block
            local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    local should_md, buff_name = OffensiveDispelDB.should_mass_dispel(enemy, NS)
                    if should_md then
                        return true
                    end
                end
            end
            return false
        end,
        execute = function(context)
            -- Find the target with the critical buff (cast Mass Dispel on their position)
            -- Reuse the cached scan result from matches if still valid
            local now = NS.time_now and NS.time_now() or 0
            if now - (_last_priest_md_scan or 0) >= 0.3 then
                _last_priest_md_scan = now
            end
            local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    local should_md, buff_name = OffensiveDispelDB.should_mass_dispel(enemy, NS)
                    if should_md then
                        local pos = enemy.get_position and enemy:get_position() or nil
                        if pos and NS.try_cast_position then
                            return NS.try_cast_position(SPELLS.MassDispel, pos, enemy, "[PRIEST] Mass Dispel -> " .. (buff_name or "bubble"))
                        end
                        return false
                    end
                end
            end
            return false
        end,
    },

    -- ============================================================================
    -- Offensive Dispel: strip priority enemy buffs with Dispel Magic
    -- ============================================================================
    {
        name = "OffensiveDispel",
        matches = function(context)
            _cached_dispel_fresh = false  -- invalidate cache each tick
            if not spec_kit.setting_bool(context, "use_offensive_dispel", true) then return false end
            if not context.in_combat then return false end
            -- Check if Dispel Magic is available
            if not (NS.is_spell_learned and NS.is_spell_learned(SPELLS.DispelMagic)) then return false end
            if not (NS.spell_ready and NS.spell_ready(SPELLS.DispelMagic)) then return false end
            -- Find a valid dispel target (cached, no double-scan)
            local _, priority = get_offensive_dispel_target(context)
            return priority and priority >= OffensiveDispelDB.PRIORITY_MEDIUM
        end,
        execute = function(context)
            local target = get_offensive_dispel_target(context)
            if not target then return false end
            return NS.try_cast(SPELLS.DispelMagic, target, "[PRIEST] Offensive Dispel")
        end,
    },

    -- ============================================================================
    -- Mana Burn: pressure enemy healer mana pools
    -- ============================================================================
    {
        name = "ManaBurn",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_mana_burn", true) then return false end
            if not context.in_combat then return false end
            if context.is_moving then return false end
            -- Spell check
            if not (NS.is_spell_learned and NS.is_spell_learned(SPELLS.ManaBurn)) then return false end
            if not (NS.spell_ready and NS.spell_ready(SPELLS.ManaBurn)) then return false end
            -- Find healers with mana to burn
            local target, mana = find_mana_burn_target(context)
            if not target then return false end
            -- Only burn if healer has meaningful mana (>20% to avoid wasted casts)
            return mana and mana > 20
        end,
        execute = function(context)
            local target = find_mana_burn_target(context)
            if not target then return false end
            return NS.try_cast(SPELLS.ManaBurn, target, "[PRIEST] Mana Burn")
        end,
    },

    {
        name = "PvPPsychicScream",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_pvp_defensives", true) then return false end
            if NS.should_kite and not NS.should_kite(context) then return false end
            if not NS.spell_ready(SPELLS.PsychicScream, context.me, { skip_range = true }) then return false end
            if (NS.GetEnemiesCount and NS.GetEnemiesCount(8) or 0) < 2 then return false end
            return true
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.PsychicScream, context.me, "[PRIEST] Psychic Scream", { skip_range = true })
        end,
    },

    {
        name = "ThreatDrop",
        matches = function(context)
            if not context.in_combat then return false end
            if not spec_kit.setting_bool(context, "use_threat_drop", true) then return false end
            -- Only drop threat if a group ally is in combat nearby (Fade is useless solo)
            if not (NS.has_group_combat_ally_40 and NS.has_group_combat_ally_40()) then return false end
            if not (NS.spell_ready and SPELLS.Fade and NS.spell_ready(SPELLS.Fade, context.me, { skip_range = true })) then return false end
            if context.me and NS.has_buff and NS.has_buff(context.me, SPELLS.Fade) then return false end
            -- Throttle: expensive enemy iteration
            local now = NS.time_now and NS.time_now() or 0
            if now - _last_priest_threat_fade_scan < 0.5 then return false end
            _last_priest_threat_fade_scan = now
            local enemies = (NS.GetEnemiesInRange and NS.GetEnemiesInRange(20)) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    local ok, etarget = pcall(function() return enemy:get_target() end)
                    if ok and etarget and context.me and NS.same_unit and NS.same_unit(etarget, context.me) then
                        return true
                    end
                end
            end
            return false
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Fade, context.me, "[PRIEST] Fade", { skip_range = true })
        end,
    },

    -- ============================================================================
    -- Party Dispel: Dispel Magic (Tier 2 Gap Feature)
    -- ============================================================================
    {
        name = "PartyDispelMagic",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_party_dispel", true) then return false end
            if not context.in_combat then return false end
            
            -- Mana check
            local mana_pct = context.mana_pct or 100
            local min_mana = spec_kit.setting_number(context, "party_dispel_mana_floor", 30)
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
                    return NS.try_cast(dispel_id, member, "[PRIEST] Dispel Magic (Party)")
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
            if not spec_kit.setting_bool(context, "use_self_dispel", true) then return false end
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
            local min_mana = spec_kit.setting_number(context, "party_dispel_mana_floor", 30)
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
            if not spec_kit.setting_bool(context, "use_party_dispel", true) then return false end
            if not context.in_combat then return false end
            
            -- Check mana
            local mana_pct = context.mana_pct or 100
            local min_mana = spec_kit.setting_number(context, "party_dispel_mana_floor", 30)
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
                    return NS.try_cast(abolish_id, member, "[PRIEST] Abolish Disease (Party)")
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
            if not spec_kit.setting_bool(context, "use_shadowfiend", true) then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            
            -- Mana threshold check
            local mana_pct = context.mana_pct or 100
            local mana_threshold = spec_kit.setting_number(context, "shadowfiend_mana_threshold", 30)
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
            return NS.try_cast(sf_id, target, "[PRIEST] Shadowfiend")
        end,
    },

    -- ============================================================================
    -- Enhanced Fade: When visible enemy is targeting player (Tier 2 Gap Feature)
    -- ============================================================================
    {
        name = "EnhancedFade",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_enhanced_fade", true) then return false end
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
            -- Throttle: expensive enemy iteration
            local now2 = NS.time_now and NS.time_now() or 0
            if now2 - _last_priest_enhanced_fade_scan < 0.5 then return false end
            _last_priest_enhanced_fade_scan = now2
            local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(40) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    -- Check if this enemy is targeting us
                    local target_of_enemy = nil
                    local ok, val = pcall(function() return enemy:get_target() end)
                    if ok then target_of_enemy = val end
                    
                    if target_of_enemy and NS.same_unit and NS.same_unit(target_of_enemy, context.me) then
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

    -- ========================================================================
    -- POWER WORD: SHIELD (Combat defensive — self-shield when HP low)
    -- ========================================================================
    {
        name = "Priest_PWShield",
        priority = 850,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            local threshold = spec_kit.setting_number(context, "pws_hp", 0)
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                -- Check if Weakened Soul debuff present (can't re-shield)
                local ws_debuffs = { 6788 }
                if NS.has_debuff and context.me and NS.has_debuff(context.me, ws_debuffs) then return false end
                local spell = SPELLS.PowerWordShield or { id = { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }, name = "PowerWordShield" }
                if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.PowerWordShield or { id = { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }, name = "PowerWordShield" }
            return NS.try_cast(spell, context.me, "[PRIEST] Power Word: Shield", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- INNER FIRE (OOC self-buff — maintain armor/spirit buff)
    -- ========================================================================
    {
        name = "InnerFire",
        priority = 450,
        matches = function(context)
            if context.in_combat then return false end
            if not spec_kit.setting_bool(context, "auto_inner_fire", true) then return false end
            local if_buffs = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
            if NS.has_player_buff and NS.has_player_buff(if_buffs) then return false end
            local spell = SPELLS.InnerFire or { id = if_buffs, name = "InnerFire" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.InnerFire or { id = { 25431, 10952, 10951, 1006, 602, 7128, 588 }, name = "InnerFire" }
            return NS.try_cast(spell, context.me, "[PRIEST] Inner Fire", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- POWER WORD: FORTITUDE (OOC self-buff — maintain stamina buff)
    -- ========================================================================
    {
        name = "PowerWordFortitude",
        priority = 440,
        matches = function(context)
            if context.in_combat then return false end
            if not spec_kit.setting_bool(context, "auto_fortitude", true) then return false end
            local fort_buffs = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }
            if NS.has_player_buff and NS.has_player_buff(fort_buffs) then return false end
            local spell = SPELLS.PowerWordFortitude or { id = fort_buffs, name = "PowerWordFortitude" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.PowerWordFortitude or { id = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }, name = "PowerWordFortitude" }
            return NS.try_cast(spell, context.me, "[PRIEST] Power Word: Fortitude", { skip_range = true })
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return consumable_manager.should_check(context) end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("priest", strategies)
return strategies
