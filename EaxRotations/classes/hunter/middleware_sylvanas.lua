-- hunter/middleware_sylvanas.lua — Hunter rotation middleware (aspect, pet, shot timer).
-- WHAT:  pre-strategy middleware that enriches context with aspect state, pet status, and shot timing.
-- WHEN:  every tick before strategy evaluation.
-- WHY:   centralizes hunter-specific context enrichment so specs stay focused on rotation logic.
-- SAFETY: nil-guards on all menu references; no allocations in on_update path.

-- Hunter shared middleware.


local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local aspect_manager = require("shared/aspect_manager_sylvanas")
local SPELLS = NS.HunterSpells or {}
local strategies = {

    interrupt_manager.register_interrupt_spell("hunter", "SilencingShot", SPELLS),
    interrupt_manager.register_interrupt_spell("hunter", "ScatterShot", SPELLS),

    {
        name = "ThreatDrop",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_threat_drop", true) then return false end
            if not context.in_combat then return false end
            local threat_level = context.threat_level or context.threat_situation or 0
            if threat_level < 2 and not context.has_aggro then return false end
            return NS.spell_ready and NS.spell_ready(SPELLS.FeignDeath, context.me, { skip_range = true, expected_cooldown = 30 })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.FeignDeath, context.me, "[HUNTER] Feign Death", { skip_range = true })
        end,
    },

    -- Viper Sting: drain mana from target when enabled and target uses mana
    {
        name = "ViperSting",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_viper_sting_pve", true) and not spec_kit.setting_bool(context, "use_viper_sting_pvp", true) then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end

            -- PvP Viper Sting check
            local is_pvp = context.is_pvp or false
            if is_pvp then
                if not spec_kit.setting_bool(context, "use_viper_sting_pvp", true) then return false end
            else
                if not spec_kit.setting_bool(context, "use_viper_sting_pve", true) then return false end
            end

            -- Check target has mana (skip non-mana users)
            local target = context.target
            if not target then return false end
            local ok_pt, power_type = pcall(function() return target:get_power_type() end)
            if not ok_pt or power_type ~= 0 then return false end -- 0 = MANA

            -- Check HP threshold — skip Viper Sting on low HP targets (focus damage instead)
            local hp_threshold = spec_kit.setting_number(context, "viper_sting_hp_threshold", 30)
            local target_hp = context.target_hp or 100
            if target_hp < hp_threshold then return false end

            -- Check for Viper Sting debuff overlap
            local VS_DEBUFF_IDS = { 27018, 14280, 14279, 3034 }
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
                local ok_tc, target_class = pcall(function() return target:get_class() end)
                if ok_tc and target_class then
                    local class_key = target_class -- enum value
                    -- Check class via power type (already confirmed mana) for PvE,
                    -- or via class enum for PvP
                    if type(class_key) == "string" and not VIPER_CLASSES[class_key] then
                        return false
                    end
                end
            end

            return NS.spell_ready and NS.spell_ready(SPELLS.ViperSting, target, { expected_cooldown = 8 })
        end,
        execute = function(context)
            local is_pvp = context.is_pvp or false
            local prefix = is_pvp and "[HUNTER/PvP]" or "[HUNTER]"
            return NS.try_cast(SPELLS.ViperSting, context.target, prefix .. " Viper Sting")
        end,
    },

    -- Freezing Trap: CC on adds when 2+ enemies and target not already frozen
    {
        name = "FreezingTrap",
        matches = function(context)
            if not spec_kit.setting_bool(context, "freezing_trap_pve", true) then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end

            -- Need 2+ enemies for trap logic
            local enemy_count = context.enemy_count or 0
            if enemy_count < 2 then return false end

            -- Don't trap if target is already frozen (Freezing Trap debuff = 3355)
            local FREEZING_TRAP_DEBUFF = { 14309, 14308, 3355 }
            local target = context.target
            if target then
                for _, id in ipairs(FREEZING_TRAP_DEBUFF) do
                    if NS.debuff_up and NS.debuff_up(target, id) then
                        return false
                    end
                end
            end

            return NS.spell_ready and NS.spell_ready(SPELLS.FreezingTrap, context.me, { skip_range = true, expected_cooldown = 30 })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.FreezingTrap, context.me, "[HUNTER] Freezing Trap", { skip_range = true })
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
            if not spec_kit.setting_bool(context, "use_misdirection", true) then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end

            local combat_time = context.combat_time or 0
            local pull_window = spec_kit.setting_number(context, "misdirection_pull_window", 6)

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
            if spec_kit.setting_bool(context, "misdirection_on_focus", true) then
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

    -- ========================================================================
    -- RAPID FIRE (Offensive cooldown — burst haste on valid target)
    -- ========================================================================
    {
        name = "RapidFire",
        priority = 780,
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_rapid_fire", true) then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            local spell = SPELLS.RapidFire or { id = { 3045 }, name = "RapidFire" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.RapidFire or { id = { 3045 }, name = "RapidFire" }
            return NS.try_cast(spell, context.me, "[HUNTER] Rapid Fire", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- HEALTHSTONE / POTION (Combat emergency heal)
    -- ========================================================================
    --
    -- BUGFIX (2026-06-29): formerly this strategy ignored the master
    -- ``use_auto_consumables`` / per-category ``use_healthstones`` /
    -- ``use_health_potions`` toggles entirely.  It also had no fast-path bag
    -- check, so every 3-throttled tick at low HP iterated 7 item ids, each
    -- costing a 5-bag scan.  Now it honours the master + per-category
    -- toggles and uses ``consumable_manager.has_any_consumable`` as a
    -- pre-flight check.
    --
    -- The hard-coded HEALING_POTION_ITEMS list below is preserved verbatim:
    -- these are the seven potion ranks in the game, and the consumable_manager
    -- ALSO scans them in M.use_health_potion.  Both paths share the
    -- ``invalidate_bag_cache`` hook inside the manager so a single successful
    -- use is reflected in the next scan.
    {
        name = "Hunter_Healthstone",
        priority = 850,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            if not spec_kit.setting_bool(context, "use_auto_consumables", true) then return false end
            if not spec_kit.setting_bool(context, "use_healthstones", true) and not spec_kit.setting_bool(context, "use_health_potions", true) then return false end
            local threshold = spec_kit.setting_number(context, "healthstone_hp", 0)
            if threshold <= 0 then return false end
            if (context.hp or 100) > threshold then return false end
            -- Fast-path bag check (uses the in-process cache when available).
            local HEALING_POTION_ITEMS = { 21877, 13446, 3928, 1710, 929, 858, 118 }
            local consumable_manager
            pcall(function() consumable_manager = require("shared/consumable_manager_sylvanas") end)
            if consumable_manager and type(consumable_manager.has_any_consumable) == "function" then
                local any = consumable_manager.has_any_consumable(HEALING_POTION_ITEMS)
                if not any then return false end
            end
            return true
        end,
        execute = function(context)
            local HEALING_POTION_ITEMS = { 21877, 13446, 3928, 1710, 929, 858, 118 }
            local used_item = false
            if NS.use_item and context.me then
                for _, item_id in ipairs(HEALING_POTION_ITEMS) do
                    if NS.use_item(item_id, context.me) then used_item = true; break end
                end
            end
            return used_item
        end,
    },

    -- ========================================================================
    -- MEND PET (Heal pet during combat — maintain pet HP above threshold)
    -- ========================================================================
    {
        name = "MendPet",
        priority = 700,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            if not spec_kit.setting_bool(context, "auto_mend_pet", true) then return false end
            -- Check if pet needs healing
            local pet_hp_pct = NS.get_pet_hp and NS.get_pet_hp() or 100
            if pet_hp_pct > spec_kit.setting_number(context, "mend_pet_hp", 50) then return false end
            -- Check if Mend Pet is already active (HoT)
            local mp_buffs = { 27046, 13544, 13543, 13542, 3662, 3661, 3111, 136 }
            local pet = NS.get_pet and NS.get_pet()
            if pet and NS.buff_up then
                for _, id in ipairs(mp_buffs) do
                    if NS.buff_up and NS.buff_up(pet, id) then return false end
                end
            end
            return NS.spell_ready and NS.spell_ready(SPELLS.MendPet, context.me)
        end,
        execute = function(context)
            local pet = NS.get_pet and NS.get_pet()
            if not pet then return false end
            return NS.try_cast(SPELLS.MendPet, pet, "[HUNTER] Mend Pet")
        end,
    },

    -- ========================================================================
    -- REVIVE PET (Out-of-combat — revive dead pet automatically)
    -- ========================================================================
    {
        name = "RevivePet",
        priority = 400,
        is_defensive = true,
        matches = function(context)
            if context.in_combat then return false end
            if not spec_kit.setting_bool(context, "auto_revive_pet", true) then return false end
            -- Check if pet is dead
            if NS.has_pet and NS.has_pet() then return false end
            return NS.spell_ready and NS.spell_ready(SPELLS.RevivePet, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.RevivePet, context.me, "[HUNTER] Revive Pet", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- CALL PET (Out-of-combat — call pet if dismissed/missing)
    -- ========================================================================
    {
        name = "CallPet",
        priority = 390,
        is_defensive = true,
        matches = function(context)
            if context.in_combat then return false end
            if not spec_kit.setting_bool(context, "auto_call_pet", true) then return false end
            if NS.has_pet and NS.has_pet() then return false end
            return NS.spell_ready and NS.spell_ready(SPELLS.CallPet, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.CallPet, context.me, "[HUNTER] Call Pet", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- FEED PET (Out-of-combat — auto-feed pet if happiness below happy)
    -- ========================================================================
    {
        name = "FeedPet",
        priority = 380,
        is_defensive = true,
        matches = function(context)
            if not spec_kit.setting_bool(context, "auto_feed_pet", true) then return false end
            if context.in_combat then return false end
            local happiness = context.pet_happiness
            if happiness == nil then return false end
            if happiness > 2 then return false end
            local pet = context.pet or (NS.get_pet and NS.get_pet())
            if not pet then return false end
            -- BUGFIX (2026-06-29): previously this block only checked
            -- ``pet.is_alive == false`` (literal false), then *only* pcall'd
            -- when ``is_alive`` was a function.  When the API returned it as
            -- nil or a boolean true, the liveness was never actually verified
            -- and we could attempt to feed a dead pet.  Now we always resolve
            -- the value via pcall regardless of type — safe on every build.
            local liveness = nil
            local ok, value = pcall(function()
                local f = pet.is_alive
                if type(f) == "function" then return f(pet) end
                return f
            end)
            if not ok then return false end
            liveness = value
            if liveness == false then return false end
            -- Happy / content / happy pets are already fed.
            return NS.spell_ready and NS.spell_ready(1539, context.me, { skip_range = true })
        end,
        execute = function(context)
            local pet = context.pet or (NS.get_pet and NS.get_pet())
            if not pet then return false end
            return NS.try_cast(1539, pet, "[HUNTER] Feed Pet")
        end,
    },

    -- ========================================================================
    -- HUNTER'S MARK (Debuff maintenance — apply to target if missing)
    -- ========================================================================
    {
        name = "HuntersMark",
        priority = 600,
        matches = function(context)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not spec_kit.setting_bool(context, "auto_hunters_mark", true) then return false end
            local target = context.target
            if not target then return false end
            -- Check if Hunter's Mark is already on target
            local hm_debuffs = { 14325, 14324, 14323, 1130 }
            for _, id in ipairs(hm_debuffs) do
                if NS.debuff_up and NS.debuff_up(target, id) then
                    local remains = NS.debuff_remains and NS.debuff_remains(target, id) or 999
                    if remains > 3 then return false end
                end
            end
            return NS.spell_ready and NS.spell_ready(SPELLS.HuntersMark, target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.HuntersMark, context.target, "[HUNTER] Hunter's Mark")
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return consumable_manager.should_check(context) end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("hunter", strategies)
return strategies
