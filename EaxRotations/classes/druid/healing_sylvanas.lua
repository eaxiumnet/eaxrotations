-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/druid/healing_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- shared druid healing helpers for resto/off-heal playstyles.

-- ============================================================================
-- What: Shared Druid healing helpers for Resto and off-heal playstyles
-- When: Loaded once, then reused by healing strategies
-- Why: Shared helper keeps healing scans and aura checks reusable
-- Safety: Nil-guarded unit checks; NS.* wrappers; static tables reused; conservative fallbacks
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end

local M = {}
local healing_targets = {}
local healing_targets_count = 0
local scan_frame = 0
local LIFEBLOOM_MAX_STACKS = 3
local LIFEBLOOM_REFRESH_REMAINS = 1.6

local SPELLS = NS.DruidSpells or {
    Lifebloom = NS.spell_action(33763, "Lifebloom"),
    Rejuvenation = NS.spell_action(26982, "Rejuvenation"),
    Regrowth = NS.spell_action(26980, "Regrowth"),
    HealingTouch = NS.spell_action(26979, "HealingTouch"),
}

local function has(unit, spell)
    return unit and spell and NS.buff_up(unit, spell.id or spell)
end

local function stacks(unit, spell)
    return unit and spell and NS.buff_stacks and NS.buff_stacks(unit, spell.id or spell) or 0
end

local function remains(unit, spell)
    return unit and spell and NS.buff_remains and NS.buff_remains(unit, spell.id or spell) or 0
end

function M.scan_healing_targets()
    local current_frame = math.floor(NS.game_time_ms() / (1000 / 60))
    if current_frame > 0 and current_frame == scan_frame then
        return healing_targets, healing_targets_count
    end
    scan_frame = current_frame
    healing_targets_count = NS.build_healing_entries(healing_targets, function(entry, unit)
        entry.has_lifebloom = has(unit, SPELLS.Lifebloom)
        entry.lifebloom_stacks = stacks(unit, SPELLS.Lifebloom)
        entry.lifebloom_remains = remains(unit, SPELLS.Lifebloom)
        entry.has_rejuvenation = has(unit, SPELLS.Rejuvenation)
        entry.has_regrowth = has(unit, SPELLS.Regrowth)
    end)
    return healing_targets, healing_targets_count
end

function M.tank_target()
    M.scan_healing_targets()
    return NS.healing_get_tank(healing_targets, healing_targets_count)
end

function M.best_target(context)
    M.scan_healing_targets()
    return NS.healing_get_lowest_hp(healing_targets, healing_targets_count, 92)
end

function M.recommend(context)
    local entry = M.best_target(context)
    local tank = M.tank_target()
    if not entry and tank then entry = tank end
    if not entry or not entry.unit then return nil end
    local target = entry.unit

    local hp = entry.hp or NS.unit_health_pct(target)
    local effective = entry.effective_hp or hp

    if effective <= 35 then
        return { spell = SPELLS.HealingTouch, target = target, reason = "emergency direct heal" }
    end
    if effective <= 55 and not entry.has_regrowth then
        return { spell = SPELLS.Regrowth, target = target, reason = "stabilize with direct heal plus HoT" }
    end
    if tank and tank.unit and (context.in_combat or (tank.effective_hp or 100) <= 95) then
        local lb_stacks = tank.lifebloom_stacks or 0
        local lb_remains = tank.lifebloom_remains or 0
        if lb_stacks < LIFEBLOOM_MAX_STACKS or lb_remains <= LIFEBLOOM_REFRESH_REMAINS then
            return { spell = SPELLS.Lifebloom, target = tank.unit, reason = "maintain tank Lifebloom roll" }
        end
    end
    if hp <= 85 and not entry.has_lifebloom then
        return { spell = SPELLS.Lifebloom, target = target, reason = "tank/party rolling HoT" }
    end
    if hp <= 90 and not entry.has_rejuvenation then
        return { spell = SPELLS.Rejuvenation, target = target, reason = "efficient maintenance HoT" }
    end
    return nil
end

function M.try_heal(context)
    -- Mounted bail: healer should not queue heals while mounted
    local me = context and context.me or NS.GetPlayer()
    if me and me.is_mounted and me:is_mounted() then return false end
    local rec = M.recommend(context)
    if not rec then return false end
    return NS.try_cast(rec.spell, rec.target, "[DRUID HEAL] " .. rec.reason)
end

NS.DruidHealing = M
return M
