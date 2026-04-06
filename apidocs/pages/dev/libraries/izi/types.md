# IZI - Types | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/libraries/izi/types

## Overview

📘 Libraries
IZI
Types

### Overview​

This page documents all the type definitions used throughout the IZI SDK. Understanding these types is essential for effectively using the SDK's spell casting, item usage, and utility functions.

#### cast_opts​

Base options for spell casting validation. These options control which checks are performed before casting.

Type Definition

```
{    skip_charges?: boolean,      -- Skip charge availability check    skip_learned?: boolean,      -- Skip "spell learned" check    skip_usable?: boolean,       -- Skip resource/usability check    skip_back?: boolean,         -- Skip backstab requirement check    skip_moving?: boolean,       -- Skip "must be stationary" check    skip_mount?: boolean,        -- Skip mounted state check    skip_casting?: boolean,      -- Skip "currently casting" check    skip_channeling?: boolean,   -- Skip "currently channeling" check    skip_immune_check?: boolean, -- Skip target immunity validation entirely    damage_type?: integer        -- Override damage type for immunity check}
```

Field Details
FieldTypeDefaultDescriptionskip_chargesbooleanfalseWhen true, skips checking if the spell has charges availableskip_learnedbooleanfalseWhen true, skips checking if the spell is learnedskip_usablebooleanfalseWhen true, skips resource cost and usability checksskip_backbooleanfalseWhen true, skips "must be behind target" requirement (e.g., Backstab)skip_movingbooleanfalseWhen true, allows casting spells that normally require standing stillskip_mountbooleanfalseWhen true, allows casting while mountedskip_castingbooleanfalseWhen true, allows queueing casts during an existing castskip_channelingbooleanfalseWhen true, allows casting during a channelskip_immune_checkbooleanfalseWhen true, bypasses target immunity validation entirelydamage_typeintegernilOverride damage type for immunity check (use enums.damage_type_flags)
Immunity Check Behavior
The immunity check works as follows:

Always blocks if target is immune to ALL damage (Divine Shield, Ice Block)

Auto-detects damage type from spell school for obvious cases:

Pure Physical school → checks physical immunity

Pure magical (Fire/Nature/Frost/Shadow/Arcane) → checks magic immunity

Holy or mixed schools → no auto-detection (ambiguous)

Developer can override with damage_type field

Use skip_immune_check = true to bypass entirely

Example Usage

```
local fireball = izi.spell(133)-- Cast with default checksfireball:cast_safe(target)-- Cast while moving (for instant spells or with special buffs)fireball:cast_safe(target, "Fireball", { skip_moving = true })-- Force physical damage type checkfireball:cast_safe(target, "Fireball", { damage_type = izi.enums.damage_type_flags.PHYSICAL })
```

#### unit_cast_opts​

Extended options for unit-targeted spell casts. Inherits all fields from cast_opts.

Type Definition

```
{    -- Inherited from cast_opts    skip_charges?: boolean,    skip_learned?: boolean,    skip_usable?: boolean,    skip_back?: boolean,    skip_moving?: boolean,    skip_mount?: boolean,    skip_casting?: boolean,    skip_channeling?: boolean,    skip_immune_check?: boolean,    damage_type?: integer,        -- Unit-specific options    skip_facing?: boolean,        -- Skip facing requirement check    skip_range?: boolean,         -- Skip range check    skip_gcd?: boolean,           -- Skip GCD check    cache_time_override?: number  -- Override prediction cache time}
```

Additional Fields
FieldTypeDefaultDescriptionskip_facingbooleanfalseWhen true, skips checking if you're facing the targetskip_rangebooleanfalseWhen true, skips checking if target is in rangeskip_gcdbooleanfalseWhen true, allows casting during global cooldowncache_time_overridenumber0.15Override prediction cache time in seconds (default 150ms)
Example Usage

```
local flash_heal = izi.spell(2061)-- Cast with GCD skip for emergency healsflash_heal:cast_safe(target, "Emergency Heal", {    skip_gcd = true,    skip_facing = true  -- Heals don't require facing})
```

#### pos_cast_opts​

Extended options for position-targeted (ground) spell casts. Inherits all fields from unit_cast_opts.

Type Definition

```
{    -- Inherited from unit_cast_opts    skip_charges?: boolean,    skip_learned?: boolean,    skip_usable?: boolean,    skip_back?: boolean,    skip_moving?: boolean,    skip_mount?: boolean,    skip_casting?: boolean,    skip_channeling?: boolean,    skip_immune_check?: boolean,    damage_type?: integer,    skip_facing?: boolean,    skip_range?: boolean,    skip_gcd?: boolean,    cache_time_override?: number,        -- Position-specific options    check_los?: boolean,             -- Check line of sight to position    use_prediction?: boolean,        -- Use position prediction (default true)    prediction_type?: string|number, -- "AUTO"|"ACCURACY"|"MOST_HITS"|number    geometry?: string|number,        -- "CIRCLE"|"LINE"|number    aoe_radius?: number,             -- Override AoE radius    min_hits?: integer,              -- Minimum targets required (default 1)    source_position?: vec3,          -- Custom origin for prediction    cast_time?: number,              -- Override cast time in milliseconds    projectile_speed?: number,       -- Override projectile speed; 0 = instant    is_heal?: boolean,               -- Target allies instead of enemies    use_intersection?: boolean,      -- Use intersection position    max_range?: number               -- Maximum cast range override}
```

Position-Specific Fields
FieldTypeDefaultDescriptioncheck_losbooleanfalseWhen true, verifies line of sight to the cast positionuse_predictionbooleantrueWhen true, uses movement prediction for optimal positioningprediction_typestring|number"AUTO"Prediction algorithm: "AUTO", "ACCURACY", "MOST_HITS", or numericgeometrystring|number"CIRCLE"AoE shape: "CIRCLE", "LINE", or numericaoe_radiusnumbernilOverride the spell's default AoE radiusmin_hitsinteger1Minimum number of targets required to castsource_positionvec3nilCustom origin point for prediction calculationscast_timenumbernilOverride cast time in milliseconds (skips SDK lookup)projectile_speednumbernilOverride projectile speed in game units/sec; 0 = instantis_healbooleanfalseWhen true, prediction targets allies instead of enemiesuse_intersectionbooleanfalseWhen true, uses intersection position for accuracy modemax_rangenumbernilOverride maximum cast range
Example Usage

```
local blizzard = izi.spell(190356)-- Cast with prediction for maximum hitsblizzard:cast_safe(target, "Blizzard", {    use_prediction = true,    prediction_type = "MOST_HITS",    min_hits = 3,    aoe_radius = 8})-- Cast healing rain on allieslocal healing_rain = izi.spell(73920)healing_rain:cast_safe(friendly_target, "Healing Rain", {    is_heal = true,    min_hits = 3})
```

#### item_use_opts​

Options for item usage validation.

Type Definition

```
{    skip_usable?: boolean,     -- Skip usability check    skip_cooldown?: boolean,   -- Skip cooldown check    skip_range?: boolean,      -- Skip range check    skip_moving?: boolean,     -- Skip movement check    skip_mount?: boolean,      -- Skip mounted check    skip_casting?: boolean,    -- Skip casting check    skip_channeling?: boolean, -- Skip channeling check    skip_gcd?: boolean,        -- Skip GCD check    check_los?: boolean        -- Verify line of sight}
```

Field Details
FieldTypeDefaultDescriptionskip_usablebooleanfalseSkip checking if item is usableskip_cooldownbooleanfalseSkip checking if item is on cooldownskip_rangebooleanfalseSkip checking if target is in rangeskip_movingbooleanfalseSkip checking if you need to stand stillskip_mountbooleanfalseSkip checking if you're mountedskip_castingbooleanfalseSkip checking if you're castingskip_channelingbooleanfalseSkip checking if you're channelingskip_gcdbooleanfalseSkip GCD checkcheck_losbooleanfalseEnable line of sight verification
Example Usage

```
local trinket = izi.item(178742)-- Use trinket during GCDtrinket:use_self_safe("Trinket", {    skip_gcd = true})-- Use healthstone even while castingizi.use_best_health_potion_safe({    skip_casting = true,    skip_channeling = true})
```

#### defensive_filters​

Filters for controlling automatic defensive spell usage.

Type Definition

```
{    block_time?: number,                           -- Seconds to block further defensives    health_percentage_threshold_raw?: number,      -- Cast if current HP% <= this    health_percentage_threshold_incoming?: number, -- Cast if predicted HP% <= this    physical_damage_percentage_threshold?: number, -- Min physical damage % required    magical_damage_percentage_threshold?: number   -- Min magical damage % required}
```

Field Details
FieldTypeDefaultDescriptionblock_timenumber1.0Seconds to prevent additional defensives after casthealth_percentage_threshold_rawnumber50Cast if current health % ≤ this valuehealth_percentage_threshold_incomingnumber40Cast if forecasted health % ≤ this valuephysical_damage_percentage_thresholdnumber0Minimum physical damage % to trigger (0 = ignore)magical_damage_percentage_thresholdnumber0Minimum magical damage % to trigger (0 = ignore)
Example Usage

```
local divine_shield = izi.spell(642)local filters = {    block_time = 8.0,                        -- Don't cast another defensive for 8s    health_percentage_threshold_raw = 30,    -- Cast if HP <= 30%    health_percentage_threshold_incoming = 20 -- Or if predicted HP <= 20%}divine_shield:cast_defensive(me, filters, "Emergency Bubble")
```

#### izi_cast_meta​

Metadata returned from cast operations with details about the cast attempt.

Type Definition

```
{    cast_position?: vec3,      -- Position for skillshots    hit_time?: number,         -- Cast time + projectile travel time    predicted?: boolean,       -- True if position came from prediction    hits?: integer,            -- Predicted number of targets hit    prediction_meta?: table,   -- Raw prediction data    target?: game_object,      -- Target for targeted casts    unit?: game_object,        -- Candidate unit for *_target_if helpers    rank_index?: integer,      -- Index in ranked target list    attempted?: integer,       -- Number of candidates attempted    reason?: string,           -- Failure reason code    err?: string               -- Lower-level error message}
```

Example Usage

```
local fireball = izi.spell(133)local success, meta = fireball:cast_safe(target, "Fireball")if success then    if meta.predicted then        izi.printf("Cast at predicted position, expecting %.2fs travel", meta.hit_time)    endelse    izi.printf("Cast failed: %s", meta.reason or "unknown")end
```

#### queue_kind​

Union type for queue popup types.

Type Definition

```
"none" | "pve" | "pvp"
```

ValueDescription"none"No active queue"pve"PvE queue (dungeons, raids, etc.)"pvp"PvP queue (battlegrounds, arenas, etc.)

#### queue_popup_info​

Comprehensive information about a queue popup.

Type Definition

```
{    kind: queue_kind,         -- "none" | "pve" | "pvp"    since_sec: number,        -- Time since popup appeared (seconds)    since_ms: integer,        -- Time since popup appeared (milliseconds)    age_sec: number,          -- Age of popup in seconds    age_ms: integer,          -- Age of popup in milliseconds    expire_sec: number|nil,   -- Seconds until expiration    expire_ms: integer|nil,   -- Milliseconds until expiration    pve: queue_pve_meta|nil,  -- PvE-specific data    pvp: queue_pvp_meta|nil   -- PvP-specific data}
```

#### queue_pve_meta​

PvE queue metadata.

```
{    proposal: boolean  -- Whether this is a proposal (ready check)}
```

#### queue_pvp_slot ​

PvP queue slot information.

```
{    idx: integer,           -- Queue slot index    status: any,            -- Current status    is_call: boolean|nil,   -- Is this a Mercenary call    expires_at_ms: integer|nil  -- Expiration timestamp}
```

#### queue_pvp_meta​

PvP queue metadata.

```
{    slots: queue_pvp_slot[]  -- Array of queue slots}
```

#### PurgeEntry​

Information about a single purgeable buff.

```
{    buff_id: integer,      -- Buff spell ID    buff_name: string,     -- Buff display name    priority: integer,     -- Purge priority (higher = more important)    min_remaining: number  -- Minimum remaining duration in seconds}
```

#### PurgeScanResult​

Result from scanning a target for purgeable buffs.

```
{    is_purgeable: boolean,        -- Has purgeable buffs    table: PurgeEntry[],          -- List of purge candidates    current_remaining_ms: integer, -- Shortest remaining duration    expire_time: number           -- Engine time when shortest expires}
```

Example Usage

```
local result = target:is_purgable(250)if result.is_purgeable then    for _, entry in ipairs(result.table) do        izi.printf("Can purge: %s (priority %d)", entry.buff_name, entry.priority)    endend
```

#### Bitmask Aliases​

These are integer types used for bitmask operations:

AliasDescriptionCCFlagMaskBitmask of CC flags (see cc_flags)DMGTypeMaskBitmask of damage type flags (see damage_type_flags)SourceMaskBitmask of effect source filtersMillisecondsTime value in milliseconds

#### Predicate Types​

AliasSignatureDescriptionunit_predicatefun(u: game_object): booleanFilter function for unitstarget_filterfun(u: game_object): number|nilScoring function for target selectionadv_conditionboolean|fun(u: game_object): booleanAdvanced condition (static or dynamic)

#### sort_mode​

Union type for target selection sorting.

```
"max" | "min"
```

ValueDescription"max"Select target with highest score"min"Select target with lowest score
Example Usage

```
-- Get lowest health enemy (for execute)local target = izi.pick_enemy(40, false, function(u)    return u:get_health_percentage()end, "min")-- Get highest health enemy (for pressure)local tank = izi.pick_enemy(40, false, function(u)    return u:get_health_percentage()end, "max")
```

Previous
SDK
Next
Maps

Overview
Cast Optionscast_opts
unit_cast_opts
pos_cast_opts

Item Optionsitem_use_opts

Defensive Filtersdefensive_filters

Cast Metadataizi_cast_meta

Queue Typesqueue_kind
queue_popup_info
queue_pve_meta
queue_pvp_slot
queue_pvp_meta

Purge TypesPurgeEntry
PurgeScanResult

Type AliasesBitmask Aliases
Predicate Types

Sort Modesort_mode
