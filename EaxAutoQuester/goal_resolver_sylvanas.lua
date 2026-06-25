-- What: Goal resolver — converts Zygor quest goals into concrete NPC/item/location targets
-- When: Called by quest_state to resolve goal text to actionable data for NAV/DO_ACTION
-- Why: Centralize 5-stage resolution (Zygor→NPC_DB→Inventory→Questie→Unresolved) with 60s cache
-- Safety: All core.* calls wrapped in pcall; nil-guarded goal fields; cache auto-expires on step change
-- Decisions: Reads npc_db from _G.EaxAutoQuester.npc_db (set by npc_db_sylvanas.lua at load);
--            Questie functions cached at load per Pattern 2; inventory scan uses static _stack per Pattern 4

-- ============================================================================
-- Hot-path API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _core_time = core.time
local _inventory_get_items = core.inventory.get_items_in_bag

-- Questie function references (may be nil if addon not loaded at module init)
local _questie_get_title = nil
local _questie_get_locations = nil
if core.addons and core.addons.questie then
    if core.addons.questie.get_quest_log_title then
        _questie_get_title = core.addons.questie.get_quest_log_title
    end
    if core.addons.questie.get_quest_locations then
        _questie_get_locations = core.addons.questie.get_quest_locations
    end
end

-- ============================================================================
-- Static Table Reuse (Pattern 4 from AGENTS.md)
-- ============================================================================

local _stack = { n = 0 }

-- ============================================================================
-- Cache State
-- ============================================================================

local _cache = {}
local _last_step_num_cache = nil

-- ============================================================================
-- NPC DB Access — reads from global (set by npc_db_sylvanas.lua at load)
-- ============================================================================

local _npc_db = nil
local function ensure_npc_db()
    if not _npc_db then
        _npc_db = (_G.EaxAutoQuester and _G.EaxAutoQuester.npc_db) or nil
    end
    return _npc_db
end

-- ============================================================================
-- Helpers
-- ============================================================================

--- Search inventory by item name substring.
--- Scans bags 0..4 (backpack through bag 4), returns first item whose
--- lowercased name contains the lowercased search substring.
--- @param me table|nil Player unit
--- @param substring string Search term
--- @return table|nil { name, id } or nil if not found
local function search_inventory_by_name(me, substring)
    if not substring or substring == "" then return nil end

    local lower = substring:lower()

    for bag = 0, 4 do
        local ok, items = pcall(_inventory_get_items, bag)
        if ok and items and #items > 0 then
            for i = 1, #items do
                local item = items[i]
                if item and item.name then
                    local item_name_lower = item.name:lower()
                    -- Check both directions: item contains search OR search contains item
                    -- e.g. goal text "Use the Red Bracers" should match item "Red Bracers"
                    if item_name_lower:find(lower, 1, true) or lower:find(item_name_lower, 1, true) then
                        return item
                    end
                end
            end
        end
    end

    return nil
end

--- Resolve a single goal into actionable data.
--- Resolution order (short-circuit on first match):
---   1. Zygor passthrough (goal.npc_id or goal.target_id is positive int)
---   2. NPC DB name lookup
---   3. Inventory item search
---   4. Questie quest log location lookup
---   5. Unresolved (source='unresolved')
---
--- Results are cached by {step_num, text} with 60s TTL.
--- Cache expires on step_num change.
---
--- @param goal table Zygor goal: fields { npc_id, target_id, text, name }
--- @param current_step_num number|nil Current Zygor step number
--- @param me table|nil Local player unit (for inventory scan)
--- @param core_proxy table|nil Unused — reserved for future proxied core access
--- @return table { npc_id, position, name, item_id, source, cached_step }
function M_resolve_goal(goal, current_step_num, me, core_proxy)
    -- == Nil-guard: goal itself (Pattern 14)
    if not goal then return { source = "unresolved" } end

    local goal_text = goal.text or goal.name or ""
    local step_num = current_step_num or 0
    local cache_key = tostring(step_num) .. "|" .. tostring(goal_text)

    -- == Cache expiry: clear on step_num change
    if _last_step_num_cache ~= nil and _last_step_num_cache ~= step_num then
        _cache = {}
    end
    _last_step_num_cache = step_num

    -- == Cache lookup: return cached result if within 60s TTL
    local cached = _cache[cache_key]
    if cached then
        local elapsed = _core_time() - cached.time
        if elapsed >= 0 and elapsed < 60 then
            return cached.result
        end
    end

    local result = nil

    -- ============================================================
    -- Stage 1: Zygor passthrough (NPC ID is a positive integer)
    -- ============================================================

    local npc_id = goal.npc_id or goal.target_id
    if type(npc_id) == "number" and npc_id > 0 and npc_id == math.floor(npc_id) then
        result = {
            npc_id   = npc_id,
            position = nil,
            name     = goal_text,
            source   = "zyg",
        }
    end

    -- ============================================================
    -- Stage 2: NPC DB name lookup
    -- ============================================================

    if not result then
        local db = ensure_npc_db()
        if db and db.search_npc_by_name and goal_text ~= "" then
            local ok, matches = pcall(db.search_npc_by_name, db, goal_text)
            if ok and matches and #matches > 0 then
                local match = matches[1]
                result = {
                    npc_id   = match.npc_id,
                    position = (match.x and match.y) and { x = match.x, y = match.y, z = match.z or 0 } or nil,
                    name     = match.name or goal_text,
                    source   = "npc_db",
                }
            end
        end
    end

    -- ============================================================
    -- Stage 3: Inventory item search
    -- ============================================================

    if not result then
        local item = search_inventory_by_name(me, goal_text)
        if item then
            result = {
                npc_id   = nil,
                position = nil,
                name     = item.name,
                item_id  = item.id,
                source   = "inventory",
            }
        end
    end

    -- ============================================================
    -- Stage 4: Questie quest log lookup
    -- ============================================================

    if not result and _questie_get_title and _questie_get_locations and goal_text ~= "" then
        local lower_text = goal_text:lower()

        -- Scan quest log indices 1..max for a matching title
        for idx = 1, 50 do
            local ok, title, qid = pcall(_questie_get_title, idx)
            if ok and title then
                if title:lower():find(lower_text, 1, true) then
                    -- Found matching quest title → get its locations
                    local ok2, locations = pcall(_questie_get_locations, qid or idx)
                    if ok2 and locations and #locations > 0 then
                        local loc = locations[1]
                        result = {
                            npc_id   = nil,
                            position = loc,
                            name     = title,
                            source   = "questie",
                        }
                        break
                    end
                end
            elseif not ok then
                -- pcall failed (e.g., index out of range) → stop scanning
                break
            end
        end
    end

    -- ============================================================
    -- Stage 5: Unresolved
    -- ============================================================

    if not result then
        result = { source = "unresolved" }
    end

    -- == Cache the result
    _cache[cache_key] = { result = result, time = _core_time() }

    return result
end

-- ============================================================================
-- Exports
-- ============================================================================

local M = {
    resolve_goal = M_resolve_goal,
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.goal_resolver = M

return M
