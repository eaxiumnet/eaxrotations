-- =============================================================================
-- UI/Render Module - HUD, ESP, and Safety Warning (v2.4.3 — prettier HUD)
-- =============================================================================

local APISurface = require("core/api_surface")
local LootDB     = require("fishing/loot_db")
local Alert      = require("core/alert")

local M = {}

-- ── Color palette ───────────────────────────────────────────────────────────
local C = {}

local function init_colors()
    C.title    = APISurface.color_new(80,  200, 255, 255)   -- icy blue
    C.section  = APISurface.color_new(255, 195, 0,   220)   -- amber
    C.head     = APISurface.color_new(200, 200, 200, 200)   -- light gray
    C.val      = APISurface.color_new(220, 220, 220, 255)   -- white
    C.green    = APISurface.color_new(100, 255, 120, 255)   -- green
    C.gold     = APISurface.color_new(255, 215, 0,   255)   -- gold
    C.gray     = APISurface.color_new(160, 160, 160, 255)   -- dim gray
    C.red      = APISurface.color_new(255, 100, 100, 255)   -- red
    C.status   = APISurface.color_new(255, 255, 255, 200)   -- white
    C.dim      = APISurface.color_new(120, 120, 120, 180)   -- faint
end

--- Draw a section header
-- @param text string
-- @param y number current Y position
-- @param x number X position
-- @return number new Y position
local function section(text, x, y)
    APISurface.draw_text_2d("— " .. text .. " —", {x=x, y=y}, 11, C.section, false)
    return y + 14
end

--- Draw a data row
-- @param label string
-- @param value string
-- @param col table color
-- @param x number
-- @param y number
-- @param label_width number
-- @return number new Y
local function row(label, value, col, x, y, label_width)
    APISurface.draw_text_2d(label, {x=x, y=y}, 12, C.head, false)
    APISurface.draw_text_2d(tostring(value), {x=x + label_width, y=y}, 12, col or C.val, false)
    return y + 15
end

--- Draw a thin separator line (using text)
-- @param x number
-- @param y number
-- @return number new Y
local function sep(x, y)
    return y + 4
end

--- Render ESP, HUD, and safety warnings
-- @param ctx table context
function M.render(ctx)
    local state = ctx.state
    local deps = ctx.deps

    if not deps.config.menu.enabled:get_state() then
        return
    end

    local me = APISurface.get_local_player()
    if not me or not APISurface.is_valid(me) then
        return
    end

    -- Lazy-init colors
    if not C.title then init_colors() end

    -- Get native position object
    local p_native = nil
    if type(me.get_position) == "function" then
        local ok, pos = pcall(me.get_position, me)
        if ok and pos then p_native = pos end
    end
    if not p_native then return end

    local p = APISurface.get_object_position(me)
    if not p then return end

    -- ═══════════════════════════════════════════════════════════════════════
    -- Pool ESP
    -- ═══════════════════════════════════════════════════════════════════════
    if deps.config.menu.esp_enabled and deps.config.menu.esp_enabled:get_state() then
        local esp_range = deps.config.menu.esp_range and deps.config.menu.esp_range:get() or 100
        local esp_range_sq = esp_range * esp_range
        local objects = APISurface.get_all_objects()
        local color_esp = APISurface.color_new(0, 255, 255, 200)

        for _, obj in ipairs(objects) do
            if APISurface.is_valid(obj) then
                local name = APISurface.get_object_name(obj)
                if deps.constants.OBJECTS.POOLS and deps.constants.OBJECTS.POOLS[name] then
                    local target_native = nil
                    if type(obj.get_position) == "function" then
                        local ok2, pos2 = pcall(obj.get_position, obj)
                        if ok2 and pos2 then target_native = pos2 end
                    end

                    if target_native then
                        local target_pos = APISurface.get_object_position(obj)
                        if target_pos then
                            local dx = p.x - target_pos.x
                            local dy = p.y - target_pos.y
                            local dz = p.z - target_pos.z
                            local dist_sq = dx*dx + dy*dy + dz*dz

                            if dist_sq <= esp_range_sq then
                                if core and core.graphics then
                                    pcall(core.graphics.line_3d, p_native, target_native, color_esp, 2.0)
                                    local label_pos = {x=target_pos.x, y=target_pos.y, z=target_pos.z + 1.0}
                                    pcall(core.graphics.text_3d, name, label_pos, 14, color_esp)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- Session Stats HUD
    -- ═══════════════════════════════════════════════════════════════════════
    if deps.config.menu.show_stats and deps.config.menu.show_stats:get_state() then
        local tnow    = APISurface.now()
        local elapsed = tnow - state.session.start_time
        local hours   = elapsed / 3600
        local emins   = math.floor(elapsed / 60)
        local esecs   = math.floor(elapsed % 60)

        local current_gold = APISurface.get_gold() or 0
        if not state.session.stats.gold_start then
            state.session.stats.gold_start = current_gold
        end
        local gold_gained = math.max(0, current_gold - (state.session.stats.gold_start or current_gold))
        local gph = (hours > 0.02) and math.floor((gold_gained / hours) / 10000) or 0

        local x  = 15
        local y  = 90
        local lw = 100  -- label width for right-alignment

        -- Title
        APISurface.draw_text_2d("◆ Eax's Fishing", {x=x, y=y}, 15, C.title, false)
        y = y + 18

        -- Status (large, prominent)
        APISurface.draw_text_2d(state.fishing.status, {x=x, y=y}, 13, C.status, false)
        y = y + 20

        -- ═══ SESSION ═══
        y = section("Session", x, y)
        y = row("Time",   string.format("%dm %02ds", emins, esecs), C.val, x, y, lw)
        y = row("Casts",  state.session.attempts, C.val, x, y, lw)
        y = row("Catches", state.session.catches, C.green, x, y, lw)

        if state.session.attempts > 0 then
            local rate = math.floor((state.session.catches / state.session.attempts) * 100)
            y = row("Rate",   rate .. "%", rate >= 80 and C.green or C.gray, x, y, lw)
        end
        if hours > 0.02 then
            y = row("C/hr",   math.floor(state.session.catches / hours) .. "/h", C.green, x, y, lw)
        end

        -- Streak
        if state.qol and state.qol.catch_streak > 1 then
            y = row("Streak", state.qol.catch_streak .. " (best: " .. state.qol.best_catch_streak .. ")", C.green, x, y, lw)
        end

        -- Misses / escapes (only if non-zero)
        if state.session.misses > 0 then
            y = row("Missed", state.session.misses, C.gray, x, y, lw)
        end
        if state.session.escaped > 0 then
            y = row("Escaped", state.session.escaped, C.gray, x, y, lw)
        end
        y = sep(x, y)

        -- ═══ RESOURCES ═══
        y = section("Resources", x, y)
        local stats = state.session.stats
        y = row("Fish",   stats.fish_count, C.green, x, y, lw)
        y = row("Junk",   stats.gray_count, C.gray, x, y, lw)

        if stats.lure_count and stats.lure_count > 0 then
            y = row("Lures",  stats.lure_count, C.green, x, y, lw)
        end
        if state.cook and state.cook.cooked_count > 0 then
            y = row("Cooked", state.cook.cooked_count, C.green, x, y, lw)
        end
        if state.containers and state.containers.opened_count > 0 then
            y = row("Opened", state.containers.opened_count, C.green, x, y, lw)
        end
        if state.pinchy and state.pinchy.uses_total > 0 then
            y = row("Pinchy", state.pinchy.uses_total, C.gold, x, y, lw)
        end
        if state.autosell and state.autosell.sold_count > 0 then
            y = row("Sold",   state.autosell.sold_count, C.green, x, y, lw)
        end
        if state.autodelete and state.autodelete.deleted_count > 0 then
            y = row("Deleted", state.autodelete.deleted_count, C.gray, x, y, lw)
        end
        y = sep(x, y)

        -- ═══ STATUS ═══
        y = section("Status", x, y)

        -- Lure timer
        if deps.config.menu.show_lure_timer and deps.config.menu.show_lure_timer:get_state() then
            if state.lure and state.lure.assumed_expire_time > 0 then
                local lure_remaining = state.lure.assumed_expire_time - tnow
                if lure_remaining > 0 then
                    local mins = math.floor(lure_remaining / 60)
                    local secs = math.floor(lure_remaining % 60)
                    local col = lure_remaining < 60 and C.red or C.green
                    y = row("Lure", string.format("%dm %02ds", mins, secs), col, x, y, lw)
                else
                    y = row("Lure", "expired", C.red, x, y, lw)
                end
            end
        end

        -- Coordinates
        if deps.config.menu.show_coordinates and deps.config.menu.show_coordinates:get_state() then
            if type(me.get_position) == "function" then
                local ok, pos = pcall(me.get_position, me)
                if ok and pos and type(pos.x) == "number" then
                    y = row("Coords", string.format("%.1f, %.1f", pos.x, pos.y), C.gray, x, y, lw)
                end
            end
        end

        -- Cast rate
        if deps.config.menu.show_cast_rate and deps.config.menu.show_cast_rate:get_state() then
            local ct = state.cast_telemetry
            if ct and (ct.success_count + ct.fail_count) > 0 then
                local rate = math.floor((ct.success_count / (ct.success_count + ct.fail_count)) * 100)
                y = row("Cast %", rate .. "%", rate >= 80 and C.green or C.gray, x, y, lw)
            end
        end

        -- Stealth multiplier
        if deps.config.menu.stealth_mode and deps.config.menu.stealth_mode:get_state() then
            local stealth = require("core/stealth")
            local mult = stealth.get_delay_multiplier(ctx, tnow)
            if mult > 1.0 then
                local col = mult >= 3.0 and C.red or (mult >= 2.0 and C.gold or C.green)
                y = row("Stealth", string.format("%.1fx", mult), col, x, y, lw)
            end
        end

        -- Quest
        if state.quest and state.quest.quest_fish_name then
            y = row("Quest", state.quest.quest_fish_name, C.gold, x, y, lw)
        end

        -- Whispers
        if state.responder and state.responder.responses_total > 0 then
            y = row("Whispers", state.responder.responses_total, C.gray, x, y, lw)
        end

        -- Hearth
        if state.hearth and state.hearth.state ~= "idle" then
            y = row("Hearth", state.hearth.state, C.gold, x, y, lw)
        end

        -- Disconnect
        if state.relog and state.relog.disconnected_at > 0 then
            y = row("Status", "DC'd!", C.red, x, y, lw)
        end

        -- Water walking
        if state.water_walking and state.water_walking.last_try_time > 0 then
            y = row("WaterWalk", "Active", C.green, x, y, lw)
        end

        -- Paused
        if state.qol and state.qol.paused then
            y = row("Paused", "YES", C.red, x, y, lw)
        end
        y = sep(x, y)

        -- ═══ GOLD ═══
        if gold_gained > 0 then
            y = section("Gold", x, y)
            y = row("Gained", string.format("%.1fg", gold_gained / 100), C.gold, x, y, lw)
            if gph > 0 then
                y = row("/ hr", gph .. "g/hr", C.gold, x, y, lw)
            end
            if stats.vendor_copper and stats.vendor_copper > 0 then
                y = row("Vendorfish", LootDB.format_gold(stats.vendor_copper) or "0c", C.gold, x, y, lw)
            end
            y = sep(x, y)
        end

        -- ═══ TOP CATCHES ═══
        local sorted = {}
        for name, count in pairs(stats.item_counts) do
            table.insert(sorted, {name=name, count=count})
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)

        if #sorted > 0 then
            y = section("Top Catches", x, y)
            for i = 1, math.min(6, #sorted) do
                local e = sorted[i]
                local n = e.name
                if #n > 18 then n = n:sub(1, 17) .. "…" end
                APISurface.draw_text_2d("  " .. n, {x=x, y=y}, 11, C.dim, false)
                APISurface.draw_text_2d("x" .. e.count, {x=x+lw, y=y}, 11, C.val, false)
                y = y + 13
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- Rare catch alert overlay
    -- ═══════════════════════════════════════════════════════════════════════
    if state.alert.active then
        local now_t = APISurface.now()
        if now_t >= state.alert.fade_end then
            state.alert.active = false
            state.alert.text = ""
        else
            local alpha = math.floor(255 * (1 - (now_t - state.alert.fade_start) / (state.alert.fade_end - state.alert.fade_start)))
            local alert_color = Alert.color_for_quality(state.alert.quality)
            alert_color.a = math.max(50, alpha)

            local cx = SCREEN_CENTER_X
            local cy = SCREEN_CENTER_Y - 120

            APISurface.draw_text_2d(state.alert.text, {x=cx, y=cy}, 22, alert_color, true)
        end
    end
end

return M
