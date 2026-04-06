-- =============================================================================
-- TREE FORM RESHIFT MIDDLEWARE
-- Handles automatic return to Tree of Life form after NS+HealingTouch
-- NS+HT requires leaving Tree form (/cancelform) - this gets us back
-- =============================================================================

local TreeReshiftMiddleware = {
    pending = false,
    max_wait_frames = 3,  -- Timeout after 3 frames (~150ms at 20fps)
    frame_count = 0,
}

-- Public API to set the pending flag (called by NS+HT strategy)
function TreeReshiftMiddleware.set_pending()
    TreeReshiftMiddleware.pending = true
    TreeReshiftMiddleware.frame_count = 0
end

-- Check if reshift is pending
function TreeReshiftMiddleware.is_pending()
    return TreeReshiftMiddleware.pending
end

-- Clear pending flag
function TreeReshiftMiddleware.clear()
    TreeReshiftMiddleware.pending = false
    TreeReshiftMiddleware.frame_count = 0
end

-- Execute reshift logic (call this at the start of RestoRotation.execute)
-- Returns: true if action taken, false otherwise
function TreeReshiftMiddleware.execute(ctx)
    if not TreeReshiftMiddleware.pending then
        return false
    end
    
    -- Increment frame counter for timeout protection
    TreeReshiftMiddleware.frame_count = TreeReshiftMiddleware.frame_count + 1
    
    -- Timeout protection: clear flag if stuck for too many frames
    if TreeReshiftMiddleware.frame_count > TreeReshiftMiddleware.max_wait_frames then
        TreeReshiftMiddleware.clear()
        return false
    end
    
    -- Already back in a form (or never left)? Clear flag and return
    if ctx.stance ~= Constants.STANCE.CASTER then
        TreeReshiftMiddleware.clear()
        return false
    end
    
    -- Try to shift back to Tree of Life
    local me = ctx.me
    if Spells.TreeOfLifeForm:is_learned() and Spells.TreeOfLifeForm:is_usable() then
        if Spells.TreeOfLifeForm:cast_safe(me, "[RESTO] Reshifting to Tree of Life") then
            TreeReshiftMiddleware.clear()
            core.log(string.format("[Cast] %s - %s", "[Druid]", "Tree Reshift"))
            return true
        end
    end
    
    return false
end

-- Validate we have Tree of Life form available
function TreeReshiftMiddleware.validate()
    if not Spells.TreeOfLifeForm:is_learned() then
        return false, "Tree of Life not learned"
    end
    return true, "Tree Reshift middleware ready"
end

return TreeReshiftMiddleware
