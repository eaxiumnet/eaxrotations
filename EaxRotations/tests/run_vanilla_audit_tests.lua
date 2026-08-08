-- run_vanilla_audit_tests.lua -- Audit vanilla spec + leveling files for TBC spell contamination.
-- WHAT:  Scans vanilla spec and leveling files for TBC spell IDs that leaked into Classic.
-- WHEN:  Run manually or in CI before releases.
-- WHY:   Catches copy-paste contamination where TBC ranks leak into Classic (incl. leveling
--        copies that carry TBC-era ladder tops, e.g. 25290/25291/25295/25296/25315/27150).
-- SAFETY: Read-only text scan. No dofile(), no mock setup.
-- MODES:
--   (default)  full 40-file audit; exits 1 on any TBC contamination
--   --self-test      asserts the 99 pinned TBC IDs fire + threshold/allowlist/inventory
--   --probe-stale-top proves a TBC-era ladder top in a vanilla table is rejected (exit 1)

local TBC_IDS = {
    [469] = "Commanding Shout (TBC)",
    [974] = "Earth Shield (TBC talent)",
    [1329] = "Mutilate (TBC talent)",
    [2825] = "Bloodlust (TBC)",
    [3738] = "Wrath of Air Totem (TBC)",
    [5938] = "Shiv (TBC)",
    [12472] = "Icy Veins (TBC talent)",
    [20243] = "Devastate (TBC talent)",
    [22570] = "Maim (TBC)",
    [23920] = "Spell Reflection (TBC)",
    [23575] = "Water Shield (TBC)",
    [24398] = "Water Shield (TBC)",
    [25046] = "Arcane Torrent (TBC racial)",
    [26679] = "Deadly Throw (TBC)",
    [25273] = "Intercept Stun (TBC; no Classic ID)",
    [25274] = "Intercept Stun (TBC; no Classic ID)",
    [25286] = "Heroic Strike rank 9 (TBC; Classic max = 11567)",
    [25289] = "Battle Shout rank 7 (TBC; Classic max = 11551)",
    [25290] = "Blessing of Wisdom rank 5 (TBC; Classic max = 19854)",
    [25291] = "Blessing of Might rank 7 (TBC; Classic max = 19838)",
    [25292] = "Holy Light rank 9 (TBC; Classic max = 10329)",
    [25295] = "Serpent Sting rank 9 (TBC; Classic max = 13555)",
    [25296] = "Aspect of the Hawk rank 7 (TBC; Classic max = 14322)",
    [25297] = "Healing Touch rank 11 (TBC; Classic max = 9889)",
    [25298] = "Starfire rank 8 (TBC; Classic max = 9876)",
    [25299] = "Rejuvenation rank 11 (TBC; Classic max = 9841)",
    [25302] = "Feint rank 5 (TBC; Classic max = 11303)",
    [25309] = "Immolate rank 7 (TBC; Classic max = 11668)",
    [25311] = "Corruption rank 6 (TBC; Classic max = 11672)",
    [25312] = "Divine Spirit rank 5 (TBC; Classic max = 14819)",
    [25314] = "Greater Heal rank 4 (TBC; Classic max = 10965)",
    [25315] = "Renew rank 10 (TBC; Classic max = 10929)",
    [25347] = "Deadly Poison rank 6 (TBC; Classic max = 11356)",
    [25349] = "Deadly Poison rank 7 (TBC; Classic max = 11356)",
    [25389] = "Power Word: Fortitude rank 7 (TBC; Classic max = 10938)",
    [25429] = "Holy Nova rank 7 (TBC)",
    [25431] = "Inner Fire rank 7 (TBC)",
    [25446] = "Arcane Explosion rank 8 (TBC)",
    [25448] = "Lightning Bolt rank 11 (TBC)",
    [25457] = "Flame Shock rank 6 (TBC)",
    [25467] = "Devouring Plague rank 7 (TBC)",
    [25469] = "Lightning Shield rank 8 (TBC)",
    [25472] = "Lightning Shield rank 9 (TBC)",
    [25479] = "Rockbiter Weapon rank 9 (TBC)",
    [25485] = "Healing Wave rank 11 (TBC)",
    [25489] = "Flametongue Weapon rank 7 (TBC)",
    [25500] = "Frostbrand Weapon rank 6 (TBC)",
    [25505] = "Windfury Weapon rank 5 (TBC)",
    [25508] = "Stoneskin Totem rank 7 (TBC)",
    [25509] = "Stoneskin Totem rank 8 (TBC)",
    [25525] = "Stoneclaw Totem rank 7 (TBC)",
    [25528] = "Strength of Earth Totem rank 5 (TBC)",
    [25533] = "Searing Totem rank 7 (TBC)",
    [25546] = "Fire Nova Totem rank 6 (TBC)",
    [25547] = "Fire Nova Totem rank 7 (TBC)",
    [25552] = "Magma Totem rank 5 (TBC)",
    [25560] = "Frost Shock rank 5 (TBC)",
    [25563] = "Fire Resistance Totem rank 4 (TBC)",
    [25570] = "Mana Spring Totem rank 5 (TBC)",
    [25574] = "Nature Resistance Totem rank 4 (TBC)",
    [26967] = "Rejuvenation rank 13 (TBC)",
    [26968] = "Regrowth rank 10 (TBC)",
    [26980] = "Maul rank 8 (TBC)",
    [26981] = "Healing Touch rank 12 (TBC)",
    [26982] = "Healing Touch rank 13 (TBC)",
    [26983] = "Tranquility rank 5 (TBC)",
    [26987] = "Starfire rank 8 (TBC)",
    [26988] = "Moonfire rank 10 (TBC)",
    [26989] = "Entangling Roots rank 7 (TBC)",
    [26990] = "Mark of the Wild rank 7 (TBC)",
    [26991] = "Gift of the Wild rank 3 (TBC)",
    [26992] = "Thorns rank 7 (TBC)",
    [26993] = "Faerie Fire rank 5 (TBC)",
    [26994] = "Rebirth rank 5 (TBC)",
    [26998] = "Demoralizing Roar rank 6 (TBC)",
    [27016] = "Serpent Sting rank 10 (TBC)",
    [27018] = "Viper Sting rank 4 (TBC)",
    [27044] = "Aspect of the Hawk rank 8 (TBC)",
    [27068] = "Wyvern Sting rank 4 (TBC)",
    [27126] = "Arcane Intellect rank 6 (TBC)",
    [27127] = "Arcane Brilliance rank 2 (TBC)",
    [27131] = "Mana Shield rank 7 (TBC; Classic max = 10223)",
    [25782] = "Blessing of Might rank 8 (TBC; Classic max = 19838)",
    [25890] = "Greater Blessing of Light rank 4 (TBC; Classic max = 19979)",
    [25894] = "Greater Blessing of Wisdom rank 1 (TBC)",
    [25898] = "Greater Blessing of Kings rank 1 (TBC)",
    [25918] = "Greater Blessing of Wisdom rank 2 (TBC)",
    [27150] = "Retribution Aura rank 6 (TBC; Classic max = 10301)",
    [27136] = "Holy Light rank 11 (TBC)",
    [27137] = "Holy Light rank 12 (TBC)",
    [27138] = "Holy Light rank 13 (TBC)",
    [27139] = "Holy Light rank 14 (TBC)",
    [27173] = "Consecration rank 6 (TBC)",
    [27179] = "Holy Shield rank 4 (TBC)",
    [28176] = "Fel Armor rank 1 (TBC)",
    [28189] = "Fel Armor rank 2 (TBC)",
    [28880] = "Gift of the Naaru (TBC racial)",
    [30146] = "Summon Felguard (TBC talent)",
    [30455] = "Ice Lance (TBC)",
    [30823] = "Shamanistic Rage (TBC talent)",
    [31016] = "Eviscerate rank 12 (TBC; Classic max = 26865)",
    [31589] = "Slow (TBC talent)",
    [32182] = "Heroism (TBC)",
    [32593] = "Earth Shield rank 1 (TBC)",
    [32594] = "Earth Shield rank 2 (TBC)",
    [33206] = "Pain Suppression (TBC talent)",
    [33736] = "Water Shield rank 3 (TBC)",
    [33763] = "Lifebloom (TBC)",
    [33786] = "Cyclone (TBC)",
    [33831] = "Force of Nature (TBC talent)",
    [33876] = "Mangle Cat rank 1 (TBC talent)",
    [33878] = "Mangle Bear rank 1 (TBC talent)",
    [33891] = "Tree of Life Form (TBC talent)",
    [34026] = "Kill Command (TBC)",
    [34074] = "Aspect of the Viper (TBC)",
    [34120] = "Steady Shot (TBC)",
    [34477] = "Misdirection (TBC)",
    [34914] = "Vampiric Touch rank 1 (TBC talent)",
    [34916] = "Vampiric Touch rank 2 (TBC)",
    [34917] = "Vampiric Touch rank 3 (TBC)",
    [35395] = "Crusader Strike (TBC talent)",
    [36554] = "Shadowstep (TBC talent)",
    [36936] = "Totemic Call (TBC)",

    -- Sub-27000 TBC-era ladder ranks (2026-08-08 cross-check): each appears in a
    -- TBC class ladder with a bridge learn level > 60, which is impossible in
    -- Classic (max 60); verified none appear in any live vanilla file. These are
    -- below the 27000 threshold rule, so without this block they were invisible.
    [2048] = "Battle Shout (TBC; lvl 69)",
    [3411] = "Intervene (TBC; lvl 70)",
    [24248] = "Ferocious Bite (TBC; lvl 63)",
    [25202] = "Demoralizing Shout (TBC; lvl 62)",
    [25203] = "Demoralizing Shout (TBC; lvl 70)",
    [25208] = "Rend (TBC; lvl 68)",
    [25210] = "Greater Heal (TBC; lvl 63)",
    [25212] = "Hamstring (TBC; lvl 67)",
    [25213] = "Greater Heal (TBC; lvl 68)",
    [25217] = "Power Word: Shield (TBC; lvl 65)",
    [25218] = "Power Word: Shield (TBC; lvl 70)",
    [25221] = "Renew (TBC; lvl 65)",
    [25222] = "Renew (TBC; lvl 70)",
    [25225] = "Sunder Armor (TBC; lvl 67)",
    [25231] = "Cleave (TBC; lvl 68)",
    [25233] = "Flash Heal (TBC; lvl 61)",
    [25234] = "Execute (TBC; lvl 65)",
    [25235] = "Flash Heal (TBC; lvl 67)",
    [25236] = "Execute (TBC; lvl 70)",
    [25241] = "Slam (TBC; lvl 61)",
    [25242] = "Slam (TBC; lvl 69)",
    [25248] = "Mortal Strike (TBC; lvl 66)",
    [25251] = "Bloodthirst (TBC; lvl 66)",
    [25258] = "Shield Slam (TBC; lvl 66)",
    [25264] = "Thunder Clap (TBC; lvl 67)",
    [25269] = "Revenge (TBC; lvl 63)",
    [25275] = "Intercept (TBC; lvl 69)",
    [25308] = "Prayer of Healing (TBC; lvl 68)",
    [25329] = "Holy Nova (TBC; lvl 68)",
    [25331] = "Holy Nova (TBC; lvl 68)",
    [25363] = "Smite (TBC; lvl 61)",
    [25364] = "Smite (TBC; lvl 69)",
    [25367] = "Shadow Word: Pain (TBC; lvl 65)",
    [25368] = "Shadow Word: Pain (TBC; lvl 70)",
    [25372] = "Mind Blast (TBC; lvl 63)",
    [25375] = "Mind Blast (TBC; lvl 69)",
    [25379] = "Mana Burn (TBC; lvl 63)",
    [25380] = "Mana Burn (TBC; lvl 70)",
    [25384] = "Holy Fire (TBC; lvl 66)",
    [25387] = "Mind Flay (TBC; lvl 68)",
    [25391] = "Healing Wave (TBC; lvl 63)",
    [25392] = "Prayer of Fortitude (TBC; lvl 70)",
    [25396] = "Healing Wave (TBC; lvl 70)",
    [25420] = "Lesser Healing Wave (TBC; lvl 66)",
    [25422] = "Chain Heal (TBC; lvl 61)",
    [25423] = "Chain Heal (TBC; lvl 68)",
    [25437] = "Desperate Prayer (TBC; lvl 66)",
    [25439] = "Chain Lightning (TBC; lvl 63)",
    [25442] = "Chain Lightning (TBC; lvl 70)",
    [25449] = "Lightning Bolt (TBC; lvl 67)",
    [25454] = "Earth Shock (TBC; lvl 69)",
    [25464] = "Frost Shock (TBC; lvl 68)",
    [25567] = "Healing Stream Totem (TBC; lvl 69)",
    [25585] = "Windfury Totem (TBC; lvl 61)",
    [25587] = "Windfury Totem (TBC; lvl 70)",
    [26839] = "Garrote (TBC; lvl 61)",
    [26861] = "Sinister Strike (TBC; lvl 62)",
    [26862] = "Sinister Strike (TBC; lvl 70)",
    [26863] = "Backstab (TBC; lvl 68)",
    [26864] = "Hemorrhage (TBC; lvl 70)",
    [26865] = "Eviscerate (TBC; lvl 64)",
    [26866] = "Expose Armor (TBC; lvl 66)",
    [26867] = "Rupture (TBC; lvl 68)",
    [26884] = "Garrote (TBC; lvl 70)",
    [26889] = "Vanish (TBC; lvl 62)",
    [26978] = "Healing Touch (TBC; lvl 62)",
    [26979] = "Healing Touch (TBC; lvl 69)",
    [26984] = "Wrath (TBC; lvl 61)",
    [26985] = "Wrath (TBC; lvl 69)",
    [26986] = "Starfire (TBC; lvl 67)",
    [26996] = "Maul (TBC; lvl 67)",
    [26997] = "Swipe (TBC; lvl 64)",
    [26999] = "Frenzied Regeneration (TBC; lvl 65)",
}

local VANILLA_SPECS = {
    "classes/druid/balance_vanilla.lua",
    "classes/druid/bear_vanilla.lua",
    "classes/druid/cat_vanilla.lua",
    "classes/druid/caster_vanilla.lua",
    "classes/druid/resto_vanilla.lua",
    "classes/hunter/beast_mastery_vanilla.lua",
    "classes/hunter/marksmanship_vanilla.lua",
    "classes/hunter/survival_vanilla.lua",
    "classes/mage/arcane_vanilla.lua",
    "classes/mage/fire_vanilla.lua",
    "classes/mage/frost_vanilla.lua",
    "classes/paladin/holy_vanilla.lua",
    "classes/paladin/protection_vanilla.lua",
    "classes/paladin/retribution_vanilla.lua",
    "classes/priest/discipline_vanilla.lua",
    "classes/priest/holy_vanilla.lua",
    "classes/priest/shadow_vanilla.lua",
    "classes/priest/smite_vanilla.lua",
    "classes/rogue/assassination_vanilla.lua",
    "classes/rogue/combat_vanilla.lua",
    "classes/rogue/subtlety_vanilla.lua",
    "classes/shaman/elemental_vanilla.lua",
    "classes/shaman/enhancement_vanilla.lua",
    "classes/shaman/restoration_vanilla.lua",
    "classes/warlock/affliction_vanilla.lua",
    "classes/warlock/demonology_vanilla.lua",
    "classes/warlock/destruction_vanilla.lua",
    "classes/warrior/arms_vanilla.lua",
    "classes/warrior/fury_vanilla.lua",
    "classes/warrior/kebab_vanilla.lua",
    "classes/warrior/protection_vanilla.lua",

    -- leveling copies (can carry TBC-era ladder tops not present in the spec files)
    "classes/druid/leveling_vanilla.lua",
    "classes/hunter/leveling_vanilla.lua",
    "classes/mage/leveling_vanilla.lua",
    "classes/paladin/leveling_vanilla.lua",
    "classes/priest/leveling_vanilla.lua",
    "classes/rogue/leveling_vanilla.lua",
    "classes/shaman/leveling_vanilla.lua",
    "classes/warlock/leveling_vanilla.lua",
    "classes/warrior/leveling_vanilla.lua",
}

local TBC_THRESHOLD = 27000

local THRESHOLD_ALLOWLIST = {
    [27799] = true, [27800] = true, [27801] = true,
    [27803] = true, [27804] = true, [27805] = true,
    [27819] = true,
    [28271] = true, [28272] = true,
    [28610] = true,
    [29166] = true,
}

-- The 26 TBC-era ranks added during the 2026-08-08 vanilla leveling+spec rank
-- sweep (each is a TBC rank above the vanilla max for its family; the audit
-- must keep flagging them). --self-test asserts every one of these fires, so a
-- future TBC_IDS edit can't silently drop enforcement.
local NEW_TBC_IDS_26 = {
    { id = 25273, desc = "Intercept Stun (TBC)" },
    { id = 25274, desc = "Intercept Stun (TBC)" },
    { id = 25286, desc = "Heroic Strike rank 9 (TBC)" },
    { id = 25290, desc = "Blessing of Wisdom rank 5 (TBC)" },
    { id = 25291, desc = "Blessing of Might rank 7 (TBC)" },
    { id = 25292, desc = "Holy Light rank 9 (TBC)" },
    { id = 25295, desc = "Serpent Sting rank 9 (TBC)" },
    { id = 25296, desc = "Aspect of the Hawk rank 7 (TBC)" },
    { id = 25297, desc = "Healing Touch rank 11 (TBC)" },
    { id = 25298, desc = "Starfire rank 8 (TBC)" },
    { id = 25299, desc = "Rejuvenation rank 11 (TBC)" },
    { id = 25302, desc = "Feint rank 5 (TBC)" },
    { id = 25309, desc = "Immolate rank 7 (TBC)" },
    { id = 25311, desc = "Corruption rank 6 (TBC)" },
    { id = 25312, desc = "Divine Spirit rank 5 (TBC)" },
    { id = 25314, desc = "Greater Heal rank 4 (TBC)" },
    { id = 25315, desc = "Renew rank 10 (TBC)" },
    { id = 25347, desc = "Deadly Poison rank 6 (TBC)" },
    { id = 25349, desc = "Deadly Poison rank 7 (TBC)" },
    { id = 25389, desc = "Power Word: Fortitude rank 7 (TBC)" },
    { id = 25782, desc = "Blessing of Might rank 8 (TBC)" },
    { id = 25890, desc = "Greater Blessing of Light rank 4 (TBC)" },
    { id = 25894, desc = "Greater Blessing of Wisdom rank 1 (TBC)" },
    { id = 25898, desc = "Greater Blessing of Kings rank 1 (TBC)" },
    { id = 25918, desc = "Greater Blessing of Wisdom rank 2 (TBC)" },
    { id = 27150, desc = "Retribution Aura rank 6 (TBC)" },
}

-- The 73 sub-27000 TBC-era ladder ranks added during the 2026-08-08 bridge
-- level-column cross-check. Each has a bridge learn level > 60 (impossible in
-- Classic, max level 60) and appears in a TBC class ladder. The threshold rule
-- only fires >= 27000, so these need explicit pins. --self-test asserts every
-- one fires, mirroring NEW_TBC_IDS_26.
local NEW_TBC_IDS_73 = {
    { id = 2048, desc = "Battle Shout (lvl 69)" },
    { id = 3411, desc = "Intervene (lvl 70)" },
    { id = 24248, desc = "Ferocious Bite (lvl 63)" },
    { id = 25202, desc = "Demoralizing Shout (lvl 62)" },
    { id = 25203, desc = "Demoralizing Shout (lvl 70)" },
    { id = 25208, desc = "Rend (lvl 68)" },
    { id = 25210, desc = "Greater Heal (lvl 63)" },
    { id = 25212, desc = "Hamstring (lvl 67)" },
    { id = 25213, desc = "Greater Heal (lvl 68)" },
    { id = 25217, desc = "Power Word: Shield (lvl 65)" },
    { id = 25218, desc = "Power Word: Shield (lvl 70)" },
    { id = 25221, desc = "Renew (lvl 65)" },
    { id = 25222, desc = "Renew (lvl 70)" },
    { id = 25225, desc = "Sunder Armor (lvl 67)" },
    { id = 25231, desc = "Cleave (lvl 68)" },
    { id = 25233, desc = "Flash Heal (lvl 61)" },
    { id = 25234, desc = "Execute (lvl 65)" },
    { id = 25235, desc = "Flash Heal (lvl 67)" },
    { id = 25236, desc = "Execute (lvl 70)" },
    { id = 25241, desc = "Slam (lvl 61)" },
    { id = 25242, desc = "Slam (lvl 69)" },
    { id = 25248, desc = "Mortal Strike (lvl 66)" },
    { id = 25251, desc = "Bloodthirst (lvl 66)" },
    { id = 25258, desc = "Shield Slam (lvl 66)" },
    { id = 25264, desc = "Thunder Clap (lvl 67)" },
    { id = 25269, desc = "Revenge (lvl 63)" },
    { id = 25275, desc = "Intercept (lvl 69)" },
    { id = 25308, desc = "Prayer of Healing (lvl 68)" },
    { id = 25329, desc = "Holy Nova (lvl 68)" },
    { id = 25331, desc = "Holy Nova (lvl 68)" },
    { id = 25363, desc = "Smite (lvl 61)" },
    { id = 25364, desc = "Smite (lvl 69)" },
    { id = 25367, desc = "Shadow Word: Pain (lvl 65)" },
    { id = 25368, desc = "Shadow Word: Pain (lvl 70)" },
    { id = 25372, desc = "Mind Blast (lvl 63)" },
    { id = 25375, desc = "Mind Blast (lvl 69)" },
    { id = 25379, desc = "Mana Burn (lvl 63)" },
    { id = 25380, desc = "Mana Burn (lvl 70)" },
    { id = 25384, desc = "Holy Fire (lvl 66)" },
    { id = 25387, desc = "Mind Flay (lvl 68)" },
    { id = 25391, desc = "Healing Wave (lvl 63)" },
    { id = 25392, desc = "Prayer of Fortitude (lvl 70)" },
    { id = 25396, desc = "Healing Wave (lvl 70)" },
    { id = 25420, desc = "Lesser Healing Wave (lvl 66)" },
    { id = 25422, desc = "Chain Heal (lvl 61)" },
    { id = 25423, desc = "Chain Heal (lvl 68)" },
    { id = 25437, desc = "Desperate Prayer (lvl 66)" },
    { id = 25439, desc = "Chain Lightning (lvl 63)" },
    { id = 25442, desc = "Chain Lightning (lvl 70)" },
    { id = 25449, desc = "Lightning Bolt (lvl 67)" },
    { id = 25454, desc = "Earth Shock (lvl 69)" },
    { id = 25464, desc = "Frost Shock (lvl 68)" },
    { id = 25567, desc = "Healing Stream Totem (lvl 69)" },
    { id = 25585, desc = "Windfury Totem (lvl 61)" },
    { id = 25587, desc = "Windfury Totem (lvl 70)" },
    { id = 26839, desc = "Garrote (lvl 61)" },
    { id = 26861, desc = "Sinister Strike (lvl 62)" },
    { id = 26862, desc = "Sinister Strike (lvl 70)" },
    { id = 26863, desc = "Backstab (lvl 68)" },
    { id = 26864, desc = "Hemorrhage (lvl 70)" },
    { id = 26865, desc = "Eviscerate (lvl 64)" },
    { id = 26866, desc = "Expose Armor (lvl 66)" },
    { id = 26867, desc = "Rupture (lvl 68)" },
    { id = 26884, desc = "Garrote (lvl 70)" },
    { id = 26889, desc = "Vanish (lvl 62)" },
    { id = 26978, desc = "Healing Touch (lvl 62)" },
    { id = 26979, desc = "Healing Touch (lvl 69)" },
    { id = 26984, desc = "Wrath (lvl 61)" },
    { id = 26985, desc = "Wrath (lvl 69)" },
    { id = 26986, desc = "Starfire (lvl 67)" },
    { id = 26996, desc = "Maul (lvl 67)" },
    { id = 26997, desc = "Swipe (lvl 64)" },
    { id = 26999, desc = "Frenzied Regeneration (lvl 65)" },
}

local root = "EaxRotations"

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a") or ""
    f:close()
    return content
end

local function is_comment_line(line)
    return line:match("^%s*%-%-") ~= nil
end

local function add_hit(hits, line_no, line, num_str, num, desc)
    hits[#hits + 1] = {
        line = line_no,
        col = line:find(num_str, 1, true),
        id = num,
        desc = desc,
        snippet = line:match("^%s*(.-)%s*$") or line,
    }
end

local function scan_content(content)
    local hits = {}
    if type(content) ~= "string" then
        return { found = false, hits = {}, error = "content must be a string" }
    end

    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end

    for line_no, line in ipairs(lines) do
        if not is_comment_line(line) then
            for num_str in line:gmatch("(%d+)") do
                local num = tonumber(num_str)
                if TBC_IDS[num] then
                    add_hit(hits, line_no, line, num_str, num, TBC_IDS[num])
                elseif #num_str == 5 and num >= TBC_THRESHOLD and not THRESHOLD_ALLOWLIST[num] then
                    add_hit(hits, line_no, line, num_str, num, "unknown TBC-era ID >= " .. TBC_THRESHOLD)
                end
            end
        end
    end

    return { found = #hits > 0, hits = hits }
end

local function scan_file(filepath)
    local content = read_file(filepath)
    if not content then
        return { found = false, hits = {}, error = "could not read file" }
    end
    return scan_content(content)
end

-- ---------------------------------------------------------------------------
-- Self-tests + probes (mirror the WotLK audit's --self-test / --probe-stale-top)
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    -- Malformed / missing input is controlled, not fatal.
    expect(scan_content(nil).error, "content must be a string", "malformed content")
    expect(scan_file("__missing_vanilla_audit_fixture__.lua").error, "could not read file", "missing fixture")

    local function map_count(map)
        local n = 0
        for _ in pairs(map) do n = n + 1 end
        return n
    end

    -- Table integrity.
    expect(map_count(TBC_IDS), 196, "TBC_IDS size")
    expect(map_count(THRESHOLD_ALLOWLIST), 11, "allowlist size")
    expect(#NEW_TBC_IDS_26, 26, "new-sweep list size")
    expect(#NEW_TBC_IDS_73, 73, "sub-27000 cross-check list size")
    expect(#VANILLA_SPECS, 40, "vanilla inventory size")
    local seen = {}
    for _, f in ipairs(VANILLA_SPECS) do
        expect(seen[f], nil, "duplicate inventory entry: " .. tostring(f))
        seen[f] = true
    end

    -- The lists themselves must not contain duplicate IDs (a dup would silently
    -- mask a removal while keeping the size constant).
    local function assert_no_dups(list, label)
        local list_seen = {}
        for _, entry in ipairs(list) do
            expect(list_seen[entry.id], nil, "duplicate " .. label .. " entry: " .. tostring(entry.id))
            list_seen[entry.id] = true
        end
    end
    assert_no_dups(NEW_TBC_IDS_26, "NEW_TBC_IDS_26")
    assert_no_dups(NEW_TBC_IDS_73, "NEW_TBC_IDS_73")

    -- Every pinned TBC rank must fire as a named hit (26 sweep + 73 cross-check).
    local function assert_all_fire(list, label)
        local unfired = {}
        for _, entry in ipairs(list) do
            expect(TBC_IDS[entry.id] ~= nil, true, "TBC_IDS must contain " .. tostring(entry.id))
            local result = scan_content("local PROBE_BUFF = { " .. entry.id .. " }")
            local fired = false
            for _, hit in ipairs(result.hits or {}) do
                if hit.id == entry.id then fired = true end
            end
            if not fired then
                unfired[#unfired + 1] = string.format("%d (%s)", entry.id, entry.desc or "?")
            end
        end
        expect(#unfired, 0, "all " .. label .. " TBC IDs fire (missed: " .. table.concat(unfired, ", ") .. ")")
    end
    assert_all_fire(NEW_TBC_IDS_26, "26 sweep")
    assert_all_fire(NEW_TBC_IDS_73, "73 sub-27000 cross-check")

    -- The threshold path still catches an unknown TBC-era ID >= 27000 that is
    -- NOT in the allowlist (27123 is not a pinned entry and is not allowlisted).
    local thr = scan_content("local PROBE = { 27123 }")
    expect(thr.found, true, "unknown >=27000 ID fires via threshold")
    expect(thr.hits[1] and thr.hits[1].id, 27123, "threshold hit id")

    -- Allowlisted IDs must NOT fire (they are valid vanilla/NPC IDs).
    for id in pairs(THRESHOLD_ALLOWLIST) do
        local r = scan_content("local PROBE = { " .. id .. " }")
        expect(r.found, false, "allowlist ID must be silent: " .. tostring(id))
    end

    print("[PASS] Vanilla audit self-tests: malformed input, 99 pinned TBC IDs fire (26 sweep + 73 sub-27000), threshold path, allowlist silence, 40-file inventory")
end

local function run_stale_top_probe()
    -- A TBC-era ladder top (25296 Aspect of the Hawk rank 7) leaking into a
    -- vanilla leveling table must be rejected. Mirrors --probe-stale-top.
    local result = scan_content("local ASPECT_HAWK_BUFF = { 25296, 14322, 14321 }")
    local saw = false
    for _, hit in ipairs(result.hits or {}) do
        if hit.id == 25296 then saw = true end
    end
    if not saw then
        print("[ERROR] stale-top probe did not flag TBC ladder top 25296")
        os.exit(2)
    end
    print("[FAIL] stale-top probe rejected as expected: id 25296 (Aspect of the Hawk rank 7, TBC)")
    os.exit(1)
end

if arg and arg[1] == "--self-test" then
    run_self_tests()
    os.exit(0)
elseif arg and arg[1] == "--probe-stale-top" then
    run_stale_top_probe()
end

local total, passed, failed = 0, 0, 0
local failures = {}

for _, file in ipairs(VANILLA_SPECS) do
    local path = root .. "/" .. file
    total = total + 1

    local result = scan_file(path)
    if result.error then
        failed = failed + 1
        failures[#failures + 1] = { file = file, error = result.error, hits = {} }
        print(string.format("  [ ERROR ] %-45s %s", file, result.error))
    elseif result.found then
        failed = failed + 1
        failures[#failures + 1] = { file = file, hits = result.hits }
        print(string.format("  [ FAIL ]  %-45s %d TBC ID(s)", file, #result.hits))
        for _, hit in ipairs(result.hits) do
            print(string.format("            line %4d: id %d - %s", hit.line, hit.id, hit.desc))
        end
    else
        passed = passed + 1
        print(string.format("  [ PASS ]  %-45s clean", file))
    end
end

print("")
print("=============================================================================")
print("  VANILLA SPELL AUDIT RESULTS")
print("=============================================================================")
print(string.format("  Total:   %3d vanilla spec + leveling files", total))
print(string.format("  Clean:   %3d", passed))
print(string.format("  Tainted: %3d", failed))

if failed > 0 then
    print("")
    print("  TBC contaminant IDs found:")
    for _, f in ipairs(failures) do
        print("    " .. f.file)
        if f.error then
            print("      ERROR: " .. f.error)
        else
            for _, hit in ipairs(f.hits) do
                print(string.format("      line %d: id %d - %s", hit.line, hit.id, hit.desc))
            end
        end
    end
end

print("=============================================================================")

if failed > 0 then
    print("Vanilla spell audit FAILED: " .. tostring(failed) .. " spec/leveling file(s) have TBC contaminant spell IDs")
    os.exit(1)
end

print("All vanilla spec + leveling files clean - no TBC contamination.")
