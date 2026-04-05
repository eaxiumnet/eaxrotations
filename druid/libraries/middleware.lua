-- =============================================================================
-- DRUID MIDDLEWARE MODULE
-- Ported from Flux AIO - Cross-form middleware for TBC Druid
-- Handles: Recovery items, Barkskin, Innervate, self-buffs
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local Constants = require("libraries/constants")
local Spells = require("libraries/spells")
local Utils = require("libraries/utils")

local Middleware = {}

-- ============================================================================
-- PENDING RESHIFT STATE (for consumable form shifts)
-- ============================================================================
local pending_reshift = {
    spell = nil,
    expire = 0,
}

--- Schedule a form reshift after using consumable
function Middleware.schedule_reshift(spell)
    if spell then
        pending_reshift.spell = spell
        pending_reshift.expire = core.time() + 3.0
    end
end

--- Check and execute pending reshift
function Middleware.check_reshift(ctx)
    if not pending_reshift.spell then return nil end
    
    local now = core.time()
    if now > pending_reshift.expire then
        pending_reshift.spell = nil
        return nil
    end
    
    -- Only reshift if we're in caster form
    if ctx.stance ~= Constants.STANCE.CASTER then
        pending_reshift.spell = nil
        return nil
    end
    
    -- Cast the form spell
    if pending_reshift.spell:is_learned() and pending_reshift.spell:is_usable() then
        if pending_reshift.spell:cast_safe(ctx.me, "[RESHIFT] Returning to form") then
            Utils.log_cast("Form Reshift", ctx)
            pending_reshift.spell = nil
            return true
        end
    end
    
    return nil
end

-- ============================================================================
-- RECOVERY ITEMS MIDDLEWARE (Healthstones, Potions)
-- ============================================================================

function Middleware.execute_recovery_items(ctx)
    if not ctx.in_combat or ctx.is_stealthed then return nil end
    if not Utils.can_use_items(ctx.stance) then return nil end
    
    -- Check if we can afford to reshift
    if not Utils.can_afford_reshift(ctx.stance, ctx.mana or 0) then
        return nil
    end
    
    local settings = ctx.settings
    
    -- Healthstone
    if settings.use_healthstone and ctx.hp <= settings.healthstone_hp then
        local items = { Spells.HealthstoneMaster, Spells.HealthstoneMajor }
        for _, item in ipairs(items) do
            if item:is_learned() and item:is_usable() and item:cooldown_up() then
                Middleware.schedule_reshift(ctx.stance == Constants.STANCE.CAT and Spells.Forms.CatForm or 
                                           (ctx.stance == Constants.STANCE.BEAR and Spells.Forms.BearForm or nil))
                if item:use_self("[ITEM] Healthstone") then
                    Utils.log_cast("Healthstone", ctx)
                    return true
                end
            end
        end
    end
    
    -- Healing Potion
    if settings.use_healing_potion and ctx.hp <= settings.healing_potion_hp then
        local items = { Spells.SuperHealingPotion, Spells.MajorHealingPotion }
        for _, item in ipairs(items) do
            if item:is_learned() and item:is_usable() and item:cooldown_up() then
                Middleware.schedule_reshift(ctx.stance == Constants.STANCE.CAT and Spells.Forms.CatForm or 
                                           (ctx.stance == Constants.STANCE.BEAR and Spells.Forms.BearForm or nil))
                if item:use_self("[ITEM] Healing Potion") then
                    Utils.log_cast("Healing Potion", ctx)
                    return true
                end
            end
        end
    end
    
    return nil
end

-- ============================================================================
-- MANA RECOVERY MIDDLEWARE (Mana Potions, Dark Runes)
-- ============================================================================

function Middleware.execute_mana_recovery(ctx)
    if not ctx.in_combat or ctx.is_stealthed then return nil end
    if not Utils.can_use_items(ctx.stance) then return nil end
    
    -- Note: Mana items provide more than enough mana to cover shift cost
    -- The reshift retry loop handles the 1-frame delay for mana to land
    
    local settings = ctx.settings
    
    -- Mana Potion
    if settings.use_mana_potion and ctx.mana_pct and ctx.mana_pct <= settings.mana_potion_mana then
        local item = Spells.SuperManaPotion
        if item:is_learned() and item:is_usable() and item:cooldown_up() then
            Middleware.schedule_reshift(ctx.stance == Constants.STANCE.CAT and Spells.Forms.CatForm or 
                                       (ctx.stance == Constants.STANCE.BEAR and Spells.Forms.BearForm or nil))
            if item:use_self("[ITEM] Mana Potion") then
                Utils.log_cast("Mana Potion", ctx)
                return true
            end
        end
    end
    
    -- Dark Rune / Demonic Rune
    if settings.use_dark_rune and ctx.mana_pct and ctx.mana_pct <= settings.dark_rune_mana then
        if ctx.hp > settings.dark_rune_min_hp then
            local items = { Spells.DarkRune, Spells.DemonicRune }
            for _, item in ipairs(items) do
                if item:is_learned() and item:is_usable() and item:cooldown_up() then
                    Middleware.schedule_reshift(ctx.stance == Constants.STANCE.CAT and Spells.Forms.CatForm or 
                                               (ctx.stance == Constants.STANCE.BEAR and Spells.Forms.BearForm or nil))
                    if item:use_self("[ITEM] Dark Rune") then
                        Utils.log_cast("Dark Rune", ctx)
                        return true
                    end
                end
            end
        end
    end
    
    return nil
end

-- ============================================================================
-- BARKSKIN DEFENSIVE MIDDLEWARE (off-GCD, usable in all forms)
-- ============================================================================

function Middleware.execute_barkskin(ctx)
    if not ctx.in_combat then return nil end
    if pending_reshift.spell then return nil end  -- Don't break reshift
    
    -- Barkskin drops bear/cat forms on some servers; be careful
    if ctx.stance == Constants.STANCE.BEAR or ctx.stance == Constants.STANCE.CAT then
        return nil
    end
    
    local settings = ctx.settings
    if not settings.use_barkskin then return nil end
    
    local threshold = settings.barkskin_hp or 40
    if ctx.hp > threshold then return nil end
    
    -- Check if already buffed
    if ctx.me:buff_up(Spells.SelfUtility.Barkskin:id()) then return nil end
    
    -- Cast Barkskin
    local spell = Spells.SelfUtility.Barkskin
    if spell:is_learned() and spell:is_usable() then
        if spell:cast_safe(ctx.me, "[DEF] Barkskin") then
            Utils.log_cast("Barkskin", ctx)
            return true
        end
    end
    
    return nil
end

-- ============================================================================
-- INNERVATE MIDDLEWARE (self-use when low mana)
-- ============================================================================

function Middleware.execute_innervate(ctx)
    if not ctx.in_combat then return nil end
    if not ctx.settings.use_innervate_self then return nil end
    
    -- Check if already innervated
    if ctx.me:buff_up(Spells.SelfUtility.Innervate:id()) then return nil end
    
    local threshold = ctx.settings.innervate_mana or 30
    if ctx.mana_pct and ctx.mana_pct > threshold then return nil end
    
    local spell = Spells.SelfUtility.Innervate
    if spell:is_learned() and spell:is_usable() then
        if spell:cast_safe(ctx.me, "[MANA] Innervate Self") then
            Utils.log_cast("Innervate", ctx)
            return true
        end
    end
    
    return nil
end

-- ============================================================================
-- RACIAL ABILITY MIDDLEWARE
-- ============================================================================

function Middleware.execute_racial(ctx)
    if not ctx.in_combat then return nil end
    if not ctx.settings.use_racial then return nil end
    
    -- Berserking (Troll)
    local berserking = Spells.Racials.Berserking
    if berserking:is_learned() and berserking:is_usable() then
        if berserking:cast_safe(ctx.me, "[RACIAL] Berserking") then
            Utils.log_cast("Berserking", ctx)
            return true
        end
    end
    
    -- Blood Fury (Orc)
    local blood_fury = Spells.Racials.BloodFury
    if blood_fury:is_learned() and blood_fury:is_usable() then
        if blood_fury:cast_safe(ctx.me, "[RACIAL] Blood Fury") then
            Utils.log_cast("Blood Fury", ctx)
            return true
        end
    end
    
    return nil
end

-- ============================================================================
-- SELF-BUFF MIDDLEWARE (OOC only)
-- ============================================================================

function Middleware.execute_self_buffs(ctx)
    if ctx.in_combat then return nil end
    
    local me = ctx.me
    local settings = ctx.settings
    
    -- Mark of the Wild
    if settings.use_motw then
        local has_motw = false
        for _, id in ipairs(Constants.MOTW_BUFF_IDS) do
            if me:buff_up(id) then has_motw = true break end
        end
        
        if not has_motw then
            local spell = Spells.SelfBuffs.MarkOfTheWild
            if spell:is_learned() and spell:is_usable() then
                if spell:cast_safe(me, "[BUFF] Mark of the Wild") then
                    Utils.log_cast("Mark of the Wild", ctx)
                    return true
                end
            end
        end
    end
    
    -- Thorns
    if settings.use_thorns then
        local has_thorns = false
        for _, id in ipairs(Constants.THORNS_BUFF_IDS) do
            if me:buff_up(id) then has_thorns = true break end
        end
        
        if not has_thorns then
            local spell = Spells.SelfBuffs.Thorns
            if spell:is_learned() and spell:is_usable() then
                if spell:cast_safe(me, "[BUFF] Thorns") then
                    Utils.log_cast("Thorns", ctx)
                    return true
                end
            end
        end
    end
    
    -- Omen of Clarity
    if settings.use_ooc then
        if not me:buff_up(Spells.SelfBuffs.OmenOfClarity:id()) then
            local spell = Spells.SelfBuffs.OmenOfClarity
            if spell:is_learned() and spell:is_usable() then
                if spell:cast_safe(me, "[BUFF] Omen of Clarity") then
                    Utils.log_cast("Omen of Clarity", ctx)
                    return true
                end
            end
        end
    end
    
    return nil
end

-- ============================================================================
-- MAIN MIDDLEWARE EXECUTION
-- ============================================================================

--- Execute all middleware in priority order
function Middleware.execute(ctx)
    -- Priority 1: Form reshift (highest priority - must complete consumable cycle)
    if Middleware.check_reshift(ctx) then return true end
    
    -- Priority 2: Recovery items (healthstones, healing potions)
    if Middleware.execute_recovery_items(ctx) then return true end
    
    -- Priority 3: Mana recovery (mana potions, dark runes)
    if Middleware.execute_mana_recovery(ctx) then return true end
    
    -- Priority 4: Emergency defensive (Barkskin)
    if Middleware.execute_barkskin(ctx) then return true end
    
    -- Priority 5: Innervate when low mana
    if Middleware.execute_innervate(ctx) then return true end
    
    -- Priority 6: Racial abilities
    if Middleware.execute_racial(ctx) then return true end
    
    -- Priority 7: Self-buffs (OOC only)
    if Middleware.execute_self_buffs(ctx) then return true end
    
    return nil
end

return Middleware
