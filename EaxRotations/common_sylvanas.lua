-- common_sylvanas.lua — Shared schema helpers for EaxRotations.
-- WHAT:  checkbox/slider/combobox factory functions used by class schema files.
-- WHEN:  addon load; schema files call these during their own load.
-- WHY:   centralizes widget metadata so schema files stay data-only (no render logic).
-- SAFETY: no menu.x:get() here — these are constructors, not accessors.

-- Shared schema helpers for EaxRotations.
-- Keep this file Sylvanas-native and independent from any external rotation UI.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local function checkbox(key, default, label, tooltip)
    -- A schema entry is just data. main.lua owns widget creation, so class
    -- schema files remain readable and do not duplicate render-time code.
    return {
        type = "checkbox",
        key = key,
        default = default,
        label = label,
        tooltip = tooltip,
    }
end

local function option(value, text)
    return { value = value, text = text }
end

local function dropdown(key, default, label, tooltip, choices)
    -- Dropdown options store stable values separately from labels. This makes
    -- saved settings resilient to text changes in public-facing menu labels.
    return {
        type = "dropdown",
        key = key,
        default = default,
        label = label,
        tooltip = tooltip,
        options = choices,
    }
end

local function section(header, settings, description)
    local out = { header = header, settings = settings }
    if description then out.description = description end
    return out
end

local trinket_modes = {
    option("off", "Off"),
    option("offensive", "Offensive"),
    option("defensive", "Defensive"),
}

-- ============================================================================
-- Shared Settings Factories for Quick-Win Improvements
-- ============================================================================

function NS.common_auto_aoe_section()
    return section("Auto-AoE", {
        checkbox("auto_aoe_enabled", true, "Enable Auto-AoE", "Automatically switch to AoE playstyle when enemy count exceeds threshold"),
        { type = "slider", key = "auto_aoe_threshold", default = 3, min = 2, max = 8, label = "AoE Threshold", tooltip = "Minimum enemies to trigger Auto-AoE" },
    }, "Dynamically switches to AoE rotation when enough enemies are in range.")
end

function NS.common_interrupt_humanize_section()
    return section("Interrupt Humanization", {
        checkbox("interrupt_humanize_enabled", true, "Humanize Interrupts", "Add random per-cast delay so interrupts look less robotic"),
        { type = "slider", key = "interrupt_cast_jitter_min", default = 0, min = 0, max = 10, label = "Cast Jitter Min (0.1s)", tooltip = "Minimum random delay for regular casts (in 0.1s units). 0 = no delay, 4 = 0.4s" },
        { type = "slider", key = "interrupt_cast_jitter_max", default = 4, min = 0, max = 10, label = "Cast Jitter Max (0.1s)", tooltip = "Maximum random delay for regular casts (in 0.1s units). 0 = no delay, 4 = 0.4s" },
        { type = "slider", key = "interrupt_channel_jitter_min", default = 3, min = 0, max = 15, label = "Channel Jitter Min (0.1s)", tooltip = "Minimum random delay for channeled spells (in 0.1s units). 3 = 0.3s" },
        { type = "slider", key = "interrupt_channel_jitter_max", default = 8, min = 0, max = 15, label = "Channel Jitter Max (0.1s)", tooltip = "Maximum random delay for channeled spells (in 0.1s units). 8 = 0.8s" },
    }, "Adds channel-aware random delay before interrupting so behavior mimics human reaction time.")
end

function NS.common_ttd_section()
    return section("Linear Regression TTD", {
        checkbox("ttd_linear_enabled", true, "Enable Regression TTD", "Estimate boss time-to-die from local HP samples instead of engine API"),
        { type = "slider", key = "ttd_sample_interval", default = 5, min = 1, max = 20, label = "Sample Interval (0.1s)", tooltip = "Seconds between HP samples. 5 = 0.5s" },
        { type = "slider", key = "ttd_window", default = 12, min = 4, max = 30, label = "Sample Window (s)", tooltip = "How many seconds of recent HP history to keep" },
        { type = "slider", key = "ttd_min_samples", default = 4, min = 3, max = 12, label = "Min Samples", tooltip = "Minimum HP samples before regression is trusted" },
        { type = "slider", key = "ttd_max_ttd", default = 300, min = 30, max = 600, label = "Max TTD Cap (s)", tooltip = "Highest TTD value the model will ever return" },
    }, "Uses least-squares regression on recent health samples for accurate boss-fight TTD.")
end

function NS.common_predictive_healing_section()
    return section("Predictive Healing Deficit", {
        checkbox("healer_predict_enabled", true, "Enable Predictive Healing", "Project future health deficit from recent damage intake to avoid overhealing"),
        { type = "slider", key = "healer_predict_sample_interval", default = 5, min = 1, max = 20, label = "Sample Interval (0.1s)", tooltip = "Seconds between HP samples. 5 = 0.5s" },
        { type = "slider", key = "healer_predict_window", default = 4, min = 1, max = 10, label = "History Window (s)", tooltip = "How many seconds of recent HP history to keep for rate estimation" },
        { type = "slider", key = "healer_predict_horizon", default = 2, min = 1, max = 5, label = "Prediction Horizon (s)", tooltip = "How far ahead to project damage (should match typical cast time)" },
        { type = "slider", key = "healer_predict_safety_pct", default = 5, min = 0, max = 20, label = "Safety Margin (% max HP)", tooltip = "Extra predicted deficit buffer as % of max HP" },
        { type = "slider", key = "healer_predict_min_rate", default = 1, min = 0, max = 10, label = "Min Damage Rate (%/s)", tooltip = "Ignore damage slower than this threshold to avoid reacting to noise" },
        { type = "slider", key = "healer_predict_max_mult", default = 15, min = 10, max = 30, label = "Max Deficit Multiplier (0.1x)", tooltip = "Cap predicted extra deficit at this multiple of current deficit. 15 = 1.5x" },
    }, "Estimates future health deficit from recent damage intake to stop healers from overhealing.")
end

-- common schema initialized
