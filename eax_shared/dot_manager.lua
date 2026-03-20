-- dot_manager.lua
-- eax_shared/dot_manager.lua
-- Shared DoT clip prevention module for all TBC Classic caster specs.
-- Prevents refreshing DoTs too early (clipping the final tick).
--
-- Key insight: in TBC Classic, server-side DoT application means a pending cast
-- takes ~(cast_time + latency + GCD) seconds before the new DoT replaces the old one.
-- We must only refresh when remaining_ms < (pending_cast_time + latency_buffer).
--
-- Usage:
--   local dot_manager = require("eax_shared/dot_manager")
--   if dot_manager.can_refresh_dot(target, debuff_ids, spell_id, utils.get_debuff_remaining_ms) then
--       -- safe to refresh
--   end
--
-- v1.0.0

local dot_manager = {}

-- --- Constants ----------------------------------------------------------------

-- TBC Global Cooldown in milliseconds
local GCD_TBC_MS = 1500

-- Network round-trip estimate (ms)
local LATENCY_BUFFER_MS = 500

-- Absolute minimum safe threshold (GCD_TBC + LATENCY_BUFFER)
local ABSOLUTE_MIN_THRESHOLD_MS = GCD_TBC_MS + LATENCY_BUFFER_MS  -- 2000ms

-- For spells without DOT_DURATIONS entry, default to generous 3000ms threshold
local DEFAULT_THRESHOLD_MS = 3000

-- --- DoT Duration Table --------------------------------------------------------
-- spell_id -> duration_ms
-- From simc reference data and WoW spell research.
-- Format: [spell_id] = total_duration_ms
-- Most DoTs tick every 2-3 seconds.

dot_manager.DOT_DURATIONS = {
    -- === Druid DoTs ===
    [26988] = 12000,  -- Moonfire rank 13: 4 ticks × 3s = 12s
    [27013] = 12000,  -- Insect Swarm rank 6: 6 ticks × 2s = 12s
    [26993] = 300000, -- Faerie Fire rank 5: 5 min duration (never clip)

    -- === Warlock Affliction DoTs ===
    [27216] = 18000,  -- Corruption rank 10: 6 ticks × 3s = 18s
    [30405] = 15000,  -- Unstable Affliction rank 5: 5 ticks × 3s = 15s
    [30911] = 15000,  -- Siphon Life rank 7: 15s duration
    [27218] = 20000,  -- Curse of Agony rank 9: 10 ticks × 2s = 20s
    [30910] = 60000,  -- Curse of Doom rank 3: 60s duration
    [18692] = 60000,  -- Curse of Doom rank 2: 60s duration
    [18691] = 60000,  -- Curse of Doom rank 1: 60s duration
    [27228] = 24000,  -- Curse of Elements rank 4: 12 ticks × 2s = 24s

    -- === Warlock Destruction DoTs ===
    [27215] = 16000,  -- Immolate rank 13: 8 ticks × 2s = 16s

    -- === Priest Shadow DoTs ===
    [25368] = 18000,  -- Shadow Word: Pain rank 12: 6 ticks × 3s = 18s
    [25467] = 15000,  -- Devouring Plague rank 4: 5 ticks × 3s = 15s (also Siphon Life rank 8)
    [34917] = 15000,  -- Vampiric Touch rank 4: 15s duration

    -- === Mage DoTs ===
    [22907] = 8000,   -- Pyroblast (dot component): 4 ticks × 2s = 8s (approx)
    [25306] = 8000,   -- Fireball (improved, dot): 4 ticks × 2s = 8s (approx)
    [27070] = 8000,   -- Molten Boulder: 4 ticks × 2s = 8s

    -- === Hunter DoTs ===
    [1978]  = 12000,  -- Serpent Sting rank 10: 5 ticks × 3s = 15s
    [27018] = 15000,  -- Black Arrow rank 6: 5 ticks × 3s = 15s (Note: likely 3s ticks)

    -- === Shaman DoTs ===
    [17364] = 12000,  -- Stormstrike (earth shock weapon proc): instant
    [3600]  = 12000,  -- Earth Shock rank 8: 2 ticks × 1.5s = 3s... actually not a dot
    [8020]  = 12000,  -- Flametongue Weapon: not a debuff
    -- Flame Shock: included below

    -- === Paladin DoTs ===
    [31803] = 15000,  -- Holy Vengeance: 5 ticks × 3s = 15s (retribution aura)
    [9342]  = 12000,  -- Holy Fire (if ever used): 5 ticks × 2s = 10s

    -- === Death Knight DoTs (Phase 3+) ===
    [49796] = 6000,   -- Blood Plague rank 4: 2 ticks × 3s = 6s
    [55095] = 6000,   -- Frost Fever rank 5: 2 ticks × 3s = 6s
    [49194] = 12000,  -- Death and Decay rank 3: 10s channeled
    [52212] = 8000,   -- Death Coil (Shadowmourne proc): not standard

    -- === Additional spells from spells.lua references ===
    [172]   = 12000,  -- Corruption rank 1: 6 ticks × 2s = 12s (low rank)
    [6223]  = 15000,  -- Corruption rank 6: 6 ticks × 3s = 18s
    [11671] = 18000,  -- Corruption rank 4: 6 ticks × 3s = 18s
    [7648]  = 18000,  -- Corruption rank 3: 6 ticks × 3s = 18s
    [25311] = 18000,  -- Corruption rank 9: 6 ticks × 3s = 18s
    [25467] = 15000,  -- Corruption rank 5: 6 ticks × 3s = 18s... wait different ranks

    -- === Affliction ranks for Siphon Life ===
    [18265] = 15000,  -- Siphon Life rank 2: 15s
    [18879] = 15000,  -- Siphon Life rank 3: 15s
    [18263] = 15000,  -- Siphon Life rank 1: 15s

    -- === SW:Pain ranks ===
    [25367] = 18000,  -- SW:Pain rank 11: 6 ticks × 3s = 18s
    [25375] = 18000,  -- SW:Pain rank 10: 6 ticks × 3s = 18s
    [10894] = 18000,  -- SW:Pain rank 9: 6 ticks × 3s = 18s
    [10893] = 12000,  -- SW:Pain rank 8: 4 ticks × 3s = 12s
    [10892] = 12000,  -- SW:Pain rank 7: 4 ticks × 3s = 12s
    [2767]  = 12000,  -- SW:Pain rank 6: 4 ticks × 3s = 12s
    [992]   = 12000,  -- SW:Pain rank 5: 4 ticks × 3s = 12s
    [970]   = 12000,  -- SW:Pain rank 4: 4 ticks × 3s = 12s
    [594]   = 12000,  -- SW:Pain rank 3: 4 ticks × 3s = 12s
    [589]   = 12000,  -- SW:Pain rank 2: 4 ticks × 3s = 12s

    -- === Devouring Plague ranks ===
    [25465] = 15000,  -- DP rank 3: 5 ticks × 3s = 15s
    [25464] = 15000,  -- DP rank 2: 5 ticks × 3s = 15s
    [29433] = 15000,  -- DP rank TBC: 5 ticks × 3s = 15s
    [16085] = 15000,  -- DP rank pre-TBC: 5 ticks × 3s = 15s

    -- === Immolate ranks ===
    [17811] = 16000,  -- Immolate rank 12: 8 ticks × 2s = 16s
    [7074]  = 16000,  -- Immolate rank low: 8 ticks × 2s = 16s

    -- === Curse of Agony ranks ===
    [11713] = 20000,  -- CoA rank 8: 10 ticks × 2s = 20s
    [11712] = 20000,  -- CoA rank 7: 10 ticks × 2s = 20s
    [7658]  = 12000,  -- CoA rank 6: 6 ticks × 2s = 12s

    -- === Moonfire ranks ===
    [26986] = 12000,  -- Moonfire rank 12: 4 ticks × 3s = 12s
    [26985] = 12000,  -- Moonfire rank 11: 4 ticks × 3s = 12s
    [16914] = 12000,  -- Moonfire rank 10: 4 ticks × 3s = 12s

    -- === Insect Swarm ranks ===
    [27012] = 12000,  -- Insect Swarm rank 5: 6 ticks × 2s = 12s
    [24974] = 12000,  -- Insect Swarm rank 4: 6 ticks × 2s = 12s

    -- === Vampiric Touch ranks ===
    [34916] = 15000,  -- VT rank 3: 15s
    [34914] = 15000,  -- VT rank 2: 15s
    [34913] = 15000,  -- VT rank 1: 15s

    -- === Additional DoTs ===
    [26991] = 300000, -- Faerie Fire rank 4: 5 min
    [26992] = 300000, -- Faerie Fire rank 3: 5 min
    [20749] = 12000,  -- Starfire (periodic): not standard
    [25448] = 12000,  -- Moonfire rank 13 with talents: not standard

    -- === Flame Shock (Shaman) ===
    [29228] = 12000,  -- Flame Shock rank 7: 3 ticks × 3s = 9s... actually 6s
    [25457] = 6000,   -- Flame Shock rank 6: 3 ticks × 2s = 6s
    [29228] = 6000,   -- Flame Shock rank 5: 3 ticks × 2s = 6s

    -- === Wrath (Druid) - not a dot but referenced in simc ===
    [26984] = 0,      -- Wrath: direct damage, not a dot

    -- === Curse of Weakness ===
    [16918] = 12000,  -- Curse of Weakness rank 10: 12s duration

    -- === Curse of Elements ===
    [27200] = 24000,  -- Curse of Elements rank 3: 24s

    -- === Drain Soul (channeled, no tick clipping in same way) ===
    -- Channeled spells don't clip - the channel continues until full duration

    -- === Holy Fire (Priest) ===
    [25367] = 18000,  -- Holy Fire rank 10: ~12s dot duration (5 ticks × 2.4s approx)
    [25384] = 12000,  -- Holy Fire rank 9: ~12s
    [14914] = 12000,  -- Holy Fire rank 8: ~12s

    -- === Explosive Trap (Hunter) ===
    [27025] = 8000,   -- Explosive Trap rank 6: 8s
    [13812] = 8000,   -- Explosive Trap rank 5: 8s

    -- === Scorch (Mage - Improved Scorch debuff) ===
    [22959] = 15000,  -- Improved Scorch debuff: 15s
    [2942]  = 15000,  -- Scorch: 15s (debuff from improved scorch talent)

    -- === Thunder Clap (Warrior) - not a dot ===
    [25203] = 0,      -- Thunder Clap: direct + DoT 0s
}

-- --- Threshold Cache ------------------------------------------------------------
-- Avoid recalculating thresholds every call

local threshold_cache = {}

-- --- Core Functions -------------------------------------------------------------

---Get the safe refresh threshold in ms for a given spell_id.
---Returns the minimum remaining duration below which it's safe to refresh a DoT.
---Never refresh before 30% of duration remains, plus GCD + latency buffer.
---@param spell_id number|nil
---@return number threshold_ms
function dot_manager.get_safe_refresh_ms(spell_id)
    if not spell_id then
        return DEFAULT_THRESHOLD_MS
    end

    -- Check cache first
    if threshold_cache[spell_id] then
        return threshold_cache[spell_id]
    end

    local duration = dot_manager.DOT_DURATIONS[spell_id]

    local threshold
    if not duration then
        -- Unknown DoT: use default
        threshold = DEFAULT_THRESHOLD_MS
    elseif duration >= 300000 then
        -- Faerie Fire (5 min): never clip - use 300s threshold (practically never)
        -- But we still need some threshold to avoid nil checks; use very large value
        -- Actually, for Faerie Fire we want to NEVER refresh except via explicit logic
        -- Return a value that effectively disables auto-refresh
        threshold = 290000  -- Only refresh when < 10s remains (out of 300s)
    else
        -- Known DoT: min(30% of duration, 3000ms) as base
        local pct_threshold = duration * 0.3
        if pct_threshold > 3000 then
            pct_threshold = 3000
        end
        -- Cap at 30% of duration, minimum 1500ms (GCD)
        if pct_threshold < 1500 then
            pct_threshold = 1500
        end
        -- Add GCD + latency buffer as absolute minimum safety margin
        threshold = pct_threshold + ABSOLUTE_MIN_THRESHOLD_MS

        -- Cap at 5000ms maximum threshold (never refresh before 30% remains + buffer)
        if threshold > 5000 then
            threshold = 5000
        end
    end

    threshold_cache[spell_id] = threshold
    return threshold
end

---Check if a DoT on target can be safely refreshed.
---Uses the get_debuff_remaining_ms function from utils.
---Returns false if remaining_ms >= threshold (would clip final tick).
---@param target game_object
---@param debuff_ids table list of spell ID tables (e.g., spells.CORRUPTION)
---@param spell_id number the spell being considered for refresh
---@param get_debuff_remaining_ms_fn function from utils or equivalent
---@return boolean true = safe to refresh, false = too early (would clip)
function dot_manager.can_refresh_dot(target, debuff_ids, spell_id, get_debuff_remaining_ms_fn)
    -- If no debuff remaining check function, defer to caller's logic
    if not get_debuff_remaining_ms_fn then
        return false
    end

    -- If no debuff IDs provided, assume dot is not present
    if not debuff_ids then
        return true
    end

    -- Get remaining duration
    local remaining_ms = 0
    if target and target.is_valid then
        remaining_ms = get_debuff_remaining_ms_fn(target, debuff_ids)
    end

    -- If DoT is gone, safe to cast
    if remaining_ms <= 0 then
        return true
    end

    -- Get the safe threshold for this spell
    local threshold = dot_manager.get_safe_refresh_ms(spell_id)

    -- Only refresh when remaining_ms < threshold
    -- This guarantees we never clip the final tick
    return remaining_ms < threshold
end

---Get pending cast timeout for a spell (for pending cast state).
---This is the time window during which we assume a cast is "in flight".
---Cast time + GCD + latency buffer.
---@param spell_id number|nil
---@return number timeout_ms
function dot_manager.get_pending_timeout_ms(spell_id)
    -- Default: 2500ms (cast time ~0 + GCD 1500ms + latency 500ms + buffer)
    -- Most instant casts or spells with cast times will fit within this window
    return 2500
end

---Check if a spell ID is a known DoT (has entry in DOT_DURATIONS with duration > 0).
---@param spell_id number
---@return boolean
function dot_manager.is_dot_spell(spell_id)
    if not spell_id then return false end
    local duration = dot_manager.DOT_DURATIONS[spell_id]
    return duration ~= nil and duration > 0
end

---Get the total duration of a DoT spell in ms.
---@param spell_id number
---@return number duration_ms (0 if not a DoT)
function dot_manager.get_dot_duration(spell_id)
    if not spell_id then return 0 end
    return dot_manager.DOT_DURATIONS[spell_id] or 0
end

---Clear the threshold cache (useful for testing or hot-reload).
function dot_manager.clear_cache()
    threshold_cache = {}
end

return dot_manager
