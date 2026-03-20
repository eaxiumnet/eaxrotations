local combat_context = {}

local function default_now(deps)
    if deps and type(deps.now_s) == "function" then
        local ok, value = pcall(deps.now_s)
        if ok and type(value) == "number" then
            return value
        end
    end

    if core and type(core.time) == "function" then
        local ok, value = pcall(core.time)
        if ok and type(value) == "number" then
            return value
        end
    end

    return 0
end

local function call_or_nil(fn, ...)
    if type(fn) ~= "function" then
        return nil, false
    end

    local ok, value = pcall(fn, ...)
    if not ok then
        return nil, false
    end

    return value, true
end

local function as_number(value)
    local n = tonumber(value)
    if not n or n < 0 then
        return 0
    end
    return n
end

local function ratio(current, maximum)
    local max_value = as_number(maximum)
    if max_value <= 0 then
        return 0, false
    end
    return math.min(as_number(current) / max_value, 1), true
end

local function normalize_role(role_id)
    local mapped = {
        [0] = "tank",
        [1] = "healer",
        [2] = "damager",
    }
    return mapped[role_id] or "unknown"
end

local function copy_fields(source, defaults)
    local out = {}
    for key, value in pairs(defaults) do
        out[key] = value
    end
    if type(source) == "table" then
        for key, value in pairs(source) do
            if out[key] ~= nil then
                out[key] = value
            end
        end
    end
    return out
end

local function clamp01(value)
    return math.max(0, math.min(as_number(value), 1))
end

local function same_unit(a, b)
    if a ~= nil and a == b then
        return true
    end

    if type(a) == "table" and type(b) == "table"
        and type(a.get_guid) == "function" and type(b.get_guid) == "function" then
        local a_guid = call_or_nil(a.get_guid, a)
        local b_guid = call_or_nil(b.get_guid, b)
        return a_guid ~= nil and a_guid == b_guid
    end

    return false
end

local function cast_progress_pct(unit)
    local progress, ok = call_or_nil(unit.get_channeling_or_casting_pct, unit)
    if ok then
        return math.min(as_number(progress) / 100, 1), true
    end

    progress, ok = call_or_nil(unit.get_cast_pct, unit)
    if ok then
        return math.min(as_number(progress) / 100, 1), true
    end

    return 0, false
end

local function normalize_party_member(member)
    if type(member) ~= "table" then
        return nil
    end

    return {
        guid = member.guid,
        unit = member.unit,
        hp_pct = clamp01(member.hp_pct),
        incoming_heal_pct = clamp01(member.incoming_heal_pct),
        role = member.role or "unknown",
        is_tank = member.is_tank == true or member.role == "tank",
    }
end

local function member_score(member)
    if type(member) ~= "table" then
        return 0
    end

    local uncovered = math.max(member.hp_pct - member.incoming_heal_pct, 0)
    local danger = 1 - uncovered
    if member.is_tank then
        danger = danger + 0.10
    end
    return danger
end

function combat_context.default_context(now_s)
    return {
        meta = {
            now_s = as_number(now_s),
            valid = true,
            fail_safe = false,
            stale_after_s = 0.25,
        },
        self = {
            hp_pct = 0,
            incoming_heal_pct = 0,
            incoming_damage_2s = 0,
            incoming_damage_pct_2s = 0,
            threat_pct = 0,
            role = "unknown",
            is_tank = false,
        },
        target = {
            exists = false,
            hp_pct = 0,
            is_casting = false,
            is_channeling = false,
            spell_id = 0,
            interruptible = false,
            cast_progress_pct = 0,
            victim_role = "unknown",
            victim_is_self = false,
        },
        party = {
            lowest_hp_pct = 0,
            any_ally_critical = false,
            members = {},
            tank = nil,
            urgent_ally = nil,
            group_collapse_risk = 0,
        },
        encounter = {
            hold_cooldowns = false,
            burn_phase = false,
            interrupt_priority = false,
            tank_damage_heavy = false,
            raid_aoe_heavy = false,
        },
    }
end

function combat_context.build(me, target, spec_meta, deps)
    local _ = spec_meta
    deps = deps or {}

    local ctx = combat_context.default_context(default_now(deps))
    local fail_safe = false

    local me_health = 0
    local me_max_health = 0

    if me then
        local ok

        me_health, ok = call_or_nil(me.get_health, me)
        if not ok then
            fail_safe = true
        end

        me_max_health, ok = call_or_nil(me.get_max_health, me)
        if not ok then
            fail_safe = true
        end

        local hp_pct, hp_ok = ratio(me_health, me_max_health)
        ctx.self.hp_pct = hp_pct
        if not hp_ok then
            fail_safe = true
        end

        local incoming_heals, heals_ok = call_or_nil(me.get_incoming_heals, me)
        if heals_ok then
            local heal_pct = ratio(incoming_heals, me_max_health)
            ctx.self.incoming_heal_pct = heal_pct
        else
            fail_safe = true
        end

        local threat_table, threat_ok = call_or_nil(me.get_threat_situation, me, target)
        if threat_ok and type(threat_table) == "table" then
            ctx.self.threat_pct = math.min(as_number(threat_table.threat_percent) / 100, 1)
        elseif target ~= nil then
            fail_safe = true
        end
    else
        fail_safe = true
    end

    if deps.health_prediction then
        local incoming_damage, damage_ok = call_or_nil(deps.health_prediction.get_incoming_damage, deps.health_prediction, me, 2.0)
        if damage_ok then
            ctx.self.incoming_damage_2s = as_number(incoming_damage)
            local damage_pct, damage_pct_ok = ratio(incoming_damage, me_max_health)
            if damage_pct_ok then
                ctx.self.incoming_damage_pct_2s = damage_pct
            else
                fail_safe = true
            end
        else
            fail_safe = true
            ctx.self.incoming_damage_2s = 0
            ctx.self.incoming_damage_pct_2s = 0
        end

        local role_id, role_ok = call_or_nil(deps.health_prediction.get_role_id, deps.health_prediction, me)
        if role_ok then
            ctx.self.role = normalize_role(role_id)
        else
            fail_safe = true
        end

        local is_tank, tank_ok = call_or_nil(deps.health_prediction.is_tank, deps.health_prediction, me)
        if tank_ok then
            ctx.self.is_tank = not not is_tank
        else
            fail_safe = true
        end
    else
        fail_safe = true
    end

    local live_target = target
    if live_target == nil and me then
        live_target = select(1, call_or_nil(me.get_target, me))
    end

    local target_valid = false
    if live_target then
        local valid = select(1, call_or_nil(live_target.is_valid, live_target))
        local dead = select(1, call_or_nil(live_target.is_dead, live_target))
        target_valid = (valid ~= false) and (dead ~= true)
    end

    if target_valid then
        ctx.target.exists = true

        local target_health = select(1, call_or_nil(live_target.get_health, live_target))
        local target_max_health = select(1, call_or_nil(live_target.get_max_health, live_target))
        local target_hp_pct, target_hp_ok = ratio(target_health, target_max_health)
        ctx.target.hp_pct = target_hp_pct
        if not target_hp_ok then
            fail_safe = true
        end

        local is_casting, cast_ok = call_or_nil(live_target.is_casting_spell, live_target)
        if cast_ok then
            ctx.target.is_casting = not not is_casting
        else
            fail_safe = true
        end

        local is_channeling, channel_ok = call_or_nil(live_target.is_channelling_spell, live_target)
        if channel_ok then
            ctx.target.is_channeling = not not is_channeling
        end

        if ctx.target.is_channeling then
            local channel_spell_id, channel_spell_ok = call_or_nil(live_target.get_active_channel_spell_id, live_target)
            if channel_spell_ok then
                ctx.target.spell_id = as_number(channel_spell_id)
            else
                fail_safe = true
            end
        else
            local spell_id, spell_ok = call_or_nil(live_target.get_active_spell_id, live_target)
            if spell_ok then
                ctx.target.spell_id = as_number(spell_id)
            elseif ctx.target.is_casting then
                fail_safe = true
            end
        end

        local interruptible, interrupt_ok = call_or_nil(live_target.is_active_spell_interruptable, live_target)
        if interrupt_ok then
            ctx.target.interruptible = not not interruptible
        elseif ctx.target.is_casting then
            fail_safe = true
        end

        if ctx.target.is_casting or ctx.target.is_channeling then
            local progress_pct, progress_ok = cast_progress_pct(live_target)
            if progress_ok then
                ctx.target.cast_progress_pct = progress_pct
            else
                fail_safe = true
            end

            local victim, victim_ok = call_or_nil(live_target.get_target, live_target)
            if victim_ok and victim ~= nil then
                ctx.target.victim_is_self = same_unit(victim, me)
                local victim_role, role_ok = call_or_nil(deps.health_prediction and deps.health_prediction.get_role_id, deps.health_prediction, victim)
                if role_ok then
                    ctx.target.victim_role = normalize_role(victim_role)
                else
                    fail_safe = true
                end
            elseif victim_ok then
                ctx.target.victim_role = "unknown"
            else
                fail_safe = true
            end
        end
    else
        ctx.target.exists = false
    end

    local party_reader = deps.party_reader
    if type(party_reader) == "function" then
        local party_members, party_ok = call_or_nil(party_reader, me, deps)
        if party_ok and type(party_members) == "table" then
            local lowest = 1
            local seen = false
            local members = {}
            local best_urgent = nil
            local best_urgent_score = -1
            for _, member in ipairs(party_members) do
                local normalized = normalize_party_member(member)
                if normalized then
                    members[#members + 1] = normalized
                    local member_hp = tonumber(normalized.hp_pct)
                    if member_hp then
                        seen = true
                        if member_hp < lowest then
                            lowest = member_hp
                        end
                    end

                    if normalized.is_tank and ctx.party.tank == nil then
                        ctx.party.tank = normalized
                    end

                    if not normalized.is_tank then
                        local score = member_score(normalized)
                        if score > best_urgent_score then
                            best_urgent_score = score
                            best_urgent = normalized
                        end
                    end
                end
            end
            if seen then
                ctx.party.lowest_hp_pct = math.max(0, math.min(lowest, 1))
                ctx.party.any_ally_critical = ctx.party.lowest_hp_pct <= 0.25
                ctx.party.members = members
                ctx.party.urgent_ally = best_urgent
                ctx.party.group_collapse_risk = clamp01((1 - ctx.party.lowest_hp_pct) + (ctx.encounter.raid_aoe_heavy and 0.15 or 0))
            end

            if ctx.party.tank == nil and ctx.target.victim_role == "tank" then
                local victim, victim_ok = call_or_nil(live_target and live_target.get_target, live_target)
                if victim_ok and victim ~= nil then
                    ctx.party.tank = {
                        guid = select(1, call_or_nil(victim.get_guid, victim)),
                        unit = victim,
                        hp_pct = 0,
                        incoming_heal_pct = 0,
                        role = "tank",
                        is_tank = true,
                    }
                end
            end
        else
            fail_safe = true
        end
    end

    if deps.encounter_manager and type(deps.encounter_manager.get_policy) == "function" then
        local policy, policy_ok = call_or_nil(deps.encounter_manager.get_policy, me)
        if policy_ok then
            ctx.encounter = copy_fields(policy, ctx.encounter)
        else
            fail_safe = true
        end
    end

    if fail_safe then
        ctx.meta.fail_safe = true
        ctx.target.exists = false
        ctx.self.incoming_damage_2s = 0
        ctx.self.incoming_damage_pct_2s = 0
        ctx.party.lowest_hp_pct = 0
        ctx.party.any_ally_critical = false
        ctx.party.members = {}
        ctx.party.tank = nil
        ctx.party.urgent_ally = nil
        ctx.party.group_collapse_risk = 0
    end

    return ctx
end

return combat_context
