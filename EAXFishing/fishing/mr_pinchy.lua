-- mr_pinchy.lua — Mr. Pinchy rare catch handler (TBC Highland Muddy Water pools).
-- WHAT:  detects Mr. Pinchy in bags, auto-uses its 3 charges, alerts on results.
-- WHEN:  between casts, when Mr. Pinchy is found and charges remain.
-- WHY:   Mr. Pinchy (27436) is a ultra-rare TBC fishing catch with 3 charges.
--        0.2% chance to grant Magical Crawdad pet. Users don't want to manually
--        use charges or miss the Crawdad alert.
-- SAFETY: pcall on item use; skips if casting/channeling/moving; throttled.
--         Never auto-uses in combat (the buff/heal is wasted there).

local APISurface = require("core/api_surface")

local M = {}

-- Mr. Pinchy item ID (TBC rare catch from Highland Muddy Water pools)
local MR_PINCHY_ITEM_ID = 27436

-- Result spell IDs (from DBC SpellName table)
local SPELL_SUMMON_CRAWDAD    = 33050 -- "Summon Magical Crawdad" — THE jackpot
local SPELL_PINCHY_BLESSING   = 33053 -- "Mr Pinchy's Blessing" — buff
local SPELL_MIGHTY_PINCHY     = 33057 -- "Summon Mighty Mr. Pinchy" — pet
local SPELL_FURIOUS_PINCHY    = 33059 -- "Summon Furious Mr. Pinchy" — hostile!
local SPELL_TINY_CRAWDAD      = 33062 -- "Tiny Magical Crawdad" — pet
local SPELL_PINCHY_GIFT       = 33064 -- "Mr. Pinchy's Gift" — loot box

--- Check if Mr. Pinchy is in bags
-- @param ctx table
-- @return boolean has_pinchy, number count
function M.has_pinchy(ctx)
    local count = APISurface.get_item_count(MR_PINCHY_ITEM_ID)
    if count and count > 0 then
        return true, count
    end
    return false, 0
end

--- Try to use Mr. Pinchy if available
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if a charge was used
function M.try_use(ctx, me, now)
    local state = ctx.state

    if not APISurface.is_valid(me) then return false end
    if APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me) then
        return false
    end
    if APISurface.is_moving(me) then return false
    end
    -- Never use in combat — the buff/pet would be wasted or killed
    if APISurface.is_in_combat(me) then return false end

    -- Throttle: don't use more than once every 3s (the cast animation takes time)
    if now - state.pinchy.last_use_time < 3.0 then
        return false
    end

    local has_pinchy, count = M.has_pinchy(ctx)
    if not has_pinchy then return false end

    APISurface.print("[EaxFishing] ★ Using Mr. Pinchy charge (" .. count .. " remaining)...")
    local success = APISurface.use_item_self_safe(MR_PINCHY_ITEM_ID)
    if success then
        state.pinchy.last_use_time = now
        state.pinchy.uses_total = state.pinchy.uses_total + 1
        -- Trigger rare alert (Mr. Pinchy is always exciting)
        if state.alert then
            state.alert.active = true
            state.alert.text = "★ Mr. Pinchy charge used! (" .. count - 1 .. " left)"
            state.alert.fade_start = now
            state.alert.fade_end = now + 4.0
            state.alert.quality = 4 -- blue
        end
        return true
    end

    return false
end

--- Reset pinchy state
function M.reset(state)
    if not state.pinchy then return end
    state.pinchy.last_use_time = 0.0
    state.pinchy.uses_total = 0
    state.pinchy.crawdad_won = false
end

return M
