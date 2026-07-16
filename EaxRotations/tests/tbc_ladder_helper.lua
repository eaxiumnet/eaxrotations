-- tbc_ladder_helper.lua — shared learned-spell mock for TBC Anniversary 1–70 ladder tests.
-- WHAT:  level-aware spell_ready/exists + class NS stubs; capture get_state via registry.
-- WHEN:  required by test_tbc_spell_ladders.lua (Phase 2 deep audit).
-- WHY:  prove fillers fire when high talents unlearned; TBC cores enter at learn levels.
-- SAFETY: test-only; does not load in production rotations.

local M = {}

--- TBC Anniversary min player level for first usable rank (cap 70).
--- Sourced from classes/*/class_sylvanas.lua `levels` + DBC-aligned TBC cores.
M.LEARN = {
    -- Hunter
    ArcaneShot = 6, SerpentSting = 4, HuntersMark = 6, AimedShot = 20,
    MultiShot = 18, RapidFire = 26, BestialWrath = 40, FeignDeath = 30,
    MendPet = 12, CallPet = 10, RevivePet = 10, AspectOfTheHawk = 10,
    RaptorStrike = 1, WingClip = 12, ConcussiveShot = 8, ExplosiveTrap = 34,
    SteadyShot = 50, KillCommand = 66, Volley = 40, AspectOfTheViper = 20,
    -- Warrior
    HeroicStrike = 1, BattleShout = 1, Charge = 4, Rend = 4, ThunderClap = 6,
    Hamstring = 8, Overpower = 12, DemoralizingShout = 14, Execute = 24,
    Whirlwind = 36, Cleave = 20, Bloodthirst = 40, MortalStrike = 40,
    ShieldSlam = 40, SunderArmor = 10, ShieldBlock = 16, Revenge = 14,
    SweepingStrikes = 30, Pummel = 38, Bloodrage = 10, BerserkerStance = 30,
    DefensiveStance = 10, BattleStance = 1, Devastate = 50,
    VictoryRush = 62, CommandingShout = 68, Intervene = 70,
    -- Warlock
    ShadowBolt = 1, Corruption = 4, Immolate = 1, CurseOfAgony = 8,
    LifeTap = 6, Fear = 8, DrainLife = 14, HealthFunnel = 12,
    Conflagrate = 40, Shadowburn = 20, SoulFire = 48, RainOfFire = 20,
    Hellfire = 30, FelArmor = 62, UnstableAffliction = 50, Incinerate = 64,
    SummonImp = 1, SummonVoidwalker = 10, SummonFelhunter = 30,
    SummonFelguard = 50, SeedOfCorruption = 70, Shadowfury = 50,
    -- Mage
    Fireball = 1, Frostbolt = 4, FireBlast = 6, Scorch = 22, Pyroblast = 20,
    Combustion = 40, ArcaneExplosion = 14, Flamestrike = 16, Blizzard = 20,
    ArcaneMissiles = 8, ArcaneBlast = 64, IceLance = 66, -- 2.5.5 backport OK
    SummonWaterElemental = 50, MoltenArmor = 62, MageArmor = 34,
    -- Rogue
    SinisterStrike = 1, Eviscerate = 1, SliceAndDice = 10, Backstab = 4,
    Rupture = 20, Ambush = 1, Garrote = 14, Hemorrhage = 30,
    AdrenalineRush = 40, BladeFlurry = 30, Envenom = 62, Mutilate = 50,
    DeadlyThrow = 64, CloakOfShadows = 66,
    -- Shaman
    LightningBolt = 1, EarthShock = 4, FlameShock = 10, FrostShock = 20,
    ChainLightning = 32, HealingWave = 1, LesserHealingWave = 20, ChainHeal = 40,
    Stormstrike = 40, WaterShield = 62, EarthShield = 50, Bloodlust = 70,
    WrathOfAirTotem = 64, ShamanisticRage = 50, WindfuryWeapon = 30,
    -- Priest
    Smite = 1, ShadowWordPain = 4, MindBlast = 10, MindFlay = 20,
    FlashHeal = 20, GreaterHeal = 40, Renew = 8, PowerWordShield = 6,
    VampiricTouch = 50, Shadowfiend = 66, ShadowWordDeath = 62,
    CircleOfHealing = 50, PrayerOfMending = 68, MassDispel = 70,
    -- Paladin
    SealOfRighteousness = 1, Judgement = 4, HolyLight = 1, FlashOfLight = 20,
    Consecration = 20, HammerOfWrath = 44, HolyShield = 40, SealOfCommand = 20,
    CrusaderStrike = 50, AvengingWrath = 70, AvengersShield = 50,
    SealOfBlood = 64, SealOfTheMartyr = 64, SealOfVengeance = 64,
    HolyShock = 40, Lightwell = 40, AvengingWrathTalent = 70,
    -- Druid
    Wrath = 1, Moonfire = 4, HealingTouch = 1, Rejuvenation = 4, Regrowth = 12,
    Starfire = 20, InsectSwarm = 20, Shred = 22, Rip = 20, FerociousBite = 32,
    Maul = 10, Swipe = 16, Bash = 14, DemoralizingRoar = 10,
    Mangle = 50, Lacerate = 66, Lifebloom = 64, TreeOfLife = 50,
    Hurricane = 40, Cyclone = 70, MangleCat = 50, MangleBear = 50,
}

M.CLASS_ID = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

M.CLASS_BY_FOLDER = {
    warrior = M.CLASS_ID.WARRIOR, paladin = M.CLASS_ID.PALADIN,
    hunter = M.CLASS_ID.HUNTER, rogue = M.CLASS_ID.ROGUE,
    priest = M.CLASS_ID.PRIEST, shaman = M.CLASS_ID.SHAMAN,
    mage = M.CLASS_ID.MAGE, warlock = M.CLASS_ID.WARLOCK,
    druid = M.CLASS_ID.DRUID,
}

local function spell_name(spell)
    if spell == nil then return nil end
    if type(spell) == "table" then
        return spell.name or spell.spell_name or spell.label
    end
    return nil
end

function M.is_learned(name, player_level)
    if not name then return true end
    local min = M.LEARN[name]
    if min == nil then return true end
    return (player_level or 0) >= min
end

function M.make_spell_table(extra_names)
    local t = {}
    for name, _ in pairs(M.LEARN) do
        t[name] = { name = name, id = 1, [1] = 1 }
    end
    if extra_names then
        for i = 1, #extra_names do
            local n = extra_names[i]
            t[n] = t[n] or { name = n, id = 1, [1] = 1 }
        end
    end
    return t
end

---@param opts { level: number, class_folder: string }
function M.setup(opts)
    opts = opts or {}
    local level = opts.level or 70
    local folder = opts.class_folder or "warrior"
    local class_id = M.CLASS_BY_FOLDER[folder] or M.CLASS_ID.WARRIOR
    local capture = { strategies = nil, get_state = nil, name = nil }

    local function learned_spell(spell)
        local name = spell_name(spell)
        return M.is_learned(name, level)
    end

    local spells = M.make_spell_table(opts.extra_spells)

    local NS = {
        is_vanilla = function() return false end,
        is_tbc = function() return true end,
        is_wotlk = function() return false end,
        CLASS_ID = M.CLASS_ID,
        PLAYER_UNIT = {},
        GetPlayer = function()
            return {
                get_class = function() return class_id end,
                get_race_id = function() return 1 end,
                get_health_percentage = function() return 100 end,
                get_dodge_chance = function() return 0 end,
                get_level = function() return level end,
                is_moving = function() return false end,
                is_dead = function() return false end,
                is_valid = function() return true end,
                is_in_combat = function() return true end,
                get_position = function() return { x = 0, y = 0, z = 0 } end,
            }
        end,
        GetPet = function() return nil end,
        spell_action = function(ids, name)
            local n = name
            if type(ids) == "table" and ids.name then n = ids.name end
            return { name = n, ids = ids, [1] = type(ids) == "table" and (ids[1] or ids.id) or ids }
        end,
        spell_ready = function(spell)
            return learned_spell(spell)
        end,
        spell_exists = function(spell)
            return learned_spell(spell)
        end,
        is_spell_learned = function(spell)
            return learned_spell(spell)
        end,
        get_spell_id = function(spell)
            if type(spell) == "number" then return spell end
            if type(spell) == "table" then return spell[1] or spell.id or 1 end
            return 1
        end,
        try_cast = function() return true end,
        action_ready = function() return true end,
        action_matches = function() return true end,
        action_execute = function() return true end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        buff_stacks = function() return 0 end,
        get_buff_stacks = function() return 0 end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        debuff_stacks = function() return 0 end,
        get_debuff_stacks = function() return 0 end,
        has_player_buff = function() return false end,
        has_player_debuff = function() return false end,
        has_buff = function() return false end,
        has_debuff = function() return false end,
        unit_health_pct = function() return 80 end,
        unit_hp_pct = function() return 80 end,
        get_rage = function() return 60 end,
        get_energy = function() return 100 end,
        get_combo_points = function() return 5 end,
        in_melee = function() return true end,
        is_behind_target = function() return true end,
        can_attack_target = function() return true end,
        player_control_locked = function() return false end,
        distance_to = function() return 5 end,
        cooldown_remains = function() return 0 end,
        swing_time_until = function() return 2.0 end,
        swing_progress = function() return 0.5 end,
        swing_time_since = function() return 1.0 end,
        game_time_ms = function() return 0 end,
        is_item_ready = function() return false end,
        unit_mana_pct = function() return 80 end,
        unit_alive = function() return true end,
        time_now = function() return 0 end,
        log = function() end,
        log_warning = function() end,
        has_item = function() return true end,
        is_execute_phase = function(hp, pct) return (hp or 100) <= (pct or 20) end,
        broken_api_throttled = function() return false end,
        should_refresh_dot = function() return true end,
        should_use_long_cd = function() return true end,
        -- Explicit: metatable must not override these with falsey stubs.
        same_unit = function() return false end,
        gate_cooldown_boss_only = function() return true end,
        get_setting = function(_, _, d) return d end,
        import_helpers = function(...)
            local n = select("#", ...)
            local out = {}
            for i = 1, n do
                local key = select(i, ...)
                if key == "spell_ready" then
                    out[i] = function(spell) return learned_spell(spell) end
                elseif key == "spell_exists" then
                    out[i] = function(spell) return learned_spell(spell) end
                elseif key == "try_cast" then
                    out[i] = function() return true end
                elseif key == "can_attack_target" then
                    out[i] = function() return true end
                elseif key == "player_control_locked" then
                    out[i] = function() return false end
                elseif key == "has_breakable_cc_nearby" then
                    out[i] = function() return false end
                elseif key == "debuff_remains" or key == "buff_remains" then
                    out[i] = function() return 0 end
                elseif key == "debuff_stacks" then
                    out[i] = function() return 0 end
                elseif key == "health_pct" then
                    out[i] = function() return 80 end
                elseif key == "has_player_buff" then
                    out[i] = function() return false end
                else
                    out[i] = function() return true end
                end
            end
            return unpack(out)
        end,
        try_interrupt = function() return false end,
        is_current_spell = function() return false end,
        get_friendly_target = function() return nil end,
        get_friendly_target_entry = function() return nil end,
        get_friendly_target_priority = function() return nil end,
        has_form = function(form) return form == "cat" or form == "bear" or form == true end,
        get_heal_targets = function() return {} end,
        build_healing_entries = function() return {}, 0 end,
        healing_get_lowest_hp = function()
            return { unit = {}, hp = 50, effective_hp = 50, hp_pct = 50 }
        end,
        healing_get_tank = function()
            return { unit = {}, hp = 60, effective_hp = 60, hp_pct = 60 }
        end,
        get_party_members = function() return {} end,
        buff_points = function() return nil end,
        debuff_points = function() return nil end,
        rotation_registry = {
            register = function(_, name, strategies, opts)
                capture.name = name
                capture.strategies = strategies
                capture.get_state = opts and opts.get_state or opts and opts.context_builder
            end,
        },
        HunterClipTracker = {
            ms_until_auto = function() return 1500 end,
            record_manual_shot = function() end,
            can_cast_steady = function() return true end,
        },
        WarriorSpells = spells,
        WarriorConstants = {
            STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
            BATTLE_SHOUT_IDS = { 6673 },
        },
        HunterSpells = spells,
        MageSpells = spells,
        PaladinSpells = spells,
        PriestSpells = spells,
        RogueSpells = spells,
        ShamanSpells = spells,
        WarlockSpells = spells,
        DruidSpells = spells,
    }

    -- Safe numeric/bool helpers only — never invent module tables (SwingDiagnostics etc.).
    setmetatable(NS, {
        __index = function(t, key)
            if type(key) ~= "string" then return nil end
            -- PascalCase / module-like names stay nil so `if NS.Foo then` is false.
            if key:match("^[A-Z]") then return nil end
            local fn
            if key:match("^get_") or key:match("_pct$") or key:match("_remains$")
                or key:match("_stacks$") or key:match("^unit_") or key == "get_hit_cap"
                or key == "get_miss_chance" or key == "get_expertise" then
                fn = function() return 0 end
            elseif key:match("^is_") or key:match("^has_") or key:match("^can_")
                or key:match("^should_") or key:match("_ready$") or key:match("^in_")
                or key:match("^try_") then
                fn = function() return false end
            else
                return nil
            end
            rawset(t, key, fn)
            return fn
        end,
    })

    _G.EaxRotations = NS

    package.loaded["shared/spec_kit_sylvanas"] = {
        setting = function(ctx, key, d)
            if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
            return d
        end,
        setting_bool = function(ctx, key, d)
            if ctx and ctx.settings and ctx.settings[key] ~= nil then
                return ctx.settings[key] and true or false
            end
            if d == nil then return false end
            return d and true or false
        end,
        setting_number = function(ctx, key, d)
            if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
            return d
        end,
        define_action_for_class = function()
            return function(name, ids)
                return { name = name, ids = ids, [1] = type(ids) == "table" and ids[1] or ids }
            end
        end,
        safe_state = function(s) return s end,
    }
    package.loaded["shared/potion_helper_sylvanas"] = {
        try_use_potion = function() return false end,
        HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
    }
    package.loaded["shared/leveling_helpers_sylvanas"] = {
        level_from_context = function(ctx, fb)
            if ctx and (ctx.level or ctx.player_level) then return ctx.level or ctx.player_level end
            return fb or 70
        end,
        vanilla_level_from_context = function(ctx)
            if ctx and (ctx.level or ctx.player_level) then return ctx.level or ctx.player_level end
            return 70
        end,
        is_low_level = function(l) return (l or 70) < 50 end,
        has_mangle_cat = function(l) return (l or 70) >= 50 end,
        spell_ready = function(sp) return learned_spell(sp) end,
        try_cast = function() return true end,
        has_buff = function() return false end,
        get_player = function() return NS.GetPlayer() end,
    }
    package.loaded["shared/leveling_sylvanas"] = {
        WAND_SPELL_ID = 5019,
        create_context_guard = function()
            return function(context)
                if not context then return false end
                if context.is_solo == true or context.is_leveling == true then return true end
                local settings = context.settings or {}
                return settings.playstyle == "leveling" or settings.active_playstyle == "leveling"
            end
        end,
        build_common_state = function(ctx, st)
            if not ctx or not st then return st end
            st.in_combat = ctx.in_combat or false
            st.mana_pct = ctx.mana_pct or 100
            st.hp = ctx.hp or 100
            st.enemies = ctx.enemies_count or ctx.enemy_count or 0
            st.target = ctx.target
            st.is_moving = ctx.is_moving or false
            st.pet = ctx.pet
            st.level = ctx.level or ctx.player_level or level
            st.rage = ctx.rage or 50
            st.energy = ctx.energy or 100
            st.use_interrupt = true
            st.wand_learned = true
            return st
        end,
        create_wand_matches = function() return function() return false end end,
        execute_wand = function() return false end,
    }
    package.loaded["shared/hunter_core_sylvanas"] = {
        get_pet = function() return nil end,
        pet_alive = function() return false end,
        pet_hp_pct = function() return 100 end,
        can_cast_steady = function() return true end,
        can_cast_instant = function() return true end,
        record_instant_shot = function() end,
        sting_remains = function() return 10 end,
        should_feign_death = function() return false end,
    }
    package.loaded["shared/targeting_sylvanas"] = {}
    package.loaded["shared/pet_manager_sylvanas"] = {}
    package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { healthstones = {}, potions = {} }, SPELLS = {} }
    package.loaded["shared/curse_helper_sylvanas"] = { other_curse_active = function() return false end }
    package.loaded["shared/hit_cap_tracker_sylvanas"] = {
        get_hit_cap = function() return { pct_needed = 9, rating_needed = 0 } end,
        get_expertise_cap = function() return { soft_expertise = 6, hard_expertise = 26 } end,
    }
    package.loaded["shared/cooldown_planner_sylvanas"] = {
        is_major_offensive_cd_active = function() return false end,
        should_use_long_cd = function() return true end,
    }
    package.loaded["shared/engineering_helper_sylvanas"] = {
        try_use_bomb = function() return false end,
    }
    package.loaded["classes/warrior/shared_helpers_sylvanas"] = package.loaded["classes/warrior/shared_helpers_sylvanas"] or {
        would_starve_core = function() return false end,
    }
    package.loaded["shared/cc_gate_db_sylvanas"] = { find_best_dispel_target = function() return nil end }
    package.loaded["shared/heal_helper_sylvanas"] = package.loaded["shared/heal_helper_sylvanas"] or {}
    package.loaded["common/izi_sdk"] = package.loaded["common/izi_sdk"] or {
        spell = function(id) return { id = id, cast_safe = function() return false end } end,
        me = function() return nil end,
        enemies = function() return {} end,
    }

    return NS, capture, level
end

function M.load_module(path, opts)
    opts = opts or {}
    local folder = path:match("classes/([^/]+)/") or opts.class_folder
    if folder then opts.class_folder = folder end
    local NS, capture, level = M.setup(opts)
    -- Clear prior load so loadfile re-executes cleanly
    package.loaded[path] = nil
    local chunk = assert(loadfile(path), "loadfile " .. path)
    local result = chunk()
    local strategies = capture.strategies
    local get_state = capture.get_state
    if type(result) == "table" then
        if result.strategies then strategies = strategies or result.strategies end
        if result.build_state then get_state = get_state or result.build_state end
        if result[1] and result[1].matches then strategies = strategies or result end
    end
    return {
        result = result,
        strategies = strategies,
        get_state = get_state,
        level = level,
        NS = NS,
    }
end

function M.find_strategy(strategies, name)
    if not strategies then return nil end
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    return nil
end

function M.ready_state(level, base)
    local st = base or {}
    st.rage = st.rage or 60
    st.energy = st.energy or 100
    st.mana_pct = st.mana_pct or 80
    st.hp = st.hp or 80
    st.level = st.level or level
    st.in_combat = st.in_combat ~= false
    st.combo_points = st.combo_points or 5
    st.enemy_count = st.enemy_count or 1
    st.target_count = st.target_count or 1
    st.is_mounted = false
    st.pet_alive = st.pet_alive or false
    st.mangle_remains = st.mangle_remains or 0
    return setmetatable(st, {
        __index = function(_, k)
            if type(k) ~= "string" then return nil end
            if k:match("_ready$") then return true end
            if k:match("^has_") then return false end
            if k:match("_remains$") then return 0 end
            if k:match("_stacks$") then return 0 end
            return nil
        end,
    })
end

function M.any_matches(strategies, names, context, state)
    for i = 1, #names do
        local s = M.find_strategy(strategies, names[i])
        if s and s.matches then
            local ok, res = pcall(s.matches, context, state)
            if ok and res then return true, names[i] end
        end
    end
    return false, nil
end

function M.any_strategy_matches(strategies, context, state, skip_names)
    skip_names = skip_names or {}
    local skip = {}
    for i = 1, #skip_names do skip[skip_names[i]] = true end
    if not strategies then return false, nil end
    for i = 1, #strategies do
        local s = strategies[i]
        local n = s and s.name
        if s and s.matches and n and not skip[n] then
            if not n:match("Potion") and not n:match("Healthstone") and n ~= "Wand"
                and n ~= "ManaEmergencyWand" and not n:match("Racial") then
                local ok, res = pcall(s.matches, context, state)
                if ok and res then return true, n end
            end
        end
    end
    for i = 1, #strategies do
        local s = strategies[i]
        if s and (s.name == "Wand" or s.name == "ManaEmergencyWand") and s.matches then
            local ok, res = pcall(s.matches, context, state)
            if ok and res then return true, s.name end
        end
    end
    return false, nil
end

function M.context(level, extra)
    local ctx = {
        in_combat = true,
        player_level = level,
        level = level,
        is_leveling = true,
        target = {
            get_health_percentage = function() return 80 end,
            get_dodge_chance = function() return 0 end,
        },
        me = {
            get_class = function() return 1 end,
            get_health_percentage = function() return 100 end,
            get_level = function() return level end,
            is_moving = function() return false end,
            is_dead = function() return false end,
            is_valid = function() return true end,
            is_in_combat = function() return true end,
            get_position = function() return { x = 0, y = 0, z = 0 } end,
        },
        rage = 60,
        energy = 100,
        mana_pct = 80,
        hp = 80,
        target_hp = 80,
        enemy_count = 1,
        enemies_count = 1,
        has_valid_enemy_target = true,
        in_melee_range = true,
        is_behind = true,
        settings = {},
        is_group = false,
        is_solo = true,
        stance = 3,
        distance = 8,
        target_distance = 8,
    }
    if extra then
        for k, v in pairs(extra) do ctx[k] = v end
    end
    return ctx
end

return M
