local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local classes = {
    hunter = { "beast_mastery", "marksmanship", "survival" },
    mage = { "arcane", "fire", "frost" },
    paladin = { "holy", "protection", "retribution" },
    priest = { "discipline", "holy", "shadow" },
    rogue = { "assassination", "combat", "subtlety" },
    shaman = { "elemental", "enhancement", "restoration" },
    warlock = { "affliction", "demonology", "destruction" },
}

local forbidden = {
    hunter = { "SteadyShot", "KillCommand", "AspectOfTheViper", "Misdirection", "SilencingShot" },
    mage = { "ArcaneBlast", "DragonsBreath", "IceLance", "MoltenArmor", "WaterElemental", "Spellsteal" },
    paladin = { "AvengingWrath", "CrusaderStrike", "RighteousDefense" },
    priest = { "BindingHeal", "Shadowfiend", "ShadowWordDeath", "VampiricTouch", "MassDispel", "PrayerOfMending", "CircleOfHealing", "PainSuppression" },
    rogue = { "CloakOfShadows", "DeadlyThrow", "Envenom", "Mutilate", "Shadowstep", "Shiv" },
    shaman = { "Bloodlust", "EarthShield", "ShamanisticRage", "TotemOfWrath", "WaterShield" },
    warlock = { "Incinerate", "SeedOfCorruption", "Soulshatter", "UnstableAffliction" },
}

local global_forbidden = { "Bloodlust", "Heroism", "ClassicRemoved" }

local orig_require = require
function require(path)
    for class, specs in pairs(classes) do
        for _, spec in ipairs(specs) do
            if path == "classes/" .. class .. "/" .. spec .. "_sylvanas" then return "TBC_" .. class .. "_" .. spec end
            if path == "classes/" .. class .. "/" .. spec .. "_vanilla" then return "VANILLA_" .. class .. "_" .. spec end
        end
    end
    if path:match("^shared/class_loader_sylvanas") then return orig_require(path) end
    if path == "core_sylvanas" then return orig_require(path) end
    return orig_require(path)
end

_G.core = { time = function() return 0 end, log = function() end, get_game_version = function() return "Tbc" end }
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
local core_mod = require("core_sylvanas")
assert_true(core_mod.is_tbc(), "Should be TBC")
local loader = require("shared/class_loader_sylvanas")
for class, specs in pairs(classes) do
    local load_tbc = loader.create_expansion_loader(class, class)
    for _, spec in ipairs(specs) do
        assert_eq(load_tbc(spec, true), "TBC_" .. class .. "_" .. spec, "TBC " .. class .. " " .. spec .. " should load _sylvanas")
    end
end

_G.core.get_game_version = function() return "Vanilla" end
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
core_mod = require("core_sylvanas")
assert_true(core_mod.is_vanilla(), "Should be Vanilla")
loader = require("shared/class_loader_sylvanas")
for class, specs in pairs(classes) do
    local load_vanilla = loader.create_expansion_loader(class, class)
    for _, spec in ipairs(specs) do
        assert_eq(load_vanilla(spec, true), "VANILLA_" .. class .. "_" .. spec, "Vanilla " .. class .. " " .. spec .. " should load _vanilla")
    end
end

require = orig_require

for class, specs in pairs(classes) do
    for _, spec in ipairs(specs) do
        local path = "EaxRotations/classes/" .. class .. "/" .. spec .. "_vanilla.lua"
        local fh = assert(io.open(path, "r"), "Missing Classic spec file: " .. path)
        local body = fh:read("*a")
        fh:close()
        for _, token in ipairs(forbidden[class]) do
            assert_true(not body:find(token, 1, true), path .. " should not reference TBC-only token " .. token)
        end
        for _, token in ipairs(global_forbidden) do
            assert_true(not body:find(token, 1, true), path .. " should not reference non-Classic global token " .. token)
        end
    end
end

print("PASS classic_remaining_specs")
