-- druid_form_sylvanas.lua -- one live-available druid shapeshift detector.
-- WHAT:  answers "which form is the druid in right now?" for the druid specs'
--        state builders, the druid middleware's caster-only lanes, and the OOC
--        manager's form gate.
-- WHEN:  required by classes/druid/{middleware,leveling,cat}_sylvanas.lua and
--        shared/ooc_manager_sylvanas.lua.
-- WHY:   two live reports (2026-09-13), and the second one is why the
--        authority order below is what it is:
--          1. a TBC feral/cat druid left Cat Form right after combat ended,
--             because the OOC lanes re-evaluated while shifted;
--          2. after that fix the cat rotation went SILENT. The detector named
--             the form from the engine stance number first, but on that client
--             a cat druid reports the class-global form id (cat = 1), NOT the
--             shapeshift bar index (cat = 3) -- so the druid was read as a
--             BEAR and every `required_form == "cat"` lane held. The gate it
--             replaced was `NS.has_form("cat") or stance == 3` and it fired,
--             which is the live proof that the aura is the truthful source.
-- SAFETY: pure reads, no casts, no tables allocated per call.
-- DECISION: the aura table (NS.has_form, over core's FORMS buff ids) NAMES the
--        form; it is the only source that does, and the one the live client
--        answers correctly. The stance number is used ONLY as proof that SOME
--        form is active ("form"), never to name one: its scale differs per
--        class -- and, on live TBC, from the bar index this codebase's own
--        STANCE_* constants assume. Naming from it is exactly how a cat druid
--        was called a bear and the rotation went silent.
-- SCOPE:  core's FORMS table has no travel/aquatic entry, so Travel and Aquatic
--        Form are never *named*; a nonzero stance still reports them as shifted
--        ("form"), which is the safe answer -- a caster-only cast while
--        travelling unshifts the druid exactly as it does in cat. Callers that
--        need a named feral form (Cower, the party dispel) fail OPEN on an
--        unnamed form rather than guess. is_cat is the same contract: only the
--        aura names Cat Form, so a client that reports a form but no aura is
--        "shifted, unnamed" and the cat-only lanes hold instead of guessing.
--        The raw `context.stance == STANCE_CAT` comparisons the cat spec used
--        are gone with this change -- the number is not a name, and that
--        comparison is disproved on live (a cat druid does not report 3).

local _G = _G
local M = {}

-- Aura-backed names, in check order. NS.has_form owns the buff ids (core's
-- FORMS table): cat 768, bear 5487/9634, moonkin 24858, tree 33891.
local AURA_FORM_ORDER = { "cat", "bear", "moonkin", "tree" }

local function ns()
    return _G.EaxRotations
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

--- Which shapeshift form is the druid in right now?
--- @param context table|nil rotation context (context.stance is the fast path)
--- @return string|nil "cat"|"bear"|"moonkin"|"tree" when the aura names it,
---         the generic "form" when only the stance number reports one, or nil
---         when the druid is in caster/humanoid form.
function M.current(context)
    local named = aura_form()
    if named then return named end
    local stance = stance_index(context)
    if type(stance) == "number" and stance > 0 then return "form" end
    return nil
end

--- True when any form is active (caster-form spells are unavailable then).
function M.is_shifted(context)
    return M.current(context) ~= nil
end

--- True only when the druid is positively in Cat Form (aura-named).
function M.is_cat(context)
    return M.current(context) == "cat"
end

--- True in the feral forms (cat/bear). These are the forms whose own lanes own
--- the rotation, and the only forms where caster maintenance is both illegal
--- AND the rotation has something better to do instead. Moonkin (Balance) and
--- Tree (HoTs) deliberately do not count: their callers keep casting. An
--- unnamed form is not feral either -- no source could name it, so the
--- feral-only callers fail open instead of guessing.
function M.is_feral(context)
    local form = M.current(context)
    return form == "cat" or form == "bear"
end

return M
