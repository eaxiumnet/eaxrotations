--- resource_gate.lua
-- Class-aware resource check helpers for TBC rotations
-- Provides thin wrappers around combat_context to answer "can we even try this cast?"

local resource_gate = {}

resource_gate.common  = {}
resource_gate.rogue   = {}
resource_gate.warrior = {}
resource_gate.hunter  = {}
resource_gate.feral   = {}
resource_gate.shaman  = {}

-- ============================================================================
-- ROGUE HELPERS
-- ============================================================================

function resource_gate.rogue.can_builder(ctx, energy_cost, combo_points, max_cp)
    -- ctx: simplified context with self.energy, self.combo_points
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local energy = ctx.self.energy or 0
    local cp = ctx.self.combo_points or 0

    -- Builder needs energy AND shouldn't be at max combo points
    if energy < energy_cost then
        return false, "not enough energy"
    end

    if max_cp and cp >= max_cp then
        return false, "at max combo points"
    end

    return true, "ok"
end

function resource_gate.rogue.can_finisher(ctx, energy_cost, combo_points, min_cp)
    -- ctx: simplified context with self.energy, self.combo_points
    if not ctx or not ctx.self then
        return false, "not enough energy"
    end

    local energy = ctx.self.energy or 0
    local cp = ctx.self.combo_points or 0

    -- Finisher needs energy AND minimum combo points
    if energy < energy_cost then
        return false, "not enough energy"
    end

    if cp < min_cp then
        return false, "not enough combo points"
    end

    return true, "ok"
end

function resource_gate.rogue.target_has_combo_points(ctx, target_guid)
    -- For TBC, combo points must be ON the current target
    -- Context already validates this via combo_target_guid tracking
    if not ctx or not ctx.self then
        return false
    end

    local cp = ctx.self.combo_points or 0
    return cp > 0
end

function resource_gate.rogue.has_buff(ctx, buff_name)
    if not ctx or not ctx.self or not ctx.self.buffs then
        return false
    end
    return ctx.self.buffs[buff_name] == true
end

-- ============================================================================
-- WARRIOR HELPERS
-- ============================================================================

function resource_gate.warrior.has_rage(ctx, min_rage)
    -- ctx: simplified context with self.rage
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local rage = ctx.self.rage or 0

    if rage < min_rage then
        return false, "not enough rage"
    end

    return true, "ok"
end

function resource_gate.warrior.can_queue_dump(ctx, min_rage, cap_rage)
    -- For abilities like Heroic Strike that queue but should not fire at high rage
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local rage = ctx.self.rage or 0

    if rage < min_rage then
        return false, "not enough rage"
    end

    if cap_rage and rage >= cap_rage then
        return false, "at rage cap, don't queue dump"
    end

    return true, "ok"
end

function resource_gate.warrior.has_buff(ctx, buff_name)
    if not ctx or not ctx.self or not ctx.self.buffs then
        return false
    end
    return ctx.self.buffs[buff_name] == true
end

function resource_gate.warrior.has_proc(ctx, proc_name)
    if not ctx or not ctx.self or not ctx.self.procs then
        return false
    end
    return ctx.self.procs[proc_name] == true
end

-- ============================================================================
-- HUNTER HELPERS (TBC uses MANA, not focus)
-- ============================================================================

function resource_gate.hunter.has_mana_pct(ctx, min_pct)
    -- ctx: simplified context with self.mana_pct
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local mana_pct = ctx.self.mana_pct or 0

    if mana_pct < min_pct then
        return false, "not enough mana"
    end

    return true, "ok"
end

function resource_gate.hunter.has_mana_current(ctx, min_mana)
    -- For abilities with specific mana costs
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local mana_current = ctx.self.mana_current or 0

    if mana_current < min_mana then
        return false, "not enough mana"
    end

    return true, "ok"
end

function resource_gate.hunter.has_buff(ctx, buff_name)
    if not ctx or not ctx.self or not ctx.self.buffs then
        return false
    end
    return ctx.self.buffs[buff_name] == true
end

-- ============================================================================
-- SHAMAN HELPERS (Enhancement uses mana in TBC)
-- ============================================================================

function resource_gate.shaman.has_mana_pct(ctx, min_pct)
    -- ctx: simplified context with self.mana_pct
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local mana_pct = ctx.self.mana_pct or 0

    if mana_pct < min_pct then
        return false, "not enough mana"
    end

    return true, "ok"
end

function resource_gate.shaman.has_buff(ctx, buff_name)
    if not ctx or not ctx.self or not ctx.self.buffs then
        return false
    end
    return ctx.self.buffs[buff_name] == true
end

-- ============================================================================
-- DRUID FERAL HELPERS
-- ============================================================================

function resource_gate.feral.can_cat_builder(ctx, energy_cost, combo_points, max_cp)
    -- Cat builder needs energy AND shouldn't be at max combo points
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local energy = ctx.self.energy or 0
    local cp = ctx.self.combo_points or 0

    if energy < energy_cost then
        return false, "not enough energy"
    end

    if max_cp and cp >= max_cp then
        return false, "at max combo points"
    end

    return true, "ok"
end

function resource_gate.feral.can_cat_finisher(ctx, energy_cost, combo_points, min_cp)
    -- Cat finisher needs energy AND minimum combo points
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local energy = ctx.self.energy or 0
    local cp = ctx.self.combo_points or 0

    if energy < energy_cost then
        return false, "not enough energy"
    end

    if cp < min_cp then
        return false, "not enough combo points"
    end

    return true, "ok"
end

function resource_gate.feral.has_bear_rage(ctx, min_rage)
    -- Bear form uses rage
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local rage = ctx.self.rage or 0

    if rage < min_rage then
        return false, "not enough rage"
    end

    return true, "ok"
end

function resource_gate.feral.has_buff(ctx, buff_name)
    if not ctx or not ctx.self or not ctx.self.buffs then
        return false
    end
    return ctx.self.buffs[buff_name] == true
end

-- ============================================================================
-- COMMON HELPERS (all classes)
-- ============================================================================

function resource_gate.common.has_self_buff(ctx, buff_name)
    if not ctx or not ctx.self or not ctx.self.buffs then
        return false
    end
    return ctx.self.buffs[buff_name] == true
end

function resource_gate.common.has_mana_pct(ctx, min_pct)
    if not ctx or not ctx.self then
        return false, "no context"
    end

    local mana_pct = ctx.self.mana_pct or 0

    if mana_pct < min_pct then
        return false, "not enough mana"
    end

    return true, "ok"
end

function resource_gate.common.has_target_debuff(ctx, debuff_name)
    if not ctx or not ctx.target or not ctx.target.debuffs then
        return false
    end
    return ctx.target.debuffs[debuff_name] == true
end

function resource_gate.common.party_has_heroism(ctx)
    -- Returns true if party has Bloodlust/Heroism
    if not ctx or not ctx.party then
        return false
    end
    return ctx.party.has_bloodlust == true or ctx.party.has_heroism == true
end

function resource_gate.common.target_alive(ctx)
    if not ctx or not ctx.target then
        return false
    end
    return ctx.target.exists == true and ctx.target.hp_pct > 0
end

function resource_gate.common.target_hp_pct(ctx)
    if not ctx or not ctx.target then
        return nil
    end
    return ctx.target.hp_pct
end

return resource_gate
