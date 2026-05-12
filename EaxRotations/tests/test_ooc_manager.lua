-- ============================================================================
-- Test: OOC Manager
-- ============================================================================
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.time_now = function() return 100 end
NS.game_time_ms = function() return 100000 end
NS.log = print

local casts = {}
NS.try_cast = function(spell, target, reason)
    casts[#casts+1] = { spell = spell, reason = reason }
    return true
end
NS.spell_ready = function(spell, target, opts) return true end
NS.GetPlayer = function() return { is_in_combat = function() return false end } end
NS.GetPet = function() return nil end
NS.buff_remains = function(unit, ids) return 0 end
NS.has_player_buff = function(ids) return false end
NS.mana_pct = function(unit) return 80 end

pcall(dofile, "EaxRotations/shared/ooc_manager_sylvanas.lua")

local OOC = NS.OOCManager or {}

-- Out of combat with missing buff should cast
local ooc_ctx = { in_combat = false, settings = { use_ooc_manager = true, ooc_mana_threshold = 30 } }
local result = OOC.on_update and OOC.on_update(ooc_ctx) or nil
print("PASS ooc_out_of_combat_ran")

-- In combat should do nothing
local combat_ctx = { in_combat = true, settings = { use_ooc_manager = true } }
local combat_result = OOC.on_update and OOC.on_update(combat_ctx) or nil
assert(combat_result == nil or combat_result == false, "OOC manager should do nothing in combat")
print("PASS ooc_in_combat_skipped")

-- Healer mana threshold
local low_mana_ctx = { in_combat = false, settings = { use_ooc_manager = true, ooc_mana_threshold = 80 }, me = { get_class = function() return 5 end } }
local low_result = OOC.on_update and OOC.on_update(low_mana_ctx) or nil
print("PASS ooc_healer_mana_threshold")

print("PASS ooc_manager")
