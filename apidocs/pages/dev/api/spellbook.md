# Spell Book - Raw Functions | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/spellbook

## Overview

👨‍💻 Lua Scripting API
Spell Book
Spell Book - Raw Functions

### Overview​

The spell_book module provides a comprehensive set of methods to interact with spells in your scripts. You can use these functions to query spell cooldowns, retrieve spell names, check if a spell is equipped, etc. However, same like with the Input module, using the raw functions directly might not be the best idea in most cases. For example, to check if a spell is castable, you would need to first check if the spell is equipped, if the spell is on cooldown, then range... As you can see, this is going to become an annoying task in most of your scripts. To make your life easier and centralize code as much as possible so the amount of bugs is reduced, we developed the
Spell helper module.

tip
Check the Spell helper module after checking the raw functions, provided below.

#### get_specialization_id()​

Returns the specialization ID of the local player.

Returns: number — The specialization ID.

note
This function is specially useful to decide whether to
load or not your script. Here is an example to properly avoid loading scripts when they are
not necessary (for example, your script is for rogues and the user is playing a monk).

```
--- this is the HEADER filelocal plugin_info = require("plugin_info")local plugin = {}plugin["name"] = plugin_info.plugin_load_nameplugin["version"] = plugin_info.plugin_versionplugin["author"] = plugin_info.author-- by default, we load the plugin alwaysplugin["load"] = true-- if there is no local player (eg. user injected before being in-game or is in loading screen) then-- we don't load the scriptlocal local_player = core.object_manager.get_local_player()if not local_player then    plugin["load"] = false    return pluginend-- we check if the class that is being played currently matches our script's intended classlocal enums = require("common/enums")local player_class = local_player:get_class()local is_valid_class = player_class == enums.class_id.ROGUEif not is_valid_class then    plugin["load"] = false    return pluginend-- then, we check if the spec id that is being currently played matches our script's intended speclocal player_spec_id = core.spell_book.get_specialization_id()local is_valid_spec_id = player_spec_id == 3if not is_valid_spec_id then    plugin["load"] = false    return pluginendreturn plugin
```

#### get_global_cooldown()​

Returns the duration of the global cooldown, which is the time between casting spells.

Returns: number — The global cooldown duration in seconds.

#### get_spell_cooldown(spell_id)​

Returns the cooldown duration of the specified spell in seconds.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: number — The cooldown duration in seconds.

#### get_spell_charge(spell_id)​

Returns the current number of charges available for the specified spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: integer — The current number of charges.

#### get_spell_charge_max(spell_id)​

Returns the maximum number of charges available for the specified spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: integer — The maximum number of charges.

#### get_spell_charge_cooldown_start_time(spell_id)​

Returns the start time of the cooldown for a spell's charge.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: number — The timestamp when the cooldown started.

#### get_spell_charge_cooldown_duration(spell_id)​

Returns the duration of the cooldown for a spell's charge.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: number — The cooldown duration in seconds.

#### get_spell_cooldown_information(spell_id)​

Returns detailed cooldown information for a spell, including start time, total duration, and whether the cooldown is active.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: table — A table containing cooldown details.

spell_cooldown_info Properties:

FieldTypeDescriptionstart_timenumberThe game time when the cooldown starteddurationnumberThe total duration of the cooldown in secondsenabledbooleanWhether the cooldown is currently active/enabled

```
local cd_info = core.spell_book.get_spell_cooldown_information(12345)if cd_info.enabled then    local remaining = (cd_info.start_time + cd_info.duration) - core.game_time()    core.log("Cooldown remaining: " .. string.format("%.1f", remaining / 1000) .. "s")else    core.log("Spell is ready!")end
```

#### get_spell_name(spell_id)​

Returns the name of the specified spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: string — The name of the spell.

#### get_spell_description(spell_id)​

Retrieves the tooltip text of the specified spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: string — The tooltip text.

#### get_buff_description(buff_ptr)​

:::warning Deprecated
This function was deprecated after 03/2026. Use uff.points directly instead.
:::

Retrieves the tooltip text of a specific buff.

Parameters:

buff_ptr (buff) — The buff object to get the description for.

Returns: string — The buff tooltip text.

#### get_spells()​

Returns a table containing all spells and their corresponding IDs.

Returns: table — A table mapping spell IDs to spell names.

#### has_spell(spell_id)​

Checks if the specified spell is equipped.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: boolean — true if the spell is equipped; otherwise, false.

#### is_spell_learned(spell_id)​

Determines if the specified spell is learned.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: boolean — true if the spell is learned; otherwise, false.

Note: is_spell_learned is more reliable than has_spell for checking talents.

#### is_usable_spell(spell_id)​

Determines whether the specified spell can be cast at the current moment.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: boolean — true if the spell is usable; otherwise, false.

#### is_important_spell(spell_id)​

Checks if a spell is flagged as important.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: boolean — true if the spell is flagged as important; otherwise, false.

#### is_current_spell(spell_id)​

Checks if the specified spell is the one currently being cast.

Parameters:

spell_id (number) — The ID of the spell.

Returns: boolean — true if the spell is currently being cast; otherwise, false.

#### spell_has_attribute(spell_id, n, flag)​

Checks if a spell has a specific attribute flag set.

Parameters:

spell_id (integer) — The ID of the spell.

n (integer) — The attribute index.

flag (integer) — The attribute flag to check.

Returns: boolean — true if the spell has the specified attribute; otherwise, false.

#### get_base_spell_id(spell_id)​

Returns the base (original) spell ID for a given spell. Useful for spells that get replaced by talents or other effects but still share a base identity.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: integer — The base spell ID.

#### get_spell_cast_count(spell_id)​

Returns the current cast count for a spell.

Parameters:

spell_id (number) — The ID of the spell.

Returns: number — The cast count.

#### get_assisted_spell_id(target)​

Returns the spell ID that the engine recommends for assisting the given target.

Parameters:

target (game_object) — The target game object.

Returns: number — The assisted spell ID.

#### get_spell_costs(spell_id)​

Returns a table containing the power cost details of the specified spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: table — A table containing power cost details.

spell_cost Properties:

min_cost: Minimum cost required to cast the spell.

cost: Standard cost to cast the spell.

cost_per_sec: Cost per second if the spell is channeled.

cost_type: Type of resource used (e.g., mana, energy).

required_buff_id: ID of any buff required to modify the cost.

warning
Do not use this function, as it returns a table that needs to be handled in a specific way. We still provide its functionality, but in general you wouldn't want to use it.

#### get_spell_range_data(spell_id)​

Returns a table containing the minimum and maximum range of the specified spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: table — A table with min_range and max_range.

Range Data Properties:

min_range: Minimum distance required to cast the spell.

max_range: Maximum distance within which the spell can be cast.

#### get_spell_min_range(spell_id)​

Returns the minimum range of the specified spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: number — The minimum range.

#### get_spell_max_range(spell_id)​

Returns the maximum range of the specified spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: number — The maximum range.

#### is_spell_in_range(spell_id, target, caster)​

Checks whether a spell is in range from a specified caster to a target. If caster is not provided, it defaults to the local player. If target is not provided, it defaults to the current target of the local player.

Parameters:

spell_id (integer) — The ID of the spell to check.

target (game_object, optional) — The target game object to check range against. Defaults to the current target if omitted.

caster (game_object, optional) — The caster game object. Defaults to the local player if omitted.

Returns: boolean — true if the target is within range for the specified spell; otherwise, false.

#### get_spell_damage(spell_id)​

Retrieves the damage value of the specified spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: number — The damage value.

#### is_melee_spell(spell_id)​

Determines if the specified spell is of melee type.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: boolean — true if the spell is melee type; otherwise, false.

#### is_spell_position_cast(spell_id)​

Checks if the specified spell is a skillshot (position-cast spell).

Parameters:

spell_id (integer) — The ID of the spell.

Returns: boolean — true if the spell is a skillshot; otherwise, false.

#### cursor_has_spell()​

Checks if the cursor is currently busy with a skillshot.

Returns: boolean — true if the cursor is busy; otherwise, false.

#### get_spell_school(spell_id)​

Determines the school of magic for a given spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: number — The school of the spell (e.g., arcane, fire, shadow).

#### get_spell_cast_time(spell_id)​

Returns the cast time required for a specific spell.

Parameters:

spell_id (integer) — The ID of the spell.

Returns: number — The spell's cast time in seconds.

#### get_talent_name(talent_id)​

Returns the name of the specified talent.

Parameters:

talent_id (integer) — The ID of the talent.

Returns: string — The name of the talent.

#### get_talent_spell_id(talent_id)​

Returns the spell ID associated with the specified talent.

Parameters:

talent_id (integer) — The ID of the talent.

Returns: number — The spell ID.

#### is_item_usable(item_id)​

Checks whether a specific item can be used at the current moment.

Parameters:

item_id (integer) — The ID of the item.

Returns: boolean — true if the item is usable; otherwise, false.

#### has_item_range(item_id)​

Checks whether an item has a built-in range definition (e.g., targetable items). The engine resolves the item's underlying "use spell" and reports if range data exists.

Parameters:

item_id (integer) — The ID of the item.

Returns: boolean — true if the item supports range checking; otherwise, false.

#### is_item_in_range(item_id, target)​

Checks whether an item can be used on a target with respect to range. Internally maps the item to its "use spell" and performs a spell range check.

Parameters:

item_id (integer) — The ID of the item.

target (game_object, optional) — The target game object. If omitted, the engine may default to the current target.

Returns: boolean — true if the target is in range for this item; otherwise, false.

#### get_pet_mode()​

Retrieves the current mode of the player's pet.

Returns: number — The pet's current mode (e.g., passive, aggressive).

#### get_pet_spells()​

Returns a table of spells available to the player's pet.

Returns: table — A table containing the pet's spell IDs and names.

#### get_pet_happiness()​

Retrieves the current pet happiness information. Returns a table with the pet's happiness level, damage modifier, and loyalty rate.

Returns: table — A table containing the following fields:

pet_happiness_data Properties:

happiness: (integer) The pet happiness level.

damage_percentage: (number) The pet damage percentage modifier.

loyalty_rate: (number) The pet loyalty rate.

```
local pet_data = core.spell_book.get_pet_happiness()if pet_data then    core.log("Happiness: " .. tostring(pet_data.happiness))    core.log("Damage %: " .. tostring(pet_data.damage_percentage))    core.log("Loyalty Rate: " .. tostring(pet_data.loyalty_rate))end
```

#### get_mount_count()​

Returns the total number of mounts available to the player.

Returns: integer — The number of available mounts.

#### get_mount_info(mount_index)​

Returns detailed information about a specific mount.

Parameters:

mount_index (integer) — The index of the mount.

Returns: table|nil — A table containing information about the mount, or nil if the index is invalid.

mount_info Properties:

mount_name: (string) The name of the mount.

spell_id: (integer) The spell ID associated with the mount.

mount_id: (integer) The unique ID of the mount.

is_active: (boolean) Whether the mount is currently active.

is_usable: (boolean) Whether the mount is usable.

mount_type: (integer) The type/category of the mount.

#### get_totem_info(index)​

Returns information about a totem in the given slot.

Parameters:

index (integer) — The totem slot index (1–4). Corresponds to the totem slot (e.g., Fire, Earth, Water, Air).

Returns: table — A table containing totem information.

totem_info Properties:

have_totem: (boolean) Whether the totem exists in this slot.

totem_name: (string) Name of the totem.

start_time: (number) Start time of the totem.

duration: (number) Duration of the totem.

```
for i = 1, 4 do    local totem = core.spell_book.get_totem_info(i)    if totem and totem.have_totem then        core.log("Slot " .. i .. ": " .. totem.totem_name .. " (duration: " .. totem.duration .. ")")    endend
```

#### get_rune_type(index)​

Returns the type of the rune at the given index.

Parameters:

index (integer) — The rune index.

Returns: integer — The rune type: 1 = Blood, 2 = Unholy, 3 = Frost, 4 = Death.

#### is_rune_slot_active(index)​

Checks if the rune at the given index is currently active (not on cooldown).

Parameters:

index (integer) — The rune index.

Returns: boolean — true if the rune is active; otherwise, false.

#### get_rune_info(slot)​

Retrieves detailed cooldown information for the rune in the given slot.

Parameters:

slot (integer) — The rune slot (1–6).

Returns: table — A table containing rune cooldown info.

rune_info Properties:

start: (number) Cooldown start time in seconds.

duration: (number) Cooldown duration in seconds.

ready: (boolean) true if the rune is ready to use.

```
for slot = 1, 6 do    local rune = core.spell_book.get_rune_info(slot)    local rune_type = core.spell_book.get_rune_type(slot)    if rune.ready then        core.log("Rune " .. slot .. " (type " .. rune_type .. ") is ready!")    endend
```

#### get_base_power_regen()​

Retrieves the base (out-of-combat) power regeneration rate of the local player. This represents the passive regeneration rate when not casting or using abilities.

Returns: number — The base power regeneration per second.

#### get_casting_power_regen()​

Retrieves the power regeneration rate of the local player while casting. This may differ from the base regen due to talents, buffs, or class mechanics.

Returns: number — The casting power regeneration per second.

#### is_player_in_control()​

Determines if the player is currently in full control of their character (not stunned, feared, or incapacitated).

Returns: boolean — true if the player is in control; otherwise, false.

Previous
Game Object - Code Examples
Next
Spell helper

Overview
FunctionsGeneral Functions 📃
get_specialization_id()
Cooldowns and Charges ⏳
get_global_cooldown()
get_spell_cooldown(spell_id)
get_spell_charge(spell_id)
get_spell_charge_max(spell_id)
get_spell_charge_cooldown_start_time(spell_id)
get_spell_charge_cooldown_duration(spell_id)
get_spell_cooldown_information(spell_id)
Spell Information ℹ️
get_spell_name(spell_id)
get_spell_description(spell_id)
get_buff_description(buff_ptr)
get_spells()
has_spell(spell_id)
is_spell_learned(spell_id)
is_usable_spell(spell_id)
is_important_spell(spell_id)
is_current_spell(spell_id)
spell_has_attribute(spell_id, n, flag)
get_base_spell_id(spell_id)
get_spell_cast_count(spell_id)
get_assisted_spell_id(target)
Spell Costs 💰
get_spell_costs(spell_id)
Spell Range and Damage 🎯
get_spell_range_data(spell_id)
get_spell_min_range(spell_id)
get_spell_max_range(spell_id)
is_spell_in_range(spell_id, target, caster)
get_spell_damage(spell_id)
Casting Types 🎭
is_melee_spell(spell_id)
is_spell_position_cast(spell_id)
cursor_has_spell()
get_spell_school(spell_id)
get_spell_cast_time(spell_id)
Talents 🌟
get_talent_name(talent_id)
get_talent_spell_id(talent_id)
Item Functions 🎒
is_item_usable(item_id)
has_item_range(item_id)
is_item_in_range(item_id, target)
Pet Functions 🐾
get_pet_mode()
get_pet_spells()
get_pet_happiness()
Mounts 🐎
get_mount_count()
get_mount_info(mount_index)
Totem Functions 🪶
get_totem_info(index)
Rune Functions (Death Knight) 💀
get_rune_type(index)
is_rune_slot_active(index)
get_rune_info(slot)
Power Regeneration ⚡
get_base_power_regen()
get_casting_power_regen()
is_player_in_control()

