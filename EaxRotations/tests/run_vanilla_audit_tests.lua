-- run_vanilla_audit_tests.lua -- Audit vanilla spec files for TBC spell contamination.
-- WHAT:  Scans vanilla spec files for TBC spell IDs that leaked into Classic.
-- WHEN:  Run manually or in CI before releases.
-- WHY:   Catches copy-paste contamination where TBC ranks leak into Classic.
-- SAFETY: Read-only text scan. No dofile(), no mock setup.

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
    [25289] = "Battle Shout rank 8 (TBC; Classic max = 2048)",
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

local function scan_file(filepath)
    local content = read_file(filepath)
    if not content then
        return { found = false, hits = {}, error = "could not read file" }
    end

    local hits = {}
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
print(string.format("  Total:   %3d vanilla spec files", total))
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
    print("Vanilla spell audit FAILED: " .. tostring(failed) .. " spec file(s) have TBC contaminant spell IDs")
    os.exit(1)
end

print("All vanilla spec files clean - no TBC contamination.")
