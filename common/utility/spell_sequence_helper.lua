
-- Example:
-- ---@type spell_sequence_helper
-- local cast_sequence = require("common/utility/spell_sequence_helper")
-- cast_sequence: -> IntelliSense
-- Warning: Access with ":", not "."

---@meta
---@diagnostic disable: undefined-global, missing-fields, lowercase-global

--------------------------------------------------------------------------------
-- Cast Policy Enum
--------------------------------------------------------------------------------

---@alias cast_policy
---| '"no_restrictions"'      # Can cast same spell repeatedly (default)
---| '"once_each_cycle"'      # Can only cast again after all spells in sequence evaluated
---| '"once_each_cycle_or_fill"' # Can cast again after cycle completes OR fill activates
---| '"once_each_cooldown"'   # Has internal cooldown before can cast again
---| '"once_each_switch"'     # Can cast again after any other base sequence spell casts
---| '"once_each_switch_or_fill"' # Can cast again after any other spell (base or fill) casts

--------------------------------------------------------------------------------
-- Entry Classes
--------------------------------------------------------------------------------

---@class advanced_spell_entry
---@field spell izi_spell The spell object
---@field target game_object|fun():game_object Target or function returning target
---@field condition fun():boolean Condition function (return true to allow cast)
---@field opts? table Cast opts passed to cast_safe

---@class advanced_fill_entry
---@field spell izi_spell The fill spell object
---@field target game_object|fun():game_object Target or function returning target
---@field condition fun():boolean Condition function (return true to allow cast)

--------------------------------------------------------------------------------
-- Options Class
--------------------------------------------------------------------------------

---@class advanced_sequence_opts
---@field timeout? number Max time before auto-cancel (default 20)
---@field cooldown? number Cooldown after sequence ends (default 0)
---@field debug_name? string Name for logging (default "advanced_seq")
---@field is_flexible_order? boolean If false, stop on first true-but-uncastable condition (default true)
---@field fill_entries? advanced_fill_entry[] Fill spells when no main entry can cast
---@field fill_delay_ms? number Ms between fill casts (default 120)
---@field cast_policy? cast_policy Controls spell re-cast behavior (default "no_restrictions")
---@field cast_policy_cooldown? number Internal cooldown for once_each_cooldown policy (default 4.0)

--------------------------------------------------------------------------------
-- Cast Policy Constants
--------------------------------------------------------------------------------

---@class cast_policy_enum
---@field NO_RESTRICTIONS string "no_restrictions"
---@field ONCE_EACH_CYCLE string "once_each_cycle"
---@field ONCE_EACH_CYCLE_OR_FILL string "once_each_cycle_or_fill"
---@field ONCE_EACH_COOLDOWN string "once_each_cooldown"
---@field ONCE_EACH_SWITCH string "once_each_switch"
---@field ONCE_EACH_SWITCH_OR_FILL string "once_each_switch_or_fill"

--------------------------------------------------------------------------------
-- Confirmed Sequence Types
--------------------------------------------------------------------------------

---@class confirmed_step
---@field spell izi_spell The spell to cast
---@field target game_object|fun():game_object Target for the spell (or function returning target)
---@field spell_id integer Spell ID for server callback matching
---@field opts? table Cast opts passed to cast_safe (e.g. { damage_type = ... })
---@field use_cast? boolean If true, uses spell:cast() instead of cast_safe() (for self-casts like Vanish, Stealth)

---@class confirmed_sequence_opts
---@field timeout? number Global timeout for the entire sequence (default 10)
---@field step_timeout? number Per-step timeout (default 3)
---@field debug_name? string Name for logging (default "confirmed_seq")
---@field cooldown? number Cooldown after sequence ends (default 0)
---@field retry_delay? number Retry cast if no confirmation after this many seconds (default 0.4)
---@field player? game_object Local player for on_spell_cast filtering (auto-detected if nil)

--------------------------------------------------------------------------------
-- spell_sequence_helper
--------------------------------------------------------------------------------

---@class spell_sequence_helper
---@field CAST_POLICY cast_policy_enum Cast policy constants
local spell_sequence_helper = {}

-- Native sequence methods (forwarded to engine if available, pure Lua fallback otherwise)

---Cast spell A then immediately spell B.
---@param spell_a izi_spell
---@param target_a game_object
---@param spell_b izi_spell
---@param target_b game_object
---@param delay? number
---@param timeout? number
---@param debug_name? string
---@param cooldown? number
---@return boolean
function spell_sequence_helper:a_into_b(spell_a, target_a, spell_b, target_b, delay, timeout, debug_name, cooldown) end

---Cast spells in strict order, one-shot. Each step advances on cast_safe success.
---@param spells izi_spell[]
---@param targets (game_object|fun():game_object)[]
---@param delay? number Seconds between steps (default 0)
---@param timeout? number Seconds before auto-cancel (default 10)
---@param debug_name? string Name for logging
---@param cooldown? number Cooldown after completion (default 0)
---@return boolean
function spell_sequence_helper:simple_sequence(spells, targets, delay, timeout, debug_name, cooldown) end

---Priority loop with conditions + fill spells. Scans all entries every frame
---top→bottom, casts first where condition() is true. Fills when nothing castable.
---Runs until timeout or cancel(). Conditions are re-evaluated each frame.
---@param entries advanced_spell_entry[]
---@param opts? advanced_sequence_opts
---@return boolean
function spell_sequence_helper:advanced_sequence(entries, opts) end

---Server-confirmed step-by-step sequence. Each step waits for on_spell_cast
---to match spell_id before advancing. Requires wiring on_spell_cast callback.
---@param steps confirmed_step[]
---@param opts? confirmed_sequence_opts
---@return boolean
function spell_sequence_helper:confirmed_sequence(steps, opts) end

---Feed spell cast callback data for confirmed_sequence player filtering.
---Wire once: core.register_on_spell_cast_callback(function(data) seq:on_spell_cast(data) end)
---@param data table
function spell_sequence_helper:on_spell_cast(data) end

-- Debug

---Debug logging for native + simple + advanced sequences.
---@param enabled boolean
function spell_sequence_helper:set_debug(enabled) end

---@return boolean
function spell_sequence_helper:get_debug() end

---Debug logging for confirmed sequences.
---@param enabled boolean
function spell_sequence_helper:set_confirmed_debug(enabled) end

---@return boolean
function spell_sequence_helper:get_confirmed_debug() end

-- Confirmed-only queries

---True if a confirmed sequence is running.
---@return boolean
function spell_sequence_helper:is_confirmed_active() end

---Cancel the active confirmed sequence.
function spell_sequence_helper:cancel_confirmed() end

---Progress of confirmed sequence only.
---@return integer|nil current, integer|nil total
function spell_sequence_helper:get_confirmed_progress() end

-- Combined state (checks native + simple + advanced + confirmed)

---True if ANY sequence is active.
---@return boolean
function spell_sequence_helper:is_active() end

---Advance all active sequences. Call every frame from on_update.
function spell_sequence_helper:on_update() end

---Cancel native + simple + advanced sequences (NOT confirmed; use cancel_confirmed()).
function spell_sequence_helper:cancel() end

---Cancel ALL sequences (native + simple + advanced + confirmed).
function spell_sequence_helper:cancel_all() end

---True if any cooldown is active.
---@return boolean
function spell_sequence_helper:is_on_cooldown() end

---Max remaining cooldown across all sources.
---@return number
function spell_sequence_helper:get_cooldown_remaining() end

---Type of the currently active sequence.
---@return string|nil type "confirmed"|"advanced"|"simple"|"a_into_b"|nil
function spell_sequence_helper:get_sequence_type() end

---Progress of whichever sequence is active (confirmed > simple > advanced > native).
---@return integer|nil current, integer|nil total
function spell_sequence_helper:get_progress() end

-- Configuration

---Override the local player resolver for on_spell_cast filtering.
---@param fn fun(): game_object
function spell_sequence_helper:set_local_player_fn(fn) end

---Bind the native C++ module manually (if loaded after require-time).
---@param native_module table
function spell_sequence_helper:bind_native(native_module) end

--------------------------------------------------------------------------------
-- USAGE EXAMPLES
--------------------------------------------------------------------------------
-- local izi = require("common/izi_sdk")
-- local cast_sequence = require("common/utility/spell_sequence_helper")
--
-- -- Enable debug logging:
-- cast_sequence:set_debug(true)            -- native + simple + advanced
-- cast_sequence:set_confirmed_debug(true)  -- confirmed
--
-- -------------------------------------------------------------------
-- -- A into B
-- -------------------------------------------------------------------
-- cast_sequence:a_into_b(
--     SPELLS.BUFF, player, SPELLS.ATTACK, target,
--     0.0, 3.0, "Buff -> Attack", 0.0
-- )
--
-- -------------------------------------------------------------------
-- -- Simple sequence (strict order, one-shot)
-- -------------------------------------------------------------------
-- cast_sequence:simple_sequence(
--     { SPELL_A, SPELL_B, SPELL_C },
--     { target, target, target },
--     0.0, 10.0, "A->B->C", 0.0
-- )
--
-- -------------------------------------------------------------------
-- -- Advanced sequence (priority loop + conditions + fill)
-- -------------------------------------------------------------------
-- -- Entries are scanned top→bottom EVERY FRAME. condition() is re-evaluated
-- -- each frame. First entry where condition=true → try cast_safe.
-- -- When no entry can cast → use fill entries.
-- -- Runs until timeout or cancel().
-- --
-- -- Perfect for dot rotations: "debuff missing" conditions become false
-- -- after cast, true again when dot falls off.
-- cast_sequence:advanced_sequence({
--     { spell = SPELLS.DOT_A, target = T, condition = function() return not T:debuff_up(DOT_A_ID) end },
--     { spell = SPELLS.DOT_B, target = T, condition = function() return not T:debuff_up(DOT_B_ID) end },
-- }, {
--     timeout = 30,
--     debug_name = "Dot Rotation",
--     fill_entries = {
--         { spell = SPELLS.FILLER, target = T, condition = function() return true end },
--     },
--     fill_delay_ms = 150,
-- })
--
-- -------------------------------------------------------------------
-- -- Confirmed sequence (server-confirmed step-by-step)
-- -------------------------------------------------------------------
-- -- Wire once:
-- core.register_on_spell_cast_callback(function(data)
--     cast_sequence:on_spell_cast(data)
-- end)
--
-- cast_sequence:confirmed_sequence({
--     { spell = SPELLS.SHADOWSTEP, target = target, spell_id = 36554 },
--     { spell = SPELLS.AMBUSH,     target = target, spell_id = 11269 },
-- }, { debug_name = "Opener", timeout = 5.0, player = me })
--
-- -------------------------------------------------------------------
-- -- In on_update:
-- -------------------------------------------------------------------
-- cast_sequence:on_update()                 -- advance all sequences
-- if cast_sequence:is_active() then return end  -- any sequence running?
--
-- -------------------------------------------------------------------
-- -- Cancel / state
-- -------------------------------------------------------------------
-- cast_sequence:cancel()            -- cancel native + simple + advanced
-- cast_sequence:cancel_confirmed()  -- cancel confirmed only
-- cast_sequence:cancel_all()        -- cancel everything

---@type spell_sequence_helper
local tbl
return tbl
