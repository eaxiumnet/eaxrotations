# Buff Manager | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/modules/buff-manager

## Overview

📘 Libraries
Modules
Buff Manager

### Overview​

The Buff Manager is a module that provides efficient, cached access to buff and debuff data on any unit. Instead of repeatedly querying the game for aura information every frame, the Buff Manager caches results and returns them quickly, significantly improving performance.

Key Features:

Automatic Caching - Queries are cached to avoid redundant game API calls

Buff Database Integration - Works with enums.buff_db for common buff lookups

Flexible Queries - Query by single ID, array of IDs, or buff database enum

Rich Data - Returns remaining time, stacks, duration, and active status

### Importing The Module​

```
---@type buff_managerlocal buff_manager = require("common/modules/buff_manager")
```

Method Access
Access functions with : (colon), not . (dot).

#### buff_manager_data​

Returned by get_buff_data, get_debuff_data, and get_aura_data:

FieldTypeDescriptionis_activebooleanWhether the buff/debuff is currently activeremainingnumberTime remaining in secondsstacksnumberCurrent stack countdurationnumberTotal duration of the buff

#### buff_manager_cache_data​

Returned by get_buff_cache, get_debuff_cache, and get_aura_cache:

FieldTypeDescriptionbuff_idnumberThe spell ID of the buffcountnumberStack countexpire_timenumberWhen the buff expiresdurationnumberTotal durationcastergame_objectWho applied the buffptrbuffRaw buff pointerbuff_namestringDisplay name of the buffbuff_typenumberType of buffis_undefinedbooleanWhether buff is undefined

#### buff_manager:get_buff_data​

Syntax

```
buff_manager:get_buff_data(    unit: game_object,    enum_key: buff_db | number[],    custom_cache_duration_ms?: number): buff_manager_data
```

Parameters

ParameterTypeDescriptionunitgame_objectThe unit to checkenum_keybuff_db | number[]Buff database enum or array of spell IDscustom_cache_duration_msnumberOptional custom cache duration in milliseconds
Returns

buff_manager_data - Buff information with is_active, remaining, stacks, duration

Example Usage

```
local buff_manager = require("common/modules/buff_manager")local player = core.object_manager.get_local_player()-- Check using buff database enumlocal stealth = buff_manager:get_buff_data(player, enums.buff_db.STEALTH)if stealth.is_active then    core.log("Stealthed! " .. stealth.remaining .. "s remaining")end-- Check using specific spell IDslocal combustion = buff_manager:get_buff_data(player, { 190319 })if combustion.is_active and combustion.stacks >= 3 then    core.log("Combustion active with " .. combustion.stacks .. " stacks")end
```

#### buff_manager:get_debuff_data​

Syntax

```
buff_manager:get_debuff_data(    unit: game_object,    enum_key: buff_db | number[],    custom_cache_duration_ms?: number): buff_manager_data
```

Same as get_buff_data but queries debuffs instead of buffs.

Example Usage

```
local target = core.object_manager.get_target()-- Check if target has your DoTlocal immolate = buff_manager:get_debuff_data(target, { 348 })if not immolate.is_active or immolate.remaining < 3 then    -- Refresh Immolateend-- Check CC status using buff databaselocal cc_data = buff_manager:get_debuff_data(target, enums.buff_db.STUN)if cc_data.is_active then    core.log("Target is stunned for " .. cc_data.remaining .. "s")end
```

#### buff_manager:get_aura_data​

Syntax

```
buff_manager:get_aura_data(    unit: game_object,    enum_key: buff_db | number[],    custom_cache_duration_ms?: number): buff_manager_data
```

Queries both buffs AND debuffs (any aura). Use when you don't care whether it's a buff or debuff.

#### buff_manager:get_buff_cache​

Syntax

```
buff_manager:get_buff_cache(    unit: game_object,    custom_cache_duration_ms?: number): buff_manager_cache_data[]
```

Returns the full cached buff list for a unit. Useful for iterating all buffs.

Example Usage

```
local player = core.object_manager.get_local_player()local buffs = buff_manager:get_buff_cache(player)for _, buff in ipairs(buffs) do    core.log(string.format("Buff: %s (ID: %d) - %d stacks, %.1fs remaining",        buff.buff_name, buff.buff_id, buff.count, buff.duration))end
```

#### buff_manager:get_debuff_cache​

```
buff_manager:get_debuff_cache(    unit: game_object,    custom_cache_duration_ms?: number): buff_manager_cache_data[]
```

Returns the full cached debuff list for a unit.

#### buff_manager:get_aura_cache​

```
buff_manager:get_aura_cache(    unit: game_object,    custom_cache_duration_ms?: number): buff_manager_cache_data[]
```

Returns the full cached aura list (buffs + debuffs) for a unit.

#### buff_manager:get_buff_value_from_description​

Syntax

```
buff_manager:get_buff_value_from_description(    description_text: string,    ignore_percentage: boolean,    ignore_flat: boolean): number
```

Parses a buff description text to extract numeric values. Useful for dynamic buff effects.

#### DoT Tracking​

```
local buff_manager = require("common/modules/buff_manager")local DOT_IDS = {    IMMOLATE = { 348 },    CORRUPTION = { 146739 },    AGONY = { 980 },}local function check_dots(target)    local dots_missing = {}        for name, ids in pairs(DOT_IDS) do        local dot_data = buff_manager:get_debuff_data(target, ids)        if not dot_data.is_active or dot_data.remaining < 4.5 then            table.insert(dots_missing, name)        end    end        return dots_missingend
```

#### Proc Monitoring​

```
local buff_manager = require("common/modules/buff_manager")local PROCS = {    HOT_STREAK = { 48108 },    HEATING_UP = { 48107 },    BRAIN_FREEZE = { 190446 },}local function get_active_procs(player)    local active = {}        for name, ids in pairs(PROCS) do        local proc = buff_manager:get_buff_data(player, ids)        if proc.is_active then            active[name] = {                remaining = proc.remaining,                stacks = proc.stacks            }        end    end        return activeend
```

#### Custom Cache Duration​

```
-- For rapidly changing buffs, use shorter cachelocal fast_buff = buff_manager:get_buff_data(player, { 12345 }, 50)  -- 50ms cache-- For stable buffs, use longer cache for better performance  local stable_buff = buff_manager:get_buff_data(player, { 67890 }, 500)  -- 500ms cache
```

Previous
Target Selector
Next
Settings Manager

Overview
Importing The Module
Return Typesbuff_manager_data
buff_manager_cache_data

Functionsbuff_manager:get_buff_data
buff_manager:get_debuff_data
buff_manager:get_aura_data
buff_manager:get_buff_cache
buff_manager:get_debuff_cache
buff_manager:get_aura_cache
buff_manager:get_buff_value_from_description

Complete ExamplesDoT Tracking
Proc Monitoring
Custom Cache Duration
