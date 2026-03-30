local role_policy = {}

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

local function resolve_role(opts, ctx)
    if type(opts) == "table" and type(opts.role) == "string" then
        return opts.role
    end
    return (((ctx or {}).self or {}).role) or "unknown"
end

local function covered(member)
    if type(member) ~= "table" then
        return false
    end
    local hp = clamp01(member.hp_pct)
    local incoming = clamp01(member.incoming_heal_pct)
    return hp + incoming >= 0.72 or incoming >= 0.30
end

local function unstable_tank(ctx)
    local tank = (((ctx or {}).party or {}).tank)
    if type(tank) ~= "table" then
        return nil
    end

    if covered(tank) then
        return nil
    end

    if clamp01(tank.hp_pct) <= 0.45 or clamp01((ctx.encounter or {}).tank_damage_heavy and 1 or 0) > 0 then
        return tank
    end

    return nil
end

local function urgent_ally(ctx)
    local ally = (((ctx or {}).party or {}).urgent_ally)
    if type(ally) ~= "table" or covered(ally) then
        return nil
    end
    return ally
end

local function imminent_self_death(ctx)
    local self_ctx = (ctx or {}).self or {}
    return clamp01(self_ctx.hp_pct) <= 0.20
        or (clamp01(self_ctx.hp_pct) <= 0.35 and clamp01(self_ctx.incoming_damage_pct_2s) >= 0.30)
end

local function cast_urgency(ctx)
    local target = (ctx or {}).target or {}
    if target.exists ~= true or (target.is_casting ~= true and target.is_channeling ~= true) or target.interruptible ~= true then
        return 0
    end

    local victim_bonus = {
        tank = 0.30,
        healer = 0.24,
        damager = 0.16,
        unknown = 0.08,
    }

    local score = 0.35
        + (clamp01(target.cast_progress_pct) * 0.35)
        + (((ctx.encounter or {}).interrupt_priority == true) and 0.20 or 0)
        + (((target.victim_is_self == true) and 0.12) or 0)
        + (victim_bonus[target.victim_role or "unknown"] or victim_bonus.unknown)

    return score
end

function role_policy.build_actions(opts)
    opts = opts or {}

    return {
        life_save_self = function(ctx)
            if imminent_self_death(ctx) then
                return { action_id = "life_save_self" }
            end
        end,
        life_save_ally = function(ctx)
            if resolve_role(opts, ctx) ~= "healer" then
                return nil
            end

            local tank = unstable_tank(ctx)
            if tank then
                return {
                    action_id = "life_save_ally",
                    target_guid = tank.guid,
                    target_role = "tank",
                }
            end

            local ally = urgent_ally(ctx)
            if ally then
                return {
                    action_id = "life_save_ally",
                    target_guid = ally.guid,
                    target_role = ally.role,
                }
            end
        end,
        interrupt_control = function(ctx)
            local urgency_score = cast_urgency(ctx)
            if urgency_score >= 0.90 then
                return {
                    action_id = "interrupt_control",
                    urgency_score = urgency_score,
                }
            end
        end,
        anti_overheal = function(ctx)
            if resolve_role(opts, ctx) ~= "healer" then
                return nil
            end

            local self_ctx = (ctx or {}).self or {}
            if clamp01(self_ctx.hp_pct) >= 0.85 and clamp01(self_ctx.incoming_heal_pct) >= 0.40 and (((ctx or {}).party or {}).group_collapse_risk or 0) < 0.25 then
                return { action_id = "anti_overheal" }
            end
        end,
        anti_aggro = function(ctx)
            local role = resolve_role(opts, ctx)
            local self_ctx = (ctx or {}).self or {}
            local target = (ctx or {}).target or {}
            local collapse_risk = clamp01((((ctx or {}).party or {}).group_collapse_risk) or 0)

            if role == "tank" then
                if not imminent_self_death(ctx)
                    and target.victim_is_self ~= true
                    and (target.victim_role == "healer" or target.victim_role == "damager" or collapse_risk >= 0.45) then
                    return { action_id = "anti_aggro" }
                end
                return nil
            end

            if role == "damager" and clamp01(self_ctx.threat_pct) >= 0.90 and (collapse_risk >= 0.20 or clamp01(self_ctx.incoming_damage_pct_2s) >= 0.20) then
                return { action_id = "anti_aggro" }
            end
        end,
        throughput_resume = function(ctx)
            if ((ctx or {}).meta or {}).fail_safe ~= true then
                return { action_id = "throughput_resume", hold_until_s = 0 }
            end
        end,
    }
end

return role_policy
