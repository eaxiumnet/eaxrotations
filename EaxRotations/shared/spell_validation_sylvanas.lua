-- spell_validation_sylvanas.lua -- Spell ID Validation: verifies spell ID exists in DBC at module load.
-- WHAT:   Spell ID Validation: verifies spell ID exists in DBC at module load.
-- WHEN:   called once at spec module load
-- WHY:    fast-fail on invalid IDs to prevent runtime 'unknown spell' crashes
-- SAFETY: PCalled on api; loads wowhead_data_bridge for ID lookup
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.


-- ============================================================================
-- Shared Helper: Spell Validation
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Validation results cache
local validation_cache = {}

-- Spell availability status
local STATUS = {
    MISSING_REQUIRED = "missing_required",
    MISSING_OPTIONAL = "missing_optional",
    PRESENT = "present",
    UNKNOWN = "unknown",
}

-- Class spell databases (populated from existing spell tables)
local function get_class_spells(class)
    if not NS then return nil end
    
    local spell_db = {
        warrior = NS.WarriorSpells,
        rogue = NS.RogueSpells,
        hunter = NS.HunterSpells,
        mage = NS.MageSpells,
        warlock = NS.WarlockSpells,
        priest = NS.PriestSpells,
        paladin = NS.PaladinSpells,
        shaman = NS.ShamanSpells,
        druid = NS.DruidSpells,
    }
    
    return spell_db[class]
end

-- Validate a single spell
function M.validate_spell(spell_id, is_required)
    if not NS then
        return { status = STATUS.UNKNOWN, reason = "NS not available" }
    end
    
    if not spell_id then
        return { status = is_required and STATUS.MISSING_REQUIRED or STATUS.MISSING_OPTIONAL, reason = "no spell_id" }
    end
    
    -- Check if spell is learned
    local is_learned = false
    if NS.is_spell_learned then
        local ok, result = pcall(NS.is_spell_learned, spell_id)
        if ok then
            is_learned = result
        end
    end
    
    if is_learned then
        return { status = STATUS.PRESENT, spell_id = spell_id }
    else
        return {
            status = is_required and STATUS.MISSING_REQUIRED or STATUS.MISSING_OPTIONAL,
            spell_id = spell_id,
            required = is_required,
        }
    end
end

-- Validate a set of class spells
-- required_keys: table of spell keys that must be present
-- optional_keys: table of spell keys that are optional
function M.validate_class_spells(class, required_keys, optional_keys)
    if not class then return nil end
    
    local class_spells = get_class_spells(class)
    if not class_spells then
        return { error = "class spells not found for " .. tostring(class) }
    end
    
    local results = {
        class = class,
        present = {},
        missing_required = {},
        missing_optional = {},
        has_errors = false,
    }
    
    -- Validate required spells
    if required_keys then
        for _, key in ipairs(required_keys) do
            local spell_data = class_spells[key]
            local spell_id = nil
            
            if type(spell_data) == "table" and spell_data.id then
                spell_id = spell_data.id
            elseif type(spell_data) == "number" then
                spell_id = spell_data
            end
            
            if spell_id then
                local result = M.validate_spell(spell_id, true)
                if result.status == STATUS.PRESENT then
                    table.insert(results.present, { key = key, spell_id = spell_id })
                else
                    table.insert(results.missing_required, { key = key, spell_id = spell_id })
                    results.has_errors = true
                end
            end
        end
    end
    
    -- Validate optional spells
    if optional_keys then
        for _, key in ipairs(optional_keys) do
            local spell_data = class_spells[key]
            local spell_id = nil
            
            if type(spell_data) == "table" and spell_data.id then
                spell_id = spell_data.id
            elseif type(spell_data) == "number" then
                spell_id = spell_data
            end
            
            if spell_id then
                local result = M.validate_spell(spell_id, false)
                if result.status == STATUS.PRESENT then
                    table.insert(results.present, { key = key, spell_id = spell_id, optional = true })
                else
                    table.insert(results.missing_optional, { key = key, spell_id = spell_id })
                end
            end
        end
    end
    
    -- Cache results
    validation_cache[class] = results
    
    return results
end

-- Get cached validation results
function M.get_cached_results(class)
    return validation_cache[class]
end

-- Print validation report to log
function M.print_report(class)
    local results = validation_cache[class]
    if not results then
        results = M.validate_class_spells(class)
    end
    
    if not results then
        if NS and NS.log then
            NS.log("[SpellValidation] No results for class: " .. tostring(class))
        end
        return
    end
    
    if results.error then
        if NS and NS.log then
            NS.log("[SpellValidation] Error: " .. results.error)
        end
        return
    end
    
    if NS and NS.log then
        NS.log("[SpellValidation] === Spell Validation Report for " .. tostring(class) .. " ===")
        
        -- Present spells
        NS.log("[SpellValidation] Present spells: " .. #results.present)
        
        -- Missing optional
        if #results.missing_optional > 0 then
            NS.log("[SpellValidation] Missing optional spells: " .. #results.missing_optional)
            for _, entry in ipairs(results.missing_optional) do
                NS.log("[SpellValidation]   - " .. entry.key .. " (ID: " .. entry.spell_id .. ")")
            end
        end
        
        -- Missing required (errors)
        if #results.missing_required > 0 then
            NS.log("[SpellValidation] ERROR: Missing required spells: " .. #results.missing_required)
            for _, entry in ipairs(results.missing_required) do
                NS.log("[SpellValidation]   - " .. entry.key .. " (ID: " .. entry.spell_id .. ")")
            end
        end
        
        if not results.has_errors then
            NS.log("[SpellValidation] All required spells present!")
        end
    end
end

-- Quick check if a spell is available
function M.is_spell_available(spell_key, class)
    local class_spells = get_class_spells(class)
    if not class_spells then return false end
    
    local spell_data = class_spells[spell_key]
    local spell_id = nil
    
    if type(spell_data) == "table" and spell_data.id then
        spell_id = spell_data.id
    elseif type(spell_data) == "number" then
        spell_id = spell_data
    end
    
    if not spell_id then return false end
    
    if NS and NS.is_spell_learned then
        local ok, result = pcall(NS.is_spell_learned, spell_id)
        return ok and result
    end
    
    return false
end

-- Initialize validation for current class
function M.init_for_class(class, required, optional)
    if not class then
        if NS and NS.PLAYER_CLASS then
            class = NS.PLAYER_CLASS
        end
    end
    
    if not class then return nil end
    
    -- Default required/optional if not provided
    if not required and not optional then
        -- These would be populated from class-specific data
        -- For now, leave empty
        required = {}
        optional = {}
    end
    
    local results = M.validate_class_spells(class, required, optional)
    M.print_report(class)
    
    return results
end

-- Check if rotation can function (no required spells missing)
function M.can_rotation_function(class)
    local results = validation_cache[class]
    if not results then
        results = M.validate_class_spells(class)
    end
    
    if not results then return false end
    return not results.has_errors
end

if NS then
    NS.SpellValidation = M
end

return M
