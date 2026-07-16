-- test_vanilla_spell_ladders.lua — Classic Phase-2 1–60 spell ladders (all 9 classes).
-- WHAT:  At L10/25/40/60, with high talents unlearned via learned-spell mock, at least
--        one real filler matches on shipped Vanilla rotations (build_state + matches).
-- WHEN:  Rotation suite; Phase-2 deep audit.
-- WHY:  Prove leveling/midgame combat is not blocked by endgame-only talents.
-- SAFETY: Test-only helper; drives shipped matches only.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/tests/?.lua;./?.lua;"
    .. (package.path or "")

local H = require("vanilla_ladder_helper")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local failures, total, passed = {}, 0, 0
local function expect(label, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then passed = passed + 1
    else failures[#failures + 1] = label .. " :: " .. tostring(err) end
end

local LEVELS = { 10, 25, 40, 60 }

--- Core ladder: for each level, build_state (if any) + any filler matches.
local function ladder_case(path, filler_names, opts)
    opts = opts or {}
    for li = 1, #LEVELS do
        local level = LEVELS[li]
        expect(path .. " L" .. level .. " filler", function()
            local mod = H.load_module(path, { level = level, class_folder = opts.class_folder })
            assert_true(mod.strategies ~= nil or (mod.result and mod.result.on_update),
                "strategies or leveling module captured")
            local strategies = mod.strategies
            -- Leveling modules may only expose on_update; still require strategies if present
            if not strategies and type(mod.result) == "table" and mod.result.strategies then
                strategies = mod.result.strategies
            end
            assert_true(strategies ~= nil, "strategies required for ladder")

            local ctx = H.context(level, opts.context_extra)
            local state = H.ready_state(level, {
                rage = 60, energy = 100, mana_pct = 80, combo_points = 5,
                level = level, in_combat = true, is_cat = true, is_bear = true,
            })
            if mod.get_state then
                local ok, st = pcall(mod.get_state, ctx)
                if ok and type(st) == "table" then
                    -- Prefer real build_state, but keep ready_state fallbacks via metatable
                    state = H.ready_state(level, st)
                    state.rage = state.rage or 60
                    state.energy = state.energy or 100
                    state.mana_pct = state.mana_pct or 80
                    state.level = state.level or level
                    state.in_combat = true
                    state.combo_points = state.combo_points or 5
                end
            end

            local hit, name = H.any_matches(strategies, filler_names, ctx, state)
            if not hit then
                hit, name = H.any_strategy_matches(strategies, ctx, state, {
                    "HealthPotion", "ManaPotion", "DamagePotion", "EngineeringBomb",
                })
            end
            assert_true(hit, "expected combat filler at L" .. level
                .. " (tried named list + any strategy); last=" .. tostring(name))
        end)
    end
end

--- High talent must NOT match at low level when unlearned (negative control).
--- Uses real build_state + spell_ready mock (no ready_state metatable).
local function high_talent_blocked(path, talent_name, low_level, opts)
    expect(path .. " " .. talent_name .. " blocked at L" .. low_level, function()
        local mod = H.load_module(path, { level = low_level, class_folder = opts and opts.class_folder })
        local s = H.find_strategy(mod.strategies, talent_name)
        if not s then return end -- not registered = fine
        local ctx = H.context(low_level, opts and opts.context_extra)
        local state = { rage = 100, energy = 100, mana_pct = 100, in_combat = true, level = low_level }
        if mod.get_state then
            local ok, st = pcall(mod.get_state, ctx)
            if ok and type(st) == "table" then state = st end
        end
        state.rage = 100
        state.energy = 100
        state.mana_pct = 100
        state.in_combat = true
        local ok, res = pcall(s.matches, ctx, state)
        assert_true(ok, talent_name .. " matches must not throw")
        assert_true(not res, talent_name .. " must not match when unlearned at L" .. low_level
            .. " (spell_ready filtered by LEARN map)")
    end)
end

--- Dungeon AoE: multi-target strategy MUST match when learned (required).
local function dungeon_aoe_case(path, aoe_names, need_level, opts)
    opts = opts or {}
    expect(path .. " dungeon AoE L" .. need_level, function()
        local mod = H.load_module(path, { level = need_level, class_folder = opts.class_folder })
        local ctx = H.context(need_level, {
            enemy_count = 4, enemies_count = 4, is_group = true, is_solo = false,
            distance = 25, target_distance = 25,
            settings = opts.settings or {},
        })
        if opts.context_extra then
            for k, v in pairs(opts.context_extra) do ctx[k] = v end
        end
        local state = H.ready_state(need_level, {
            rage = 100, mana_pct = 80, enemy_count = 4, target_count = 4,
            in_combat = true, multi_shot_ready = true, cleave_ready = true,
            consecration_ready = true, consecration_remains = 0,
            multishot_mode = 2, aoe_threshold = 3, use_volley = false,
            is_mounted = false, cc_nearby = false, has_seal = true,
        })
        if mod.get_state then
            local ok, st = pcall(mod.get_state, ctx)
            if ok and type(st) == "table" then
                state = H.ready_state(need_level, st)
                state.enemy_count = 4
                state.target_count = 4
                state.rage = 100
                state.mana_pct = 80
                state.in_combat = true
                state.multi_shot_ready = true
                state.cleave_ready = true
                state.consecration_ready = true
                state.consecration_remains = 0
                state.multishot_mode = state.multishot_mode or 2
                state.is_mounted = false
                state.cc_nearby = false
            end
        end
        local hit, name = H.any_matches(mod.strategies, aoe_names, ctx, state)
        assert_true(hit, "dungeon AoE must match one of [" .. table.concat(aoe_names, ",")
            .. "] got " .. tostring(name))
    end)
end

print("=== test_vanilla_spell_ladders (Phase 2) ===")

-- ============================================================================
-- 1. HUNTER
-- ============================================================================
local hunter_fillers = {
    "ArcaneShot", "SerpentSting", "SerpentStingRefresh", "LevelingArcaneShot",
    "LevelingSting", "RaptorStrike", "AimedShot", "MultiShot", "HuntersMark",
}
ladder_case("EaxRotations/classes/hunter/beast_mastery_vanilla.lua", hunter_fillers, { class_folder = "hunter" })
ladder_case("EaxRotations/classes/hunter/marksmanship_vanilla.lua", hunter_fillers, { class_folder = "hunter" })
ladder_case("EaxRotations/classes/hunter/survival_vanilla.lua", hunter_fillers, { class_folder = "hunter" })
ladder_case("EaxRotations/classes/hunter/leveling_vanilla.lua", {
    "ArcaneShot", "SerpentSting", "AimedShot", "MultiShot", "RaptorStrike", "HuntersMark",
}, { class_folder = "hunter" })
high_talent_blocked("EaxRotations/classes/hunter/beast_mastery_vanilla.lua", "AimedShot", 10, { class_folder = "hunter" })
high_talent_blocked("EaxRotations/classes/hunter/beast_mastery_vanilla.lua", "BestialWrath", 25, { class_folder = "hunter" })
dungeon_aoe_case("EaxRotations/classes/hunter/beast_mastery_vanilla.lua", { "MultiShot" }, 40, {
    class_folder = "hunter",
})

-- ============================================================================
-- 2. WARRIOR
-- ============================================================================
local warrior_fillers = {
    "HeroicStrike", "Rend", "SunderArmor", "Overpower", "Whirlwind", "Cleave",
    "Bloodthirst", "MortalStrike", "Execute", "BattleShout", "ThunderClap",
    "DemoralizingShout", "ShieldSlam", "Revenge",
}
ladder_case("EaxRotations/classes/warrior/fury_vanilla.lua", warrior_fillers, { class_folder = "warrior" })
ladder_case("EaxRotations/classes/warrior/arms_vanilla.lua", warrior_fillers, { class_folder = "warrior" })
ladder_case("EaxRotations/classes/warrior/protection_vanilla.lua", warrior_fillers, { class_folder = "warrior" })
ladder_case("EaxRotations/classes/warrior/kebab_vanilla.lua", warrior_fillers, { class_folder = "warrior" })
ladder_case("EaxRotations/classes/warrior/leveling_vanilla.lua", {
    "HeroicStrike", "Rend", "Charge", "Overpower", "BattleShout", "Bloodthirst", "SunderArmor",
}, { class_folder = "warrior" })
high_talent_blocked("EaxRotations/classes/warrior/fury_vanilla.lua", "Bloodthirst", 25, { class_folder = "warrior" })
dungeon_aoe_case("EaxRotations/classes/warrior/fury_vanilla.lua", { "Cleave", "Whirlwind", "SweepingStrikes" }, 40, {
    class_folder = "warrior",
})

-- ============================================================================
-- 3. WARLOCK
-- ============================================================================
local lock_fillers = {
    "ShadowBolt", "ShadowBoltFiller", "Corruption", "CorruptionDoT", "Immolate", "ImmolateDoT",
    "CurseOfAgony", "LifeTap", "Conflagrate", "Incinerate", "Wand",
}
ladder_case("EaxRotations/classes/warlock/affliction_vanilla.lua", lock_fillers, { class_folder = "warlock" })
ladder_case("EaxRotations/classes/warlock/demonology_vanilla.lua", lock_fillers, { class_folder = "warlock" })
ladder_case("EaxRotations/classes/warlock/destruction_vanilla.lua", lock_fillers, { class_folder = "warlock" })
ladder_case("EaxRotations/classes/warlock/leveling_vanilla.lua", {
    "ShadowBolt", "Corruption", "Immolate", "CurseOfAgony", "LifeTap", "Wand",
}, { class_folder = "warlock" })
high_talent_blocked("EaxRotations/classes/warlock/destruction_vanilla.lua", "Conflagrate", 25, { class_folder = "warlock" })

-- ============================================================================
-- 4. MAGE
-- ============================================================================
local mage_fillers = {
    "Fireball", "Frostbolt", "FireBlast", "Scorch", "ArcaneMissiles",
    "FireballLeveling", "FrostboltLeveling", "Pyroblast",
}
ladder_case("EaxRotations/classes/mage/fire_vanilla.lua", mage_fillers, { class_folder = "mage" })
ladder_case("EaxRotations/classes/mage/frost_vanilla.lua", mage_fillers, { class_folder = "mage" })
ladder_case("EaxRotations/classes/mage/arcane_vanilla.lua", mage_fillers, { class_folder = "mage" })
ladder_case("EaxRotations/classes/mage/leveling_vanilla.lua", mage_fillers, { class_folder = "mage" })
-- Fireball must match at L10 even if Scorch unlearned (scorch_known gate)
expect("fire Fireball when Scorch unlearned L10", function()
    local mod = H.load_module("EaxRotations/classes/mage/fire_vanilla.lua", {
        level = 10, class_folder = "mage",
    })
    local fb = H.find_strategy(mod.strategies, "Fireball")
    assert_true(fb ~= nil, "Fireball strategy")
    local ctx = H.context(10, { scorch_stacks = 0, settings = { use_scorch_debuff = true } })
    local state = { scorch_stacks = 0 }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then state = st end
    end
    assert_true(fb.matches(ctx, state), "Fireball matches at L10 with Scorch unlearned")
end)

-- ============================================================================
-- 5. ROGUE
-- ============================================================================
local rogue_fillers = {
    "SinisterStrike", "Eviscerate", "SliceAndDice", "Backstab", "Rupture",
    "Hemorrhage", "Ambush", "Garrote", "LevelingSinisterStrike", "EviscerateFallback",
}
ladder_case("EaxRotations/classes/rogue/combat_vanilla.lua", rogue_fillers, { class_folder = "rogue" })
ladder_case("EaxRotations/classes/rogue/assassination_vanilla.lua", rogue_fillers, { class_folder = "rogue" })
ladder_case("EaxRotations/classes/rogue/subtlety_vanilla.lua", rogue_fillers, { class_folder = "rogue" })
ladder_case("EaxRotations/classes/rogue/leveling_vanilla.lua", {
    "SinisterStrike", "Eviscerate", "SliceAndDice", "Backstab",
}, { class_folder = "rogue" })

-- ============================================================================
-- 6. SHAMAN
-- ============================================================================
local sham_fillers = {
    "LightningBolt", "ChainLightning", "EarthShock", "FlameShock", "FrostShock",
    "HealingWave", "ChainHeal", "LesserHealingWave", "Stormstrike",
}
ladder_case("EaxRotations/classes/shaman/elemental_vanilla.lua", sham_fillers, { class_folder = "shaman" })
ladder_case("EaxRotations/classes/shaman/enhancement_vanilla.lua", sham_fillers, { class_folder = "shaman" })
ladder_case("EaxRotations/classes/shaman/restoration_vanilla.lua", {
    "HealingWave", "ChainHeal", "LesserHealingWave", "LightningBolt", "EarthShock",
}, { class_folder = "shaman" })
ladder_case("EaxRotations/classes/shaman/leveling_vanilla.lua", sham_fillers, { class_folder = "shaman" })
high_talent_blocked("EaxRotations/classes/shaman/enhancement_vanilla.lua", "Stormstrike", 25, { class_folder = "shaman" })

-- ============================================================================
-- 7. PRIEST
-- ============================================================================
local priest_dps = {
    "Smite", "SmiteFiller", "ShadowWordPain", "MindBlast", "MindFlay",
    "IdleSWP", "IdleSmite", "HolyFire", "FlashHeal", "Renew",
}
ladder_case("EaxRotations/classes/priest/shadow_vanilla.lua", priest_dps, { class_folder = "priest" })
ladder_case("EaxRotations/classes/priest/smite_vanilla.lua", priest_dps, { class_folder = "priest" })
ladder_case("EaxRotations/classes/priest/holy_vanilla.lua", {
    "FlashHeal", "GreaterHeal", "Renew", "RenewTank", "RenewSpread", "EmergencyFlashHeal",
    "IdleSmite", "IdleSWP",
}, { class_folder = "priest" })
ladder_case("EaxRotations/classes/priest/discipline_vanilla.lua", {
    "FlashHeal", "GreaterHeal", "EmergencyFlashHeal", "PowerWordShield", "EmergencyPowerWordShield",
    "Renew", "IdleSmite", "IdleShadowWordPain",
}, { class_folder = "priest" })
ladder_case("EaxRotations/classes/priest/leveling_vanilla.lua", {
    "Smite", "ShadowWordPain", "MindBlast", "FlashHeal", "PowerWordShield",
}, { class_folder = "priest" })
-- TBC stubs must not match at Classic 60 when unlearned
high_talent_blocked("EaxRotations/classes/priest/smite_vanilla.lua", "ShadowWordDeath", 60, { class_folder = "priest" })
high_talent_blocked("EaxRotations/classes/priest/smite_vanilla.lua", "ShadowfiendMana", 60, { class_folder = "priest" })

-- ============================================================================
-- 8. PALADIN
-- ============================================================================
local pally_fillers = {
    "Judgement", "Consecration", "HolyLight", "FlashOfLight", "HolyShock",
    "SealRighteousness", "SealOfCommand", "Ret_SealCommand_Primary", "Ret_JudgeDamageSeal",
    "HolyShield", "HammerOfWrath", "SmartHeal", "HolyLightEmergency",
}
ladder_case("EaxRotations/classes/paladin/retribution_vanilla.lua", pally_fillers, { class_folder = "paladin" })
ladder_case("EaxRotations/classes/paladin/protection_vanilla.lua", pally_fillers, { class_folder = "paladin" })
ladder_case("EaxRotations/classes/paladin/holy_vanilla.lua", pally_fillers, { class_folder = "paladin" })
ladder_case("EaxRotations/classes/paladin/leveling_vanilla.lua", {
    "Judgement", "HolyLight", "SealOfRighteousness", "Consecration", "FlashOfLight",
}, { class_folder = "paladin" })
high_talent_blocked("EaxRotations/classes/paladin/protection_vanilla.lua", "HolyShield", 25, { class_folder = "paladin" })
dungeon_aoe_case("EaxRotations/classes/paladin/protection_vanilla.lua", { "Consecration" }, 40, {
    class_folder = "paladin",
    settings = { prot_consecration = true, prot_consecration_targets = 3 },
})

-- ============================================================================
-- 9. DRUID
-- ============================================================================
local druid_fillers = {
    "Wrath", "Moonfire", "Starfire", "InsectSwarm", "Shred", "Rip", "FerociousBite",
    "Maul", "Swipe", "DemoralizingRoar", "HealingTouch", "Rejuvenation", "Regrowth",
    "ClawFallback", "Rake", "MangleFiller",
}
ladder_case("EaxRotations/classes/druid/balance_vanilla.lua", druid_fillers, { class_folder = "druid" })
-- Cat Form is L20+; B1 cat ladder starts at 25 (Shred 22, no Mangle required)
for _, level in ipairs({ 25, 40, 60 }) do
    expect("EaxRotations/classes/druid/cat_vanilla.lua L" .. level .. " filler", function()
        local mod = H.load_module("EaxRotations/classes/druid/cat_vanilla.lua", {
            level = level, class_folder = "druid",
        })
        local ctx = H.context(level, { energy = 100, combo_points = 5 })
        local state = H.ready_state(level, { energy = 100, combo_points = 5, is_cat = true, level = level })
        if mod.get_state then
            local ok, st = pcall(mod.get_state, ctx)
            if ok and type(st) == "table" then
                state = H.ready_state(level, st)
                state.energy = 100
                state.is_cat = true
                state.is_behind = true
                state.level = level
                state.combo_points = state.combo_points or 5
                state.mangle_remains = 99 -- do not require Mangle refresh
                state.rake_remains = 0
            end
        end
        state.is_cat = true
        state.is_behind = true
        state.energy = 100
        local hit = H.any_matches(mod.strategies, {
            "Shred", "Rake", "Rip", "ClawFallback", "FerociousBite", "FaerieFireFeral",
        }, ctx, state)
        if not hit then hit = H.any_strategy_matches(mod.strategies, ctx, state, { "HealthPotion", "ManaPotion" }) end
        assert_true(hit, "cat filler at L" .. level)
    end)
end
ladder_case("EaxRotations/classes/druid/bear_vanilla.lua", druid_fillers, {
    class_folder = "druid",
    context_extra = { rage = 50 },
})
ladder_case("EaxRotations/classes/druid/caster_vanilla.lua", druid_fillers, { class_folder = "druid" })
ladder_case("EaxRotations/classes/druid/resto_vanilla.lua", {
    "HealingTouch", "Rejuvenation", "Regrowth", "RegrowthSpotHeal", "PriorityRejuvenation",
    "SwiftmendEmergency", "FallbackHealingTouch",
}, { class_folder = "druid" })
ladder_case("EaxRotations/classes/druid/leveling_vanilla.lua", {
    "Wrath", "Moonfire", "HealingTouch", "Rejuvenation", "CatForm", "BearForm",
}, { class_folder = "druid" })

-- Cat: Mangle not required — Shred/Rip at L25 with level-aware CP
expect("cat Shred/Rip without Mangle L25", function()
    local mod = H.load_module("EaxRotations/classes/druid/cat_vanilla.lua", {
        level = 25, class_folder = "druid",
    })
    local ctx = H.context(25, { energy = 100, combo_points = 5 })
    local state = { level = 25, energy = 100, combo_points = 5, in_combat = true,
        mangle_remains = 0, is_cat = true }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then
            state = st
            state.level = 25
            state.energy = 100
            state.combo_points = state.combo_points or 5
        end
    end
    local hit = H.any_matches(mod.strategies, { "Shred", "Rip", "Rake", "ClawFallback", "FerociousBite" }, ctx, state)
    assert_true(hit, "Cat must have builder/finisher without Mangle at L25")
end)

-- ============================================================================
-- Content modes + settings + raid-60 priority (criterion 2 / §B / §C)
-- ============================================================================
expect("hunter pet Mend at L25 solo", function()
    local mod = H.load_module("EaxRotations/classes/hunter/beast_mastery_vanilla.lua", {
        level = 25, class_folder = "hunter",
    })
    local mend = H.find_strategy(mod.strategies, "MendPet")
    assert_true(mend ~= nil, "MendPet strategy exists")
    local ctx = H.context(25, { is_solo = true })
    local state = {
        in_combat = true, pet_alive = true, pet_hp = 30, mend_pet_ready = true, is_mounted = false,
    }
    assert_true(mend.matches(ctx, state), "MendPet matches low pet HP solo")
end)

expect("fury Cleave MATCHES when multi + rage", function()
    local mod = H.load_module("EaxRotations/classes/warrior/fury_vanilla.lua", {
        level = 40, class_folder = "warrior",
    })
    local cleave = H.find_strategy(mod.strategies, "Cleave")
    assert_true(cleave ~= nil, "Cleave strategy present")
    local ctx = H.context(40, { enemy_count = 3, enemies_count = 3, rage = 80 })
    local state = {}
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        state = (ok and st) or {}
    end
    state.rage = 80
    state.cleave_ready = true
    state.target_count = 3
    local ok, res = pcall(cleave.matches, ctx, state)
    assert_true(ok, "Cleave matches no throw")
    assert_true(res == true, "Cleave must match with target_count>=2 and rage>=40")
end)

expect("destruction no FelArmor on Classic", function()
    local mod = H.load_module("EaxRotations/classes/warlock/destruction_vanilla.lua", {
        level = 60, class_folder = "warlock",
    })
    local fel = H.find_strategy(mod.strategies, "FelArmor")
    if fel and fel.matches then
        local ctx = H.context(60)
        local state = {}
        if mod.get_state then
            local ok, st = pcall(mod.get_state, ctx)
            state = (ok and st) or {}
        end
        local ok, res = pcall(fel.matches, ctx, state)
        assert_true(ok and not res, "FelArmor must not match on Classic")
    end
end)

-- Settings flip matches (schema keys that change Vanilla behavior)
expect("setting: hunter use_cooldowns false blocks BestialWrath", function()
    local mod = H.load_module("EaxRotations/classes/hunter/beast_mastery_vanilla.lua", {
        level = 60, class_folder = "hunter",
    })
    local bw = H.find_strategy(mod.strategies, "BestialWrath")
    assert_true(bw ~= nil, "BestialWrath present")
    local ctx_on = H.context(60, {
        settings = { use_cooldowns = true },
        in_combat = true,
    })
    local st_on = H.ready_state(60, {
        in_combat = true, bestial_wrath_ready = true, pet_alive = true,
        use_cooldowns = true, is_mounted = false,
    })
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx_on)
        if ok and type(st) == "table" then
            st_on = H.ready_state(60, st)
            st_on.bestial_wrath_ready = true
            st_on.pet_alive = true
            st_on.use_cooldowns = true
            st_on.in_combat = true
            st_on.is_mounted = false
        end
    end
    local ctx_off = H.context(60, { settings = { use_cooldowns = false }, in_combat = true })
    local st_off = H.ready_state(60, {
        in_combat = true, bestial_wrath_ready = true, pet_alive = true,
        use_cooldowns = false, is_mounted = false,
    })
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx_off)
        if ok and type(st) == "table" then
            st_off = H.ready_state(60, st)
            st_off.bestial_wrath_ready = true
            st_off.pet_alive = true
            st_off.use_cooldowns = false -- setting must win for this test
            st_off.in_combat = true
            st_off.is_mounted = false
        end
    end
    -- cooldowns_allowed reads module-local state from last build_state — re-build off path last
    pcall(mod.get_state, ctx_off)
    st_off.use_cooldowns = false
    local ok_off, res_off = pcall(bw.matches, ctx_off, st_off)
    assert_true(ok_off, "BW matches no throw when CDs off")
    assert_true(not res_off, "BestialWrath must not match when use_cooldowns=false")
end)

expect("setting: aff amplify curse disabled", function()
    local mod = H.load_module("EaxRotations/classes/warlock/affliction_vanilla.lua", {
        level = 60, class_folder = "warlock",
    })
    local ac = H.find_strategy(mod.strategies, "AmplifyCurse")
    if not ac then return end -- optional talent strategy
    local ctx = H.context(60, {
        settings = { aff_use_amplify_curse = false },
        ttd = 120,
    })
    local state = H.ready_state(60, {
        amplify_curse_ready = true, agony_remains = 0, doom_remains = 0,
    })
    local ok, res = pcall(ac.matches, ctx, state)
    assert_true(ok and not res, "AmplifyCurse blocked when aff_use_amplify_curse=false")
end)

expect("setting: mage use_scorch_debuff false allows Fireball without stacks", function()
    local mod = H.load_module("EaxRotations/classes/mage/fire_vanilla.lua", {
        level = 60, class_folder = "mage",
    })
    local fb = H.find_strategy(mod.strategies, "Fireball")
    assert_true(fb ~= nil, "Fireball present")
    local ctx = H.context(60, {
        settings = { use_scorch_debuff = false },
        scorch_stacks = 0,
    })
    local state = { scorch_stacks = 0 }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then state = st end
    end
    assert_true(fb.matches(ctx, state), "Fireball matches with scorch duty off")
end)

expect("setting: prot consecration disabled", function()
    local mod = H.load_module("EaxRotations/classes/paladin/protection_vanilla.lua", {
        level = 60, class_folder = "paladin",
    })
    local c = H.find_strategy(mod.strategies, "Consecration")
    assert_true(c ~= nil, "Consecration present")
    local ctx = H.context(60, {
        settings = { prot_consecration = false },
        enemy_count = 5,
    })
    local state = H.ready_state(60, {
        consecration_ready = true, mana_pct = 90, enemy_count = 5,
        consecration_remains = 0, cc_nearby = false,
    })
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and type(st) == "table" then
            state = H.ready_state(60, st)
            state.consecration_ready = true
            state.enemy_count = 5
            state.mana_pct = 90
        end
    end
    local ok, res = pcall(c.matches, ctx, state)
    assert_true(ok and not res, "Consecration blocked when prot_consecration=false")
end)

expect("setting: hunter multishot_mode 0 disables MultiShot", function()
    local mod = H.load_module("EaxRotations/classes/hunter/beast_mastery_vanilla.lua", {
        level = 40, class_folder = "hunter",
    })
    local ms = H.find_strategy(mod.strategies, "MultiShot")
    assert_true(ms ~= nil, "MultiShot present")
    local ctx = H.context(40, {
        enemy_count = 5, settings = { multishot_mode = 0 },
    })
    local state = H.ready_state(40, {
        in_combat = true, multi_shot_ready = true, multishot_mode = 0,
        enemy_count = 5, mana_pct = 80, is_mounted = false,
    })
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and type(st) == "table" then
            state = H.ready_state(40, st)
            state.multishot_mode = 0
            state.multi_shot_ready = true
            state.enemy_count = 5
            state.in_combat = true
            state.is_mounted = false
        end
    end
    local ok, res = pcall(ms.matches, ctx, state)
    assert_true(ok and not res, "MultiShot off when multishot_mode=0")
end)

--- Helper: assert strategy does not match under settings (real matches path).
local function setting_blocks(label, path, folder, strategy_name, settings, state_extra)
    expect(label, function()
        local mod = H.load_module(path, { level = 60, class_folder = folder })
        local strat = H.find_strategy(mod.strategies, strategy_name)
        assert_true(strat ~= nil, strategy_name .. " present in " .. path)
        local ctx = H.context(60, { settings = settings or {}, in_combat = true, is_group = true })
        local state = H.ready_state(60, state_extra or {})
        if mod.get_state then
            local ok, st = pcall(mod.get_state, ctx)
            if ok and type(st) == "table" then
                state = H.ready_state(60, st)
                if state_extra then
                    for k, v in pairs(state_extra) do state[k] = v end
                end
            end
        end
        local ok, res = pcall(strat.matches, ctx, state)
        assert_true(ok, strategy_name .. " matches no throw")
        assert_true(not res, strategy_name .. " must not match under settings")
    end)
end

-- ============================================================================
-- Per-class settings flips (3–5 keys each) + group overwrite (curse/seal/shout)
-- ============================================================================

-- Hunter (additional)
setting_blocks("setting hunter use_volley false",
    "EaxRotations/classes/hunter/beast_mastery_vanilla.lua", "hunter", "Volley",
    { use_volley = false },
    { in_combat = true, use_volley = false, enemy_count = 5, mana_pct = 90, is_mounted = false })
setting_blocks("setting hunter use_melee false blocks Raptor",
    "EaxRotations/classes/hunter/beast_mastery_vanilla.lua", "hunter", "RaptorStrike",
    { use_melee = false },
    { in_combat = true, use_melee = false, raptor_ready = true, is_mounted = false, distance = 3 })
setting_blocks("setting hunter use_explosive_trap false",
    "EaxRotations/classes/hunter/beast_mastery_vanilla.lua", "hunter", "ExplosiveTrap",
    { use_explosive_trap = false },
    { in_combat = true, use_explosive_trap = false, is_mounted = false })

-- Warrior fury + kebab group overwrite (Sunder/Demo)
expect("setting warrior fury sunder_armor_mode none", function()
    local mod = H.load_module("EaxRotations/classes/warrior/fury_vanilla.lua", {
        level = 60, class_folder = "warrior",
    })
    local s = H.find_strategy(mod.strategies, "SunderArmor")
    assert_true(s ~= nil, "SunderArmor present")
    local ctx = H.context(60, {
        settings = { sunder_armor_mode = "none" },
        target_armor = 5000, in_combat = true,
    })
    local state = { sunder_ready = true, has_sunder = false }
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and not res, "Fury Sunder blocked when sunder_armor_mode=none")
end)
expect("setting warrior fury maintain_demo_shout false", function()
    local mod = H.load_module("EaxRotations/classes/warrior/fury_vanilla.lua", {
        level = 60, class_folder = "warrior",
    })
    local s = H.find_strategy(mod.strategies, "DemoralizingShout")
    assert_true(s ~= nil, "DemoralizingShout present")
    local ctx = H.context(60, { settings = { maintain_demo_shout = false } })
    local state = { demo_ready = true, has_demo_shout = false }
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and not res, "Fury Demo blocked when maintain_demo_shout=false")
end)
expect("setting warrior kebab sunder_armor_mode none", function()
    local mod = H.load_module("EaxRotations/classes/warrior/kebab_vanilla.lua", {
        level = 60, class_folder = "warrior",
    })
    local s = H.find_strategy(mod.strategies, "SunderMaintain")
    assert_true(s ~= nil, "SunderMaintain present")
    local ctx = H.context(60, {
        settings = { sunder_armor_mode = "none" },
        target_armor = 5000, in_combat = true, stance = 1,
    })
    local state = { sunder_stacks = 0 }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then state = st; state.sunder_stacks = 0 end
    end
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and not res, "Kebab Sunder blocked when mode=none")
end)
expect("setting warrior kebab maintain_demo_shout false", function()
    local mod = H.load_module("EaxRotations/classes/warrior/kebab_vanilla.lua", {
        level = 60, class_folder = "warrior",
    })
    local s = H.find_strategy(mod.strategies, "DemoShout")
    assert_true(s ~= nil, "DemoShout present")
    local ctx = H.context(60, {
        settings = { maintain_demo_shout = false },
        in_melee_range = true, in_combat = true,
    })
    local state = { demo_shout_duration = 0 }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then state = st; state.demo_shout_duration = 0 end
    end
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and not res, "Kebab Demo blocked when maintain_demo_shout=false")
end)
expect("setting warrior fury use_sunder_armor false", function()
    local mod = H.load_module("EaxRotations/classes/warrior/fury_vanilla.lua", {
        level = 60, class_folder = "warrior",
    })
    local s = H.find_strategy(mod.strategies, "SunderArmor")
    assert_true(s ~= nil, "SunderArmor present")
    local ctx = H.context(60, {
        settings = { use_sunder_armor = false },
        target_armor = 5000,
    })
    local ok, res = pcall(s.matches, ctx, { sunder_ready = true, has_sunder = false })
    assert_true(ok and not res, "use_sunder_armor=false blocks Sunder")
end)

-- Warlock group curse overwrite
expect("setting warlock curse_mode agony blocks CoE", function()
    local mod = H.load_module("EaxRotations/classes/warlock/affliction_vanilla.lua", {
        level = 60, class_folder = "warlock",
    })
    local coe = H.find_strategy(mod.strategies, "CurseOfElements")
    assert_true(coe ~= nil, "CurseOfElements present")
    local ctx = H.context(60, {
        settings = { warlock_curse_mode = "agony" },
        is_group = true, target = {},
    })
    local state = { coe_remains = 0 }
    local ok, res = pcall(coe.matches, ctx, state)
    assert_true(ok and not res, "CoE blocked when warlock_curse_mode=agony")
end)
expect("setting warlock assigned_curse agony blocks CoE", function()
    local mod = H.load_module("EaxRotations/classes/warlock/affliction_vanilla.lua", {
        level = 60, class_folder = "warlock",
    })
    local coe = H.find_strategy(mod.strategies, "CurseOfElements")
    local ctx = H.context(60, {
        settings = { warlock_assigned_curse = "agony" },
        is_group = true, target = {},
    })
    local ok, res = pcall(coe.matches, ctx, { coe_remains = 0 })
    assert_true(ok and not res, "CoE blocked when assigned_curse=agony")
end)
expect("setting warlock assigned_curse elements blocks Agony", function()
    local mod = H.load_module("EaxRotations/classes/warlock/affliction_vanilla.lua", {
        level = 60, class_folder = "warlock",
    })
    local ca = H.find_strategy(mod.strategies, "CurseOfAgony")
    assert_true(ca ~= nil, "CurseOfAgony present")
    local ctx = H.context(60, {
        settings = { warlock_assigned_curse = "elements" },
        has_valid_enemy_target = true, ttd = 120,
    })
    local ok, res = pcall(ca.matches, ctx, { agony_remains = 0 })
    assert_true(ok and not res, "Agony blocked when assigned_curse=elements")
end)
setting_blocks("setting warlock aff amplify already covered path",
    "EaxRotations/classes/warlock/affliction_vanilla.lua", "warlock", "DamagePotion",
    { use_auto_potions = false },
    { in_combat = true })

-- Mage additional
setting_blocks("setting mage use_cooldowns false Combustion",
    "EaxRotations/classes/mage/fire_vanilla.lua", "mage", "Combustion",
    { use_cooldowns = false },
    { combustion_ready = true, in_combat = true })
setting_blocks("setting mage use_interrupt false Counterspell",
    "EaxRotations/classes/mage/fire_vanilla.lua", "mage", "Counterspell",
    { use_interrupt = false },
    { in_combat = true })
setting_blocks("setting mage use_mana_gem false",
    "EaxRotations/classes/mage/fire_vanilla.lua", "mage", "ManaGem",
    { use_mana_gem = false },
    { mana_pct = 20, mana_gem_available = true })
setting_blocks("setting mage use_auto_potions false",
    "EaxRotations/classes/mage/fire_vanilla.lua", "mage", "ManaPotion",
    { use_auto_potions = false },
    { in_combat = true, mana_pct = 10 })

-- Rogue
setting_blocks("setting rogue use_cooldowns false BladeFlurry",
    "EaxRotations/classes/rogue/combat_vanilla.lua", "rogue", "BladeFlurry",
    { use_cooldowns = false },
    { in_combat = true, blade_flurry_ready = true, has_blade_flurry = false, target_count = 5 })
expect("setting rogue combat_blade_flurry_count high", function()
    local mod = H.load_module("EaxRotations/classes/rogue/combat_vanilla.lua", {
        level = 60, class_folder = "rogue",
    })
    local bf = H.find_strategy(mod.strategies, "BladeFlurry")
    assert_true(bf ~= nil, "BladeFlurry present")
    local ctx = H.context(60, {
        settings = { use_cooldowns = true, combat_blade_flurry_count = 5 },
        in_combat = true,
    })
    local state = {
        in_combat = true, blade_flurry_ready = true, has_blade_flurry = false, target_count = 2,
    }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then
            state = st
            state.blade_flurry_ready = true
            state.has_blade_flurry = false
            state.target_count = 2
            state.in_combat = true
        end
    end
    local ok, res = pcall(bf.matches, ctx, state)
    assert_true(ok and not res, "BladeFlurry needs combat_blade_flurry_count targets")
end)
setting_blocks("setting combat use_auto_potions false HealthPotion",
    "EaxRotations/classes/rogue/combat_vanilla.lua", "rogue", "HealthPotion",
    { use_auto_potions = false },
    { in_combat = true, hp = 10 })
setting_blocks("setting subtlety use_auto_potions false HealthPotion",
    "EaxRotations/classes/rogue/subtlety_vanilla.lua", "rogue", "HealthPotion",
    { use_auto_potions = false },
    { in_combat = true, hp = 10 })

-- Shaman
setting_blocks("setting ele elemental_use_elemental_mastery false",
    "EaxRotations/classes/shaman/elemental_vanilla.lua", "shaman", "ElementalMastery",
    { elemental_use_elemental_mastery = false },
    { in_combat = true })
setting_blocks("setting ele elemental_use_fire_nova_aoe false",
    "EaxRotations/classes/shaman/elemental_vanilla.lua", "shaman", "FireNovaTotem",
    { elemental_use_fire_nova_aoe = false },
    { in_combat = true, enemy_count = 5 })
setting_blocks("setting resto restoration_manage_totems false Strength",
    "EaxRotations/classes/shaman/restoration_vanilla.lua", "shaman", "StrengthOfEarthTotem",
    { restoration_manage_totems = false },
    {})
setting_blocks("setting resto restoration_manage_totems false ManaSpring",
    "EaxRotations/classes/shaman/restoration_vanilla.lua", "shaman", "ManaSpringTotem",
    { restoration_manage_totems = false },
    {})
setting_blocks("setting enh use_ooc_buffs false GhostWolf",
    "EaxRotations/classes/shaman/enhancement_vanilla.lua", "shaman", "GhostWolf",
    { use_ooc_buffs = false },
    { in_combat = false, ghost_wolf_ooc = true, ghost_wolf_ready = true, has_ghost_wolf = false })
setting_blocks("setting enh use_cooldowns false ManaTide",
    "EaxRotations/classes/shaman/enhancement_vanilla.lua", "shaman", "ManaTideTotem",
    { use_cooldowns = false },
    { in_combat = true, mana_pct = 10 })

-- Priest
setting_blocks("setting holy holy_use_pws false EmergencyPWS",
    "EaxRotations/classes/priest/holy_vanilla.lua", "priest", "EmergencyPWS",
    { holy_use_pws = false },
    { lowest = { effective_hp = 20, unit = {} }, lowest_hp = 20 })
setting_blocks("setting shadow shadow_use_inner_fire false",
    "EaxRotations/classes/priest/shadow_vanilla.lua", "priest", "InnerFire",
    { shadow_use_inner_fire = false },
    {})
setting_blocks("setting disc discipline_use_power_infusion false",
    "EaxRotations/classes/priest/discipline_vanilla.lua", "priest", "PowerInfusion",
    { discipline_use_power_infusion = false },
    { in_combat = true })
setting_blocks("setting smite smite_use_mb false",
    "EaxRotations/classes/priest/smite_vanilla.lua", "priest", "MindBlast",
    { smite_use_mb = false },
    { mb_ready = true, in_combat = true, has_valid_enemy_target = true })
setting_blocks("setting holy holy_use_poh false",
    "EaxRotations/classes/priest/holy_vanilla.lua", "priest", "PrayerOfHealing",
    { holy_use_poh = false },
    { group_damaged_count = 5, poh_count = 5 })

-- Paladin seals / group
expect("setting prot prot_seal_of_righteousness false", function()
    local mod = H.load_module("EaxRotations/classes/paladin/protection_vanilla.lua", {
        level = 60, class_folder = "paladin",
    })
    local seal = H.find_strategy(mod.strategies, "SealRighteousness")
    assert_true(seal ~= nil, "SealRighteousness present")
    local ctx = H.context(60, { settings = { prot_seal_of_righteousness = false } })
    local state = { has_seal = false }
    local ok, res = pcall(seal.matches, ctx, state)
    assert_true(ok and not res, "Seal SoR blocked when setting false")
end)
setting_blocks("setting prot prot_holy_shield false",
    "EaxRotations/classes/paladin/protection_vanilla.lua", "paladin", "HolyShield",
    { prot_holy_shield = false },
    { holy_shield_ready = true, in_combat = true })
setting_blocks("setting ret sanctity_aura_enabled false",
    "EaxRotations/classes/paladin/retribution_vanilla.lua", "paladin", "Ret_SanctityAura",
    { sanctity_aura_enabled = false },
    {})
setting_blocks("setting ret blessing_of_might_self false",
    "EaxRotations/classes/paladin/retribution_vanilla.lua", "paladin", "Ret_BlessingMight_Self",
    { blessing_of_might_self = false },
    {})
setting_blocks("setting prot prot_judgement false",
    "EaxRotations/classes/paladin/protection_vanilla.lua", "paladin", "Judgement",
    { prot_judgement = false },
    { judgement_ready = true, has_seal = true })

-- Druid
setting_blocks("setting bear bear_demo_roar false",
    "EaxRotations/classes/druid/bear_vanilla.lua", "druid", "DemoralizingRoar",
    { bear_demo_roar = false },
    { is_bear = true, in_combat = true, demo_roar_enabled = false, enemy_count = 3, rage = 50 })
setting_blocks("setting balance balance_use_insect_swarm false",
    "EaxRotations/classes/druid/balance_vanilla.lua", "druid", "InsectSwarmDoT",
    { balance_use_insect_swarm = false },
    { in_combat = true })
expect("setting resto group idle SoloWrath blocked without dps_when_idle", function()
    local mod = H.load_module("EaxRotations/classes/druid/resto_vanilla.lua", {
        level = 60, class_folder = "druid",
    })
    local s = H.find_strategy(mod.strategies, "SoloWrath")
    assert_true(s ~= nil, "SoloWrath present")
    local ctx = H.context(60, {
        settings = { resto_dps_when_idle = false },
        is_solo = false, is_leveling = false, is_group = true,
        has_valid_enemy_target = true, mana_pct = 90, is_moving = false,
    })
    local state = { mana_emergency = false, mana_pct = 90 }
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and not res, "SoloWrath off in group when resto_dps_when_idle=false")
end)
setting_blocks("setting cat use_auto_potions false",
    "EaxRotations/classes/druid/cat_vanilla.lua", "druid", "HealthPotion",
    { use_auto_potions = false },
    { in_combat = true, hp = 10 })
setting_blocks("setting balance balance_auto_dispel false RemoveCurse",
    "EaxRotations/classes/druid/balance_vanilla.lua", "druid", "RemoveCurse",
    { balance_auto_dispel = false },
    { in_combat = true })
setting_blocks("setting resto barkskin_hp threshold high",
    "EaxRotations/classes/druid/resto_vanilla.lua", "druid", "BarkskinSelfPreservation",
    { barkskin_hp = 5 },
    {})

-- Raid-60 priority order (wowsims classic: high-priority names before filler)
local function assert_prio_before(path, folder, earlier, later)
    expect("raid60 prio " .. earlier .. " before " .. later .. " in " .. path, function()
        local mod = H.load_module(path, { level = 60, class_folder = folder })
        local _, i_early = H.find_strategy(mod.strategies, earlier)
        local _, i_late = H.find_strategy(mod.strategies, later)
        assert_true(i_early ~= nil, earlier .. " present")
        assert_true(i_late ~= nil, later .. " present")
        assert_true(i_early < i_late, earlier .. " (" .. i_early .. ") before " .. later .. " (" .. i_late .. ")")
    end)
end

-- wowsims classic warrior DPS: Execute before fillers; BT before HS
assert_prio_before("EaxRotations/classes/warrior/fury_vanilla.lua", "warrior", "Bloodthirst", "HeroicStrike")
assert_prio_before("EaxRotations/classes/warrior/fury_vanilla.lua", "warrior", "Execute", "HeroicStrike")
-- wowsims hunter p1: Aimed before Arcane when both exist
assert_prio_before("EaxRotations/classes/hunter/beast_mastery_vanilla.lua", "hunter", "AimedShot", "ArcaneShot")
assert_prio_before("EaxRotations/classes/hunter/marksmanship_vanilla.lua", "hunter", "InCombatAimedShot", "ArcaneShot")
-- wowsims warlock: Conflagrate/Immolate structure — Shadowburn before ShadowBolt
assert_prio_before("EaxRotations/classes/warlock/destruction_vanilla.lua", "warlock", "Shadowburn", "ShadowBolt")
-- rogue combat: SnD before Evis
assert_prio_before("EaxRotations/classes/rogue/combat_vanilla.lua", "rogue", "SliceAndDice", "Eviscerate")
-- mage fire: Scorch before Fireball in table (maintenance)
assert_prio_before("EaxRotations/classes/mage/fire_vanilla.lua", "mage", "Scorch", "Fireball")
-- shaman ele: ChainLightning before LightningBolt when both listed
assert_prio_before("EaxRotations/classes/shaman/elemental_vanilla.lua", "shaman", "ChainLightning", "LightningBolt")
-- priest shadow: MindBlast before MindFlay
assert_prio_before("EaxRotations/classes/priest/shadow_vanilla.lua", "priest", "MindBlast", "MindFlay")
-- druid balance: dots before fillers if present
assert_prio_before("EaxRotations/classes/druid/balance_vanilla.lua", "druid", "MoonfireDoT", "StarfirePrimary")
-- paladin ret: seal/judge structure (wowsims classic ret)
assert_prio_before("EaxRotations/classes/paladin/retribution_vanilla.lua", "paladin", "Ret_ApplyCrusaderSeal", "Ret_SealCommand_Primary")
assert_prio_before("EaxRotations/classes/paladin/retribution_vanilla.lua", "paladin", "Ret_JudgeCrusader", "Ret_JudgeDamageSeal")
assert_prio_before("EaxRotations/classes/paladin/protection_vanilla.lua", "paladin", "HolyShield", "Consecration")
assert_prio_before("EaxRotations/classes/paladin/holy_vanilla.lua", "paladin", "HolyLightEmergency", "SmartHeal")

-- ============================================================================
if #failures > 0 then
    print("FAIL test_vanilla_spell_ladders — " .. passed .. "/" .. total)
    for i = 1, math.min(#failures, 40) do
        print("  " .. failures[i])
    end
    if #failures > 40 then print("  ... +" .. (#failures - 40) .. " more") end
    error("test_vanilla_spell_ladders failed", 0)
end
print("PASS test_vanilla_spell_ladders — " .. passed .. "/" .. total)
