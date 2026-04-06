local reactive_engine = {}

reactive_engine.reason_codes = {
    LIFE_SAVE_SELF = "LIFE_SAVE_SELF",
    LIFE_SAVE_ALLY = "LIFE_SAVE_ALLY",
    INTERRUPT_DANGER = "INTERRUPT_DANGER",
    CONTROL_DANGER = "CONTROL_DANGER",
    ANTI_OVERHEAL = "ANTI_OVERHEAL",
    ANTI_AGGRO = "ANTI_AGGRO",
    THROUGHPUT_RESUME = "THROUGHPUT_RESUME",
    FAIL_SAFE_HOLD = "FAIL_SAFE_HOLD",
    NO_ACTION = "NO_ACTION",
}

local STABILITY_BUFFER_S = 0.50
reactive_engine.STABILITY_BUFFER_S = STABILITY_BUFFER_S

local ORDER = {
    { name = "life_save_self", reason_code = reactive_engine.reason_codes.LIFE_SAVE_SELF },
    { name = "life_save_ally", reason_code = reactive_engine.reason_codes.LIFE_SAVE_ALLY },
    { name = "interrupt_control", reason_code = reactive_engine.reason_codes.INTERRUPT_DANGER },
    { name = "anti_overheal", reason_code = reactive_engine.reason_codes.ANTI_OVERHEAL },
    { name = "anti_aggro", reason_code = reactive_engine.reason_codes.ANTI_AGGRO },
    { name = "throughput_resume", reason_code = reactive_engine.reason_codes.THROUGHPUT_RESUME },
}

local function result(acted, reason_code, action_id, hold_until_s)
    return {
        acted = acted,
        reason_code = reason_code,
        action_id = action_id or "none",
        hold_until_s = hold_until_s or 0,
    }
end

local function is_non_throughput(reason_code)
    return reason_code ~= reactive_engine.reason_codes.NO_ACTION
        and reason_code ~= reactive_engine.reason_codes.THROUGHPUT_RESUME
end

local function maybe_hold(ctx, state)
    if type(state) ~= "table" then
        return nil
    end

    local now_s = (((ctx or {}).meta or {}).now_s) or 0
    local hold_until_s = tonumber(state.hold_until_s) or 0
    if hold_until_s > now_s then
        return result(false, state.reason_code or reactive_engine.reason_codes.FAIL_SAFE_HOLD, state.action_id or "none", hold_until_s)
    end

    return nil
end

function reactive_engine.try_handle(ctx, deps)
    deps = deps or {}
    ctx = ctx or { meta = {} }

    if ((ctx.meta or {}).fail_safe) then
        return result(false, reactive_engine.reason_codes.FAIL_SAFE_HOLD, "none", ((ctx.meta or {}).now_s or 0) + STABILITY_BUFFER_S)
    end

    local held = maybe_hold(ctx, deps.state)
    if held then
        return held
    end

    local actions = deps.actions or {}
    local now_s = (((ctx or {}).meta or {}).now_s) or 0

    for _, branch in ipairs(ORDER) do
        local handler = actions[branch.name]
        if type(handler) == "function" then
            local action = handler(ctx, deps)
            if action then
                local action_id = action.action_id or branch.name
                local hold_until_s = tonumber(action.hold_until_s) or 0
                if hold_until_s <= 0 and is_non_throughput(branch.reason_code) then
                    hold_until_s = now_s + STABILITY_BUFFER_S
                end

                if type(deps.state) == "table" then
                    deps.state.hold_until_s = hold_until_s
                    deps.state.reason_code = branch.reason_code
                    deps.state.action_id = action_id
                end

                return result(true, branch.reason_code, action_id, hold_until_s)
            end
        end
    end

    if type(deps.state) == "table" then
        deps.state.hold_until_s = 0
        deps.state.reason_code = reactive_engine.reason_codes.NO_ACTION
        deps.state.action_id = "none"
    end

    return result(false, reactive_engine.reason_codes.NO_ACTION, "none", 0)
end

return reactive_engine
