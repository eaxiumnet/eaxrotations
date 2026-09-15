-- warrior_stance_sylvanas.lua -- one live-available warrior stance detector.
-- WHAT:  answers "which stance is the warrior in right now?" for every warrior
--        spec's stance lanes (fury, arms, protection, leveling).
-- WHEN:  required by classes/warrior/{fury,arms,protection,leveling}_sylvanas.lua.
-- WHY:   before this module the stance question was answered three different
--        ways that can disagree:
--          1. state.stance -- the engine stance NUMBER, defaulted by the specs
--             to their preferred stance when the engine reports 0
--             (fury: `context.stance or STANCE.BERSERKER`), so a stalled
--             stance read looked like "already in Berserker";
--          2. inline `NS.has_form("berserker")` aura checks in fury/arms
--             (absent in prot/leveling);
--          3. the fury builder's `if stance == 0 then trust aura` correction,
--             which only repairs zero -- a WRONG nonzero number stays wrong.
--        Two of the three sources disagreeing is exactly the Battle/Berserker
--        stance ping-pong observed live (2026-09-14 logs: Battle Stance and
--        Berserker Stance re-cast in alternation for 90+ seconds). The druid
--        form wave (shared/druid_form_sylvanas.lua) proved the live client's
--        stance NUMBER is the untrustworthy source: a cat druid reports the
--        class-global form id, not the bar index this codebase's constants
--        assume. Warriors have the same engine, so the aura table NAMES the
--        stance here too and the number only ever answers "some stance is
--        active" (never names one).
-- SAFETY: pure reads, no casts, no per-call allocation, nil-guarded at every
--        layer: no aura API and no stance number => "unknown", and every
--        caller treats unknown exactly like its pre-module conservative
--        answer (fury/arms lanes hold, prot/leveling keep their current
--        gates). An engine that reports nothing changes nothing.
-- DECISION: aura first (it names the stance AND is the source the druid wave
--        proved truthful), number second (only as existence proof), and a
--        disagreement is resolved IN FAVOUR OF THE AURA -- the number cannot
--        override a named aura, but a named aura plus a zero/absent number is
--        still trusted (the bar index is known to read 0 on some builds).

local _G = _G
local M = {}

-- Stance names -> core's FORMS aura ids (core_sylvanas.lua FORMS table):
-- battle 2457, defensive 71, berserker 2458. Names match NS.has_form keys.
local AURA_STANCE_ORDER = { "battle", "defensive", "berserker" }

-- Number -> name under the codebase's own STANCE constants
-- (NS.WarriorConstants.STANCE: BATTLE=1, DEFENSIVE=2, BERSERKER=3).
local NUMBER_TO_NAME = { [1] = "battle", [2] = "defensive", [3] = "berserker" }

local function ns()
    return _G.EaxRotations
end

local function aura_stance()
    local EaxRotations = ns()
    if not EaxRotations or type(EaxRotations.has_form) ~= "function" then return nil end
    for i = 1, #AURA_STANCE_ORDER do
        local name = AURA_STANCE_ORDER[i]
        local ok, has = pcall(EaxRotations.has_form, name)
        if ok and has then return name end
    end
    return nil
end

local function stance_number(context)
    local stance = context and context.stance
    if type(stance) == "number" and stance > 0 then return stance end
    local EaxRotations = ns()
    if EaxRotations and type(EaxRotations.get_player_stance) == "function" then
        local ok, value = pcall(EaxRotations.get_player_stance)
        if ok and type(value) == "number" and value > 0 then return value end
    end
    return nil
end

--- Which stance is the warrior in right now?
--- @param context table|nil rotation context (context.stance is the fast path)
--- @return string|nil "battle"|"defensive"|"berserker" when a source names it,
---         the generic "stance" when only a nonzero number reports one, or nil
---         when no source can answer (treated as "no stance" by callers).
function M.current(context)
    local named = aura_stance()
    if named then return named end
    local num = stance_number(context)
    if type(num) == "number" then
        return NUMBER_TO_NAME[num] or "stance"
    end
    return nil
end

--- True only when positively in the named stance (aura-named, or the number
--- agrees under the codebase's own constants). The central question for the
--- stance lanes: a lane that wants to CAST this stance holds on true, so an
--- unknown (nil) must read as false -- fail open to the lane, never freeze it.
function M.is_stance(context, name)
    if type(name) ~= "string" then return false end
    return M.current(context) == name
end

--- Numeric stance id under the codebase's constants (1/2/3), or nil when no
--- source can name a stance. Number-source answers map through the same
--- constants; aura answers always have a numeric twin.
function M.current_id(context)
    local name = M.current(context)
    if name == "battle" then return 1 end
    if name == "defensive" then return 2 end
    if name == "berserker" then return 3 end
    return nil
end

return M
