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

-- The loot module is the single owner of emptying a loot window (0-based slots, gold
-- first, a walk that survives the window compacting) — loot_manager_sylvanas.try_loot.
-- It is resolved once here and retried lazily, so no second copy of those index rules
-- can grow back in this file.
local _loot_manager = nil
do
    local ok, mod = pcall(require, "loot_manager_sylvanas")
    if ok and mod then _loot_manager = mod end
end

--- @return table|nil The loot module, if it can be loaded.
local function get_loot_manager()
    if _loot_manager and _loot_manager.try_loot then return _loot_manager end
    local ok, mod = pcall(require, "loot_manager_sylvanas")
    if ok and mod and mod.try_loot then
        _loot_manager = mod
        return mod
    end
    return nil
end

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

-- ============================================================================
-- Framed quest selection — shared by accept_all_available and turn_in_completable
-- ============================================================================
--
-- A gossip frame's quest_id is a 1-BASED ROW INDEX on the private-server builds
-- (.api/core.lua, "GOSSIP ACROSS GAME VERSIONS"): it addresses the frame it was
-- read from and nothing else. Selecting an entry rebuilds that list and the rows
-- renumber, so a snapshot captured before an earlier selection must never be
-- walked -- the next select would address whatever row now sits at that index
-- (the wrong quest) or fall off the end (a skipped quest).
--
-- Each step therefore re-reads the frame and re-resolves its target from THAT
-- read, and "already selected in this pass" is tracked by TITLE -- the documented
-- portable identifier on every build -- never by the position that produced the id.

local _MAX_SELECT_STEPS = 8   -- anti-spin bound; a partial pass resumes next tick
local _sel = {}               -- titles selected in the current pass

--- Select every matching quest in the open gossip frame, one re-read per selection.
-- @param getter function Returns the frame's current quest list.
-- @param selector function(quest_id) Selects one row by the id it carried.
-- @param complete_only boolean|nil When true, only entries flagged complete.
-- @return number count selected (labels are written to the module _t table)
local function select_from_frame(getter, selector, complete_only)
    _t.n = 0
    for k in pairs(_sel) do _sel[k] = nil end

    local unnamed_seen = 0
    for _ = 1, _MAX_SELECT_STEPS do
        local ok, list = pcall(getter)
        if not ok or not list or #list == 0 then break end

        -- Resolve the target from THIS read only.
        local target, label = nil, nil
        local unnamed_here = 0
        for i = 1, #list do
            local q = list[i]
            if q and q.quest_id and (not complete_only or q.is_complete) then
                if q.title then
                    if not _sel[q.title] then
                        target, label = q, q.title
                        break
                    end
                else
                    -- No title: allow one unnamed entry per step, so the pass still
                    -- advances without ever trusting a row from a previous read.
                    unnamed_here = unnamed_here + 1
                    if unnamed_here > unnamed_seen then
                        target = q
                        break
                    end
                end
            end
        end
        if not target then break end

        if not pcall(selector, target.quest_id) then break end
        if label then _sel[label] = true else unnamed_seen = unnamed_seen + 1 end
        _t.n = _t.n + 1
        _t[_t.n] = label or tostring(target.quest_id)
    end

    return _t.n
end

-- ============================================================================
-- accept_all_available: select every quest the gossip frame offers
-- ============================================================================

--- Select all available (unaccepted) quests from the gossip frame.
--- Selecting transitions to the quest detail frame for subsequent accept_quest().
--- @return string|nil Action description or nil if none
function M.accept_all_available()
    local count = select_from_frame(
        _quests.get_gossip_available_quests, _quests.select_gossip_available_quest, false)
    if count == 0 then return nil end
    return "accept_available:" .. table.concat(_t, ",", 1, _t.n)
end

-- ============================================================================
-- Frame probe + throttled debug logging
-- ============================================================================

--- Is a quest reward/detail frame showing, and what does it publish?
--- The runtime has no "quest frame is up" predicate — only is_gossip_frame_shown
--- (.api/core.lua:4791) — so the frame is inferred from the reward data it publishes: a choice
--- item link, or reward money. That inference can LATCH: live, the link kept answering after the
--- turn-in calls, which is why every consumer of this probe also bounds its own attempts and why
--- detect_open_frame's answer alone must never be allowed to decide an unbounded loop.
--- @return boolean showing, string|nil link, number|nil money
local function reward_frame_probe()
    local ok_link, link = pcall(function() return _quests.get_quest_item_link("choice", 1) end)
    local ok_money, money = pcall(function() return _quests.get_reward_money() end)
    local showing = (ok_link and link and link ~= "") or (ok_money and money and money > 0)
    return showing, link, money
end

--- Debug line, at most once per `interval` per key. These handlers run every tick, and the
--- unconditional "checking frames..." line buried the log the user needed under thousands of
--- copies of itself — the whole trace was four lines repeating.
--- @param key string throttle key
--- @param message string what to log (prefixed for you)
--- @param interval number|nil seconds between repeats (default 1.0)
local _last_dlog = {}
local function dlog(key, message, interval)
    local now = _core_time()
    local last = _last_dlog[key]
    if last and now - last < (interval or 1.0) then return end
    _last_dlog[key] = now
    _core_log("[EaxAutoQuester-DEBUG] " .. message)
end

-- ============================================================================
-- turn_in_completable: select every complete quest the frame offers
-- ============================================================================

--- Select each complete-flagged active quest from the gossip frame.
--- Selecting transitions to the quest completion frame for complete_quest().
--- @return string|nil Action description or nil if none
function M.turn_in_completable()
    local count = select_from_frame(
        _quests.get_gossip_active_quests, _quests.select_gossip_active_quest, true)
    if count == 0 then return nil end
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

-- Does a "is a frame open?" probe currently answer yes? Shared by handle_any_frame's give-up,
-- and hoisted rather than written as an inner closure: the INTERACT tick is allocation-gated
-- (tests/test_tick_allocation.lua) and a per-call closure cost 60 B/tick.
local function probe_says_open(probe)
    local ok, open = pcall(probe)
    return ok and open == true
end

-- Throttle: prevent re-processing the same quest frame
local _last_quest_time = 0
local _last_quest_action = nil  -- "accept" or "complete"
local _quest_retry_count = 0    -- consecutive attempts on a frame that would not close
local _last_giveup_step = nil   -- step named by the last give-up warning (one warning per frame)
local _last_giveup_count = 0    -- how many times that frame has been given up on

-- ============================================================================
-- auto_equip_best_reward: Equip the selected reward if it's an upgrade
-- ============================================================================

--- After selecting a quest reward, auto-equip it if better than current gear.
--- Uses equipment_compare_sylvanas.lua for slot classification and quality comparison.
function M.auto_equip_best_reward()
    local eq_ok, eq = pcall(require, "equipment_compare_sylvanas")
    if not eq_ok or not eq then return end

    local me = _get_local_player()
    if not me then return end

    -- Get equipped items: returns [{object=game_object, slot_id=integer}]
    local ok_eq_items, eq_items = pcall(function() return me:get_equipped_items() end)
    if not ok_eq_items or not eq_items then return end

    -- Build equipped item list for comparison
    local equipped_list = {}
    for _, entry in ipairs(eq_items) do
        if entry and entry.object then
            local ok_name, name = pcall(function() return entry.object:get_name() end)
            local ok_id, item_id = pcall(function() return entry.object:get_item_id() end)
            if ok_name and ok_id and item_id then
                -- Documented source: core.quests.get_item_info(item_id_or_link) (.api/core.lua),
                -- the same cached function this file already uses for reward links. The name
                -- `_get_item_info` was declared nowhere, so the lookup always failed and every
                -- equipped item compared as quality 0.
                local ok_info, info = pcall(function() return _quests.get_item_info(item_id) end)
                local quality = (ok_info and info and info.quality) or 0
                local slot = eq.classify_slot(name)
                if slot then
                    table.insert(equipped_list, { slot = slot, name = name, quality = quality })
                end
            end
        end
    end

    -- Scan reward choices and equip the first upgrade
    for i = 1, 6 do
        local ok_link, link = pcall(function() return _quests.get_quest_item_link("choice", i) end)
        if not ok_link or not link or link == "" then break end

        local ok_info, info = pcall(function() return _quests.get_item_info(link) end)
        if ok_info and info then
            local should, slot = eq.should_equip(info.name, info.quality or 0, equipped_list)
            if should then
                pcall(function() _quests.get_quest_reward(i) end)
                -- Try to equip via use_container_item if item lands in bags
                -- (The exact bag/slot is unknown at this moment; we'll scan on next tick)
                break
            end
        end
    end
end

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

    -- Probe: check if any quest frame is showing via reward link, reward money, or gossip quests
    local showing, link, reward_money = reward_frame_probe()
    local ok_avail, available = pcall(function() return _quests.get_gossip_available_quests() end)
    local ok_active, active = pcall(function() return _quests.get_gossip_active_quests() end)
    dlog("quest_probe", "handle_quest_detail: link=" .. tostring(link and #link) ..
        " money=" .. tostring(reward_money) ..
        " avail=" .. tostring(ok_avail and available and #available) ..
        " active=" .. tostring(ok_active and active and #active))
    local has_frame = showing
                      or (ok_avail and available and #available > 0)
                      or (ok_active and active and #active > 0)

    -- Absence is checked BEFORE the give-up, so a frame that closes — by our attempt or by the
    -- player's hand — clears the budget instead of leaving the handler poisoned for the next one.
    if not has_frame then
        -- Observed absence: the frame really is gone (or was never there). This — not a probe
        -- taken in the same tick an action was issued — is what proves a turn-in landed.
        if _quest_retry_count > 0 then _quest_retry_count = 0 end
        return nil
    end

    -- After 3 failed attempts, permanently give up on this frame
    if _quest_retry_count >= 3 then
        core.log_warning("[EaxAutoQuester] Quest frame unhandled after 3 attempts - giving up")
        return nil
    end

    -- Check if this is a reward frame (has reward choices or money)
    local has_rewards = (link and link ~= "") or (reward_money and reward_money > 0)

    if has_rewards then
        -- Reward frame: select the best reward, then FINISH the dialog.
        --
        -- The documented order is get_quest_reward ("Selects a reward choice and completes the
        -- quest", scraped_docs_md/dev/api/quests.md) and then complete_quest ("Completes the
        -- current quest dialog. Use this when turning in a quest that has no reward choices, or
        -- AFTER selecting a reward with get_quest_reward").
        --
        -- This branch used to select the reward and close the frame WITHOUT ever completing it,
        -- so the reward frame stayed up and the bot re-selected the same reward every second
        -- forever: "INTERACT: handled (complete_quest+best_reward:1(...))" then "INTERACT: frame
        -- still open", for as long as the client kept the frame. Nothing stopped it, because the
        -- reward path returned before the retry counter was ever charged.
        _last_quest_action = "complete"
        local reward_action = M.select_best_reward()
        -- Auto-equip the chosen reward if it's better than current gear
        M.auto_equip_best_reward()
        pcall(function() _quests.complete_quest() end)
        local ok_g, gossip = pcall(function() return _quests.is_gossip_frame_shown() end)
        if ok_g and gossip then
            pcall(function() _quests.close_gossip() end)
        end

        -- Charge the attempt UNCONDITIONALLY, then let a later tick's absence observation
        -- (top of this function) clear it.
        --
        -- This used to consult reward_frame_probe() right here and clear the counter when the
        -- choice links went empty. In the live client they empty for an instant and the server
        -- re-populates them because the turn-in was refused, so the probe read "closed", the
        -- counter went back to 0, and the caller's own probe saw the same window still on screen
        -- a millisecond later. Give-up lived behind _quest_retry_count >= 3, which could then
        -- never be reached: the log filled with one completed-looking attempt per second for as
        -- long as the frame stayed up.
        _quest_retry_count = _quest_retry_count + 1

        -- The frame is still right there: it may be an OFFER, and offers publish "choice" links
        -- too, as a preview of what the quest pays. Claim it in the same pass — otherwise an offer
        -- is only ever "completed", three attempts are spent, and a quest the bot should have taken
        -- is given up on. This probe decides the VERB only; it is never the success test, because a
        -- refused turn-in re-populates its choices and would read as a closed frame.
        if reward_frame_probe() then
            dlog("quest_still", "handle_quest_detail: frame outlived complete_quest — claiming it")
            _last_quest_action = "accept"
            pcall(function() _quests.accept_quest() end)
            pcall(function() _quests.confirm_accept_quest() end)
            pcall(function() _quests.close_quest() end)
            return "accept_quest"
        end
        if reward_action then
            return "complete_quest+" .. reward_action
        end
        return "complete_quest"
    else
        -- No reward choices — complete the dialog directly (turn-in with nothing to pick).
        _last_quest_action = "complete"
        pcall(function() _quests.complete_quest() end)
        pcall(function() _quests.close_quest() end)
        _quest_retry_count = _quest_retry_count + 1
        -- (the accept fall-through below still applies to this shape: gossip offer frames arrive
        -- without reward choices and are claimed there)
        local ok_g2, gossip2 = pcall(function() return _quests.is_gossip_frame_shown() end)
        if ok_g2 and gossip2 then
            pcall(function() _quests.close_gossip() end)
        end
        return "complete_quest"
    end

    -- Frame still open — try accept_quest (new quest offer)
    _last_quest_action = "accept"
    pcall(function() _quests.accept_quest() end)
    pcall(function() _quests.confirm_accept_quest() end)
    pcall(function() _quests.close_quest() end)
    pcall(function() _quests.complete_quest() end)
    local ok_g3, gossip3 = pcall(function() return _quests.is_gossip_frame_shown() end)
    if ok_g3 and gossip3 then
        pcall(function() _quests.close_gossip() end)
    end
    if not reward_frame_probe() then
        _quest_retry_count = 0
        return "accept_quest"
    end

    -- Nothing cleared it. Do not churn: the attempt is charged, and once three are in,
    -- handle_any_frame stops calling this and reports "quest_giveup" so INTERACT backs off and the
    -- player is told to finish the turn-in by hand.
    pcall(function() _input.close_loot() end)
    dlog("quest_stuck", "handle_quest_detail: quest frame would not close (attempt " ..
        tostring(_quest_retry_count) .. "/3)")
    return "accept_quest"
end

-- ============================================================================
-- handle_gossip: Process gossip frame — turn-in, accept, or close
-- ============================================================================

--- Handle an open gossip frame.
--- Priority order:
---   1. Turn in complete active quests (turn_in_completable)
---   2. Accept available quests (accept_all_available)
---   3. Service gossip (inn, bank, repair) if indicated by step text
---   4. If nothing queued, close gossip
--- @param step_text string|nil Current Zygor step text for service detection.
--- @return string|nil Action description or nil if gossip not shown
function M.handle_gossip(step_text)
    -- Check if gossip frame is actually shown
    local ok, is_shown = pcall(function() return _quests.is_gossip_frame_shown() end)
    dlog("gossip_probe", "handle_gossip: is_gossip_frame_shown ok=" .. tostring(ok) .. " shown=" .. tostring(is_shown))
    if not ok or not is_shown then return nil end

    -- Priority 0: Pre-accept all available quests on turn-in NPCs
    -- When at a quest giver that has both turn-ins and new quests,
    -- accept all available first so we don't have to come back.
    local pre_accept = M.accept_all_available()
    if pre_accept then
        -- After accepting, return to let the frame transition
        return "pre_accept:" .. pre_accept
    end

    -- Priority 1: Turn-in completable quests
    local turnin_action = M.turn_in_completable()
    if turnin_action then return turnin_action end

    -- Priority 2: Accept available quests (secondary pass after turn-in)
    local accept_action = M.accept_all_available()
    if accept_action then return accept_action end

    -- Priority 3: Service gossip (innkeeper hearth, bank, repair)
    local svc_ok, svc = pcall(require, "service_gossip_sylvanas")
    if svc_ok and svc then
        local svc_result = svc.handle_service_gossip(step_text)
        if svc_result then return svc_result end
    end

    -- Priority 4: Nothing to do — close gossip
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
---
--- The offer list carries no id (.api/core.lua:4379-4383 — spell_name/rank/category
--- only) and the docs never say whether buying a service removes it from the list
--- (quests.md, Trainer Functions), so this walk identifies an offer by its position in
--- a FRESH read rather than by any field. That is the only thing correct both ways:
---   * walking a count captured once skips whatever shifts into an index already
---     visited when the list compacts;
---   * keying "already bought" on a field skips an offer that shares that field (two
---     ranks of one spell) or has no usable value at all.
--- Each step reads its target through the read it just took. After a purchase the list
--- is read once more: if it shrank, the purchase removed an entry and the rest
--- renumbered, so the cursor stays put — the same index now holds the next offer; if it
--- did not, the cursor steps past the offer just bought. Either way each is bought once.
--- @return string|nil Action description or nil if no trainer frame
function M.handle_trainer()
    local ok_count, num_services = pcall(function() return _quests.get_num_trainer_services() end)
    if not ok_count or type(num_services) ~= "number" or num_services < 1 then return nil end

    local player_gold = get_player_gold()
    if player_gold < 1 then return nil end

    local bought_count = 0
    _t.n = 0

    local offers = num_services   -- offers as of the most recent read
    local index = 1
    local steps = 0

    -- A purchase can only remove an offer, never add one, so the count read on entry
    -- bounds how many services this pass may buy.
    while steps < num_services and index <= offers do
        steps = steps + 1

        local ok_info, info = pcall(function() return _quests.get_trainer_service_info(index) end)
        if not ok_info or not info then break end

        local ok_cost, cost = pcall(function() return _quests.get_trainer_service_cost(index) end)
        if not ok_cost or not cost then break end

        local service_cost = cost.service_cost or 0

        if service_cost > 0 and service_cost <= player_gold then
            local ok_buy = pcall(function() _quests.buy_trainer_service(index) end)
            if not ok_buy then break end

            bought_count = bought_count + 1
            _t.n = _t.n + 1
            _t[_t.n] = tostring(index) .. ":" .. (info.spell_name or "unknown")
            player_gold = player_gold - service_cost

            local ok_n, n = pcall(function() return _quests.get_num_trainer_services() end)
            if ok_n and type(n) == "number" and n < offers then
                offers = n            -- compacted: this index holds the next offer now
            else
                index = index + 1     -- stable list: step past the offer just bought
            end
        else
            -- Free, or more than we can afford — leave it and move on
            index = index + 1
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
--- @param step_text string|nil Current Zygor step text for service gossip detection.
--- @param frame_open_fn function|nil The caller's own "is a frame still open?" probe. It decides
---   whether a given-up frame is still up, so the loop can only end the way the caller sees it.
--- @return string|nil Action description or nil if no frame handled
function M.handle_any_frame(step_text, frame_open_fn)
    -- No unconditional per-tick line here: the frame handlers below log what they did, and this
    -- one printed on every tick whether or not anything was open (see dlog).

    -- One truth for "is the frame still there": the caller's probe when it supplies one. The
    -- give-up below used to consult this module's reward-link probe while the caller consulted
    -- its own, and a reward frame whose choices are re-sent by the server reads open to one and
    -- closed to the other — a disagreement that let the frame be "given up on" never.
    local frame_probe = frame_open_fn or reward_frame_probe

    -- Priority 1: Loot frame — emptied by its single owner, which reads the slot count,
    -- loots gold first and walks downward so a compacting window cannot shift a slot that
    -- has not been visited yet.
    local loot_manager = get_loot_manager()
    if loot_manager then
        local looted, loot_count = loot_manager.try_loot()
        if looted then
            return "loot:" .. tostring(loot_count) .. "items"
        end
    end

    -- Priority 2: Gossip frame (quest interaction + service gossip)
    local gossip_action = M.handle_gossip(step_text)
    if gossip_action then return gossip_action end

    -- Priority 3: Quest detail frame (accept/complete/reward)
    -- If we've permanently given up, skip quest detail and signal state machine.
    -- The window is long on purpose: the frame is retried once every 2 minutes, so a quest the
    -- handlers cannot finish costs a handful of warnings rather than a per-second churn.
    if _quest_retry_count >= 3 and _core_time() - _last_quest_time > 120.0 then
        _quest_retry_count = 0
    end
    if _quest_retry_count >= 3 then
        if probe_says_open(frame_probe) then
            -- Say WHAT could not be finished, once per stuck frame, so the player can turn it in
            -- by hand instead of watching an unreadable loop.
            if _last_giveup_step ~= (step_text or "") then
                _last_giveup_step = step_text or ""
                _last_giveup_count = 0
            end
            _last_giveup_count = (_last_giveup_count or 0) + 1
            if _last_giveup_count == 1 then
                core.log_warning("[EaxAutoQuester] Quest frame would not close after 3 attempts" ..
                    (step_text and (" — step: " .. tostring(step_text)) or "") ..
                    ". Finish this turn-in by hand; the bot will stop touching the frame.")
            end
            return "quest_giveup"
        end
    end

    local quest_action = M.handle_quest_detail()
    if quest_action then return quest_action end
    -- If quest detail frame detected but throttled, signal stay in INTERACT
    if _last_quest_time > 0 and _core_time() - _last_quest_time < 1.0 then
        local ok_link, link = pcall(function() return _quests.get_quest_item_link("choice", 1) end)
        local ok_money, reward_money = pcall(function() return _quests.get_reward_money() end)
        if (ok_link and link and link ~= "") or (ok_money and reward_money and reward_money > 0) then
            return "quest_throttled"
        end
    end

    -- Priority 4: Trainer frame
    local trainer_action = M.handle_trainer()
    if trainer_action then return trainer_action end

    -- Priority 5: Vendor frame — auto-repair and sell junk, then close
    local ok_vendor, vendor_count = pcall(function() return _game_ui.get_vendor_item_count() end)
    if ok_vendor and vendor_count and vendor_count > 0 then
        local _, vendor = pcall(require, "vendor_manager_sylvanas")
        if vendor and vendor.handle_vendor then
            vendor.handle_vendor(nil)
        end
        pcall(function() _quests.close_gossip() end)
        return "vendor_handled"
    end

    dlog("no_frame", "handle_any_frame: no frame detected")
    return nil
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.quest_interaction = M

return M
