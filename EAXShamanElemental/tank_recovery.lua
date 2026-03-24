local tank_recovery = {}

local SAFE_DAMAGE_WINDOW = 0.28
local HIGH_DAMAGE_WINDOW = 0.36
local STABLE_THREAT_WINDOW = 0.35
local RECOVERY_COLLAPSE_WINDOW = 0.45

local function clamp01(value)
    local n = tonumber(value) or 0
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function read_snapshot(opts)
    if type(opts) == "table" and type(opts.snapshot) == "table" then
        return opts.snapshot
    end
    if type(opts) == "table" then
        return opts
    end
    return {}
end

local function read_candidates(opts)
    if type(opts) ~= "table" or type(opts.candidates) ~= "table" then
        return {}
    end
    return opts.candidates
end

local function candidate_guid(candidate)
    if type(candidate) ~= "table" then
        return nil
    end
    return candidate.guid or candidate.target_guid or candidate.name
end

local function victim_role_score(candidate)
    local role = type(candidate) == "table" and candidate.victim_role or nil
    if role == "healer" then
        return 50
    end
    if role == "damager" then
        return 36
    end
    if role == "tank" then
        return 12
    end
    return 0
end

local function score_candidate(candidate)
    if type(candidate) ~= "table" then
        return -1
    end

    local score = victim_role_score(candidate)
    if candidate.dangerous_caster == true then
        score = score + 28
    end
    if candidate.interruptible == true then
        score = score + 8
    end
    if candidate.elite == true or candidate.boss == true then
        score = score + 6
    end
    score = score + (clamp01(candidate.cast_progress_pct) * 18)
    return score
end

function tank_recovery.describe_window(snapshot, opts)
    local self_state = (snapshot or {}).self or {}
    local party = (snapshot or {}).party or {}
    local hp_pct = clamp01(self_state.hp_pct)
    local incoming_damage_pct_2s = clamp01(self_state.incoming_damage_pct_2s)
    local incoming_heal_pct = clamp01(self_state.incoming_heal_pct)
    local threat_instability = clamp01(party.threat_instability)
    local collapse_risk = clamp01(party.group_collapse_risk)
    local candidates = read_candidates(opts)

    local self_death_imminent = hp_pct <= 0.20
        or (hp_pct <= 0.35 and incoming_damage_pct_2s >= HIGH_DAMAGE_WINDOW)
    if self_death_imminent then
        return {
            name = "self_death_imminent",
            self_death_imminent = true,
            pressure_rising = true,
            stable = false,
        }
    end

    local pressure_rising = incoming_damage_pct_2s > SAFE_DAMAGE_WINDOW or collapse_risk >= 0.60
    local stable = threat_instability < STABLE_THREAT_WINDOW
        and collapse_risk < RECOVERY_COLLAPSE_WINDOW
        and incoming_damage_pct_2s < SAFE_DAMAGE_WINDOW
        and (#candidates == 0 or pressure_rising == false)
        and hp_pct + incoming_heal_pct >= 0.55

    return {
        name = stable and "stable" or (pressure_rising and "pressure_rising" or "recoverable"),
        self_death_imminent = false,
        pressure_rising = pressure_rising,
        stable = stable,
    }
end

function tank_recovery.should_prioritize_defensive(snapshot, opts)
    local window = tank_recovery.describe_window(snapshot, opts)
    return window.self_death_imminent == true or window.pressure_rising == true
end

function tank_recovery.select_recovery_target(me, opts)
    local snapshot = read_snapshot(opts)
    local window = tank_recovery.describe_window(snapshot, opts)
    local candidates = read_candidates(opts)

    if window.stable or window.self_death_imminent then
        return nil
    end

    local best = nil
    local best_score = -1
    for i = 1, #candidates do
        local candidate = candidates[i]
        local score = score_candidate(candidate)
        if score > best_score and candidate_guid(candidate) then
            best = candidate
            best_score = score
        end
    end

    if not best or best_score <= 0 then
        return nil
    end

    local party = snapshot.party or {}
    if clamp01(party.threat_instability) < STABLE_THREAT_WINDOW and clamp01(party.group_collapse_risk) < RECOVERY_COLLAPSE_WINDOW then
        return nil
    end

    return best
end

return tank_recovery
