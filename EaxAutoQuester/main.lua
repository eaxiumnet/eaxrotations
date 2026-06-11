-- What: Entry point for EaxAutoQuester
-- When: Loaded by Project Sylvanas on plugin start (standalone, not EaxRotations)
-- Why: Bootstraps auto-questing system — registers pre-tick, render, menu callbacks
-- Safety: lazy-loads all submodules; nil-guards menu access; graceful fallback on missing modules
-- Decision: Standalone _G.EaxAutoQuester namespace — no dependency on EaxRotations

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _core_time = core.time
local _core_log = core.log
local _get_local_player = core.object_manager.get_local_player

local NS = {}
_G.EaxAutoQuester = NS

-- Plugin state — nil-guarded defaults
local state = {
    enabled = true,
    initialized = false,
    version = "1.0.0",
}

-- Module references (lazy-loaded via pcall)
local _utils = nil
local _menu = nil
local _quest_state = nil

-- Static table reuse (Pattern 4 from AGENTS.md) — avoids per-frame GC churn
local _t = { n = 0 }
local _loaded_modules = { n = 0 }

-- ============================================================================
-- Module Initialization
-- ============================================================================
local function init_modules()
    if state.initialized then return true end

    local ok

    -- Clear static reuse table before building module list
    _t.n = 0

    ok, _utils = pcall(require, "EaxAutoQuester.utils")
    if ok then
        _t.n = _t.n + 1; _t[_t.n] = "utils"
    else
        _utils = nil
    end

    ok, _menu = pcall(require, "EaxAutoQuester.menu")
    if ok then
        _t.n = _t.n + 1; _t[_t.n] = "menu"
    else
        _menu = nil
    end

    ok, _quest_state = pcall(require, "EaxAutoQuester.quest_state")
    if ok then
        _t.n = _t.n + 1; _t[_t.n] = "quest_state"
    else
        _quest_state = nil
    end

    state.initialized = true
    _core_log("EaxAutoQuester v" .. tostring(state.version) .. " initialized — modules: " .. table.concat(_t, ", ", 1, _t.n))
    return true
end

-- ============================================================================
-- Callbacks
-- ============================================================================

-- on_pre_tick: Called before each game tick. Runs quest state updates.
local function on_pre_tick()
    -- (state.enabled or 0) > 0 — nil-guard with safe boolean coercion
    if not state.enabled then return end
    if not state.initialized then init_modules() end
    if not _quest_state then return end

    _quest_state.update()
end

-- on_render: Called every frame for graphics rendering. Shows debug overlay.
local function on_render()
    if not state.enabled then return end
    if not state.initialized then init_modules() end
    if not _quest_state then return end

    _quest_state.render_debug()
end

-- on_render_menu: Called for rendering custom menu elements.
local function on_render_menu()
    -- Menu always shows when plugin is loaded, even if disabled
    if not state.initialized then init_modules() end
    if not _menu then return end

    _menu.render()
end

-- Register callbacks
core.register_on_pre_tick_callback(on_pre_tick)
core.register_on_render_callback(on_render)
core.register_on_render_menu_callback(on_render_menu)

-- ============================================================================
-- Exports
-- ============================================================================
function NS.init_modules()
    return init_modules()
end

function NS.get_utils()
    return _utils
end

function NS.get_menu()
    return _menu
end

function NS.get_quest_state()
    return _quest_state
end

return NS
