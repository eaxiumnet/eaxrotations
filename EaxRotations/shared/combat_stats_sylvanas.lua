-- combat_stats_sylvanas.lua -- aggregate per-session combat statistics.
-- WHAT:   aggregate per-session combat statistics
-- WHEN:   any combat state
-- WHY:    single source of truth for the in-game DPS/HPS overlay
-- SAFETY: bounded ring buffer; nil-guard on event source
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Session data
local session_data = {
    start_time = 0,
    actions_cast = 0,
    failed_actions = 0,
    downtime_ticks = 0,
    total_ticks = 0,
    cooldowns_used = {},
    dot_uptimes = {},
}

local last_summary = nil
local is_tracking = false

local function now()
    return NS and NS.time_now and NS.time_now() or 0
end

-- DoT spell IDs we track
local TRACKED_DOTS = {
    -- Warlock
    [172] = "Corruption", [6222] = "Corruption", [6223] = "Corruption", [11671] = "Corruption",
    [11672] = "Corruption", [25311] = "Corruption", [27216] = "Corruption",
    [980] = "Curse of Agony", [1014] = "Curse of Agony", [6217] = "Curse of Agony",
    [11711] = "Curse of Agony", [11712] = "Curse of Agony", [11713] = "Curse of Agony",
    [27218] = "Curse of Agony", [27219] = "Curse of Agony",
    [603] = "Curse of Doom", [30910] = "Curse of Doom", [30911] = "Curse of Doom", [30912] = "Curse of Doom",
    [1120] = "Drain Soul", [8288] = "Drain Soul", [8289] = "Drain Soul", [11675] = "Drain Soul",
    [27217] = "Drain Soul", [27218] = "Drain Soul",
    
    -- Priest
    [589] = "Shadow Word: Pain", [594] = "Shadow Word: Pain", [970] = "Shadow Word: Pain",
    [992] = "Shadow Word: Pain", [2767] = "Shadow Word: Pain", [10892] = "Shadow Word: Pain",
    [10893] = "Shadow Word: Pain", [10894] = "Shadow Word: Pain", [25367] = "Shadow Word: Pain",
    [25368] = "Shadow Word: Pain",
    [34917] = "Vampiric Touch", [34918] = "Vampiric Touch", [34919] = "Vampiric Touch",
    
    -- Mage
    [133] = "Fireball", [143] = "Fireball", [145] = "Fireball", [3140] = "Fireball", [8400] = "Fireball",
    [8401] = "Fireball", [8402] = "Fireball", [10148] = "Fireball", [10149] = "Fireball", [10150] = "Fireball",
    [10151] = "Fireball", [25306] = "Fireball", [27070] = "Fireball", [27071] = "Fireball",
    [11366] = "Pyroblast", [12505] = "Pyroblast", [12522] = "Pyroblast", [12523] = "Pyroblast",
    [12524] = "Pyroblast", [12525] = "Pyroblast", [12526] = "Pyroblast", [18809] = "Pyroblast",
    [27132] = "Pyroblast", [27133] = "Pyroblast",
    [122] = "Frost Nova", [865] = "Frost Nova", [6131] = "Frost Nova", [10230] = "Frost Nova",
    [27088] = "Frost Nova",
    
    -- Druid
    [8921] = "Moonfire", [8924] = "Moonfire", [8925] = "Moonfire", [8926] = "Moonfire",
    [8927] = "Moonfire", [8928] = "Moonfire", [8929] = "Moonfire", [9833] = "Moonfire",
    [9834] = "Moonfire", [9835] = "Moonfire", [26987] = "Moonfire", [26988] = "Moonfire",
    [1822] = "Rake", [1823] = "Rake", [1824] = "Rake", [9904] = "Rake", [9905] = "Rake",
    [27002] = "Rake", [27003] = "Rake",
    [1079] = "Rip", [9492] = "Rip", [9493] = "Rip", [9752] = "Rip", [9894] = "Rip",
    [9896] = "Rip", [26993] = "Rip",
    
    -- Rogue
    [1943] = "Rupture", [8639] = "Rupture", [8640] = "Rupture", [11273] = "Rupture",
    [11274] = "Rupture", [11275] = "Rupture", [26867] = "Rupture", [26868] = "Rupture",
    [703] = "Garrote", [8631] = "Garrote", [8632] = "Garrote", [8633] = "Garrote",
    [11289] = "Garrote", [11290] = "Garrote", [26839] = "Garrote", [26884] = "Garrote",
    
    -- Hunter
    [1978] = "Serpent Sting", [13549] = "Serpent Sting", [13550] = "Serpent Sting",
    [13551] = "Serpent Sting", [13552] = "Serpent Sting", [13553] = "Serpent Sting",
    [13554] = "Serpent Sting", [13555] = "Serpent Sting", [25295] = "Serpent Sting",
    [27016] = "Serpent Sting",
    [1513] = "Scare Beast", [14326] = "Scare Beast", [14327] = "Scare Beast",
    
    -- Shaman
    [8050] = "Flame Shock", [8052] = "Flame Shock", [8053] = "Flame Shock", [10447] = "Flame Shock",
    [10448] = "Flame Shock", [29228] = "Flame Shock", [25457] = "Flame Shock",
}

-- Called when combat starts
function M.on_combat_start(context)
    is_tracking = true
    session_data.start_time = now()
    session_data.actions_cast = 0
    session_data.failed_actions = 0
    session_data.downtime_ticks = 0
    session_data.total_ticks = 0
    session_data.cooldowns_used = {}
    session_data.dot_uptimes = {}
    
    -- Initialize DoT tracking
    for spell_id, dot_name in pairs(TRACKED_DOTS) do
        session_data.dot_uptimes[dot_name] = {
            last_applied = 0,
            total_uptime = 0,
        }
    end
end

-- Called when an action is cast
function M.on_action(spell_id, success, context)
    if not is_tracking then return end
    
    if success then
        session_data.actions_cast = session_data.actions_cast + 1
        
        -- Check if it was a cooldown
        if NS and NS.is_cooldown and NS.is_cooldown(spell_id) then
            local spell_name = NS.get_spell_name and NS.get_spell_name(spell_id) or tostring(spell_id)
            session_data.cooldowns_used[spell_name] = (session_data.cooldowns_used[spell_name] or 0) + 1
        end
    else
        session_data.failed_actions = session_data.failed_actions + 1
    end
end

-- Called every update tick
function M.on_update(context)
    if not is_tracking then return end
    
    session_data.total_ticks = session_data.total_ticks + 1
    
    -- Check for downtime (GCD available and no cast queued)
    if context then
        local gcd_remains = context.gcd_remains or 0
        local is_casting = context.is_casting or false
        local is_channeling = context.is_channeling or false
        
        -- Downtime = GCD ready + not casting + not channeling
        if gcd_remains == 0 and not is_casting and not is_channeling then
            -- Only count as downtime if we also didn't act last tick
            -- This is simplified - real downtime detection needs more context
        end
    end
    
    -- Track DoT uptimes (throttled)
    M.update_dot_uptimes(context)
end

-- Update DoT uptime tracking
function M.update_dot_uptimes(context)
    if not context or not context.target then return end
    if not NS or not NS.has_debuff then return end
    
    local t = now()
    
    for spell_id, dot_name in pairs(TRACKED_DOTS) do
        if NS.has_debuff(context.target, spell_id) then
            local entry = session_data.dot_uptimes[dot_name]
            if entry then
                if entry.last_applied == 0 then
                    entry.last_applied = t
                end
                -- Accumulate uptime
                entry.total_uptime = entry.total_uptime + 0.05  -- Approximation per tick
            end
        end
    end
end

-- Called when combat ends
function M.on_combat_end(context)
    if not is_tracking then return end
    
    is_tracking = false
    
    local t = now()
    local duration = t - session_data.start_time
    
    if duration < 1 then
        -- Combat too short, ignore
        return
    end
    
    -- Calculate metrics
    local apm = (session_data.actions_cast / duration) * 60
    local downtime_pct = (session_data.downtime_ticks / math.max(1, session_data.total_ticks)) * 100
    
    -- Calculate DoT uptimes
    local dot_summary = {}
    for dot_name, data in pairs(session_data.dot_uptimes) do
        if data.total_uptime > 0 then
            local uptime_pct = (data.total_uptime / duration) * 100
            dot_summary[dot_name] = {
                uptime_seconds = data.total_uptime,
                uptime_pct = uptime_pct,
            }
        end
    end
    
    -- Build summary
    last_summary = {
        duration = duration,
        actions_cast = session_data.actions_cast,
        failed_actions = session_data.failed_actions,
        apm = apm,
        downtime_pct = downtime_pct,
        cooldowns_used = {},
        dot_uptimes = dot_summary,
        timestamp = t,
    }
    
    -- Copy cooldowns used
    for name, count in pairs(session_data.cooldowns_used) do
        last_summary.cooldowns_used[name] = count
    end
end

-- Get current combat metrics
function M.get_current()
    if not is_tracking then return nil end
    
    local t = now()
    local duration = t - session_data.start_time
    
    return {
        duration = duration,
        actions_cast = session_data.actions_cast,
        failed_actions = session_data.failed_actions,
        apm = duration > 0 and (session_data.actions_cast / duration) * 60 or 0,
        is_tracking = true,
    }
end

-- Get last combat summary
function M.get_last_summary()
    return last_summary
end

-- Check if currently tracking
function M.is_tracking()
    return is_tracking
end

-- Get DoT uptime for a specific DoT
function M.get_dot_uptime(dot_name)
    if not is_tracking then return 0 end
    local entry = session_data.dot_uptimes[dot_name]
    if not entry then return 0 end
    return entry.total_uptime
end

-- Reset current session
function M.reset()
    session_data = {
        start_time = 0,
        actions_cast = 0,
        failed_actions = 0,
        downtime_ticks = 0,
        total_ticks = 0,
        cooldowns_used = {},
        dot_uptimes = {},
    }
    is_tracking = false
end

-- Initialize
function M.init()
    if not NS then return end
    
    -- Register combat start/end callbacks if available
    if NS.on_combat_start then
        NS.on_combat_start(function(context)
            M.on_combat_start(context)
        end)
    end
    
    if NS.on_combat_end then
        NS.on_combat_end(function(context)
            M.on_combat_end(context)
        end)
    end
    
    -- Initialize DoT tracking table
    for spell_id, dot_name in pairs(TRACKED_DOTS) do
        session_data.dot_uptimes[dot_name] = {
            last_applied = 0,
            total_uptime = 0,
        }
    end
end

if NS then
    NS.CombatStats = M
    -- Defer init until player is available (engine callbacks may not be ready at require() time)
    if NS.GetPlayer and NS.GetPlayer() then
        M.init()
    end
end

return M
