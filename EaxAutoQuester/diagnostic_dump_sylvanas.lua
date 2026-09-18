-- diagnostic_dump_sylvanas.lua — One-shot diagnostic for quest-object mismatch hunting.
-- WHAT:  dumps nearby objects + Questie/Zygor/quest-log cross-reference.
-- WHEN:  call M.dump() from console or bind to a key when standing near
--        a quest object that EaxESP/EaxAutoQuester fails to detect.
-- WHY:   reveals name mismatches (plural vs singular), missing is_quest_unit
--        flags, and whether Questie/Zygor/core APIs disagree on item names.
-- SAFETY: all API calls pcall-guarded; nil-safe; produces no errors.

local M = {}

local function safe_call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end

local function log(fmt, ...)
    local c = rawget(_G, "core")
    if c and type(c.log) == "function" then
        pcall(c.log, string.format(fmt, ...))
    end
end

-- ============================================================================
-- Section 1 — Nearby Objects (raw scan)
-- ============================================================================
local function dump_nearby_objects()
    log("===== DIAGNOSTIC: Nearby Objects =====")

    local me = safe_call(function()
        local c = rawget(_G, "core")
        return c and c.object_manager and c.object_manager.get_local_player and c.object_manager.get_local_player()
    end)
    if not me then
        log("  [ERR] No local player")
        return
    end

    local me_pos = safe_call(function() return me:get_position() end)
    local mx, my, mz = 0, 0, 0
    if type(me_pos) == "table" then
        mx, my, mz = me_pos.x or 0, me_pos.y or 0, me_pos.z or 0
    end
    log("  Player pos: (%.2f, %.2f, %.2f)", mx, my, mz)

    local c = rawget(_G, "core")
    local sources = {}
    if c and c.object_manager then
        local om = c.object_manager
        if type(om.get_visible_objects) == "function" then
            sources[#sources + 1] = { name = "visible", fn = om.get_visible_objects }
        end
        if type(om.get_all_objects) == "function" then
            sources[#sources + 1] = { name = "all", fn = om.get_all_objects }
        end
    end

    if #sources == 0 then
        log("  [ERR] No object scan API available")
        return
    end

    for _, src in ipairs(sources) do
        local objs = safe_call(src.fn)
        if not objs or #objs == 0 then
            log("  [%s] No objects returned", src.name)
        else
            log("  [%s] Total objects: %d", src.name, #objs)
            local printed = 0
            local limit = 30  -- cap per source to avoid log spam

            for i = 1, #objs do
                if printed >= limit then break end
                local obj = objs[i]
                if obj then
                    local name = safe_call(function() return obj:get_name() end) or "?"
                    local npc_id = safe_call(function() return obj:get_npc_id() end)
                    local item_id = safe_call(function() return obj:get_item_id() end)
                    local is_unit = safe_call(function() return obj:is_unit() end)
                    local is_item = safe_call(function() return obj:is_item() end)
                    local is_quest = safe_call(function() return obj:is_quest_unit() end)
                    local can_use = safe_call(function() return obj:can_be_used() end)
                    local has_loot = safe_call(function() return obj:has_loot() end)
                    local pos = safe_call(function() return obj:get_position() end)
                    local dist = -1
                    if pos and mx ~= 0 then
                        local dx, dy = (pos.x or 0) - mx, (pos.y or 0) - my
                        dist = math.sqrt(dx * dx + dy * dy)
                    end

                    -- Only print quest-relevant objects OR very close objects (< 15yd)
                    local relevant = (is_quest == true) or (is_item == true) or (can_use == true) or (has_loot == true) or (dist > 0 and dist < 15)
                    if relevant or printed < 10 then
                        log("    [%s][%d] name='%s' npc_id=%s item_id=%s is_unit=%s is_item=%s is_quest=%s can_use=%s has_loot=%s dist=%.1f",
                            src.name, i, name,
                            tostring(npc_id or "nil"),
                            tostring(item_id or "nil"),
                            tostring(is_unit),
                            tostring(is_item),
                            tostring(is_quest),
                            tostring(can_use),
                            tostring(has_loot),
                            dist)
                        printed = printed + 1
                    end
                end
            end
            if printed >= limit then
                log("    ... (%d more objects hidden — increase limit if needed)", #objs - limit)
            end
        end
    end
end

-- ============================================================================
-- Section 2 — Questie Data
-- ============================================================================
local function dump_questie()
    log("===== DIAGNOSTIC: Questie =====")
    local c = rawget(_G, "core")
    local q = c and c.addons and c.addons.questie
    if not q then
        log("  [SKIP] Questie API not available")
        return
    end

    local loaded = safe_call(q.is_loaded) or safe_call(q.is_available)
    log("  Questie loaded: %s", tostring(loaded))
    if not loaded then return end

    -- Active quest NPC IDs
    local npc_ids = safe_call(q.get_quest_npc_ids)
    if npc_ids and #npc_ids > 0 then
        log("  Questie NPC IDs (%d): %s", #npc_ids, table.concat(npc_ids, ", "))
    else
        log("  Questie NPC IDs: (none)")
    end

    -- Quest log -> Questie objectives cross-reference
    local quests = safe_call(function()
        local r = {}
        local num = c.quests and c.quests.get_num_quest_log_entries and c.quests.get_num_quest_log_entries()
        if not num then return nil end
        for i = 1, num do
            local info = c.quests.get_quest_log_title(i)
            if info and not info.is_header and info.quest_id then
                r[#r + 1] = { idx = i, id = info.quest_id, title = info.title, level = info.level }
            end
        end
        return r
    end)

    if not quests or #quests == 0 then
        log("  No active quests in log")
        return
    end

    log("  Active quests: %d", #quests)
    for _, qinfo in ipairs(quests) do
        log("  --- Quest [%d] '%s' (Lv %d) ---", qinfo.id, qinfo.title, qinfo.level)

        -- Questie objectives
        local objectives = safe_call(q.get_quest_objectives, qinfo.id)
        if objectives and #objectives > 0 then
            for j, o in ipairs(objectives) do
                local text = (type(o) == "table" and o.text) or tostring(o)
                local otype = (type(o) == "table" and o.type) or "?"
                local finished = (type(o) == "table" and o.finished) or false
                log("    [Questie obj %d] type=%s finished=%s text='%s'", j, tostring(otype), tostring(finished), text)
            end
        else
            log("    [Questie] No objectives returned")
        end

        -- Questie locations
        local locations = safe_call(q.get_quest_locations, qinfo.id)
        if locations and #locations > 0 then
            for j, loc in ipairs(locations) do
                local name = (type(loc) == "table" and loc.name) or "?"
                local npc_id = (type(loc) == "table" and loc.npc_id) or "?"
                log("    [Questie loc %d] name='%s' npc_id=%s", j, name, tostring(npc_id))
            end
        else
            log("    [Questie] No locations returned")
        end
    end
end

-- ============================================================================
-- Section 3 — Zygor Data
-- ============================================================================
local function dump_zygor()
    log("===== DIAGNOSTIC: Zygor =====")
    local c = rawget(_G, "core")
    local z = c and c.addons and c.addons.zygor
    if not z then
        log("  [SKIP] Zygor API not available")
        return
    end

    local loaded = safe_call(z.is_loaded) or safe_call(z.is_available)
    log("  Zygor loaded: %s", tostring(loaded))
    if not loaded then return end

    local has_step = safe_call(z.has_current_step)
    log("  Has current step: %s", tostring(has_step))

    local step = safe_call(z.get_current_step)
    if step and type(step) == "table" then
        log("  Step num=%s complete=%s",
            tostring(step.step_num or step.number or "?"),
            tostring(step.is_complete or "?"))
        local goals = step.goals
        if type(goals) == "table" and #goals > 0 then
            for i, g in ipairs(goals) do
                local text = (type(g) == "table" and (g.text or g.action or g.name)) or tostring(g)
                log("    [Zygor goal %d] '%s'", i, text)
            end
        else
            log("    [Zygor] No goals in step")
        end
    else
        log("  [Zygor] No current step")
    end

    local wp = safe_call(z.get_current_waypoint)
    if wp and type(wp) == "table" then
        log("  Waypoint: title='%s' type='%s' map=%s (%.2f, %.2f) dist=%.1f",
            tostring(wp.title or "?"),
            tostring(wp.type or "?"),
            tostring(wp.map_id or "?"),
            wp.x or 0, wp.y or 0,
            wp.dist or -1)
    else
        log("  [Zygor] No current waypoint")
    end

    local objectives = safe_call(z.get_objectives)
    if type(objectives) == "table" and #objectives > 0 then
        for i, o in ipairs(objectives) do
            log("    [Zygor objective %d] %s", i, tostring(o))
        end
    end
end

-- ============================================================================
-- Section 4 — Core Quest Log (leaderboards = objective text from WoW client)
-- ============================================================================
local function dump_quest_log()
    log("===== DIAGNOSTIC: Core Quest Log =====")
    local c = rawget(_G, "core")
    if not c or not c.quests then
        log("  [SKIP] core.quests not available")
        return
    end

    local num = safe_call(c.quests.get_num_quest_log_entries)
    if not num or num == 0 then
        log("  No quest log entries")
        return
    end

    log("  Quest log entries: %d", num)
    for i = 1, num do
        local info = safe_call(c.quests.get_quest_log_title, i)
        if info and not info.is_header and info.quest_id then
            log("  --- [%d] '%s' (Lv %d) complete=%s ---", info.quest_id, info.title, info.level, tostring(info.is_complete))

            -- Leaderboards = objective progress text
            local num_obj = safe_call(c.quests.get_num_quest_leader_boards, i)
            if num_obj and num_obj > 0 then
                for j = 1, num_obj do
                    local text = safe_call(c.quests.get_quest_log_leader_board, j, i)
                    log("    [Leaderboard %d] '%s'", j, tostring(text or "?"))
                end
            else
                log("    [Leaderboard] No objectives")
            end
        end
    end
end

-- ============================================================================
-- Section 5 — Cross-reference: quest item names vs nearby object names
-- ============================================================================
local function dump_cross_reference()
    log("===== DIAGNOSTIC: Cross-Reference (quest item names vs objects) =====")

    -- Collect quest-item keywords from quest log leaderboards
    local c = rawget(_G, "core")
    if not c or not c.quests then return end

    local item_keywords = {}
    local num = safe_call(c.quests.get_num_quest_log_entries)
    if num then
        for i = 1, num do
            local info = safe_call(c.quests.get_quest_log_title, i)
            if info and not info.is_header then
                local num_obj = safe_call(c.quests.get_num_quest_leader_boards, i)
                if num_obj then
                    for j = 1, num_obj do
                        local text = safe_call(c.quests.get_quest_log_leader_board, j, i)
                        if text then
                            -- Extract item names from common patterns:
                            -- "Collect 5 Bundle of Wood" -> "Bundle of Wood"
                            -- "Bundle of Wood: 0/5" -> "Bundle of Wood"
                            local name = text:match("^([^:]+)[:/]") or text:match("[Cc]ollect%s+%d+%s+(.+)") or text:match("[Uu]se%s+(.+)%s+[Oo]n") or text:match("[Ll]oot%s+(.+)")
                            if name then
                                name = name:gsub("^%s+", ""):gsub("%s+$", "")
                                if #name > 2 then
                                    item_keywords[#item_keywords + 1] = name:lower()
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if #item_keywords == 0 then
        log("  No item keywords extracted from quest log")
        return
    end

    log("  Extracted item keywords (%d): %s", #item_keywords, table.concat(item_keywords, ", "))

    -- Scan nearby objects for name matches
    local me = safe_call(function() return c.object_manager.get_local_player() end)
    local me_pos = me and safe_call(function() return me:get_position() end)
    local mx, my = 0, 0
    if type(me_pos) == "table" then mx, my = me_pos.x or 0, me_pos.y or 0 end

    local om = c.object_manager
    local scan_fn = (type(om.get_visible_objects) == "function") and om.get_visible_objects or om.get_all_objects
    if type(scan_fn) ~= "function" then return end

    local objs = safe_call(scan_fn)
    if not objs then return end

    local found_any = false
    for _, kw in ipairs(item_keywords) do
        local matches = {}
        for i = 1, math.min(#objs, 100) do
            local obj = objs[i]
            if obj then
                local name = safe_call(function() return obj:get_name() end)
                if name and name:lower():find(kw, 1, true) then
                    local pos = safe_call(function() return obj:get_position() end)
                    local dist = -1
                    if pos and mx ~= 0 then
                        local dx, dy = (pos.x or 0) - mx, (pos.y or 0) - my
                        dist = math.sqrt(dx * dx + dy * dy)
                    end
                    matches[#matches + 1] = string.format("'%s' (dist=%.1f)", name, dist)
                end
            end
        end
        if #matches > 0 then
            found_any = true
            log("  Keyword '%s' -> matches: %s", kw, table.concat(matches, ", "))
        else
            log("  Keyword '%s' -> NO matches within 100 scanned objects", kw)
        end
    end

    if not found_any then
        log("  WARNING: None of the extracted quest item keywords matched any nearby object name!")
        log("  This usually means Questie/Zygor uses plural forms ('Apples') while the world object uses singular ('Apple').")
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Run the full diagnostic dump to core.log.
--- Call this when standing next to a quest object that isn't detected.
function M.dump()
    log("========== EAX DIAGNOSTIC DUMP START ==========")
    dump_nearby_objects()
    dump_questie()
    dump_zygor()
    dump_quest_log()
    dump_cross_reference()
    log("========== EAX DIAGNOSTIC DUMP END ==========")
end

--- Convenience: dump only nearby objects (lightweight).
function M.dump_objects()
    log("========== EAX OBJECT DUMP START ==========")
    dump_nearby_objects()
    log("========== EAX OBJECT DUMP END ==========")
end

--- Convenience: dump only quest data (Questie + Zygor + log).
function M.dump_quests()
    log("========== EAX QUEST DUMP START ==========")
    dump_questie()
    dump_zygor()
    dump_quest_log()
    log("========== EAX QUEST DUMP END ==========")
end

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.diagnostic_dump = M

return M
