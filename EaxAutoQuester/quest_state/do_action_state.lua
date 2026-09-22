-- What: DO_ACTION state handler — execute Zygor goal actions (loot, kill, talk, area)
-- When: Called by coordinator when shared._state == "DO_ACTION"
-- Why: Centralize all goal execution: targeting, distance checks, area brute-force, NPC DB lookups
-- API: exports run(shared, ctx) → next_state string, execute_goal_action as internal helper

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

local goal_names = require("shared/goal_names")
local objective_match = require("shared/objective_match")
local pull_safety = require("shared/pull_safety")
local spawn_patrol = require("shared/spawn_patrol")
local goal_resolver_ok, goal_resolver = pcall(require, "goal_resolver_sylvanas")
local quest_blacklist_ok, quest_blacklist = pcall(require, "quest_blacklist_sylvanas")

local function unit_get_position(u) return u:get_position() end

-- ============================================================================
-- Engagement range — where the bot stops walking and lets the rotation fight
-- ============================================================================

--- Squared distance at which to stop approaching an enemy for this player's class.
--- Ranged classes stop outside melee reach (28yd); everyone else keeps closing (3yd).
--- @param ctx table Per-tick context
--- @return number engage_sq
local function engage_sq_for(ctx)
    local ch = ctx.combat_helper
    if ch and ch.engage_distance_sq then
        local ok, sq = pcall(ch.engage_distance_sq, ctx.me)
        if ok and type(sq) == "number" and sq > 0 then return sq end
    end
    return 9
end

--- Open the fight from range for a class that fights from range.
--- There is no rotation API to "start the rotation", and EaxRotations only rotates with a
--- target (it owns the out-of-combat buff path), so the pull is a ranged auto-attack — the
--- same call the priest/spec rotations make for their own wand fallback. Returns true when
--- combat was opened; false means the caller should keep closing to melee, which is exactly
--- what every class did before this existed.
--- @param ctx table Per-tick context
--- @param enemy game_object Enemy to pull
--- @param engage_sq number The class's squared engagement distance
--- @return boolean pulled
local function pull_at_range(ctx, enemy, engage_sq)
    if engage_sq <= 9 then return false end
    local ch = ctx.combat_helper
    if not (ch and ch.is_ranged_class) then return false end
    local ok_ranged, ranged = pcall(ch.is_ranged_class, ctx.me)
    if not ok_ranged or not ranged then return false end
    local NS = _G.EaxRotations
    if not (NS and NS.start_auto_attack and NS.AUTO_ATTACK_WAND) then return false end
    local ok, started = pcall(NS.start_auto_attack, enemy, NS.AUTO_ATTACK_WAND)
    if not (ok and started) then return false end
    pcall(core.input.set_target, enemy)
    local _, epos = pcall(unit_get_position, enemy)
    if epos then pcall(core.input.look_at_3d, epos) end
    ctx.debug_log("DO_ACTION: engaged from range (wand pull)")
    return true
end

-- ============================================================================
-- Corpse filter — shared by every target scan in this file
-- ============================================================================

--- True when a unit is a corpse: dead, or a body that still reports lootable.
--- The real-game is_dead() is unreliable for a corpse that still holds loot (it can report
--- false), while can_be_looted() reliably reports true for a corpse — the Stonetusk Boar loop
--- (bot kept targeting the same 2yd "enemy") is what taught the enemy scan this. Game objects
--- are never corpses: a lootable chest is a valid interaction target, so only units are
--- filtered, and a corpse can never be chosen as an enemy or an interaction target.
--- @param obj game_object|nil
--- @return boolean
-- Before anything walks toward it: is this unit something we would FIGHT? The pull gate is only
-- about fights, so every site that may be looking at either a hostile or a quest giver / clickable
-- object asks this first and the gate is applied to the hostile answer only. A build that cannot
-- answer `can_attack` says "not hostile", so a missing probe can never block a turn-in.
local function unit_can_attack(u, other) return u:can_attack(other) end

--- @param ctx table Per-tick context
--- @param obj game_object|nil
--- @return boolean hostile
local function hostile_to_me(ctx, obj)
    if not obj or not ctx or not ctx.me then return false end
    local ok, can = pcall(unit_can_attack, obj, ctx.me)
    return ok and can == true
end

local function unit_is_corpse(obj)
    if not obj then return false end
    local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
    if not (ok_unit and is_unit) then return false end
    local ok_dead, is_dead = pcall(function() return obj:is_dead() end)
    if ok_dead and is_dead then return true end
    local ok_loot, can_loot = pcall(function() return obj:can_be_looted() end)
    if ok_loot and can_loot then return true end
    return false
end

-- ============================================================================
-- Talk-target discovery ladder — ported from the monolith's live talk branch
-- (docs/phase1_port_list.md item 9). The modular talk branch only knew has a
-- quest-NPC-id lookup at 20yd; goals whose NPC carries no Questie/Zygor id
-- ("Marshal Dughan"-class) were unreachable.
-- ============================================================================

--- Non-empty string or nil. Zygor's goal.target is often "" — truthy but useless.
--- @param s string|nil
--- @return string|nil
local function nonempty(s)
    return (s and s ~= "") and s or nil
end

--- Walk the discovery ladder and return the best talk target.
--- Rung order is the monolith's: quest-NPC ids (50yd) → goal-name match →
--- engine quest-unit flag → brute-force quest-relevant scan (30yd) → wide name
--- scan (100yd) → proximity fallback (30yd, name match preferred).
--- @param ctx table Per-tick context
--- @param goal table|number Zygor goal
--- @param goal_name string|nil Name extracted from the goal
--- @param npc_ids number[]|nil Questie/Zygor quest NPC ids
--- @return game_object|nil target, number|nil dist_sq, string|nil rung
local function discover_talk_target(ctx, goal, goal_name, npc_ids)
    local npc = ctx.npc_manager
    local me = ctx.me
    if not npc or not me then return nil end
    local pos_ok, pos = pcall(function() return me:get_position() end)
    if not pos_ok or not pos then return nil end

    local function visible_objects()
        if ctx.object_scanner and ctx.object_scanner.get_visible_objects then
            local ok, objs = pcall(ctx.object_scanner.get_visible_objects)
            if ok and objs then return objs end
        end
        local ok, objs = pcall(core.object_manager.get_visible_objects)
        if ok then return objs end
        return nil
    end

    local function dist_sq_of(obj)
        local ok, opos = pcall(function() return obj:get_position() end)
        if not ok or not opos then return nil end
        if ctx.utils and ctx.utils.squared_distance then
            return ctx.utils.squared_distance(pos, opos)
        end
        local dx = (opos.x or 0) - (pos.x or 0)
        local dy = (opos.y or 0) - (pos.y or 0)
        return dx * dx + dy * dy
    end

    local function is_player(obj)
        local ok, flag = pcall(function() return obj:is_player() end)
        return ok and flag
    end

    local function is_dead(obj)
        local ok, flag = pcall(function() return obj:is_dead() end)
        return ok and flag
    end

    -- Rung 1: quest NPC ids from Questie/Zygor (widened 20yd → 50yd)
    if npc_ids and #npc_ids > 0 and npc.find_nearest_npc then
        local nearest = npc.find_nearest_npc(npc_ids, 50, nil, ctx.object_scanner)
        if nearest then
            local d = dist_sq_of(nearest)
            if d then return nearest, d, "quest-npc-id" end
        end
    end

    -- Rung 2: goal name straight from the world (first match, as the monolith did)
    if goal_name and npc.find_interactable_objects then
        local found = npc.find_interactable_objects(goal_name, ctx.object_scanner)
        if found and found[1] then
            local d = dist_sq_of(found[1])
            if d then return found[1], d, "goal-name" end
        end
    end

    -- Rung 3: the engine's own quest-unit flag
    if npc.find_nearest_quest_unit then
        local nearest = npc.find_nearest_quest_unit(50, true)
        if nearest then
            local d = dist_sq_of(nearest)
            if d then return nearest, d, "is_quest_unit" end
        end
    end

    local id_set = {}
    if npc_ids then
        for i = 1, #npc_ids do id_set[npc_ids[i]] = true end
    end

    -- Rung 4: brute-force scan for quest-relevant units only (30yd)
    do
        local objs = visible_objects()
        if objs then
            local best, best_sq = nil, 900
            local limit = #objs > 50 and 50 or #objs
            for i = 1, limit do
                local obj = objs[i]
                if obj and not is_player(obj) and not is_dead(obj) then
                    local relevant = false
                    local ok_q, quest_flag = pcall(function() return obj:is_quest_unit() end)
                    if ok_q and quest_flag then
                        relevant = true
                    elseif next(id_set) then
                        local ok_id, obj_npc_id = pcall(function() return obj:get_npc_id() end)
                        if ok_id and obj_npc_id and id_set[obj_npc_id] then relevant = true end
                    end
                    if relevant then
                        local d = dist_sq_of(obj)
                        if d and d < best_sq then best, best_sq = obj, d end
                    end
                end
            end
            if best then return best, best_sq, "quest-scan" end
        end
    end

    -- Rung 5: wide name scan (100yd) for units named in the goal
    if goal_name then
        local objs = visible_objects()
        if objs then
            local best, best_sq = nil, 10000
            local limit = #objs > 100 and 100 or #objs
            local glower = goal_name:lower()
            for i = 1, limit do
                local obj = objs[i]
                if obj and not is_player(obj) then
                    local ok_u, is_unit = pcall(function() return obj:is_unit() end)
                    if ok_u and is_unit then
                        local ok_n, name = pcall(function() return obj:get_name() end)
                        if ok_n and name then
                            local nlower = name:lower()
                            if nlower:find(glower, 1, true) or glower:find(nlower, 1, true) then
                                local d = dist_sq_of(obj)
                                if d and d < best_sq then best, best_sq = obj, d end
                            end
                        end
                    end
                end
            end
            if best then return best, best_sq, "name-scan" end
        end
    end

    -- Rung 6: proximity fallback (30yd) — any non-player living unit, a name
    -- match always winning over the closest unrelated one
    do
        local objs = visible_objects()
        if objs then
            local best, best_sq, named_found = nil, 900, false
            local limit = #objs > 50 and 50 or #objs
            local glower = goal_name and goal_name:lower() or nil
            for i = 1, limit do
                local obj = objs[i]
                if obj and not is_player(obj) and not is_dead(obj) then
                    local d = dist_sq_of(obj)
                    if d and d < best_sq then
                        local ok_n, name = pcall(function() return obj:get_name() end)
                        local named = false
                        if ok_n and name and glower then
                            local nlower = name:lower()
                            named = nlower:find(glower, 1, true) or glower:find(nlower, 1, true)
                        end
                        if named then
                            if not named_found or d < best_sq then
                                named_found, best, best_sq = true, obj, d
                            end
                        elseif not named_found then
                            best, best_sq = obj, d
                        end
                    end
                end
            end
            if best then return best, best_sq, "proximity" end
        end
    end

    return nil
end

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
        -- Quest item usage: match inventory item to goal text, then use it
        local goal_text = (type(goal) == "table" and (goal.text or goal.name)) or nil
        if goal_text then
            local qim_ok, qim = pcall(require, "quest_item_manager_sylvanas")
            if qim_ok and qim and qim.handle_goal_item then
                local target = nil
                local position = nil
                if ctx.me then
                    local t_ok, t = pcall(function() return ctx.me:get_target() end)
                    if t_ok then target = t end
                    local p_ok, p = pcall(function() return ctx.me:get_position() end)
                    if p_ok then position = p end
                end
                local used = qim.handle_goal_item(goal_text, target, position)
                if used then
                    ctx.debug_log("DO_ACTION: used quest item for goal '" .. tostring(goal_text) .. "'")
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
            local npc_id = objective_match.goal_id(goal) or ctx.safe(goal.npc_id, ctx.safe(goal.id, nil))
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
        -- Skip re-tagging while already fighting a valid target: re-entering the
        -- kill branch every cycle thrashes the target and can pull extra mobs.
        -- (Ported: docs/phase1_port_list.md item 8.)
        if combat and combat.is_current_target_valid and combat.is_current_target_valid(50) then
            ctx.debug_log("DO_ACTION: kill — target still valid, skip re-tag")
            return true
        end
        -- Prefer the goal's own quest NPC (e.g. Elder Stranglethorn Tiger over a
        -- generic tiger): killing the generic mob does not advance the quest.
        local goal_npc_id = nil
        if type(goal) == "table" then
            goal_npc_id = objective_match.goal_id(goal)
        end
        if npc and goal_npc_id and npc.find_nearest_npc then
            local quest_mob = npc.find_nearest_npc({ goal_npc_id }, 50, nil, ctx.object_scanner)
            if quest_mob then
                -- The gate goes before the TAG, not only before the swing that follows it. Choosing
                -- a hostile is what the rotation's combat path keys off, and it is the visible half
                -- of "the bot walked up to the mob and started something" — on an empty bar or in a
                -- crowd, none of that may begin. This is the goal's own mob by id, i.e. the path
                -- every kill objective in the game takes; it used to start the fight with no gate
                -- consulted at all.
                if pull_safety.gate(ctx, shared, quest_mob) then return true end
                shared._respawn_wait_until = 0
                shared._respawn_target_name = nil
                pcall(core.input.set_target, quest_mob)
                pcall(core.input.interact_with_object, quest_mob)
                local _, npos = pcall(function() return quest_mob:get_position() end)
                if npos then pcall(core.input.look_at_3d, npos) end
                ctx.debug_log("DO_ACTION: kill — targeted quest NPC " .. tostring(goal_npc_id))
                return true
            end
        end
        if npc then
            local enemy = npc.get_nearest_enemy(50, ctx.object_scanner)
            if enemy then
                -- Before anything walks toward it: is this fight worth starting? Low health, a
                -- caster with no mana, or a crowd that includes patrolling mobs means no — the
                -- module walks the player out (or parks them) and this tick is done.
                if pull_safety.gate(ctx, shared, enemy) then return true end
                -- Enemy found — clear any respawn wait and engage
                shared._respawn_wait_until = 0
                shared._respawn_target_name = nil
                if ctx.me then
                    local _, me_pos = pcall(unit_get_position, ctx.me)
                    local _, enemy_pos = pcall(unit_get_position, enemy)
                    if me_pos and enemy_pos then
                        local dist_sq = ctx.utils and ctx.utils.squared_distance(me_pos, enemy_pos) or 1e9
                        local engage_sq = engage_sq_for(ctx)
                        if dist_sq > engage_sq then
                            shared._nav_destination = enemy_pos
                            -- A live unit is a moving point: record which unit owns this
                            -- destination so NAV can follow it instead of walking to where the
                            -- mob stood when the scan ran. See nav_state.lua.
                            shared._nav_unit_dest = enemy
                            shared._nav_unit_dest_key = enemy_pos
                            if engage_sq > 9 then
                                shared._nav_engage_dest = enemy_pos
                                shared._nav_engage_sq = engage_sq
                            end
                            local dist_yds = math.floor(math.sqrt(dist_sq))
                            ctx.debug_log("DO_ACTION: kill — approaching enemy (" .. tostring(dist_yds) .. "yd)")
                            -- This return is documentary: M.run ignores execute_goal_action's
                            -- result. The destination above is the real work — IDLE picks it up
                            -- (`approaching target → NAV`) and NAV honours the stand-off.
                            return false
                        end
                        -- In range: a ranged class engages from here and leaves the fight to
                        -- the rotation. Without a ranged attack it keeps closing, exactly as
                        -- every class did before.
                        if pull_at_range(ctx, enemy, engage_sq) then return true end
                        if dist_sq > 9 then
                            shared._nav_destination = enemy_pos
                            shared._nav_unit_dest = enemy
                            shared._nav_unit_dest_key = enemy_pos
                            local dist_yds = math.floor(math.sqrt(dist_sq))
                            ctx.debug_log("DO_ACTION: kill — closing to melee, no ranged attack (" .. tostring(dist_yds) .. "yd)")
                            return false
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
        -- No enemy found — enter respawn wait mode. 60s, not the old 180s: the wait exists to
        -- stop 100fps re-scans, and three minutes parked is indistinguishable from being stuck
        -- (IDLE re-checks every 5s and resumes the moment an enemy is within range).
        if (shared._respawn_wait_until or 0) == 0 then
            shared._respawn_wait_until = ctx.now + 60
            local target_name = nil
            if type(goal) == "table" then
                target_name = goal.target or goal.npc or goal.name
            end
            shared._respawn_target_name = target_name
            ctx.debug_log("DO_ACTION: no enemy — entering respawn wait (60s)" .. (target_name and " for " .. target_name or ""))
        end
        return true
    end

    if action_type == "talk" or action_type == "gossip" then
        if npc then
            local npc_ids = npc.find_quest_npcs()
            local goal_name = nil
            if type(goal) == "table" then
                goal_name = nonempty(goal.npc) or nonempty(goal.target)
                    or nonempty(goal.npc_name) or nonempty(goal.text) or nonempty(goal.name)
            end
            local target, dist_sq, rung = discover_talk_target(ctx, goal, goal_name, npc_ids)
            if target then
                if dist_sq and dist_sq > 36 then
                    -- Too far to interact — hand the walk back to IDLE, which NAVs
                    -- any pending _nav_destination. The monolith logged
                    -- "navigating closer" and called utils.move_to, which does not
                    -- exist anywhere in this plugin, so that branch never moved.
                    local _, npos = pcall(function() return target:get_position() end)
                    if npos then
                        shared._nav_destination = npos
                        ctx.debug_log("DO_ACTION: talk target [" .. tostring(rung) ..
                            "] out of range → NAV")
                        -- Setting the destination is the whole mechanism: M.run ignores this
                        -- return, IDLE picks the destination up and emits NAV for it.
                        return "NAV"
                    end
                end
                pcall(core.input.set_target, target)
                if pcall(core.input.interact_with_object, target) then
                    ctx.debug_log("DO_ACTION: targeted quest NPC for talk [" .. tostring(rung) .. "]")
                    shared._post_interact_timer = ctx.now + 0.5
                    shared._interact_start_time = ctx.now
                    shared._should_enter_interact = true
                end
                return true
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
            -- The goal's own id, in every spelling the bridge and the addon use: an id is what
            -- makes "the mob that drops this" knowable (shared/objective_match.lua).
            local nid = objective_match.goal_id(goal)
            if nid then goal_npc_id = nid end
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

        -- Fast path: use game_object:is_quest_unit() to find the nearest quest-related unit.
        -- This is more reliable than Questie name matching because it uses the engine's own
        -- quest flag. Fires before Questie fallback so we prefer what's actually visible.
        if not goal_npc_id and not (goal_target and goal_target ~= "") and npc and npc.find_nearest_quest_unit then
            if shared._questie_fallback_time and ctx.now - shared._questie_fallback_time < 5.0 then
                return true
            end
            local nearest_quest = npc.find_nearest_quest_unit(80, true)
            if nearest_quest then
                -- A quest unit is usually a giver, and then the gate has nothing to say. When it
                -- is a hostile quest mob it is a fight like any other, and it is refused before
                -- the approach: walking up to the camp while empty is the pull this gate exists to
                -- stop, whether or not the swing happens afterwards.
                if hostile_to_me(ctx, nearest_quest)
                    and pull_safety.gate(ctx, shared, nearest_quest) then
                    return true
                end
                local _, npos = pcall(function() return nearest_quest:get_position() end)
                local _, nname = pcall(function() return nearest_quest:get_name() end)
                local _, nguid = pcall(function() return nearest_quest:get_guid() end)
                if npos and ctx.me then
                    local _, me_pos = pcall(function() return ctx.me:get_position() end)
                    if me_pos and ctx.utils then
                        local dist_sq = ctx.utils.squared_distance(me_pos, npos)
                        if dist_sq > 25 then
                            shared._nav_destination = npos
                            shared._questie_fallback_time = ctx.now
                            shared._questie_last_guid = nguid
                            ctx.debug_log("DO_ACTION: area — navigating to quest unit '" .. tostring(nname or "unknown") .. "' (" .. tostring(math.floor(math.sqrt(dist_sq))) .. "yd) [is_quest_unit]")
                            return false
                        end
                    end
                end
                pcall(core.input.set_target, nearest_quest)
                pcall(core.input.interact_with_object, nearest_quest)
                shared._questie_fallback_time = ctx.now
                shared._questie_last_guid = nguid
                ctx.debug_log("DO_ACTION: area — targeted quest unit '" .. tostring(nname or "unknown") .. "' [is_quest_unit]")
                return true
            end
        end

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
                    local is_hostile = hostile_to_me(ctx, nearest)
                    if is_hostile and pull_safety.gate(ctx, shared, nearest) then return true end
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
            -- Where to go when the mob is not here: SWEEP its spawn points rather than navigate
            -- to one coordinate. The single-point version (npc_db.find_npc_spawn, first match)
            -- parked the bot on one spawn forever — with the mob's other spawn points, and any
            -- respawn at them, hundreds of yards outside the 50yd probe that was the only sensor.
            -- shared/spawn_patrol.lua owns the sweep, including the Z fix-up and the visited marks.
            local point = spawn_patrol.next_point(shared, ctx, goal)
            if point then
                shared._nav_destination = point
                ctx.debug_log("DO_ACTION: area — searching spawn points for NPC " ..
                    tostring(goal_npc_id))
                return false
            end
            if npc then
                local nearest = npc.find_nearest_npc({ goal_npc_id }, 50, nil, ctx.object_scanner)
                if nearest then
                    -- Hostile only: the same id can be a green quest giver on a "speak to" step.
                    if hostile_to_me(ctx, nearest)
                        and pull_safety.gate(ctx, shared, nearest) then
                        return true
                    end
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
            -- Zygor's target string is comma-separated and pluralized ("Bundles of Wood",
            -- "Milly's Harvest Pumpkins"); one owner translates it (shared/goal_names.lua).
            local names_to_try = goal_names.expand(goal_target)
            for _, name in ipairs(names_to_try) do
                local objects = npc.find_interactable_objects(name, ctx.object_scanner)
                -- Only the goal's own mobs (shared/objective_match.lua): the name lookup matches
                -- substrings, and "Lesser Rock Elemental" contains "Rock Elemental".
                objects = objective_match.only(goal, objects)
                if objects and #objects > 0 then
                    -- A corpse is not a target. find_interactable_objects matches by NAME and
                    -- includes dead units, and a looted corpse still reports is_dead() — so a
                    -- kill objective whose mobs all lay dead under the player kept
                    -- "targeted enemy '<name>', auto-attacking" on the corpse every tick, for as
                    -- long as Zygor's step stayed open (live: Stonevault Shaman).
                    local obj = nil
                    local best_dist_sq = 1e9
                    local _, me_pos_scan = pcall(function() return ctx.me:get_position() end)
                    for _, candidate in ipairs(objects) do
                        if not unit_is_corpse(candidate) then
                            local _, cpos = pcall(function() return candidate:get_position() end)
                            if cpos and me_pos_scan and ctx.utils then
                                local dsq = ctx.utils.squared_distance(me_pos_scan, cpos)
                                if dsq < best_dist_sq then
                                    best_dist_sq = dsq
                                    obj = candidate
                                end
                            end
                        end
                    end
                    -- Stop at the class's engagement range, not on top of the mob: a ranged
                    -- class fights from cast range. The same policy drives the enemy scan below
                    -- (engage_sq_for is the single owner); melee classes keep closing to 3yd.
                    local is_enemy = false
                    if obj and ctx.me then
                        local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
                        if ok_unit and is_unit then
                            local ok_att, can_att = pcall(function() return obj:can_attack(ctx.me) end)
                            if ok_att and can_att then is_enemy = true end
                        end
                    end
                    local in_range_sq = is_enemy and engage_sq_for(ctx) or 25

                    -- The gate before the WALK, not only before the swing: the destination set
                    -- below is the bot committing to the fight, and on an empty bar the right move
                    -- is to stand where it is (the hold), not to walk into the mob and refuse
                    -- there. Quest objects and friendly NPCs are untouched — the gate only ever
                    -- refuses hostiles.
                    if is_enemy and pull_safety.gate(ctx, shared, obj) then return true end

                    if obj and ctx.me then
                        local _, me_pos = pcall(function() return ctx.me:get_position() end)
                        local _, obj_pos = pcall(function() return obj:get_position() end)
                        if me_pos and obj_pos and ctx.utils then
                            local dist_sq = ctx.utils.squared_distance(me_pos, obj_pos)
                            if dist_sq > in_range_sq then
                                shared._nav_destination = obj_pos
                                if is_enemy then
                                    -- Only a hostile unit is a moving point; a quest object
                                    -- or NPC stays where it is (see nav_state.lua).
                                    shared._nav_unit_dest = obj
                                    shared._nav_unit_dest_key = obj_pos
                                end
                                if in_range_sq > 25 then
                                    shared._nav_engage_dest = obj_pos
                                    shared._nav_engage_sq = in_range_sq
                                end
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
                    if not obj then
                        -- Every match for this name was a corpse, so there is nothing here to
                        -- attack or use. Act on nothing and try the next name — this is the case
                        -- that used to target the player's own looted kill once per tick.
                        ctx.debug_log("DO_ACTION: area — '" .. tostring(name) .. "' matched only corpses, skipping")
                    else
                        -- A hostile is only selected AFTER the pull gate has had its say. Selecting
                        -- is not harmless: it is what the rotation's combat path keys off, and it
                        -- is the visible half of "the bot walked up to the mob and started
                        -- something" — on an empty bar or in a crowd, none of that may begin. Quest
                        -- objects and friendly NPCs are untouched by the gate (it only ever refuses
                        -- hostiles), so their selection stays exactly where it was.
                        if not is_enemy then
                            pcall(core.input.set_target, obj)
                        end

                        if is_enemy then
                            if pull_safety.gate(ctx, shared, obj) then return true end
                            pcall(core.input.set_target, obj)
                            -- Live hostile in range: open the fight from range when the class
                            -- fights from range, otherwise let the rotation swing.
                            local ns = _G.EaxRotations
                            if in_range_sq > 9 then
                                local dist_sq = 0
                                local _, me_pos = pcall(unit_get_position, ctx.me)
                                local _, obj_pos = pcall(unit_get_position, obj)
                                if me_pos and obj_pos and ctx.utils then
                                    dist_sq = ctx.utils.squared_distance(me_pos, obj_pos)
                                end
                                if dist_sq > 9 and pull_at_range(ctx, obj, in_range_sq) then
                                    shared._post_interact_timer = ctx.now + 0.3
                                    return true
                                end
                            end
                            if ns and ns.start_auto_attack then
                                pcall(function() ns.start_auto_attack(obj) end)
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
                                -- Dead or lootable units are not enemies (single owner: the
                                -- same filter the name path above uses).
                                if not unit_is_corpse(obj) then
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
                        -- Same gate as the other two engage sites, and it has to be HERE: the
                        -- chain below both walks the player in and opens from range, so a check
                        -- placed after it would only ever describe a pull that already happened.
                        if pull_safety.gate(ctx, shared, best_enemy, objects, limit) then
                            return true
                        end
                        local dist_yds = math.floor(math.sqrt(best_enemy_sq))
                        ctx.debug_log("DO_ACTION: area — best_enemy_sq=" .. tostring(best_enemy_sq) .. " dist_yds=" .. tostring(dist_yds))
                        local engage_sq = engage_sq_for(ctx)
                        if best_enemy_sq > engage_sq then
                            local _, enemy_pos = pcall(unit_get_position, best_enemy)
                            if enemy_pos then
                                shared._nav_destination = enemy_pos
                                shared._nav_unit_dest = best_enemy
                                shared._nav_unit_dest_key = enemy_pos
                                if engage_sq > 9 then
                                    shared._nav_engage_dest = enemy_pos
                                    shared._nav_engage_sq = engage_sq
                                end
                                ctx.debug_log("DO_ACTION: area — approaching enemy '" .. tostring(goal_target) .. "' (" .. tostring(dist_yds) .. "yd)")
                                return false
                            end
                        elseif best_enemy_sq > 9 and pull_at_range(ctx, best_enemy, engage_sq) then
                            return true
                        elseif best_enemy_sq > 9 then
                            local _, enemy_pos = pcall(unit_get_position, best_enemy)
                            if enemy_pos then
                                shared._nav_destination = enemy_pos
                                shared._nav_unit_dest = best_enemy
                                shared._nav_unit_dest_key = enemy_pos
                                ctx.debug_log("DO_ACTION: area — closing to melee, no ranged attack (" .. tostring(dist_yds) .. "yd)")
                                return false
                            end
                        else
                            local _, enemy_pos = pcall(function() return best_enemy:get_position() end)
                            -- Declared before the melee block so the attack log below can report
                            -- the count this block measures. It used to be declared inside the
                            -- `if enemy_pos` block, leaving that log to read a name that was
                            -- neither declared nor assigned anywhere — a global nil, so the
                            -- line always printed "nearby=nil".
                            -- The private crowd count that used to live here is gone: it asked the
                            -- same question as pull_safety.gate (hostiles around the fight site)
                            -- with a narrower radius, no mover awareness, and only AFTER the fight
                            -- had been started — and its answer was to freeze mid-fight, which is
                            -- not a thing the game lets you decline. The gate above now answers it
                            -- before the pull, and answers it with "walk away" instead of "stand
                            -- still". What remains here is the count for the log line, taken from
                            -- the one shared definition so the two can never disagree.
                            local nearby_count = 0
                            if enemy_pos then
                                local _, hostiles = pull_safety.crowd(ctx, enemy_pos, objects, limit)
                                nearby_count = hostiles
                                -- shared/facing: throttled, cone-checked aim (see shared/facing.lua).
                                facing.ensure(ctx.me, best_enemy)
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
                                -- Record the failure; do NOT delete the quest. This block used to
                                -- call quest_blacklist.should_abandon + core.quests.abandon_quest,
                                -- which threw away quests the player was still working on. Giving up
                                -- on a target and telling the player is the plugin's job; deleting
                                -- quests is not. tests/test_no_quest_abandon.lua enforces that.
                                if quest_blacklist_ok and quest_blacklist and quest_blacklist.record_failure and quest_id then
                                    quest_blacklist.record_failure(quest_id, "area_fail")
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
                -- The area lane's last resort — "nothing of the goal's is here, so kill whatever
                -- is nearest" — used to approach and attack with no gate consulted at all, which
                -- made it the widest door for fighting on an empty bar.
                if pull_safety.gate(ctx, shared, enemy) then return true end
                if ctx.me then
                    local _, me_pos = pcall(unit_get_position, ctx.me)
                    local _, enemy_pos = pcall(unit_get_position, enemy)
                    if me_pos and enemy_pos then
                        local dist_sq = ctx.utils and ctx.utils.squared_distance(me_pos, enemy_pos) or 1e9
                        local engage_sq = engage_sq_for(ctx)
                        if dist_sq > engage_sq then
                            shared._nav_destination = enemy_pos
                            shared._nav_unit_dest = enemy
                            shared._nav_unit_dest_key = enemy_pos
                            if engage_sq > 9 then
                                shared._nav_engage_dest = enemy_pos
                                shared._nav_engage_sq = engage_sq
                            end
                            local dist_yds = math.floor(math.sqrt(dist_sq))
                            ctx.debug_log("DO_ACTION: area — approaching enemy (" .. tostring(dist_yds) .. "yd)")
                            return false
                        end
                        if pull_at_range(ctx, enemy, engage_sq) then return true end
                        if dist_sq > 9 then
                            shared._nav_destination = enemy_pos
                            shared._nav_unit_dest = enemy
                            shared._nav_unit_dest_key = enemy_pos
                            local dist_yds = math.floor(math.sqrt(dist_sq))
                            ctx.debug_log("DO_ACTION: area — closing to melee, no ranged attack (" .. tostring(dist_yds) .. "yd)")
                            return false
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

    -- Progress tracking: check if this quest is making progress
    do
        local pt_ok, pt = pcall(require, "progress_tracker_sylvanas")
        if pt_ok and pt and current_goal and current_goal.quest_id then
            local status = pt.check_progress(current_goal.quest_id, action_type)
            if status == "blacklisted" then
                ctx.debug_log("DO_ACTION: quest " .. tostring(current_goal.quest_id) .. " blacklisted — skipping")
                -- Reset and let idle_state pick a different goal
                shared._respawn_wait_until = 0
                return "IDLE"
            end
        end
    end

    execute_goal_action(shared, ctx, action_type, current_goal)

    if shared._area_wait_timer > 0 and ctx.now < shared._area_wait_timer then
        return "DO_ACTION"
    end

    -- If we just interacted with an NPC (talk/gossip), enter INTERACT to process dialog
    if shared._should_enter_interact then
        shared._should_enter_interact = false
        return "INTERACT"
    end

    -- Talk/gossip: do not wait out the general pause — give the server 0.3s to
    -- open the dialog frame, then let INTERACT process it.
    -- (Ported: docs/phase1_port_list.md item 10.)
    if action_type == "talk" or action_type == "gossip" then
        shared._action_pause_timer = ctx.now + 0.3
        return "IDLE"
    end

    -- Progressive action pacing: repeating the same action type doubles the
    -- pause (0.5s → 1s → 2s, capped at 2s) with ±10% jitter, so a goal that
    -- cannot advance cannot spin the state machine at 2Hz.
    -- (Ported: docs/phase1_port_list.md item 10.)
    local pause = 0.5
    if action_type == shared._last_action_type then
        shared._action_loop_count = (shared._action_loop_count or 0) + 1
        -- `2 ^ n`, not math.pow: the operator exists on every Lua the plugin runs on
        -- (5.1 game runtime and 5.4 host tooling), math.pow was removed after 5.2.
        pause = math.min(0.5 * (2 ^ shared._action_loop_count), 2.0)
    else
        shared._action_loop_count = 0
    end
    shared._last_action_type = action_type
    shared._action_pause_timer = ctx.now + pause + math.random() * 0.1 * pause - 0.05 * pause
    return "IDLE"
end

return M
