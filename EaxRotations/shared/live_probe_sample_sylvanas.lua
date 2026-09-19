-- live_probe_sample_sylvanas.lua — one snapshot line at the moment of an action.
-- WHAT:  sample(tag, context): form / energy / rage / mana% / hp% / combo / AP /
--        haste plus a timestamp on a single line.
-- WHEN:  run from the Diagnostics "Probe: Snapshot Now" entry; inert at load.
-- WHY:   the Block-1 gate probes compare values at one instant, and a single
--        line is the cheapest honest record of that instant.
-- SAFETY: nil-safe with no player and no context; reads only, never writes.
local NS = _G.EaxRotations
if not NS then return nil end
local type = type
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local kit = require("shared/live_probe_kit_sylvanas")
local out, safe, player, now, power_of = kit.out, kit.safe, kit.player, kit.now, kit.power_of
local M = {}
-- ---------------------------------------------------------------------------
-- M.sample(tag, context): one snapshot line at the moment of an in-game action
-- ---------------------------------------------------------------------------
local function snapshot(p, context)
    local form = nil
    if p then
        form = safe(p.get_form, p) or safe(p.get_shapeshift_form, p)
    end
    local energy = context and tonumber(context.energy) or power_of(p, NS.POWER_ENERGY)
    local rage = context and tonumber(context.rage) or power_of(p, NS.POWER_RAGE)
    if rage == nil then rage = power_of(p, NS.POWER_RAGE) end
    local mana_pct = context and tonumber(context.mana_pct) or safe(NS.unit_mana_pct, p)
    local ap = p and safe(p.get_attack_power, p) or nil
    local haste = p and safe(p.get_haste, p) or nil
    return {
        form = form, energy = energy, rage = rage, mana_pct = mana_pct,
        hp_pct = context and tonumber(context.hp_pct) or nil,
        combo = context and tonumber(context.combo_points) or nil,
        ap = tonumber(ap), haste = tonumber(haste),
        t = now(),
    }
end

function M.sample(tag, context)
    kit.reset_lines()
    local p = player()
    local s = snapshot(p, context)
    out(string_format(
        "[LiveProbe] %s t=%.2f form=%s energy=%s rage=%s mana=%s hp=%s combo=%s ap=%s haste=%s",
        tostring(tag or "sample"), s.t, tostring(s.form or "-"), tostring(s.energy or "-"),
        tostring(s.rage or "-"), tostring(s.mana_pct or "-"), tostring(s.hp_pct or "-"),
        tostring(s.combo or "-"), tostring(s.ap or "-"), tostring(s.haste or "-")))
    return s
end
return M
