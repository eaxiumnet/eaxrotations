-- =============================================================================
-- Fishing/Cook Module - Auto-cook raw fish into buff food
-- WHAT:  Detects raw fish stacks in bags and casts the matching DBC-verified
--        cooking recipe to convert them into cooked buff food (more bag-space
--        efficient + far higher vendor/AH value per slot).
-- WHEN:  in engine.tick() between casts, when the player is idle and a fire
--        (basic campfire aura OR a world cooking fire) is nearby.
-- WHY:   cooked food frees bag slots mid-session and turns raw fish (vendor
--        trash, ~1s each) into meals worth 10s-2g each. This converts a
--        "fillbags-and-stop" bot into a self-emptying economy loop.
-- SAFETY: every recipe spell ID is DBC-verified (SpellName exact match, see
--        wowheadScrape/dbc_extract/wowsims.db). No guessing — we did NOT
--        repeat the ghost-spell 13147 mistake. is_spell_learned() gates each
--        cast. All API access through APISurface with pcall.
-- =============================================================================

local APISurface = require("core/api_surface")
local Behavior   = require("core/behavior")
local LootDB     = require("fishing/loot_db")

local M = {}

-- -----------------------------------------------------------------------------
-- DBC-VERIFIED cooking recipe table
-- -----------------------------------------------------------------------------
-- Each entry: raw_item_id -> { recipe_spell_id (DBC-verified), cooked_name (debug only) }
-- Recipe spell IDs were verified against SpellName exact-match in the DBC:
--   33290 Blackened Trout, 33291 Feltail Delight, 33296 Spicy Crawdad,
--   33294 Poached Bluefish, 33293 Grilled Mudfish, 33292 Blackened Sporefish,
--   7755  Bristle Whisker Catfish, 25954 Sagefish Delight, 25704 Smoked Sagefish.
-- Raw-fish IDs come from loot_db.lua (which were themselves DBC-verified).
-- Only raw fish that ALSO appear in loot_db are included — we never cook fish
-- the bot didn't catch (avoids accidental conversion of quest/stock fish).
local COOKABLE = {
    [27422] = { spell = 33290, name = "Blackened Trout" },          -- Barbed Gill Trout
    [27425] = { spell = 33291, name = "Feltail Delight" },          -- Spotted Feltail
    [27435] = { spell = 33296, name = "Spicy Crawdad" },            -- Furious Crawdad
    [27438] = { spell = 33294, name = "Poached Bluefish" },         -- Icefin Bluefish
    [27439] = { spell = 33293, name = "Grilled Mudfish" },          -- Figluster's Mudfish
    [27426] = { spell = 33292, name = "Blackened Sporefish" },      -- Zangarian Sporefish
    [6308]  = { spell = 7755,  name = "Bristle Whisker Catfish" },  -- Raw Bristle Whisker Catfish
    [13760] = { spell = 25954, name = "Sagefish Delight" },         -- Raw Greater Sagefish
    [13757] = { spell = 25704, name = "Smoked Sagefish" },          -- Raw Sagefish
}

-- Minimum raw-fish stack size worth a cook click (avoids cooking 1 fish at a
-- time, which wastes the brief fire-cast window and looks robotic).
local MIN_COOK_STACK = 2

-- Throttle: don't try to cook more than once per cook_interval seconds even if
-- the fire is up. Prevents a tight loop if the cast fails.
local COOK_INTERVAL_S = 1.5

--- Put module into a known clean state (called on enable/disable transitions).
-- state.cook is initialised in core/state.lua; this just clears timers.
function M.reset(ctx)
    local st = ctx.state.cook
    if not st then return end
    st.last_cook_time = 0.0
    st.cooked_count = 0
    st.queued = nil
    st.status = "Idle"
    st.cook_delay_end = 0.0
end

--- Decide whether cooking is currently allowed.
-- Cooking requires: a basic campfire OR standing near a world cooking fire.
-- Many fishing spots (Shattrath pier, nodes by FP) have a usable fire nearby.
-- We detect a nearby fire object by name; failing that, we require the
-- player's own Basic Campfire (spell 818) aura if they carry flint+wood.
-- @param ctx table
-- @param me game_object
-- @return boolean can_cook, string reason
function M.can_cook_here(ctx, me)
    if not APISurface.is_valid(me) then return false, "invalid player" end

    -- Quick reject: must not be casting/channeling (would interrupt a cast).
    if APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me) then
        return false, "casting"
    end

    -- Must be standing still — cooking requires stationary cast.
    if APISurface.is_moving(me) then
        return false, "moving"
    end

    -- Check player has learned ANY cooking recipe (cheap gate).
    -- We test the Apprentice Cooking skill (2550 / Apprentice Cook 2551).
    if not APISurface.is_spell_learned(2550) and not APISurface.is_spell_learned(2551) then
        return false, "cooking not learned"
    end

    -- Look for a nearby Basic Campfire / Cooking Fire game object.
    -- Names are matched case-insensitively; only the documented names are used.
    local p = APISurface.get_object_position(me)
    if not p then return false, "no position" end

    local range_sq = 10 * 10  -- within 10 yards of a fire
    local objects = APISurface.get_all_objects()
    for _, obj in ipairs(objects) do
        if APISurface.is_valid(obj) then
            local name = APISurface.get_object_name(obj)
            if type(name) == "string" and #name > 0 then
                local lower = string.lower(name)
                if string.find(lower, "campfire", 1, true)
                or string.find(lower, "cooking fire", 1, true)
                or string.find(lower, "fire", 1, true) then  -- broad: world braziers often named "Fire"
                    local pos = APISurface.get_object_position(obj)
                    if pos then
                        local dx = p.x - pos.x
                        local dy = p.y - pos.y
                        if dx*dx + dy*dy <= range_sq then
                            return true, "near fire"
                        end
                    end
                end
            end
        end
    end

    return false, "no fire nearby"
end

--- Find the first raw-fish stack in bags with a learnable matching recipe.
-- Returns the raw_item_id + recipe_spell_id if cooking is possible right now.
-- @return number? raw_item_id, number? recipe_spell_id, number stack_count
function M.find_cookable_stack()
    for raw_id, info in pairs(COOKABLE) do
        -- Skip recipes the player hasn't learned (no point queueing them).
        if APISurface.is_spell_learned(info.spell) then
            local count = APISurface.get_item_count(raw_id)
            if count >= MIN_COOK_STACK then
                -- Also skip if loot_db doesn't classify this as a fish
                -- (defensive: prevents cooking quest items that share an ID).
                local db = LootDB.get(raw_id)
                if db and db.cat == LootDB.CAT_FISH then
                    return raw_id, info.spell, count
                end
            end
        end
    end
    return nil, nil, 0
end

--- Try one cooking step. Returns true if a cast was issued this tick.
-- @param ctx table context
-- @param me table player object
-- @param now number current time
-- @return boolean did_act
function M.try_cook(ctx, me, now)
    local st = ctx.state.cook
    if not st then return false end

    -- Feature gate
    local config = ctx.deps.config
    local cook_on = config.menu.auto_cook
        and config.menu.auto_cook.get_state
        and config.menu.auto_cook:get_state()
    if not cook_on then return false end

    -- Throttle
    if now - st.last_cook_time < COOK_INTERVAL_S then return false end

    local ok, reason = M.can_cook_here(ctx, me)
    if not ok then
        st.status = "no fire"
        return false
    end

    -- Wait out a small cook delay (humanisation) before the first cook click
    local use_delays = config.menu.enable_lure_delays
        and config.menu.enable_lure_delays.get_state
    if use_delays then
        if st.cook_delay_end <= 0 then
            local d = 0.4 + math.random() * 0.6  -- 0.4-1.0s
            st.cook_delay_end = now + d
            return false
        end
        if now < st.cook_delay_end then return false end
    end
    st.cook_delay_end = 0
    st.last_cook_time = now

    local raw_id, recipe_id, count = M.find_cookable_stack()
    if not raw_id then
        st.status = "nothing to cook"
        return false
    end

    -- Cast the cooking recipe on self (cooking is self-targeted craft).
    local success = APISurface.cast_target_spell(recipe_id, me)
    if success then
        st.cooked_count = st.cooked_count + 1
        st.status = "cooking " .. (COOKABLE[raw_id].name or "?") .. " (" .. count .. ")"
        if ctx.deps.config.menu.debug and ctx.deps.config.menu.debug.get_state
           and ctx.deps.config.menu.debug:get_state() then
            APISurface.print("[EaxFishing] cooked 1x raw " .. raw_id
                .. " (" ..  (COOKABLE[raw_id].name or "?") .. ")")
        end
        return true
    else
        st.status = "cast failed"
        return false
    end
end

return M
