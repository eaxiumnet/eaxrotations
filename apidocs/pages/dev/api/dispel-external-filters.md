# Dispel External Filters | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/dispel-external-filters

## Overview

📘 Libraries
Mini Libs
Dispel External Filters

### Overview​

The Dispel External Filters API allows you to register custom filters that control when the Universal Dispels plugin should or should not dispel. This enables fine-grained control over dispel behavior based on your own conditions - such as blocking dispels while stealthed, allowing only specific targets, or temporarily muting dispel logic.

Key Features:

Block Filters - Prevent dispels when your condition returns false

Allow Filters - Require at least one allow filter to pass before dispelling

Auto-Expiration - Filters can expire after time, frame count, or usage count

Priority Access - Check debuff priority in your filter logic

Runtime Management - Register, unregister, and modify filters dynamically

Plugin Dependency
This API is internal to the Universal Dispels plugin. Use pcall to safely require it - the module won't exist if the plugin isn't loaded.

### Importing The Module​

```
local prefix = "ext_0_plugin_universal_dispels/"local dispels_exist, ext = pcall(require, "root/" .. prefix .. "dispel/external_filters")if not dispels_exist or not ext then    -- Plugin not present, nothing to do    returnend-- 'ext' is now the filters API
```

#### Block Filters (type = "block")​

Block filters prevent dispels when they return false. Multiple block filters can exist - if ANY block filter returns false, the dispel is blocked.

```
ext.register("my_block_filter",    function(local_player, target, data_packet)        if should_block then            return false, "reason_string"  -- Block the dispel        end        return true  -- Allow the dispel to proceed    end,    { type = "block", label = "My Block Filter" })
```

#### Allow Filters (type = "allow")​

Allow filters create a whitelist requirement. When ANY allow filter exists, at least one must return true for the dispel to proceed.

```
ext.register("my_allow_filter",    function(local_player, target, data_packet)        return target == my_priority_target  -- Only allow this target    end,    { type = "allow", label = "Priority Target Only" })
```

Allow Filter Behavior
If you register ANY allow filter, dispels are permitted ONLY when at least one allow filter returns true. This is more restrictive than block filters.

#### ext.register​

Syntax

```
ext.register(name: string, func: function, opts?: table): nil
```

Parameters

ParameterTypeDescriptionnamestringUnique identifier for this filterfuncfunctionFilter function (see callback signature below)optstableOptions including type, expiration, and label
Callback Signature

```
function(local_player: game_object, target: game_object, data_packet: table): boolean, string|nil
```

ParameterTypeDescriptionlocal_playergame_objectThe local playertargetgame_objectThe dispel targetdata_packettableContains details.id, details.priority, etc.
Returns: boolean (allow/block), string|nil (optional reason)

Options Table

FieldTypeDefaultDescriptiontypestring"block"Filter type: "block" or "allow"labelstringnilHuman-readable label for debuggingtimenumbernilAuto-expire after this many secondscountnumbernilAuto-expire after this many checksframesnumbernilAuto-expire after this many frames

#### ext.unregister​

```
ext.unregister(name: string): nil
```

Removes a registered filter by name.

#### ext.clear​

```
ext.clear(): nil
```

Removes all registered filters.

#### ext.priority_enum​

Access to priority level constants for checking debuff priority:

```
ext.priority_enum.lowext.priority_enum.mediumext.priority_enum.highext.priority_enum.critical
```

#### Block While Stealthed​

```
local prefix = "ext_0_plugin_universal_dispels/"local ok, ext = pcall(require, "root/" .. prefix .. "dispel/external_filters")if not ok or not ext then return endext.register("block_while_stealth",    function(local_player, target, data_packet)        local stealth_data = buff_manager:get_buff_data(local_player, enums.buff_db.STEALTH, 50)        local is_stealthed = stealth_data and stealth_data.is_active == true        if is_stealthed then            return false, "stealth_active"        end        return true    end,    { type = "block", label = "No Dispel While Stealth" })
```

#### Block Low Priority for Short Window​

```
ext.register("no_low_priority_for_0_7s",    function(_, _, data_packet)        local prio = (data_packet and data_packet.details and data_packet.details.priority) or 0        if prio <= ext.priority_enum.medium then            return false, "priority_low"        end        return true    end,    { type = "block", time = 0.7, label = "Low Priority Gate" })
```

#### Allow Only Specific Target for 2 Seconds​

```
local my_unit_pointer = my_module.get_primary_target()if my_unit_pointer then    ext.register("allow_only_primary_target",        function(_, target)            return target == my_unit_pointer or false, "not_primary_target"        end,        { type = "allow", time = 2.0, label = "Only Primary Target" }    )end
```

#### Block Specific Debuff ID Once​

```
local blocked_id = 388392ext.register("ban_debuff_388392_once",    function(_, _, data_packet)        local id = data_packet and data_packet.details and data_packet.details.id        return id ~= blocked_id or false, "id_388392_blocked"    end,    { type = "block", count = 1, label = "Ban 388392 Once" })
```

#### Temporary Global Mute (Next 3 Checks)​

```
ext.register("block_next_3_checks",    function() return false, "temp_mute" end,    { type = "block", count = 3, label = "Mute Next 3" })
```

#### Single Frame Guard​

```
ext.register("block_once_frame",    function() return false, "single_guard" end,    { type = "block", frames = 1, label = "Single Check Guard" })
```

#### Boss Only Window (1.5 Seconds)​

```
local boss_ptr = encounter and encounter.get_boss_ptr and encounter.get_boss_ptr() or nilif boss_ptr then    ext.register("allow_only_boss",        function(_, target)            return target == boss_ptr or false, "not_boss"        end,        { type = "allow", time = 1.5, label = "Boss Only Window" }    )end
```

#### Druid Cat Form Toggle​

```
-- Register on enter cat form, unregister on exitif is_cat_form then    ext.register("druid_no_dispel",        function() return false, "cat_form" end,        { type = "block", label = "No Dispel in Cat Form" }    )else    ext.unregister("druid_no_dispel")end
```

### Tips​

Prefer time or count expirations for temporary rules so you don't have to manually unregister

If you register ANY allow filter, dispels only work when at least one returns true

Use ext.unregister() when conditions change (e.g., leaving stealth)

Filter functions are called every time a dispel is considered, so keep them fast

Previous
Spell Queue
Next
Kick External Filters

Overview
Importing The Module
Filter TypesBlock Filters (type = "block")
Allow Filters (type = "allow")

Functionsext.register
ext.unregister
ext.clear
ext.priority_enum

Complete ExamplesBlock While Stealthed
Block Low Priority for Short Window
Allow Only Specific Target for 2 Seconds
Block Specific Debuff ID Once
Temporary Global Mute (Next 3 Checks)
Single Frame Guard
Boss Only Window (1.5 Seconds)
Druid Cat Form Toggle

Tips
