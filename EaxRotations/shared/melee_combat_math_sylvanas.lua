-- melee_combat_math_sylvanas.lua -- physical damage / swing / crit / glancing formulas for melee specs.
-- WHAT:   physical damage / swing / crit / glancing formulas for melee specs
-- WHEN:   called per-frame in melee spec match functions
-- WHY:    single source of TBC melee formulas (no string-table lookups)
-- SAFETY: constants DBC-verified; pure math, no game API
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Pure math functions for TBC melee combat calculations:
-- glancing blow chance/damage, off-hand multiplier, dual-wield miss chance,
-- armor mitigation, and rage normalization.
-- No NS/api/ dependencies — safe for unit testing.
--
-- Usage (production):
--   local gc = NS.glancing_chance
--   local chance = gc(level_delta)
--
-- Usage (unit test — dofile pattern):
--   dofile("EaxRotations/shared/melee_combat_math_sylvanas.lua")
--   local glancing_chance = _G.MeleeCombatMath.glancing_chance

local M = {}

--- Glancing blow chance based on level difference.
-- TBC 2.4.3: 8% per level delta, capped at 24% for +3 (boss-level mobs).
-- @param level_delta  number — target_level - attacker_level (e.g. 3 for boss)
-- @return number — glancing chance as decimal (0.0 to 0.24)
function M.glancing_chance(level_delta)
    return math.min(0.24, (level_delta or 0) * 0.08)
end

--- Fixed glancing blow damage penalty.
-- TBC 2.4.3: glancing blows deal 40% reduced damage (fixed, not variable).
-- @return number — damage reduction factor (0.4)
function M.glancing_damage_penalty()
    return 0.4
end

--- Off-hand damage multiplier, scaling with Dual Wield Specialization talent.
-- TBC: Base 50% off-hand damage. Each talent rank adds 2.5% (max 5 ranks → 62.5%).
-- Applies to Warrior and Shaman Dual Wield Specialization talents.
-- @param talent_rank  number — number of talent points invested (0-5)
-- @return number — off-hand damage multiplier (0.5 to 0.625)
function M.off_hand_multiplier(talent_rank)
    return 0.5 + (talent_rank or 0) * 0.025
end

--- Dual-wield miss chance against a target.
-- TBC 2.4.3: base dual-wield miss is 19% vs same-level, 27% vs +3 boss.
-- This is the white-hit miss chance for off-hand (and main-hand while dual wielding).
-- @param level_delta  number — target_level - attacker_level
-- @return number — miss chance as decimal (0.19 or 0.27)
function M.dual_wield_miss_chance(level_delta)
    if (level_delta or 0) == 0 then
        return 0.19
    end
    return 0.27
end

--- Armor mitigation percentage for a given armor value and attacker level.
-- TBC 2.4.3 formula: armor / (armor + (467.5 * attacker_level - 22167.5))
-- For level 70 attacker: armor / (armor + 10557.5)
-- @param armor          number — target's armor value
-- @param attacker_level number — attacker level (default: 70)
-- @return number — mitigation as decimal (0.0 to ~1.0)
function M.armor_mitigation(armor, attacker_level)
    attacker_level = attacker_level or 70
    local divider = 467.5 * attacker_level - 22167.5
    return armor / (armor + divider)
end

--- Rage normalization factor for auto-attack rage generation.
-- TBC 2.4.3: rage from auto-attacks is normalized to a 2.5-second swing timer.
-- Factor = weapon_speed / 2.5. Faster weapons generate less rage per hit,
-- slower weapons generate more.
-- @param weapon_speed number — weapon speed in seconds (default: 3.0)
-- @return number — normalization factor
function M.rage_normalization(weapon_speed)
    return (weapon_speed or 3.0) / 2.5
end

-- Export to _G for dofile-based unit testing
local _G = _G
_G.MeleeCombatMath = M

-- Export to NS namespace (Sylvanas production path)
if _G.EaxRotations then
    _G.EaxRotations.MeleeCombatMath = M
    _G.EaxRotations.glancing_chance = M.glancing_chance
    _G.EaxRotations.glancing_damage_penalty = M.glancing_damage_penalty
    _G.EaxRotations.off_hand_multiplier = M.off_hand_multiplier
    _G.EaxRotations.dual_wield_miss_chance = M.dual_wield_miss_chance
    _G.EaxRotations.armor_mitigation = M.armor_mitigation
    _G.EaxRotations.rage_normalization = M.rage_normalization
end

return M
