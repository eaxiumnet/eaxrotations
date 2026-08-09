-- snapshot_sylvanas.lua — Shared DoT/finisher snapshot upgrade gating.
-- WHAT:  Centralises the "should I refresh this snapshot now?" decision used by
--        Rip/Rake (feral cat, attack-power snapshot) and SW:P/VT/UA/DoTs
--        (shadow priest / affliction warlock, spell-damage snapshot).
-- WHEN:  called per-frame in match functions that gate DoT/finisher refreshes.
-- WHY:   replaces 3+ duplicated inline implementations with one tested helper.
-- SAFETY: pure function; nil-guarded; no on_update side-effects.
-- DECISION: parameterised so each spec preserves its exact prior behavior:
--           - no_snapshot_refresh: what to do when snapshotted_value <= 0
--               (cat: false — don't refresh without a snapshot to beat;
--                shadow: true — refresh to establish a snapshot)
--           - extra_window: seconds of slack beyond refresh_window
--               (cat: 1.5; shadow: REFRESH_EXTRA_WINDOW)

local M = {}

--- Decide whether to refresh a snapshot now.
-- @param current          number  current stat value (AP or spell damage)
-- @param snapshotted      number  stat value captured when the DoT was last applied
-- @param remains          number  remaining duration of the active DoT (seconds)
-- @param refresh_window   number  pandemic refresh window (seconds)
-- @param ratio            number  upgrade ratio (e.g. 1.05 = 5% stronger)
-- @param opts             table|nil  { no_snapshot_refresh=bool, extra_window=number }
-- @return boolean  true if the DoT should be (re)applied now
function M.should_upgrade(current, snapshotted, remains, refresh_window, ratio, opts)
    opts = opts or {}
    local no_snapshot_refresh = opts.no_snapshot_refresh
    if no_snapshot_refresh == nil then no_snapshot_refresh = false end
    local extra_window = opts.extra_window or 1.5

    -- DoT expired or about to expire: always refresh.
    if (remains or 0) <= 0 then return true end
    if remains <= refresh_window then return true end

    -- No snapshot captured yet.
    if (snapshotted or 0) <= 0 then
        return no_snapshot_refresh
    end

    -- Refresh only if current stat beats the snapshot by `ratio` AND we're
    -- within the extended window (refresh_window + extra_window).
    if (current or 0) >= snapshotted * ratio and remains <= refresh_window + extra_window then
        return true
    end
    return false
end

-- Export for unit-test dofile pattern
_G.SnapshotHelper = M
local _G_NS = _G.EaxRotations
-- Mock-NS guard (survey item #2): a mock NS (battery / apl_status, marked
-- _EAX_MOCK) must never capture module instances via require-time write-back.
-- Written via the _G_NS alias — same hazard as the 8 direct write-backs.
if _G_NS and not _G_NS._EAX_MOCK then _G_NS.SnapshotHelper = M end
return M
