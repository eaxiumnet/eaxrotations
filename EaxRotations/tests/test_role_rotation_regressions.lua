-- role-focused regressions for healer scans, load order, and tank/AoE priorities.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;api/?/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local function read_file(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()
    return data
end

local function new_unit(opts)
    opts = opts or {}
    local unit = {}
    function unit:is_valid() return true end
    function unit:is_unit() return true end
    function unit:get_health() return opts.health or 1000 end
    function unit:get_max_health() return opts.max_health or 1000 end
    function unit:get_health_percentage() return ((opts.health or 1000) / (opts.max_health or 1000)) * 100 end
    function unit:get_incoming_heals() return opts.incoming or 0 end
    function unit:get_total_shield() return opts.absorb or 0 end
    function unit:get_group_role() return opts.role or -1 end
    function unit:is_tank() return opts.is_tank == true end
    function unit:is_friend_with(other) return opts.friend == true end
    function unit:get_distance(other) return opts.distance or 0 end
    return unit
end

local player = new_unit({ health = 900, max_health = 1000, role = -1, distance = 0 })
function player:get_class() return 5 end

local ally_in_range = new_unit({ health = 500, max_health = 1000, role = 0, friend = true, distance = 35 })
local ally_out_of_range = new_unit({ health = 100, max_health = 1000, role = 0, friend = true, distance = 42 })
local role_extension_tank = new_unit({ health = 700, max_health = 1000, role = -1, is_tank = true, friend = true, distance = 30 })

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return { player, ally_in_range, ally_out_of_range, role_extension_tank } end,
    },
    spell_book = {},
    input = {},
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil
local NS = require("core_sylvanas")

local entries = {}
local count = NS.build_healing_entries(entries)
assert_eq(count, 3, "healing scan should include unique player and 40 yd friendlies only")

local player_entry, tank_entry, out_entry, extension_tank_entry = nil, nil, nil, nil
for i = 1, count do
    if entries[i].unit == player then player_entry = entries[i] end
    if entries[i].unit == ally_in_range then tank_entry = entries[i] end
    if entries[i].unit == ally_out_of_range then out_entry = entries[i] end
    if entries[i].unit == role_extension_tank then extension_tank_entry = entries[i] end
end

assert_true(player_entry and player_entry.is_player == true, "player healing entry should be flagged")
assert_true(tank_entry and tank_entry.is_tank == true, "tank role should be flagged from get_group_role()")
assert_true(extension_tank_entry and extension_tank_entry.is_tank == true, "tank role should be flagged from is_tank() extension")
assert_true(out_entry == nil, "42 yd unit should not be selected as heal target")

local druid_class = read_file("EaxRotations/classes/druid/class_sylvanas.lua")
local healing_pos = assert(druid_class:find('load_child%("healing_sylvanas"%)'))
local resto_pos = assert(druid_class:find('load_child%("resto_sylvanas"%)'))
assert_true(healing_pos < resto_pos, "druid healing helpers should load before resto")

local prot = read_file("EaxRotations/classes/warrior/protection_sylvanas.lua")
local thunder = prot:match('%{ name = "ThunderClap".-%}')
assert_true(thunder and not thunder:find("required_stance", 1, true), "prot Thunder Clap should not require Battle Stance")

local holy = read_file("EaxRotations/classes/priest/holy_sylvanas.lua")
local coh_pos = assert(holy:find('name = "CircleOfHealing"', 1, true))
local poh_pos = assert(holy:find('name = "PrayerOfHealing"', 1, true))
local gh_pos = assert(holy:find('name = "GreaterHeal"', 1, true))
local fh_pos = assert(holy:find('name = "FlashHeal"', 1, true))
assert_true(coh_pos < poh_pos, "CoH should stay before PoH")
assert_true(poh_pos < gh_pos and poh_pos < fh_pos, "PoH should precede single-target filler heals")

local paladin_holy = read_file("EaxRotations/classes/paladin/holy_sylvanas.lua")
local shock = paladin_holy:match('name = "HolyShock".-name = "SmartHeal"')
assert_true(shock and shock:find("context.is_moving", 1, true), "Holy Shock should be movement/emergency gated")

print("PASS test_role_rotation_regressions")
