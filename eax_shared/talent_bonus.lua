-- talent_bonus.lua | TBC talent bonus lookups
-- Percent values are max-rank TBC talent baselines for a spec.
-- mana_modifier is expressed as mana efficiency / cost reduction percent when applicable.
-- crit_bonus is extra critical damage bonus percent.
-- cooldown reductions are seconds.

local talent_bonus = {}

local DATA = {
    druid = {
        balance = {
            damage_modifier = 10,
            mana_modifier = 9,
            crit_bonus = 100,
            haste_modifier = 3,
            armor_reduction = 0,
            talents = {
                insect_swarm = 5570,
                focused_starlight = 35363,
                vengeance = 16909,
                celestial_focus = 16850,
                moonglow = 16845,
                moonfury = 16896,
                moonkin_form = 24858,
                improved_faerie_fire = 33600,
                wrath_of_cenarius = 33603,
                force_of_nature = 33831,
            },
            spells = {
                moonkin_form = 24858,
                force_of_nature = 33831,
                insect_swarm = 5570,
            },
            proc_flags = {
                natures_grace = true,
            },
            cooldowns = {},
        },
        feral = {
            damage_modifier = 20,
            mana_modifier = 0,
            crit_bonus = 10,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                ferocity = 16934,
                shredding_attacks = 16966,
                savage_fury = 16998,
                heart_of_the_wild = 17003,
                leader_of_the_pack = 17007,
                improved_leader_of_the_pack = 34297,
                predatory_instincts = 33859,
                faerie_fire_feral = 16857,
                mangle = 33917,
            },
            spells = {
                faerie_fire_feral = 16857,
                leader_of_the_pack = 17007,
                mangle = 33917,
            },
            proc_flags = {
                primal_fury = true,
            },
            cooldowns = {},
        },
        restoration = {
            damage_modifier = 0,
            mana_modifier = 20,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                intensity = 17106,
                tranquil_spirit = 24968,
                gift_of_nature = 17104,
                natures_swiftness = 17116,
                living_spirit = 34151,
                natural_perfection = 33881,
                empowered_rejuvenation = 33886,
                tree_of_life = 33891,
            },
            spells = {
                natures_swiftness = 17116,
                tree_of_life = 33891,
            },
            proc_flags = {},
            cooldowns = {},
        },
    },
    hunter = {
        beast_mastery = {
            damage_modifier = 13,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 20,
            armor_reduction = 0,
            talents = {
                focused_fire = 35029,
                unleashed_fury = 19616,
                frenzy = 19621,
                ferocious_inspiration = 34455,
                bestial_wrath = 19574,
                serpents_swiftness = 34466,
                the_beast_within = 34692,
            },
            spells = {
                bestial_wrath = 19574,
                the_beast_within = 34692,
            },
            proc_flags = {
                frenzy = true,
                ferocious_inspiration = true,
            },
            cooldowns = {},
        },
        marksmanship = {
            damage_modifier = 5,
            mana_modifier = 10,
            crit_bonus = 30,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                efficiency = 19416,
                go_for_the_throat = 34950,
                mortal_shots = 19485,
                barrage = 19461,
                ranged_weapon_specialization = 19507,
                trueshot_aura = 19506,
                master_marksman = 34485,
                silencing_shot = 34490,
            },
            spells = {
                trueshot_aura = 19506,
                silencing_shot = 34490,
                aimed_shot = 19434,
            },
            proc_flags = {
                go_for_the_throat = true,
            },
            cooldowns = {},
        },
        survival = {
            damage_modifier = 3,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                killer_instinct = 19370,
                resourcefulness = 34491,
                thrill_of_the_hunt = 34497,
                expose_weakness = 34500,
                master_tactician = 34506,
                readiness = 23989,
                wyvern_sting = 19386,
            },
            spells = {
                readiness = 23989,
                wyvern_sting = 19386,
            },
            proc_flags = {
                thrill_of_the_hunt = true,
                expose_weakness = true,
                master_tactician = true,
            },
            cooldowns = {
                trap = 6,
            },
        },
    },
    mage = {
        arcane = {
            damage_modifier = 3,
            mana_modifier = 30,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                arcane_meditation = 18462,
                arcane_mind = 11232,
                arcane_instability = 15058,
                mind_mastery = 31584,
                arcane_power = 12042,
                slow = 31589,
            },
            spells = {
                arcane_power = 12042,
                presence_of_mind = 12043,
                slow = 31589,
            },
            proc_flags = {
                clearcasting = true,
                arcane_potency = true,
            },
            cooldowns = {},
        },
        fire = {
            damage_modifier = 10,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                master_of_elements = 29074,
                playing_with_fire = 31638,
                critical_mass = 11115,
                fire_power = 11124,
                pyromaniac = 34293,
                combustion = 11129,
                molten_fury = 31679,
                pyroblast = 11366,
                dragons_breath = 31661,
            },
            spells = {
                pyroblast = 11366,
                combustion = 11129,
                dragons_breath = 31661,
            },
            proc_flags = {
                master_of_elements = true,
            },
            cooldowns = {},
        },
        frost = {
            damage_modifier = 6,
            mana_modifier = 15,
            crit_bonus = 100,
            haste_modifier = 20,
            armor_reduction = 0,
            talents = {
                ice_shards = 11207,
                piercing_ice = 11151,
                icy_veins = 12472,
                frost_channeling = 11160,
                shatter = 11170,
                ice_barrier = 11426,
                summon_water_elemental = 31687,
            },
            spells = {
                icy_veins = 12472,
                ice_barrier = 11426,
                cold_snap = 11958,
                summon_water_elemental = 31687,
            },
            proc_flags = {},
            cooldowns = {},
        },
    },
    paladin = {
        holy = {
            damage_modifier = 0,
            mana_modifier = 50,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                healing_light = 20237,
                illumination = 20210,
                sanctified_light = 20359,
                holy_power = 5923,
                holy_shock = 20473,
                divine_illumination = 31842,
                purifying_power = 31825,
            },
            spells = {
                divine_favor = 20216,
                holy_shock = 20473,
                divine_illumination = 31842,
            },
            proc_flags = {
                illumination = true,
                lights_grace = true,
            },
            cooldowns = {
                lay_on_hands = 20 * 60,
            },
        },
        protection = {
            damage_modifier = 5,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                improved_righteous_fury = 20468,
                one_handed_weapon_specialization = 20196,
                improved_hammer_of_justice = 20487,
                holy_shield = 20925,
                ardent_defender = 31850,
                combat_expertise = 31858,
                avengers_shield = 31935,
            },
            spells = {
                holy_shield = 20925,
                blessing_of_sanctuary = 20911,
                avengers_shield = 31935,
            },
            proc_flags = {},
            cooldowns = {
                hammer_of_justice = 15,
            },
        },
        retribution = {
            damage_modifier = 9,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                improved_judgement = 25956,
                conviction = 20117,
                seal_of_command = 20375,
                crusade = 31866,
                two_handed_weapon_specialization = 20111,
                sanctity_aura = 20218,
                vengeance = 20049,
                fanaticism = 31879,
                crusader_strike = 35395,
            },
            spells = {
                seal_of_command = 20375,
                repentance = 20066,
                crusader_strike = 35395,
            },
            proc_flags = {
                vengeance = true,
            },
            cooldowns = {
                judgement = 2,
            },
        },
    },
    priest = {
        discipline = {
            damage_modifier = 0,
            mana_modifier = 20,
            crit_bonus = 0,
            haste_modifier = 20,
            armor_reduction = 0,
            talents = {
                meditation = 14521,
                mental_agility = 14520,
                mental_strength = 18551,
                improved_divine_spirit = 33174,
                power_infusion = 10060,
                enlightenment = 34908,
                pain_suppression = 33206,
            },
            spells = {
                power_infusion = 10060,
                pain_suppression = 33206,
                divine_spirit = 14752,
            },
            proc_flags = {
                inner_focus = true,
            },
            cooldowns = {},
        },
        holy = {
            damage_modifier = 10,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                divine_fury = 18530,
                searing_light = 14909,
                spiritual_healing = 14898,
                holy_concentration = 34753,
                empowered_healing = 33158,
                circle_of_healing = 34861,
            },
            spells = {
                holy_nova = 15237,
                lightwell = 724,
                circle_of_healing = 34861,
            },
            proc_flags = {
                holy_concentration = true,
                surge_of_light = true,
            },
            cooldowns = {},
        },
        shadow = {
            damage_modifier = 25,
            mana_modifier = 15,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                shadow_focus = 15260,
                improved_mind_blast = 15273,
                shadow_weaving = 15257,
                focused_mind = 33213,
                darkness = 15259,
                shadowform = 15473,
                shadow_power = 33221,
                misery = 33191,
                vampiric_touch = 34914,
            },
            spells = {
                shadowform = 15473,
                silence = 15487,
                vampiric_touch = 34914,
            },
            proc_flags = {
                shadow_weaving = true,
            },
            cooldowns = {
                mind_blast = 2.5,
            },
        },
    },
    rogue = {
        assassination = {
            damage_modifier = 10,
            mana_modifier = 0,
            crit_bonus = 30,
            haste_modifier = 0,
            armor_reduction = 25,
            talents = {
                murder = 14158,
                improved_expose_armor = 14168,
                lethality = 14128,
                vile_poisons = 16513,
                cold_blood = 14177,
                seal_fate = 14186,
                find_weakness = 31233,
                mutilate = 1329,
            },
            spells = {
                cold_blood = 14177,
                mutilate = 1329,
            },
            proc_flags = {
                seal_fate = true,
                find_weakness = true,
            },
            cooldowns = {},
        },
        combat = {
            damage_modifier = 10,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 20,
            armor_reduction = 0,
            talents = {
                dual_wield_specialization = 13715,
                blade_flurry = 13877,
                aggression = 18427,
                adrenaline_rush = 13750,
                combat_potency = 35541,
                surprise_attacks = 32601,
            },
            spells = {
                blade_flurry = 13877,
                adrenaline_rush = 13750,
                riposte = 14251,
            },
            proc_flags = {
                combat_potency = true,
            },
            cooldowns = {},
        },
        subtlety = {
            damage_modifier = 5,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                opportunity = 14057,
                elusiveness = 13981,
                serrated_blades = 14171,
                hemorrhage = 16511,
                preparation = 14185,
                sinister_calling = 31216,
                shadowstep = 36554,
            },
            spells = {
                hemorrhage = 16511,
                preparation = 14185,
                premeditation = 14183,
                shadowstep = 36554,
            },
            proc_flags = {},
            cooldowns = {
                vanish = 45,
                blind = 90,
            },
        },
    },
    shaman = {
        elemental = {
            damage_modifier = 5,
            mana_modifier = 0,
            crit_bonus = 100,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                convection = 16039,
                concussion = 16035,
                elemental_focus = 16164,
                reverberation = 16040,
                elemental_fury = 16089,
                unrelenting_storm = 30664,
                lightning_mastery = 16578,
                elemental_mastery = 16166,
                lightning_overload = 30675,
                totem_of_wrath = 30706,
            },
            spells = {
                elemental_mastery = 16166,
                totem_of_wrath = 30706,
            },
            proc_flags = {
                clearcasting = true,
                lightning_overload = true,
            },
            cooldowns = {
                shock = 1,
            },
        },
        enhancement = {
            damage_modifier = 10,
            mana_modifier = 60,
            crit_bonus = 0,
            haste_modifier = 30,
            armor_reduction = 0,
            talents = {
                shamanistic_focus = 43338,
                flurry = 16256,
                elemental_weapons = 16266,
                mental_quickness = 30812,
                weapon_mastery = 29082,
                dual_wield = 30798,
                stormstrike = 17364,
                unleashed_rage = 30802,
                shamanistic_rage = 30823,
            },
            spells = {
                dual_wield = 30798,
                stormstrike = 17364,
                shamanistic_rage = 30823,
            },
            proc_flags = {
                flurry = true,
                unleashed_rage = true,
                shamanistic_focus = true,
            },
            cooldowns = {},
        },
        restoration = {
            damage_modifier = 0,
            mana_modifier = 5,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                tidal_focus = 16179,
                natures_guidance = 16180,
                purification = 16178,
                natures_swiftness = 16188,
                mana_tide_totem = 16190,
                natures_blessing = 30867,
                improved_chain_heal = 30872,
                earth_shield = 974,
            },
            spells = {
                natures_swiftness = 16188,
                mana_tide_totem = 16190,
                earth_shield = 974,
            },
            proc_flags = {},
            cooldowns = {},
        },
    },
    warlock = {
        affliction = {
            damage_modifier = 10,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                suppression = 18174,
                amplify_curse = 18288,
                nightfall = 18094,
                shadow_mastery = 18271,
                contagion = 30060,
                malediction = 32477,
                unstable_affliction = 30108,
            },
            spells = {
                amplify_curse = 18288,
                dark_pact = 18220,
                unstable_affliction = 30108,
            },
            proc_flags = {
                nightfall = true,
            },
            cooldowns = {},
        },
        demonology = {
            damage_modifier = 0,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                demonic_knowledge = 35691,
                demonic_tactics = 30242,
                soul_link = 19028,
                demonic_sacrifice = 18788,
                summon_felguard = 30146,
            },
            spells = {
                soul_link = 19028,
                demonic_sacrifice = 18788,
                summon_felguard = 30146,
            },
            proc_flags = {
                demonic_tactics = true,
            },
            cooldowns = {},
        },
        destruction = {
            damage_modifier = 10,
            mana_modifier = 5,
            crit_bonus = 100,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                cataclysm = 17778,
                bane = 17788,
                devastation = 18130,
                ruin = 17959,
                emberstorm = 17954,
                conflagrate = 17962,
                soul_leech = 30293,
                shadow_and_flame = 30288,
                shadowfury = 30283,
            },
            spells = {
                shadowburn = 17877,
                conflagrate = 17962,
                shadowfury = 30283,
            },
            proc_flags = {
                backlash = true,
                soul_leech = true,
            },
            cooldowns = {},
        },
    },
    warrior = {
        arms = {
            damage_modifier = 15,
            mana_modifier = 0,
            crit_bonus = 20,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                deep_wounds = 12834,
                two_handed_weapon_specialization = 12163,
                impale = 16493,
                death_wish = 12292,
                improved_disciplines = 29723,
                blood_frenzy = 29836,
                mortal_strike = 12294,
                improved_mortal_strike = 35446,
                endless_rage = 29623,
            },
            spells = {
                death_wish = 12292,
                mortal_strike = 12294,
            },
            proc_flags = {
                deep_wounds = true,
            },
            cooldowns = {
                mortal_strike = 1,
                retaliation = 30,
                recklessness = 15,
                shield_wall = 30,
            },
        },
        fury = {
            damage_modifier = 0,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 25,
            armor_reduction = 0,
            talents = {
                cruelty = 12320,
                dual_wield_specialization = 23584,
                enrage = 12317,
                flurry = 12319,
                bloodthirst = 23881,
                improved_whirlwind = 29721,
                rampage = 29801,
            },
            spells = {
                bloodthirst = 23881,
                rampage = 29801,
            },
            proc_flags = {
                enrage = true,
                flurry = true,
            },
            cooldowns = {
                whirlwind = 2,
            },
        },
        protection = {
            damage_modifier = 10,
            mana_modifier = 0,
            crit_bonus = 0,
            haste_modifier = 0,
            armor_reduction = 0,
            talents = {
                toughness = 12299,
                improved_taunt = 12302,
                one_handed_weapon_specialization = 16538,
                focused_rage = 29787,
                shield_slam = 23922,
                devastate = 20243,
            },
            spells = {
                shield_slam = 23922,
                devastate = 20243,
            },
            proc_flags = {},
            cooldowns = {
                taunt = 2,
            },
        },
    },
}

local SPEC_ALIASES = {
    beastmastery = "beast_mastery",
    beast_mastery = "beast_mastery",
    marksmanship = "marksmanship",
    survival = "survival",
    feralcombat = "feral",
    feral_combat = "feral",
    feral = "feral",
    restoration = "restoration",
    balance = "balance",
    arcane = "arcane",
    fire = "fire",
    frost = "frost",
    holy = "holy",
    protection = "protection",
    retribution = "retribution",
    discipline = "discipline",
    shadow = "shadow",
    assassination = "assassination",
    combat = "combat",
    subtlety = "subtlety",
    elemental = "elemental",
    enhancement = "enhancement",
    affliction = "affliction",
    demonology = "demonology",
    destruction = "destruction",
    arms = "arms",
    fury = "fury",
}

local spec_cache = {}
local class_talent_cache = {}
local class_spell_cache = {}
local class_cooldown_cache = {}

local function normalize_key(value)
    if not value then
        return nil
    end
    local key = tostring(value):lower()
    key = key:gsub("[^a-z0-9]+", "_")
    key = key:gsub("_+", "_")
    key = key:gsub("^_", "")
    key = key:gsub("_$", "")
    return key
end

local function normalize_class(class_name)
    return normalize_key(class_name)
end

local function normalize_spec(spec_name)
    local key = normalize_key(spec_name)
    if not key then
        return nil
    end
    return SPEC_ALIASES[key] or key
end

local function get_spec_data(class_name, spec_name)
    if not class_name or not spec_name then
        return nil
    end

    local class_key = normalize_class(class_name)
    local spec_key = normalize_spec(spec_name)
    local cache_key = class_key .. ":" .. spec_key
    if spec_cache[cache_key] then
        return spec_cache[cache_key]
    end

    local class_data = DATA[class_key]
    local spec_data = class_data and class_data[spec_key] or nil
    spec_cache[cache_key] = spec_data or false
    return spec_data
end

local function build_class_cache(target_cache, class_key, field_name)
    if target_cache[class_key] then
        return target_cache[class_key]
    end

    local out = {}
    local class_data = DATA[class_key] or {}
    for _, spec_data in pairs(class_data) do
        local source = spec_data[field_name] or {}
        for name, value in pairs(source) do
            if field_name == "cooldowns" then
                if not out[name] or value > out[name] then
                    out[name] = value
                end
            else
                out[name] = value
            end
        end
    end

    target_cache[class_key] = out
    return out
end

function talent_bonus.get_damage_modifier(class_name, spec_name)
    local spec_data = get_spec_data(class_name, spec_name)
    return spec_data and spec_data.damage_modifier or 0
end

function talent_bonus.get_mana_modifier(class_name, spec_name)
    local spec_data = get_spec_data(class_name, spec_name)
    return spec_data and spec_data.mana_modifier or 0
end

function talent_bonus.get_crit_bonus(class_name, spec_name)
    local spec_data = get_spec_data(class_name, spec_name)
    return spec_data and spec_data.crit_bonus or 0
end

function talent_bonus.get_haste_modifier(class_name, spec_name)
    local spec_data = get_spec_data(class_name, spec_name)
    return spec_data and spec_data.haste_modifier or 0
end

function talent_bonus.get_armor_reduction(class_name, spec_name)
    local spec_data = get_spec_data(class_name, spec_name)
    return spec_data and spec_data.armor_reduction or 0
end

function talent_bonus.get_talent_spell_id(class_name, spec_name, talent_name)
    local spec_data = get_spec_data(class_name, spec_name)
    if not spec_data or not talent_name then
        return nil
    end
    return spec_data.talents[normalize_key(talent_name)]
end

function talent_bonus.has_talent(class_name, talent_name, spec_name)
    local class_key = normalize_class(class_name)
    local talent_key = normalize_key(talent_name)
    if not class_key or not talent_key then
        return false
    end

    if spec_name then
        local spec_data = get_spec_data(class_key, spec_name)
        return spec_data and spec_data.talents[talent_key] ~= nil or false
    end

    local talent_map = build_class_cache(class_talent_cache, class_key, "talents")
    return talent_map[talent_key] ~= nil
end

function talent_bonus.get_cooldown_reduction(class_name, spell_name, spec_name)
    local spell_key = normalize_key(spell_name)
    if not spell_key then
        return 0
    end

    if spec_name then
        local spec_data = get_spec_data(class_name, spec_name)
        return spec_data and (spec_data.cooldowns[spell_key] or 0) or 0
    end

    local class_key = normalize_class(class_name)
    local cooldown_map = build_class_cache(class_cooldown_cache, class_key, "cooldowns")
    return cooldown_map[spell_key] or 0
end

function talent_bonus.get_available_spells(class_name, spec_name)
    local spec_data = get_spec_data(class_name, spec_name)
    return spec_data and spec_data.spells or {}
end

function talent_bonus.has_spell(class_name, spell_name, spec_name)
    local class_key = normalize_class(class_name)
    local spell_key = normalize_key(spell_name)
    if not class_key or not spell_key then
        return false
    end

    if spec_name then
        local spec_data = get_spec_data(class_name, spec_name)
        return spec_data and spec_data.spells[spell_key] ~= nil or false
    end

    local spell_map = build_class_cache(class_spell_cache, class_key, "spells")
    return spell_map[spell_key] ~= nil
end

function talent_bonus.get_proc_flags(class_name, spec_name)
    local spec_data = get_spec_data(class_name, spec_name)
    return spec_data and spec_data.proc_flags or {}
end

function talent_bonus.get_spec_data(class_name, spec_name)
    return get_spec_data(class_name, spec_name)
end

talent_bonus.TALENT_CONSTANTS = DATA

return talent_bonus
