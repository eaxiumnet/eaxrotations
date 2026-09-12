-- spell_school_gate_sylvanas.lua — Spell-school lockout gate (engine LoC signal).
-- WHAT:  answers "is the spell school I want to cast currently locked out on me?".
-- WHEN:  read by spec build_state (context.school_lockout) before committing a
--        cast, so the rotation falls back to its OFF-SCHOOL spell instead of
--        spamming a school the engine will refuse (guides: after a lockout,
--        switch schools — e.g. a frost mage uses Fire Blast, a balance druid
--        swaps Wrath <-> Starfire).
-- WHY:   the engine exposes the native lockout via
--        unit:get_loss_of_control_info().lockout_school (schools_flag bitmask);
--        main_sylvanas publishes it as context.school_lockout each frame. Before
--        this module NO rotation read it (grep-verified: zero callers), so every
--        spec kept queueing the locked school.
-- SAFETY: pure module — takes the lockout mask as data, captures no NS at
--         require time (behavioral_audit's shared-virgin guard), allocates
--         nothing, and FAILS OPEN: an absent/zero/non-numeric mask reports
--         "not locked", which is exactly today's behavior when the field is
--         unavailable (older clients / mock harnesses).

local M = {}

-- WoW spell-school bits (schools_flag). Composite schools (frostfire, etc.)
-- are sums of these bits, so the mask test below works for them unchanged.
M.SCHOOL = {
    PHYSICAL = 1,
    HOLY     = 2,
    FIRE     = 4,
    NATURE   = 8,
    FROST    = 16,
    SHADOW   = 32,
    ARCANE   = 64,
}

-- Bitwise AND on two school masks without bit operators (Lua 5.1): a mask
-- contains `flag` iff its value modulo twice the flag is at least the flag.
-- Works for composite schools because it is evaluated per bit.
function M.contains(mask, flag)
    if type(mask) ~= "number" or type(flag) ~= "number" then return false end
    if mask <= 0 or flag <= 0 then return false end
    return (mask % (flag * 2)) >= flag
end

-- Is `school_mask` locked out for the player in this context?
-- context.school_lockout is the engine mask (0/nil = nothing locked).
function M.locked(context, school_mask)
    local lock = context and context.school_lockout
    if type(lock) ~= "number" or lock <= 0 then return false end
    return M.contains(lock, school_mask)
end

-- Convenience: is anything locked for the player at all?
function M.any_locked(context)
    local lock = context and context.school_lockout
    return type(lock) == "number" and lock > 0
end

return M
