-- Shared Helper: DPS Simulator
-- ============================================================================
local M = {}

local floor = math.floor
local max = math.max
local min = math.min

local DEFAULT_DURATION = 60
local GCD = 1.5
local AUTO_STEP = 0.05
local BOSS_HP_FALL_RATE = 100 / DEFAULT_DURATION

local function copy_table(src)
    local dst = {}
    for k, v in pairs(src) do dst[k] = v end
    return dst
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function duration_of(opts, fallback)
    if type(opts) == "number" then return opts end
    if type(opts) == "table" and type(opts.duration) == "number" then return opts.duration end
    return fallback
end

local function get_buff_db()
    local ok, buffs = pcall(require, "common/buff_db")
    if ok and type(buffs) == "table" then return buffs end
    return nil
end

local BUFF_DB = get_buff_db()

local AURAS = {
    battle_shout = { kind = "buff", duration = 120, ids = (BUFF_DB and BUFF_DB.BATTLE_SHOUT) or { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 } },
    hunters_mark = { kind = "debuff", duration = 120, ids = { 14325, 14324, 14323, 1130 } },
    serpent_sting = { kind = "debuff", duration = 15, tick = 3, ids = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 } },
    bestial_wrath = { kind = "buff", duration = 18, ids = { 19574 } },
    rapid_fire = { kind = "buff", duration = 15, ids = { 3045 } },
    aspect_hawk = { kind = "buff", duration = 9999, ids = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 } },
    aspect_viper = { kind = "buff", duration = 9999, ids = { 34074 } },
}

local SPELLS = {
    warrior_arms = {
        mortal_strike = { id = 30330, cooldown = 6, gcd = GCD, rage = 30, base = 520, ap = 0.18, weapon = 1.1, damage_type = "direct" },
        overpower = { id = 11585, cooldown = 0, gcd = GCD, rage = 5, base = 360, ap = 0.16, weapon = 0.9, damage_type = "direct", proc_window = 5 },
        execute = { id = 25236, cooldown = 0, gcd = GCD, rage = 15, base = 430, ap = 0.24, weapon = 1.35, damage_type = "direct" },
        heroic_strike = { id = 30324, cooldown = 0, gcd = 0, rage = 15, base = 170, ap = 0.11, weapon = 0.55, damage_type = "on_swing" },
        auto_attack = { speed = 3.6, base = 200, ap = 0.14, weapon = 1.0, rage = 12 },
    },
    hunter_beast_mastery = {
        hunters_mark = { id = 14325, cooldown = 0, gcd = GCD, mana = 3, aura = "hunters_mark", damage_type = "debuff" },
        serpent_sting = { id = 27016, cooldown = 0, gcd = GCD, mana = 8, aura = "serpent_sting", duration = 15, tick = 3, base_tick = 110, rap = 0.08, damage_type = "dot" },
        bestial_wrath = { id = 19574, cooldown = 120, gcd = 0, aura = "bestial_wrath", damage_type = "buff" },
        rapid_fire = { id = 3045, cooldown = 300, gcd = 0, aura = "rapid_fire", damage_type = "buff" },
        kill_command = { id = 34026, cooldown = 5, gcd = 0, mana = 5, base = 250, rap = 0.12, damage_type = "direct" },
        multi_shot = { id = 27021, cooldown = 10, gcd = GCD, mana = 12, base = 340, rap = 0.12, damage_type = "direct", requires_two_targets = true },
        steady_shot = { id = 34120, cooldown = 0, gcd = GCD, cast = 1.5, mana = 7, base = 160, rap = 0.22, damage_type = "direct" },
        arcane_shot = { id = 27019, cooldown = 6, gcd = GCD, mana = 8, base = 350, rap = 0.15, damage_type = "direct" },
        auto_attack = { speed = 2.8, base = 140, rap = 0.12, mana = 0 },
    },
}

local PROFILES = {
    warrior_arms = {
        class = "warrior",
        playstyle = "arms",
        spell_set = "warrior_arms",
        display_name = "Warrior Arms",
        summary_buffs = { "battle_shout" },
        summary_debuffs = {},
        burst_window = nil,
        target_hp_floor = 20,
        rotation = function(state, t)
            if state.target_hp_pct <= 20 and state.cooldown.execute <= 0 and state.rage >= 15 then
                return "execute"
            end
            if state.cooldown.overpower <= 0 and state.rage >= 5 and state.overpower_proc_until >= t then
                return "overpower"
            end
            if state.cooldown.mortal_strike <= 0 and state.rage >= 30 then
                return "mortal_strike"
            end
            if state.rage >= 45 then
                return "heroic_strike"
            end
            return nil
        end,
        apply_spells = {
            battle_shout = { aura = "battle_shout" },
        },
    },
    hunter_beast_mastery = {
        class = "hunter",
        playstyle = "beast_mastery",
        spell_set = "hunter_beast_mastery",
        display_name = "Hunter Beast Mastery",
        summary_buffs = { "bestial_wrath", "rapid_fire", "aspect_hawk", "aspect_viper" },
        summary_debuffs = { "hunters_mark", "serpent_sting" },
        burst_window = 10,
        target_hp_floor = 20,
        rotation = function(state, t)
            if not state.aura.hunters_mark and state.mana >= 3 then
                return "hunters_mark"
            end
            if not state.aura.serpent_sting and state.mana >= 8 then
                return "serpent_sting"
            end
            if state.cooldown.bestial_wrath <= 0 and state.cooldown.rapid_fire <= 0 then
                return "bestial_wrath"
            end
            if state.cooldown.bestial_wrath <= 10 and state.cooldown.rapid_fire <= 0 then
                return "rapid_fire"
            end
            if state.mana <= 10 and not state.aura.aspect_viper then
                return "aspect_viper"
            end
            if state.mana >= 50 and state.aura.aspect_viper then
                return "aspect_hawk"
            end
            if state.cooldown.kill_command <= 0 then
                return "kill_command"
            end
            if state.enemy_count >= 2 and state.cooldown.multi_shot <= 0 then
                return "multi_shot"
            end
            if state.can_steady then
                return "steady_shot"
            end
            if state.cooldown.arcane_shot <= 0 then
                return "arcane_shot"
            end
            return nil
        end,
        apply_spells = {
            hunters_mark = { aura = "hunters_mark" },
            serpent_sting = { aura = "serpent_sting", dot = true },
            bestial_wrath = { aura = "bestial_wrath" },
            rapid_fire = { aura = "rapid_fire" },
            aspect_hawk = { aura = "aspect_hawk" },
            aspect_viper = { aura = "aspect_viper" },
        },
    },
}

local function profile_key(name)
    if name == "arms" or name == "warrior_arms" then return "warrior_arms" end
    if name == "beast_mastery" or name == "hunter_beast_mastery" then return "hunter_beast_mastery" end
    return name
end

local function make_state(profile, opts, duration)
    return {
        profile = profile,
        duration = duration,
        ap = opts.ap or (profile.class == "warrior" and 1500 or 1800),
        mana = opts.mana or 100,
        rage = opts.rage or 0,
        enemy_count = opts.enemy_count or 1,
        target_hp_pct = 100,
        gcd_ready = 0,
        next_auto = 0,
        auto_speed = opts.auto_speed or SPELLS[profile.spell_set].auto_attack.speed,
        cooldown = {
            mortal_strike = 0,
            overpower = 0,
            execute = 0,
            heroic_strike = 0,
            hunters_mark = 0,
            serpent_sting = 0,
            bestial_wrath = 0,
            rapid_fire = 0,
            kill_command = 0,
            multi_shot = 0,
            steady_shot = 0,
            arcane_shot = 0,
        },
        aura = {
            battle_shout = false,
            hunters_mark = false,
            serpent_sting = false,
            bestial_wrath = false,
            rapid_fire = false,
            aspect_hawk = true,
            aspect_viper = false,
        },
        aura_until = {},
        aura_uptime = {},
        dot_next_tick = {},
        damage = 0,
        healing = 0,
        casts = 0,
        wasted_cd = 0,
        cooldown_alignment = 0,
        overpower_proc_until = 0,
        last_attack_time = 0,
        can_steady = true,
    }
end

local function init_uptime(state)
    for k in pairs(state.aura) do
        state.aura_uptime[k] = 0
        state.aura_until[k] = state.aura[k] and 1e9 or 0
    end
end

local function aura_active(state, name, t)
    local until_t = state.aura_until[name] or 0
    return until_t > t
end

local function refresh_aura(state, name, duration, t)
    state.aura[name] = true
    state.aura_until[name] = t + duration
    if AURAS[name] and AURAS[name].tick then
        state.dot_next_tick[name] = t + AURAS[name].tick
    end
end

local function expire_aura(state, name)
    state.aura[name] = false
    state.aura_until[name] = 0
    state.dot_next_tick[name] = nil
end

local function add_uptime(state, dt, t)
    for name, active in pairs(state.aura) do
        if active and (state.aura_until[name] or 0) > t then
            state.aura_uptime[name] = (state.aura_uptime[name] or 0) + dt
        elseif active and (state.aura_until[name] or 0) <= t then
            expire_aura(state, name)
        end
    end
end

local function auto_damage(profile, state)
    local spell = SPELLS[profile.spell_set].auto_attack
    local coeff = spell.ap or spell.rap or 0
    local dmg = spell.base + (state.ap * coeff) + (state.ap * (spell.weapon or 0) * 0.25)
    return dmg
end

local function cast_damage(spell, state, profile)
    local dmg = spell.base or 0
    dmg = dmg + (state.ap * (spell.ap or spell.rap or 0))
    dmg = dmg + (state.ap * (spell.weapon or 0) * 0.25)
    if state.aura.bestial_wrath and profile.playstyle == "beast_mastery" and spell.damage_type == "direct" then
        dmg = dmg * 1.4
    end
    return dmg
end

local function spend_resource(state, spell)
    if spell.rage then state.rage = max(0, state.rage - spell.rage) end
    if spell.mana then state.mana = max(0, state.mana - spell.mana) end
end

local function regen_resources(state, dt, profile)
    if profile.class == "warrior" then
        state.rage = clamp(state.rage + (2.2 * dt), 0, 100)
    else
        local regen = state.aura.aspect_viper and 18 or 8
        state.mana = clamp(state.mana + (regen * dt), 0, 100)
    end
end

local function update_cooldowns(state, dt)
    for k, v in pairs(state.cooldown) do
        state.cooldown[k] = max(0, v - dt)
    end
end

local function schedule_cast(state, profile, action_name, t)
    local spells = SPELLS[profile.spell_set]
    local spell = spells[action_name]
    if not spell then return false end

    local ready_at = state.cooldown[action_name] or 0
    if ready_at > t then
        state.wasted_cd = state.wasted_cd + (ready_at - t)
    end

    state.casts = state.casts + 1
    spend_resource(state, spell)

    if action_name == "mortal_strike" then
        state.damage = state.damage + cast_damage(spell, state, profile)
        state.cooldown.mortal_strike = t + spell.cooldown
        state.gcd_ready = t + spell.gcd
    elseif action_name == "overpower" then
        state.damage = state.damage + cast_damage(spell, state, profile)
        state.cooldown.overpower = t + 5
        state.gcd_ready = t + spell.gcd
        state.overpower_proc_until = 0
    elseif action_name == "execute" then
        local hp_bonus = 1 + ((20 - state.target_hp_pct) / 40)
        state.damage = state.damage + cast_damage(spell, state, profile) * hp_bonus
        state.gcd_ready = t + spell.gcd
    elseif action_name == "heroic_strike" then
        state.damage = state.damage + cast_damage(spell, state, profile)
        state.gcd_ready = t + 0
    elseif action_name == "hunters_mark" then
        refresh_aura(state, "hunters_mark", AURAS.hunters_mark.duration, t)
        state.gcd_ready = t + spell.gcd
    elseif action_name == "serpent_sting" then
        refresh_aura(state, "serpent_sting", AURAS.serpent_sting.duration, t)
        state.gcd_ready = t + spell.gcd
        state.cooldown.serpent_sting = t + 15
    elseif action_name == "bestial_wrath" then
        refresh_aura(state, "bestial_wrath", AURAS.bestial_wrath.duration, t)
        state.cooldown.bestial_wrath = t + spell.cooldown
        state.gcd_ready = t + 0
    elseif action_name == "rapid_fire" then
        refresh_aura(state, "rapid_fire", AURAS.rapid_fire.duration, t)
        state.cooldown.rapid_fire = t + spell.cooldown
        state.gcd_ready = t + 0
    elseif action_name == "kill_command" then
        state.damage = state.damage + cast_damage(spell, state, profile)
        state.cooldown.kill_command = t + spell.cooldown
        state.gcd_ready = t + 0
    elseif action_name == "multi_shot" then
        state.damage = state.damage + cast_damage(spell, state, profile)
        state.cooldown.multi_shot = t + spell.cooldown
        state.gcd_ready = t + spell.gcd
    elseif action_name == "steady_shot" then
        state.damage = state.damage + cast_damage(spell, state, profile)
        state.cooldown.steady_shot = t + spell.cast
        state.gcd_ready = t + spell.gcd
    elseif action_name == "arcane_shot" then
        state.damage = state.damage + cast_damage(spell, state, profile)
        state.cooldown.arcane_shot = t + spell.cooldown
        state.gcd_ready = t + spell.gcd
    elseif action_name == "aspect_viper" then
        state.aura.aspect_viper = true
        state.aura.aspect_hawk = false
        state.aura_until.aspect_viper = 1e9
        state.aura_until.aspect_hawk = 0
        state.gcd_ready = t + 0
    elseif action_name == "aspect_hawk" then
        state.aura.aspect_viper = false
        state.aura.aspect_hawk = true
        state.aura_until.aspect_viper = 0
        state.aura_until.aspect_hawk = 1e9
        state.gcd_ready = t + 0
    end

    return true
end

local function maybe_apply_proc(state, t, profile)
    if profile.playstyle ~= "warrior_arms" then return end
    if t >= state.overpower_proc_until then
        state.overpower_proc_until = t + 10
    end
end

local function maintain_auras(state, profile, t)
    if profile.playstyle == "warrior_arms" and not aura_active(state, "battle_shout", t) then
        refresh_aura(state, "battle_shout", AURAS.battle_shout.duration, t)
    end

    if profile.playstyle == "hunter_beast_mastery" then
        if not aura_active(state, "aspect_hawk", t) and not aura_active(state, "aspect_viper", t) then
            refresh_aura(state, "aspect_hawk", AURAS.aspect_hawk.duration, t)
        end
    end
end

local function advance_to_next_event(state, t, duration)
    local next_event = duration
    next_event = min(next_event, state.gcd_ready)
    next_event = min(next_event, state.next_auto)
    for _, cd in pairs(state.cooldown) do
        next_event = min(next_event, cd)
    end
    for _, until_t in pairs(state.aura_until) do
        if until_t > t then next_event = min(next_event, until_t) end
    end
    if next_event <= t then
        return min(duration, t + AUTO_STEP)
    end
    return min(duration, next_event)
end

local function finalize_auras(state, duration)
    for name, active in pairs(state.aura) do
        if active then
            local until_t = state.aura_until[name] or duration
            local uptime = min(until_t, duration)
            if uptime > 0 then
                state.aura_uptime[name] = (state.aura_uptime[name] or 0) + uptime
            end
        end
    end
end

local function build_summary(state, profile, duration)
    local summary = {
        playstyle = profile.playstyle,
        display_name = profile.display_name,
        duration = duration,
        total_casts = state.casts,
        average_dps = state.damage / duration,
        average_hps = state.healing / duration,
        wasted_cooldown_time = state.wasted_cd,
        cooldown_alignment = state.cooldown_alignment,
        uptime_pct = {},
        damage = state.damage,
        healing = state.healing,
    }

    for _, aura_name in ipairs(profile.summary_buffs or {}) do
        local up = state.aura_uptime[aura_name] or 0
        summary.uptime_pct[aura_name] = (up / duration) * 100
    end
    for _, aura_name in ipairs(profile.summary_debuffs or {}) do
        local up = state.aura_uptime[aura_name] or 0
        summary.uptime_pct[aura_name] = (up / duration) * 100
    end

    return summary
end

local function simulate_once(playstyle_name, opts)
    local key = profile_key(playstyle_name)
    local profile = PROFILES[key]
    if not profile then
        return nil, "unknown playstyle: " .. tostring(playstyle_name)
    end

    local duration = duration_of(opts, DEFAULT_DURATION)
    if duration <= 0 then duration = DEFAULT_DURATION end

    local options = type(opts) == "table" and opts or {}
    local state = make_state(profile, options, duration)
    init_uptime(state)

    local t = 0
    state.next_auto = state.auto_speed

    while t < duration do
        local dt = min(AUTO_STEP, duration - t)
        maintain_auras(state, profile, t)

        state.target_hp_pct = clamp(100 - (t * BOSS_HP_FALL_RATE), 0, 100)
        maybe_apply_proc(state, t, profile)

        if t >= state.next_auto - 0.0001 then
            state.damage = state.damage + auto_damage(profile, state)
            if profile.class == "warrior" then
                state.rage = clamp(state.rage + SPELLS.warrior_arms.auto_attack.rage, 0, 100)
                if state.rage >= 40 and state.cooldown.overpower <= 0 then
                    state.overpower_proc_until = t + 5
                end
            end
            state.next_auto = t + state.auto_speed
        end

        if state.gcd_ready <= t then
            local action = profile.rotation(state, t)
            if action then
                if action == "bestial_wrath" and profile.burst_window then
                    local rf_ready = state.cooldown.rapid_fire or 0
                    if rf_ready > t and rf_ready - t <= profile.burst_window then
                        state.wasted_cd = state.wasted_cd + (rf_ready - t)
                    end
                elseif action == "rapid_fire" and profile.burst_window then
                    local bw_ready = state.cooldown.bestial_wrath or 0
                    if bw_ready > t and bw_ready - t <= profile.burst_window then
                        state.wasted_cd = state.wasted_cd + (bw_ready - t)
                    end
                end
                schedule_cast(state, profile, action, t)
            end
        end

        add_uptime(state, dt, t)
        regen_resources(state, dt, profile)
        update_cooldowns(state, dt)
        t = advance_to_next_event(state, t + dt, duration)
    end

    finalize_auras(state, duration)

    if profile.playstyle == "hunter_beast_mastery" then
        state.cooldown_alignment = min(state.aura_uptime.bestial_wrath or 0, state.aura_uptime.rapid_fire or 0)
    end

    return build_summary(state, profile, duration), state
end

function M.simulate(playstyle_name, opts)
    local summary, state_or_err = simulate_once(playstyle_name, opts)
    if not summary then return nil, state_or_err end
    return summary, state_or_err
end

local function delta_map(a, b)
    local out = {}
    for k, v in pairs(b) do
        if type(v) == "number" then
            out[k] = v - (type(a[k]) == "number" and a[k] or 0)
        end
    end
    return out
end

function M.compare(playstyle_a, playstyle_b, opts)
    local summary_a, err_a = simulate_once(playstyle_a, opts)
    if not summary_a then return nil, err_a end
    local summary_b, err_b = simulate_once(playstyle_b, opts)
    if not summary_b then return nil, err_b end

    local report = {
        playstyle_a = summary_a.playstyle,
        playstyle_b = summary_b.playstyle,
        duration = summary_a.duration,
        a = summary_a,
        b = summary_b,
        delta = {
            average_dps = summary_b.average_dps - summary_a.average_dps,
            average_hps = summary_b.average_hps - summary_a.average_hps,
            total_casts = summary_b.total_casts - summary_a.total_casts,
            wasted_cooldown_time = summary_b.wasted_cooldown_time - summary_a.wasted_cooldown_time,
            cooldown_alignment = summary_b.cooldown_alignment - summary_a.cooldown_alignment,
            uptime_pct = delta_map(summary_a.uptime_pct, summary_b.uptime_pct),
        },
    }

    return report, summary_a, summary_b
end

function M.get_profiles()
    return copy_table(PROFILES)
end

return M
