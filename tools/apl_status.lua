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
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;tools/?.lua;tools/build_tools/?.lua;" .. package.path

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

local function base_ns()
    return {
        GetPlayer = function() return {
            get_health_percentage = function() return 80 end,
            get_mana_percentage = function() return 80 end,
            get_energy = function() return 100 end,
            get_combo_points = function() return 5 end,
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
        rotation_registry = {
            register = function(self, name, strategies, options) end,
        },
    }
end

-- Load a spec file's strategy table under the mock NS. `spells` names the
-- action table to inject (e.g. "MageSpells"), `actions` maps strategy name ->
-- spell id (or id list).
function M.load_spec(spec_file, spells, actions)
    _G.EaxRotations = base_ns()
    local t = {}
    for name, ids in pairs(actions) do t[name] = make_action(ids, name) end
    _G.EaxRotations[spells] = t
    local mod = dofile(spec_file)
    if type(mod) ~= "table" or type(mod.strategies) ~= "table" then
        error(spec_file .. " should return { strategies = ... }")
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
        spec_file = "EaxRotations/classes/rogue/combat_sylvanas.lua",
        spells = "RogueSpells",
        actions = {
            SliceAndDice = 6774, Eviscerate = 26865, SinisterStrike = 26862,
        },
        reference_names = { "SliceAndDice", "Eviscerate", "SinisterStrike" },
    },
    {
        key = "tbc/elemental",
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
        spec_file = "EaxRotations/classes/mage/frost_sylvanas.lua",
        spells = "MageSpells",
        actions = {
            Frostbolt = 27072,
        },
        reference_names = { "Frostbolt" },
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
            local strategies = M.load_spec(e.spec_file, e.spells, e.actions)
            local names = M.strategy_names(strategies)
            local violation
            if e.reference_names then
                violation = apl.check_name_order(names, e.reference_names)
            else
                local raw = M.read_file(e.fixture)
                if not raw then error("missing fixture: " .. e.fixture) end
                local ids = apl.priority_ids(apl.decode_json(raw))
                if #ids == 0 then error("fixture has no priority ids: " .. e.fixture) end
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
