-- Test: Aspect Manager shared module.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

_G.EaxRotations = { log = function() end }
local AM = dofile("EaxRotations/shared/aspect_manager_sylvanas.lua")
assert_true(AM ~= nil, "module should load")

-- should_hawk: already has hawk -> false
assert_false(AM.should_hawk({ has_aspect_hawk = true, mana_pct = 100 }), "already hawk -> false")

-- should_hawk: has viper, mana not recovered -> false
assert_false(AM.should_hawk({ has_aspect_viper = true, mana_pct = 20 }), "viper + low mana -> false")

-- should_hawk: has viper, mana recovered -> true
assert_true(AM.should_hawk({ has_aspect_viper = true, mana_pct = 30 }), "viper + recovered mana -> true")

-- should_viper: already viper -> false
assert_false(AM.should_viper({ has_aspect_viper = true, mana_pct = 10 }), "already viper -> false")

-- should_viper: mana above threshold -> false
assert_false(AM.should_viper({ has_aspect_viper = false, mana_pct = 50 }), "high mana -> false")

-- should_viper: mana below threshold -> true
assert_true(AM.should_viper({ has_aspect_viper = false, mana_pct = 3 }), "low mana -> true")

-- should_cheetah: in combat -> false
assert_false(AM.should_cheetah({ in_combat = true, is_mounted = false, enemy_count = 0 }, { has_valid_enemy_target = false }), "in combat -> false")

-- should_cheetah: mounted -> false
assert_false(AM.should_cheetah({ in_combat = false, is_mounted = true, enemy_count = 0 }, { has_valid_enemy_target = false }), "mounted -> false")

-- should_cheetah: enemies nearby -> false
assert_false(AM.should_cheetah({ in_combat = false, is_mounted = false, enemy_count = 1 }, { has_valid_enemy_target = false }), "enemies nearby -> false")

-- should_cheetah: safe OOC -> true
assert_true(AM.should_cheetah({ in_combat = false, is_mounted = false, enemy_count = 0 }, { has_valid_enemy_target = false }), "safe OOC -> true")

-- recommend_aspect: low mana -> viper
assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
assert_eq(AM.recommend_aspect({ has_aspect_viper = false, mana_pct = 10, in_combat = true }, {}, 20), "viper", "low mana -> viper")

-- recommend_aspect: recovered -> hawk
assert_eq(AM.recommend_aspect({ has_aspect_hawk = false, has_aspect_viper = true, mana_pct = 40, in_combat = true }, {}, 20), "hawk", "recovered -> hawk")

-- recommend_aspect: no change -> nil
assert_eq(AM.recommend_aspect({ has_aspect_hawk = true, mana_pct = 80, in_combat = true }, {}, 20), nil, "no change -> nil")

print("PASS test_aspect_manager")
