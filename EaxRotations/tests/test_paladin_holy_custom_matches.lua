-- test_paladin_holy_custom_matches.lua -- Holy Paladin custom match validation tests.
-- WHAT:  Holy Paladin custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- unit tests for paladin_holy_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local action_calls = {}
_G.EaxRotations = {
    PaladinSpells = {
        DivineFavor = 20216,
        HolyShock = 20473,
        FlashOfLight = 19750,
        HolyLight = 635,
        AvengingWrath = 31884,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return _G.EaxRotations.PLAYER_UNIT end,
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    spell_ready = function(spell, target, opts)
        return true
    end,
    has_player_buff = function(buff_list)
        return false
    end,
    healing_get_lowest_hp = function(entries, count, threshold)
        return entries and entries[1] or nil
    end,
    healing_get_tank = function(entries, count)
        return nil
    end,
    log = function() end,
    gate_overheal = function() return false end,
    buff_remains = function(unit, ids) return 0 end,
    rotation_registry = {
        register = function() end,
    },
}

-- Mock healing module
local mock_healing = {
    scan_healing_targets = function()
        return {}, 0
    end,
    select_heal = function(context, state, target)
        return { spell = 19750, label = "FlashOfLight" }
    end,
}
package.loaded["classes/paladin/healing_sylvanas"] = mock_healing

local strategies = dofile("EaxRotations/classes/paladin/holy_sylvanas.lua").strategies
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- DivineFavor: only when lowest HP <= 45%
-- ============================================================================

local divine_favor = find_strategy("DivineFavor")

-- High HP -> should NOT match
action_calls = {}
local ctx_df_high = {
    settings = {},
}
assert_false(divine_favor.matches(ctx_df_high, { lowest = { effective_hp = 60 } }), "DivineFavor should not match when lowest HP > 45%")

-- Low HP -> should match
action_calls = {}
local ctx_df_low = {
    settings = {},
}
assert_true(divine_favor.matches(ctx_df_low, { lowest = { effective_hp = 30, unit = {} } }), "DivineFavor should match when lowest HP <= 45%")

-- No lowest -> should NOT match
action_calls = {}
assert_false(divine_favor.matches({}, { lowest = nil }), "DivineFavor should not match without lowest")

-- ============================================================================
-- ============================================================================

local holy_shock = find_strategy("HolyShock")

-- High HP, not moving -> should NOT match
action_calls = {}
local ctx_hs_high = {
    settings = { holy_shock_hp = 40 },
    is_moving = false,
}
assert_false(holy_shock.matches(ctx_hs_high, { lowest = { effective_hp = 60, unit = {} } }), "HolyShock should not match when HP > threshold and not moving")

-- Low HP -> should match
action_calls = {}
local ctx_hs_low = {
    settings = { holy_shock_hp = 40 },
    is_moving = false,
}
assert_true(holy_shock.matches(ctx_hs_low, { lowest = { effective_hp = 30, unit = {} } }), "HolyShock should match when HP <= threshold")

action_calls = {}
local ctx_hs_move = {
    settings = { holy_shock_hp = 40 },
    is_moving = true,
}
assert_true(holy_shock.matches(ctx_hs_move, { lowest = { effective_hp = 60, unit = {} } }), "HolyShock should match as an instant moving fallback")

-- No lowest -> should NOT match
action_calls = {}
assert_false(holy_shock.matches({}, { lowest = nil }), "HolyShock should not match without lowest")

-- ============================================================================
-- SmartHeal: only when a heal is selected and spell ready
-- ============================================================================

local smart_heal = find_strategy("SmartHeal")

-- No lowest -> should NOT match
action_calls = {}
assert_false(smart_heal.matches({}, { lowest = nil }), "SmartHeal should not match without lowest")

-- Lowest exists, heal selected -> should match
action_calls = {}
local ctx_sh = {
    settings = {},
}
assert_true(smart_heal.matches(ctx_sh, { lowest = { effective_hp = 50, unit = {} } }), "SmartHeal should match when lowest exists and heal selected")

-- ============================================================================
-- AvengingWrathHeavyHealing: +20% healing burst (3-min CD). Only in combat + a
-- heavy-healing window + setting enabled + target not about to die.
-- ============================================================================

local aw = find_strategy("AvengingWrathHeavyHealing")

-- Setting disabled -> should NOT match
assert_false(aw.matches({ in_combat = true, settings = { holy_avenging_wrath = false } }, { heavy_healing = true }), "AvengingWrath should not match when setting disabled")

-- Out of combat -> should NOT match (even with heavy_healing)
assert_false(aw.matches({ in_combat = false, settings = {} }, { heavy_healing = true }), "AvengingWrath should not match out of combat")

-- In combat but no heavy-healing window -> should NOT match
assert_false(aw.matches({ in_combat = true, settings = {} }, { heavy_healing = false }), "AvengingWrath should not match without a heavy-healing window")

-- In combat + heavy_healing + setting default + no ttd -> should match
assert_true(aw.matches({ in_combat = true, settings = {} }, { heavy_healing = true }), "AvengingWrath should match in combat + heavy_healing (setting default true)")

-- Target about to die (ttd < 15) -> should NOT match (don't waste 3-min CD)
assert_false(aw.matches({ in_combat = true, settings = {}, ttd_known = true, ttd = 10 }, { heavy_healing = true }), "AvengingWrath should not match when ttd < 15")

-- ============================================================================
-- LightGraceChain: refresh LG before it expires
-- ============================================================================

local lg_chain = find_strategy("LightGraceChain")

-- Setting disabled -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = { holy_lg_chain_enabled = false } }, { lights_grace_remains = 2, tank = { unit = {}, deficit = 1000 } }), "LGChain should not match when disabled")

-- LG not active -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 0, tank = { unit = {}, deficit = 1000 } }), "LGChain should not match without LG")

-- LG expires in >=2.5s -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 3, tank = { unit = {}, deficit = 1000 } }), "LGChain should not match when LG >= 2.5s")

-- Out of combat -> should NOT match
assert_false(lg_chain.matches({ in_combat = false, settings = {} }, { lights_grace_remains = 2, tank = { unit = {}, deficit = 1000 } }), "LGChain should not match out of combat")

-- No tank -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 2, tank = nil }), "LGChain should not match without tank")

-- Tank with zero deficit -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 2, tank = { unit = {}, deficit = 0 } }), "LGChain should not match when tank full")

-- Valid: LG active, <2.5s, in combat, tank with deficit -> should match
assert_true(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 2, tank = { unit = {}, deficit = 1000 } }), "LGChain should match in valid conditions")

-- Valid edge: LG at 0.1s -> should match
assert_true(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 0.1, tank = { unit = {}, deficit = 500 } }), "LGChain should match at 0.1s remaining")

-- ============================================================================
-- Holy Light deficit-fit (2026-09-16): smallest covering rank via the shared
-- hook, fail-closed to the legacy R11/R9/R7/R4 bands. Live NS lookup so the
-- hook is injected post-load here.
-- ============================================================================

local NS_T = _G.EaxRotations
NS_T.HOLY_LIGHT_RANKS = { { spell = "HL_FAKE_LADDER", label = "R11" } }
NS_T.HealValue = { pick_castable = function() return nil end }
local FIT_SPELL = "HL_FIT_R7"
local hook_calls = 0
NS_T.cast_best_heal_rank = function(ranks, target, context, label)
    hook_calls = hook_calls + 1
    assert_true(ranks == NS_T.HOLY_LIGHT_RANKS, "fit receives the shared HL ladder")
    assert_eq(label, "Holy Light", "fit label")
    return FIT_SPELL, "Holy Light R7"
end

local hle = find_strategy("HolyLightEmergency")
local function hle_state(deficit)
    return { lowest = { unit = {}, effective_hp = 40, hp = 40, deficit = deficit } }
end

-- Fit used: mid-rank spell wins over the R9 band (hp 40 / deficit 1500).
hook_calls = 0
local s_fit = hle_state(1500)
assert_true(hle.matches({ settings = {} }, s_fit), "HolyLightEmergency should match at hp 40")
assert_eq(s_fit.holy_light_spell, FIT_SPELL, "deficit-fit rank replaces the R9 band")
assert_eq(s_fit.holy_light_label, "Holy Light R7", "fit label threads through")
assert_eq(hook_calls, 1, "hook attempted once")

-- Fail-closed: hook returns nil -> legacy R9 band (hp 40 / deficit 1500).
NS_T.cast_best_heal_rank = function() return nil end
local s_fb = hle_state(1500)
assert_true(hle.matches({ settings = {} }, s_fb), "HolyLightEmergency should match on fit miss")
assert_eq(s_fb.holy_light_label, "Holy Light R9", "fit miss falls back to the R9 band")

-- Explicit rank mode always wins, even when the fit is available.
NS_T.cast_best_heal_rank = function() return FIT_SPELL, "Holy Light R7" end
local s_exp = hle_state(1500)
assert_true(hle.matches({ settings = { holy_light_rank = "rank4" } }, s_exp), "HolyLightEmergency should match in rank4 mode")
assert_eq(s_exp.holy_light_label, "Holy Light R4", "explicit rank4 bypasses the fit")

-- Unreadable deficit: hook never attempted, legacy band answers.
hook_calls = 0
local hook_probe = NS_T.cast_best_heal_rank
NS_T.cast_best_heal_rank = function(...) hook_calls = hook_calls + 1; return hook_probe(...) end
local s_zero = hle_state(0)
assert_true(hle.matches({ settings = {} }, s_zero), "HolyLightEmergency should match at hp 40 / zero deficit")
assert_eq(s_zero.holy_light_label, "Holy Light R9", "zero deficit keeps the hp band")
assert_eq(hook_calls, 0, "hook skipped when deficit is unreadable")

-- ============================================================================
-- Flash of Light deficit-fit (2026-09-16): smallest covering FoL rank via the
-- shared hook over the 7-rank ladder; conserve/max bands stay as fail-closed
-- fallback. Public practice: Warcraft Tavern TBC ("experiment with different
-- ranks of Holy Light and Flash of Light ... do just enough healing"),
-- wowtbc.gg ("Downrank if necessary for mana"). No TBC holy sim exists, so
-- the hook's own math pins carry it.
-- ============================================================================

NS_T.FLASH_OF_LIGHT_RANKS = { { spell = "FOL_FAKE_LADDER", label = "R7" } }
local FIT_FOL = "FOL_FIT_R4"
local fol_hook_calls = 0
local fol_fit_enabled = true
NS_T.cast_best_heal_rank = function(ranks, target, context, label)
    if ranks == NS_T.HOLY_LIGHT_RANKS then return nil end
    assert_true(ranks == NS_T.FLASH_OF_LIGHT_RANKS, "FoL fit receives the shared FoL ladder")
    assert_eq(label, "Flash of Light", "FoL fit label")
    fol_hook_calls = fol_hook_calls + 1
    if not fol_fit_enabled then return nil end
    return FIT_FOL, "Flash of Light R4"
end

local smart_heal = find_strategy("SmartHeal")
local function fol_state(hp, deficit, mana)
    return { mana_pct = mana or 100, lowest = { unit = {}, effective_hp = hp, hp = hp, deficit = deficit } }
end

-- Fit used in the flash zone (hp 80, deficit 300: below the HL 70/900 bar).
fol_hook_calls = 0
local s_fol = fol_state(80, 300)
assert_true(smart_heal.matches({ settings = {} }, s_fol), "SmartHeal should match in the flash zone")
assert_eq(s_fol.heal_spell, FIT_FOL, "deficit-fit FoL replaces max R7")
assert_eq(s_fol.heal_label, "Flash of Light R4", "FoL fit label threads through")
assert_eq(fol_hook_calls, 1, "FoL hook attempted once")

-- Fail-closed: hook misses -> max R7.
fol_fit_enabled = false
local s_fol_fb = fol_state(80, 300)
assert_true(smart_heal.matches({ settings = {} }, s_fol_fb), "SmartHeal should match on FoL fit miss")
assert_eq(s_fol_fb.heal_label, "Flash of Light R7", "FoL fit miss falls back to R7")

-- Conserve band preserved: hook misses + low mana -> R6 conserve.
local s_fol_cons = fol_state(80, 300, 10)
assert_true(smart_heal.matches({ settings = {} }, s_fol_cons), "SmartHeal should match at low mana")
assert_eq(s_fol_cons.heal_label, "Flash of Light R6 conserve", "conserve band survives the fit")

-- Zero deficit + low mana: hook never attempted, conserve answers directly.
fol_hook_calls = 0
local s_fol_zero = fol_state(80, 0, 10)
assert_true(smart_heal.matches({ settings = {} }, s_fol_zero), "SmartHeal should match at zero deficit")
assert_eq(s_fol_zero.heal_label, "Flash of Light R6 conserve", "zero deficit keeps the conserve band")
assert_eq(fol_hook_calls, 0, "FoL hook skipped when deficit is unreadable")

-- HL-overheal fallthrough routes through the same fit (single FoL path).
fol_fit_enabled = true
NS_T.HealerDeficit = { gate_spell_overheal = function(spell_key) return spell_key == "HolyLight" end }
local s_fol_thru = fol_state(60, 1000)
assert_true(smart_heal.matches({ settings = {} }, s_fol_thru), "SmartHeal should match when HL overheats")
assert_eq(s_fol_thru.heal_spell, FIT_FOL, "HL fallthrough uses the FoL fit, not hardcoded R7")
NS_T.HealerDeficit = nil

print("PASS test_paladin_holy_custom_matches")
