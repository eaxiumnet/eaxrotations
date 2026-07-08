-- hearth.lua — Auto-hearth to inn when bags are full, vendor, and return.
-- WHAT:  uses Hearthstone (spell 8690) to teleport to inn when bags are full,
--        then returns to the fishing spot via saved position.
-- WHEN:  when bags full AND auto_hearth_full enabled AND no vendor nearby.
-- WHY:   enables true unattended sessions — hearth, sell, repair, return.
-- SAFETY: saves return position; only fires when not in combat/casting/moving;
--         throttled; requires Hearthstone in bags.

local APISurface = require("core/api_surface")

local M = {}

-- Hearthstone spell ID (from DBC SpellName table)
local HEARTHSTONE_SPELL_ID = 8690
-- Hearthstone item ID
local HEARTHSTONE_ITEM_ID = 6948

--- Check if player has a Hearthstone
-- @return boolean
function M.has_hearthstone()
    local count = APISurface.get_item_count(HEARTHSTONE_ITEM_ID)
    return count and count > 0
end

--- Try to hearth to inn
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if hearth was initiated
function M.try_hearth(ctx, me, now)
    local state = ctx.state

    if not APISurface.is_valid(me) then return false end
    if APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me) then
        return false
    end
    if APISurface.is_in_combat(me) then return false end
    if APISurface.is_moving(me) then return false end

    -- Must have hearthstone
    if not M.has_hearthstone() then
        APISurface.print("[EaxFishing] No Hearthstone found — cannot auto-hearth")
        return false
    end

    -- Save current position for return trip
    local pos = APISurface.get_object_position(me)
    if pos then
        state.hearth.return_position = { x = pos.x, y = pos.y, z = pos.z }
    end

    -- Cast Hearthstone
    APISurface.print("[EaxFishing] Bags full — hearthing to inn to vendor...")
    local success = APISurface.use_item_self_safe(HEARTHSTONE_ITEM_ID)
    if success then
        state.hearth.state = "hearth"
        state.hearth.hearth_time = now
        state.fishing.status = "Hearthing to inn..."
        return true
    end

    return false
end

--- Check if we should return to fishing spot after hearth
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if return was initiated
function M.try_return(ctx, me, now)
    local state = ctx.state

    if state.hearth.state ~= "hearth" then return false end
    if not state.hearth.return_position then return false end

    -- Wait for hearth cast to complete (10s cast time)
    if now - state.hearth.hearth_time < 12.0 then
        return false
    end

    -- After hearth, we're at the inn — try to navigate back
    if Client.has_client(ctx) then
        local dest = state.hearth.return_position
        APISurface.print("[EaxFishing] Returning to fishing spot...")
        Client.move(ctx, dest, 15.0)
        state.hearth.state = "returning"
        return true
    end

    -- No nav client — can't auto-return
    APISurface.print("[EaxFishing] No navigation client — cannot auto-return to fishing spot")
    state.hearth.state = "idle"
    return false
end

--- Reset hearth state
function M.reset(state)
    if not state.hearth then return end
    state.hearth.state = "idle"
    state.hearth.hearth_time = 0.0
    state.hearth.return_position = nil
end

return M
