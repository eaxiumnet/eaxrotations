-- =============================================================================
-- UI/ControlPanel Module - Control panel rendering (v2.4.3)
-- Shows fishing toggle + real-time session stats + stealth status.
-- =============================================================================

local M = {}

--- Render control panel
-- @param ctx table context
-- @return table elements array
function M.render_control_panel(ctx)
    local state = ctx.state
    local deps = ctx.deps
    local elements = {}
    local now = 0
    local APISurface = require("core/api_surface")
    if APISurface.now then
        local ok, t = pcall(APISurface.now)
        if ok then now = t end
    end
    
    local current = deps.config.menu.enabled:get_state()
    local cp_id = "openfishing_main_toggle_" .. state.safety.stop_id
    
    local new_state = deps.control_panel_helper:insert_key_checkbox_(
        elements, "Eax's Fishing", current, 0, false, cp_id
    )
    
    -- Safety lock for bag full — require an explicit OFF then ON after a full-bag stop
    if state.bag.safety_lock_active then
        if new_state == false then
            state.bag.safety_lock_active = false
        else
            state.safety.stop_id = state.safety.stop_id + 1
            table.insert(elements, {type="label", text="Safety lock: toggle OFF once, then ON"})
            return elements
        end
    end
    
    -- Handle toggle change
    if new_state ~= current then
        -- Safely set menu value
        local item = deps.config.menu.enabled
        if item then
            if type(item.set_state) == "function" then
                item:set_state(new_state)
            elseif type(item.set) == "function" then
                item:set(new_state)
            end
        end
        
        if new_state then
            state.fishing.failed_cast_count = 0
            state.fishing.consecutive_catches = 0
            state.fishing.awaiting_bobber = false
            state.fishing.status = "Idle"
        else
            state.fishing.awaiting_bobber = false
            -- Stop nav
            local Client = require("navigation/client")
            Client.stop(ctx)
        end
    end
    
    -- ═══════════════════════════════════════════════════════════════════
    -- Status + Session Stats (v2.4.3)
    -- ═══════════════════════════════════════════════════════════════════
    
    -- Main status
    table.insert(elements, {type="label", text="Status: " .. state.fishing.status})
    
    -- Core session stats
    local elapsed_min = 0
    if state.session.start_time and state.session.start_time > 0 then
        elapsed_min = math.floor((now - state.session.start_time) / 60)
    end
    local rate = 0
    if elapsed_min > 0 then
        rate = math.floor(state.session.catches / elapsed_min)
    end
    
    table.insert(elements, {type="label", text="Session: " .. elapsed_min .. "min | Casts: " .. state.session.attempts .. " | Catches: " .. state.session.catches})
    if rate > 0 then
        table.insert(elements, {type="label", text="Rate: " .. rate .. "/min | Streak: " .. (state.qol and state.qol.catch_streak or 0) .. " (best: " .. (state.qol and state.qol.best_catch_streak or 0) .. ")"})
    end
    
    -- Stealth status (v2.4.3)
    if deps.config.menu.stealth_mode and deps.config.menu.stealth_mode:get_state() then
        local st = state.stealth
        if st then
            local stealth_text = ""
            if st.player_nearby then
                local mult = 1.0
                local Stealth = require("core/stealth")
                mult = Stealth.get_delay_multiplier(ctx, now)
                stealth_text = "Player nearby — " .. string.format("%.1fx", mult)
            elseif st.cooldown_end and now < st.cooldown_end then
                local remaining = math.ceil(st.cooldown_end - now)
                stealth_text = "Cooldown — " .. remaining .. "s left"
            elseif st.total_encounters and st.total_encounters > 0 then
                stealth_text = "Safe (" .. st.total_encounters .. " encounters)"
            else
                stealth_text = "Safe"
            end
            table.insert(elements, {type="label", text="Stealth: " .. stealth_text})
        end
    end
    
    -- Gold tracking (v2.4.3)
    local current_gold = 0
    local gold_ok, gold_result = pcall(APISurface.get_gold)
    if gold_ok then current_gold = gold_result end
    local gold_start = state.session.stats and state.session.stats.gold_start or current_gold
    local gold_gained = math.max(0, current_gold - gold_start)
    if gold_gained > 0 then
        local gph = 0
        if elapsed_min > 0 then gph = math.floor(gold_gained / elapsed_min * 60 / 100) / 10 end
        table.insert(elements, {type="label", text="Gold: +" .. string.format("%.1f", gold_gained / 100) .. "g" .. (gph > 0 and " (" .. gph .. "g/hr)" or "")})
    end
    
    -- Lure status (v2.4.3)
    if state.lure and state.lure.assumed_expire_time > 0 then
        local lure_remaining = state.lure.assumed_expire_time - now
        if lure_remaining > 0 then
            local mins = math.floor(lure_remaining / 60)
            local secs = math.floor(lure_remaining % 60)
            table.insert(elements, {type="label", text="Lure: " .. mins .. "m " .. secs .. "s"})
        else
            table.insert(elements, {type="label", text="Lure: expired"})
        end
    end
    
    return elements
end

return M
