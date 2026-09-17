-- assassination_forever.lua — Rogue Assassination delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 assassination delta over the vanilla baseline: MUTILATE (the
--        new 2-combo-point dagger builder — "Instantly attacks with both
--        weapons ... Damage increased by $m4% against Poisoned targets.
--        Awards $m1 Combo Points"), VENOM (the poison-window finisher —
--        "Finishing move that increases the damage of your Poisons by $m2%
--        and your chance to apply Poisons by $m4%. Lasts longer per combo
--        point: 1 point: 9 seconds ... 5 points: 21 seconds") and IMPROVED
--        EXPOSE ARMOR (the talent that makes the armor debuff cheap:
--        "Reduces the Energy cost of your Expose Armor ability by $m1, and
--        refunds $m2 Combo Points when cast with $m3 Combo Points").
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/rogue.md: "Mutilate (NEW): 2-combo-point
--        generator, bonus damage vs poisoned targets — faster CP pace;
--        poisoned-target check becomes a lane gate", "Venom (NEW capstone):
--        spend combo points -> +30% poison damage + 10% poison-application
--        chance, duration scales with CP spent — a spendable burst WINDOW",
--        "Improved Expose Armor: cheaper AND refunds a CP at 5 CP". DBC
--        FINDINGS (1.60.1.69893): Mutilate ladder 1310707@30 / 399956@40 /
--        1241582@50 / 1241584@60 (the @60 row wins the maxrank mirror);
--        effect dump = 2 combo points + two weapon-strike triggers + a 20%
--        dummy vs poisoned (the kit's bonus confirmed); the client text has
--        NO "must be behind" clause (unlike the TBC 34413 row — the Forever
--        Mutilate is positional-free; recorded as an in-game probe). Venom
--        1310703@40: effect rows confirm +30% poison damage (aura 108 x2)
--        and +10% application chance (aura 107) — the kit's numbers exactly.
--        Improved Expose Armor 14168: effect rows confirm -10 energy and a
--        2-CP refund at 5 combo points. The P2 energy-model probe stays
--        unconfirmed (tick-pulse regen), so the delta keeps the vanilla
--        energy shape: builders gate on the real cost (60), finishers use
--        the baseline's pooling flag.
-- SAFETY: ZERO numeric spell-ID literals — Mutilate, Venom and Improved
--        Expose Armor resolve BY NAME through the bridge mirrors; the poison
--        and Expose Armor debuff reads use the bridge buff mirror and the
--        class-map ladder. A nil lookup leaves the lane dormant — never a
--        guessed ID. The vanilla baseline is loaded through an intercepted
--        registration (affliction/demonology_forever template) so this file
--        edits nothing in assassination_vanilla.lua and its safe_state-backed
--        get_state is reused unchanged. The Mutilate lane mirrors the TBC
--        sibling's dagger eligibility (both hands, shared/dagger_set) and
--        reports the poisoned state in its tag without gating on it — 2 CP
--        beats Sinister Strike's 1 CP even unbuffed (the DBC text makes the
--        poison bonus damage, not a usability requirement). Splice geometry:
--        Mutilate leads the builder ("LevelingSinisterStrike"), Venom leads
--        the finisher block ("SliceAndDice") and Improved Expose Armor sits
--        directly above the baseline's "ExposeArmor" lane.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.RogueSpells or {}

-- Dagger eligibility for Mutilate (mirrors assassination_sylvanas.lua:224).
local _dagger_ok, dagger_set = pcall(require, "shared/dagger_set_sylvanas")
if not _dagger_ok or type(dagger_set) ~= "table" then dagger_set = nil end

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "assassination"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] rogue assassination delta: rotation_registry unavailable", 0)
end
local original_register = registry.register
local baseline = nil
registry.register = function(self, name, strategies, options)
    registry.register = original_register
    baseline = { name = name, strategies = strategies, options = options or {} }
    return true
end
-- Force baseline re-execution so its registration always reaches the
-- interceptor above, even if some earlier require() cached the module.
package.loaded["classes/rogue/assassination_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/rogue/assassination_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] rogue assassination delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- casts resolve the maxrank mirror, the learn gates read both mirrors and
-- the buff/debuff reads the buff mirror. A nil lookup leaves the lane
-- dormant -- never a guessed ID. Sentinel stand-ins are seeded per mirror by
-- the battery's build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_name = (ForeverBridge
    and type(ForeverBridge.spell_index_by_name_forever) == "table")
    and ForeverBridge.spell_index_by_name_forever or {}
local by_maxrank = (ForeverBridge
    and type(ForeverBridge.spell_maxrank_by_name_forever) == "table")
    and ForeverBridge.spell_maxrank_by_name_forever or {}
local by_buff = (ForeverBridge
    and type(ForeverBridge.spell_buff_by_name_forever) == "table")
    and ForeverBridge.spell_buff_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local MUTILATE = resolve_id(by_maxrank, "Mutilate")
local MUTILATE_R1 = resolve_id(by_name, "Mutilate")
local VENOM = resolve_id(by_maxrank, "Venom")
local VENOM_BUFF = resolve_id(by_buff, "Venom")
local IMPROVED_EXPOSE_ARMOR = resolve_id(by_name, "Improved Expose Armor")
local EXPOSE_ARMOR = resolve_id(by_maxrank, "Expose Armor")
local EXPOSE_ARMOR_IDS = (SPELLS.ExposeArmor and SPELLS.ExposeArmor._meta
    and SPELLS.ExposeArmor._meta.ids) or nil
local POISON_IDS = {
    resolve_id(by_buff, "Deadly Poison"),
    resolve_id(by_buff, "Crippling Poison"),
    resolve_id(by_buff, "Wound Poison"),
}

-- ---------------------------------------------------------------------------
-- Shared helpers. Mutilate's base cost is 60 energy (the TBC sibling's
-- constant; the Forever effect dump carries no power cost), Venom is a
-- finisher that rides the baseline's pooling flag.
-- ---------------------------------------------------------------------------
local MUTILATE_ENERGY = 60
local VENOM_REFRESH = 4
local EA_REFRESH = 4

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function knows_any(id_a, id_b)
    if type(NS.is_spell_learned) ~= "function" then return false end
    for _, id in ipairs({ id_a, id_b or id_a }) do
        if type(id) == "number" then
            local ok, learned = pcall(NS.is_spell_learned, id)
            if ok and learned == true then return true end
        end
    end
    return false
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function debuff_up(target, ids)
    if not target or type(NS.debuff_up) ~= "function" then return false end
    local ok, up = pcall(NS.debuff_up, target, ids)
    return ok and up == true
end

-- Player-buff idiom (mirrors the baseline's Slice-and-Dice reads).
local function player_buff_up(id)
    if not id then return false end
    if type(NS.has_player_buff) == "function" then
        local ok, up = pcall(NS.has_player_buff, id)
        if ok then return up == true end
    end
    if type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, NS.PLAYER_UNIT, id)
    return ok and up == true
end

local function player_buff_remains(id)
    if not id or type(NS.buff_remains) ~= "function" then return 0 end
    local ok, remains = pcall(NS.buff_remains, NS.PLAYER_UNIT, id)
    if ok and type(remains) == "number" then return remains end
    return 0
end

local function debuff_remains(target, ids)
    if not target or not ids or type(NS.debuff_remains) ~= "function" then return 0 end
    local ok, remains = pcall(NS.debuff_remains, target, ids)
    if ok and type(remains) == "number" then return remains end
    return 0
end

-- Dagger eligibility: Mutilate strikes with BOTH weapons, so both hands
-- must hold a dagger (the shared dagger set answers dagger / not-dagger /
-- unknown; unknown fails closed like the TBC sibling).
local function has_daggers()
    if not dagger_set or type(NS.get_equipped_item_id) ~= "function"
        or type(NS.EQUIPMENT_SLOTS) ~= "table" then
        return false
    end
    local is_dagger = dagger_set.is_dagger or {}
    local main_id = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.MAIN_HAND)
    local off_id = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.OFF_HAND)
    return (main_id and main_id ~= 0 and is_dagger[main_id] == true)
        and (off_id and off_id ~= 0 and is_dagger[off_id] == true)
        or false
end

-- The poisoned state (the Mutilate +20% window) is reported, not gated:
-- 2 combo points beat Sinister Strike's 1 even unbuffed.
local function target_poisoned(context)
    for _, id in ipairs(POISON_IDS) do
        if type(id) == "number" and debuff_up(context.target, id) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Mutilate leads the builder, Venom the finisher block and
-- Improved Expose Armor the armor-debuff lane.
-- ---------------------------------------------------------------------------
local delta_builder = {}
local delta_finisher = {}
local delta_armor = {}

if MUTILATE and knows_any(MUTILATE, MUTILATE_R1) then
    delta_builder[#delta_builder + 1] = {
        name = "Forever_Mutilate",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if s.stealth_active then return false end  -- the Garrote opener is preferred
            if (s.combo or 0) >= 5 then return false end  -- never overbuild past a finisher
            if (s.energy or 0) < setting(context, "assassin_forever_mutilate_energy", MUTILATE_ENERGY) then return false end
            if not has_daggers() then return false end
            return NS.spell_ready(MUTILATE, context.target)
        end,
        execute = function(context, s)
            local tag = target_poisoned(context)
                and "[FOREVER-ASSASSIN] Mutilate (poisoned: +20%)"
                or "[FOREVER-ASSASSIN] Mutilate"
            return NS.try_cast(MUTILATE, context.target, tag)
        end,
    }
end

if VENOM and VENOM_BUFF then
    delta_finisher[#delta_finisher + 1] = {
        name = "Forever_Venom",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if s.energy_pool_finisher then return false end  -- pool energy like Rupture
            if (s.combo or 0) < setting(context, "assassin_forever_venom_cp", 5) then return false end
            if player_buff_up(VENOM_BUFF) then
                local remains = player_buff_remains(VENOM_BUFF)
                if remains > setting(context, "assassin_forever_venom_refresh", VENOM_REFRESH) then
                    return false
                end
            end
            return NS.spell_ready(VENOM, context.target)
        end,
        execute = function(context, s)
            return NS.try_cast(VENOM, context.target,
                string.format("[FOREVER-ASSASSIN] Venom window (%d cp)", s.combo or 0))
        end,
    }
end

if IMPROVED_EXPOSE_ARMOR and EXPOSE_ARMOR and knows_any(IMPROVED_EXPOSE_ARMOR) then
    delta_armor[#delta_armor + 1] = {
        name = "Forever_ImprovedExposeArmor",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            -- Same assignment gate as the baseline lane (one class-wide
            -- Expose Armor duty; combat_expose_assigned is the battery's key).
            local assigned = spec_kit.setting_bool(context, "assassin_expose_assigned", false)
                or spec_kit.setting_bool(context, "combat_expose_assigned", false)
            if not assigned then return false end
            if (context.target_armor or 0) <= 0 then return false end
            if context.has_sunder then return false end
            if (s.combo or 0) < 5 then return false end  -- the 2-CP refund condition
            if debuff_remains(context.target, EXPOSE_ARMOR_IDS) > setting(context, "assassin_forever_ea_refresh", EA_REFRESH) then
                return false
            end
            return NS.spell_ready(EXPOSE_ARMOR, context.target)
        end,
        execute = function(context)
            return NS.try_cast(EXPOSE_ARMOR, context.target,
                "[FOREVER-ASSASSIN] Improved Expose Armor (5 cp refund)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: Mutilate goes immediately above the baseline's
-- "LevelingSinisterStrike" builder (fallback: "EviscerateFallback"), Venom
-- immediately above "SliceAndDice" (fallback: "RuptureBleed") and Improved
-- Expose Armor immediately above "ExposeArmor"; then append. Re-registering
-- the playstyle name replaces the baseline wholesale — the combined list IS
-- the "assassination" playstyle on Forever.
-- ---------------------------------------------------------------------------
local BUILDER_ANCHORS = { LevelingSinisterStrike = true, EviscerateFallback = true }
local FINISHER_ANCHORS = { SliceAndDice = true, RuptureBleed = true }
local ARMOR_ANCHORS = { ExposeArmor = true }

local combined = {}
local builder_done = false
local finisher_done = false
local armor_done = false
local function insert_builder()
    if builder_done then return end
    for j = 1, #delta_builder do combined[#combined + 1] = delta_builder[j] end
    builder_done = true
end
local function insert_finisher()
    if finisher_done then return end
    for j = 1, #delta_finisher do combined[#combined + 1] = delta_finisher[j] end
    finisher_done = true
end
local function insert_armor()
    if armor_done then return end
    for j = 1, #delta_armor do combined[#combined + 1] = delta_armor[j] end
    armor_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and BUILDER_ANCHORS[name] then insert_builder() end
    if name and FINISHER_ANCHORS[name] then insert_finisher() end
    if name and ARMOR_ANCHORS[name] then insert_armor() end
    combined[#combined + 1] = st
end
insert_builder()
insert_finisher()
insert_armor()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Rogue assassination Forever delta registered (" ..
    #delta_builder .. " mutilate + " .. #delta_finisher .. " venom + " ..
    #delta_armor .. " improved-expose-armor lanes over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
