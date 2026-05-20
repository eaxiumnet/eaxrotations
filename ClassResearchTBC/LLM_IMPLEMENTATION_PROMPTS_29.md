# 29 LLM Implementation Prompts

Use one prompt per LLM session. Each prompt is scoped to one spec and is meant to improve `C:\newbot\scripts\EaxRotations` using the vetted `ClassResearchTBC` research.

## 1. Druid Balance

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Druid Balance

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Druid\Balance\Research.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\druid\balance_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\caster_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\schema_sylvanas.lua

Task:
Compare current Balance implementation to the Research.md contract and patch missing vetted behavior only. Focus on Starfire/Wrath filler choice, Moonfire/Insect Swarm refresh gates, mana conservation, Force of Nature, Innervate/Rebirth assignment, movement fallback, and target validity.

Hard rules:
- Do not hard-code the [VERIFY] SP breakpoint rows at 800/1000/1200 spell power. Make them configurable or leave as comments/TODOs only.
- No Eclipse, Starfall, Typhoon, Wild Growth, Berserk, Savage Roar, or other later-expansion mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 2. Druid Feral DPS

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Druid Feral DPS

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Druid\Feral-DPS\Research.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\druid\cat_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\schema_sylvanas.lua

Task:
Compare Cat/Feral DPS implementation to the Research.md contract and patch missing vetted behavior only. Focus on Mangle uptime before bleed spenders, Shred/Rip/Ferocious Bite priority, powershift gates, Clearcasting use, combo-point handling, target time-to-die, and movement/reopen logic.

Hard rules:
- Do not hard-code [VERIFY] AP/energy floors around 1500/2000/2500 AP. Keep these configurable.
- No Berserk [50334], Savage Roar, Cat Swipe, or later-expansion energy logic.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 3. Druid Bear Tank

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Druid Bear Tank

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Druid\Bear-Tank\Research.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\druid\bear_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\schema_sylvanas.lua

Task:
Compare Bear implementation to the Research.md contract and patch missing vetted behavior only. Focus on Mangle (Bear), Lacerate, Maul rage dump, Swipe target-count and CC gates, Demoralizing Roar, Faerie Fire (Feral), defensive cooldowns, threat, and form checks.

Hard rules:
- Do not hard-code runtime taunt/form-swap assumptions marked for Sylvanas validation.
- No Cat Swipe, Berserk, Savage Defense, Thrash, or later-expansion tank mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 4. Druid Restoration

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Druid Restoration

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Druid\Restoration\Research.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\druid\resto_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\healing_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\schema_sylvanas.lua

Task:
Compare Restoration implementation to the Research.md contract and patch missing vetted behavior only. Focus on Lifebloom bloom/refresh logic, Rejuvenation, Regrowth, Swiftmend, Nature's Swiftness, emergency triage, Clearcasting, decurse/utility, mana conservation, and target selection.

Hard rules:
- Nourish [50464] is DB2 absent. Do not implement it.
- No Wild Growth, Efflorescence, Tree modern behavior, or later-expansion healing mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 5. Hunter Beast Mastery

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Hunter Beast Mastery

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Hunter\Beast-Mastery\Research.md
- C:\newbot\scripts\ClassResearchTBC\Hunter\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Hunter\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\hunter\beast_mastery_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\cliptracker_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\schema_sylvanas.lua

Task:
Compare BM implementation to the Research.md contract and patch missing vetted behavior only. Focus on Steady Shot/Auto Shot weaving, Bestial Wrath, Kill Command, pet uptime, Rapid Fire, Aspect of the Hawk/Viper switching, mana floors, and target validity.

Hard rules:
- Aspect of the Viper [34074] is valid TBC and should be mana-recovery aspect logic, not modern on-hit restore.
- No Trap Launcher, Focus resource, Cobra Shot, Kill Shot, or later-expansion Hunter mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 6. Hunter Marksmanship

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Hunter Marksmanship

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Hunter\Marksmanship\Research.md
- C:\newbot\scripts\ClassResearchTBC\Hunter\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Hunter\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\hunter\marksmanship_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\cliptracker_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\schema_sylvanas.lua

Task:
Compare MM implementation to the Research.md contract and patch missing vetted behavior only. Focus on Auto Shot clipping prevention, Steady Shot timing, Aimed Shot, Multi-Shot, Arcane Shot, Rapid Fire, Trueshot Aura, Silencing Shot [34490], and Aspect of the Viper [34074].

Hard rules:
- Silencing Shot [34490] is valid TBC, 20s DB2 cooldown, 3s Wowhead silence. Gate by casting target and immunity.
- No Trap Launcher, Focus resource, Chimera Shot, Kill Shot, or later-expansion Hunter mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 7. Hunter Survival

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Hunter Survival

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Hunter\Survival\Research.md
- C:\newbot\scripts\ClassResearchTBC\Hunter\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Hunter\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\hunter\survival_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\cliptracker_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\schema_sylvanas.lua

Task:
Compare Survival implementation to the Research.md contract and patch missing vetted behavior only. Focus on Expose Weakness, Serpent Sting, Steady/Auto timing, valid traps, pet/target handling, mana floors, and Aspect of the Viper [34074].

Hard rules:
- Do not implement Survival Black Arrow. [19434] is Aimed Shot, not Survival Black Arrow.
- Explosive Shot [53209] and Trap Launcher [77769] are DB2 absent. Remove or block them.
- No Focus resource, Lock and Load, Cobra Shot, Kill Shot, or later-expansion Hunter mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 8. Mage Arcane

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Mage Arcane

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Mage\Arcane\Research.md
- C:\newbot\scripts\ClassResearchTBC\Mage\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Mage\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\mage\arcane_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\mage\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\mage\schema_sylvanas.lua

Task:
Compare Arcane implementation to the Research.md contract and patch missing vetted behavior only. Focus on Arcane Blast stack management, Arcane Missiles/filler fallback, mana gem/evocation timing, cooldowns, threat, movement, and conserve/burn phases.

Hard rules:
- Focus Magic [54646] is DB2 absent. Do not implement it.
- No Missile Barrage, Arcane Barrage, Rune of Power, or later-expansion Mage mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 9. Mage Fire

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Mage Fire

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Mage\Fire\Research.md
- C:\newbot\scripts\ClassResearchTBC\Mage\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Mage\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\mage\fire_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\mage\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\mage\schema_sylvanas.lua

Task:
Compare Fire implementation to the Research.md contract and patch missing vetted behavior only. Focus on Fireball, Scorch/Improved Scorch maintenance, Combustion, Ignite awareness, mana tools, AoE/CC gates, and movement fallback.

Hard rules:
- Living Bomb [44457] has no Mage class skillline entry in local TBC DB2. Do not implement it as a Mage rotation spell.
- No Hot Streak, Pyroblast proc logic, Dragon's Breath if not DB2/talent-validated, or later-expansion Mage mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 10. Mage Frost

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Mage Frost

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Mage\Frost\Research.md
- C:\newbot\scripts\ClassResearchTBC\Mage\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Mage\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\mage\frost_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\mage\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\mage\schema_sylvanas.lua

Task:
Compare Frost implementation to the Research.md contract and patch missing vetted behavior only. Focus on Frostbolt priority, Water Elemental if talented/valid, Icy Veins, Cold Snap, Shatter/Frostbite awareness, defensive Ice Block/Ice Barrier, and movement/CC gates.

Hard rules:
- Brain Freeze [44549] is DB2 absent. Do not implement it.
- No Deep Freeze, Frostfire Bolt, Fingers of Frost, or later-expansion Mage mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 11. Paladin Holy

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Paladin Holy

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Paladin\Holy\Research.md
- C:\newbot\scripts\ClassResearchTBC\Paladin\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Paladin\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\paladin\holy_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\healing_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\heal_helper_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\schema_sylvanas.lua

Task:
Compare Holy implementation to the Research.md contract and patch missing vetted behavior only. Focus on Holy Light/Flash of Light triage, Holy Shock, Divine Favor, Divine Illumination, Blessing of Light, Cleanse, aura/blessing support, mana conservation, and target selection.

Hard rules:
- Holy Light [27136] rank 11 is 2196-2446 base heal with 840 mana, not a fixed 2500 base heal.
- No Beacon of Light, Sacred Shield, Divine Plea, Holy Power resource, or modern Paladin healing mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 12. Paladin Protection

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Paladin Protection

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Paladin\Protection\Research.md
- C:\newbot\scripts\ClassResearchTBC\Paladin\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Paladin\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\paladin\protection_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\schema_sylvanas.lua

Task:
Compare Protection implementation to the Research.md contract and patch missing vetted behavior only. Focus on Righteous Fury, Holy Shield, Consecration, Judgement/Seal maintenance, Avenger's Shield, Exorcism on valid targets, threat, defensives, CC-safe AoE, and TBC mana recovery.

Hard rules:
- Mana recovery is TBC-only: Wisdom, Spiritual Attunement from healing taken, consumables, and encounter sources.
- No Divine Plea, Shield of the Righteous, Holy Power resource, or modern Paladin tank mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 13. Paladin Retribution

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Paladin Retribution

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Paladin\Retribution\Research.md
- C:\newbot\scripts\ClassResearchTBC\Paladin\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Paladin\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\paladin\retribution_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\paladin\schema_sylvanas.lua

Task:
Compare Ret implementation to the Research.md contract and patch missing vetted behavior only. Focus on Seal/Judgement cycle, Crusader Strike, Hammer of Wrath, Exorcism target gates, Consecration mana gates, Avenging Wrath, swing timing, and seal twisting where already supported.

Hard rules:
- Seal of Blood is [31892/31893]. Seal of the Martyr is [348700/348701], not the WotLK ID.
- Faction-gate Blood vs Martyr.
- No Divine Storm, Holy Power resource, Templar's Verdict, Inquisition, or modern Paladin mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 14. Priest Discipline

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Priest Discipline

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Priest\Discipline\Research.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\priest\discipline_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\healing_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\schema_sylvanas.lua

Task:
Compare Discipline implementation to the Research.md contract and patch missing vetted behavior only. Focus on Power Word: Shield with Weakened Soul gates, Flash Heal/Greater Heal triage, Prayer of Mending, Pain Suppression, Power Infusion, dispels, mana conservation, and target selection.

Hard rules:
- Penance [47540] and Rapture [47535] are DB2 absent. Do not implement them.
- No Atonement, Borrowed Time, modern absorbs, or Mind Sear.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 15. Priest Holy

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Priest Holy

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Priest\Holy\Research.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\priest\holy_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\healing_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\schema_sylvanas.lua

Task:
Compare Holy implementation to the Research.md contract and patch missing vetted behavior only. Focus on Flash Heal/Greater Heal triage, Renew, Prayer of Healing, Circle of Healing [34861], Lightwell [724], Prayer of Mending, Guardian Spirit guardrail, dispels, and mana conservation.

Hard rules:
- Guardian Spirit [47788] is DB2 absent. Do not implement it.
- Circle of Healing [34861] and Lightwell [724] are valid TBC Holy spells.
- No Chakra, Serendipity, modern Holy Words, or Mind Sear.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 16. Priest Shadow

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Priest Shadow

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Priest\Shadow\Research.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\priest\shadow_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\schema_sylvanas.lua

Task:
Compare Shadow implementation to the Research.md contract and patch missing vetted behavior only. Focus on Vampiric Touch, Shadow Word: Pain, Mind Blast, Mind Flay, Shadow Word: Death safety, Shadow Weaving, mana support, interrupts/silence if valid, and multi-dot target gating.

Hard rules:
- Dispersion [47585] is DB2 absent. Do not implement it.
- No Mind Sear, Devouring Plague for non-valid race/ruleset if not already supported, Shadow Orbs, or later-expansion Shadow mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 17. Priest Smite

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Priest Smite

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Priest\Smite\Research.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\priest\smite_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\schema_sylvanas.lua

Task:
Compare Smite implementation to the Research.md contract and patch missing vetted behavior only. Focus on Smite/Holy Fire priority, Shadow Word: Pain if documented, Inner Fire maintenance, Power Word: Shield safety, wand/mana fallback, emergency self-heal, and target validity.

Hard rules:
- Penance [47540] is DB2 absent. Do not implement it.
- No Atonement, Chakra, Mind Sear, or later-expansion Priest mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 18. Rogue Assassination

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Rogue Assassination

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Rogue\Assassination\Research.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\rogue\assassination_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\schema_sylvanas.lua

Task:
Compare Assassination implementation to the Research.md contract and patch missing vetted behavior only. Focus on Mutilate [34413] poison/behind gates, Slice and Dice, Rupture/Eviscerate, poisons, energy pooling, cooldowns, interrupts, and target immunity checks.

Hard rules:
- Mutilate [34413] is valid TBC and gains +50% damage against poisoned targets; it requires proper position/poison checks.
- No Envenom if not DB2/ruleset-validated, Fan of Knives, Vendetta, or later-expansion Rogue mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 19. Rogue Combat

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Rogue Combat

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Rogue\Combat\Research.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\rogue\combat_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\schema_sylvanas.lua

Task:
Compare Combat implementation to the Research.md contract and patch missing vetted behavior only. Focus on Slice and Dice uptime, Sinister Strike, Rupture/Eviscerate, Adrenaline Rush, Blade Flurry [13877], poisons, energy pooling, interrupts, and target-count/CC-safe cleave.

Hard rules:
- Blade Flurry [13877] is valid TBC: +20% melee attack speed, additional nearby target, 15s duration, 2m cooldown.
- No Killing Spree, Fan of Knives, Bandit's Guile, or later-expansion Rogue mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 20. Rogue Subtlety

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Rogue Subtlety

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Rogue\Subtlety\Research.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\rogue\subtlety_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\schema_sylvanas.lua

Task:
Compare Subtlety implementation to the Research.md contract and patch missing vetted behavior only. Focus on Hemorrhage [26864] debuff maintenance, Slice and Dice, Rupture/Eviscerate, stealth/openers, cooldowns, energy pooling, interrupts, and target bleed/physical vulnerability checks.

Hard rules:
- Hemorrhage [26864] is valid TBC: 35 energy, 15s debuff, 10 charges, +42 physical damage taken at max rank.
- No Shadow Dance, Fan of Knives, Honor Among Thieves, or later-expansion Rogue mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 21. Shaman Elemental

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Shaman Elemental

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Shaman\Elemental\Research.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\shaman\elemental_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\schema_sylvanas.lua

Task:
Compare Elemental implementation to the Research.md contract and patch missing vetted behavior only. Focus on Lightning Bolt, Chain Lightning [25442], Flame Shock refresh, Earth Shock interrupts, Elemental Mastery, totems, mana floors, target validity, and AoE target thresholds.

Hard rules:
- Chain Lightning [25442] has 3 total targets and 0.70 jump amplitude; keep any cluster-radius heuristic configurable.
- No Lava Burst, Thunderstorm, Hex, Wind Shear, or later-expansion Shaman mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 22. Shaman Enhancement

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Shaman Enhancement

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Shaman\Enhancement\Research.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\shaman\enhancement_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\schema_sylvanas.lua

Task:
Compare Enhancement implementation to the Research.md contract and patch missing vetted behavior only. Focus on Stormstrike, shocks, Shamanistic Rage [30823], weapon imbues, Windfury/Grace of Air totems, totem twisting, mana, target validity, and melee uptime.

Hard rules:
- Grace of Air Totem [10627] is rank 2; max TBC rank is [25359]. Resolve ranks [8835/10627/25359].
- No Feral Spirit, Maelstrom Weapon, Lava Lash, Wind Shear, Lava Burst, or later-expansion Shaman mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 23. Shaman Restoration

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Shaman Restoration

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Shaman\Restoration\Research.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\shaman\restoration_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\healing_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\schema_sylvanas.lua

Task:
Compare Restoration implementation to the Research.md contract and patch missing vetted behavior only. Focus on Chain Heal bounce logic, Earth Shield, Water Shield, Lesser Healing Wave [25420], Healing Wave ranks, Nature's Swiftness [16188] emergency path, Earth Shock [25454] interrupt logic, totems, and mana conservation.

Hard rules:
- Nature's Swiftness [16188], Lesser Healing Wave [25420], Chain Heal, Earth Shield, and Earth Shock [25454] are valid TBC tools.
- No Riptide, Wind Shear, Lava Burst, Hex, or modern instant-heal mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 24. Warlock Affliction

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Warlock Affliction

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Warlock\Affliction\Research.md
- C:\newbot\scripts\ClassResearchTBC\Warlock\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Warlock\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\warlock\affliction_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warlock\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warlock\schema_sylvanas.lua

Task:
Compare Affliction implementation to the Research.md contract and patch missing vetted behavior only. Focus on Unstable Affliction, Corruption, Curse assignment, Siphon Life, Immolate if documented, Shadow Bolt filler, Life Tap, pet state, and non-clipping DoT refresh rules.

Hard rules:
- Unstable Affliction max rank is [30405]. Use rank list [30108/30404/30405/31117]. Do not use the Shadowfury ID as UA.
- No Demonic Empowerment, Metamorphosis, Demon Soul, Soul Swap, Haunt, or later-expansion Warlock mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 25. Warlock Demonology

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Warlock Demonology

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Warlock\Demonology\Research.md
- C:\newbot\scripts\ClassResearchTBC\Warlock\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Warlock\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\warlock\demonology_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warlock\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warlock\schema_sylvanas.lua

Task:
Compare Demonology implementation to the Research.md contract and patch missing vetted behavior only. Focus on Felguard [30146] uptime, pet management, Shadow Bolt/DoT priority, curses, Life Tap, trinkets/cooldowns, and defensive utility.

Hard rules:
- Demonic Empowerment [47193], Metamorphosis [47241], Demon Soul [77801], Demonic Pact [47236], and Fel Intelligence [54424] are DB2 absent. Do not implement them.
- No Molten Core, Hand of Gul'dan, or later-expansion Warlock mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 26. Warlock Destruction

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Warlock Destruction

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Warlock\Destruction\Research.md
- C:\newbot\scripts\ClassResearchTBC\Warlock\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Warlock\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\warlock\destruction_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warlock\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warlock\schema_sylvanas.lua

Task:
Compare Destruction implementation to the Research.md contract and patch missing vetted behavior only. Focus on Shadow Bolt/Incinerate priority, Immolate before Conflagrate, Shadowburn, curses, Life Tap, pet state, mana tools, and target validity.

Hard rules:
- Chaos Bolt [50796] and Backdraft [54274] are DB2 absent. Do not implement them.
- No Havoc, Ember resource, Soul Fire modern procs, or later-expansion Warlock mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 27. Warrior Arms

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Warrior Arms

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Warrior\Arms\Research.md
- C:\newbot\scripts\ClassResearchTBC\Warrior\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Warrior\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\warrior\arms_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warrior\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warrior\schema_sylvanas.lua

Task:
Compare Arms implementation to the Research.md contract and patch missing vetted behavior only. Focus on Mortal Strike, Slam timing after swing, Whirlwind, Execute, rage pooling, Hamstring/Overpower if supported, Battle/Commanding Shout, interrupts, stance checks, and target validity.

Hard rules:
- Commanding Shout [469] is valid TBC. Gate by learned spell and raid assignment.
- No Bladestorm, Heroic Throw, Taste for Blood, Colossus Smash, or later-expansion Warrior mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 28. Warrior Fury

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Warrior Fury

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Warrior\Fury\Research.md
- C:\newbot\scripts\ClassResearchTBC\Warrior\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Warrior\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\warrior\fury_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warrior\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warrior\schema_sylvanas.lua

Task:
Compare Fury implementation to the Research.md contract and patch missing vetted behavior only. Focus on Bloodthirst, Whirlwind, Rampage, Heroic Strike/Cleave rage dump, Execute, Death Wish/Recklessness, shouts, rage pooling, and dual-wield threat/rage gates.

Hard rules:
- Rampage cast ranks are [29801/30030/30033]. Use [30033] at level 70 when learned and maintain 5-stack when talented/available.
- Commanding Shout [469] is valid TBC. Gate by learned spell and raid assignment.
- No Titan's Grip, Heroic Throw, Bloodsurge, Raging Blow, or later-expansion Warrior mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```

## 29. Warrior Protection

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Warrior Protection

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Warrior\Protection\Research.md
- C:\newbot\scripts\ClassResearchTBC\Warrior\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Warrior\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\warrior\protection_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warrior\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warrior\schema_sylvanas.lua

Task:
Compare Protection implementation to the Research.md contract and patch missing vetted behavior only. Focus on Shield Slam, Revenge, Devastate/Sunder, Shield Block uptime, Thunder Clap, Demoralizing Shout, Heroic Strike rage dump, taunt/interrupts, defensives, stance checks, and threat.

Hard rules:
- Commanding Shout [469] is valid TBC. Gate by learned spell and raid assignment.
- No Shockwave, Sword and Board proc, Heroic Throw, Devastator, Ignore Pain, or later-expansion Warrior mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\<Class>_<Spec>_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```




