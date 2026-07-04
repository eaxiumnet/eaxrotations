-- =============================================================================
-- UI/Render Module - HUD, ESP, and Safety Warning
-- =============================================================================

local APISurface = require("core/api_surface")
local LootDB     = require("fishing/loot_db")
local Alert      = require("core/alert")

local M = {}

-- Screen resolution estimate for centering (updated each frame via text_2d position)
local SCREEN_CENTER_X = 960
local SCREEN_CENTER_Y = 540

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

    -- Get native position object directly (runtime requires its own Vec3, not a plain table)
    local p_native = nil
    if type(me.get_position) == "function" then
        local ok, pos = pcall(me.get_position, me)
        if ok and pos then p_native = pos end
    end
    if not p_native then return end

    -- Also get plain table version for distance math
    local p = APISurface.get_object_position(me)
    if not p then return end

    -- =========================================================
    -- Pool ESP
    -- =========================================================
    if deps.config.menu.esp_enabled and deps.config.menu.esp_enabled:get_state() then
        local esp_range = deps.config.menu.esp_range and deps.config.menu.esp_range:get() or 100
        local esp_range_sq = esp_range * esp_range
        local objects = APISurface.get_all_objects()
        local color_esp = APISurface.color_new(0, 255, 255, 200)

        for _, obj in ipairs(objects) do
            if APISurface.is_valid(obj) then
                local name = APISurface.get_object_name(obj)
                if deps.constants.OBJECTS.POOLS and deps.constants.OBJECTS.POOLS[name] then
                    -- Use native position for graphics
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
                                -- Pass native Vec3 objects to graphics
                                if core and core.graphics then
                                    pcall(core.graphics.line_3d, p_native, target_native, color_esp, 2.0)
                                    local label_pos = nil
                                    if type(target_native.x) == "number" then
                                        -- plain table works too - try it
                                        label_pos = {x=target_pos.x, y=target_pos.y, z=target_pos.z + 1.0}
                                    else
                                        label_pos = target_native
                                    end
                                    pcall(core.graphics.text_3d,
                                        name,
                                        label_pos, 14, color_esp)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- =========================================================
    -- Session Stats HUD
    -- =========================================================
    if deps.config.menu.show_stats and deps.config.menu.show_stats:get_state() then
        local tnow    = APISurface.now()
        local elapsed = tnow - state.session.start_time
        local hours   = elapsed / 3600
        local emins   = math.floor(elapsed / 60)
        local esecs   = math.floor(elapsed % 60)

        -- Track gold gained this session
        local current_gold = APISurface.get_gold() or 0
        if not state.session.stats.gold_start then
            state.session.stats.gold_start = current_gold
        end
        local gold_gained = math.max(0, current_gold - (state.session.stats.gold_start or current_gold))
        local gph = (hours > 0.02) and math.floor((gold_gained / hours) / 10000) or 0

        local c_title  = APISurface.color_new(80,  200, 255, 255)
        local c_head   = APISurface.color_new(255, 195, 0,   220)
        local c_val    = APISurface.color_new(220, 220, 220, 255)
        local c_green  = APISurface.color_new(100, 255, 120, 255)
        local c_gold   = APISurface.color_new(255, 215, 0,   255)
        local c_gray   = APISurface.color_new(160, 160, 160, 255)
        local c_status = APISurface.color_new(255, 255, 255, 200)

        local x  = 15
        local y  = 90
        local lh = 16

        local function row(label, value, col)
            APISurface.draw_text_2d(label, {x=x,    y=y}, 13, c_head,     false)
            APISurface.draw_text_2d(value, {x=x+96, y=y}, 13, col or c_val, false)
            y = y + lh
        end

        -- Title + status
        APISurface.draw_text_2d("Eax's Fishing", {x=x, y=y}, 16, c_title, false)
        y = y + lh
        APISurface.draw_text_2d(state.fishing.status, {x=x, y=y}, 13, c_status, false)
        y = y + lh + 4

        -- Time
        row("Session",    string.format("%dm %02ds", emins, esecs))

        -- Casts / catches / rate
        row("Casts",      tostring(state.session.attempts))
        row("Catches",    tostring(state.session.catches), c_green)
        if state.session.attempts > 0 then
            local rate = math.floor((state.session.catches / state.session.attempts) * 100)
            row("Catch rate", rate .. "%", c_green)
        end
        if hours > 0.02 then
            local cph = math.floor(state.session.catches / hours)
            row("Catches/hr", tostring(cph) .. "/h", c_green)
        end

        -- Misses / escapes (only shown if non-zero)
        if state.session.misses > 0 then
            row("Misses",   tostring(state.session.misses),  c_gray)
        end
        if state.session.escaped > 0 then
            row("Escaped",  tostring(state.session.escaped), c_gray)
        end

        y = y + 4

        -- Item categories
        local stats = state.session.stats
        row("Fish",       tostring(stats.fish_count), c_green)
        if hours > 0.02 then
            local fph = math.floor(stats.fish_count / hours)
            row("Fish / hr",  tostring(fph) .. "/h", c_green)
        end
        row("Junk",       tostring(stats.gray_count), c_gray)

        -- Cooked count (new v2.3.0)
        if state.cook and state.cook.cooked_count > 0 then
            row("Cooked",   tostring(state.cook.cooked_count), c_green)
        end

        -- Top items caught (up to 6)
        local sorted = {}
        for name, count in pairs(stats.item_counts) do
            table.insert(sorted, {name=name, count=count})
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)

        if #sorted > 0 then
            y = y + 4
            APISurface.draw_text_2d("Items caught:", {x=x, y=y}, 12, c_head, false)
            y = y + 14
            for i = 1, math.min(6, #sorted) do
                local e = sorted[i]
                local n = #e.name > 22 and (e.name:sub(1, 21) .. ".") or e.name
                APISurface.draw_text_2d(n .. "  x" .. e.count, {x=x+4, y=y}, 12, c_val, false)
                y = y + 13
            end
        end

        y = y + 6

        -- Goldenscale Vendorfish are worth 6g each to vendor — track separately
        if stats.vendor_copper and stats.vendor_copper > 0 then
            row("Vendorfish", LootDB.format_gold(stats.vendor_copper) or "0c", c_gold)
        end

        -- Actual gold gained (real, not estimated)
        local gold_str = LootDB.format_gold(gold_gained) or "0c"
        row("Gold gained", gold_str, c_gold)
        row("Gold / hr",   tostring(gph) .. "g", c_gold)
    end

    -- =========================================================
    -- Safety Warning — same-position detection
    -- =========================================================
    local now = APISurface.now()

    -- Update stand-still tracking (check every 10s)
    if not state.safety.last_position then
        state.safety.last_position      = {x=p.x, y=p.y, z=p.z}
        state.safety.last_position_check = now
        state.safety.standing_since      = now
    else
        if now - state.safety.last_position_check > 10.0 then
            local lp    = state.safety.last_position
            local dx    = p.x - lp.x
            local dy    = p.y - lp.y
            local moved = dx*dx + dy*dy > 25
            if moved then
                state.safety.standing_since = now
                state.safety.last_position  = {x=p.x, y=p.y, z=p.z}
                -- Reset warning thresholds when player moves so they re-randomise fresh
                state.safety.warn_yellow_at = nil
                state.safety.warn_red_at    = nil
            end
            state.safety.last_position_check = now
        end
    end

    -- Only warn if bot is active
    if deps.config.menu.enabled:get_state() then
        local standing_secs = now - (state.safety.standing_since or now)

        -- Thresholds are randomised and re-randomised after each warning fires,
        -- so warnings keep appearing at unpredictable intervals during long sessions.
        -- Yellow: 20-35 min, Red: 45-70 min initially, then repeat every 20-40 min.
        if not state.safety.warn_yellow_at then
            state.safety.warn_yellow_at = 1200 + math.random(0, 900)   -- 20-35 min
        end
        if not state.safety.warn_red_at then
            state.safety.warn_red_at = state.safety.warn_yellow_at
                + 1500 + math.random(0, 1500)                           -- 25-50 min after yellow
        end

        if standing_secs >= state.safety.warn_red_at then
            local color_red = APISurface.color_new(255, 50, 50, 230)
            local mins = math.floor(standing_secs / 60)
            APISurface.draw_text_2d(
                "!! MOVE — " .. mins .. " min at same spot !!",
                {x=SCREEN_CENTER_X - 170, y=SCREEN_CENTER_Y - 20}, 24, color_red, false)
            -- Re-randomise red threshold so it fires again later in the session
            if not state.safety.warn_red_acked then
                state.safety.warn_red_acked = true
                -- Schedule next red warning 20-40 min from now
                state.safety.warn_red_at = standing_secs + 1200 + math.random(0, 1200)
            end
        elseif standing_secs >= state.safety.warn_yellow_at then
            local color_yellow = APISurface.color_new(255, 220, 0, 210)
            local mins = math.floor(standing_secs / 60)
            APISurface.draw_text_2d(
                "Same spot: " .. mins .. " min",
                {x=SCREEN_CENTER_X - 90, y=SCREEN_CENTER_Y - 20}, 18, color_yellow, false)
            state.safety.warn_red_acked = false
            -- Nudge yellow threshold forward so it doesn't spam every frame
            if standing_secs >= state.safety.warn_yellow_at + 1 then
                state.safety.warn_yellow_at = standing_secs + 1200 + math.random(0, 600)
            end
        end
    end

    -- =========================================================
    -- Rare Catch Alert Overlay
    -- =========================================================
    Alert.render(ctx, now, SCREEN_CENTER_X, SCREEN_CENTER_Y)
end

return M
