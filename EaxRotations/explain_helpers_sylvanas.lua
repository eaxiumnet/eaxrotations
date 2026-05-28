-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "explain_helpers_sylvanas.lua"
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
-- diagnostic helper.

-- ============================================================================
-- EaxRotations - Explain Helpers
-- Debug-only summaries for strategy and spell gate failures.
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local tostring = tostring
local type = type
local concat = table.concat
local ipairs = ipairs

local context_parts = {}
local spell_parts = {}
local readiness_parts = {}

local function append(parts, index, key, value)
    index = index + 1
    parts[index] = key .. "=" .. tostring(value)
    return index
end

local function clear_tail(parts, from_index)
    for i = from_index, #parts do
        parts[i] = nil
    end
end

local function safe_call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return "err:" .. tostring(result)
end

function NS.explain_context_gates(context)
    if not context then return "context=nil" end

    local n = 0
    n = append(context_parts, n, "combat", context.in_combat)
    n = append(context_parts, n, "target", context.has_valid_enemy_target)
    n = append(context_parts, n, "gcd", context.gcd_remains or 0)
    n = append(context_parts, n, "casting", context.casting_or_channeling)
    n = append(context_parts, n, "cc", context.player_control_locked)
    n = append(context_parts, n, "moving", context.is_moving)
    n = append(context_parts, n, "mounted", context.is_mounted)
    n = append(context_parts, n, "phys_immune", context.target_phys_immune)
    n = append(context_parts, n, "enemies", context.enemies_count or context.enemy_count or 0)
    n = append(context_parts, n, "hp", context.hp or "?")
    n = append(context_parts, n, "mana", context.mana_pct or "?")
    n = append(context_parts, n, "ttd", context.ttd or "?")

    clear_tail(context_parts, n + 1)
    return concat(context_parts, " ")
end

function NS.explain_spell_gates(spell, target)
    if not spell then return "spell=nil" end

    local meta = spell._meta or {}
    local cast_target = meta.is_self_cast and NS.GetPlayer and NS.GetPlayer() or target
    local n = 0

    n = append(spell_parts, n, "id", meta.id or "?")
    n = append(spell_parts, n, "desc", meta.desc or "?")
    n = append(spell_parts, n, "self", meta.is_self_cast == true)
    n = append(spell_parts, n, "target", cast_target ~= nil)
    n = append(spell_parts, n, "exists", safe_call(NS.spell_exists, spell))
    n = append(spell_parts, n, "ready", safe_call(NS.spell_ready, spell, cast_target))
    n = append(spell_parts, n, "cd", safe_call(NS.cooldown_remains, spell))

    if spell.IsInRange then
        n = append(spell_parts, n, "range", safe_call(spell.IsInRange, spell, cast_target))
    end

    clear_tail(spell_parts, n + 1)
    return concat(spell_parts, " ")
end

function NS.explain_spell_readiness(spell, target)
    if not spell then return "spell=nil" end

    local meta = spell._meta or {}
    local ids = meta.ids or { meta.id }
    local core = NS.core or _G.core or {}
    local spell_book = core.spell_book or {}
    local me = NS.GetPlayer and NS.GetPlayer() or nil
    local cast_target = meta.is_self_cast and me or target
    local n = 0

    n = append(readiness_parts, n, "id", meta.id or "?")
    n = append(readiness_parts, n, "target", cast_target ~= nil)
    n = append(readiness_parts, n, "exists", safe_call(NS.spell_exists, spell))
    n = append(readiness_parts, n, "ready", safe_call(NS.spell_ready, spell, cast_target))

    for _, spell_id in ipairs(ids) do
        if spell_id then
            local learned = safe_call(NS.spell_id_is_known, spell_id)
            local usable = safe_call(spell_book.is_usable_spell, spell_id)
            local cd = safe_call(spell_book.get_spell_cooldown, spell_id)
            local range = "skip"
            if cast_target and not meta.is_self_cast then
                range = safe_call(spell_book.is_spell_in_range, spell_id, cast_target, me)
            end
            n = append(readiness_parts, n, "rank" .. tostring(spell_id), "learned:" .. tostring(learned) .. "/api_usable:" .. tostring(usable) .. "/cd:" .. tostring(cd) .. "/range:" .. tostring(range))
        end
    end

    clear_tail(readiness_parts, n + 1)
    return concat(readiness_parts, " ")
end

NS.log("Explain helpers ready")

return {
    explain_context_gates = NS.explain_context_gates,
    explain_spell_gates = NS.explain_spell_gates,
    explain_spell_readiness = NS.explain_spell_readiness,
}
