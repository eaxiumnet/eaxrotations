-- test_character_profiles.lua — per-character settings isolation and restoration.
-- WHAT: proves profiles are keyed by name/realm, restore every profile-backed widget, and keep safe defaults.
-- WHEN: run through the isolated EaxAutoQuester suite runner.
-- WHY: a global widget value makes one character's careful pulling and mount choice leak into the next.
-- SAFETY: uses only a local menu/core stub; no client calls, writes, or persistence claims.
-- DECISION: session-scoped storage is tested directly; the supported runtime has no file-write API.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local created = {}
local _tree_body
local log_lines = {}
local profession_slots = {}
local profession_info = {}
local profession_calls = { slots = 0, info = 0 }

local function find_log(fragment)
    for i = 1, #log_lines do
        if string.find(log_lines[i], fragment, 1, true) then return log_lines[i] end
    end
    return nil
end

local function count_log(fragment)
    local n = 0
    for i = 1, #log_lines do
        if string.find(log_lines[i], fragment, 1, true) then n = n + 1 end
    end
    return n
end

local function checkbox(default, id)
    local w = { _state = default, _id = id }
    function w:get_state() return w._state end
    function w:set(value) w._state = value end
    function w:render() end
    created[#created + 1] = { kind = "checkbox", id = id, default = default }
    return w
end

local function slider(min, max, default, id)
    local w = { _value = default, _id = id, _min = min, _max = max }
    function w:get() return w._value end
    function w:set(value) w._value = value end
    function w:render() end
    created[#created + 1] = { kind = "slider", id = id, default = default, min = min, max = max }
    return w
end

core = {
    log = function(msg) log_lines[#log_lines + 1] = tostring(msg) end,
    menu = {
        tree_node = function()
            return { render = function(_, _, body) _tree_body = body end }
        end,
        checkbox = checkbox,
        slider_int = slider,
        button = function(id)
            return { render = function() end, is_clicked = function() return false end, _id = id }
        end,
        keybind = function()
            return { render = function() end }
        end,
    },
    spell_book = {
        get_professions = function()
            profession_calls.slots = profession_calls.slots + 1
            return profession_slots
        end,
        get_profession_info = function(index)
            profession_calls.info = profession_calls.info + 1
            return profession_info[index]
        end,
    },
}

_G.EaxAutoQuester = {}

package.loaded["menu_sylvanas"] = nil
package.loaded["character_profile_sylvanas"] = nil
local menu = require("menu_sylvanas")
local profile = require("character_profile_sylvanas")

local function character(name, realm)
    return {
        get_name = function() return name end,
        get_realm_name = function() return realm end,
    }
end

-- P1: a first character receives the established safe defaults.
local alice = character("Alice", "Ravencrest")
assert(profile.activate_for(alice, menu) == true, "P1a FAIL: first character was not activated")
assert(profile.active_key() == "alice@ravencrest", "P1b FAIL: profile key is not name/realm")
assert(profile.profile_count() == 1, "P1c FAIL: first character did not create exactly one profile")
assert(menu.get("profile_vendor_bag_threshold") == 80, "P1d FAIL: vendor default changed")
assert(menu.get("profile_mount_use") == true, "P1e FAIL: mount default changed")
assert(menu.get("pull_gate_min_hp") == 50 and menu.get("pull_gate_min_mana") == 30,
    "P1f FAIL: pull defaults changed")
assert(profile.gathering_enabled("herbalism") == false,
    "P1g FAIL: an unselected gathering profession must remain off")
assert(profession_calls.slots == 1 and profession_calls.info == 0,
    "P1h FAIL: a character with no learned profession slots must not query profession detail")
assert(profile.gather_min_free_slots() == 4,
    "P1i FAIL: the gathering free-slot reserve must default to the loot gate's 4")
local alice_line = find_log("[Alice - Ravencrest]")
assert(alice_line, "P1i FAIL: no startup profession diagnostic was logged for the first character")
assert(string.find(alice_line, "none reported", 1, true),
    "P1j FAIL: the diagnostic did not say that no professions were reported: " .. alice_line)

-- P2: edits are captured and restored only for Alice.
menu.profile_gather_herbalism:set(true)
menu.profile_gather_mining:set(true)
menu.profile_vendor_bag_threshold:set(65)
menu.profile_mount_use:set(false)
menu.pull_gate:set(false)
menu.pull_gate_min_hp:set(72)
menu.pull_gate_min_mana:set(18)
menu.profile_gather_min_free_slots:set(9)
assert(profile.activate_for(alice, menu) == false, "P2a FAIL: same character should not be reactivated")
assert(profile.vendor_threshold() == 65, "P2b FAIL: vendor edit was not captured")
assert(profile.mount_use_enabled() == false, "P2c FAIL: mount edit was not captured")
assert(profile.gathering_enabled("herbalism") and profile.gathering_enabled("mining"),
    "P2d FAIL: gathering edits were not captured")
assert(profile.gathering_enabled("fishing") == false,
    "P2e FAIL: an unselected profession was enabled")
assert(profile.gather_min_free_slots() == 9,
    "P2f FAIL: the reserve edit was not captured")

-- P3: switching to Bob restores defaults; switching back restores Alice's values.
local bob = character("Bob", "Ravencrest")
assert(profile.activate_for(bob, menu) == true, "P3a FAIL: second character was not activated")
assert(profile.profile_count() == 2, "P3b FAIL: second character did not get its own profile")
assert(menu.get("profile_vendor_bag_threshold") == 80, "P3c FAIL: Bob inherited Alice's vendor threshold")
assert(menu.get("profile_mount_use") == true, "P3d FAIL: Bob inherited Alice's mount choice")
assert(menu.get("pull_gate") == true and menu.get("pull_gate_min_hp") == 50,
    "P3e FAIL: Bob inherited Alice's pull policy")
assert(profile.gathering_enabled("herbalism") == false,
    "P3f FAIL: Bob inherited Alice's gathering preferences")
assert(profile.gather_min_free_slots() == 4,
    "P3g FAIL: Bob inherited Alice's free-slot reserve")

assert(profile.activate_for(alice, menu) == true, "P3g FAIL: Alice was not reactivated")
assert(menu.get("profile_vendor_bag_threshold") == 65, "P3h FAIL: Alice's vendor threshold was not restored")
assert(menu.get("profile_mount_use") == false, "P3i FAIL: Alice's mount choice was not restored")
assert(menu.get("pull_gate_min_hp") == 72 and menu.get("pull_gate_min_mana") == 18,
    "P3j FAIL: Alice's pull policy was not restored")
assert(profile.gathering_enabled("herbalism") and profile.gathering_enabled("mining"),
    "P3k FAIL: Alice's gathering preferences were not restored")
assert(profile.gather_min_free_slots() == 9,
    "P3l FAIL: Alice's free-slot reserve was not restored")

-- P4: same name on another realm is a different character profile.
local alice_alt = character("Alice", "Bloodfang")
assert(profile.activate_for(alice_alt, menu) == true, "P4a FAIL: realm-qualified character was not activated")
assert(profile.profile_count() == 3, "P4b FAIL: realm was not part of the profile key")
assert(menu.get("profile_vendor_bag_threshold") == 80, "P4c FAIL: alternate realm inherited Alice's values")

-- P6: a new profile seeds only supported gathering professions from the documented client surface.
profession_slots.prof1 = 201
profession_slots.prof2 = 202
profession_slots.fishing = 203
profession_info[201] = { name = "Herbalism", skill_line_name = "Herbalism", skill_level = 300 }
profession_info[202] = { name = "Alchemy", skill_line_name = "Alchemy", skill_level = 300 }
profession_info[203] = { name = "Fishing", skill_line_name = "Fishing", skill_level = 300 }
local slots_before = profession_calls.slots
local info_before = profession_calls.info
local cara = character("Cara", "Ravencrest")
assert(profile.activate_for(cara, menu) == true, "P6a FAIL: detected character was not activated")
assert(profession_calls.slots == slots_before + 1 and profession_calls.info == info_before + 3,
    "P6b FAIL: profession discovery did not read the two primary slots and Fishing exactly once")
assert(profile.gathering_enabled("herbalism") and profile.gathering_enabled("fishing"),
    "P6c FAIL: learned supported professions were not enabled")
assert(profile.gathering_enabled("mining") == false and profile.gathering_enabled("skinning") == false,
    "P6d FAIL: an unlearned supported profession was enabled")
assert(menu.get("profile_gather_herbalism") == true and menu.get("profile_gather_fishing") == true,
    "P6e FAIL: detected values were not reflected in the real menu")
assert(menu.get("profile_gather_mining") == false and menu.get("profile_gather_skinning") == false,
    "P6f FAIL: a non-gathering profession changed an unrelated route")
local cara_line = find_log("[Cara - Ravencrest]")
assert(cara_line, "P6g FAIL: no startup profession diagnostic was logged for the detected character")
assert(string.find(cara_line, "prof1=Herbalism (300)", 1, true)
    and string.find(cara_line, "prof2=Alchemy (300)", 1, true)
    and string.find(cara_line, "fishing=Fishing (300)", 1, true),
    "P6h FAIL: the diagnostic did not report every slot with its skill level: " .. tostring(cara_line))
assert(string.find(cara_line, "gathering: Herbalism, Fishing", 1, true),
    "P6i FAIL: the diagnostic did not report which professions unlocked gathering: " .. tostring(cara_line))

-- P7: the checkbox is a real manual override, and re-activation does not re-run discovery or the
-- startup diagnostic.
local slots_after_detect = profession_calls.slots
local cara_logs_before = count_log("[Cara - Ravencrest]")
menu.profile_gather_herbalism:set(false)
assert(profile.activate_for(cara, menu) == false, "P7a FAIL: same character should not be reactivated")
assert(profile.gathering_enabled("herbalism") == false,
    "P7b FAIL: an explicit opt-out did not beat the detected default")
assert(profession_calls.slots == slots_after_detect,
    "P7c FAIL: profession discovery repeated instead of staying one-shot per profile")
assert(count_log("[Cara - Ravencrest]") == cara_logs_before,
    "P7d FAIL: the startup diagnostic repeated on re-activation")

-- P8: a non-English client is detected by its verified skill-line id, not by its localized name.
-- Skill-line ids are the 2.5.5 client's own (DBC SkillLineAbility): 182 Herbalism, 186 Mining,
-- 356 Fishing, 393 Skinning. The name here is deliberately not English and not a supported word.
profession_slots.prof1, profession_slots.prof2, profession_slots.fishing = 301, nil, nil
profession_info[301] = { name = "Kraeuterkunde", skill_line_name = "Kraeuterkunde",
    skill_line = 182, skill_level = 300 }
local dana = character("Dana", "Ravencrest")
assert(profile.activate_for(dana, menu) == true, "P8a FAIL: localized character was not activated")
assert(profile.gathering_enabled("herbalism"),
    "P8b FAIL: a verified skill-line id did not enable gathering on a non-English client")
local dana_line = find_log("[Dana - Ravencrest]")
assert(dana_line and string.find(dana_line, "[skill 182]", 1, true),
    "P8c FAIL: the diagnostic did not report the skill line it matched on: " .. tostring(dana_line))
assert(dana_line and string.find(dana_line, "gathering: Herbalism", 1, true),
    "P8d FAIL: the gathering tail did not name the canonical profession: " .. tostring(dana_line))

-- P9: a real non-gathering profession (Alchemy, skill line 171) is never mistaken for a gathering
-- route, whatever language the client is in.
profession_slots.prof1, profession_slots.prof2, profession_slots.fishing = 302, nil, nil
profession_info[302] = { name = "Alchemie", skill_line_name = "Alchemie",
    skill_line = 171, skill_level = 300 }
local eli = character("Eli", "Ravencrest")
assert(profile.activate_for(eli, menu) == true, "P9a FAIL: alchemy character was not activated")
assert(profile.gathering_enabled("herbalism") == false and profile.gathering_enabled("mining") == false
    and profile.gathering_enabled("skinning") == false and profile.gathering_enabled("fishing") == false,
    "P9b FAIL: a non-gathering profession enabled a gathering route")
local eli_line = find_log("[Eli - Ravencrest]")
assert(eli_line and string.find(eli_line, "gathering: none", 1, true),
    "P9c FAIL: the diagnostic did not report that nothing was unlocked: " .. tostring(eli_line))

-- P10: the reserve is clamped to the slider's range, so a value from a stale menu or an older
-- build can never hand the gathering route a reserve the control never allowed. This runs BEFORE
-- P5 on purpose: P5 proves an unreadable identity latches the name probe off for the session,
-- after which no further character can be activated.
local garm = character("Garm", "Ravencrest")
assert(profile.activate_for(garm, menu) == true, "P10a FAIL: clamped character was not activated")
menu.profile_gather_min_free_slots:set(99)
assert(profile.activate_for(garm, menu) == false, "P10b FAIL: same character should not be reactivated")
assert(profile.gather_min_free_slots() == 16,
    "P10c FAIL: a reserve above the slider maximum must clamp to 16, got " ..
    tostring(profile.gather_min_free_slots()))
menu.profile_gather_min_free_slots:set(-5)
assert(profile.activate_for(garm, menu) == false, "P10d FAIL: same character should not be reactivated")
assert(profile.gather_min_free_slots() == 0,
    "P10e FAIL: a negative reserve must clamp to 0 (the gate's off position), got " ..
    tostring(profile.gather_min_free_slots()))

-- P5: an unreadable identity stays on defaults, never claims another character's profile, and
-- logs no profession line (there is no profile to attach it to).
profile.reset()
local logs_before_nameless = #log_lines
local nameless = { get_name = function() error("no name") end }
assert(profile.activate_for(nameless, menu) == false, "P5a FAIL: nameless player must not activate")
assert(profile.profile_count() == 0, "P5b FAIL: nameless player created a profile")
assert(profile.vendor_threshold() == 80 and profile.mount_use_enabled() == true,
    "P5c FAIL: nameless player did not retain safe defaults")
assert(#log_lines == logs_before_nameless,
    "P5d FAIL: a profession diagnostic was logged without a character profile")
assert(profile.gather_min_free_slots() == 4,
    "P5e FAIL: a nameless player must fall back to the documented reserve default")

print("PASS test_character_profiles")
os.exit(0)
