-- tree_reshift_manager.lua
-- Tree of Life form reshift after emergency NS+HT cast
-- When casting NS+Healing Touch (leaves Tree form), auto-return to Tree next frame

local tree_reshift_manager = {}

-- ============================================================================
-- STATE
-- ============================================================================
local state = {
    pending_reshift = false,
    reshift_reason = nil,           -- "ns_ht", "emergency", "manual"
    requested_at = 0,               -- timestamp
    max_wait_time = 3.0,            -- seconds before giving up
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local TREE_OF_LIFE_SPELL_ID = 33891
local TREE_OF_LIFE_FORM_ID = 5     -- Stance index for Tree of Life (Moonkin shares 5)
local CASTER_FORM_ID = 0           -- Human form

-- ============================================================================
-- CORE FUNCTIONS
-- ============================================================================

--- Request Tree of Life reshift
---@param reason string Why reshift is needed ("ns_ht", "emergency", "manual")
function tree_reshift_manager.request_reshift(reason)
    state.pending_reshift = true
    state.reshift_reason = reason or "manual"
    state.requested_at = core.time()
end

--- Clear the reshift flag (called after successful reshift or timeout)
function tree_reshift_manager.clear_reshift_flag()
    state.pending_reshift = false
    state.reshift_reason = nil
    state.requested_at = 0
end

--- Check if reshift is pending
---@return boolean is_pending
---@return string|nil reason
function tree_reshift_manager.is_reshift_pending()
    if not state.pending_reshift then
        return false, nil
    end
    
    -- Check for timeout
    local elapsed = core.time() - state.requested_at
    if elapsed > state.max_wait_time then
        tree_reshift_manager.clear_reshift_flag()
        return false, "timeout"
    end
    
    return true, state.reshift_reason
end

--- Get current form/stance
---@param me game_object Player unit
---@return number form_id
function tree_reshift_manager.get_current_form(me)
    if not me or not me.is_valid or not me:is_valid() then
        return CASTER_FORM_ID
    end
    
    local ok, form_id = pcall(function() return me:get_stance() end)
    if ok and form_id then
        return tonumber(form_id) or CASTER_FORM_ID
    end
    
    -- Fallback: check for Tree buff
    local ok2, has_tree = pcall(function() 
        return me:has_buff(TREE_OF_LIFE_SPELL_ID) 
    end)
    if ok2 and has_tree then
        return TREE_OF_LIFE_FORM_ID
    end
    
    return CASTER_FORM_ID
end

--- Check if we're already in Tree of Life form
---@param me game_object Player unit
---@return boolean is_in_tree
function tree_reshift_manager.is_in_tree_form(me)
    local form = tree_reshift_manager.get_current_form(me)
    return form == TREE_OF_LIFE_FORM_ID
end

--- Check if Tree of Life cast is possible
---@param me game_object Player unit
---@param spells table Spells database
---@return boolean can_cast
---@return number|nil spell_id
function tree_reshift_manager.can_cast_tree(me, spells)
    if not me or not me.is_valid or not me:is_valid() then
        return false, nil
    end
    
    -- Check if already in Tree
    if tree_reshift_manager.is_in_tree_form(me) then
        return false, "already_in_tree"
    end
    
    -- Check if spell is learned
    if not spells or not spells.TREE_OF_LIFE then
        return false, "no_spell_data"
    end
    
    -- Check mana (Tree form costs mana to cast)
    local ok, mana_pct = pcall(function() return me:get_mana_percentage() end)
    if ok and mana_pct and mana_pct < 5 then
        return false, "no_mana"
    end
    
    -- Check if in combat (sometimes we don't want to shift in combat)
    local ok2, in_combat = pcall(function() return me:is_in_combat() end)
    if ok2 and in_combat then
        -- Can still cast, but log it
        -- core.log("[Tree Reshift] Casting Tree in combat")
    end
    
    return true, spells.TREE_OF_LIFE[1]
end

--- Execute Tree of Life reshift
---@param me game_object Player unit
---@param utils table Utils library
---@param spells table Spells database
---@return boolean success
function tree_reshift_manager.execute_reshift(me, utils, spells)
    if not state.pending_reshift then
        return false
    end
    
    -- Check if already back in Tree
    if tree_reshift_manager.is_in_tree_form(me) then
        tree_reshift_manager.clear_reshift_flag()
        return true  -- Already done
    end
    
    -- Check if we can cast
    local can_cast, spell_id = tree_reshift_manager.can_cast_tree(me, spells)
    if not can_cast then
        -- If we can't cast (no mana, etc), clear the flag after a few attempts
        local elapsed = core.time() - state.requested_at
        if elapsed > 1.0 then
            tree_reshift_manager.clear_reshift_flag()
        end
        return false
    end
    
    -- Attempt cast
    if utils and utils.cast_self_fast then
        local success = utils.cast_self_fast(spell_id, me)
        if success then
            tree_reshift_manager.clear_reshift_flag()
            return true
        end
    end
    
    return false
end

--- Process reshift request (call in on_update loop)
---@param me game_object Player unit
---@param utils table Utils library
---@param spells table Spells database
---@return boolean did_reshift
function tree_reshift_manager.process(me, utils, spells)
    local is_pending, reason = tree_reshift_manager.is_reshift_pending()
    
    if not is_pending then
        return false
    end
    
    -- Double-check: are we still in caster form?
    if tree_reshift_manager.is_in_tree_form(me) then
        tree_reshift_manager.clear_reshift_flag()
        return false
    end
    
    -- Try to reshift
    return tree_reshift_manager.execute_reshift(me, utils, spells)
end

--- Get debug info
---@return table state_info
function tree_reshift_manager.get_debug_info()
    return {
        pending = state.pending_reshift,
        reason = state.reshift_reason,
        requested_at = state.requested_at,
        elapsed = state.pending_reshift and (core.time() - state.requested_at) or 0,
    }
end

return tree_reshift_manager
