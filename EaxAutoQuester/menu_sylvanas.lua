-- What: Plugin configuration UI for EaxAutoQuester
-- When: Rendered in-game via core.register_on_render_menu_callback (main.lua)
-- Why: Centralizes the settings the quest loop actually honors; legacy controls are not rendered
-- Safety: All menu widgets nil-guarded via get(key, fallback); widgets created once at load
-- Decision: Standalone menu (not EaxRotations schema), uses core.menu.* widget API

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _core_menu = core.menu

-- ============================================================================
-- Menu IDs — prefix: "eaxaq_<feature>_<subfeature>"
-- ============================================================================

local IDs = {
    tree            = "eaxaq_tree",
    enable          = "eaxaq_enable",
    btn_start       = "eaxaq_btn_start",
    btn_stop        = "eaxaq_btn_stop",
    btn_pause       = "eaxaq_btn_pause",
    btn_resume      = "eaxaq_btn_resume",
    debug           = "eaxaq_debug",
    nav_tolerance   = "eaxaq_nav_tolerance",
    pull_gate       = "eaxaq_pull_gate",
    pull_gate_min_hp = "eaxaq_pull_gate_min_hp",
    pull_gate_min_mana = "eaxaq_pull_gate_min_mana",
    profile_gather_herbalism = "eaxaq_profile_gather_herbalism",
    profile_gather_mining = "eaxaq_profile_gather_mining",
    profile_gather_skinning = "eaxaq_profile_gather_skinning",
    profile_gather_fishing = "eaxaq_profile_gather_fishing",
    profile_gather_min_free_slots = "eaxaq_profile_gather_min_free_slots",
    profile_vendor_bag_threshold = "eaxaq_profile_vendor_bag_threshold",
    profile_mount_use = "eaxaq_profile_mount_use",
    toggle_keybind  = "eaxaq_toggle_keybind",
}

-- ============================================================================
-- Menu Widgets — created once at module load, cached for lifetime
-- ============================================================================

local M = {}

-- Tree node — top-level "EaxAutoQuester" container
M.tree = _core_menu.tree_node()

-- Checkboxes (default: enabled for core features)
M.enable          = _core_menu.checkbox(true, IDs.enable)
M.btn_start       = _core_menu.button(IDs.btn_start)
M.btn_stop        = _core_menu.button(IDs.btn_stop)
M.btn_pause       = _core_menu.button(IDs.btn_pause)
M.btn_resume      = _core_menu.button(IDs.btn_resume)
M.debug           = _core_menu.checkbox(false, IDs.debug)

-- Navigation
M.nav_tolerance   = _core_menu.slider_int(1, 10, 3, IDs.nav_tolerance)

-- Pull safety — shared/pull_safety.lua reads these three and nothing else. 0 on either slider
-- turns that one rule off, since no percentage is below zero.
M.pull_gate          = _core_menu.checkbox(true, IDs.pull_gate)
M.pull_gate_min_hp   = _core_menu.slider_int(0, 100, 50, IDs.pull_gate_min_hp)
M.pull_gate_min_mana = _core_menu.slider_int(0, 100, 30, IDs.pull_gate_min_mana)

-- Per-character profile values. The profile module restores these widgets when the character
-- changes. A new profile seeds the four gathering rows from the client's learned professions;
-- these widget defaults keep a no-identity or API-less client on the established manual behavior.
M.profile_gather_herbalism = _core_menu.checkbox(false, IDs.profile_gather_herbalism)
M.profile_gather_mining = _core_menu.checkbox(false, IDs.profile_gather_mining)
M.profile_gather_skinning = _core_menu.checkbox(false, IDs.profile_gather_skinning)
M.profile_gather_fishing = _core_menu.checkbox(false, IDs.profile_gather_fishing)
-- The free-slot reserve the gathering route needs before it takes another node. 0 turns the bag
-- gate off entirely (the vendor threshold remains the backstop); the default matches the loot
-- gate's own "< 4 free slots" rule so the two gates agree until the user moves this one.
M.profile_gather_min_free_slots =
    _core_menu.slider_int(0, 16, 4, IDs.profile_gather_min_free_slots)
M.profile_vendor_bag_threshold = _core_menu.slider_int(50, 100, 80, IDs.profile_vendor_bag_threshold)
M.profile_mount_use = _core_menu.checkbox(true, IDs.profile_mount_use)

-- Keybind — toggle plugin on/off (Ctrl+Shift+T = key 7, shift=true)
M.toggle_keybind  = _core_menu.keybind(7, true, IDs.toggle_keybind)

-- ============================================================================
-- Settings Accessor — nil-guarded read of any setting
-- ============================================================================

--- Read a setting value with fallback default.
--- @param key string Widget key/ID
--- @param fallback any Value returned if widget is nil
--- @return any
-- Hoisted widget probes (item 15). M.get is read on every tick (the coordinator refreshes its
-- debug flag through it), and the inline `pcall(function() ... end)` form allocated a closure per
-- call. Same call, same pcall protection, no closure.
local function widget_get_state(w) return w:get_state() end
local function widget_get(w) return w:get() end

function M.get(key, fallback)
    if not key then return fallback end

    local widget = M[key]
    if not widget then return fallback end

    -- Checkbox: use get_state()
    if widget.get_state then
        local ok, val = pcall(widget_get_state, widget)
        if ok and val ~= nil then return val end
        return fallback
    end

    -- Slider / Combobox: use get()
    if widget.get then
        local ok, val = pcall(widget_get, widget)
        if ok and val ~= nil then return val end
        return fallback
    end

    return fallback
end

--- Set a widget when the profile owner restores a character's values. This is deliberately
--- separate from get(): user settings still flow through the widgets, while a character switch
--- is the only caller that writes them programmatically.
function M.set(key, value)
    if not key then return false end
    local widget = M[key]
    if not widget or type(widget.set) ~= "function" then return false end
    local ok = pcall(widget.set, widget, value)
    return ok
end

-- ============================================================================
-- Render
-- ============================================================================

--- The tree body. A module-level function rather than a closure built in `M.render`: the body
--- was handed to `M.tree:render` as a fresh closure on every menu frame (measured 32 B/frame),
--- and it only ever reads the widgets that were created once at load, so the body itself
--- allocates nothing.
local function render_tree_body()
    -- Checkboxes — core features
    if M.enable then
        M.enable:render("Enable AutoQuester", "Master toggle — enables or disables the entire auto-questing system")
    end

    -- Control buttons row
    if M.btn_start then M.btn_start:render("Start", "Begin auto-questing") end
    if M.btn_stop then M.btn_stop:render("Stop", "Stop all movement and disable") end
    if M.btn_pause then M.btn_pause:render("Pause", "Pause navigation (keep enabled)") end
    if M.btn_resume then M.btn_resume:render("Resume", "Resume after pause") end

    if M.debug then
        M.debug:render("Debug Logging", "Enable verbose debug output to the Sylvanas log console")
    end

    -- Navigation
    if M.nav_tolerance then
        M.nav_tolerance:render("Nav Tolerance", "Distance (yards) from waypoint considered 'arrived' — lower = more precise")
    end

    -- Pull safety — the gate that decides whether to start a fight at all
    if M.pull_gate then
        M.pull_gate:render("Careful Pulling", "Don't start a fight you'd regret: too low on health or mana, or a crowd with mobs pathing nearby. Uncheck to pull everything as before")
    end

    if M.pull_gate_min_hp then
        M.pull_gate_min_hp:render("Pull Safety: Min Health %", "Do not pull below this health (0 = this rule off)")
    end

    if M.pull_gate_min_mana then
        M.pull_gate_min_mana:render("Pull Safety: Min Mana %", "Do not pull below this mana — a caster needs enough for one more kill (0 = this rule off)")
    end

    -- Per-character profile. Gathering rows are seeded from learned professions and remain manual
    -- overrides; the nearby-node route runs only while the guide has no active goal, and quest
    -- objectives and combat always remain authoritative.
    if M.profile_gather_herbalism then
        M.profile_gather_herbalism:render("Profile: Gather Herbalism", "Auto-enabled when this character has Herbalism; uncheck to keep it off. Uses nearby nodes only while no quest goal is active")
    end
    if M.profile_gather_mining then
        M.profile_gather_mining:render("Profile: Gather Mining", "Auto-enabled when this character has Mining; uncheck to keep it off. Uses nearby nodes only while no quest goal is active")
    end
    if M.profile_gather_skinning then
        M.profile_gather_skinning:render("Profile: Gather Skinning", "Auto-enabled when this character has Skinning; uncheck to keep it off. Uses nearby nodes only while no quest goal is active")
    end
    if M.profile_gather_fishing then
        M.profile_gather_fishing:render("Profile: Gather Fishing", "Auto-enabled when this character has Fishing; uncheck to keep it off. Uses nearby nodes only while no quest goal is active")
    end
    if M.profile_gather_min_free_slots then
        M.profile_gather_min_free_slots:render("Profile: Gather Min Free Slots", "Stop gathering below this many free bag slots for this character (0 = never block on bag space; default 4, matching the loot rule)")
    end
    if M.profile_vendor_bag_threshold then
        M.profile_vendor_bag_threshold:render("Profile: Vendor at Bag %", "Visit a vendor when bags reach this fullness for this character (50-100%)")
    end
    if M.profile_mount_use then
        M.profile_mount_use:render("Profile: Use Mounts", "Allow automatic mounting for long walks for this character; dismount safety remains unconditional")
    end

    -- Keybind
    if M.toggle_keybind then
        M.toggle_keybind:render("Toggle Plugin Keybind", "Keybind to enable/disable the auto-questing plugin on the fly")
    end
end

--- Render the full EaxAutoQuester menu tree.
--- Called every frame by main.lua's on_render_menu callback.
function M.render()
    if not M.tree then return end

    -- Begin tree with the hoisted body
    M.tree:render("EaxAutoQuester", render_tree_body)
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.menu = M

return M
