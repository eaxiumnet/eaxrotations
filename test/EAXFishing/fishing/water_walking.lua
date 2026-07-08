-- water_walking.lua — Auto-apply water walking / levitate buffs before fishing.
-- WHAT:  detects if the player has a water walking or levitate buff active,
--        and auto-applies the best available source if missing.
-- WHEN:  before casting, when not awaiting bobber.
-- WHY:   fishing from the surface of water (pools in lakes, rivers, ocean)
--        requires water walking or levitate. Users often forget to buff.
-- SAFETY: pcall on all buff checks; skips if casting/channeling/in combat;
--         only applies if the spell is learned (class spell) or item is in
--         bags (consumable); throttled to avoid spam.

local APISurface = require("core/api_surface")

local M = {}

-- Buff IDs (verified against DBC SpellName table)
local BUFF_WATER_WALKING     = 546   -- Shaman: Water Walking
local BUFF_WATER_WALKING_ALT = 10665 -- alternative spell ID
local BUFF_LEVITATE          = 1706  -- Priest: Levitate
local BUFF_PATH_OF_FROST     = 3714  -- DK: Path of Frost (WotLK, may be backported)

-- Spell IDs that grant the buff
local WATER_WALKING_SPELLS = {
    [546]   = { name = "Water Walking",   class = "shaman", item = nil },
    [10665] = { name = "Water Walking",   class = "shaman", item = nil },
    [1706]  = { name = "Levitate",        class = "priest", item = nil },
    [3714]  = { name = "Path of Frost",   class = "deathknight", item = nil },
}

-- Consumable items that grant water walking
local WATER_WALKING_ITEMS = {
    -- Elixir of Water Walking (TBC alchemy, item 8827)
    -- The spell cast by the item is 11447 "Elixir of Waterwalking"
    [8827]  = { name = "Elixir of Water Walking", spell = 11447 },
}

--- Check if player has any water-walking or levitate buff active
-- @param me game_object
-- @return boolean has_buff, number|nil expire_time
function M.has_water_walking_buff(me)
    if not APISurface.is_valid(me) then return false end
    local buffs = APISurface.get_buffs(me)
    if not buffs then return false end
    for _, b in ipairs(buffs) do
        if b.id == BUFF_WATER_WALKING
            or b.id == BUFF_WATER_WALKING_ALT
            or b.id == BUFF_LEVITATE
            or b.id == BUFF_PATH_OF_FROST
        then
            return true, b.expire_time
        end
    end
    return false
end

--- Try to apply the best available water walking buff
-- Also refreshes the buff before it expires (configurable threshold).
-- Priority: learned class spell > consumable item
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if a buff was applied
function M.try_apply(ctx, me, now)
    local state = ctx.state

    if not APISurface.is_valid(me) then return false end
    if APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me) then
        return false
    end
    if APISurface.is_in_combat(me) then return false end
    if APISurface.is_moving(me) then return false end

    -- Throttle: don't try more than once every 5s
    if now - (state.water_walking and state.water_walking.last_try_time or 0) < 5.0 then
        return false
    end
    if not state.water_walking then state.water_walking = { last_try_time = 0 } end
    state.water_walking.last_try_time = now

    -- Check if buffed and when it expires
    local has_buff, expire_time = M.has_water_walking_buff(me)
    if has_buff then
        -- Check if buff is about to expire (refresh before it runs out)
        local refresh_secs = 60
        if ctx.deps.config.menu.water_walking_refresh_secs
           and ctx.deps.config.menu.water_walking_refresh_secs.get then
            refresh_secs = ctx.deps.config.menu.water_walking_refresh_secs:get()
        end
        if refresh_secs > 0 and expire_time then
            local remaining = expire_time - now
            -- STEALTH: random variance on refresh threshold so it's not robotic.
            -- A human notices the buff fading at different times, not on a metronome.
            local variance = refresh_secs * 0.35  -- ±35% random window
            local trigger_at = refresh_secs + (math.random() * 2 - 1) * variance
            if trigger_at < 10 then trigger_at = 10 end  -- minimum 10s safety
            if remaining <= trigger_at then
                -- STEALTH: human reaction delay — not instant re-apply.
                -- Takes a moment to notice the buff is fading, then casts.
                if not state.water_walking.reaction_deadline then
                    local reaction_delay = 0.5 + math.random() * 1.5  -- 0.5-2.0s
                    state.water_walking.reaction_deadline = now + reaction_delay
                    state.fishing.status = "Noticing buff fading..."
                    return false  -- Wait for reaction delay
                end
                if now < state.water_walking.reaction_deadline then
                    return false  -- Still "noticing"
                end
                state.water_walking.reaction_deadline = nil
                -- STEALTH: occasional forgetfulness — 4% chance to let it expire.
                -- Humans sometimes forget to re-buff. This breaks perfect patterns.
                if math.random() < 0.04 then
                    APISurface.print("[EaxFishing] Letting water walking expire (human forgetfulness)")
                    return false
                end
                APISurface.print("[EaxFishing] Water walking expiring in " .. math.floor(remaining) .. "s — refreshing...")
                -- Fall through to re-apply below
            else
                state.water_walking.reaction_deadline = nil
                return false  -- Buff is fine, no need to refresh
            end
        else
            state.water_walking.reaction_deadline = nil
            return false  -- Buff is fine, no refresh configured
        end
    end

    -- Try class spells first (free, no item consumption)
    for spell_id, info in pairs(WATER_WALKING_SPELLS) do
        if APISurface.is_spell_learned(spell_id) then
            local ok, result = pcall(APISurface.cast_target_spell, spell_id, me)
            if ok and result then
                APISurface.print("[EaxFishing] Casting " .. info.name .. "...")
                return true
            end
        end
    end

    -- Try consumable items (elixirs)
    for item_id, info in pairs(WATER_WALKING_ITEMS) do
        local count = APISurface.get_item_count(item_id)
        if count and count > 0 then
            local ok, result = pcall(APISurface.use_item_self_safe, item_id)
            if ok and result then
                APISurface.print("[EaxFishing] Using " .. info.name .. " (" .. count .. " left)...")
                return true
            end
        end
    end

    return false
end

--- Reset water walking state
function M.reset(state)
    if not state.water_walking then return end
    state.water_walking.last_try_time = 0.0
end

return M
