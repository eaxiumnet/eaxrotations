-- Readability notes:
--   What: Warlock shared middleware.
--   When: dispatcher runs it before the selected playstyle.
--   Why: threat tools are centralized instead of duplicated in every spec.
--   Safety: threat drops require group combat and an ally within 40 yards; never solo.

-- Decision notes:
--   Middleware owns class-wide reactions such as interrupts, defensive checks, utility, and recovery actions.
--   A middleware row should return true only when it actually performs work; otherwise playstyle priorities must continue.
--   Safety gates are repeated here when the action can disrupt combat flow or break crowd control.
local NS = _G.EaxRotations
if not NS then return nil end
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local SPELLS = NS.WarlockSpells or {}
local strategies = {

    interrupt_manager.register_interrupt_spell("warlock", "SpellLock", SPELLS),

    {
        name = "PvPHowlofTerror",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_defensives == false then return false end
            if not NS.should_kite(context) then return false end
            if (NS.GetEnemiesCount and NS.GetEnemiesCount(8) or 0) < 2 then return false end
            return NS.action_matches(context, { name = "PvPHowlofTerror", spell = SPELLS.HowlofTerror, target = "self", requires_target = false })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "PvPHowlofTerror", spell = SPELLS.HowlofTerror, target = "self", requires_target = false }, "[WARLOCK]")
        end,
    },

    {
        name = "ThreatDrop",
        matches = function(context)
            if context.settings.use_threat_drop == false then return false end
            return NS.action_matches(context, { name = "ThreatDrop", spell = SPELLS.Soulshatter, target = "self", kind = "threat_drop", requires_target = false })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "ThreatDrop", spell = SPELLS.Soulshatter, target = "self", requires_target = false }, "[WARLOCK]")
        end,
    },

    -- ========================================================================
    -- DEATH COIL (Emergency heal + fear — highest priority in combat)
    -- ========================================================================
    {
        name = "Warlock_DeathCoil",
        priority = 1000,
        is_defensive = true,
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            local threshold = settings.death_coil_hp or 0
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                return true
            end
            return false
        end,
        execute = function(context)
            -- Death Coil is a fear effect that heals the warlock when it damages the enemy
            -- Cast on enemy target, the self-heal is a passive effect
            local target = context.target
            if not target then return false end
            local spell = SPELLS.DeathCoil or { id = { 6789, 17928, 17924, 17923 }, name = "DeathCoil" }
            if NS.spell_ready and NS.spell_ready(spell, target, {}) then
                return NS.try_cast(spell, target, "[WARRIOR] Death Coil")
            end
            return false
        end,
    },

    -- ========================================================================
    -- HEALTHSTONE (Recovery - Healthstone then Healing Potion)
    -- ========================================================================
    {
        name = "Warlock_Healthstone",
        priority = 850,
        is_defensive = true,
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            local threshold = settings.healthstone_hp or 0
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                return true
            end
            return false
        end,
        execute = function(context)
            -- Try Healthstone first (item-based, has CD)
            -- Healthstone items: 190005 (Healthstone - Fel), 190006 (Healthstone - Master), 190007 (Healthstone - Major)
            local healthstone_ids = { 190005, 190006, 190007, 22116, 18892, 11766 }
            local used_item = false
            if NS.use_item and context.me then
                for _, item_id in ipairs(healthstone_ids) do
                    if NS.use_item(item_id, context.me) then
                        used_item = true
                        break
                    end
                end
            end
            if used_item then return true end

            -- Fallback: Healing Potion if no Healthstone used
            local potion_ids = { 18707, 17182, 39213, 13446, 5665 }
            if NS.use_item and context.me then
                for _, item_id in ipairs(potion_ids) do
                    if NS.use_item(item_id, context.me) then
                        return true
                    end
                end
            end
            return false
        end,
    },

}
NS.register_class_middleware("warlock", strategies)
return strategies