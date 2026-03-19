# PITFALLS - Common Mistakes

## Critical Pitfalls

### 1. DoT Clipping
**What it is**: Refreshing a DoT before its final tick. You lose the last tick's damage.

**Example**: Casting Corruption when Corruption has 2 seconds left — you get a new 12-second DoT but lose 2 seconds of damage.

**Prevention**: Track remaining duration. Only recast when remaining < cast time.

```lua
-- Wrong
if not utils.has_debuff(target, spells.CORRUPTION) then
    utils.cast_target(corruption_id, target)
end

-- Right
local remaining = utils.get_debuff_remaining_ms(target, spells.CORRUPTION)
local cast_time = core.spell_book.get_spell_cast_time(corruption_id) * 1000
if remaining < cast_time then
    utils.cast_target(corruption_id, target)
end
```

**Affected specs**: Affliction Lock, Shadow Priest, Balance Druid, Feral Druid, Destruction Lock (Immolate)

### 2. Slam Clip / Swing Timer Desync
**What it is**: Casting Slam too early, delaying the next auto-attack, net DPS loss.

**Prevention**: Check swing timer before Slam. Allow configurable safety buffer.

**Affected specs**: Arms Warrior, Fury Warrior

### 3. Auto Shot Clip (Hunters)
**What it is**: Casting a spell that delays the next auto shot, losing ranged attacks.

**Prevention**: Track next auto shot time. Only cast if spell fits before next auto.

**Affected specs**: Beast Mastery, Marksmanship, Survival

### 4. Hardcoded Set Bonuses
**What it is**: Only 3 sets hardcoded (Warbringer, WarbringerBattlegear, Ymirjar). All other T4/T5/T6 ignored.

**Prevention**: Dynamic gear scanning. Check every equipped item against all known set item IDs.

**Impact**: DPS undercounted by 5-10% for most players wearing tier gear.

### 5. Interrupt on Almost-Complete Casts
**What it is**: Interrupting a target's cast when it has <0.2s remaining — wasted interrupt, spell goes off anyway.

**Prevention**: Add minimum cast time remaining check before interrupt.

```lua
if cast_time_remaining < 200 then return false end  -- Let it finish
```

### 6. Threat Death Spiral
**What it is**: Rotation pulls threat, mob turns and kills the bot.

**Prevention**: No current threat tracking. Add threat estimation:
- Track estimated DPS
- Calculate time until threat would exceed tank
- Use Fade/Shield Wall/Feign Death if close

**Affected specs**: All DPS specs, especially Warlocks (high burst)

### 7. OOM Mid-Combat
**What it is**: Running out of mana before encounter ends.

**Prevention**: 
- Track mana burn rate vs encounter duration
- Pre-pull innervate from Druid
- Use mana potions proactively
- Evocation timing (Arcane Mage)

**Affected specs**: All mana-using casters

### 8. Missing Shaman Totems
**What it is**: Totem spells fail silently because player doesn't have totem items in bag.

**Prevention**: Check bag for totem items before casting. Use `core.input.use_item()` for physical totem placement.

**Affected specs**: All Shaman specs

### 9. GCD Overlap
**What it is**: Two spells queued within GCD window, one fails.

**Prevention**: `spell_queue` system handles this, but fast-cast path (`cast_target_fast`) bypasses it. Be careful with fast-path usage.

**Affected specs**: All

### 10. Talent Detection Gaps
**What it is**: Assuming a spell exists when the player hasn't specced into it.

**Prevention**: `resolve_spell_id` returns nil for unlearned spells. Always check return value before casting.

**Status**: Already handled in current codebase via spell resolution.

## Phase Mapping

| Pitfall | Phase |
|---------|-------|
| Shared module extraction | Foundation |
| DoT clip prevention | Rotation tuning |
| Swing timer optimization | Rotation tuning |
| Dynamic set bonus scanner | Critical missing |
| Interrupt refinement | Interrupt tuning |
| Threat management | Survival polish |
| DPS meter | Benchmarking |
| Consumables automation | Polish |
