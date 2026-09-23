-- shared/recovery.lua -- out-of-combat recovery: eat and drink while the pull gate holds.
-- WHAT:  recovery.tick(ctx, shared) is called from the parked path (idle_state, while
--        pull_safety is holding and the bot is standing still). While a bar is below the PULL
--        GATE's own refusal floor it uses a matching food/drink item from the bags; the pause
--        ends when the bar clears that floor, or at the per-pause cap.
-- WHEN:  only while the pull gate's hold is armed, and only when the client says the player is
--        provably out of combat and not walking. It has no entry point anywhere else: it never
--        decides anything on its own.
-- WHY:   the gate refuses a pull on low health/mana and parks the bot, which then waits for
--        natural regen; recovery is the other half of that same decision. Because it runs only
--        where the gate has already parked, a floor equal to the gate's cannot become a
--        "wait before every pull": above the floor the bot fights, and the gate's own
--        anti-stall cap (40s) bounds the pause from the outside.
-- SAFETY: every probe fails closed — a bot that cannot answer "am I low" or "am I in combat"
--        fights, it does not stand. Quest items are recognised by their module and NEVER used
--        here. Food and drink channel, so an item is used at most once per CHANNEL_SECONDS.
--        No navigation field is ever written (tests/test_nav_destination_ownership.lua bans
--        it): the caller owns the park.
-- DECISION: shared module — the classification (which item refills which bar, and the level it
--        requires) lives next to the generated table it reads, and the only caller keeps one
--        call in one branch. The client's own consumables list is preferred when the build
--        provides it; a raw bag walk judged by the table is the backstop.

local M = {}

local _core_time = core.time

-- ============================================================================
-- Floors and caps
-- ============================================================================

-- The floors are the PULL GATE's own refusal floors, asked live via pull_safety.floors: the
-- gate parks a bot by exactly those numbers, so a parked bot refills in exactly the band it was
-- parked for. Nothing restates them, so the two cannot drift, and a rule the user disabled (0)
-- is disabled here too — no healthy percentage is below zero. No answer -> no need (fail
-- closed, like the bar probes).
-- Above the floor = fight. There is no "eat until full": that is the disabled wait's failure.

-- One use channels for the item's duration (up to 30s); using again mid-channel cancels it
-- and re-queues the GCD. One pause may therefore consist of several uses, but never a second
-- use sooner than this.
local CHANNEL_SECONDS = 30.0

-- Hard cap on one pause. The gate's anti-stall cap (40s) bounds the hold from the outside;
-- this bounds the eat from the inside, so a bot that keeps finding consumables still walks
-- away on schedule.
local MAX_PAUSE_SECONDS = 60.0

local PLAYER_POWER_MANA = 0

-- Shared empty list for "no classification table": returned, never written to.
local EMPTY = {}

-- ============================================================================
-- Hoisted probes
-- ============================================================================

local function unit_get_health(u) return u:get_health() end
local function unit_get_max_health(u) return u:get_max_health() end
local function unit_get_power(u, t) return u:get_power(t) end
local function unit_get_max_power(u, t) return u:get_max_power(t) end

local function get_items_in_bag(bag)
    return core.inventory.get_items_in_bag(bag)
end

-- The generated table: { [item_id] = { name, kind, min_level } }. Immutable data, cached at
-- first use like mount_manager caches its table.
local _item_table = nil
local function item_table()
    if not _item_table then
        local ok, t = pcall(require, "shared/recovery_items_sylvanas")
        if ok and t then _item_table = t end
    end
    return _item_table
end

-- The client's own consumable classification, when this build carries it
-- (common/utility/inventory_helper; absent in the test environment, present live).
local _inventory_helper = nil
local function inventory_helper()
    if not _inventory_helper then
        local ok, h = pcall(require, "common/utility/inventory_helper")
        if ok and h then _inventory_helper = h end
    end
    return _inventory_helper
end

-- quest_item_manager_sylvanas owns quest item handling; its ids are never touched here.
-- The scan is a snapshot of the bags, so it is cached and dropped via M.reset() (a suite
-- that fills the bags between two ticks must see both).
local _quest_items = nil
local function quest_item_ids()
    if not _quest_items then
        _quest_items = {}
        local ok, qim = pcall(require, "quest_item_manager_sylvanas")
        if ok and qim and qim.get_all_inventory_items then
            local ok2, list = pcall(qim.get_all_inventory_items)
            if ok2 and type(list) == "table" then
                for i = 1, #list do
                    local e = list[i]
                    if e and e.item_id then _quest_items[e.item_id] = true end
                end
            end
        end
    end
    return _quest_items
end

--- Drop the caches that snapshot the environment — the quest-item scan and the client's helper
--- reference (tests swap both between ticks; nothing in production calls this).
function M.reset()
    _quest_items = nil
    _inventory_helper = nil
end

-- ============================================================================
-- The player's bars
-- ============================================================================

--- Health as a percentage, or nil when the client cannot say.
local function health_pct(me)
    local ok_h, hp = pcall(unit_get_health, me)
    local ok_m, max_hp = pcall(unit_get_max_health, me)
    if not (ok_h and ok_m) or not hp or not max_hp or max_hp <= 0 then return nil end
    return (hp / max_hp) * 100
end

--- Mana as a percentage, or nil for a class with no mana bar at all.
local function mana_pct(me)
    local ok_m, max_mp = pcall(unit_get_max_power, me, PLAYER_POWER_MANA)
    if not ok_m or not max_mp or max_mp <= 0 then return nil end
    local ok_c, mp = pcall(unit_get_power, me, PLAYER_POWER_MANA)
    if not ok_c or not mp then return nil end
    return (mp / max_mp) * 100
end

--- Which bars are below their floor. Both nil-safe: a probe that cannot be answered is not a
--- need, and a class without mana is never "low on mana". A nil floor means the gate could not
--- be asked — that is not a need either.
--- @param me game_object
--- @param min_hp number|nil the gate's health floor
--- @param min_mana number|nil the gate's mana floor
--- @return boolean need_food, boolean need_drink
local function bar_needs(me, min_hp, min_mana)
    local hp = health_pct(me)
    local mp = mana_pct(me)
    return (hp ~= nil and min_hp ~= nil and hp < min_hp),
        (mp ~= nil and min_mana ~= nil and mp < min_mana)
end

-- ============================================================================
-- Consumables in the bags
-- ============================================================================

--- Is this table entry usable by a player of this level? An item whose Requires Level is
--- above the player's cannot be consumed; there is always a lower-tier alternative to hand
--- instead. A level the client would not report counts as "usable".
local function level_ok(entry, player_level)
    if not player_level then return true end
    return player_level >= (entry and entry.min_level or 1)
end

--- Every usable consumable in the bags: { kind = "food"|"drink", item_id }.
--- The helper's consumables list is the client's own verdict; the generated table is the
--- classifier (and says WHICH of food/drink an item is). A build without the helper's
--- consumables call falls back to a raw bag walk judged by the table alone.
--- @param player_level number|nil
--- @return table[] consumables
local function bag_consumables(player_level)
    local table_ = item_table()
    if not table_ then return EMPTY end

    local banned = quest_item_ids()
    local out = {}

    local helper = inventory_helper()
    local entries = nil
    if helper and type(helper.get_current_consumables_list) == "function" then
        local ok, list = pcall(helper.get_current_consumables_list, helper)
        if ok and type(list) == "table" then entries = list end
    end

    if entries then
        for i = 1, #entries do
            local e = entries[i]
            if e and e.item and e.is_food_or_drink then
                local ok_id, item_id = pcall(function() return e.item:get_item_id() end)
                local info = ok_id and item_id and table_[item_id]
                if info and not banned[item_id] and level_ok(info, player_level) then
                    out[#out + 1] = { kind = info.kind, item_id = item_id }
                end
            end
        end
        return out
    end

    -- Raw bag walk, judged by the table alone. The item is used by ID (core.input.use_item),
    -- which needs no (bag, slot) conventions — the pair the helper owns is simply not needed.
    for bag = 0, 4 do
        local ok, items = pcall(get_items_in_bag, bag)
        if ok and type(items) == "table" then
            for _, item in ipairs(items) do
                local obj = item and item.object
                if obj and obj.get_item_id then
                    -- pcall assigned directly: an `and`-chain would truncate its second
                    -- return to nil (logical expressions adjust to one value).
                    local ok_id, item_id = pcall(obj.get_item_id, obj)
                    if ok_id and item_id then
                        local info = table_[item_id]
                        if info and not banned[item_id] and level_ok(info, player_level) then
                            out[#out + 1] = { kind = info.kind, item_id = item_id }
                        end
                    end
                end
            end
        end
    end
    return out
end

--- The consumable to use: the HIGHEST-tier matching item (the table's min_level is the tier
--- proxy — a higher requirement is a stronger item), so the shortest channel does the most.
--- @param consumables table[]
--- @param kind string "food" or "drink"
--- @return table|nil
local function pick(consumables, kind)
    local best, best_tier = nil, -1
    for i = 1, #consumables do
        local c = consumables[i]
        if c.kind == kind then
            local info = item_table()[c.item_id]
            local tier = info and info.min_level or 0
            if tier > best_tier then
                best, best_tier = c, tier
            end
        end
    end
    return best
end

-- ============================================================================
-- The pause
-- ============================================================================

--- Use one consumable, by id — the one shape of the call that names an exact item and needs
--- no slot conventions.
--- @param consumable table
local function use(consumable)
    pcall(core.input.use_item, consumable.item_id)
end

--- The pause itself. Called from idle_state's parked path: the pull gate holds, the bot has
--- walked its retreat (or has nowhere to retreat to) and is standing still.
--- @param ctx table Per-tick context
--- @param shared table Shared state variables
--- @return boolean paused true when this tick must not do anything else
function M.tick(ctx, shared)
    if not ctx or not shared or not ctx.me then return false end

    -- Never in combat, and never on a probe that cannot answer: combat recovery is the
    -- rotation's business (potions, bandages, heals), not a park-and-eat. Only a definitive
    -- "not in combat" lets the pause start — the same fail-closed doctrine as the bar probes.
    local ok_combat, in_combat = pcall(function() return ctx.me:is_in_combat() end)
    if not ok_combat or in_combat ~= false then
        shared._recov_since = 0
        return false
    end

    -- The pull gate is this module's only licence: no hold, no pause. Asking the gate itself
    -- keeps the two modules' ideas of "holding" — and of where "low" starts — identical by
    -- construction, so a bot the gate parked drinks in exactly the band it was parked for.
    local ok_ps, pull_safety = pcall(require, "shared/pull_safety")
    if not (ok_ps and pull_safety and pull_safety.holding(ctx)) then
        shared._recov_since = 0
        return false
    end
    local min_hp, min_mana = nil, nil
    if type(pull_safety.floors) == "function" then
        local ok_f, f_hp, f_mana = pcall(pull_safety.floors, ctx)
        if ok_f then min_hp, min_mana = f_hp, f_mana end
    end

    -- Remain seated means remain seated: a channel is cancelled by movement, so a bot that is
    -- still walking (the retreat being walked out) is not eating yet. The caller only invokes
    -- this when parked; the guard is the same question asked defensively.
    local ok_nav, nav = pcall(function() return ctx.nav end)
    if ok_nav and nav and nav.is_navigating and nav.is_navigating() then
        return false
    end

    local now = ctx.now or (_core_time and _core_time() or 0)

    -- Cap first: whatever the bars say, the pause ends on schedule.
    if (shared._recov_since or 0) > 0 and (now - shared._recov_since) > MAX_PAUSE_SECONDS then
        shared._recov_since = 0
        ctx.debug_log("RECOVERY: pause cap reached — resuming")
        return false
    end

    local need_food, need_drink = bar_needs(ctx.me, min_hp, min_mana)
    if not (need_food or need_drink) then
        shared._recov_since = 0
        return false
    end

    -- Pause clock: this is one pause, not a new one every tick.
    if (shared._recov_since or 0) == 0 then
        shared._recov_since = now
    end

    local ok_lvl, player_level = pcall(function() return ctx.me:get_level() end)
    local consumables = bag_consumables(ok_lvl and player_level or nil)
    local consumable = (need_drink and pick(consumables, "drink"))
        or (need_food and pick(consumables, "food"))
        or nil

    if not consumable then
        -- Nothing to use (or everything left is a quest item / above level): stand, don't
        -- wedge. The gate's cap and this pause's cap both still bound the total time.
        return false
    end

    -- Channel pause: re-using the item mid-channel would cancel it and re-queue the GCD.
    if (shared._recov_used_at or 0) == 0
        or (now - shared._recov_used_at) >= CHANNEL_SECONDS then
        shared._recov_used_at = now
        use(consumable)
        ctx.debug_log("RECOVERY: using item " .. tostring(consumable.item_id)
            .. " (" .. consumable.kind .. ")")
    end
    return true
end

-- ============================================================================
-- Constants, for callers and tests
-- ============================================================================

M.CHANNEL_SECONDS = CHANNEL_SECONDS
M.MAX_PAUSE_SECONDS = MAX_PAUSE_SECONDS

return M
