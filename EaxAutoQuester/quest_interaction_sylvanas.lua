-- What: Quest interaction module — gossip, accept, complete, trainer
-- When: Called from main loop to auto-handle quest NPC interaction
-- Why: Centralize all UI frame handling in one place with nil-guarded API calls
-- Safety: All external API calls pcall-guarded; static table reuse; no math.sqrt()
-- Decision: Standalone module (not EaxRotations), caches core API at load

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _core_time = core.time
local _core_log = core.log
local _get_local_player = core.object_manager.get_local_player

-- Static table reuse (Pattern 4 from AGENTS.md)
local _t = { n = 0 }

-- ============================================================================
-- Cached quest/game_ui API references (Pattern 2)
-- ============================================================================

local _quests = core.quests
local _game_ui = core.game_ui
local _inventory = core.inventory
local _input = core.input

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

-- ============================================================================
-- Internal Helpers
-- ============================================================================

--- Get player gold in copper — nil-guarded.
--- @return number 0 if unavailable
local function get_player_gold()
    local ok, gold = pcall(function() return _inventory.get_gold() end)
    if ok and gold then return gold end
    return 0
end

--- Get NPC gossip quests that are flagged complete — static table reuse.
--- @param active_quests table Array of gossip_quest from get_gossip_active_quests()
--- @return table Array of complete-flagged gossip_quest entries
local function get_completable_quests(active_quests)
    _t.n = 0
    if not active_quests then return _t end

    for i = 1, #active_quests do
        local q = active_quests[i]
        if q and q.is_complete then
            _t.n = _t.n + 1
            _t[_t.n] = q
        end
    end
    return _t
end

-- ============================================================================
-- accept_all_available: Loop available gossip quests and select each
-- ============================================================================

--- Select all available (unaccepted) quests from the gossip frame.
--- Calls select_gossip_available_quest for each, which transitions to
--- the quest detail frame for subsequent accept_quest().
--- @return string|nil Action description or nil if none
function M.accept_all_available()
    local ok, available = pcall(function() return _quests.get_gossip_available_quests() end)
    if not ok or not available or #available == 0 then return nil end

    _t.n = 0
    for i = 1, #available do
        local q = available[i]
        if q and q.quest_id then
            local sel_ok = pcall(function() _quests.select_gossip_available_quest(q.quest_id) end)
            if sel_ok then
                _t.n = _t.n + 1
                _t[_t.n] = q.title or tostring(q.quest_id)
            end
        end
    end

    if _t.n == 0 then return nil end
    return "accept_available:" .. table.concat(_t, ",", 1, _t.n)
end

-- ============================================================================
-- turn_in_completable: Loop gossip active quests flagged complete and select
-- ============================================================================

--- Select each complete-flagged active quest from the gossip frame.
--- This transitions to the quest completion frame for complete_quest().
--- @return string|nil Action description or nil if none
function M.turn_in_completable()
    local ok, active = pcall(function() return _quests.get_gossip_active_quests() end)
    if not ok or not active or #active == 0 then return nil end

    local completable = get_completable_quests(active)
    if completable.n == 0 then return nil end

    _t.n = 0
    for i = 1, completable.n do
        local q = completable[i]
        if q and q.quest_id then
            local sel_ok = pcall(function() _quests.select_gossip_active_quest(q.quest_id) end)
            if sel_ok then
                _t.n = _t.n + 1
                _t[_t.n] = q.title or tostring(q.quest_id)
            end
        end
    end

    if _t.n == 0 then return nil end
    return "turn_in:" .. table.concat(_t, ",", 1, _t.n)
end

-- ============================================================================
-- select_best_reward: Choose quest reward by max vendor sell value
-- ============================================================================

--- Select the best quest reward from the completion reward frame.
--- Compares vendor sell_price of up to 6 reward choice items.
--- Falls back to money reward if no item choices present.
--- @return string|nil Action description or nil if no reward frame
function M.select_best_reward()
    -- Check if reward frame is showing — probe first choice item link
    local ok_probe, probe_link = pcall(function() return _quests.get_quest_item_link("choice", 1) end)

    -- Also check reward money availability
    local ok_money, reward_money = pcall(function() return _quests.get_reward_money() end)

    local has_item_frame = ok_probe and probe_link and probe_link ~= ""
    local has_money = ok_money and reward_money and reward_money > 0

    if not has_item_frame and not has_money then
        return nil
    end

    -- Scan reward choices (max 6 — typical wow cap)
    local best_idx = 0
    local best_price = 0

    _t.n = 0
    for i = 1, 6 do
        local ok_link, link = pcall(function() return _quests.get_quest_item_link("choice", i) end)
        if not ok_link or not link or link == "" then break end

        local ok_info, info = pcall(function() return _quests.get_item_info(link) end)
        if ok_info and info then
            local price = info.sell_price or 0
            if price > best_price then
                best_price = price
                best_idx = i
            end
            _t.n = _t.n + 1
            _t[_t.n] = tostring(i) .. "=" .. tostring(price) .. "c"
        end
    end

    if best_idx > 0 then
        local ok_select = pcall(function() _quests.get_quest_reward(best_idx) end)
        if ok_select then
            return "best_reward:" .. tostring(best_idx) .. "(" .. tostring(best_price) .. "c)"
        end
    end

    -- Fallback: take money reward
    if has_money then
        local ok_take = pcall(function() _quests.get_quest_reward(0) end)
        if ok_take then
            return "reward_money:" .. tostring(reward_money) .. "c"
        end
    end

    return nil
end

-- Throttle: prevent re-processing the same quest frame
local _last_quest_time = 0

-- ============================================================================
-- handle_quest_detail: Accept or complete quest from quest detail frame
-- ============================================================================

--- Handle the quest detail frame after selecting a quest from gossip.
--- First tries accept_quest() for new quest offers.
--- If that doesn't work (no accept frame), tries complete_quest() for turn-ins.
--- After completion, attempts select_best_reward() for reward selection.
--- @return string|nil Action description or nil if no quest frame
function M.handle_quest_detail()
    -- Throttle: only attempt once per second (pcall always succeeds even if API fails)
    local now = _core_time()
    if now - _last_quest_time < 1.0 then return nil end
    _last_quest_time = now

    -- Probe: check if any quest frame is showing via reward link or reward money
    local ok_link, link = pcall(function() return _quests.get_quest_item_link("choice", 1) end)
    local ok_money, reward_money = pcall(function() return _quests.get_reward_money() end)
    local has_frame = (ok_link and link and link ~= "") or (ok_money and reward_money and reward_money > 0)

    if not has_frame then return nil end

    -- Try accept first (new quest offer)
    local accept_ok = pcall(function() _quests.accept_quest() end)
    if accept_ok then
        -- Some quests auto-accept and need confirmation
        pcall(function() _quests.confirm_accept_quest() end)
        -- Dismiss the quest detail frame after accepting
        pcall(function() _quests.close_quest() end)
        -- Also try complete_quest as fallback (some quests need it to dismiss the frame)
        pcall(function() _quests.complete_quest() end)
        return "accept_quest"
    end

    -- Try complete (turn-in)
    local complete_ok = pcall(function() _quests.complete_quest() end)
    if complete_ok then
        -- After completing, try selecting best reward
        local reward_action = M.select_best_reward()
        if reward_action then
            return "complete_quest+" .. reward_action
        end
        return "complete_quest"
    end

    return nil
end

-- ============================================================================
-- handle_gossip: Process gossip frame — turn-in, accept, or close
-- ============================================================================

--- Handle an open gossip frame.
--- Priority order:
---   1. Turn in complete active quests (turn_in_completable)
---   2. Accept available quests (accept_all_available)
---   3. If nothing queued, close gossip
--- @return string|nil Action description or nil if gossip not shown
function M.handle_gossip()
    -- Check if gossip frame is actually shown
    local ok, is_shown = pcall(function() return _quests.is_gossip_frame_shown() end)
    if not ok or not is_shown then return nil end

    -- Priority 1: Turn-in completable quests
    local turnin_action = M.turn_in_completable()
    if turnin_action then return turnin_action end

    -- Priority 2: Accept available quests
    local accept_action = M.accept_all_available()
    if accept_action then return accept_action end

    -- Priority 3: Nothing to do — close gossip
    local close_ok = pcall(function() _quests.close_gossip() end)
    if close_ok then
        return "close_gossip"
    end

    return nil
end

-- ============================================================================
-- handle_trainer: Buy affordable spells from trainer
-- ============================================================================

--- Handle trainer frame — buy all affordable unlearned spells.
--- Checks player gold against each service cost before purchasing.
--- @return string|nil Action description or nil if no trainer frame
function M.handle_trainer()
    local ok_count, num_services = pcall(function() return _quests.get_num_trainer_services() end)
    if not ok_count or not num_services or num_services < 1 then return nil end

    local player_gold = get_player_gold()
    if player_gold < 1 then return nil end

    local bought_count = 0
    _t.n = 0

    for i = 1, num_services do
        -- Get service info
        local ok_info, info = pcall(function() return _quests.get_trainer_service_info(i) end)
        if not ok_info or not info then break end

        -- Get service cost
        local ok_cost, cost = pcall(function() return _quests.get_trainer_service_cost(i) end)
        if not ok_cost or not cost then break end

        local service_cost = cost.service_cost or 0

        -- Skip if too expensive
        if service_cost > 0 and service_cost <= player_gold then
            local ok_buy = pcall(function() _quests.buy_trainer_service(i) end)
            if ok_buy then
                bought_count = bought_count + 1
                _t.n = _t.n + 1
                _t[_t.n] = tostring(i) .. ":" .. (info.spell_name or "unknown")
                player_gold = player_gold - service_cost
            end
        end
    end

    if bought_count == 0 then return nil end
    return "trainer:" .. tostring(bought_count) .. "spells(" .. table.concat(_t, ",", 1, _t.n) .. ")"
end

-- ============================================================================
-- handle_any_frame: Dispatcher — detect open UI frame and dispatch
-- ============================================================================

--- Detect any open UI frame and dispatch to the appropriate handler.
--- Priority order: loot → gossip → quest_detail → trainer → vendor
--- @return string|nil Action description or nil if no frame handled
function M.handle_any_frame()
    -- Priority 1: Loot frame — auto-loot all
    local ok_loot, loot_count = pcall(function() return _game_ui.get_loot_item_count() end)
    if ok_loot and loot_count and loot_count > 0 then
        -- Auto-loot all available items
        for i = 1, loot_count do
            pcall(function() _input.loot_item(i) end)
        end
        pcall(function() _input.close_loot() end)
        return "loot:" .. tostring(loot_count) .. "items"
    end

    -- Priority 2: Gossip frame (quest interaction)
    local gossip_action = M.handle_gossip()
    if gossip_action then return gossip_action end

    -- Priority 3: Quest detail frame (accept/complete/reward)
    local quest_action = M.handle_quest_detail()
    if quest_action then return quest_action end

    -- Priority 4: Trainer frame
    local trainer_action = M.handle_trainer()
    if trainer_action then return trainer_action end

    -- Priority 5: Vendor frame — close if nothing else to do
    -- (No auto-vendor logic in scope; just close to prevent blocking)
    local ok_vendor, vendor_count = pcall(function() return _game_ui.get_vendor_item_count() end)
    if ok_vendor and vendor_count and vendor_count > 0 then
        return "vendor_open"
    end

    return nil
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.quest_interaction = M

return M
