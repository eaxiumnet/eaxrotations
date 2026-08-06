-- test_healer_encounter_profiles.lua -- cross-spec healer encounter profiles.
-- WHAT:  deterministic first-match/action/target regressions for five TBC healers.
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects tank sustain, emergencies, group damage, mana, utility, and target boundaries.
-- SAFETY: Isolated mocked namespaces; no production code or live game state.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local unpack = table.unpack or unpack

local function assert_true(value, label)
    if not value then error(label or "assert_true failed", 2) end
end

local function assert_false(value, label)
    if value then error(label or "assert_false failed", 2) end
end

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local function unit(name)
    return { name = name, get_health_percentage = function() return 100 end }
end

local function entry(target, hp, extra)
    local result = { unit = target, effective_hp = hp, hp = hp, max_hp = 10000, deficit = (100 - hp) * 100 }
    for key, value in pairs(extra or {}) do result[key] = value end
    return result
end

local function first_id(value)
    if type(value) ~= "table" then return value end
    if type(value.id) == "function" then
        local ok, id = pcall(value.id, value)
        if ok then return id end
    end
    if type(value.spell_id) == "number" then return value.spell_id end
    if type(value.ids) == "table" then return value.ids[1] end
    return value[1]
end

local function new_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        ids = type(ids) == "table" and ids or { ids },
        spell_id = id,
        label = label,
        id = function(self) return self.spell_id end,
    }
end

local function load_spec(path, class_field, healing)
    local calls = {}
    local player = unit("self")
    local class_ids = { DruidSpells = 11, PriestSpells = 5, PaladinSpells = 2, ShamanSpells = 7 }
    player.get_class = function() return class_ids[class_field] end
    local function capture(kind, spell, target, label)
        calls[#calls + 1] = { kind = kind, spell = spell, target = target, label = label }
        return true
    end

    local ns
    ns = {
        PLAYER_UNIT = player,
        CLASS_ID = { DRUID = 11, PRIEST = 5, PALADIN = 2, SHAMAN = 7 },
        [class_field] = {},
        [class_field == "PriestSpells" and "PriestFLASH_HEAL_RANKS" or "_unused"] = nil,
        GetPlayer = function() return player end,
        spell_action = new_action,
        spell_exists = function() return true end,
        unready_ids = {},
        spell_ready = function(spell)
            local id = first_id(spell)
            return id ~= 26994 and id ~= 20484 and not ns.unready_ids[id]
        end,
        try_cast = function(spell, target, label) return capture("cast", spell, target, label) end,
        use_item_by_id = function(id, target) return capture("item", id, target, "item") end,
        import_helpers = function(...)
            local values = {}
            for i = 1, select("#", ...) do
                local name = select(i, ...)
                values[i] = ns[name]
            end
            return unpack(values)
        end,
        gate_overheal = function() return false end,
        buff_up = function(target) return target and target.has_buffs == true end,
        has_buff = function() return false end,
        has_player_buff = function() return false end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        buff_remains = function() return 0 end,
        health_pct = function() return 100 end,
        unit_health_pct = function() return 100 end,
        unit_alive = function(target) return target ~= nil end,
        player_control_locked = function() return false end,
        same_unit = function(a, b) return a == b end,
        is_tank_unit = function(target) return target and target.is_tank == true end,
        is_in_party = function(target) return target and target.party == true end,
        is_in_raid = function() return false end,
        has_dispel_type_debuff = function() return false end,
        time_now = function() return 0 end,
        game_time_ms = function() return 0 end,
        GetEnemiesInRange = function() return {} end,
        GetPartyMembers = function() return {} end,
        log = function() end,
        log_warning = function() end,
        rotation_registry = { register = function() end },
        spell_book = { is_spell_learned = function() return false end },
        ConsumableManager = { use_mana_potion = function() return capture("mana_potion", 0, nil, "mana potion") end },
    }
    ns[class_field == "PriestSpells" and "PriestFLASH_HEAL_RANKS" or "_unused"] = nil
    ns[class_field == "PriestSpells" and "PriestFLASH_HEAL_RANKS" or "_unused"] = nil
    if class_field == "PriestSpells" then
        ns.PriestFLASH_HEAL_RANKS = { { spell = 25235, label = "R9" } }
        ns.PriestGREATER_HEAL_RANKS = { { spell = 25213, label = "R7" } }
        ns.PriestPRAYER_OF_HEALING_RANKS = { { spell = 25308, label = "R6" } }
        ns.PriestBINDING_HEAL_RANKS = { { spell = 32546, label = "R1" } }
        ns.cast_best_heal_rank = function(ranks) return ranks[1].spell, ranks[1].label end
    end
    ns[class_field == "DruidSpells" and "DruidHealing" or "_unused"] = nil
    ns[class_field == "PaladinSpells" and "PaladinHealing" or "_unused"] = nil
    ns[class_field == "ShamanSpells" and "ShamanHealing" or "_unused"] = nil
    ns[class_field == "DruidSpells" and "DruidHealing" or "_unused"] = healing
    ns[class_field == "PaladinSpells" and "PaladinHealing" or "_unused"] = healing
    ns[class_field == "ShamanSpells" and "ShamanHealing" or "_unused"] = healing
    ns[class_field == "PriestSpells" and "PriestHealing" or "_unused"] = healing

    _G.core = { time = function() return 0 end, game_time = function() return 0 end, log = function() end, get_game_version = function() return "Tbc" end }
    _G.EaxRotations = ns
    package.loaded[path] = nil
    local module = dofile(path)
    return module.strategies, ns, player, calls
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("strategy not found: " .. name, 2)
end

local function select_strategy(strategies, context, state)
    for i = 1, #strategies do
        local strategy = strategies[i]
        if strategy.matches then
            local ok, matches = pcall(strategy.matches, context, state)
            if not ok then error("strategy " .. strategy.name .. " crashed: " .. tostring(matches), 2) end
            if matches then return strategy, i end
        end
    end
    return nil, nil
end

local function normalize_state(context, state)
    local defaults = {
        in_combat = context.in_combat == true, mana_pct = context.mana_pct or 100, hp_pct = context.hp_pct or 100,
        enemy_count = context.enemy_count or 0, lowest_hp = 100, lowest_hp_pct = 100,
        group_damaged_count = 0, subgroup_damaged_count = 0, party_injured_count = 0,
        tranquility_count = 0, chain_heal_target_count = 0, chain_heal_cluster_count = 0,
        tree_aura_count = 0, melee_pressure_count = 0, earth_shield_charges = 0,
        earth_shield_remains = 0, healing_way_stacks = 0, healing_way_remains = 0,
        mana_conserve = false, mana_emergency = false, mana_critical = false,
        in_tree = false, has_natures_swiftness = false, has_divine_favor = false,
        has_divine_illumination = false, has_seal_wisdom = false, has_weakened_soul = false,
    }
    for key, value in pairs(defaults) do
        if state[key] == nil then state[key] = value end
    end
    return state
end

local function profile(label, strategies, context, state, expected_name, expected_id, expected_target, calls)
    state = normalize_state(context, state)
    local selected, index = select_strategy(strategies, context, state)
    assert_true(selected ~= nil, label .. ": no strategy selected")
    assert_eq(selected.name, expected_name, label .. ": selected strategy")
    calls[1] = nil
    local ok = selected.execute and selected.execute(context, state)
    assert_true(ok, label .. ": selected strategy did not execute")
    assert_true(calls[1] ~= nil, label .. ": no action captured")
    assert_eq(first_id(calls[1].spell), expected_id, label .. ": selected action")
    assert_eq(calls[1].target, expected_target, label .. ": target identity")
    return index
end

local function no_profile(label, strategies, context, state)
    state = normalize_state(context, state)
    local selected = select_strategy(strategies, context, state)
    assert_true(selected == nil, label .. ": unexpected strategy " .. tostring(selected and selected.name))
end

local function base_context(player)
    return { in_combat = true, is_group = true, is_moving = false, mana_pct = 100, hp = 100, hp_pct = 100,
        settings = {}, me = player, target = nil, has_valid_enemy_target = false, enemy_count = 0 }
end

local healer = {
    scan_healing_targets = function() return {}, 0 end,
    select_heal = function() return { spell = 25420, label = "Lesser Healing Wave" } end,
    pws_absorb_remaining = function() return 0 end,
    all_members_above_hp = function() return true end,
    has_dangerous_dispel = function(target) return target and target.dangerous_magic == true end,
    has_disease = function(target) return target and target.disease == true end,
}

local tank = unit("tank")
tank.is_tank, tank.party = true, true
local healer_unit = unit("healer")
healer_unit.party = true
local raider = unit("raider")
raider.party = true
local outsider = unit("outsider")
outsider.party, outsider.out_of_range = false, true

do
    local strategies, ns, player, calls = load_spec("EaxRotations/classes/druid/resto_sylvanas.lua", "DruidSpells", healer)
    local ctx = base_context(player)
    profile("druid tank sustain", strategies, ctx, { in_combat = true, mana_pct = 80, tank = entry(tank, 70), lifebloom_tank = entry(tank, 70) }, "TankLifebloomStack", 33763, tank, calls)
    profile("druid emergency", strategies, ctx, { in_combat = true, mana_pct = 80, swiftmend_target = entry(healer_unit, 20), ht_target = nil }, "SwiftmendEmergency", 18562, healer_unit, calls)
    profile("druid group damage", strategies, ctx, { in_combat = true, mana_pct = 80, lifebloom_raid = entry(raider, 80) }, "RaidLifebloomCoverage", 33763, raider, calls)
    ctx.mana_pct = 20
    profile("druid low mana", strategies, ctx, { in_combat = true, mana_pct = 20, mana_conserve = true, mana_emergency = false, mana_critical = false, lowest = entry(healer_unit, 40) }, "DownrankHealingTouch", 26978, healer_unit, calls)
    ctx.mana_pct = 100
    profile("druid utility", strategies, ctx, { in_combat = true, cursed_target = entry(raider, 90) }, "RemoveCurse", 2782, raider, calls)
    no_profile("druid full-health party", strategies, ctx, { in_combat = true, lowest = nil, tank = nil })
    ctx.party_members = { outsider }
    no_profile("druid non-party out-of-range", strategies, ctx, { in_combat = true, lowest = nil, friendly_target_ready = false })
    print("PASS druid encounter profiles")
end

do
    local strategies, ns, player, calls = load_spec("EaxRotations/classes/priest/holy_sylvanas.lua", "PriestSpells", healer)
    local ctx = base_context(player)
    profile("holy priest tank sustain", strategies, ctx, { in_combat = true, tank = entry(tank, 80, { renew_remains = 0 }) }, "RenewTank", 25222, tank, calls)
    ctx.settings.holy_use_pws = false
    profile("holy priest emergency", strategies, ctx, { in_combat = true, lowest = entry(healer_unit, 20), lowest_hp = 20, flash_heal_ready = true }, "EmergencyFlashHeal", 25235, healer_unit, calls)
    ctx.settings.holy_use_pws = true
    profile("holy priest group damage", strategies, ctx, { in_combat = true, lowest = entry(healer_unit, 70), lowest_hp = 70, prayer_of_healing_ready = true, subgroup_damaged_count = 3, group_damaged_count = 3 }, "PrayerOfHealing", 25308, player, calls)
    ctx.mana_pct = 20
    ctx.settings.holy_use_inner_focus = false
    profile("holy priest low mana", strategies, ctx, { in_combat = true, mana_pct = 20, lowest = entry(healer_unit, 45), lowest_hp = 45, flash_heal_ready = true }, "FlashHeal", 25233, healer_unit, calls)
    ctx.settings.holy_use_inner_focus = true
    ctx.mana_pct = 100
    local utility_target = entry(tank, 90)
    utility_target.unit.dangerous_magic = true
    profile("holy priest utility", strategies, ctx, { in_combat = true, mana_pct = 80, tank = utility_target, dispel_magic_ready = true }, "DispelMagic", 988, tank, calls)
    no_profile("holy priest full-health party", strategies, ctx, { in_combat = true, lowest = nil, tank = nil })
    ctx.party_members = { outsider }
    no_profile("holy priest non-party out-of-range", strategies, ctx, { in_combat = true, lowest = nil, tank = nil, friendly_target_ready = false })
    print("PASS holy priest encounter profiles")
end

do
    local strategies, ns, player, calls = load_spec("EaxRotations/classes/priest/discipline_sylvanas.lua", "PriestSpells", healer)
    local ctx = base_context(player)
    profile("discipline tank sustain", strategies, ctx, { in_combat = true, pws_ready = true, tank = entry(tank, 30) }, "PowerWordShieldTank", 25218, tank, calls)
    profile("discipline emergency", strategies, ctx, { in_combat = true, mana_pct = 80, lowest = entry(healer_unit, 25), flash_heal_ready = true, pws_ready = false }, "EmergencyFlashHeal", 25235, healer_unit, calls)
    profile("discipline group damage", strategies, ctx, { in_combat = true, party_injured_count = 4, lowest = entry(healer_unit, 70), prayer_of_healing_ready = true }, "PrayerOfHealing", 25308, player, calls)
    ctx.mana_pct = 10
    profile("discipline low mana", strategies, ctx, { in_combat = true, mana_pct = 10, lowest = entry(healer_unit, 20), pws_ready = true }, "EmergencyPowerWordShield", 25218, healer_unit, calls)
    ctx.mana_pct = 100
    profile("discipline utility", strategies, ctx, { in_combat = true, enemy_count = 1, fear_ward_ready = true, fear_ward_target = tank }, "FearWard", 6346, tank, calls)
    no_profile("discipline full-health party", strategies, ctx, { in_combat = true, lowest = nil, tank = nil })
    ctx.party_members = { outsider }
    no_profile("discipline non-party out-of-range", strategies, ctx, { in_combat = true, lowest = nil, tank = nil, friendly_target_ready = false })
    print("PASS discipline encounter profiles")
end

do
    local paladin_healing = {}
    local strategies, ns, player, calls = load_spec("EaxRotations/classes/paladin/holy_sylvanas.lua", "PaladinSpells", paladin_healing)
    local ctx = base_context(player)
    ctx.settings.holy_blessing_light = false
    local steady_tank = entry(tank, 80, { unit = tank })
    tank.has_buffs = true
    profile("holy paladin tank sustain", strategies, ctx, { in_combat = true, mana_pct = 80, tank = steady_tank, lights_grace_remains = 10 }, "TankPreHeal", 25292, tank, calls)
    ctx.settings.holy_divine_favor_hp = 0
    profile("holy paladin emergency", strategies, ctx, { in_combat = true, mana_pct = 80, lowest = entry(healer_unit, 25) }, "HolyShock", 33072, healer_unit, calls)
    ctx.settings.holy_divine_favor_hp = 45
    profile("holy paladin group damage", strategies, ctx, { in_combat = true, mana_pct = 80, lowest = entry(raider, 75) }, "SmartHeal", 25292, raider, calls)
    ctx.mana_pct = 25
    profile("holy paladin low mana", strategies, ctx, { in_combat = true, mana_pct = 25, lowest = entry(raider, 80), has_divine_illumination = true, has_seal_wisdom = true }, "FlashOfLightEfficientTopoff", 27137, raider, calls)
    ctx.mana_pct = 100
    local cleanse = entry(tank, 85, { needs_cleanse = true })
    profile("holy paladin utility", strategies, ctx, { in_combat = true, tank = cleanse }, "CleanseTankPriority", 4987, tank, calls)
    no_profile("holy paladin full-health party", strategies, ctx, { in_combat = true, lowest = nil, tank = nil })
    ctx.party_members = { outsider }
    no_profile("holy paladin non-party out-of-range", strategies, ctx, { in_combat = true, lowest = nil, tank = nil, friendly_target_ready = false })
    print("PASS holy paladin encounter profiles")
end

do
    local strategies, ns, player, calls = load_spec("EaxRotations/classes/shaman/restoration_sylvanas.lua", "ShamanSpells", healer)
    local ctx = base_context(player)
    profile("resto shaman tank sustain", strategies, ctx, { in_combat = true, tank = entry(tank, 80), earth_shield_ready = true, earth_shield_charges = 0, earth_shield_remains = 0 }, "EarthShieldTank", 32594, tank, calls)
    profile("resto shaman emergency", strategies, ctx, { in_combat = true, lowest = entry(healer_unit, 20), lowest_time_to_die = 2, natures_swiftness_ready = true }, "NaturesSwiftness", 16188, player, calls)
    ns.unready_ids[2825] = true
    profile("resto shaman group damage", strategies, ctx, { in_combat = true, lowest = entry(raider, 50), chain_heal_ready = true, chain_heal_optimal_target = entry(raider, 50), chain_heal_cluster_count = 3 }, "ChainHeal", 25423, raider, calls)
    ns.unready_ids[2825] = nil
    ctx.mana_pct = 25
    profile("resto shaman low mana", strategies, ctx, { in_combat = true, mana_pct = 25, lowest = entry(healer_unit, 60) }, "ManaTideTotem", 16190, player, calls)
    ctx.mana_pct = 100
    local poison = entry(raider, 85, { has_poison = true })
    ns.unready_ids[2825] = true
    ctx.settings.restoration_manage_totems = false
    profile("resto shaman utility", strategies, ctx, { in_combat = true, cleanse_target = poison, cure_poison_ready = true, mana_emergency = false, lowest = nil }, "CurePoison", 526, raider, calls)
    ctx.settings.restoration_manage_totems = true
    ns.unready_ids[2825] = nil
    ctx.settings.restoration_manage_totems = false
    ns.unready_ids[2825] = true
    no_profile("resto shaman full-health party", strategies, ctx, { in_combat = true, lowest = nil, tank = nil })
    ctx.party_members = { outsider }
    no_profile("resto shaman non-party out-of-range", strategies, ctx, { in_combat = true, lowest = nil, tank = nil, friendly_target_ready = false })
    ns.unready_ids[2825] = nil
    print("PASS shaman encounter profiles")
end

print("PASS test_healer_encounter_profiles")
