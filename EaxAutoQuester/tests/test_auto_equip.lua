-- What: Unit tests for EaxAutoQuester/equipment_compare_sylvanas.lua, plus S10, which pins
--       where its caller gets the equipped item's quality from.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify slot classification and equipment upgrade heuristic
-- Scenarios: S1 empty, S2 upgrade, S3 downgrade, S4 type mismatch, S5 keyword bonus, S6 classifier names,
--            S6a authoritative client slots and deterministic classifier order, S6b stable paired-slot tie,
--            S10 auto_equip_best_reward's item-info source, S13 real slot override, S14 real deferred tie
-- S10 fails if that source is an undeclared global again: the equipped quality then reads 0
-- and the quality-1 downgrade wins.
-- Safety: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local ok, eq = pcall(require, "equipment_compare_sylvanas")
assert(ok, "equipment_compare_sylvanas module must load without error")
assert(eq ~= nil, "module must return a value")
assert(type(eq.classify_slot) == "function", "classify_slot must be a function")
assert(type(eq.should_equip) == "function", "should_equip must be a function")

-- ============================================================================
-- S6: Classifier Sanity
-- ============================================================================

assert(eq.classify_slot("Hood of the Whelpling") == "HEAD",
    "classify_slot 'Hood of the Whelpling' → HEAD")
assert(eq.classify_slot("Bracers of the Bear") == "WRIST",
    "classify_slot 'Bracers of the Bear' → WRIST")
assert(eq.classify_slot("Battle Axe") == "WEAPON_MAIN",
    "classify_slot 'Battle Axe' → WEAPON_MAIN")
assert(eq.classify_slot("Cured Leather Tunic") == "CHEST",
    "classify_slot 'Cured Leather Tunic' → CHEST")
assert(eq.classify_slot("Worn Sword") == "WEAPON_MAIN",
    "classify_slot 'Worn Sword' → WEAPON_MAIN")
assert(eq.classify_slot("Knight's Gauntlets") == "HANDS",
    "classify_slot \"Knight's Gauntlets\" → HANDS")
assert(eq.classify_slot("Pauldrons of Might") == "SHOULDERS",
    "classify_slot 'Pauldrons of Might' → SHOULDERS")
assert(eq.classify_slot("Leggings of the Fang") == "LEGS",
    "classify_slot 'Leggings of the Fang' → LEGS")
assert(eq.classify_slot("Old Blunderbuss") == "RANGED",
    "classify_slot 'Old Blunderbuss' → RANGED")
assert(eq.classify_slot("Wooden Shield") == "WEAPON_OFF",
    "classify_slot 'Wooden Shield' → WEAPON_OFF")

-- The name fallback has an explicit first-match order, even when a name
-- contains more than one existing keyword.
assert(eq.classify_slot("Shadowcraft Cap of the Axe") == "HEAD",
    "S6a: overlapping name keywords use the declared slot order")

-- Client-provided data wins over display-name inference.
assert(eq.classify_slot("Mystery Relic", "INVEQUIPLOC_FINGER") == "FINGER",
    "S6a: quest item equip_loc must classify an otherwise-unknown name")
assert(eq.classify_slot("Worn Sword", nil, 3) == "SHOULDERS",
    "S6a: equipped row slot_id must classify a misleading name")
assert(eq.classify_slot("Worn Sword", "CHEST", 24) == nil,
    "S6a: non-equipment inventory positions must not enter comparison")

-- Paired client slots use the lowest INVSLOT_* consistently, not list order.
local paired_rows_s6b = {
    { slot_id = 12, name = "Worn Sword", quality = 1 },
    { slot_id = 11, name = "Worn Sword", quality = 2 },
}
local s6_equip, s6_slot = eq.should_equip("Worn Sword", 2, paired_rows_s6b, "FINGER")
assert(s6_equip == false,
    "S6b: equal quality against stable slot 11 must not replace it")
paired_rows_s6b = {
    { slot_id = 11, name = "Worn Sword", quality = 2 },
    { slot_id = 12, name = "Worn Sword", quality = 1 },
}
s6_equip, s6_slot = eq.should_equip("Worn Sword", 2, paired_rows_s6b, "FINGER")
assert(s6_equip == false,
    "S6b: reversing the client list must not change the paired-slot decision")

-- ============================================================================
-- S1: Empty equipped list — should equip, no slot to replace
-- ============================================================================

local equip, slot = eq.should_equip("Superior Tunic", 3, {})
assert(equip == true, "S1: empty equipped → should_equip=true")
assert(slot == nil, "S1: empty equipped → slot_to_replace=nil")

-- ============================================================================
-- S2: Upgrade same type (quality higher)
-- Equipped: "Tunic of the Bear" (Common, q=2, CHEST)
-- Candidate: "Superior Tunic" (Uncommon, q=3, CHEST)
-- ============================================================================

local equipped_s2 = {
    { slot = "CHEST", name = "Tunic of the Bear", quality = 2 },
}
equip, slot = eq.should_equip("Superior Tunic", 3, equipped_s2)
assert(equip == true, "S2: upgrade same type → should_equip=true")
assert(slot == "CHEST", "S2: upgrade same type → slot_to_replace=CHEST, got " .. tostring(slot))

-- ============================================================================
-- S3: Downgrade same type (quality lower)
-- Equipped: "Cured Leather Tunic" (Uncommon, q=3, CHEST)
-- Candidate: "Cheap Cloth Tunic" (Common, q=1, CHEST)
-- ============================================================================

local equipped_s3 = {
    { slot = "CHEST", name = "Cured Leather Tunic", quality = 3 },
}
equip, slot = eq.should_equip("Cheap Cloth Tunic", 1, equipped_s3)
assert(equip == false, "S3: downgrade same type → should_equip=false")

-- ============================================================================
-- S4: Different types — candidate slot (CHEST) not in equipped list
-- Equipped: "Worn Sword" (Common, q=2, WEAPON_MAIN)
-- Candidate: "Haste Cloth Robe" (Rare, q=4, CHEST) — no CHEST in equipped
-- Result: empty CHEST slot → equip without replacement
-- ============================================================================

local equipped_s4 = {
    { slot = "WEAPON_MAIN", name = "Worn Sword", quality = 2 },
}
equip, slot = eq.should_equip("Haste Cloth Robe", 4, equipped_s4)
assert(equip == true, "S4: no CHEST in equipped → should_equip=true")
assert(slot == nil, "S4: no CHEST in equipped → slot_to_replace=nil")

-- ============================================================================
-- S5: Keyword bonus — "Knight" in name triggers equip even at same quality
-- Equipped: "Cured Leather Gloves" (Uncommon, q=3, HANDS)
-- Candidate: "Knight's Gauntlets" (Uncommon, q=3, HANDS)
-- ============================================================================

local equipped_s5 = {
    { slot = "HANDS", name = "Cured Leather Gloves", quality = 3 },
}
equip, slot = eq.should_equip("Knight's Gauntlets", 3, equipped_s5)
assert(equip == true, "S5: keyword bonus (Knight) → should_equip=true")
assert(slot == "HANDS", "S5: keyword bonus → slot_to_replace=HANDS, got " .. tostring(slot))

-- ============================================================================
-- S5b: Same quality without keyword bonus → no equip
-- ============================================================================

equip, slot = eq.should_equip("Simple Cloth Gloves", 3, equipped_s5)
assert(equip == false, "S5b: same quality no keyword → should_equip=false")

-- ============================================================================
-- S5c: Keyword bonus on higher quality → still works (quality > bonus case)
-- Equipped: "Cured Leather Gloves" (Common, q=2, HANDS)
-- Candidate: "Knight's Gauntlets" (Uncommon, q=3, HANDS)
-- ============================================================================

local equipped_s5c = {
    { slot = "HANDS", name = "Cured Leather Gloves", quality = 2 },
}
equip, slot = eq.should_equip("Knight's Gauntlets", 3, equipped_s5c)
assert(equip == true, "S5c: higher quality + keyword → should_equip=true")
assert(slot == "HANDS", "S5c: higher quality + keyword → slot_to_replace=HANDS")

-- ============================================================================
-- S7: Nil-guard — nil name or quality returns false
-- ============================================================================

equip, slot = eq.should_equip(nil, 3, {})
assert(equip == false, "S7: nil name → false")

equip, slot = eq.should_equip("Superior Tunic", nil, {})
assert(equip == false, "S7: nil quality → false")

equip, slot = eq.should_equip("Superior Tunic", 3, nil)
assert(equip == false, "S7: nil equipped list → false")

-- ============================================================================
-- S8: Empty slot for that type (other slots equipped)
-- Equipped: legs item, candidate is chest piece
-- ============================================================================

local equipped_s8 = {
    { slot = "LEGS", name = "Leggings of the Bear", quality = 2 },
}
equip, slot = eq.should_equip("Superior Tunic", 3, equipped_s8)
assert(equip == true, "S8: candidate slot empty in equipped list → should_equip=true")
assert(slot == nil, "S8: candidate slot empty → slot_to_replace=nil")

-- ============================================================================
-- S9: Unclassified item name → should not crash, returns false
-- Names without any slot keyword (no helm/cap/robe/boot etc.)
-- ============================================================================

equip, slot = eq.should_equip("Crushed Soulspinner", 5, {})
assert(equip == false, "S9: unclassified name → false")

-- ============================================================================
-- S10: what the caller actually compares against — quest_interaction_sylvanas
-- auto_equip_best_reward() reads the EQUIPPED item's quality through the documented
-- core.quests.get_item_info. That read used to be an undeclared global (`_get_item_info`),
-- so the lookup always failed and every equipped item compared as quality 0 — every reward
-- with quality >= 1 then looked like an upgrade. This scenario is the load-bearing pin:
-- the equipped chest is quality 3, the FIRST reward choice is quality 1 (a downgrade) and
-- the SECOND is quality 4 (an upgrade), so only the second may be taken.
-- ============================================================================

do
    mock.reset()

    local equipped_obj = mock.create_object({
        pos = { x = 0, y = 0, z = 0 },
        name = "Cured Leather Tunic",
        item_id = 1001,
    })
    mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        equipped = { { object = equipped_obj, slot_id = 5 } },
    })

    mock._item_info[1001] = {
        name = "Cured Leather Tunic", quality = 3, equip_loc = "CHEST",
    }
    mock._quest_rewards[1] = { link = "item:2002" }
    mock._item_info["item:2002"] = {
        name = "Cheap Cloth Tunic", quality = 1, equip_loc = "CHEST",
    }
    mock._quest_rewards[2] = { link = "item:2003" }
    mock._item_info["item:2003"] = {
        name = "Superior Tunic", quality = 4, equip_loc = "CHEST",
    }

    local qi = require("quest_interaction_sylvanas")
    assert(type(qi.auto_equip_best_reward) == "function",
        "S10 FAIL: quest_interaction_sylvanas.auto_equip_best_reward must exist")

    mock._input_calls = {}
    qi.auto_equip_best_reward()

    local taken = nil
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "get_quest_reward" then taken = call[2] end
    end
    assert(taken == 2,
        "S10 FAIL: the equipped item's quality must come from the documented get_item_info, so " ..
        "only choice 2 (quality 4 > equipped 3) may be taken; took " .. tostring(taken))
    print("S10 PASS: auto_equip reads equipped quality from core.quests.get_item_info")
end

-- S11: the selected reward reaches bags and is equipped with the helper-owned bag pair.
do
    mock.install_inventory_helper()
    local reward = mock.create_object({ name = "Superior Tunic", item_id = 2003 })
    mock._bag_items[0] = { { object = reward, slot_id = 300 } }
    mock._input_calls = {}

    local qi = require("quest_interaction_sylvanas")
    qi.process_auto_equip()

    local equip
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "use_container_item" then equip = call end
    end
    assert(equip and equip[2] == 0 and equip[3] == 8,
        "S11 FAIL: reward equip must use inventory_helper's (bag_id, bag_slot), got " ..
        tostring(equip and equip[2]) .. "/" .. tostring(equip and equip[3]))
    print("S11 PASS: selected reward is equipped through the helper bag/slot pair")
end

-- S12a: the quest-item fallback names the item ID, never a raw inventory slot pair.
do
    local qim = require("quest_item_manager_sylvanas")
    local old_use_item = core.input.use_item
    local old_use_target = core.input.use_item_target
    local old_use_position = core.input.use_item_position
    core.input.use_item = function() error("blocked") end
    core.input.use_item_target = function() error("blocked") end
    core.input.use_item_position = function() error("blocked") end
    mock._input_calls = {}
    local item_object = mock.create_object({ name = "Test Item", item_id = 12345 })
    local attempted = qim.use_quest_item({ item_id = 12345, name = "Test Item", object = item_object }, "target")
    core.input.use_item = old_use_item
    core.input.use_item_target = old_use_target
    core.input.use_item_position = old_use_position
    assert(attempted == false, "S12a FAIL: a blocked quest-item use must report failure")
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "use_container_item",
            "S12a FAIL: quest-item fallback regressed to raw container-slot use")
    end
    print("S12a PASS: quest-item fallback uses the item ID and never raw container slots")
end

-- S12: a bind-on-equip event is answered only while this module owns the pending equip.
do
    local bridge = require("quest_frame_events_sylvanas")
    local qi = require("quest_interaction_sylvanas")
    mock._input_calls = {}
    bridge.on_game_event("AUTOEQUIP_BIND_CONFIRM", { 4 })
    assert(qi.process_auto_equip() == true,
        "S12 FAIL: the pending reward equip must release its own bind prompt")
    local confirmed
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "equip_pending_item" then confirmed = call[2] end
    end
    assert(confirmed == 4, "S12 FAIL: expected equip_pending_item(4), got " .. tostring(confirmed))    print("  S12 PASS: bind-on-equip confirmation is owned and released once")
end

-- S12b: a prompt raised by the player while no reward equip is pending is left alone.
do
    local bridge = require("quest_frame_events_sylvanas")
    local qi = require("quest_interaction_sylvanas")
    mock._input_calls = {}
    bridge.on_game_event("AUTOEQUIP_BIND_CONFIRM", { 4 })
    assert(qi.process_auto_equip() == false,
        "S12b FAIL: an unowned bind prompt must not be answered")
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "equip_pending_item",
            "S12b FAIL: player-originated equip prompt was answered")
    end
    print("S12b PASS: player-originated bind prompt is left alone")
end

-- S13: the real selected-reward path trusts client slot data over both names.
do
    mock.reset()
    mock.install_inventory_helper()

    local equipped = mock.create_object({
        name = "Hood of the Whelpling", item_id = 3101,
    })
    mock.create_player({
        equipped = { { object = equipped, slot_id = 1 } },
    })
    mock._item_info[3101] = {
        name = "Hood of the Whelpling", quality = 4, equip_loc = "HEAD",
    }

    local reward = mock.create_object({ name = "Worn Sword", item_id = 3102 })
    mock._quest_rewards[1] = { link = "item:3102" }
    mock._item_info["item:3102"] = {
        item_id = 3102, name = "Worn Sword", quality = 3,
        equip_loc = "HEAD", sell_price = 5,
    }
    mock._bag_items[0] = { { object = reward, slot_id = 301 } }
    mock._input_calls = {}

    local qi = require("quest_interaction_sylvanas")
    assert(qi.select_best_reward() == "best_reward:1(5c)",
        "S13 FAIL: the real reward selector must still select the offered reward")
    assert(qi.process_auto_equip() == false,
        "S13 FAIL: a lower-quality HEAD reward must be rejected using slot_id/equip_loc")
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "use_container_item",
            "S13 FAIL: slot-mismatched reward was equipped through the real deferred path")
    end
    print("S13 PASS: real auto-equip uses client slot data over misleading names")
end

-- S14: equal-quality comparison is stable when the client returns paired slots
-- in either order. The candidate is not a keyword-bonus upgrade.
do
    local qi = require("quest_interaction_sylvanas")
    for _, first_slot in ipairs({ 12, 11 }) do
        mock.reset()
        mock.install_inventory_helper()

        local slot11 = mock.create_object({ name = "Worn Sword", item_id = 3201 })
        local slot12 = mock.create_object({ name = "Worn Sword", item_id = 3202 })
        mock._item_info[3201] = {
            name = "Worn Sword", quality = 2, equip_loc = "FINGER",
        }
        mock._item_info[3202] = {
            name = "Worn Sword", quality = 1, equip_loc = "FINGER",
        }
        local equipped
        if first_slot == 12 then
            equipped = {
                { object = slot12, slot_id = 12 },
                { object = slot11, slot_id = 11 },
            }
        else
            equipped = {
                { object = slot11, slot_id = 11 },
                { object = slot12, slot_id = 12 },
            }
        end
        mock.create_player({ equipped = equipped })

        local reward = mock.create_object({ name = "Worn Sword", item_id = 3203 })
        mock._quest_rewards[1] = { link = "item:3203" }
        mock._item_info["item:3203"] = {
            item_id = 3203, name = "Worn Sword", quality = 2,
            equip_loc = "FINGER", sell_price = 5,
        }
        mock._bag_items[0] = { { object = reward, slot_id = 302 } }
        mock._input_calls = {}

        assert(qi.select_best_reward() == "best_reward:1(5c)",
            "S14 FAIL: the real reward selector changed during equipment comparison")
        assert(qi.process_auto_equip() == false,
            "S14 FAIL: an equal-quality reward replaced stable slot 11")
        for _, call in ipairs(mock._input_calls) do
            assert(call[1] ~= "use_container_item",
                "S14 FAIL: an incidental equipped-row order changed the real equip decision")
        end
    end
    print("S14 PASS: real deferred auto-equip breaks paired-slot ties deterministically")
end

print("PASS test_auto_equip")

os.exit(0)
