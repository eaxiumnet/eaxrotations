-- What: DO_ACTION state handler — execute Zygor goal actions (loot, kill, talk, area)
-- When: Called by coordinator when shared._state == "DO_ACTION"
-- Why: Centralize all goal execution: targeting, distance checks, area brute-force, NPC DB lookups
-- API: exports run(shared, ctx) → next_state string, execute_goal_action as internal helper

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

local goal_resolver_ok, goal_resolver = pcall(require, "EaxAutoQuester/goal_resolver_sylvanas")
local quest_blacklist_ok, quest_blacklist = pcall(require, "EaxAutoQuester/quest_blacklist_sylvanas")

-- ============================================================================
-- Goal Execution — Execute a single goal action based on its type
-- ============================================================================

--- Execute a single goal action based on its type.
--- Types: loot/click/use, kill, talk/gossip, area
--- @param shared table Shared state variables
--- @param ctx table Per-tick context with submodules, me, helpers
--- @param action_type string Goal action type
--- @param goal table|number Goal data from Zygor
--- @return boolean true if action was attempted
local function execute_goal_action(shared, ctx, action_type, goal)
    local npc = ctx.npc_manager
    local combat = ctx.combat_helper

    if action_type == "loot" or action_type == "click" or action_type == "use" then
        -- Quest item usage: if goal has quest_item_id, use it on target
        if type(goal) == "table" and goal.quest_item_id and combat then
            local target = ctx.me and ctx.me:get_target()
            if target then
                local used = combat.use_quest_item_on_target(goal.quest_item_id)
                if used then
                    ctx.debug_log("DO_ACTION: used quest item " .. tostring(goal.quest_item_id))
                    return true
                end
            end
        end

        -- Find and target interactable object by name
        local obj_name = nil
        if type(goal) == "table" then
            obj_name = ctx.safe(goal.text, ctx.safe(goal.name, nil))
        end

        if obj_name and npc then
            local objects = npc.find_interactable_objects(obj_name, ctx.object_scanner)
            if objects and #objects > 0 then
                local ok = pcall(core.input.set_target, objects[1])
                if ok then
                    ctx.debug_log("DO_ACTION: targeted '" .. tostring(obj_name) .. "'")
                end
                return true
            end
        end

        -- Fallback: try to find by goal NPC ID
        if type(goal) == "table" and npc then
            local npc_id = ctx.safe(goal.npc_id, ctx.safe(goal.id, nil))
            if npc_id then
                local nearest = npc.find_nearest_npc({ npc_id }, 20, nil, ctx.object_scanner)
                if nearest then
                    pcall(core.input.set_target, nearest)
                    ctx.debug_log("DO_ACTION: targeted NPC " .. tostring(npc_id))
                    return true
                end
            end
        end

        -- No target found
        ctx.debug_log("DO_ACTION: no target for " .. action_type)
        return true -- still count as done (will re-evaluate next cycle)
    end

    if action_type == "kill" then
        local npc = ctx.npc_manager
        if npc then
            local enemy = npc.get_nearest_enemy(50, ctx.object_scanner)
            if enemy then
                if ctx.me then
                    local _, me_pos = pcall(function() return ctx.me:get_position() end)
                    local _, enemy_pos = pcall(function() return enemy:get_position() end)
                    if me_pos and enemy_pos then
                        local dist_sq = ctx.utils and ctx.utils.squared_distance(me_pos, enemy_pos) or 1e9
                        if dist_sq > 9 then
                            shared._nav_destination = enemy_pos
                            local dist_yds = math.floor(math.sqrt(dist_sq))
                            ctx.debug_log("DO_ACTION: kill — approaching enemy (" .. tostring(dist_yds) .. "yd)")
                            return false
                        end
                        local mh_ok, mh = pcall(require, "common/utility/movement_handler")
                        if mh_ok and mh and mh.look_at_target then
                            if mh.pause_movement_light then
                                pcall(function() mh:pause_movement_light(0.5) end)
                            end
                            pcall(function() mh:look_at_target(0.5, 0, enemy) end)
                        end
                        local NS = _G.EaxRotations
                        if NS and NS.start_auto_attack then
                            local ok = pcall(function() NS.start_auto_attack(enemy) end)
                            if ok then
                                ctx.debug_log("DO_ACTION: kill — auto-attacking")
                            end
                        end
                        pcall(core.input.set_target, enemy)
                        ctx.debug_log("DO_ACTION: kill — tagged enemy in melee range")
                        return true
                    end
                end
            end
        end
        ctx.debug_log("DO_ACTION: no enemy to tag")
        return true
    end

    if action_type == "talk" or action_type == "gossip" then
        if npc then
            local npc_ids = npc.find_quest_npcs()
            if npc_ids then
                local nearest = npc.find_nearest_npc(npc_ids, 20, nil, ctx.object_scanner)
                if nearest then
                    pcall(core.input.set_target, nearest)
                    ctx.debug_log("DO_ACTION: targeted quest NPC for talk")
                    return true
                end
            end
        end
        ctx.debug_log("DO_ACTION: no quest NPC to talk to")
        return true
    end

    if action_type == "area" then
        local zygor = ctx.zygor
        if zygor then
            local step = zygor.get_current_step_info()
            if step and step.is_complete then
                ctx.debug_log("DO_ACTION: area — step complete")
                return true
            end
            if step and step.step_num and step.step_num ~= shared._last_step_num then
                shared._last_step_num = step.step_num
                ctx.debug_log("DO_ACTION: area — new step " .. tostring(step.step_num))
                return true
            end
        end

        local goal_npc_id = nil
        local goal_target = nil
        if type(goal) == "table" then
            local nid = goal.npc_id or goal.target_id
            if nid and nid > 0 then goal_npc_id = nid end
            goal_target = goal.target or goal.npc
        end

        -- Item A: goal_resolver integration - try to resolve name-only goals via NPC DB / Questie
        local resolved = nil
        if goal_resolver_ok and goal_resolver and goal_resolver.resolve_goal then
            local step = zygor.get_current_step_info()
            local step_num = (step and step.step_num) or shared._last_step_num or 1
            local ok, res = pcall(goal_resolver.resolve_goal, goal, step_num, ctx.me)
            if ok and res and res.source ~= "unresolved" then
                resolved = res
                ctx.debug_log("DO_ACTION: resolved goal via " .. tostring(res.source) .. " npc_id=" .. tostring(res.npc_id or "nil"))
            end
        end
        if resolved then
            if resolved.npc_id and (not goal_npc_id or goal_npc_id == 0) then
                goal_npc_id = resolved.npc_id
            end
            if resolved.position and ctx.me then
                local _, me_pos = pcall(function() return ctx.me:get_position() end)
                if me_pos and ctx.utils then
                    local dist_sq = ctx.utils.squared_distance(me_pos, resolved.position)
                    if dist_sq > 100 then
                        shared._nav_destination = resolved.position
                        ctx.debug_log("DO_ACTION: area - navigating to resolved position")
                        return false
                    end
                end
            end
        end

        ctx.debug_log("DO_ACTION: area goal — npc_id=" .. tostring(goal_npc_id or "nil") .. " target=" .. tostring(goal_target or "nil"))

        -- Questgiver fallback: when Zygor gave us a goal with no NPC identity
        -- (npc_id=0 and target="" — common for "turn in here" / "accept here" steps),
        -- query Questie via the existing npc_manager helper which unions Questie's
        -- quest NPC IDs with the current Zygor step's goal NPCs. Search up to 100yd
        -- — wider than 25yd because questgivers often sit 30-80yd from the waypoint.
        --
        -- Anti-spam cooldown: action_pause is 0.5s, so without a cooldown this
        -- branch fires twice per second. Questie data can return wrong NPC ids
        -- (e.g., 327 = Goldtooth mapped to "Kobold Miner" in the quest data) and
        -- re-targeting the same wrong NPC every 0.5s is the spam loop. 5s
        -- cooldown = try once, then wait. Long enough for the actual interaction
        -- to take effect (gossip frame, quest accept/turn-in).
        if not goal_npc_id and not (goal_target and goal_target ~= "") and npc then
            if shared._questie_fallback_time and ctx.now - shared._questie_fallback_time < 5.0 then
                return true
            end
            local quest_npc_ids = npc.find_quest_npcs()
            if quest_npc_ids and #quest_npc_ids > 0 then
                local nearest = npc.find_nearest_npc(quest_npc_ids, 100, nil, ctx.object_scanner)
                if nearest then
                    local _, npos = pcall(function() return nearest:get_position() end)
                    local _, nname = pcall(function() return nearest:get_name() end)
                    local _, nguid = pcall(function() return nearest:get_guid() end)
                    local is_hostile = false
                    local ok_att, can_att = pcall(function() return nearest:can_attack(ctx.me) end)
                    if ok_att and can_att then is_hostile = true end
                    if npos and ctx.me then
                        local _, me_pos = pcall(function() return ctx.me:get_position() end)
                        if me_pos and ctx.utils then
                            local dist_sq = ctx.utils.squared_distance(me_pos, npos)
                            if dist_sq > 25 then
                                shared._nav_destination = npos
                                shared._questie_fallback_time = ctx.now
                                shared._questie_last_guid = nguid
                                ctx.debug_log("DO_ACTION: area — navigating to quest NPC '" .. tostring(nname or "unknown") .. "' (" .. tostring(math.floor(math.sqrt(dist_sq))) .. "yd) [Questie fallback]")
                                return false
                            end
                        end
                    end
                    pcall(core.input.set_target, nearest)
                    if is_hostile then
                        local NS = _G.EaxRotations
                        if NS and NS.start_auto_attack then
                            pcall(function() NS.start_auto_attack(nearest) end)
                        end
                        ctx.debug_log("DO_ACTION: area — set target on hostile '" .. tostring(nname or "unknown") .. "' (combat handles) [Questie fallback]")
                    else
                        pcall(core.input.interact_with_object, nearest)
                        ctx.debug_log("DO_ACTION: area — targeted quest NPC '" .. tostring(nname or "unknown") .. "' [Questie fallback]")
                    end
                    shared._questie_fallback_time = ctx.now
                    shared._questie_last_guid = nguid
                    return true
                end
                ctx.debug_log("DO_ACTION: area — no quest NPC found in 100yd (Questie fallback exhausted)")
            end
        end

        if goal_npc_id then
            local npc_db_ok, npc_db = pcall(require, "npc_db_sylvanas")
            if npc_db_ok and npc_db.find_npc_spawn then
                local map_id = nil
                if ctx.me then
                    local _, mid = pcall(function() return core.get_map_id() end)
                    if mid then map_id = mid end
                end
                local spawn = npc_db.find_npc_spawn(goal_npc_id, map_id)
                if spawn then
                    local _, pos = pcall(function() return ctx.me:get_position() end)
                    if pos and ctx.utils then
                        local dist_sq = ctx.utils.squared_distance(pos, spawn)
                        if dist_sq > 100 then
                            shared._nav_destination = { x = spawn.x, y = spawn.y, z = spawn.z }
                            ctx.debug_log("DO_ACTION: area — navigating to NPC spawn")
                            return false
                        end
                    end
                end
            end
            if npc then
                local nearest = npc.find_nearest_npc({ goal_npc_id }, 50, nil, ctx.object_scanner)
                if nearest then
                    local _, npos = pcall(function() return nearest:get_position() end)
                    if npos and ctx.me then
                        local _, me_pos = pcall(function() return ctx.me:get_position() end)
                        if me_pos and ctx.utils then
                            local dist_sq = ctx.utils.squared_distance(me_pos, npos)
                            if dist_sq > 25 then
                                shared._nav_destination = npos
                                ctx.debug_log("DO_ACTION: area — approaching NPC " .. tostring(goal_npc_id) .. " (" .. tostring(math.floor(math.sqrt(dist_sq))) .. "yd)")
                                return false
                            end
                        end
                    end
                    pcall(core.input.set_target, nearest)
                    pcall(core.input.interact_with_object, nearest)
                    shared._post_interact_timer = ctx.now + 0.3
                    shared._at_quest_object_timer = ctx.now + 5.0
                    ctx.debug_log("DO_ACTION: area — targeted NPC " .. tostring(goal_npc_id))
                    return true
                end
            end
        end

        if npc and goal_target then
            local names_to_try = {}
            for name in goal_target:gmatch("[^,]+") do
                local trimmed = name:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    names_to_try[#names_to_try + 1] = trimmed
                end
            end
            -- Plural→singular fallback: Zygor often pluralizes the FIRST word
            -- (e.g. "Bundles of Wood" → "Bundle of Wood"). Also handle simple
            -- plurals at the end (e.g. "Milly's Harvest Pumpkins").
            local n = #names_to_try
            for i = 1, n do
                local name = names_to_try[i]
                -- Try 1: strip trailing 's' from first word ("Bundles of Wood")
                local first_word = name:match("^(%S+)")
                if first_word and first_word:sub(-1) == "s" then
                    local singular_first = name:gsub("^" .. first_word, first_word:sub(1, -2), 1)
                    names_to_try[#names_to_try + 1] = singular_first
                end
                -- Try 2: strip trailing 's' from whole string ("Pumpkins")
                if name:sub(-1) == "s" then
                    local singular = name:sub(1, -2)
                    if singular ~= "" then
                        names_to_try[#names_to_try + 1] = singular
                    end
                end
            end
            for _, name in ipairs(names_to_try) do
                local objects = npc.find_interactable_objects(name, ctx.object_scanner)
                if objects and #objects > 0 then
                    local obj = nil
                    local best_dist_sq = 1e9
                    local _, me_pos_scan = pcall(function() return ctx.me:get_position() end)
                    for _, candidate in ipairs(objects) do
                        local _, cpos = pcall(function() return candidate:get_position() end)
                        if cpos and me_pos_scan and ctx.utils then
                            local dsq = ctx.utils.squared_distance(me_pos_scan, cpos)
                            if dsq < best_dist_sq then
                                best_dist_sq = dsq
                                obj = candidate
                            end
                        end
                    end
                    if not obj then obj = objects[1] end
                    if ctx.me then
                        local _, me_pos = pcall(function() return ctx.me:get_position() end)
                        local _, obj_pos = pcall(function() return obj:get_position() end)
                        if me_pos and obj_pos and ctx.utils then
                            local dist_sq = ctx.utils.squared_distance(me_pos, obj_pos)
                            if dist_sq > 25 then
                                shared._nav_destination = obj_pos
                                ctx.debug_log("DO_ACTION: area — approaching '" .. tostring(name) .. "' (" .. tostring(math.floor(math.sqrt(dist_sq))) .. "yd)")
                                return false
                            end
                            -- Face the object before interacting. WoW requires the
                            -- player to face a game object to right-click it
                            -- (units auto-face, game objects don't). Without
                            -- this, interact_with_object is a no-op for the
                            -- Milly's Harvest pumpkins and similar nodes.
                            pcall(core.input.look_at, obj_pos)
                        end
                    end
                    pcall(core.input.set_target, obj)

                    -- Distinguish quest objects from enemy units.
                    -- Enemy units (e.g. "Young Forest Bear") should NOT get the
                    -- 5s quest-object timer — that timer locks the bot in IDLE
                    -- while the enemy is free to attack. Let EaxRotations handle
                    -- combat via auto-attack on the selected target.
                    local is_enemy = false
                    if ctx.me then
                        local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
                        if ok_unit and is_unit then
                            local ok_att, can_att = pcall(function() return obj:can_attack(ctx.me) end)
                            if ok_att and can_att then is_enemy = true end
                        end
                    end

                    if is_enemy then
                        -- Unit: start auto-attack via EaxRotations if available
                        local NS = _G.EaxRotations
                        if NS and NS.start_auto_attack then
                            pcall(function() NS.start_auto_attack(obj) end)
                        end
                        shared._post_interact_timer = ctx.now + 0.3
                        ctx.debug_log("DO_ACTION: area — targeted enemy '" .. tostring(name) .. "', auto-attacking")
                        return true
                    end

                    -- Game object: use_object for gathering/interaction
                    pcall(core.input.use_object, obj)
                    shared._post_interact_timer = ctx.now + 0.3
                    shared._at_quest_object_timer = ctx.now + 5.0
                    ctx.debug_log("DO_ACTION: area — targeted quest object '" .. tostring(name) .. "'")
                    return true
                end
            end
            ctx.debug_log("DO_ACTION: area — no interactable objects named '" .. tostring(goal_target) .. "'")
        end

        if goal_target and npc and ctx.me then
            local _, pos = pcall(function() return ctx.me:get_position() end)
            if pos then
                local objects = (ctx.object_scanner and ctx.object_scanner.get_visible_objects and ctx.object_scanner.get_visible_objects()) or {}
                if objects and #objects > 0 then
                    local target_names = {}
                    for name in goal_target:gmatch("[^,]+") do
                        local trimmed = name:match("^%s*(.-)%s*$")
                        if trimmed and trimmed ~= "" then
                            target_names[#target_names + 1] = trimmed:lower()
                        end
                    end
                    local best_enemy = nil
                    local best_enemy_sq = 1e9
                    local limit = #objects > 50 and 50 or #objects
                    local found_count = 0
                    for i = 1, limit do
                        local obj = objects[i]
                        if not obj then break end
                        local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
                        if ok_unit and is_unit then
                            local ok_attack, can_attack = pcall(function() return obj:can_attack(ctx.me) end)
                            if ok_attack and can_attack then
                                local ok_dead, is_dead = pcall(function() return obj:is_dead() end)
                                local dead_filtered = ok_dead and is_dead
                                -- Also filter lootable units — the real-game
                                -- is_dead() check is unreliable (returns false
                                -- for corpses that still have loot), but
                                -- can_be_looted() reliably returns true for
                                -- corpses. A lootable "enemy" is a corpse
                                -- that hasn't been looted yet, not a live
                                -- target. Live observed: Stonetusk Boar loop
                                -- — bot kept targeting the same 2yd "enemy"
                                -- because the API said it was alive (it was
                                -- actually a corpse with loot).
                                if not dead_filtered then
                                    local ok_loot, can_loot = pcall(function() return obj:can_be_looted() end)
                                    if ok_loot and can_loot then
                                        dead_filtered = true
                                    end
                                end
                                if not dead_filtered then
                                    local ok_name, obj_name = pcall(function() return obj:get_name() end)
                    if ok_name and obj_name then
                        local obj_name_lower = obj_name:lower()
                        for _, tname in ipairs(target_names) do
                            local matched = false
                            if obj_name_lower:find(tname, 1, true) then
                                matched = true
                            elseif tname:len() > 1 and tname:sub(-1) == "s" then
                                local singular = tname:sub(1, -2)
                                if obj_name_lower:find(singular, 1, true) then
                                    matched = true
                                end
                            end
                            if matched then
                                found_count = found_count + 1
                                local ok_pos, opos = pcall(function() return obj:get_position() end)
                                if ok_pos and opos then
                                    local dx = (opos.x or 0) - (pos.x or 0)
                                    local dy = (opos.y or 0) - (pos.y or 0)
                                    local d_sq = dx * dx + dy * dy
                                    if d_sq < best_enemy_sq then
                                        best_enemy = obj
                                        best_enemy_sq = d_sq
                                    end
                                end
                                break
                            end
                        end
                    end
                                end
                            end
                        end
                    end
                    ctx.debug_log("DO_ACTION: area — enemy scan found " .. tostring(found_count) .. " matching targets")
                    if best_enemy then
                        local dist_yds = math.floor(math.sqrt(best_enemy_sq))
                        ctx.debug_log("DO_ACTION: area — best_enemy_sq=" .. tostring(best_enemy_sq) .. " dist_yds=" .. tostring(dist_yds))
                        if best_enemy_sq > 9 then
                            local _, enemy_pos = pcall(function() return best_enemy:get_position() end)
                            if enemy_pos then
                                shared._nav_destination = enemy_pos
                                ctx.debug_log("DO_ACTION: area — approaching enemy '" .. tostring(goal_target) .. "' (" .. tostring(dist_yds) .. "yd)")
                                return false
                            end
                        else
                            local _, enemy_pos = pcall(function() return best_enemy:get_position() end)
                            if enemy_pos then
                                local nearby_count = 0
                                for j = 1, limit do
                                    local other = objects[j]
                                    if other and other ~= best_enemy then
                                        local ok_other, is_other = pcall(function() return other:is_unit() end)
                                        if ok_other and is_other then
                                            local ok_attack, can_attack = pcall(function() return other:can_attack(ctx.me) end)
                                            if ok_attack and can_attack then
                                                local ok_other_dead, is_other_dead = pcall(function() return other:is_dead() end)
                                                if not (ok_other_dead and is_other_dead) then
                                                    local ok_other_pos, other_pos = pcall(function() return other:get_position() end)
                                                    if ok_other_pos and other_pos then
                                                        local dx = (other_pos.x or 0) - (enemy_pos.x or 0)
                                                        local dy = (other_pos.y or 0) - (enemy_pos.y or 0)
                                                        if dx * dx + dy * dy < 100 then
                                                            nearby_count = nearby_count + 1
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                if nearby_count > 2 then
                                    ctx.debug_log("DO_ACTION: area — too many nearby enemies (" .. tostring(nearby_count) .. "), skipping")
                                    return true
                                end
                                local mh_ok, mh = pcall(require, "common/utility/movement_handler")
                                if mh_ok and mh and mh.look_at_target then
                                    if mh.pause_movement_light then
                                        pcall(function() mh:pause_movement_light(0.5) end)
                                    end
                                    pcall(function() mh:look_at_target(0.5, 0, best_enemy) end)
                                end
                            end
                            local NS = _G.EaxRotations
                            if NS and NS.start_auto_attack then
                                pcall(function() NS.start_auto_attack(best_enemy) end)
                            end
                            pcall(core.input.set_target, best_enemy)
                            ctx.debug_log("DO_ACTION: area — attacking enemy '" .. tostring(goal_target) .. "' (" .. tostring(dist_yds) .. "yd) nearby=" .. tostring(nearby_count))
                            return true
                        end
                    end
                end
            end
        end

        local AREA_FAIL_BLOCK = 999
        if (shared._area_fail_count or 0) < AREA_FAIL_BLOCK then
            if ctx.me then
                local _, pos = pcall(function() return ctx.me:get_position() end)
                local _, me_guid = pcall(function() return ctx.me:get_guid() end)
                if pos then
                    local objects = (ctx.object_scanner and ctx.object_scanner.get_visible_objects and ctx.object_scanner.get_visible_objects()) or {}
                    if objects and #objects > 0 then
                        ctx.debug_log("DO_ACTION: area — scanning " .. tostring(#objects) .. " objects")
                        local best = nil
                        local best_sq = 1e9
                        local best_guid = nil
                        local best_name = nil
                        local limit = #objects > 50 and 50 or #objects
                        for i = 1, limit do
                            local obj = objects[i]
                            if not obj then break end
                            local skip = false
                            if me_guid then
                                local _, guid = pcall(function() return obj:get_guid() end)
                                if guid and guid == me_guid then skip = true end
                            end
                            if not skip then
                                local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
                                if not (ok_unit and is_unit) then skip = true end
                            end
                            if not skip then
                                local ok_player, is_player = pcall(function() return obj:is_player() end)
                                if ok_player and is_player then skip = true end
                            end
                            if not skip then
                                local ok_enemy, is_enemy = pcall(function() return obj:is_enemy_with(ctx.me) end)
                                if ok_enemy and is_enemy then skip = true end
                            end
                            if not skip then
                                local ok_dead, is_dead = pcall(function() return obj:is_dead() end)
                                if ok_dead and is_dead then
                                    -- Quest objects are often "dead" but still
                                    -- lootable/interactable. Only skip if it can't
                                    -- be looted.
                                    local ok_loot, can_loot = pcall(function() return obj:can_be_looted() end)
                                    if not (ok_loot and can_loot) then skip = true end
                                end
                            end
                            if not skip then
                                local ok_valid = pcall(function() return obj:is_valid() end)
                                if ok_valid then
                                    local ok_pos, opos = pcall(function() return obj:get_position() end)
                                    if ok_pos and opos then
                                        local dx = (opos.x or 0) - (pos.x or 0)
                                        local dy = (opos.y or 0) - (pos.y or 0)
                                        local d_sq = dx * dx + dy * dy
                                        if d_sq < best_sq and d_sq < 625 then
                                            best = obj
                                            best_sq = d_sq
                                            local _, g = pcall(function() return obj:get_guid() end)
                                            if g then best_guid = g end
                                            local _, n = pcall(function() return obj:get_name() end)
                                            if n then best_name = n end
                                        end
                                    end
                                end
                            end
                        end
                        if best then
                            if best_guid and best_guid == shared._area_last_target_guid then
                                shared._area_fail_count = shared._area_fail_count + 1
                            else
                                shared._area_fail_count = 0
                                shared._area_last_target_guid = best_guid
                            end
                            if shared._area_fail_count >= 5 then
                                -- Item H: quest_blacklist integration
                                local quest_id = nil
                                if type(goal) == "table" and goal.quest_id then
                                    quest_id = goal.quest_id
                                end
                                if not quest_id then
                                    local step = zygor.get_current_step_info()
                                    if step and step.goals then
                                        for _, g in ipairs(step.goals) do
                                            if g and g.quest_id then
                                                quest_id = g.quest_id
                                                break
                                            end
                                        end
                                    end
                                end
                                if quest_blacklist_ok and quest_blacklist and quest_blacklist.record_failure and quest_id then
                                    quest_blacklist.record_failure(quest_id, "area_fail")
                                    if quest_blacklist.should_abandon(quest_id) then
                                        local ok_abandon = pcall(function() core.quests.abandon_quest(quest_id) end)
                                        if ok_abandon then
                                            ctx.debug_log("DO_ACTION: area - abandoned quest " .. tostring(quest_id) .. " after repeated failures")
                                        end
                                    end
                                end
                                shared._area_fail_count = 999
                                shared._area_last_target_guid = nil
                                core.log_warning("[EaxAutoQuester] Cannot interact with target - manual help required")
                                local ns = _G.EaxAutoQuester
                                if ns and ns.set_warning then
                                    ns.set_warning("Stuck - cannot interact with NPC here", 0)
                                end
                                ctx.debug_log("DO_ACTION: area - giving up after 5 failed attempts")
                                return true
                            end
                            local _, valid = pcall(function() return best:is_valid() end)
                            if not valid then
                                ctx.debug_log("DO_ACTION: area — target became invalid")
                                return true
                            end
                            pcall(core.input.set_target, best)
                            pcall(core.input.interact_with_object, best)
                            local dist_yds = math.floor(math.sqrt(best_sq))
                            ctx.debug_log("DO_ACTION: area — interacting with " .. tostring(best_name or "nearest NPC") .. " at " .. tostring(dist_yds) .. "yd (attempt " .. tostring(shared._area_fail_count) .. ")")
                            return true
                        else
                            ctx.debug_log("DO_ACTION: area — no valid NPC in 25yd scan")
                        end
                    end
                end
            end
        end

        local npc = ctx.npc_manager
        if npc then
            local enemy = npc.get_nearest_enemy(50, ctx.object_scanner)
            if enemy then
                if ctx.me then
                    local _, me_pos = pcall(function() return ctx.me:get_position() end)
                    local _, enemy_pos = pcall(function() return enemy:get_position() end)
                    if me_pos and enemy_pos then
                        local dist_sq = ctx.utils and ctx.utils.squared_distance(me_pos, enemy_pos) or 1e9
                        if dist_sq > 9 then
                            shared._nav_destination = enemy_pos
                            local dist_yds = math.floor(math.sqrt(dist_sq))
                            ctx.debug_log("DO_ACTION: area — approaching enemy (" .. tostring(dist_yds) .. "yd)")
                            return false
                        end
                        local mh_ok, mh = pcall(require, "common/utility/movement_handler")
                        if mh_ok and mh and mh.look_at_target then
                            if mh.pause_movement_light then
                                pcall(function() mh:pause_movement_light(0.5) end)
                            end
                            pcall(function() mh:look_at_target(0.5, 0, enemy) end)
                        end
                        local NS = _G.EaxRotations
                        if NS and NS.start_auto_attack then
                            pcall(function() NS.start_auto_attack(enemy) end)
                        end
                        pcall(core.input.set_target, enemy)
                        ctx.debug_log("DO_ACTION: area — attacking enemy in range")
                        return true
                    end
                end
            end
        end

        shared._area_wait_timer = ctx.now + 5.0
        ctx.debug_log("DO_ACTION: area — no NPC/enemy found, waiting 5s")
        return true
    end

    -- Unknown action type — skip
    ctx.debug_log("DO_ACTION: unknown type '" .. tostring(action_type) .. "' — skip")
    return true
end

-- ============================================================================
-- State: DO_ACTION — Execute current goal and determine next state
-- ============================================================================

--- Execute the current goal and determine next state.
--- After action, pause 0.5s then transition to IDLE for re-evaluation.
--- Area type waits 2s before returning to IDLE.
--- @param shared table Shared state variables
--- @param ctx table Per-tick context with submodules, me, helpers
--- @return string next_state
function M.run(shared, ctx)
    -- Area wait: hold in DO_ACTION until timer expires
    if shared._area_wait_timer > 0 then
        if ctx.now < shared._area_wait_timer then
            return "DO_ACTION"
        end
        -- Timer done — proceed
        shared._area_wait_timer = 0
        ctx.debug_log("DO_ACTION: area wait done → IDLE")
        return "IDLE"
    end

    -- General action pause (0.5s after non-area actions)
    if shared._action_pause_timer > 0 and ctx.now < shared._action_pause_timer then
        return "DO_ACTION"
    end
    shared._action_pause_timer = 0

    -- Get current step info to find the goal to execute
    local zygor = ctx.zygor
    if not zygor then return "IDLE" end

    local step = zygor.get_current_step_info()
    if not step then return "IDLE" end

    -- Find first uncompleted goal
    local goals = ctx.safe(step.goals, {})
    local current_goal = nil

    for i = 1, #goals do
        local g = goals[i]
        local complete = false
        if type(g) == "table" then
            complete = ctx.safe(g.is_complete, false)
        end
        if not complete then
            current_goal = g
            break
        end
    end

    -- No uncompleted goal — back to IDLE to re-evaluate
    if not current_goal then
        ctx.debug_log("DO_ACTION: no uncompleted goal → IDLE")
        return "IDLE"
    end

    -- Determine action type from goal or cached value
    local action_type = ctx.safe(shared._last_goal_type, "area")
    if type(current_goal) == "table" then
        action_type = ctx.safe(current_goal.type, ctx.safe(current_goal.action_type, action_type))
    end

    execute_goal_action(shared, ctx, action_type, current_goal)

    if shared._area_wait_timer > 0 and ctx.now < shared._area_wait_timer then
        return "DO_ACTION"
    end

    shared._action_pause_timer = ctx.now + 0.5
    return "IDLE"
end

return M
