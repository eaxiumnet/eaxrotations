-- apl_status.lua — APL conformance manifest + live status (Phase 2, made real).
-- WHAT:  Single source of truth for the pinned wowsims APL fixtures. For each
--        conformant spec it maps fixture -> spec file -> spell-id resolver,
--        loads the spec under the mock-NS harness, parses the pinned fixture
--        with shared/apl_parser.lua, and computes a live pass/fail verdict +
--        evidence string. tools/spec_scorecard.lua consumes compute() so the
--        APL column is auto-filled (no hardcoded APL_STATUS) and
--        tests/test_apl_conformance.lua iterates the same ENTRIES so the CI
--        gate and the scorecard can never drift apart.
-- WHEN:  loaded by tools/spec_scorecard.lua and tests/test_apl_conformance.lua
--        (via package.path "tools/?.lua"); no game API touched at load time.
-- WHY:   Phase 2 — _wotlk.lua strategy order must match the pinned wowsims APL
--        priority list; this module makes "pass" a computed, evidence-backed
--        fact instead of a hand-maintained table entry.
-- SAFETY: pure data + loader; nil-tolerant; fixtures are git-tracked.

-- Self-contained: ensure shared/ and tools/ resolvable regardless of caller.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;tools/?.lua;" .. package.path

local apl = require("shared/apl_parser")

local M = {}

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
M.read_file = read_file

-- ---------------------------------------------------------------------------
-- Mock-NS loader (shared with test_apl_conformance.lua so both exercise the
-- exact same load path).
-- ---------------------------------------------------------------------------
local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

-- Which class id does the mock player report? Specs that gate on
-- enums.class_id.<CLASS> at require() time (smite PRIEST, kebab WARRIOR)
-- bail unless it matches; load_spec sets _mock_player_class before dofile.
local _mock_player_class = 5 -- PRIEST default

local function base_ns()
    return {
        -- Mock marker (survey item #2): shared modules that bind exports into
        -- _G.EaxRotations at require() time (auto_tremor, dot_refresh, purge_manager,
        -- mf_tick_compute, etc.) must NOT write into a mock NS. base_ns() is installed
        -- as _G.EaxRotations while spec files are dofile'd for APL conformance; without
        -- the marker those write-backs would bind module instances into a mock that is
        -- discarded per-entry — pure pollution that can shadow real-engine bindings.
        _EAX_MOCK = true,
        GetPlayer = function() return {
            get_health_percentage = function() return 80 end,
            get_mana_percentage = function() return 80 end,
            get_energy = function() return 100 end,
            get_combo_points = function() return 5 end,
            get_class = function() return _mock_player_class end,
            get_race_id = function() return 1 end,
        } end,
        me = {
            get_health_percentage = function() return 80 end,
            get_mana_percentage = function() return 80 end,
            get_energy = function() return 100 end,
            get_combo_points = function() return 5 end,
        },
        core = {
            spell_book = { get_spell_cast_time = function() return 1.75 end },
        },
        -- Some TBC-era files (smite_sylvanas) read NS.PLAYER_UNIT /
        -- NS.GetPlayer() / NS.is_threat_safe at require() time.
        PLAYER_UNIT = {
            get_health_percentage = function() return 80 end,
            get_mana_percentage = function() return 80 end,
            get_energy = function() return 100 end,
            get_combo_points = function() return 5 end,
        },
        -- CLASS_ID mirrors api/common/enums class_id (a table, not a number) so
        -- specs that gate on enums.class_id.PRIEST etc. load under the mock.
        CLASS_ID = {
            warrior = 1, paladin = 2, hunter = 3, rogue = 4,
            priest = 5, deathknight = 6, shaman = 7, mage = 8, warlock = 9, druid = 11,
            WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4,
            PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
        },
        class_id = nil, -- set below after table literal
        is_threat_safe = function() return true end,
        unit_creature_type = function() return 0 end,
        debuff_up = function() return false end,
        aoe_self_meets = function() return false end,
        get_spell_id = function(action) return type(action) == 'table' and action.id or nil end,
        spell_action = make_action,
        spell_ready = function() return true end,
        spell_exists = function() return true end,
        try_cast = function() return true end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        debuff_stacks = function() return 0 end,
        get_debuff_stacks = function() return 0 end,
        cooldown_remains = function() return 0 end,
        is_behind_target = function() return true end,
        is_item_ready = function() return false end,
        use_item_by_id = function() return true end,
        broken_api_throttled = function() return false end,
        should_use_long_cd = function() return true end,
        time_now = function() return 0 end,
        log = function() end,
        log_warning = function() end,
        -- Some TBC-era spec files call NS.import_helpers(...) at require() time
        -- (e.g. priest/smite_sylvanas.lua, warrior/kebab_sylvanas.lua). The real
        -- implementation is populated on class registration; return permissive
        -- stubs so those files load under the mock. Health/player-buff helpers
        -- are unit-aware via the same forwarding used by the battery.
        import_helpers = function(...)
            local names = { ... }
            local results = {}
            local typed = {
                debuff_remains = 0, debuff_stacks = 0, buff_remains = 0, buff_stacks = 0,
            }
            for i = 1, #names do
                local n = names[i]
                if typed[n] ~= nil then
                    results[i] = function() return typed[n] end
                elseif n == 'health_pct' then
                    results[i] = function(unit)
                        if unit and unit.get_health_percentage then
                            local ok, v = pcall(unit.get_health_percentage, unit)
                            if ok and type(v) == 'number' then return v end
                        end
                        return 100
                    end
                elseif n == 'has_player_buff' then
                    results[i] = function(id) return false end
                else
                    results[i] = function() return true end
                end
            end
            -- Lua 5.1 has no unpack; table.unpack exists in 5.2+. Build a
            -- vararg tuple manually so smite/kebab get all requested names.
            return (function(...) return ... end)(table.unpack and table.unpack(results) or unpack(results))
        end,
        rotation_registry = {
            register = function(self, name, strategies, options) end,
        },
    }
end

-- Load a spec file's strategy table under the mock NS. `spells` names the
-- action table to inject (e.g. "MageSpells"), `actions` maps strategy name ->
-- spell id (or id list).
function M.load_spec(spec_file, spells, actions, class_id)
    _G.EaxRotations = base_ns()
    -- Reset per call: do NOT inherit the previous entry's class. Spec files
    -- that guard on player class (kebab->WARRIOR, smite->PRIEST) bail loudly on
    -- a mismatch, so an entry that omits class_id must not silently borrow the
    -- prior entry's class (would produce confusing failures). Entries without
    -- class_id (all wotlk/*) fall back to the documented default (PRIEST).
    _mock_player_class = class_id or 5
    local t = {}
    for name, ids in pairs(actions) do t[name] = make_action(ids, name) end
    _G.EaxRotations[spells] = t
    local ok_dofile, mod = pcall(dofile, spec_file)
    if not ok_dofile then
        error(spec_file .. " failed to load: " .. tostring(mod))
    end
    if type(mod) ~= "table" or type(mod.strategies) ~= "table" then
        error(spec_file .. " should return { strategies = ... } (got " .. type(mod) .. ")")
    end
    return mod.strategies
end

function M.strategy_names(strategies)
    local names = {}
    for i, s in ipairs(strategies) do names[i] = s.name end
    return names
end

-- ---------------------------------------------------------------------------
-- Conformance manifest.
-- Each entry: key (era-qualified), fixture (pinned JSON path), spec_file,
-- spells (action-table name), actions (name -> spell id), and EITHER:
--   resolve(id, occurrence)  -> strategy name for JSON fixtures, or
--   reference_names          -> ordered name list (Go black-box specs like
--                               feral cat; see tools/evidence/apl/SOURCES.md).
-- Add a new conformant spec here (plus its pinned fixture + SOURCES.md row).
-- ---------------------------------------------------------------------------
local function fire_resolve(id, occurrence)
    if id == 42859 then
        return occurrence == 1 and "Scorch" or "ScorchFinal"
    end
    if id == 42891 then return "Pyroblast" end
    if id == 55360 then return "LivingBomb" end
    if id == 42873 then return "FireBlast" end
    if id == 42833 then return "Fireball" end
    return nil
end

local function affl_resolve(id)
    if id == 59164 then return "Haunt" end
    if id == 47813 then return "Corruption" end
    if id == 47843 then return "UnstableAffliction" end
    if id == 47864 then return "CurseOfAgony" end
    if id == 47855 then return "DrainSoul" end
    if id == 47809 then return "ShadowBolt" end
    return nil
end

-- feral: JSON is a Go black box (catOptimalRotationAction) — reference order
-- pinned from sim/druid/feral/rotation.go doRotation() dispatch at the same
-- wowsims commit (see tools/evidence/apl/SOURCES.md).
local FERAL_REFERENCE = {
    "FaerieFireFeral", "SavageRoar", "Rip", "FerociousBite", "MangleCat", "Rake", "Shred",
}

-- ---------------------------------------------------------------------------
-- Resolvers for the Phase-2 batch (2026-08-09): arcane/frost mage,
-- combat/assassination rogue, elemental shaman, shadow priest. Occurrence-aware
-- like fire's Scorch (occ 2 of a repeated id resolves to a name absent from the
-- rotation, which the checker ignores) — the sim lists the same spell twice
-- (e.g. AB stacker + AB filler), our single strategy covers both.
-- ---------------------------------------------------------------------------
local function arcane_resolve(id, occurrence)
    if id == 42897 then -- Arcane Blast (stacker occ 1, mana>25 filler occ 2)
        return occurrence == 1 and "ArcaneBlast" or "ArcaneBlastFiller"
    end
    if id == 42846 then -- Arcane Missiles (proc occ 1, filler occ 2)
        return occurrence == 1 and "ArcaneMissiles" or "ArcaneMissilesFiller"
    end
    if id == 12051 then return "Evocation" end
    return nil
end

local function frost_resolve(id)
    if id == 44572 then return "DeepFreeze" end
    if id == 47610 then return "FrostfireBolt" end -- 47610 = max-rank FFB
    if id == 42842 then return "Frostbolt" end
    return nil
end

local function combat_resolve(id)
    if id == 6774 then return "SliceAndDice" end
    if id == 48638 then return "SinisterStrike" end
    if id == 48668 then return "Eviscerate" end
    if id == 13877 then return "BladeFlurry" end
    if id == 51690 then return "KillingSpree" end
    return nil
end

local function assassination_resolve(id)
    if id == 6774 then return "SliceAndDice" end
    if id == 51662 then return "HungerForBlood" end
    if id == 57934 then return "TricksOfTheTrade" end
    if id == 57993 then return "Envenom" end
    if id == 48666 then return "Mutilate" end
    return nil
end

local function elemental_resolve(id)
    if id == 2825 then return "Bloodlust" end
    if id == 16166 then return "ElementalMastery" end
    if id == 58704 then return "SearingTotem" end
    if id == 49233 then return "FlameShock" end
    if id == 60043 then return "LavaBurst" end
    if id == 49271 then return "ChainLightning" end
    if id == 49238 then return "LightningBolt" end
    if id == 59159 then return "Thunderstorm" end
    return nil
end

local function shadow_resolve(id, occurrence)
    if id == 48300 then -- Devouring Plague (execute occ 1, refresh occ 2)
        return occurrence == 1 and "DevouringPlague" or "DevouringPlagueRefresh"
    end
    if id == 48125 then return "ShadowWordPain" end
    if id == 48160 then return "VampiricTouch" end
    if id == 48127 then return "MindBlast" end
    if id == 48156 then return "MindFlay" end
    return nil
end

M.ENTRIES = {
    {
        key = "wotlk/fire",
        fixture = "tools/evidence/apl/fire_wotlk.apl.json",
        spec_file = "EaxRotations/classes/mage/fire_wotlk.lua",
        spells = "MageSpells",
        actions = {
            Pyroblast = 42891, LivingBomb = 55360, FireBlast = 42873,
            Scorch = 42859, Fireball = 42833, Combustion = 11129,
        },
        resolve = fire_resolve,
    },
    {
        key = "wotlk/affliction",
        fixture = "tools/evidence/apl/affliction_wotlk.apl.json",
        spec_file = "EaxRotations/classes/warlock/affliction_wotlk.lua",
        spells = "WarlockSpells",
        actions = {
            UnstableAffliction = 47843, Haunt = 59164, Corruption = 47813,
            CurseOfAgony = 47864, DrainSoul = 47855, ShadowBolt = 47809,
        },
        resolve = affl_resolve,
    },
    {
        key = "wotlk/cat",
        fixture = "tools/evidence/apl/feralcat_wotlk.apl.json",
        spec_file = "EaxRotations/classes/druid/cat_wotlk.lua",
        spells = "DruidSpells",
        actions = {
            FaerieFireFeral = 27011, Ravage = 27005, MangleCat = 48566,
            Rake = 48574, Rip = 49800, SavageRoar = 52610,
            FerociousBite = 48576, Shred = 48572,
        },
        reference_names = FERAL_REFERENCE,
    },
    {
        key = "wotlk/arcane",
        fixture = "tools/evidence/apl/arcane_wotlk.apl.json",
        spec_file = "EaxRotations/classes/mage/arcane_wotlk.lua",
        spells = "MageSpells",
        actions = {
            ArcaneBlast = 42897, ArcaneMissiles = 42846, Evocation = 12051,
            ArcaneBarrage = 44425, ArcanePower = 12042, IcyVeins = 12472,
            MirrorImage = 55342, PresenceOfMind = 12043, Counterspell = 2139,
            ConjureManaEmerald = 27101, MageArmor = 43024,
        },
        resolve = arcane_resolve,
    },
    {
        key = "wotlk/frost",
        fixture = "tools/evidence/apl/frost_wotlk.apl.json",
        spec_file = "EaxRotations/classes/mage/frost_wotlk.lua",
        spells = "MageSpells",
        actions = {
            DeepFreeze = 44572, FrostfireBolt = 47610, Frostbolt = 42842,
            IceLance = 42914, ColdSnap = 11958,
        },
        resolve = frost_resolve,
    },
    {
        key = "wotlk/combat",
        fixture = "tools/evidence/apl/combat_wotlk.apl.json",
        spec_file = "EaxRotations/classes/rogue/combat_wotlk.lua",
        spells = "RogueSpells",
        actions = {
            SliceAndDice = 6774, SinisterStrike = 48638, Eviscerate = 48668,
            BladeFlurry = 13877, KillingSpree = 51690,
        },
        resolve = combat_resolve,
    },
    {
        key = "wotlk/assassination",
        fixture = "tools/evidence/apl/mutilate_wotlk.apl.json",
        spec_file = "EaxRotations/classes/rogue/assassination_wotlk.lua",
        spells = "RogueSpells",
        actions = {
            SliceAndDice = 6774, HungerForBlood = 51662, TricksOfTheTrade = 57934,
            Envenom = 57993, Mutilate = 48666, Rupture = 48672,
        },
        resolve = assassination_resolve,
    },
    {
        key = "wotlk/elemental",
        fixture = "tools/evidence/apl/elemental_wotlk.apl.json",
        spec_file = "EaxRotations/classes/shaman/elemental_wotlk.lua",
        spells = "ShamanSpells",
        actions = {
            Bloodlust = 2825, ElementalMastery = 16166, SearingTotem = 58704,
            FlameShock = 49233, LavaBurst = 60043, ChainLightning = 49271,
            LightningBolt = 49238, Thunderstorm = 59159, FireElemental = 2894,
            TotemOfWrath = 57722,
        },
        resolve = elemental_resolve,
    },
    {
        key = "wotlk/shadow",
        fixture = "tools/evidence/apl/shadow_wotlk.apl.json",
        spec_file = "EaxRotations/classes/priest/shadow_wotlk.lua",
        spells = "PriestSpells",
        actions = {
            DevouringPlague = 48300, ShadowWordPain = 48125, VampiricTouch = 48160,
            MindBlast = 48127, MindFlay = 48156,
        },
        resolve = shadow_resolve,
    },
    -- -----------------------------------------------------------------------
    -- HEALER pins (2026-08-10): wowsims/wotlk HAS a real, executed healing
    -- priest sim — sim/priest/healing/healing_priest.go + healing_priest_test.go
    -- (TestDisc/TestHoly run with IsHealer:true against core.GetAplRotation of
    -- these exact JSONs). This corrects the earlier "no healer APL exists" claim
    -- (see tools/evidence/apl/SOURCES.md). The APLs are CPM-budget profiles
    -- (spellCpm conditions), NOT full DPS priority lists — the pin therefore
    -- enforces the ORDER of the spell actions (the sim's evaluation order), not
    -- the CPM budgets. Spells absent from our rotation resolve to nil and are
    -- ignored (holy: Circle of Healing 48089 — no CoH strategy in holy_wotlk;
    -- disc: the 1-CPM filler GreaterHeal 48063 — disc_wotlk uses Renew instead),
    -- mirroring the TBC seed/AoE-branch exclusion policy. Keys are
    -- class-qualified (wotlk/priest/holy NOT wotlk/holy) so the scorecard's
    -- WotLK lookup cannot collide with holy PALADIN.
    -- -----------------------------------------------------------------------
    {
        key = "wotlk/priest/holy",
        fixture = "tools/evidence/apl/holy_priest_wotlk.apl.json",
        spec_file = "EaxRotations/classes/priest/holy_wotlk.lua",
        spells = "PriestSpells",
        actions = {
            GreaterHeal = 48063, Renew = 48068, PrayerofMending = 33076,
            GuardianSpirit = 47788, FlashHeal = 48071,
        },
        -- APL order: GreaterHeal(48063) -> CircleOfHealing(48089, absent) ->
        -- Renew(48068, multidot) -> PrayerOfMending(48113). Our rotation was
        -- Renew/PoM ABOVE GreaterHeal (a genuine divergence, fixed 2026-08-10
        -- as a pure order move in holy_wotlk.lua — see SOURCES.md).
        resolve = function(id, occurrence)
            if id == 48063 then return "GreaterHeal" end
            if id == 48089 then return nil end -- Circle of Healing: no CoH strategy
            if id == 48068 then return "Renew" end
            if id == 48113 then return "PrayerOfMending" end
            return nil
        end,
    },
    {
        key = "wotlk/priest/discipline",
        fixture = "tools/evidence/apl/disc_priest_wotlk.apl.json",
        spec_file = "EaxRotations/classes/priest/discipline_wotlk.lua",
        spells = "PriestSpells",
        actions = {
            PowerWordShield = 48066, Penance = 47540, PrayerofMending = 33076,
            Renew = 48068,
        },
        -- APL order: PowerWordShield(48066, multishield) -> Penance(53007) ->
        -- PrayerOfMending(48113) -> GreaterHeal(48063, 1-CPM filler, absent
        -- from disc_wotlk — Renew is our filler instead, imposes no constraint).
        resolve = function(id, occurrence)
            if id == 48066 then return "PowerWordShield" end
            if id == 53007 then return "Penance" end -- sim max-rank; ours is 47540
            if id == 48113 then return "PrayerOfMending" end -- sim max-rank; ours is 33076
            if id == 48063 then return nil end -- GreaterHeal filler: not in disc rotation
            return nil
        end,
    },
    -- -----------------------------------------------------------------------
    -- TBC era (Phase 2-TBC, 2026-08-09). wowsims/tbc has NO TypeAPL JSON
    -- fixtures (that format postdates the TBC repo) — rotations are imperative
    -- Go dispatch files, so each pin below is a `reference_names` list extracted
    -- from the sim's dispatch check-order at wowsims/tbc master (see
    -- tools/evidence/apl/SOURCES.md). `check_name_order` only enforces relative
    -- order of names present in BOTH lists, so Go extras (curses switch,
    -- Starshards racial, seed/AoE branches) are deliberately excluded and our
    -- extra strategies (potions/defensives) are ignored. All pilots verified
    -- conformant; healers (holy/disc/resto/healing) have no wowsims rotation
    -- and stay `pending` by design.
    -- -----------------------------------------------------------------------
    {
        key = "tbc/shadow",
        class_id = 5,
        spec_file = "EaxRotations/classes/priest/shadow_sylvanas.lua",
        spells = "PriestSpells",
        actions = {
            VampiricTouch = 34914, ShadowWordPain = 25368, DevouringPlague = 25467,
            MindBlast = 25375, MindFlay = 25387,
        },
        reference_names = { "VampiricTouch", "ShadowWordPain", "DevouringPlague", "MindBlast", "MindFlay" },
    },
    {
        key = "tbc/affliction",
        class_id = 9,
        spec_file = "EaxRotations/classes/warlock/affliction_sylvanas.lua",
        spells = "WarlockSpells",
        actions = {
            UnstableAffliction = 30108, Corruption = 27216, SiphonLife = 30911,
            Immolate = 27215, ShadowBolt = 27209,
        },
        -- NOTE: names must be the ACTUAL strategy names in the file
        -- (CorruptionDoT / ImmolateDoT / ShadowBoltFiller), not the spell
        -- names — check_name_order matches strategy names exactly.
        reference_names = { "UnstableAffliction", "CorruptionDoT", "SiphonLife", "ImmolateDoT", "ShadowBoltFiller" },
    },
    {
        key = "tbc/combat",
        class_id = 4,
        spec_file = "EaxRotations/classes/rogue/combat_sylvanas.lua",
        spells = "RogueSpells",
        actions = {
            SliceAndDice = 6774, Eviscerate = 26865, SinisterStrike = 26862,
        },
        reference_names = { "SliceAndDice", "Eviscerate", "SinisterStrike" },
    },
    {
        key = "tbc/elemental",
        class_id = 7,
        spec_file = "EaxRotations/classes/shaman/elemental_sylvanas.lua",
        spells = "ShamanSpells",
        actions = {
            ChainLightning = 25442, LightningBolt = 25449,
        },
        -- wowsims TBC elemental is LB/CL-only (no FlameShock in the sim
        -- rotation); FlameShock/other strategies are our extras, ignored.
        reference_names = { "ChainLightning", "LightningBolt" },
    },
    {
        key = "tbc/fire",
        class_id = 8,
        spec_file = "EaxRotations/classes/mage/fire_sylvanas.lua",
        spells = "MageSpells",
        actions = {
            Scorch = 2948, Fireball = 27070,
        },
        -- wowsims TBC fire: Scorch 5-stack maintenance -> Fireball filler.
        -- FireBlast weave is an OPT-IN (WeaveFireBlast defaults false in
        -- ui/mage/inputs.ts), so it is not part of the default pin.
        reference_names = { "Scorch", "Fireball" },
    },
    {
        key = "tbc/frost",
        class_id = 8,
        spec_file = "EaxRotations/classes/mage/frost_sylvanas.lua",
        spells = "MageSpells",
        actions = {
            Frostbolt = 27072,
        },
        reference_names = { "Frostbolt" },
    },
    -- -----------------------------------------------------------------------
    -- TBC batch 2 (2026-08-09): 13 more sylvanas DPS specs wired from the same
    -- Go dispatch files. Balance pin excludes Hurricane (AoE branch, 3+ targets
    -- — same policy as the seed/AoE exclusion for affliction); smite pin
    -- excludes HolyFire (opt-in weave, RotationType HolyFireWeave — same policy
    -- as WeaveFireBlast for fire). All pins verified conformant; divergences
    -- were fixed in the spec files (see git log: cat Mangle<Rip, hunter
    -- sting<MultiShot x3, demo SiphonLife<Immolate, arms WW<Overpower).
    -- -----------------------------------------------------------------------
    {
        key = "tbc/balance",
        class_id = 11,
        spec_file = "EaxRotations/classes/druid/balance_sylvanas.lua",
        spells = "DruidSpells",
        actions = {
            FaerieFire = 26993, InsectSwarm = 27013, Moonfire = 26988, Starfire = 26986,
        },
        reference_names = { "FaerieFireDebuff", "InsectSwarmDoT", "MoonfireDoT", "StarfirePrimary" },
    },
    {
        key = "tbc/cat",
        class_id = 11,
        spec_file = "EaxRotations/classes/druid/cat_sylvanas.lua",
        spells = "DruidSpells",
        actions = {
            FaerieFireFeral = 27011, Rip = 27008, MangleCat = 33983, FerociousBite = 24248, Shred = 27002,
        },
        reference_names = { "FaerieFireFeral", "Rip", "MangleDebuff", "FerociousBite", "Shred" },
    },
    {
        key = "tbc/beast_mastery",
        class_id = 3,
        spec_file = "EaxRotations/classes/hunter/beast_mastery_sylvanas.lua",
        spells = "HunterSpells",
        actions = {
            SerpentSting = 27016, MultiShot = 27021, ArcaneShot = 27019, SteadyShot = 34120,
        },
        reference_names = { "SerpentSting", "MultiShot", "ArcaneShot", "SteadyShot" },
    },
    {
        key = "tbc/marksmanship",
        class_id = 3,
        spec_file = "EaxRotations/classes/hunter/marksmanship_sylvanas.lua",
        spells = "HunterSpells",
        actions = {
            SerpentSting = 27016, MultiShot = 27021, ArcaneShot = 27019, SteadyShot = 34120,
        },
        reference_names = { "SerpentSting", "MultiShot", "ArcaneShot", "SteadyShot" },
    },
    {
        key = "tbc/survival",
        class_id = 3,
        spec_file = "EaxRotations/classes/hunter/survival_sylvanas.lua",
        spells = "HunterSpells",
        actions = {
            SerpentSting = 27016, MultiShot = 27021, ArcaneShot = 27019, SteadyShot = 34120,
        },
        reference_names = { "SerpentSting", "MultiShot", "ArcaneShot", "SteadyShot" },
    },
    {
        key = "tbc/arcane",
        class_id = 8,
        spec_file = "EaxRotations/classes/mage/arcane_sylvanas.lua",
        spells = "MageSpells",
        actions = {
            ArcaneBlast = 30451, Frostbolt = 27072, ArcaneMissiles = 38699,
        },
        reference_names = { "ArcaneBlast", "FrostboltConserve", "ArcaneMissiles" },
    },
    {
        key = "tbc/retribution",
        class_id = 2,
        spec_file = "EaxRotations/classes/paladin/retribution_sylvanas.lua",
        spells = "PaladinSpells",
        actions = {
            Judgement = 20271, CrusaderStrike = 35395, SealBlood = 31892,
        },
        reference_names = { "Ret_JudgeCrusader", "Ret_ApplyCrusaderSeal", "CrusaderStrike", "Ret_SealBlood_Primary" },
    },
    {
        key = "tbc/smite",
        class_id = 5,
        spec_file = "EaxRotations/classes/priest/smite_sylvanas.lua",
        spells = "PriestSpells",
        actions = {
            ShadowWordPain = 25368, Starshards = 25446, DevouringPlague = 25467, MindBlast = 25375, Smite = 25364,
        },
        reference_names = { "ShadowWordPain", "Starshards", "DevouringPlague", "MindBlast", "SmiteFiller" },
    },
    {
        key = "tbc/enhancement",
        class_id = 7,
        spec_file = "EaxRotations/classes/shaman/enhancement_sylvanas.lua",
        spells = "ShamanSpells",
        actions = {
            Stormstrike = 17364, FlameShock = 25457, EarthShock = 25454, FrostShock = 25464,
        },
        reference_names = { "Stormstrike", "FlameShock", "EarthShock", "FrostShock" },
    },
    {
        key = "tbc/demonology",
        class_id = 9,
        spec_file = "EaxRotations/classes/warlock/demonology_sylvanas.lua",
        spells = "WarlockSpells",
        actions = {
            Corruption = 27216, SiphonLife = 30911, Immolate = 27215, ShadowBolt = 27209,
        },
        reference_names = { "Corruption", "SiphonLife", "Immolate", "ShadowBolt" },
    },
    {
        key = "tbc/destruction",
        class_id = 9,
        spec_file = "EaxRotations/classes/warlock/destruction_sylvanas.lua",
        spells = "WarlockSpells",
        actions = {
            Corruption = 27216, Immolate = 27215, Incinerate = 32231,
        },
        reference_names = { "Corruption", "Immolate", "Incinerate" },
    },
    {
        key = "tbc/arms",
        class_id = 1,
        spec_file = "EaxRotations/classes/warrior/arms_sylvanas.lua",
        spells = "WarriorSpells",
        actions = {
            Execute = 25236, MortalStrike = 30330, Whirlwind = 1680, Overpower = 11585,
        },
        reference_names = { "Execute", "MortalStrike", "Whirlwind", "Overpower" },
    },
    {
        key = "tbc/fury",
        class_id = 1,
        spec_file = "EaxRotations/classes/warrior/fury_sylvanas.lua",
        spells = "WarriorSpells",
        actions = {
            Execute = 25236, Bloodthirst = 30335, Whirlwind = 1680, Overpower = 11585,
        },
        reference_names = { "Execute", "Bloodthirst", "Whirlwind", "Overpower" },
    },
    -- Batch 3: remaining DPS/tank specs with a wowsims/tbc Go dispatch.
    -- druid bear: sim/druid_tank_rotation.go doRotation checks FaerieFire BEFORE
    -- DemoralizingRoar, then Mangle > Lacerate (Swipe is AoE/AP-gated, Maul is
    -- queued on-next-swing — both excluded as non-GCD branches).
    {
        key = "tbc/bear",
        class_id = 11,
        spec_file = "EaxRotations/classes/druid/bear_sylvanas.lua",
        spells = "DruidSpells",
        actions = {
            FaerieFireFeral = 27011, DemoralizingRoar = 26998, MangleBear = 33987, Lacerate = 33745,
        },
        reference_names = { "FaerieFireFeral", "DemoralizingRoar", "MangleBear", "Lacerate" },
    },
    -- paladin protection: sim/paladin_protection_rotation.go OnGCDReady checks
    -- HolyShield -> Consecration -> Judgement/Seal -> Exorcism (seal is applied
    -- on the Judgement branch; AoE Avenger's Shield excluded as not in the GCD).
    {
        key = "tbc/paladin/protection",
        class_id = 2,
        spec_file = "EaxRotations/classes/paladin/protection_sylvanas.lua",
        spells = "PaladinSpells",
        actions = {
            HolyShield = 27179, Consecration = 27173, Judgement = 20271,
            SealRighteousness = 27155, Exorcism = 27138,
        },
        reference_names = { "HolyShield", "Consecration", "Judgement", "SealRighteousness", "Exorcism" },
    },
    -- warrior protection: DEDICATED sim/warrior/protection/rotation.go
    -- doRotation: ShieldSlam -> Bloodthirst -> MortalStrike -> Revenge ->
    -- Shout -> ThunderClap -> DemoShout -> Devastate -> SunderArmor.
    -- (Corrected 2026-08-09: the earlier pin cited sim/warrior_dps_rotation.go
    -- and claimed "Revenge is not modeled by the sim" — WRONG; the dedicated
    -- protection file DOES model Revenge. Bloodthirst/MortalStrike are
    -- arms/fury talents absent from the prot rotation. Shout (Battle Shout) is
    -- a buff-maintenance lane our rotation places far below the sim's mid-chain
    -- check — excluded with that honest reason. ThunderClap is checked before
    -- DemoShout in the dispatch; our ACTIONS table was REVERSED and is now
    -- reordered to match (pure order move, 2026-08-09) so both are pinnable.)
    {
        key = "tbc/warrior/protection",
        class_id = 1,
        spec_file = "EaxRotations/classes/warrior/protection_sylvanas.lua",
        spells = "WarriorSpells",
        actions = {
            ShieldSlam = 30356, Revenge = 30357, ThunderClap = 25264,
            DemoralizingShout = 25203, Devastate = 30022, SunderArmor = 25225,
        },
        reference_names = { "ShieldSlam", "Revenge", "ThunderClap", "DemoralizingShout", "Devastate", "SunderArmor" },
    },
    -- druid caster: solo/leveling Moonfire/Wrath rotation (no wowsims "caster"
    -- preset exists — the only druid caster dispatch is the balance moonkin
    -- rotation). Pin the damage chain shared with the balance Go dispatch
    -- (FaerieFire -> Moonfire -> primary filler): Hurricane/InsectSwarm/Starfire
    -- are the raid branches the leveling rotation deliberately omits, and
    -- Barkskin/Thorns/Innervate are defensives excluded like potions.
    {
        key = "tbc/caster",
        class_id = 11,
        spec_file = "EaxRotations/classes/druid/caster_sylvanas.lua",
        spells = "DruidSpells",
        actions = {
            FaerieFire = 26993, Moonfire = 26988, Wrath = 26985,
        },
        reference_names = { "FaerieFire", "Moonfire", "Wrath" },
    },
}

-- ---------------------------------------------------------------------------
-- Live compute: verdict + evidence per manifest entry.
-- Returns { status = { [key] = "pass"|"fail" }, evidence = { [key] = "..." } }.
-- A spec whose reference ids are entirely absent from our rotation is NOT a
-- conformance failure per se (the checker ignores unknown names) — but we
-- report zero-match entries as "fail" with evidence, because a fixture that
-- resolves nothing is silently testing nothing.
-- ---------------------------------------------------------------------------
function M.compute()
    local status, evidence = {}, {}
    for _, e in ipairs(M.ENTRIES) do
        local ok, err = pcall(function()
            local strategies = M.load_spec(e.spec_file, e.spells, e.actions, e.class_id)
            local names = M.strategy_names(strategies)
            local known = {}
            for _, n in ipairs(names) do known[n] = true end
            local violation
            if e.reference_names then
                -- Vacuity guard (mirrors test_apl_conformance.lua): check_name_order
                -- SILENTLY SKIPS names absent from our rotation, so a typo'd pin
                -- would otherwise compute "pass" while testing nothing. Every
                -- pinned name must resolve — else fail with the offenders. An
                -- EMPTY pin is equally vacuous (mirrors the #ids==0 guard on the
                -- fixture path below).
                if #e.reference_names == 0 then
                    error("reference_names pin is empty (tests nothing)")
                end
                local missing = {}
                for _, n in ipairs(e.reference_names) do
                    if not known[n] then missing[#missing + 1] = n end
                end
                if #missing > 0 then
                    error("reference_names pin has names missing from the rotation: "
                        .. table.concat(missing, ", ") .. " (actual: " .. table.concat(names, ", ") .. ")")
                end
                violation = apl.check_name_order(names, e.reference_names)
            else
                local raw = M.read_file(e.fixture)
                if not raw then error("missing fixture: " .. e.fixture) end
                local ids = apl.priority_ids(apl.decode_json(raw))
                if #ids == 0 then error("fixture has no priority ids: " .. e.fixture) end
                -- Vacuity guard (mirrors the test): a resolver that maps ZERO
                -- fixture ids to real strategy names is testing nothing — fail it.
                -- Occurrence-aware like check_id_order (repeat ids may resolve to
                -- names absent from the rotation, e.g. ArcaneBlastFiller).
                local seen, resolved, occurrence = {}, 0, {}
                for _, id in ipairs(ids) do
                    occurrence[id] = (occurrence[id] or 0) + 1
                    local name = e.resolve(id, occurrence[id])
                    if name and not seen[name] then
                        seen[name] = true
                        if known[name] then resolved = resolved + 1 end
                    end
                end
                if resolved == 0 then
                    error("resolver maps 0 fixture ids to real strategies (vacuous check)")
                end
                violation = apl.check_id_order(names, ids, e.resolve)
            end
            if violation then
                status[e.key] = "fail"
                evidence[e.key] = string.format(
                    "%s: ORDER VIOLATION: %s (pos %d) should precede %s (pos %d)",
                    e.reference_names and table.concat(e.reference_names, " > ") or e.fixture,
                    violation.prev, violation.prev_pos,
                    violation.name, violation.name_pos)
            else
                status[e.key] = "pass"
                -- Prefer the fixture label when both exist (e.g. wotlk/cat has
                -- a tracked JSON fixture AND a Go reference_names pin).
                evidence[e.key] = (e.fixture and (e.reference_names
                        and e.fixture .. ": conformant (Go reference: " .. table.concat(e.reference_names, " > ") .. ")"
                        or e.fixture .. ": conformant"))
                    or (e.reference_names and "Go reference: " .. table.concat(e.reference_names, " > "))
            end
        end)
        if not ok then
            status[e.key] = "fail"
            evidence[e.key] = "compute error: " .. tostring(err)
        end
    end
    return { status = status, evidence = evidence }
end

-- ---------------------------------------------------------------------------
-- Standalone mode: print the live status table (evidence for humans).
--   lua tools/apl_status.lua
-- ---------------------------------------------------------------------------
if arg and arg[0] and arg[0]:find("apl_status%.lua$") and select("#", ...) == 0 then
    local res = M.compute()
    local keys = {}
    for k in pairs(res.status) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        print(string.format("%-22s %-5s %s", k, res.status[k], res.evidence[k]))
    end
end

return M
