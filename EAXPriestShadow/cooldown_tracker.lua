local cooldown_tracker = {}

local state = {
    spell_id = nil,
    set_at = 0,
    cooldown_s = 0,
}

function cooldown_tracker.set_next_spell(spell_id, set_at, cooldown_s)
    state.spell_id = spell_id
    state.set_at = tonumber(set_at) or 0
    state.cooldown_s = math.max(0, tonumber(cooldown_s) or 0)
end

function cooldown_tracker.clear()
    state.spell_id = nil
    state.set_at = 0
    state.cooldown_s = 0
end

function cooldown_tracker.seconds_remaining(now_s)
    if not state.spell_id then
        return 0
    end

    local now = tonumber(now_s) or 0
    local remaining = (state.set_at + state.cooldown_s) - now
    if remaining <= 0 then
        return 0
    end
    return remaining
end

return cooldown_tracker
