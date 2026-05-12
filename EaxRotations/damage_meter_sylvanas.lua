-- Readability notes:
--   What: runtime module.
--   When: loaded by bootstrap or tests when required.
--   Why: keeps related behavior in one auditable file.
--   Safety: use NS helpers, guard nil values, and avoid hot-path allocations.

-- Decision notes:
--   This support module keeps side effects explicit and routes runtime-sensitive work through NS helpers.
--   Comments emphasize intent and constraints so future edits preserve behavior without adding frame-costly checks.
--   When API data is missing, callers should skip unsafe work rather than guessing.
-- ============================================================================
-- EaxRotations - Damage Meter (Project Sylvanas API)
-- Session damage tracking, DPS calculation, combat stats
-- Session damage tracking, DPS calculation, combat stats
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then
    print("[EaxRotations ERROR] Core module not loaded!")
    return
end

-- format removed: unused (no string.format calls in damage_meter)
local floor = math.floor
local time_now = NS.time_now

local PLAYER_UNIT = "player"

local DamageMeter = {
    session_start = 0,
    session_damage = 0,
    session_hits = 0,
    session_start_damage = 0,
    session_start_time = 0,

    realtime_damage = 0,
    realtime_hits = 0,
    realtime_start = 0,
    realtime_buffer = {},

    dps = 0,
    dps_count = 0,
    dps_samples = {},
    max_dps_samples = 20,

    damage_by_type = {
        physical = 0,
        magical = 0,
        holy = 0,
        fire = 0,
        frost = 0,
        shadow = 0,
        nature = 0,
        arcane = 0,
    },

    last_combat_time = 0,
    combat_tracking = false,

    current_damage_event = 0,
}

NS.DamageMeter = DamageMeter

function DamageMeter:StartSession()
    self.session_start = time_now()
    self.session_damage = 0
    self.session_hits = 0
    self.session_start_damage = 0
    self.session_start_time = self.session_start

    self.realtime_damage = 0
    self.realtime_hits = 0
    self.realtime_start = self.session_start

    self.combat_tracking = true

    for k in pairs(self.damage_by_type) do
        self.damage_by_type[k] = 0
    end
end

function DamageMeter:EndSession()
    self.combat_tracking = false
    self:CalculateDPS()
end

function DamageMeter:OnCombatEvent()
    if not self.combat_tracking then return end

    local now = time_now()
    self.last_combat_time = now
    self.realtime_damage = self.realtime_damage + self.current_damage_event
    self.session_damage = self.session_damage + self.current_damage_event
    self.realtime_hits = self.realtime_hits + 1
    self.session_hits = self.session_hits + 1
    self.current_damage_event = 0
end

function DamageMeter:AddDamage(amount, school)
    if not self.combat_tracking then return end

    self.current_damage_event = amount

    if school then
        local school_key = "physical"
        if school == 2 then school_key = "holy"
        elseif school == 4 then school_key = "fire"
        elseif school == 8 then school_key = "nature"
        elseif school == 16 then school_key = "frost"
        elseif school == 32 then school_key = "shadow"
        elseif school == 64 then school_key = "arcane"
        elseif school == 128 then school_key = "magical"
        end
        self.damage_by_type[school_key] = (self.damage_by_type[school_key] or 0) + amount
    end
end

function DamageMeter:CalculateDPS()
    local now = time_now()
    local elapsed = now - self.realtime_start

    if elapsed > 0.5 then
        self.dps = floor(self.realtime_damage / elapsed)
    else
        self.dps = 0
    end

    local session_elapsed = now - self.session_start_time
    if session_elapsed > 0.5 then
        self.dps_count = floor(self.session_damage / session_elapsed)
    else
        self.dps_count = 0
    end
end

function DamageMeter:GetDPS()
    self:CalculateDPS()
    return self.dps
end

function DamageMeter:GetSessionDPS()
    self:CalculateDPS()
    return self.dps_count
end

function DamageMeter:GetTotalDamage()
    return self.session_damage
end

function DamageMeter:GetTotalHits()
    return self.session_hits
end

function DamageMeter:GetAverageHit()
    if self.session_hits > 0 then
        return floor(self.session_damage / self.session_hits)
    end
    return 0
end

function DamageMeter:GetDamageByType()
    return self.damage_by_type
end

function DamageMeter:Reset()
    self.session_damage = 0
    self.session_hits = 0
    self.realtime_damage = 0
    self.realtime_hits = 0
    self.dps = 0
    self.dps_count = 0
    self.session_start = time_now()
    self.realtime_start = time_now()
    self.session_start_time = time_now()
    self.combat_tracking = false

    for k in pairs(self.damage_by_type) do
        self.damage_by_type[k] = 0
    end
end

function DamageMeter:StartCombat()
    if not self.combat_tracking then
        self:StartSession()
    end
end

function DamageMeter:EndCombat()
    if self.combat_tracking then
        self:EndSession()
    end
end

function DamageMeter:GetStats()
    self:CalculateDPS()
    return {
        total_damage = self.session_damage,
        total_hits = self.session_hits,
        dps = self.dps_count,
        avg_hit = self:GetAverageHit(),
        elapsed = time_now() - self.session_start_time,
    }
end

-- [#17] core.register_event does NOT exist in the Sylvanas API.
-- CLEU (COMBAT_LOG_EVENT_UNFILTERED) is never dispatched — the damage meter
-- previously showed zero damage because OnCLEU never fired.
--
-- Migration: Replace CLEU damage detection with:
--   1. NS.register_on_spell_cast: detect spell cast events (limited — no damage amount)
--   2. on_update polling: track combat state, calculate DPS from available data
--
-- NOTE: Without CLEU, the damage meter cannot track exact damage amounts per spell.
-- The spell_cast_callback only tells us a spell was cast, not how much damage it dealt.
-- Full damage tracking requires a CLEU-equivalent API from the Sylvanas runtime.
-- For now, the meter tracks combat time and spell counts as a DPS approximation.

-- Spell cast callback: count spell casts as damage events (approximation)
if NS.register_on_spell_cast then
    NS.register_on_spell_cast(function(spell_id, target)
        if not DamageMeter.combat_tracking then return end
        -- Count spell casts as hits (approximation — no damage amount from callback)
        -- A future CLEU-equivalent API would provide actual damage amounts
        DamageMeter.session_hits = DamageMeter.session_hits + 1
        DamageMeter.realtime_hits = DamageMeter.realtime_hits + 1
        -- Use estimated average hit damage for DPS calculation
        -- This is a rough approximation until CLEU becomes available
        local avg_hit = DamageMeter.session_hits > 0
            and (DamageMeter.session_damage / DamageMeter.session_hits)
            or 0
        if avg_hit > 0 then
            DamageMeter.current_damage_event = avg_hit
            DamageMeter:OnCombatEvent()
        end
    end)
end

if NS.register_on_update_callback then
    NS.register_on_update_callback(function(elapsed)
        -- Combat state tracking
        local me = NS.GetPlayer()
        if me then
            local in_combat = false
            if me.is_in_combat then
                local ok, value = pcall(me.is_in_combat, me)
                in_combat = ok and value == true
            end
            if in_combat and not DamageMeter.combat_tracking then
                DamageMeter:StartCombat()
            elseif not in_combat and DamageMeter.combat_tracking then
                DamageMeter:EndCombat()
            end
        end

        -- DPS recalculation when no recent combat events
        if DamageMeter.combat_tracking then
            local now = time_now()
            if (now - DamageMeter.last_combat_time) > 5 then
                DamageMeter:CalculateDPS()
            end
        end
    end)
end

NS.log("Damage Meter loaded")
return DamageMeter
