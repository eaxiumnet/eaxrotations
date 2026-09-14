-- test_sod_interrupt_lanes.lua -- SoD per-class interrupt-manager lanes.
-- WHAT: loads the 12 specs wired in the 2026-09-14 SoD interrupt sweep and
--       proves each Interrupt lane's fire/hold/inert/identity/stance contract.
-- WHY: every non-druid SoD spec previously had no interrupt path; the manager
--      lane is strategy #1 and must beat casts while holding on every gate.
-- SAFETY: deterministic API stubs; no game client, network, or persistent state.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
	if actual ~= expected then
		error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
	end
end

local registered = {}
local cast_action
_G.EaxRotations = {
	is_sod = function() return true end,
	rotation_registry = {
		register = function(_, name, strategies, options)
			registered[name] = { strategies = strategies, options = options }
		end,
	},
	spell_action = function(ids, label)
		local id = type(ids) == "table" and ids[1] or ids
		return { _meta = { id = id, name = label } }
	end,
	spell_ready = function() return true end,
	try_cast = function(action)
		cast_action = action
		return true
	end,
	-- class spell tables referenced by define_sod_action_for_class call sites
	-- (the W5.1 factory ignores them; explicit SoD ids are authoritative).
	DruidSpells = {}, HunterSpells = {}, RogueSpells = {}, ShamanSpells = {},
	MageSpells = {}, WarriorSpells = {}, PriestSpells = {}, PaladinSpells = {},
	WarlockSpells = {},
}

local function load(path)
	package.loaded[path] = nil
	return assert(require(path), "module did not load: " .. path)
end

local function interrupt_strategy(module)
	for i = 1, #module.strategies do
		if module.strategies[i].name == "Interrupt" then return module.strategies[i] end
	end
	error("missing Interrupt lane", 2)
end

-- Manager gate stubs (same shape the druid pins proved in test_sod_druid_hunter).
local NS = _G.EaxRotations
NS.try_interrupt = function(t) return t ~= nil end
NS.gcd_remains = function() return 0 end
NS.time_now = function() return 100 end

local INTERRUPT_SETTINGS = { interrupt_humanize_enabled = false }
local me = {}
local target = {} -- bare table: the cast-window check fails open (druid-pin precedent)

local SPECS = {
	{ path = "classes/mage/dps_mage_sod", action = "Counterspell", id = 2139, ctx = { in_combat = true } },
	{ path = "classes/rogue/combat_sod", action = "Kick", id = 1769, ctx = { in_combat = true } },
	{ path = "classes/rogue/tank_sod", action = "Kick", id = 1769, ctx = { in_combat = true } },
	{ path = "classes/warrior/dps_warrior_sod", action = "Pummel", id = 6554, ctx = { in_combat = true, stance = 3 }, pummel = true },
	{ path = "classes/warrior/tank_warrior_sod", action = "ShieldBash", id = 1672, ctx = { in_combat = true, stance = 2 }, shield_bash = true },
	{ path = "classes/shaman/elemental_sod", action = "EarthShock", id = 10414, ctx = { in_combat = true } },
	{ path = "classes/shaman/enhancement_sod", action = "EarthShock", id = 10414, ctx = { in_combat = true } },
	{ path = "classes/shaman/warden_sod", action = "EarthShock", id = 10414, ctx = { in_combat = true } },
	{ path = "classes/shaman/restoration_sod", action = "EarthShock", id = 10414, ctx = { in_combat = true } },
	{ path = "classes/priest/shadow_sod", action = "Silence", id = 15487, ctx = { in_combat = true } },
	{ path = "classes/paladin/protection_sod", action = "HammerOfJustice", id = 10308, ctx = { in_combat = true } },
	{ path = "classes/paladin/retribution_sod", action = "HammerOfJustice", id = 10308, ctx = { in_combat = true } },
}

for _, spec in ipairs(SPECS) do
	local module = load(spec.path)
	local lane = interrupt_strategy(module)
	local ctx = { is_sod = true, sod_phase = 8, target = target, me = me,
		in_combat = true, settings = INTERRUPT_SETTINGS }
	for k, v in pairs(spec.ctx) do ctx[k] = v end
	local state = {}

	-- Inert without NS.try_interrupt (skip-lane contract: hold, not error).
	local saved_ti = NS.try_interrupt
	NS.try_interrupt = nil
	assert_eq(lane.matches(ctx, state), false, spec.path .. " Interrupt lane inert without NS.try_interrupt")
	NS.try_interrupt = saved_ti

	-- Fire on a casting target.
	assert_eq(lane.matches(ctx, state), true, spec.path .. " Interrupt lane fires on a casting target")

	-- Hold: spell not ready.
	local saved_ready = NS.spell_ready
	NS.spell_ready = function() return false end
	assert_eq(lane.matches(ctx, state), false, spec.path .. " held while the spell is not ready")
	NS.spell_ready = saved_ready

	-- Hold: no target.
	local saved_target = ctx.target
	ctx.target = nil
	assert_eq(lane.matches(ctx, state), false, spec.path .. " held without a target")
	ctx.target = saved_target

	-- Hold: target not casting.
	NS.try_interrupt = function() return false end
	assert_eq(lane.matches(ctx, state), false, spec.path .. " held when the target is not casting")
	NS.try_interrupt = saved_ti

	-- Hold: use_interrupt opt-out.
	local opt_out = { settings = { use_interrupt = false, interrupt_humanize_enabled = false } }
	for k, v in pairs(ctx) do if k ~= "settings" then opt_out[k] = v end end
	assert_eq(lane.matches(opt_out, {}), false, spec.path .. " held when use_interrupt is false")

	-- Stance gates (manager `required` / ShieldBash wrapper).
	if spec.pummel then
		local battle = { is_sod = true, sod_phase = 8, target = target, me = me,
			in_combat = true, stance = 1, settings = INTERRUPT_SETTINGS }
		assert_eq(lane.matches(battle, {}), false, spec.path .. " Pummel held outside Berserker Stance")
	end
	if spec.shield_bash then
		local zerk = { is_sod = true, sod_phase = 8, target = target, me = me,
			in_combat = true, stance = 3, settings = INTERRUPT_SETTINGS }
		assert_eq(lane.matches(zerk, {}), false, spec.path .. " ShieldBash held in Berserker Stance")
		local battle = { is_sod = true, sod_phase = 8, target = target, me = me,
			in_combat = true, stance = 1, settings = INTERRUPT_SETTINGS }
		assert_eq(lane.matches(battle, {}), true, spec.path .. " ShieldBash fires in Battle Stance")
	end

	-- Execute drives NS.try_cast with the INNER action: identity against
	-- module.actions[<spell>].action plus the pinned head id.
	cast_action = nil
	assert_eq(lane.execute(ctx), true, spec.path .. " execute casts through NS.try_cast")
	assert_eq(cast_action, module.actions[spec.action].action, spec.path .. " execute passes the inner action")
	assert_eq(module.actions[spec.action].action._meta.id, spec.id, spec.path .. " pinned head id")
end

print("PASS test_sod_interrupt_lanes (12 wired specs; fire/hold/inert/identity/stance gates)")
