# Enums | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/enums

## Overview

👨‍💻 Lua Scripting API
Enums

### Overview​

The enums module provides a comprehensive collection of enumeration constants used throughout the API. These constants help make your code more readable and maintainable by replacing magic numbers with meaningful names.

### Importing The Module​

```
---@type enumslocal enums = require("common/enums")
```

IZI SDK Shorthand
If you're using the IZI SDK, you can access enums directly:

```
local izi = require("common/izi_sdk")local enums = izi.enums
```

#### class_id​

Constants for identifying player classes.

ConstantValueDescriptionANY0Matches any classWARRIOR1WarriorPALADIN2PaladinHUNTER3HunterROGUE4RoguePRIEST5PriestDEATHKNIGHT6Death KnightSHAMAN7ShamanMAGE8MageWARLOCK9WarlockMONK10MonkDRUID11DruidDEMONHUNTER12Demon HunterEVOKER13Evoker
Example Usage

```
local enums = require("common/enums")local me = core.object_manager.get_local_player()if me:get_class() == enums.class_id.PALADIN then    -- Paladin-specific logicend
```

#### class_id_to_name​

Lookup table to convert class IDs to their string names.

Example Usage

```
local class_name = enums.class_id_to_name[enums.class_id.WARRIOR]-- class_name = "WARRIOR"
```

#### spec_enum​

Constants for identifying specific class specializations.

Warrior

ConstantDescriptionARMS_WARRIORArmsFURY_WARRIORFuryPROTECTION_WARRIORProtection
Paladin

ConstantDescriptionHOLY_PALADINHolyPROTECTION_PALADINProtectionRETRIBUTION_PALADINRetribution
Hunter

ConstantDescriptionBEAST_MASTERY_HUNTERBeast MasteryMARKSMANSHIP_HUNTERMarksmanshipSURVIVAL_HUNTERSurvival
Rogue

ConstantDescriptionASSASSINATION_ROGUEAssassinationOUTLAW_ROGUEOutlawSUBTLETY_ROGUESubtlety
Priest

ConstantDescriptionDISCIPLINE_PRIESTDisciplineHOLY_PRIESTHolySHADOW_PRIESTShadow
Death Knight

ConstantDescriptionBLOOD_DEATHKNIGHTBloodFROST_DEATHKNIGHTFrostUNHOLY_DEATHKNIGHTUnholy
Shaman

ConstantDescriptionELEMENTAL_SHAMANElementalENHANCEMENT_SHAMANEnhancementRESTORATION_SHAMANRestoration
Mage

ConstantDescriptionARCANE_MAGEArcaneFIRE_MAGEFireFROST_MAGEFrost
Warlock

ConstantDescriptionAFFLICTION_WARLOCKAfflictionDEMONOLOGY_WARLOCKDemonologyDESTRUCTION_WARLOCKDestruction
Monk

ConstantDescriptionBREWMASTER_MONKBrewmasterMISTWEAVER_MONKMistweaverWINDWALKER_MONKWindwalker
Druid

ConstantDescriptionBALANCE_DRUIDBalanceFERAL_DRUIDFeralGUARDIAN_DRUIDGuardianRESTORATION_DRUIDRestoration
Demon Hunter

ConstantDescriptionHAVOC_DEMON_HUNTERHavocVENGEANCE_DEMON_HUNTERVengeance
Evoker

ConstantDescriptionEVOKER_DEVASTATIONDevastationEVOKER_PRESERVATIONPreservationEVOKER_AUGMENTATIONAugmentation
Example Usage

```
local spec = enums.class_spec_id.spec_enumif player_spec == spec.FROST_MAGE then    -- Frost Mage specific logicend
```

#### class_spec_id​

Helper functions for working with class and specialization IDs.

Methods

MethodDescriptionget_specialization_name(class_id, spec_id)Returns the spec name as a stringget_specialization_enum(class_id, spec_id)Returns the spec_enum valueget_spec_id_from_enum(spec_enum)Converts spec_enum back to numeric ID
Example Usage

```
local me = core.object_manager.get_local_player()local class_id = me:get_class()local spec_id = me:get_spec()local spec_name = enums.class_spec_id.get_specialization_name(class_id, spec_id)core.log("Playing as: " .. spec_name)
```

#### power_type​

Constants for identifying unit power/resource types.

ConstantValueDescriptionHEALTH-2Health (special)NONE-1No power typeMANA0ManaRAGE1RageFOCUS2FocusENERGY3EnergyCOMBOPOINTS4Combo PointsRUNES5RunesRUNICPOWER6Runic PowerSOULSHARDS7Soul ShardsLUNARPOWER8Astral Power (Lunar Power)HOLYPOWER9Holy PowerALTERNATE10Alternate PowerMAELSTROM11MaelstromCHI12ChiINSANITY13InsanityARCANECHARGES16Arcane ChargesFURY17FuryPAIN18PainESSENCE19Essence (Evoker)RUNEFORGEPOWER20Runeforge PowerCOMBOPOINTS_TBC-TBC Combo Points (Classic)
Example Usage

```
local enums = require("common/enums")local me = core.object_manager.get_local_player()local energy = me:get_power(enums.power_type.ENERGY)local max_energy = me:get_max_power(enums.power_type.ENERGY)
```

#### group_role​

Constants for identifying unit roles in a group.

ConstantValueDescriptionNONE-1No role / UnknownTANK0TankHEALER1HealerDAMAGER2Damage dealer
Example Usage

```
local enums = require("common/enums")if unit:get_role() == enums.group_role.HEALER then    -- Prioritize this targetend
```

#### classification​

Constants for unit classification (elite status).

ConstantValueDescriptionUNKNOWN-1UnknownNORMAL0Normal mobELITE1Elite mobRARE_ELITE2Rare elite mobWORLD_BOSS3World bossRARE4Rare mobTRIVIAL5Trivial (grey) mobMINUS6Minus (weak) mob

#### creature_type​

Constants for identifying creature types.

ConstantValueDescriptionABERRATION0AberrationBEAST1BeastDRAGONKIN2DragonkinDEMON3DemonELEMENTAL4ElementalGIANT5GiantUNDEAD6UndeadHUMANOID7HumanoidCRITTER8CritterMECHANICAL9MechanicalNOT_SPECIFIED10Not specifiedTOTEM11TotemNON_COMBAT_PET12Non-combat petGAS_CLOUD13Gas cloudWILD_PET14Wild pet
Example Usage

```
local enums = require("common/enums")-- Check if target is a demon (for Exorcism, etc.)if target:get_creature_type() == enums.creature_type.DEMON then    -- Use anti-demon abilitiesend
```

#### mark_index​

Constants for raid target icons.

ConstantValueIconNO_MARK-1No mark (warning)NO_ICON0No iconSTAR1⭐ StarCIRCLE2🟠 Circle (Orange)DIAMOND3💎 Diamond (Purple)TRIANGLE4🔺 Triangle (Green)MOON5🌙 MoonSQUARE6🟦 Square (Blue)CROSS7❌ Cross (Red X)SKULL8💀 SkullNO_MARK_29No mark (alternate)

#### loss_of_control_type​

Constants for loss of control effects.

ConstantValueDescriptionNONE0No effectPOSSES1PossessedCONFUSE2ConfusedCHARM3CharmedFEAR4FearedSTUN5StunnedPACIFY6PacifiedROOT7RootedSILENCE8SilencedPACIFY_SILENCE9Pacified and silencedDISARM10DisarmedSCHOOL_INTERRUPT11School interruptedSTUN_MECHANIC12Stun (mechanic)FEAR_MECHANIC13Fear (mechanic)

#### buff_type​

Constants for categorizing buff/debuff types.

ConstantValueDescriptionEXCEPTION-2ExceptionUNDEFINIED-1UndefinedUNKNOWN0UnknownMAGIC1MagicCURSE2CurseDISEASE3DiseasePOISON4PoisonSTEALTH5StealthTO_BE_DETERMINED6To be determinedMAGIC_CURSE_DISEASE_POISON7Multiple typesSPECIAL8SpecialENRAGE9Enrage

#### spell_schools_flags​

Bitmask constants for spell school types. Can be combined using bitwise OR.

Base Schools

ConstantValueDescriptionPhysical1Physical damageHoly2Holy damageFire4Fire damageNature8Nature damageFrost16Frost damageShadow32Shadow damageArcane64Arcane damage
Combined Schools

ConstantCombinationDescriptionFrostfireFire + FrostFrostfireShadowflameFire + ShadowShadowflameShadowfrostFrost + ShadowShadowfrostSpellfireFire + ArcaneSpellfireSpellfrostFrost + ArcaneSpellfrostAstralNature + ArcaneAstralRadiantHoly + FireRadiantTwilightHoly + ShadowTwilightDivineHoly + NatureDivinePlagueNature + ShadowPlagueVolcanicFire + NatureVolcanicHolyfrostHoly + FrostHolyfrostHolystormHoly + NatureHolystormFroststormFrost + NatureFroststormSpellstrikePhysical + ArcaneSpellstrikeFlamestrikePhysical + FireFlamestrikeFroststrikePhysical + FrostFroststrikeHolystrikePhysical + HolyHolystrikeStormstrikePhysical + NatureStormstrikeShadowstrikePhysical + ShadowShadowstrikeSpellshadowShadow + ArcaneSpellshadow
Methods

```
-- Combine multiple schoolslocal combined = enums.spell_schools_flags.combine("Fire", "Frost")-- Check if a school is presentlocal has_fire = enums.spell_schools_flags.contains(spell_school, enums.spell_schools_flags.Fire)
```

#### collision_flags​

Bitmask constants for collision detection.

ConstantValueDescriptionNone0x0No collisionDoodadCollision0x1Doodad collisionDoodadRender-Doodad renderWmoCollision0x10WMO collisionWmoRender-WMO renderWmoNoCamCollision-WMO no camera collisionTerrain0x100Terrain collisionIgnoreWmoDoodad-Ignore WMO doodadsLiquidWaterWalkable-Water walkable liquidLiquidAll-All liquidsCull-CullingEntityCollision0x100000Entity collisionEntityRender-Entity renderCollision-General collisionLineOfSight0x100010Line of sight check
Methods

```
-- Combine flagslocal flags = enums.collision_flags.combine("WmoCollision", "Terrain")
```

#### cc_flags​

Bitmask constants for crowd control types in PvP. Cross-expansion compatible.

ConstantValueDescriptionROOT0x1Root effectsINCAPACITATE0x2Incapacitate (breaks on damage)DISORIENT0x4Disorient (breaks on damage)STUN0x8Hard stunSILENCE0x10SilenceKNOCKBACK0x20KnockbackDISARM0x40DisarmSAP0x80SapFEAR0x100FearCYCLONE0x200CycloneMORTAL_COIL-Mortal CoilHORROR0x800HorrorMAGICAL0x1000Magical sourcePHYSICAL0x2000Physical sourceMIND_CONTROL-Mind ControlRANDOM_STUN-Random stun procsRANDOM_ROOT-Random root procsBLINDING_LIGHT-Blinding LightKIDNEY_SHOT-Kidney ShotSCATTER-Scatter ShotBANISH-BanishANY0x1FFFFFMatch any CCANY_BUT_ROOT(computed)Any except roots
Methods

```
-- Combine multiple CC flagslocal stun_or_root = enums.cc_flags.combine(enums.cc_flags.STUN, enums.cc_flags.ROOT)-- Check if a mask contains a flagif enums.cc_flags.has(applied_mask, enums.cc_flags.STUN) then    -- Target is stunnedend
```

#### cc_source​

Constants for CC source filtering.

ConstantValueDescriptionANY0Matches any sourcePHYSICAL1Physical CC sourceMAGICAL2Magical CC source

#### damage_type_flags​

Bitmask constants for damage types (used for immunity checks).

ConstantValueDescriptionPHYSICAL0x1Physical damageMAGICAL0x2Magical damageANY0x3Any damage type
Methods

```
-- Combine damage typeslocal both = enums.damage_type_flags.combine(    enums.damage_type_flags.PHYSICAL,    enums.damage_type_flags.MAGICAL)-- Check if contains a typeif enums.damage_type_flags.has(mask, enums.damage_type_flags.MAGICAL) then    -- Includes magical damageend
```

#### spell_type​

Constants for spell targeting types.

ConstantValueDescriptionTARGET1Unit-targeted spellPOSITION2Position-targeted (ground) spell

#### trigger_mode​

Constants for trigger/activation modes.

ConstantValueDescriptionBASIC-Basic trigger modePREDICTION-Prediction-based trigger mode

#### font_id​

Constants for graphics font selection.

ConstantValueDescriptionFONT_VERY_SMALL2Very small fontFONT_SMALL7Small fontFONT_SEMI_BIG1Semi-big fontFONT_BIG8Big fontFONT_ICONS_SMALL3Small icons fontFONT_ICONS_BIG4Big icons fontFONT_ICONS_VERY_BIG6Very big icons fontFONT_CN9Chinese fontFONT_RU10Russian fontFONT_JP11Japanese fontFONT_KR12Korean font

#### menu_element_type​

Constants for menu UI element types.

ConstantValueDescriptionBUTTON1ButtonCHECKBOX2CheckboxCOLOR_PICKER3Color pickerCOMBOBOX4Dropdown comboboxCOMBOBOX_REORDERABLE5Reorderable comboboxKEY_CHECKBOX6Key + checkboxKEYBIND7KeybindSLIDER_FLOAT8Float sliderSLIDER_INT9Integer sliderTEXT_INPUT10Text inputTREE_NODE11Tree nodeHEADER12HeaderWINDOW13Window

### Complete Example​

```
local izi = require("common/izi_sdk")local enums = izi.enumslocal me = izi.me()local target = izi.target()-- Check if we're a caster classlocal caster_classes = {    [enums.class_id.MAGE] = true,    [enums.class_id.WARLOCK] = true,    [enums.class_id.PRIEST] = true,}if caster_classes[me:get_class()] then    -- Check target's magic immunity    local immune, remaining = target:is_damage_immune(enums.damage_type_flags.MAGICAL)    if immune then        izi.printf("Target immune to magic for %dms", remaining)    endend-- Check for CC on targetlocal is_cc, cc_mask, cc_remaining = target:is_cc(500, enums.cc_flags.ANY)if is_cc then    if enums.cc_flags.has(cc_mask, enums.cc_flags.STUN) then        izi.print("Target is stunned!")    endend-- Check creature type for special abilitiesif target:get_creature_type() == enums.creature_type.UNDEAD then    -- Use Turn Undead, Shackle, etc.end-- Check specializationlocal spec = enums.class_spec_id.get_specialization_enum(me:get_class(), me:get_spec())if spec == enums.class_spec_id.spec_enum.FROST_MAGE then    -- Frost Mage specific rotationend
```

Previous
Color
Next
Geometry

Overview
Importing The Module
Class Identificationclass_id
class_id_to_name

Specializationsspec_enum
class_spec_id

Power Typespower_type

Group Rolesgroup_role

Unit Classificationclassification

Creature Typescreature_type

Raid Markersmark_index

Loss of Controlloss_of_control_type

Buff Typesbuff_type

Spell Schoolsspell_schools_flags

Collision Flagscollision_flags

PvP Crowd Controlcc_flags
cc_source

Damage Type Flagsdamage_type_flags

Spell Typesspell_type

Trigger Modetrigger_mode

Font IDsfont_id

Menu Element Typesmenu_element_type

Complete Example
