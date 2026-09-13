-- druid_form_sylvanas.lua -- one live-available druid shapeshift detector.
-- WHAT:  answers "which form is the druid in right now?" from every source the
--        client actually exposes at once, so a single lying API can never make a
--        rotation lane believe a shifted druid is standing in caster form.
-- WHEN:  required by the druid specs' state builders, the druid middleware's
--        caster-only lanes, and the OOC manager's form gate.
-- WHY:   live report (2026-09-13): a TBC feral/cat druid left Cat Form right
--        after combat ended, when the OOC lanes re-evaluated. Two things need a
--        truthful form answer:
--          1. Casting Cat Form while ALREADY in Cat Form toggles the form OFF,
--             so "am I in cat?" must not hang on one aura read -- the specs use
--             it to decide whether to re-shift.
--          2. Caster-only maintenance (Mark of the Wild / Thorns) must never be
--             attempted while shifted; the client refuses the cast and the form
--             (or the GCD) is lost for nothing.
-- SAFETY: pure reads, no casts, no tables allocated per call.
-- DECISION: the shapeshift bar index (NS.get_player_stance, the .api-preferred
--        cross-version source), then the aura table (NS.has_form). Either source
--        alone is enough to say "shifted": the sources disagree, not the druid.
-- SCOPE:  the engine stance source stops at index 3 (bear/aquatic/cat), so
--        Moonkin and Tree are read from their auras. Travel Form has neither a
--        stance index nor an aura entry in core's FORMS table, so it reads as
--        caster here exactly as it did before this module existed; no caller
--        depends on the detector for travel.

local _G = _G
local M = {}

-- Shapeshift bar index -> form name. The druid bar is ordered Bear, Aquatic,
-- Cat, Travel, Moonkin, Tree; the engine stance source (core.get_player_stance)
-- only reports the first three, so the rest are resolved by aura below.
local BAR_FORM = {
    [1] = "bear",
    [2] = "aquatic",
    [3] = "cat",
}

-- Aura-backed names, in check order. NS.has_form owns the buff ids (core's
-- FORMS table): cat 768, bear 5487/9634, moonkin 24858, tree 33891.
local AURA_FORM_ORDER = { "cat", "bear", "moonkin", "tree" }

local function ns()
    return _G.EaxRotations
end

local function stance_index(context)
    local stance = context and context.stance
    if type(stance) == "number" then return stance end
    local EaxRotations = ns()
    if EaxRotations and type(EaxRotations.get_player_stance) == "function" then
        local ok, value = pcall(EaxRotations.get_player_stance)
        if ok and type(value) == "number" then return value end
    end
    return nil
end

local function aura_form()
    local EaxRotations = ns()
    if not EaxRotations or type(EaxRotations.has_form) ~= "function" then return nil end
    for i = 1, #AURA_FORM_ORDER do
        local name = AURA_FORM_ORDER[i]
        local ok, has = pcall(EaxRotations.has_form, name)
        if ok and has then return name end
    end
    return nil
end

--- Which shapeshift form is the druid in right now?
--- @param context table|nil rotation context (context.stance is the fast path)
--- @return string|nil "bear"|"aquatic"|"cat"|"moonkin"|"tree"|"form",
---         or nil when the druid is in caster/humanoid form.
function M.current(context)
    local stance = stance_index(context)
    if stance and stance > 0 then return BAR_FORM[stance] or "form" end
    return aura_form()
end

--- True when any form is active (caster-form spells are unavailable then).
function M.is_shifted(context)
    return M.current(context) ~= nil
end

--- True only when the druid is positively in Cat Form.
function M.is_cat(context)
    return M.current(context) == "cat"
end

--- True in the feral forms (cat/bear). These are the forms whose own lanes own
--- the rotation, and the only forms where caster maintenance is both illegal
--- AND the rotation has something better to do instead. Moonkin (Balance) and
--- Tree (HoTs) deliberately do not count: their callers keep casting.
function M.is_feral(context)
    local form = M.current(context)
    return form == "cat" or form == "bear"
end

return M
