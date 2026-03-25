# EAX TBC Hunter Rotations

## Customer Overview

This package currently includes three Hunter rotations for **WoW TBC Classic** on **Project Sylvanas**:

- **Hunter Beast Mastery**
- **Hunter Marksmanship**
- **Hunter Survival**

These profiles are built to be:

- **TBC-focused**
- **Sylvanas compliant**
- **Menu-driven**
- **Safe to use while leveling and at endgame**

---

## Current Readiness

**Status:** `Ready with caveats`

That means:

- The rotations are usable now
- Core combat behavior is in place
- Leveling characters should not hang just because a spell or talent is not learned
- There are still some edge cases and polish opportunities, especially in advanced utility behavior

---

## Leveling Safety (1-70)

**Yes — these rotations are generally level safe.**

What that means in practice:

- Unlearned spells are usually resolved safely
- Missing talents should not hard-break the rotation
- If a spell is not available yet, the profile normally skips it and continues
- Pet recovery, basic aspects, and core shot logic are protected well enough for normal leveling use

### Leveling caveat

The main known leveling caveat is:

- **aspect recovery can sometimes no-op quietly if the expected aspect rank is not learned yet**

That is usually not a hard failure. It just means the Hunter may occasionally stay in the wrong aspect until a new decision or manual correction happens.

---

## What The Hunter Rotations Can Do

## Beast Mastery

- Pet-focused TBC ranged rotation
- Handles **Kill Command** and pet-assisted damage timing
- Uses **Steady Shot** filler logic
- Supports **Mend Pet**
- Supports **Call Pet / Revive Pet** recovery
- Supports travel and combat aspects:
  - Hawk
  - Viper
  - Monkey
  - Cheetah
  - optional Pack
- Supports optional utility:
  - Deterrence
  - Scare Beast
  - Flare
- Supports anti-stealth helpers:
  - warning popup
  - predictive stealth overlay
  - auto anti-stealth Flare attempt
- Pet autocast sync can help keep **Growl disabled in groups**

## Marksmanship

- TBC Marksmanship ranged priority
- Uses **Aimed Shot**, **Steady Shot**, and **Multi-Shot** logic
- Uses pet support where appropriate
- Supports **Call Pet / Revive Pet** recovery
- Supports travel and combat aspects:
  - Hawk
  - Viper
  - Cheetah
  - optional Pack
- Supports optional utility:
  - Deterrence
  - Scare Beast
  - Flare
- Supports anti-stealth helpers:
  - warning popup
  - predictive stealth overlay
  - auto anti-stealth Flare attempt
- Pet autocast sync can help keep **Growl disabled in groups**

## Survival

- TBC Survival ranged rotation
- Supports:
  - Hunter's Mark
  - Serpent Sting
  - Aimed Shot
  - Arcane Shot
  - Multi-Shot
  - Steady Shot
- Supports trap usage and utility-focused ranged play
- Supports **Call Pet / Revive Pet** recovery
- Supports travel and combat aspects:
  - Hawk
  - Viper
  - Cheetah
  - optional Pack
- Supports optional utility:
  - Deterrence
  - Scare Beast
  - Wyvern Sting
  - Flare
- Supports anti-stealth helpers:
  - warning popup
  - predictive stealth overlay
  - auto anti-stealth Flare attempt
- Pet autocast sync can help keep **Growl disabled in groups**

---

## What The Hunter Rotations Cannot Guarantee

These rotations are strong, but there are limits.

### Anti-stealth is best-effort, not magical detection

The anti-stealth system can:

- warn when stealth is likely nearby
- track last known position
- estimate direction and speed
- draw a predictive uncertainty area
- attempt Flare into that area

It **cannot guarantee exact enemy position** after stealth.

If the runtime no longer exposes the target properly once it vanishes, the system has to rely on:

- last seen position
- last seen velocity
- movement direction
- Sprint / Dash style bias

So it is **prediction**, not true invisibility reading.

### Aspect handling is good, but not perfect at low levels

- Travel aspects work
- Combat aspects work
- Low-level rank progression is broadly safe
- But aspect recovery can still occasionally be imperfect on partially learned kits

### Utility is optional by design

Some utility tools are intentionally conservative or disabled by default, such as:

- Scare Beast
- Wyvern Sting
- Flare automation
- anti-stealth overlay extras

This is to avoid over-triggering in normal play.

---

## Anti-Stealth Feature Summary

The Hunter profiles now support a best-effort anti-stealth system with:

- **Stealth Warning**
- **Auto Anti-Stealth Flare**
- **Stealth Overlay**
- **Stealth Direction**
- configurable **Stealth Radius**
- configurable **Stealth Prediction**

What it tries to do:

1. detect nearby stealth-capable enemies
2. capture their last visible movement snapshot
3. estimate where they are likely moving
4. draw a predictive area
5. cast Flare into that area

This works best when:

- the stealthed unit was visible just before stealth
- movement direction was clear
- the unit used obvious movement like Sprint or Dash

---

## Recommended Customer Expectation

These Hunter rotations should be treated as:

- **good to use now**
- **safe enough for normal leveling and endgame use**
- **strong on core TBC combat**
- **stronger than average on pet handling and stealth utility**
- **still open to refinement in advanced edge cases**

If you want the simplest honest description:

> These Hunter profiles are ready for use, safe for normal progression, and already include advanced utility features like pet recovery, travel aspects, and anti-stealth prediction — but the anti-stealth system is still best-effort rather than perfect enemy tracking.

---

## Suggested Customer-Facing Summary

```md
# EAX TBC Hunter Rotations

Includes:
- Beast Mastery
- Marksmanship
- Survival

## What it does
- Runs TBC-focused Hunter combat priorities
- Supports pet recovery (Call Pet / Revive Pet)
- Supports travel and combat aspects
- Supports optional utility like Deterrence, Scare Beast, Wyvern Sting, and Flare
- Includes anti-stealth warning + prediction + Flare support
- Safe enough for leveling and endgame use

## Leveling safety
- Yes, generally safe from 1-70
- Missing or unlearned spells are normally skipped safely
- No obvious hard hangs expected from incomplete spellbooks

## What it cannot guarantee
- Anti-stealth is prediction-based, not perfect true detection
- Some low-level aspect behavior can still be imperfect until more skills are learned
- Advanced utility features are best-effort and may need tuning for edge cases

## Current state
- Ready with caveats
- Good for customers now
- Still being refined toward a top-tier final state
```
