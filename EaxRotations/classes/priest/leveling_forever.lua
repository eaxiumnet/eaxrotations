-- leveling_forever.lua — Priest leveling delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 priest leveling delta over the vanilla baseline: the
--        UNIVERSAL-ACCESS pair — DEVOURING PLAGUE (the shadow dot that was
--        the Undead racial) and FEAR WARD (the fear immunity that was the
--        Dwarf racial) now belong to every priest ("Racial-spell system
--        dissolved; the Vanilla race-choice matrix for priests collapses"),
--        so the leveling rotation gains both lanes: DP in the dot block and
--        Fear Ward in the self-buff block.
-- WHEN:  any combat while leveling (DP) / out of combat (Fear Ward), Forever
--        client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/priest.md: "Devouring Plague for ALL races (was
--        Undead racial) — Shadow's flagship dot becomes universally
--        available" and "Fear Ward baseline for all Priests (was Dwarf
--        racial) — Racial-spell system dissolved" plus the leveling bullet
--        "Fear Ward/DP universal access reshape early leveling for all
--        races." The vanilla leveling baseline has NO lane for either (it
--        was race-gated content), so both are pure additions; the lanes
--        mirror the baseline's own patterns exactly (debuff lanes:
--        target + ready + remains < 4; self-buff lanes: out of combat +
--        ready + not already buffed). DBC FINDINGS (1.60.1.69893): Fear
--        Ward resolves as 6346 (the class-map row, level 20) and Devouring
--        Plague's ladder is 2944@20 ... 19280@60 (the class map carries the
--        TBC 25467 first; NS.get_spell_id walks to the known rung).
-- SAFETY: ZERO numeric spell-ID literals — both spells are era-shared from
--        the class map and their debuff/buff reads reuse the same ladders.
--        The vanilla baseline is loaded through an intercepted registration
--        (affliction/demonology_forever template) so this file edits nothing
--        in leveling_vanilla.lua and its safe_state-backed get_state is
--        reused unchanged. Splice geometry: DP immediately above the
--        baseline's "ShadowWordPain" (fallback: "HolyFire"), Fear Ward
--        immediately above "PowerWordFortitude" (fallback: "InnerFire");
--        then append.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.PriestSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "leveling" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("priest leveling", "classes/priest/leveling_vanilla")

-- ---------------------------------------------------------------------------
-- Era-shared resolution (zero-literal contract): both spells and their
-- aura/debuff id lists come from the class map (no Forever-new names here —
-- the change is access, not the spell row). A nil lookup leaves the lane
-- dormant -- never a guessed ID.
-- ---------------------------------------------------------------------------
local DEVOURING_PLAGUE = SPELLS.DevouringPlague or nil
local DP_IDS = (DEVOURING_PLAGUE and DEVOURING_PLAGUE._meta
    and DEVOURING_PLAGUE._meta.ids) or nil
local FEAR_WARD = SPELLS.FearWard or nil
local FEAR_WARD_IDS = (FEAR_WARD and FEAR_WARD._meta and FEAR_WARD._meta.ids) or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. The refresh window mirrors the baseline's dot lanes
-- (remains < 4); the buff lanes mirror the baseline's out-of-combat
-- self-buff pattern.
-- ---------------------------------------------------------------------------
local DOT_REFRESH = 4

local function has_valid_enemy(context, s)
    return context and s and s.target and context.has_valid_enemy_target ~= false
end

local function debuff_remains(target, ids)
    if not target or not ids or type(NS.debuff_remains) ~= "function" then return 0 end
    local ok, remains = pcall(NS.debuff_remains, target, ids)
    if ok and type(remains) == "number" then return remains end
    return 0
end

local function player_buff_up(ids)
    if not ids or type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, NS.PLAYER_UNIT, ids)
    return ok and up == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. DP leads the dot block; Fear Ward leads the self-buff block.
-- ---------------------------------------------------------------------------
local delta_dot = {}
local delta_buff = {}

if DEVOURING_PLAGUE and DP_IDS then
    delta_dot[#delta_dot + 1] = {
        name = "Forever_DevouringPlague",
        matches = function(context, s)
            if not has_valid_enemy(context, s) then return false end
            if not s.in_combat then return false end
            if s.is_moving then return false end
            if debuff_remains(s.target, DP_IDS) >= DOT_REFRESH then return false end
            return NS.spell_ready(DEVOURING_PLAGUE, s.target)
        end,
        execute = function(context, s)
            return NS.try_cast(DEVOURING_PLAGUE, s.target,
                "[FOREVER-LEVELING] Devouring Plague (universal dot)")
        end,
    }
end

if FEAR_WARD and FEAR_WARD_IDS then
    delta_buff[#delta_buff + 1] = {
        name = "Forever_FearWard",
        matches = function(context, s)
            if not s then return false end
            if s.in_combat then return false end
            if player_buff_up(FEAR_WARD_IDS) then return false end
            return NS.spell_ready(FEAR_WARD, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(FEAR_WARD, NS.PLAYER_UNIT,
                "[FOREVER-LEVELING] Fear Ward (universal)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: DP immediately above "ShadowWordPain" (fallback:
-- "HolyFire"), Fear Ward immediately above "PowerWordFortitude" (fallback:
-- "InnerFire"); then append. Re-registering the playstyle name replaces the
-- baseline wholesale — the combined list IS the "leveling" playstyle on
-- Forever.
-- ---------------------------------------------------------------------------
local DOT_ANCHORS = { ShadowWordPain = true, HolyFire = true }
local BUFF_ANCHORS = { PowerWordFortitude = true, InnerFire = true }

local combined = {}
local dot_done = false
local buff_done = false
local function insert_dot()
    if dot_done then return end
    for j = 1, #delta_dot do combined[#combined + 1] = delta_dot[j] end
    dot_done = true
end
local function insert_buff()
    if buff_done then return end
    for j = 1, #delta_buff do combined[#combined + 1] = delta_buff[j] end
    buff_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and DOT_ANCHORS[name] then insert_dot() end
    if name and BUFF_ANCHORS[name] then insert_buff() end
    combined[#combined + 1] = st
end
insert_dot()
insert_buff()

baseline.register(combined)
if NS.log then NS.log("Priest leveling Forever delta registered (" ..
    #delta_dot .. " devouring-plague + " .. #delta_buff ..
    " fear-ward lanes over " .. #baseline.strategies .. " baseline lanes)") end

return combined
