-- Readability notes:
--   What: Hunter shared middleware.
--   When: dispatcher runs it before the selected playstyle.
--   Why: threat tools, Viper Sting, Freezing Trap, and aspect management are centralized
--        instead of duplicated in every spec.

-- Decision notes:
--   Middleware owns class-wide reactions such as interrupts, defensive checks, utility,
--   and recovery actions.
--   A middleware row should return true only when it actually performs work;
--   otherwise playstyle priorities must continue.
--   Safety gates are repeated here when the action can disrupt combat flow or break CC.
local NS = _G.EaxRotations
if not NS then return nil end
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local aspect_manager = require("shared/aspect_manager_sylvanas")
local SPELLS = NS.HunterSpells or {}
local strategies = {

    interrupt_manager.register_interrupt_spell("hunter", "SilencingShot", SPELLS),
    interrupt_manager.register_interrupt_spell("hunter", "ScatterShot", SPELLS),

    {
        name = "ThreatDrop",
        matches = function(context)
            if context.settings.use_threat_drop == false then return false end
            return NS.action_matches(context, { name = "ThreatDrop", spell = SPELLS.FeignDeath, target = "self", kind = "threat_drop", requires_target = false })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "ThreatDrop", spell = SPELLS.FeignDeath, target = "self", requires_target = false }, "[HUNTER]")
        end,
    },

    -- Viper Sting: drain mana from target when enabled and target uses mana
    {
        name = "ViperSting",
        matches = function(context)
            if context.settings.use_viper_sting_pve == false and context.settings.use_viper_sting_pvp == false then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end

            -- PvP Viper Sting check
            local is_pvp = context.is_pvp or false
            if is_pvp then
                if context.settings.use_viper_sting_pvp == false then return false end
            else
                if context.settings.use_viper_sting_pve == false then return false end
            end

            -- Check target has mana (skip non-mana users)
            local target = context.target
            if not target then return false end
            local power_type = target.get_power_type and target:get_power_type()
            if power_type ~= 0 then return false end -- 0 = MANA

            -- Check HP threshold — skip Viper Sting on low HP targets (focus damage instead)
            local hp_threshold = context.settings.viper_sting_hp_threshold or 30
            local target_hp = context.target_hp or 100
            if target_hp < hp_threshold then return false end

            -- Check for Viper Sting debuff overlap
            local VS_DEBUFF_IDS = { 3034, 14276, 14277, 14278, 14279, 25810 }
            for _, id in ipairs(VS_DEBUFF_IDS) do
                if NS.debuff_up and NS.debuff_up(target, id) then
                    -- Viper Sting already on target, check remaining duration
                    local remains = NS.debuff_remains and NS.debuff_remains(target, id) or 0
                    if remains > 2 then return false end
                end
            end

            -- Check target class is in Viper-Sting-eligible classes (PvP)
            if is_pvp then
                local VIPER_CLASSES = {
                    PALADIN = true, PRIEST = true, SHAMAN = true,
                    MAGE = true, WARLOCK = true, DRUID = true, HUNTER = true,
                }
                local target_class = target.get_class and target:get_class()
                if target_class then
                    local class_key = target_class -- enum value
                    -- Check class via power type (already confirmed mana) for PvE,
                    -- or via class enum for PvP
                    if type(class_key) == "string" and not VIPER_CLASSES[class_key] then
                        return false
                    end
                end
            end

            -- Use action_matches for spell readiness check
            return NS.action_matches(context, {
                name = "ViperSting",
                spell = SPELLS.ViperSting,
                setting = "use_viper_sting_pve",
                not_moving = false,
                requires_target = true,
            })
        end,
        execute = function(context)
            local is_pvp = context.is_pvp or false
            local prefix = is_pvp and "[HUNTER/PvP]" or "[HUNTER]"
            return NS.action_execute(context, {
                name = "ViperSting",
                spell = SPELLS.ViperSting,
                requires_target = true,
            }, prefix)
        end,
    },

    -- Freezing Trap: CC on adds when 2+ enemies and target not already frozen
    {
        name = "FreezingTrap",
        matches = function(context)
            if context.settings.freezing_trap_pve == false then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end

            -- Need 2+ enemies for trap logic
            local enemy_count = context.enemy_count or 0
            if enemy_count < 2 then return false end

            -- Don't trap if target is already frozen (Freezing Trap debuff = 3355)
            local FREEZING_TRAP_DEBUFF = { 3355, 22458, 26362 }
            local target = context.target
            if target then
                for _, id in ipairs(FREEZING_TRAP_DEBUFF) do
                    if NS.debuff_up and NS.debuff_up(target, id) then
                        return false
                    end
                end
            end

            return NS.action_matches(context, {
                name = "FreezingTrap",
                spell = SPELLS.FreezingTrap,
                setting = "freezing_trap_pve",
                requires_target = true,
                skip_range = true,
            })
        end,
        execute = function(context)
            return NS.action_execute(context, {
                name = "FreezingTrap",
                spell = SPELLS.FreezingTrap,
                requires_target = true,
                skip_range = true,
            }, "[HUNTER]")
        end,
    },

    -- Aspect of the Viper: switch to Viper when mana is low
    aspect_manager.viper_middleware_strategy(SPELLS),

    -- Aspect of the Hawk: switch back to Hawk when mana recovers
    aspect_manager.hawk_middleware_strategy(SPELLS),

    -- ============================================================================
    -- Misdirection (Tier 2 Gap Feature)
    -- ============================================================================
    -- Casts Misdirection on focus/pet at pull (< 6s combat) or when threat risk
    {
        name = "Misdirection",
        matches = function(context)
            if context.settings.use_misdirection == false then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end

            local combat_time = context.combat_time or 0
            local pull_window = context.settings.misdirection_pull_window or 6

            -- Only during pull window or if explicit threat risk
            if combat_time > pull_window then
                -- Could add threat risk check here if API available
                return false
            end

            -- Check Misdirection cooldown and if spell is learned
            local md_id = 34477  -- Misdirection spell ID
            if not (NS.is_spell_learned and NS.is_spell_learned(md_id)) then return false end
            if not (NS.spell_ready and NS.spell_ready(md_id)) then return false end

            -- Check if Misdirection buff is already active on player
            -- Misdirection buff = 34477
            if NS.has_buff and context.me then
                if NS.has_buff(context.me, 34477) then return false end
            end

            return true
        end,
        execute = function(context)
            local md_id = 34477
            local target = nil

            -- Try focus target first if enabled
            if context.settings.misdirection_on_focus ~= false then
                if NS.GetFocus then
                    target = NS.GetFocus()
                end
            end

            -- Fall back to pet if focus not available
            if not target and NS.GetPet then
                target = NS.GetPet()
            end

            -- Fall back to self if no valid target
            if not target then
                target = context.me
            end

            if target then
                return NS.try_cast(md_id, target, "[HUNTER] Misdirection", { skip_range = true })
            end

            return false
        end,
    },

}
NS.register_class_middleware("hunter", strategies)
return strategies