
-- IntelliSense / Syntax helper for: common/utility/ts_override_helper
-- Target Selector Override Helper
--
-- Usage:
--   local ts = require("common/utility/ts_override_helper")
--
--   -- call in on_update, safe to call every frame (ONCE mode is default, only writes once)
--   ts:set_mode(ts.enums.mode.SILENT_AUTO)
--   ts:set_max_range_damage(40)
--   ts:set_weight(ts.enums.context.DAMAGE, ts.enums.weight.MULTIPLE_HITS, true, 5)
--
-- Write modes (optional last parameter on every setter):
--   ts.enums.write_mode.ONCE       -- (DEFAULT) apply once per session, never again
--   ts.enums.write_mode.ON_CHANGE  -- apply only when value differs from last write
--   ts.enums.write_mode.ALWAYS     -- apply every frame (use sparingly)

-- ─────────────────────────────────────────────────
-- Enums
-- ─────────────────────────────────────────────────

---@class ts_write_mode
---@field ONCE number       Apply once per session (default). Safe to call every frame.
---@field ON_CHANGE number  Apply only when the value has changed since last write.
---@field ALWAYS number     Apply every frame. Use only when you need real-time sync.

---@class ts_mode
---@field MANUAL number         Manual targeting only.
---@field HARD_TARGET number    Semi-manual: prioritize HUD target.
---@field SILENT_AUTO number    Fully automatic, no HUD changes.
---@field DISABLED number       Target selector disabled entirely.

---@class ts_pull_mode
---@field DONT_PULL number              Don't auto-pull.
---@field PULL_HUD_TARGET number        Pull only HUD target.
---@field PULL_FULL_AUTOMATIC number    Pull any valid target automatically.

---@class ts_override_type
---@field DISABLED number
---@field MARK number
---@field TARGET number
---@field FOCUS number
---@field MOST_HITS number
---@field CLOSER number
---@field MOST_MAX_HEALTH number
---@field MOST_CURRENT_HEALTH number
---@field LEAST_MAX_HEALTH number
---@field LEAST_CURRENT_HEALTH number
---@field TEAM_TARGET_FOLLOWUP number

---@class ts_context
---@field DAMAGE string  "damage"
---@field HEAL string    "heal"

---@class ts_weight
---@field THREAT string                 Less threat = more weight (float-based).
---@field ANGLE string                  Is inside angle cone (bool) — flat weight on/off.
---@field ANGLE_F string                Less angle = more weight (float-based). Use set_weight_angle_f().
---@field CLOSE string                  Less distance = more weight (float-based).
---@field HEALTH_DECREASE string        Less HP % = more weight (float-based).
---@field HEALTH_INCREASE string        More HP % = more weight (float-based).
---@field MULTIPLE_HITS string          More nearby units = more weight (float-based). Use set_weight_multiple_hits().
---@field LOWEST_MAX_HP string          Is lowest max HP unit in list (bool).
---@field LOWEST_CURRENT_HP string      Is lowest current HP unit in list (bool).
---@field HIGHEST_MAX_HP string         Is highest max HP unit in list (bool).
---@field HIGHEST_CURRENT_HP string     Is highest current HP unit in list (bool).
---@field FOCUS string                  Is focus target (bool).
---@field TARGET string                 Is HUD target (bool).
---@field SELFISH string                Is local player (bool).
---@field TANK string                   Is tank role (bool).
---@field HEALER string                 Is healer role (bool).
---@field DPS string                    Is DPS role (bool).
---@field INJURED string                HP <= 60% damage / <= 50% heal (bool).
---@field LOW_HP string                 HP <= 40% damage / <= 25% heal (bool).
---@field TEAM_TARGET_FOLLOWUP string   Most targeted unit by your team (bool).
---@field LOW_FORECAST string           Combat forecast <= 5.0s (bool).
---@field MARKS string                  Is marked with selected marks (bool).

---@class ts_enums
---@field write_mode ts_write_mode
---@field mode ts_mode
---@field pull_mode ts_pull_mode
---@field override_type ts_override_type
---@field context ts_context
---@field weight ts_weight

-- ─────────────────────────────────────────────────
-- Class Definition
-- ─────────────────────────────────────────────────

---@class ts_override_helper
---@field enums ts_enums                        All enums for modes, weights, contexts.
---@field target_selector target_selector        Direct access to the target_selector module.
---@field menu_elements table                    Direct access to menu_elements (advanced use).
--
-- Mode & Settings
---@field set_mode fun(self: ts_override_helper, mode: number, write_mode: number|nil): nil                             Set targeting mode (ts_enums.mode: MANUAL, HARD_TARGET, SILENT_AUTO, DISABLED).
---@field set_max_range_damage fun(self: ts_override_helper, range: number, write_mode: number|nil): nil                Set max targeting range for damage (0-50).
---@field set_max_range_heal fun(self: ts_override_helper, range: number, write_mode: number|nil): nil                  Set max targeting range for healing (0-50).
---@field set_pull_mode fun(self: ts_override_helper, mode: number, write_mode: number|nil): nil                        Set pull logic (ts_enums.pull_mode: DONT_PULL, PULL_HUD_TARGET, PULL_FULL_AUTOMATIC).
---@field set_semi_force_target_heal fun(self: ts_override_helper, enabled: boolean, write_mode: number|nil): nil       Override HUD target for heal in semi-manual mode.
---@field set_semi_force_target_damage fun(self: ts_override_helper, enabled: boolean, write_mode: number|nil): nil     Override HUD target for damage in semi-manual mode.
---@field set_aa_totems fun(self: ts_override_helper, enabled: boolean, write_mode: number|nil): nil                    Enable/disable auto-attack totems.
---@field set_re_focus fun(self: ts_override_helper, enabled: boolean, write_mode: number|nil): nil                     Enable/disable auto re-focus dead units.
---@field set_re_target_hunter fun(self: ts_override_helper, enabled: boolean, write_mode: number|nil): nil             Enable/disable re-target hunter after feign death.
---@field set_pull_allowed fun(self: ts_override_helper, enabled: boolean, write_mode: number|nil): nil                 Set the is_pull_allowed internal flag.
--
-- Enable / Disable
---@field set_damage_enabled fun(self: ts_override_helper, enabled: boolean, write_mode: number|nil): nil               Enable or disable the damage target selector.
---@field set_heal_enabled fun(self: ts_override_helper, enabled: boolean, write_mode: number|nil): nil                 Enable or disable the heal target selector.
--
-- Weights
---@field set_weight fun(self: ts_override_helper, ctx: string, weight_name: string, enabled: boolean, value: number, write_mode: number|nil): nil                  Set a weight toggle + slider. Use ts_enums.context and ts_enums.weight enums.
---@field set_weight_angle_f fun(self: ts_override_helper, ctx: string, enabled: boolean, value: number, write_mode: number|nil): nil                               Set the float-based angle weight (angle_f). Separate from the bool "angle".
---@field set_weight_multiple_hits fun(self: ts_override_helper, ctx: string, enabled: boolean, value: number, radius: number, write_mode: number|nil): nil         Set the multiple_hits weight including splash radius (2.0-20.0).
--
-- Override Slots
---@field set_override_slot fun(self: ts_override_helper, ctx: string, slot: number, override_type: number, write_mode: number|nil): nil     Configure override slot (1-3) with ts_enums.override_type.
---@field disable_override_slot fun(self: ts_override_helper, ctx: string, slot: number, write_mode: number|nil): nil                        Disable an override slot (1-3).
--
-- Blacklist Marks
---@field set_blacklist_marks_enabled fun(self: ts_override_helper, ctx: string, enabled: boolean, write_mode: number|nil): nil              Enable/disable mark-based blacklisting. ctx = "damage"|"heal".
---@field set_blacklist_mark fun(self: ts_override_helper, ctx: string, slot: number, mark_index: number, write_mode: number|nil): nil       Set which mark to blacklist in slot (1-3).
--
-- Batch & Utility
---@field set_weights_batch fun(self: ts_override_helper, ctx: string, weights: table, write_mode: number|nil): nil     Apply multiple weights at once. { name = { enabled=bool, value=number, radius?=number }, ... }
---@field reset fun(self: ts_override_helper): nil                                                                       Reset all ONCE guards. Call on spec change or encounter start.
---@field is_applied fun(self: ts_override_helper, key: string): boolean                                                 Check if a key was already applied in ONCE mode. e.g. "damage.weight_close"

--========================
-- Examples (copy-paste)
--========================

-- EXAMPLE 1: Basic damage rotation setup (call in on_update, safe every frame)
--
--   local ts = require("common/utility/ts_override_helper")
--
--   local W = ts.enums.weight
--   local CTX = ts.enums.context
--
--   local function setup_ts()
--       ts:set_damage_enabled(true)
--       ts:set_max_range_damage(40)
--       ts:set_mode(ts.enums.mode.SILENT_AUTO)
--       ts:set_weight(CTX.DAMAGE, W.TARGET, true, 2)
--       ts:set_weight(CTX.DAMAGE, W.HIGHEST_MAX_HP, true, 1)
--   end

-- EXAMPLE 2: AoE-focused damage setup with splash radius
--
--   local ts = require("common/utility/ts_override_helper")
--
--   local W = ts.enums.weight
--   local CTX = ts.enums.context
--
--   local function setup_ts_aoe()
--       ts:set_damage_enabled(true)
--       ts:set_max_range_damage(40)
--       ts:set_weight_multiple_hits(CTX.DAMAGE, true, 5, 8.0)
--       ts:set_weight(CTX.DAMAGE, W.HEALTH_DECREASE, false, 0)
--   end

-- EXAMPLE 3: Batch weights (one call for many weights)
--
--   local ts = require("common/utility/ts_override_helper")
--
--   local W = ts.enums.weight
--   local CTX = ts.enums.context
--
--   ts:set_weights_batch(CTX.DAMAGE, {
--       [W.TARGET]                = { enabled = true,  value = 2 },
--       [W.HEALTH_DECREASE]       = { enabled = true,  value = 3 },
--       [W.MULTIPLE_HITS]         = { enabled = true,  value = 5, radius = 8.0 },
--       [W.TEAM_TARGET_FOLLOWUP]  = { enabled = true,  value = 1 },
--       [W.HIGHEST_MAX_HP]        = { enabled = false, value = 0 },
--   })

-- EXAMPLE 4: Heal setup
--
--   local ts = require("common/utility/ts_override_helper")
--
--   local W = ts.enums.weight
--   local CTX = ts.enums.context
--
--   ts:set_heal_enabled(true)
--   ts:set_max_range_heal(40)
--   ts:set_weight(CTX.HEAL, W.HEALTH_DECREASE, true, 3)
--   ts:set_weight(CTX.HEAL, W.INJURED, true, 2)
--   ts:set_weight(CTX.HEAL, W.LOW_HP, true, 4)
--   ts:set_weight(CTX.HEAL, W.TANK, true, -1)

-- EXAMPLE 5: ON_CHANGE mode (value synced from a menu slider every frame)
--
--   local ts = require("common/utility/ts_override_helper")
--   local SYNC = ts.enums.write_mode.ON_CHANGE
--
--   local function on_update()
--       ts:set_max_range_damage(my_menu.range_slider:get(), SYNC)
--   end

-- EXAMPLE 6: Override slot — prioritize focus target
--
--   local ts = require("common/utility/ts_override_helper")
--
--   ts:set_override_slot(ts.enums.context.DAMAGE, 1, ts.enums.override_type.FOCUS)

-- EXAMPLE 7: Reset guards on encounter start
--
--   local ts = require("common/utility/ts_override_helper")
--
--   local function on_encounter_start()
--       ts:reset()
--       -- now all ONCE overrides will fire again
--   end

---@type ts_override_helper
local tbl
return tbl
