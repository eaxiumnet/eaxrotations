-- test_gear_score_regression.lua — pins shared/gear_score_sylvanas.lua.
-- WHAT:  Exercises the gear-score calculator: estimate_item_level boundary
--        arithmetic (the TBC item-ID ranges), scan()'s slot scoring (weight x
--        estimated ilevel), weak/missing slot detection, tier classification
--        from average ilevel (incl. the below-preraid / above-sunwell clamps),
--        get_score / get_weak_slots / get_full_audit aggregation, and
--        get_consumable_status's buff batching + weapon-imbue scoring. The
--        module is live in main.lua and weapon_imbue_sylvanas and previously
--        had ZERO test references.
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to the ilevel ranges, slot weights, tier thresholds, or
--        consumable scoring could silently mis-rate gear in the UI; this test
--        fails on regressions in the arithmetic.
-- SAFETY: Pure unit test. The module caches NS at load, so a mock NS is
--        installed BEFORE dofile. tbc_data_sylvanas is stubbed via
--        package.preload with a known BUFFS table so the consumable batching
--        is driven deterministically. The real SDK is never touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function assert_close(a, b, label)
    if math.abs(a - b) > 1e-9 then
        error((label or "assert_close") .. ": expected " .. tostring(b) .. " +/- 1e-9, got " .. tostring(a), 2)
    end
end

-- Deterministic TBC buff data: flasks={1,2}, food={3}, battle={4},
-- guardian={5,6}. Stubbed BEFORE dofile so the module's pcall(require,
-- "shared/tbc_data_sylvanas") picks it up (and the real module, possibly
-- cached by another suite, can't shadow it).
package.loaded["shared/tbc_data_sylvanas"] = nil
package.preload["shared/tbc_data_sylvanas"] = function()
    return {
        BUFFS = {
            flasks = { 1, 2 },
            food = { 3 },
            battle_elixirs = { 4 },
            guardian_elixirs = { 5, 6 },
        },
    }
end

-- Mock NS: get_equipped_item_id drives the slot population; has_buff answers
-- batch membership checks; WeaponImbueManager is added per section.
local equipped = {}
local has_buff_impl = function(me, ids) return false end
local weapon_status = nil

local NS = {
    get_equipped_item_id = function(slot) return equipped[slot] end,
    has_buff = function(me, ids) return has_buff_impl(me, ids) end,
}
_G.EaxRotations = NS

local gs = dofile("EaxRotations/shared/gear_score_sylvanas.lua")
assert_true(type(gs) == "table", "gear_score must load under mock NS")
assert_eq(NS.GearScore, gs, "module registers itself as NS.GearScore")

-- ---------------------------------------------------------------------------
-- 1. estimate_item_level boundary arithmetic (TBC item-ID ranges)
-- ---------------------------------------------------------------------------
assert_eq(gs.estimate_item_level(nil), 80, "nil item id estimates 80")
assert_eq(gs.estimate_item_level("abc"), 80, "non-number item id estimates 80")
assert_eq(gs.estimate_item_level(19999), 80, "Classic range (< 20000)")
assert_eq(gs.estimate_item_level(20000), 90, "Early TBC lower bound")
assert_eq(gs.estimate_item_level(23999), 90, "Early TBC upper bound")
assert_eq(gs.estimate_item_level(24000), 100, "Mid TBC lower bound")
assert_eq(gs.estimate_item_level(27999), 100, "Mid TBC upper bound")
assert_eq(gs.estimate_item_level(28000), 115, "Late TBC Kara lower bound")
assert_eq(gs.estimate_item_level(31999), 115, "Late TBC Kara upper bound")
assert_eq(gs.estimate_item_level(32000), 125, "T5 lower bound")
assert_eq(gs.estimate_item_level(32999), 125, "T5 upper bound")
assert_eq(gs.estimate_item_level(33000), 135, "T6 lower bound")
assert_eq(gs.estimate_item_level(33999), 135, "T6 upper bound")
assert_eq(gs.estimate_item_level(34000), 145, "T6.5 lower bound")
assert_eq(gs.estimate_item_level(34999), 145, "T6.5 upper bound")
assert_eq(gs.estimate_item_level(35000), 155, "Sunwell lower bound")
assert_eq(gs.estimate_item_level(99999), 155, "above Sunwell clamps to 155")

-- ---------------------------------------------------------------------------
-- 2. scan with NO equipped items
-- ---------------------------------------------------------------------------
equipped = {}
local empty = gs.scan()
assert_eq(empty.total_score, 0, "no items -> zero score")
assert_eq(empty.tier, "unknown", "no items -> unknown tier")
assert_eq(empty.avg_ilevel, 0, "no items -> zero average")
local missing_count = 0
for _ in pairs(empty.missing_slots) do missing_count = missing_count + 1 end
assert_eq(missing_count, 17, "all 17 inventory slots reported missing")
local item_count = 0
for _ in pairs(empty.items) do item_count = item_count + 1 end
assert_eq(item_count, 0, "no items populated")

-- ---------------------------------------------------------------------------
-- 3. scan with a full kit of T6 items (id 33000 -> ilevel 135)
-- ---------------------------------------------------------------------------
equipped = {}
for _, slot in ipairs({ "HEAD", "NECK", "SHOULDER", "CHEST", "WAIST", "LEGS", "FEET", "WRIST",
    "HANDS", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2", "BACK", "MAIN_HAND", "OFF_HAND", "RANGED" }) do
    equipped[slot] = 33000
end
local kit = gs.scan()
assert_eq(kit.items.HEAD.estimated_ilevel, 135, "slot item estimated ilevel")
assert_close(kit.items.HEAD.score, 135, "HEAD score = 135 x weight 1.0")
assert_close(kit.items.MAIN_HAND.score, 135 * 1.5, "MAIN_HAND score = 135 x 1.5")
assert_close(kit.items.NECK.score, 135 * 0.6, "NECK score = 135 x 0.6")
assert_close(kit.total_score, 135 * 13.8, "total = 135 x sum(17 slot weights)")
local weak = 0
for _ in pairs(kit.weak_slots) do weak = weak + 1 end
assert_eq(weak, 0, "T6 kit has no weak slots (ilevel >= 110)")
assert_eq(kit.tier, "t5", "avg ilevel 135 classifies as t5 (125-138)")
assert_eq(kit.avg_ilevel, 135, "average item level 135")

-- ---------------------------------------------------------------------------
-- 4. Weak slot detection (a Classic item at 80 in one slot)
-- ---------------------------------------------------------------------------
equipped = {}
for _, slot in ipairs({ "HEAD", "CHEST", "LEGS" }) do equipped[slot] = 33000 end
equipped.FEET = 19999  -- ilevel 80 -> weak
local mixed = gs.scan()
assert_eq(mixed.items.FEET.score, 80 * 0.8, "weak slot scored at its own ilevel")
assert_eq(mixed.weak_slots.FEET.estimated_ilevel, 80, "weak slot flagged with its ilevel")
assert_true(mixed.weak_slots.HEAD == nil, "strong slot not flagged")
assert_close(mixed.avg_ilevel, (135 * 3 + 80) / 4, "average over 4 equipped slots")

-- ---------------------------------------------------------------------------
-- 5. Tier clamps: below preraid -> preraid; above sunwell -> sunwell
-- ---------------------------------------------------------------------------
equipped = { HEAD = 19999, CHEST = 19999 }
local low = gs.scan()
assert_eq(low.tier, "preraid", "avg 80 clamps to preraid (below the min range)")
equipped = { HEAD = 99999, CHEST = 99999 }
local high = gs.scan()
assert_eq(high.tier, "sunwell", "avg 155 clamps to sunwell (above the max range)")

-- ---------------------------------------------------------------------------
-- 6. get_score / get_weak_slots
-- ---------------------------------------------------------------------------
equipped = { HEAD = 33000, CHEST = 19999 }
local score, scan_result = gs.get_score()
assert_eq(score, 135 + 80, "get_score returns the total")
assert_eq(scan_result.weak_slots.CHEST.estimated_ilevel, 80, "get_score scan carries weak slots")
local weaks, scan2 = gs.get_weak_slots()
assert_true(weaks.HEAD == nil and weaks.CHEST ~= nil, "get_weak_slots returns only weak slots")

-- ---------------------------------------------------------------------------
-- 7. get_consumable_status: buff batching + scoring + clamp
-- ---------------------------------------------------------------------------
assert_eq(gs.get_consumable_status().score, 0, "no NS context -> zero status")
assert_eq(gs.get_consumable_status({ me = nil }).score, 0, "no me -> zero status")

-- No buffs match -> score 0, all flags false.
local none = gs.get_consumable_status({ me = {} })
assert_eq(none.score, 0, "no buffs -> zero consumable score")
assert_eq(none.flask, false, "no flask flag")

-- Flasks batch only (id 1 is in flasks={1,2}): +25.
has_buff_impl = function(me, ids)
    for _, id in ipairs(ids) do
        if id == 1 then return true end
    end
    return false
end
local flask_only = gs.get_consumable_status({ me = {} })
assert_eq(flask_only.score, 25, "flask batch scores 25")
assert_eq(flask_only.flask, true, "flask flag set")
assert_eq(flask_only.food, false, "food flag clear")

-- All batches match: 25+15+10+10 = 60.
has_buff_impl = function() return true end
local all = gs.get_consumable_status({ me = {} })
assert_eq(all.score, 60, "flask 25 + food 15 + battle 10 + guardian 10")
assert_eq(all.flask, true, "flask flag")
assert_eq(all.food, true, "food flag")
assert_eq(all.battle_elixir, true, "battle elixir flag")
assert_eq(all.guardian_elixir, true, "guardian elixir flag")

-- Weapon imbue adds 10 (60 + 10 = 70; clamp at 100 unreachable via these
-- categories, pinned as observed).
NS.WeaponImbueManager = {
    get_status = function() return { mh_imbue = true } end,
}
local with_weapon = gs.get_consumable_status({ me = {} })
assert_eq(with_weapon.weapon_buff, true, "weapon buff flag")
assert_eq(with_weapon.score, 70, "60 + 10 weapon imbue")
NS.WeaponImbueManager = nil

-- Throwing get_status is pcall-isolated.
NS.WeaponImbueManager = { get_status = function() error("boom") end }
local throw_weapon = gs.get_consumable_status({ me = {} })
assert_eq(throw_weapon.weapon_buff, false, "throwing weapon status ignored")
assert_eq(throw_weapon.score, 60, "score unchanged by throwing weapon status")
NS.WeaponImbueManager = nil

-- ---------------------------------------------------------------------------
-- 8. get_full_audit: total + parse_ready gate
-- ---------------------------------------------------------------------------
equipped = { HEAD = 33000, CHEST = 33000, LEGS = 33000 }  -- tier t5, gear 135*2.7
has_buff_impl = function() return true end
local audit = gs.get_full_audit({ me = {} })
assert_close(audit.gear_score, 135 * 3, "audit gear score (HEAD+CHEST+LEGS weights)")
assert_eq(audit.consumable_score, 60, "audit consumable score")
assert_close(audit.total_score, 135 * 3 + 60, "audit total score")
assert_eq(audit.tier, "t5", "audit tier")
assert_eq(audit.parse_ready, true, "total >= 70 and tier ~= preraid -> parse ready")

-- preraid tier blocks parse_ready even with consumables pushing total >= 70.
equipped = { HEAD = 19999, CHEST = 19999 }  -- avg 80 -> preraid
local audit_low = gs.get_full_audit({ me = {} })
assert_eq(audit_low.total_score, 160 + 60, "low gear + consumables total")
assert_eq(audit_low.tier, "preraid", "low gear tier")
assert_eq(audit_low.parse_ready, false, "preraid tier -> parse_ready false")

print("PASS test_gear_score_regression")
