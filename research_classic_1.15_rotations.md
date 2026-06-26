# WoW Classic Anniversary (1.15.x) Rotation Research — Batch 2

> Research date: 2026-06-26
> Sources: IcyVeins, WarcraftTavern, WoWHead, NoobToBoss, Millenium, WoWTBC.gg

---

## Hunter — Beast Mastery (Vanilla)

### Single-Target Priority
1. **Hunter's Mark** (if not applied)
2. **Serpent Sting** (keep up)
3. **Arcane Shot** (on cooldown)
4. **Multi-Shot** (careful — clips auto-shot, use at end of swing timer)
5. **Auto Shot** (primary damage source)

### Key Mechanics
- Pet does ~30-40% of total DPS — **keep pet alive**
- Mend Pet when pet HP < 50%
- No Steady Shot (TBC 62+), no Kill Command (TBC)
- No Bestial Wrath in Vanilla (TBC 31pt talent)
- Melee weave: Raptor Strike when in melee range

### AoE
- Multi-Shot (2 targets)
- Volley (3+ targets, channeled)

### Our File Check
- `beast_mastery_vanilla.lua`: Has Pattern 15 header ✓
- Removed TBC dead code (Steady Shot, Kill Command, Misdirection) ✓
- Features: Mend Pet, Hunter's Mark, Serpent Sting, Arcane Shot, Multi-Shot, Raptor Strike ✓

---

## Hunter — Marksmanship (Vanilla)

### Single-Target Priority
1. **Hunter's Mark**
2. **Serpent Sting** (keep up)
3. **Aimed Shot** (primary nuke, 3s cast)
4. **Multi-Shot** (on CD, careful with auto-clip)
5. **Arcane Shot** (filler)
6. **Auto Shot**

### Key Mechanics
- Aimed Shot resets auto-shot timer — cast immediately after auto-shot fires
- No Steady Shot (TBC-only)
- No Bestial Wrath (TBC-only)
- Trueshot Aura (MM 31pt) — party-wide AP buff

### Our File Check
- `marksmanship_vanilla.lua`: Removed BestialWrath dead code ✓
- Has Aimed Shot, Multi-Shot, Arcane Shot ✓
- Needs: Trueshot Aura maintenance strategy

---

## Hunter — Survival (Vanilla)

### Single-Target Priority
1. **Hunter's Mark**
2. **Serpent Sting**
3. **Aimed Shot** (if specced)
4. **Multi-Shot**
5. **Arcane Shot**
6. **Auto Shot**

### Survival-Specific
- Melee weave: Raptor Strike + Wing Clip kiting
- Explosive Trap (AoE)
- Immolation Trap (single-target DoT)
- Concussive Shot for kiting
- No Aspect of the Viper (TBC-only)

### Our File Check
- `survival_vanilla.lua`: Removed Viper, Steady Shot, Kill Command, Misdirection ✓
- Has Raptor Strike, Wing Clip, Concussive Shot, Explosive Trap ✓

---

## Mage — Arcane (Vanilla)

### Single-Target Priority
1. **Arcane Power** (cooldown, +30% damage)
2. **Presence of Mind** (instant spell)
3. **Arcane Missiles** (if Clearcast procs — free)
4. **Frostbolt** (primary filler when no Clearcast)
5. **Fire Blast** (while moving only)

### Key Mechanics
- Arcane in Vanilla = Arcane Power Frost hybrid
- No Arcane Blast (TBC-only)
- Clearcasting (Arcane Concentration) procs = free next spell
- PoM + Pyroblast opener in PvP; PoM + Frostbolt in PvE

### Our File Check
- `arcane_vanilla.lua`: Fixed — Frostbolt is primary, Fire Blast only while moving ✓
- Has Arcane Power, Presence of Mind, Arcane Missiles, Frostbolt ✓

---

## Mage — Fire (Vanilla)

### Single-Target Priority
1. **Combustion** (cooldown, stacks crit chance)
2. **Scorch** (stack 5× for Ignite — if no other fire mage)
3. **Fireball** (primary nuke)
4. **Fire Blast** (while moving / instant)
5. **Pyroblast** (PoM instant only)

### Key Mechanics
- Ignite: crits leave a DoT that stacks to 5
- Scorch debuff: +15% fire crit chance at 5 stacks
- Living Bomb? **Wrath-only** (not in Classic Era)
- Dragon's Breath? **TBC-only**
- Fireball is primary nuke, NOT Scorch spam

### Our File Check
- `fire_vanilla.lua`: Has Combustion, Scorch, Fireball, Fire Blast ✓
- Verify: Scorch maintenance for Ignite stacks (5×)
- Verify: No Living Bomb / Dragon's Breath references

---

## Mage — Frost (Vanilla)

### Single-Target Priority
1. **Summon Water Elemental** (if available — TBC backported? VERIFY)
2. **Icy Veins** (cooldown, TBC backported? VERIFY)
3. **Frostbolt** (primary nuke, 95% of casts)
4. **Ice Lance** (on frozen target only)
5. **Fire Blast** (while moving)

### Key Mechanics
- Frostbolt is THE spell — 90%+ of casts
- Shatter combo: Frost Nova → Ice Lance (if frozen)
- Ice Barrier for defense
- Cold Snap resets Ice Block
- **Water Elemental**: TBC talent (50pt), NOT in Classic 1.15 unless backported
- **Ice Lance**: TBC spell (30455), check if backported to 1.15

### Our File Check
- `frost_vanilla.lua`: Removed Water Elemental and Ice Lance dead code ✓
- Has Frostbolt, Cone of Cold, Frost Nova, Blizzard, Ice Barrier, Ice Block ✓
- Verify against DBC: Are Water Elemental / Ice Lance in Classic Era client?

---

## Action Items

| Spec | Priority | Action |
|------|----------|--------|
| Hunter MM Vanilla | Low | Add Trueshot Aura maintenance strategy |
| Hunter BM Vanilla | Low | Verify pet commands (Attack/Passive/Defensive) |
| Mage Fire Vanilla | Medium | Verify Scorch stacks to 5 for Ignite |
| Mage Frost Vanilla | Medium | DBC-verify if Water Elemental / Ice Lance exist in 1.15 |

## DBC Verification Needed

Run Classic Era spell audit to check:
- `31687` — Summon Water Elemental (TBC 50pt talent)
- `30455` — Ice Lance (TBC spell)
- `12472` — Icy Veins (TBC 24pt Frost talent)

If present in `wowsims_classic_era.db`, they were backported and should be restored.
