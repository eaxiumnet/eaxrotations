-- spec_kit_forever_delta.lua — single owner for the _forever delta template.
-- WHAT:  the baseline-capture dance (intercept register, require the vanilla
--        baseline, restore-on-error, re-register the combined list), the
--        Forever bridge mirror fetch, and the by-name/setting helpers that
--        were copy-pasted into every classes/<class>/<spec>_forever.lua
--        (38 files as of 2026-09-18). One owner = one place to get the
--        restore-on-error right.
-- WHEN:  delta-file load time (once per file), never per tick.
-- WHY:   the four-dimension audit flagged ~30 lines of duplicated interceptor
--        per file as the top structural finding; every copy was a place to
--        get restore-on-error subtly wrong.
-- SAFETY: identical mechanics and error strings to the deleted inline copies
--        (unit suites pin "baseline load failed" and registry restoration);
--        registry.register is ALWAYS restored before this module returns,
--        on success and on every error path. NS and all requires resolve at
--        call time, so test harnesses that override global require() and
--        serve stub modules keep working unchanged.

local M = {}

-- ---------------------------------------------------------------------------
-- forever_delta(name, module_path)
--
-- Captures the vanilla baseline's registration without overwriting the
-- playstyle: installs an interceptor on NS.rotation_registry.register,
-- forces baseline re-execution (package.loaded entry cleared), restores the
-- original immediately, and fails loudly when the baseline did not register
-- a strategies table.
--
--   name        human label used verbatim in error strings, e.g.
--               "druid balance"  ->  "[FOREVER] druid balance delta: ..."
--   module_path require path of the vanilla baseline, e.g.
--               "classes/druid/balance_vanilla"
--
-- Returns baseline = { name, strategies, options, register(fn) } where
-- register(combined) re-registers the combined list under the baseline's
-- playstyle name and options through the captured original register.
-- ---------------------------------------------------------------------------
function M.forever_delta(name, module_path)
    local NS = _G.EaxRotations
    local registry = NS and NS.rotation_registry or nil
    if not registry or type(registry.register) ~= "function" then
        error("[FOREVER] " .. name .. " delta: rotation_registry unavailable", 0)
    end
    local original_register = registry.register
    local baseline = nil
    registry.register = function(self, playstyle, strategies, options)
        -- Restore on first use: the baseline registration must not leak the
        -- interceptor, exactly like the pre-extraction inline copies.
        registry.register = original_register
        baseline = { name = playstyle, strategies = strategies, options = options or {} }
        return true
    end
    -- Force baseline re-execution so its registration always reaches the
    -- interceptor above, even if some earlier require() cached the module.
    package.loaded[module_path] = nil
    local baseline_ok, baseline_result = pcall(require, module_path)
    registry.register = original_register
    if not baseline_ok or type(baseline) ~= "table"
        or type(baseline.strategies) ~= "table" then
        error("[FOREVER] " .. name .. " delta: baseline load failed: "
            .. tostring(baseline_result), 0)
    end
    baseline.register = function(combined)
        return original_register(registry, baseline.name, combined, baseline.options)
    end
    return baseline
end

-- ---------------------------------------------------------------------------
-- mirrors() — the Forever bridge name mirrors (Pattern 9: pcall require, an
-- absent bridge degrades every lane to dormant, never to a guessed ID).
-- Sentinel stand-ins are seeded per mirror by the battery's build_ns, so
-- mirror selection itself stays pinned.
-- ---------------------------------------------------------------------------
function M.mirrors()
    local ok_bridge, ForeverBridge = pcall(require,
        "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
    if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
    local function pick(key)
        return (ForeverBridge and type(ForeverBridge[key]) == "table")
            and ForeverBridge[key] or {}
    end
    return {
        name = pick("spell_index_by_name_forever"),
        maxrank = pick("spell_maxrank_by_name_forever"),
        buff = pick("spell_buff_by_name_forever"),
    }
end

-- ---------------------------------------------------------------------------
-- resolve_id(map, client_name) — zero-literal contract (dbc_runbook.md step
-- 3b): only positive integers resolve; anything else leaves the lane
-- dormant. Never a guessed ID.
-- ---------------------------------------------------------------------------
function M.resolve_id(map, client_name)
    local id = map and map[client_name] or nil
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

-- ---------------------------------------------------------------------------
-- append_unique(dst, src) — merge positive numeric IDs into dst without
-- duplicates (debuff/buff id tables shared between era tables).
-- ---------------------------------------------------------------------------
function M.append_unique(dst, src)
    if type(src) ~= "table" then return dst end
    for i = 1, #src do
        local v = src[i]
        if type(v) == "number" and v > 0 then
            local seen = false
            for j = 1, #dst do
                if dst[j] == v then seen = true break end
            end
            if not seen then dst[#dst + 1] = v end
        end
    end
    return dst
end

-- ---------------------------------------------------------------------------
-- setting / setting_bool — menu-setting reads. spec_kit is resolved at CALL
-- time so harnesses that stub "shared/spec_kit_sylvanas" keep working; the
-- setting_bool fallback body mirrors the production shim byte-for-byte.
-- ---------------------------------------------------------------------------
function M.setting(context, key, default)
    local ok_kit, spec_kit = pcall(require, "shared/spec_kit_sylvanas")
    if not ok_kit or type(spec_kit) ~= "table"
        or type(spec_kit.setting) ~= "function" then return default end
    return spec_kit.setting(context, key, default)
end

function M.setting_bool(context, key, default)
    local ok_kit, spec_kit = pcall(require, "shared/spec_kit_sylvanas")
    if ok_kit and type(spec_kit) == "table"
        and type(spec_kit.setting_bool) == "function" then
        return spec_kit.setting_bool(context, key, default)
    end
    local v = M.setting(context, key, default)
    if v == nil then return default end
    return v ~= false
end

return M
