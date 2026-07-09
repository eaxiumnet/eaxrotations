-- diagnostics.lua — Logging and diagnostic helpers for EaxRotations.
-- WHAT:  NS.log / NS.log_warning / NS.log_error + API-health stubs + spell dump.
-- WHEN:  installed by core_sylvanas.lua during addon load (must be FIRST install).
-- WHY:   separates logging from core logic; NS.log is required by other domains.
-- SAFETY: safe fallbacks when core.log is unavailable; never errors on nil fields.

-- =============================================================================
-- core/diagnostics.lua
--
-- Diagnostics domain — extracted from EaxRotations/core_sylvanas.lua.
-- Owns the logging emit helper, NS.log / log_warning / log_error,
-- the API-health stubs (is_api_health_broken / reset_api_health — no-ops
-- since PS build API health tracking was removed in v2.1.x), and
-- NS.dump_class_spells (per-class spell-known diagnostic dump).
--
-- WHY THIS EXTRACT
--   core_sylvanas.lua mixed ~15 unrelated domains. Centralising diagnostics
--   lets logging / dump logic evolve in one file. NS.log is required early
--   in core_sylvanas's own load (the units/items/cooldowns domain installs
--   log via NS.log), so diagnostics installs FIRST, in place of the original
--   inline definitions. dump_class_spells resolves NS.GetPlayer /
--   NS.spell_id_is_known / NS.izi at CALL time, so installing early is safe.
--
-- CONTRACT
--   - install(NS): wires NS.log, NS.log_warning, NS.log_error,
--     NS.is_api_health_broken, NS.reset_api_health, NS.dump_class_spells.
--   - Reads the `core` global via _G.core (same pattern as aura_cache).
--   - Behavior identical to the pre-extract inline definitions.
-- =============================================================================

local _G = _G
local core = _G.core
local M = {}

local function emit(kind, prefix, msg)

    msg = tostring(msg or "")

    local fn = core and core[kind]

    if type(fn) == "function" then pcall(fn, "[EaxRotations] " .. msg)

    elseif print then print(prefix .. msg) end

end

function M.install(NS)
function NS.log(msg) emit("log", "[EaxRotations] ", msg) end

function NS.log_warning(msg) emit("log_warning", "[EaxRotations WARNING] ", msg) end

function NS.log_error(msg) emit("log_error", "[EaxRotations ERROR] ", msg) end

-- Backward-compatible stubs: PS build API health tracking was removed
-- in v2.1.x (live TBC Classic only). These no-ops prevent crashes in
-- callers (paladin class init, warlock vanilla specs, test files).
function NS.is_api_health_broken()
    return false
end

function NS.reset_api_health()
    -- No-op: API health counters were removed.
end

--- Dumps every spell entry registered for `class_name` (e.g. "Paladin").
--- Logs the table name, each spell name, the first id that returns true from
--- NS.spell_id_is_known (or "none" if all ids are unknown), and whether the
--- spell is available at the player's current level.
--- Call as NS.dump_class_spells("Paladin") — must run after class module loads.
function NS.dump_class_spells(class_name)
    class_name = class_name or "Unknown"
    local tbl_name = class_name .. "Spells"
    local tbl = NS[tbl_name]
    if not tbl then
        NS.log("dump_class_spells: no table " .. tbl_name .. " found on NS")
        return
    end
    -- Get player level for level-appropriate reporting
    local player = NS.GetPlayer()
    local player_level = 0
    if player and type(player.get_level) == "function" then
        player_level = player:get_level() or 1
    end
    if player_level == 0 then
        -- Fallback: try izi level
        local ok, lvl = pcall(function() return player:level() end)
        if ok and lvl then player_level = lvl end
    end
    if player_level == 0 then player_level = 1 end

    NS.log("=== DUMP CLASS SPELLS: " .. class_name .. " (Player Level " .. tostring(player_level) .. ") ===")
    local known_count = 0
    local available_count = 0
    local missing_count = 0
    for key, spell in pairs(tbl) do
        if type(spell) == "table" then
            -- Read _meta.ids / _meta.levels as fallbacks before the
            -- direct spell.ids / spell.levels fields. NS.spell_action
            -- stores the rank arrays at spell._meta, so the dump must
            -- look there first to see the real level / id lists.
            local meta = spell._meta or spell
            local ids = meta.ids or spell.ids or (spell[1] and { spell[1] }) or {}
            local levels = meta.levels or spell.levels or {}
            local name = spell.name or tostring(key)
            local resolved = 0

            -- Check which rank the player qualifies for by level
            local best_rank_idx = 0
            if #levels > 0 and #ids > 0 then
                for i = #levels, 1, -1 do
                    if levels[i] and levels[i] <= player_level then
                        best_rank_idx = i
                        break
                    end
                end
            end

            -- Check if already known via API
            for _, id in ipairs(ids) do
                if NS.spell_id_is_known(id) then
                    resolved = id
                    break
                end
            end

            -- Also check via IZI (may report known when core doesn't)
            local izi_known_id = 0
            if not resolved and NS.izi then
                for _, id in ipairs(ids) do
                    local ok, learned = pcall(function()
                        local s = NS.izi.spell(id)
                        return s and s.is_learned and s:is_learned()
                    end)
                    if ok and learned then
                        izi_known_id = id
                        break
                    end
                end
            end

            if resolved ~= 0 then
                known_count = known_count + 1
                local prefix = "[KNOWN]  "
                if best_rank_idx > 0 then
                    local lvl = levels[best_rank_idx]
                    local id_by_level = ids[best_rank_idx]
                    if resolved == id_by_level then
                        NS.log("  " .. prefix .. name .. " -> id=" .. tostring(resolved) .. " (rank " .. tostring(lvl) .. ")")
                    else
                        NS.log("  " .. prefix .. name .. " -> id=" .. tostring(resolved) .. " (highest rank " .. tostring(lvl) .. " is id=" .. tostring(id_by_level) .. ")")
                    end
                else
                    NS.log("  " .. prefix .. name .. " -> id=" .. tostring(resolved))
                end
            elseif izi_known_id ~= 0 then
                known_count = known_count + 1
                NS.log("  [IZI]   " .. name .. " -> id=" .. tostring(izi_known_id) .. " (core reports unknown, IZI reports learned)")
            elseif best_rank_idx > 0 then
                available_count = available_count + 1
                local lvl = levels[best_rank_idx]
                local id_by_level = ids[best_rank_idx]
                NS.log("  [LVL " .. tostring(lvl) .. "] " .. name .. " -> id=" .. tostring(id_by_level) .. " (not yet trained)")
            else
                local next_lvl = (#levels > 0 and levels[1]) and (" (first at " .. tostring(levels[1]) .. ")") or ""
                missing_count = missing_count + 1
                NS.log("  [MISSING] " .. name .. next_lvl)
            end
        end
    end
    NS.log("=== END DUMP: " .. tostring(known_count) .. " known, " .. tostring(available_count) .. " available at level, " .. tostring(missing_count) .. " above level ===")
end

end

return M
