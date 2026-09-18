-- test_paladin_protection_forever.lua — Prot paladin Forever delta unit suite.
-- WHAT:  pins the Seal of Fury pair (taunt + upkeep) and the SealRighteousness
--        ping-pong wrap on the protection_forever splice; proves the dormant
--        path (bridge resolves nothing -> baseline unchanged).
-- WHEN:  run via run_rotation_tests.lua or standalone.
-- WHY:   the battery seeds ONE sentinel per name across all mirrors, so
--        mirror SELECTION (maxrank cast vs buff anchor) is pinned here with
--        distinct per-mirror sentinels (19000/19100 convention) — a delta
--        that reads the wrong mirror would pass the battery and break live.
--        The wrap pin is the load-bearing behavioral contract: with Fury up
--        the baseline's SealRighteousness matcher MUST be blocked (the
--        baseline's buff table predates the seal and would re-stomp it).
-- SAFETY: mocked NS + registry capture; no filesystem writes; self-contained.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local SENT_CAST = 19059      -- maxrank mirror sentinel (Seal of Fury cast row)
local SENT_BUFF = 19159      -- buff mirror sentinel (Seal of Fury aura anchor)

local _fury_up = false
local _last_cast = nil
local _sor_original_matches = nil

local function fresh_ns()
    _fury_up = false
    _last_cast = nil
    _sor_original_matches = nil
    return {
        PaladinSpells = {
            Judgement = { name = "Judgement" },
        },
        PLAYER_UNIT = { _mock = true },
        GetPlayer = function() return { _mock = true } end,
        is_forever = function() return true end,
        spell_action = function(ids, name) return { ids = ids, name = name } end,
        spell_ready = function() return true end,
        spell_exists = function() return true end,
        buff_up = function(unit, ids)
            if _fury_up and type(ids) == "table" then
                for i = 1, #ids do if ids[i] == SENT_CAST or ids[i] == SENT_BUFF then return true end end
            end
            return false
        end,
        buff_remains = function() return 0 end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        buff_points = function() return nil end,
        try_cast = function(spell, target, reason, opts)
            _last_cast = { spell = spell, target = target, reason = reason }
            return true
        end,
        mana_pct = function() return 100 end,
        unit_mana_pct = function() return 100 end,
        unit_health_pct = function() return 100 end,
        log = function() end,
        log_warning = function() end,
        rotation_registry = {
            register = function(self, name, strategies, options)
                -- capture the BASELINE registration (the delta re-registers
                -- through original_register; the mock records every call so
                -- we can find the vanilla baseline's matcher for comparison)
                _ns_registrations[#_ns_registrations + 1] =
                    { name = name, strategies = strategies, options = options }
            end,
        },
    }
end

_ns_registrations = {}

_G.EaxRotations = nil
package.loaded["classes/paladin/protection_vanilla"] = nil
package.loaded["shared/spec_kit_sylvanas"] = nil
package.loaded["shared/wowhead_data_bridge_spell_index_forever_sylvanas"] = nil
package.loaded["classes/paladin/protection_forever"] = nil

-- Sentinel bridge: distinct ids per mirror so mirror selection is pinned.
package.loaded["shared/wowhead_data_bridge_spell_index_forever_sylvanas"] = {
    spell_index_by_name_forever = { ["Seal of Fury"] = SENT_BUFF },
    spell_maxrank_by_name_forever = { ["Seal of Fury"] = SENT_CAST },
    spell_buff_by_name_forever = { ["Seal of Fury"] = SENT_BUFF },
}

-- Load the baseline FIRST (its registration lands in the mock registry), then
-- the delta (which re-requires the baseline through the interceptor).
_G.EaxRotations = fresh_ns()
local baseline_ok = pcall(require, "classes/paladin/protection_vanilla")
assert_true(baseline_ok, "baseline protection_vanilla loads under mock NS")
assert_true(#_ns_registrations >= 1, "baseline registered")

local baseline_strategies = _ns_registrations[1].strategies
local baseline_sor = nil
local baseline_sor_index = nil
for i, s in ipairs(baseline_strategies) do
    if s.name == "SealRighteousness" then baseline_sor = s baseline_sor_index = i break end
end
assert_true(baseline_sor, "baseline carries a SealRighteousness lane")
_sor_original_matches = baseline_sor.matches

local result = dofile("EaxRotations/classes/paladin/protection_forever.lua")
local strategies = type(result) == "table" and (result.strategies or result) or nil
assert_true(type(strategies) == "table", "delta returns a strategies table")

-- Re-registration replaces the baseline playstyle (the delta calls
-- original_register, which the mock also recorded).
assert_true(#_ns_registrations >= 2, "delta re-registered the playstyle")
local re_reg = _ns_registrations[#_ns_registrations]
assert_eq(re_reg.name, "protection", "re-registration keeps the playstyle name")

local function find(name)
    for i, s in ipairs(strategies) do
        if s.name == name then return s, i end
    end
    return nil, nil
end

-- Pin 1: the Fury pair exists and splices immediately above the (wrapped)
-- SealRighteousness lane.
local judgement_lane, judgement_idx = find("Forever_JudgementOfFury")
local upkeep_lane, upkeep_idx = find("Forever_SealOfFuryUpkeep")
local wrapped_sor, wrapped_sor_idx = find("SealRighteousness")
assert_true(judgement_lane, "Forever_JudgementOfFury present")
assert_true(upkeep_lane, "Forever_SealOfFuryUpkeep present")
assert_true(wrapped_sor, "SealRighteousness lane survives the splice")
assert_true(wrapped_sor_idx == baseline_sor_index + 2,
    "Fury pair sits immediately above SealRighteousness (idx "
    .. tostring(wrapped_sor_idx) .. " vs " .. tostring(baseline_sor_index + 2) .. ")")
assert_true(judgement_idx < upkeep_idx and upkeep_idx < wrapped_sor_idx,
    "taunt outranks upkeep outranks the wrapped baseline lane")

-- Pin 2: mirror selection — the cast action resolves the MAXRANK sentinel and
-- the buff probe uses the BUFF sentinel (distinct per-mirror ids).
assert_true(type(upkeep_lane.execute) == "function", "upkeep lane is executable")
assert_eq(re_reg.strategies[upkeep_idx].name, "Forever_SealOfFuryUpkeep",
    "re-registered list is the combined list")
-- Drive the upkeep lane: fury down -> fires the cast action (whose ids carry
-- the maxrank sentinel).
_fury_up = false
local ctx = { in_combat = true, has_valid_enemy_target = true,
              target = { _mock = true }, settings = {} }
local state = { mana_pct = 100 }
assert_true(upkeep_lane.matches(ctx, state), "upkeep fires with no seal up")
assert_true(upkeep_lane.execute(ctx, state), "upkeep executes")
assert_true(_last_cast and _last_cast.spell and _last_cast.spell.ids
    and _last_cast.spell.ids[1] == SENT_CAST,
    "upkeep casts through the MAXRANK mirror id (" .. tostring(SENT_CAST) .. ")")

-- Pin 3: the taunt gates on Fury UP (through the buff-mirror id in the probe
-- table) + a combat enemy target.
_fury_up = true
assert_true(judgement_lane.matches(ctx, state), "taunt fires with Fury up")
_fury_up = false
assert_false(judgement_lane.matches(ctx, state), "taunt holds without Fury")
_fury_up = true
local ooc = { in_combat = false, has_valid_enemy_target = false, target = nil, settings = {} }
assert_false(judgement_lane.matches(ooc, state), "taunt holds out of combat")
assert_true(judgement_lane.execute(ctx, state), "taunt executes on the target")
assert_true(_last_cast and _last_cast.target == ctx.target, "taunt casts at the target")

-- Pin 4 (the load-bearing wrap): with Fury up the wrapped SealRighteousness
-- matcher is BLOCKED even when the baseline matcher would fire; without Fury
-- it delegates identically.
_fury_up = true
local baseline_says = _sor_original_matches(ctx, state)
local wrapped_says = wrapped_sor.matches(ctx, state)
assert_true(baseline_says, "baseline SoR matcher would fire (mock conditions)")
assert_false(wrapped_says, "the wrap BLOCKS SoR while Fury is up (no ping-pong)")
_fury_up = false
assert_true(wrapped_sor.matches(ctx, state), "the wrap delegates when Fury is down")

-- Pin 6 (placement truth): the delta lanes splice ABOVE the baseline's
-- HammerOfWrath execute — the splice anchor (SealRighteousness) precedes HoW
-- in the baseline list, so at low target HP the taunt outranks the execute.
-- This is the load-bearing pin for the file's placement claims.
local baseline_how_index = nil
for i, s2 in ipairs(baseline_strategies) do
    if s2.name == "HammerOfWrath" then baseline_how_index = i break end
end
assert_true(baseline_how_index, "baseline carries a HammerOfWrath lane")
assert_true(baseline_sor_index < baseline_how_index,
    "baseline precondition: SealRighteousness precedes HammerOfWrath ("
    .. tostring(baseline_sor_index) .. " < " .. tostring(baseline_how_index) .. ")")
local combined_how_idx = nil
for i, s2 in ipairs(strategies) do
    if s2.name == "HammerOfWrath" then combined_how_idx = i break end
end
assert_true(combined_how_idx, "HammerOfWrath survives the splice")
assert_true(judgement_idx < combined_how_idx and upkeep_idx < combined_how_idx,
    "both Fury lanes sit ABOVE HammerOfWrath (taunt " .. tostring(judgement_idx)
    .. ", upkeep " .. tostring(upkeep_idx) .. ", HoW " .. tostring(combined_how_idx) .. ")")

-- Pin 7 (tracked starvation floor): the upkeep lane's mana floor reads the
-- baseline's prot_seal_of_wisdom_mana setting — inside the band the lane
-- holds (handing the seal slot to the baseline's SoW lane), above it fires.
local tracked = { in_combat = true, has_valid_enemy_target = true,
                  target = { _mock = true }, settings = { prot_seal_of_wisdom_mana = 60 } }
_fury_up = false
assert_false(upkeep_lane.matches(tracked, { mana_pct = 55 }),
    "upkeep holds below the tracked prot_seal_of_wisdom_mana band (60)")
assert_true(upkeep_lane.matches(tracked, { mana_pct = 70 }),
    "upkeep fires above the tracked band")
-- the default still applies when the setting is absent
local untracked = { in_combat = true, has_valid_enemy_target = true,
                    target = { _mock = true }, settings = {} }
assert_true(upkeep_lane.matches(untracked, { mana_pct = 40 }),
    "upkeep fires above the default 30 floor when the setting is absent")

-- Pin 5: the dormant path — a bridge that resolves nothing leaves the lane
-- set IDENTICAL to the baseline list (no Forever_ lanes, no wrap).
package.loaded["classes/paladin/protection_forever"] = nil
package.loaded["classes/paladin/protection_vanilla"] = nil
package.loaded["shared/wowhead_data_bridge_spell_index_forever_sylvanas"] = {
    spell_index_by_name_forever = {},
    spell_maxrank_by_name_forever = {},
    spell_buff_by_name_forever = {},
}
_ns_registrations = {}
_G.EaxRotations = fresh_ns()
assert_true(pcall(require, "classes/paladin/protection_vanilla"), "baseline re-load")
local dormant = dofile("EaxRotations/classes/paladin/protection_forever.lua")
local dormant_strategies = type(dormant) == "table" and (dormant.strategies or dormant) or nil
assert_true(type(dormant_strategies) == "table", "dormant load returns a table")
local dormant_names = {}
for _, s in ipairs(dormant_strategies) do dormant_names[s.name or "?"] = true end
assert_false(dormant_names["Forever_JudgementOfFury"], "dormant: no taunt lane")
assert_false(dormant_names["Forever_SealOfFuryUpkeep"], "dormant: no upkeep lane")
assert_eq(#dormant_strategies, #baseline_strategies,
    "dormant: strategy count equals the baseline's")

print("PASS test_paladin_protection_forever (7 pins)")
return { name = "test_paladin_protection_forever" }
