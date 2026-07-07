-- Gate test: Rogue Assassination custom matches functions.
-- Covers: SliceAndDice, RuptureBleed, EnvenomFinisher, ColdBloodEnvenom,
--         ExposeArmor, DeadlyThrow, BlindCC, PvP_SprintGapClose.
-- Asserts TRUE/FALSE return values (gold-standard style, not just no-crash).

package.path = "EaxRotations/?.lua;" .. package.path

local cap_gs, cap_st
_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations
NS.PLAYER_UNIT = {}
NS.spell_action = function() return {} end
NS.spell_ready = function() return true end
NS.try_cast = function() return false end
NS.has_player_buff = function() return false end
NS.has_target_debuff = function() return false end
NS.debuff_remains = function() return 0 end
NS.buff_remains = function() return 0 end
NS.get_debuff_stacks = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.log = function() end
NS.time_now = function() return 100 end
NS.GetPlayer = function() return {} end
NS.OffensiveDispelDB = { find_best_dispel_target = function() return nil end }
NS.rotation_registry = { register = function(self, spec, strats, opts) cap_st = strats; cap_gs = opts and opts.get_state end }
package.loaded["shared/potion_helper_sylvanas"] = {}
package.loaded["shared/offensive_dispel_sylvanas"] = { find_best_dispel_target = function() return nil end }

local st = dofile("EaxRotations/classes/rogue/assassination_sylvanas.lua").strategies
assert(cap_st, "Assassination strategies captured via register")
assert(cap_gs, "build_state captured")

local function at(v, m) if not v then error("FAIL: " .. m) end end
local function af(v, m) if v then error("FAIL: " .. m) end end
local function fs(n) for i = 1, #cap_st do if cap_st[i].name == n then return cap_st[i] end end error("not found: " .. n) end

-- State defaults: high combo, plenty energy, SnD up + fresh, rupture up, DP 5 stacks.
local function cs(o)
    local s = {
        combo = 5, energy = 80, energy_pool_finisher = false,
        slice_dice_active = true, snd_needs_refresh = false, snd_remains = 30,
        rupture_remains = 10, dp_stacks = 5, has_cold_blood = false,
        hp_pct = 100, find_weakness_active = false, target_poisoned = true,
    }
    if o then for k, v in pairs(o) do s[k] = v end end
    return s
end

-- SliceAndDice: skip if active & not needing refresh; match if not active, combo >= 2.
local snd = fs("SliceAndDice")
af(snd.matches({ target = {} }, cs({ slice_dice_active = true, snd_needs_refresh = false })), "SnD active+fresh skip")
at(snd.matches({ target = {} }, cs({ combo = 3, slice_dice_active = false })), "SnD match")
af(snd.matches({ target = {} }, cs({ combo = 1, slice_dice_active = false })), "SnD low combo")

-- RuptureBleed: combo >= 4, rupture not fresh, target bleeds, TTD > 12.
local rup = fs("RuptureBleed")
af(rup.matches({ target = {} }, cs({ combo = 2 })), "Rupture low combo")
af(rup.matches({ target = {} }, cs({ combo = 5, rupture_remains = 30 })), "Rupture fresh skip")
af(rup.matches({ target = {}, target_bleed_immune = true }, cs({ combo = 5, rupture_remains = 0 })), "Rupture bleed-immune skip")
at(rup.matches({ target = {}, ttd = 30, ttd_known = true }, cs({ combo = 5, rupture_remains = 0 })), "Rupture match")

-- EnvenomFinisher: SnD up, combo >= 4, DP >= stacks.
local env = fs("EnvenomFinisher")
af(env.matches({ target = {} }, cs({ combo = 2, dp_stacks = 5 })), "Envenom low combo")
af(env.matches({ target = {} }, cs({ combo = 5, slice_dice_active = false })), "Envenom no SnD")
at(env.matches({ target = {} }, cs({ combo = 5, dp_stacks = 5 })), "Envenom match")

-- ColdBloodEnvenom: requires setting assassin_cold_blood_auto, combo >= 5, DP >= stacks.
local cb = fs("ColdBloodEnvenom")
af(cb.matches({ target = {}, settings = {} }, cs({ combo = 5, dp_stacks = 5 })), "ColdBlood not enabled")
af(cb.matches({ target = {}, settings = { assassin_cold_blood_auto = true } }, cs({ combo = 4, dp_stacks = 5 })), "ColdBlood low combo")
at(cb.matches({ target = {}, settings = { assassin_cold_blood_auto = true } }, cs({ combo = 5, dp_stacks = 5 })), "ColdBlood match")

-- ExposeArmor: target, combo >= 3, has armor, no sunder.
local ea = fs("ExposeArmor")
af(ea.matches({ target = {} }, cs({ combo = 2 })), "Expose low combo")
af(ea.matches({ target = {}, has_sunder = true }, cs({ combo = 5 })), "Expose sundered skip")
af(ea.matches({ target = {}, target_armor = 0 }, cs({ combo = 5 })), "Expose no armor skip")
at(ea.matches({ target = {}, target_armor = 5000 }, cs({ combo = 5 })), "Expose match")

-- DeadlyThrow: combo >= 3.
local dt = fs("DeadlyThrow")
af(dt.matches({ target = {} }, cs({ combo = 2 })), "DeadlyThrow low combo")
at(dt.matches({ target = {} }, cs({ combo = 3 })), "DeadlyThrow match")

-- BlindCC: requires PvP or group.
local blind = fs("BlindCC")
af(blind.matches({ target = {}, is_pvp = false, is_group = false }), "Blind not PvP")
at(blind.matches({ target = {}, is_pvp = true }), "Blind match")

-- PvP_SprintGapClose: PvP, target_distance >= 15.
local sprint = fs("PvP_SprintGapClose")
af(sprint.matches({ target = {}, is_pvp = true, target_distance = 10 }), "Sprint in range skip")
at(sprint.matches({ target = {}, is_pvp = true, target_distance = 25 }), "Sprint match")
af(sprint.matches({ target = {}, is_pvp = false, target_distance = 25 }), "Sprint not PvP")

print("PASS test_assassination_custom_matches")
