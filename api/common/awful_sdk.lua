
-- Example:
-- ---@type awful_api
-- local awful = require("common/awful_sdk")

---@meta
---@diagnostic disable: undefined-global, missing-fields, lowercase-global

--------------------------------------------------------------------------------
-- Forward declarations
--------------------------------------------------------------------------------

---@alias awful_buff_id integer
---@alias awful_buff_spec integer|integer[]
---@alias awful_dr_category "stun"|"silence"|"disorient"|"incapacitate"|"root"|"knockback"|"disarm"

--------------------------------------------------------------------------------
-- BuffData (returned by unit:get_buff / unit:get_debuff)
--------------------------------------------------------------------------------

---@class awful_buff_data
---@field is_active boolean               -- True if the aura is currently on the unit
---@field stacks integer                  -- Stack count (0 if absent)
---@field duration number                 -- Total duration in seconds
---@field remaining number                -- Remaining time in seconds
---@field uptime number                   -- How long the aura has been active in seconds
---@field min number                      -- Remaining time in seconds (alias of remaining)
---@field _object userdata|nil            -- Raw aura pointer from engine

--------------------------------------------------------------------------------
-- Vector3 (position)
--------------------------------------------------------------------------------

---@class awful_vec3
---@field x number
---@field y number
---@field z number

--------------------------------------------------------------------------------
-- awful_unit (wrapped unit object)
-- Accessed via awful.player, awful.target, collection iteration, etc.
-- Properties can be accessed as fields (unit.hp) or called as functions (unit:hp()).
-- The metatable resolves both styles transparently.
--------------------------------------------------------------------------------

-- Health / Status
---@class awful_unit
---@field hp number                                                              -- Health percentage 0..1 (e.g., 0.75 = 75%)
---@field hpliteral number                                                       -- Current health value
---@field health number                                                          -- Alias of hpliteral
---@field hpmax number                                                           -- Maximum health
---@field hpdeficit number                                                       -- Missing health (max - current)
---@field missinghealth number                                                   -- Alias of hpdeficit
---@field dead boolean                                                           -- True if dead or ghost
---@field exists boolean                                                         -- True if the unit reference is valid
---@field visible boolean                                                        -- True if the unit is visible

-- Identity / Class
---@class awful_unit
---@field name string                                                            -- Unit name
---@field class string                                                           -- Uppercase class name ("WARRIOR", "ROGUE", etc.)
---@field classliteral string                                                    -- Class name from enums
---@field unitclass string                                                       -- Alias of class
---@field getclass string                                                        -- Alias of class
---@field classID integer                                                        -- Numeric class ID (1=Warrior, 2=Paladin, etc.)
---@field spec integer                                                           -- Specialization ID
---@field guid string                                                            -- Unique identifier (GUID string)
---@field id2 integer                                                            -- NPC ID (0 for players)
---@field pointer userdata                                                       -- Raw game object reference
---@field unit userdata                                                          -- Raw game object reference (alias for interop with pvp_helper etc.)

-- Type checks
---@class awful_unit
---@field isplayer boolean                                                       -- True if player character
---@field player boolean                                                         -- Alias of isplayer
---@field playercheck boolean                                                    -- Alias of isplayer
---@field ispet boolean                                                          -- True if pet unit
---@field pet boolean                                                            -- Alias of ispet
---@field enemy boolean                                                          -- True if hostile to local player
---@field hostile boolean                                                        -- Alias of enemy
---@field isfriend boolean                                                       -- True if friendly to local player
---@field friendly boolean                                                       -- Alias of isfriend
---@field friend boolean                                                         -- Alias of isfriend
---@field isfriendly boolean                                                     -- Alias of isfriend
---@field ishealer boolean                                                       -- True if healer specialization
---@field healer boolean                                                         -- Alias of ishealer
---@field istank boolean                                                         -- True if tank specialization
---@field tank boolean                                                           -- Alias of istank
---@field dummy boolean                                                          -- True if training dummy
---@field isdummy boolean                                                        -- Alias of dummy

-- Combat
---@class awful_unit
---@field combat boolean                                                         -- True if in combat
---@field incombat boolean                                                       -- Alias of combat
---@field affectingcombat boolean                                                -- Alias of combat
---@field isincombat boolean                                                     -- Alias of combat
---@field target awful_unit                                                      -- Unit's current target (wrapped)
---@field tar awful_unit                                                         -- Alias of target
---@field stealth boolean                                                        -- True if unit is stealthed

-- Resources
---@class awful_unit
---@field power number                                                           -- Primary power/resource value
---@field energy number                                                          -- Energy (Rogue, Monk, Druid)
---@field energyMax number                                                       -- Maximum energy
---@field comboPoints integer                                                    -- Combo points (Rogue, Druid)
---@field comboMax integer                                                       -- Maximum combo points

-- Movement / Position
---@class awful_unit
---@field position awful_vec3                                                    -- Current position {x, y, z}
---@field distance number                                                        -- Distance to local player in yards
---@field dist number                                                            -- Alias of distance
---@field moving boolean                                                         -- True if unit is moving
---@field ismoving boolean                                                       -- Alias of moving
---@field speed number                                                           -- Current movement speed
---@field movespeed number                                                       -- Alias of speed
---@field movementspeed number                                                   -- Alias of speed
---@field getspeed number                                                        -- Alias of speed
---@field timestandingstill number                                               -- Seconds standing still
---@field timesincedirectionchange number                                        -- Seconds since last direction change
---@field mounted boolean                                                        -- True if mounted
---@field ismounted boolean                                                      -- Alias of mounted
---@field combatreach number                                                     -- Bounding/combat reach radius

-- Casting / Channeling
---@class awful_unit
---@field casting boolean                                                        -- True if casting a spell
---@field castID integer                                                         -- Active cast spell ID (0 if not casting)
---@field castid integer                                                         -- Alias of castID
---@field castingid integer                                                      -- Alias of castID
---@field interruptible boolean                                                  -- True if active cast is interruptible
---@field interruptable boolean                                                  -- Alias of interruptible
---@field castint boolean                                                        -- Alias of interruptible
---@field castpct number                                                         -- Cast progress 0..1
---@field casttimeleft number                                                    -- Cast time remaining in seconds
---@field castremains number                                                     -- Alias of casttimeleft
---@field channeling boolean                                                     -- True if channeling a spell
---@field channel boolean                                                        -- Alias of channeling
---@field channelID integer                                                      -- Active channel spell ID (0 if not channeling)
---@field channelid integer                                                      -- Alias of channelID
---@field channelingid integer                                                   -- Alias of channelID
---@field channelremains number                                                  -- Channel time remaining in seconds
---@field channelpct number                                                      -- Channel progress 0..1
---@field channelstarttime number                                                -- Channel start time in seconds
---@field channelendtime number                                                  -- Channel end time in seconds
---@field casttimecomplete number                                                -- Seconds until cast completes

-- CC State (properties)
---@class awful_unit
---@field stunned boolean                                                        -- True if stunned
---@field isstunned boolean                                                      -- Alias
---@field stunremains number                                                     -- Stun remaining seconds
---@field incapacitated boolean                                                  -- True if incapacitated
---@field incapped boolean                                                       -- Alias
---@field incapremains number                                                    -- Incap remaining seconds
---@field rooted boolean                                                         -- True if rooted
---@field isrooted boolean                                                       -- Alias
---@field rootremains number                                                     -- Root remaining seconds
---@field silenced boolean                                                       -- True if silenced
---@field issilenced boolean                                                     -- Alias
---@field silenceremains number                                                  -- Silence remaining seconds
---@field disoriented boolean                                                    -- True if disoriented
---@field isdisoriented boolean                                                  -- Alias
---@field disorientremains number                                                -- Disorient remaining seconds
---@field slow boolean                                                           -- True if slowed
---@field slowed boolean                                                         -- Alias
---@field isslowed boolean                                                       -- Alias
---@field slowremains number                                                     -- Slow remaining seconds
---@field disarmed boolean                                                       -- True if disarmed
---@field isdisarmed boolean                                                     -- Alias
---@field disarmremains number                                                   -- Disarm remaining seconds

-- CC Immunity (properties)
---@class awful_unit
---@field immunestun boolean                                                     -- True if immune to stuns
---@field immunecc boolean                                                       -- True if immune to all CC
---@field immunemagic boolean                                                    -- True if immune to magic damage
---@field immunephysical boolean                                                 -- True if immune to physical damage
---@field immuneslow boolean                                                     -- True if immune to slows (or buff ID)
---@field magicimmunityremains number                                            -- Magic immunity remaining seconds
---@field physicalimmunityremains number                                         -- Physical immunity remaining seconds
---@field magicccimmune boolean                                                  -- True if immune to magic CC
---@field physicalccimmune boolean                                               -- True if immune to physical CC
---@field magicccimmunityremains number                                          -- Magic CC immunity remaining seconds
---@field physicalccimmunityremains number                                       -- Physical CC immunity remaining seconds

-- GCD (player units)
---@class awful_unit
---@field gcdremains number                                                      -- GCD remaining in seconds

-- Totem
---@class awful_unit
---@field uptime number                                                          -- Totem uptime in seconds

--------------------------------------------------------------------------------
-- awful_unit methods
--------------------------------------------------------------------------------

-- Buff / Debuff methods
---@class awful_unit
---@field buff fun(self: awful_unit, id: awful_buff_spec, criteria?: table, source?: awful_unit): boolean                  -- True if buff is present
---@field debuff fun(self: awful_unit, id: awful_buff_spec, criteria?: table, source?: awful_unit): boolean                -- True if debuff is present
---@field buffFrom fun(self: awful_unit, id_table: table, source?: awful_unit): boolean                                    -- True if any buff from table is present
---@field debuffFrom fun(self: awful_unit, id_table: table, source?: awful_unit): boolean                                  -- True if any debuff from table is present
---@field get_buff fun(self: awful_unit, id: awful_buff_spec, source?: awful_unit): awful_buff_data                        -- Get full buff data object
---@field get_debuff fun(self: awful_unit, id: awful_buff_spec, source?: awful_unit): awful_buff_data                      -- Get full debuff data object
---@field buffremains fun(self: awful_unit, id: awful_buff_spec): number                                                   -- Buff remaining time in seconds (0 if absent)
---@field buffRemains fun(self: awful_unit, id: awful_buff_spec): number                                                   -- Alias of buffremains
---@field debuffremains fun(self: awful_unit, id: awful_buff_spec): number                                                 -- Debuff remaining time in seconds (0 if absent)
---@field debuffRemains fun(self: awful_unit, id: awful_buff_spec): number                                                 -- Alias of debuffremains
---@field buffstacks fun(self: awful_unit, id: awful_buff_spec): integer                                                   -- Buff stack count (0 if absent)
---@field debuffstacks fun(self: awful_unit, id: awful_buff_spec): integer                                                 -- Debuff stack count (0 if absent)
---@field buffuptime fun(self: awful_unit, id: awful_buff_spec): number                                                    -- How long buff has been active in seconds
---@field debuffuptime fun(self: awful_unit, id: awful_buff_spec): number                                                  -- How long debuff has been active in seconds
---@field buffdesc fun(self: awful_unit, buff_ptr: userdata): string                                                       -- Get buff description text

-- CC methods
---@class awful_unit
---@field stun fun(self: awful_unit): boolean                                                                              -- Is stunned
---@field incap fun(self: awful_unit): boolean                                                                             -- Is incapacitated
---@field root fun(self: awful_unit): boolean                                                                              -- Is rooted
---@field silence fun(self: awful_unit): boolean                                                                           -- Is silenced
---@field disorient fun(self: awful_unit): boolean                                                                         -- Is disoriented
---@field bcc fun(self: awful_unit): boolean                                                                               -- In breakable CC
---@field bccremains fun(self: awful_unit): number                                                                         -- Breakable CC remaining seconds
---@field bccr fun(self: awful_unit): number                                                                               -- Alias of bccremains
---@field cc fun(self: awful_unit): boolean                                                                                -- In any CC
---@field ccremains fun(self: awful_unit): number                                                                          -- Any CC remaining seconds
---@field ccr fun(self: awful_unit): number                                                                                -- Alias of ccremains
---@field cccheck fun(self: awful_unit): boolean                                                                           -- Alias of cc
---@field iscc fun(self: awful_unit): boolean                                                                              -- Alias of cc
---@field isincc fun(self: awful_unit): boolean                                                                            -- Alias of cc

-- DR methods
---@class awful_unit
---@field stundr fun(self: awful_unit): number                                                                             -- Stun DR multiplier 0..1 (1.0 = full, 0.0 = immune)
---@field sdr fun(self: awful_unit): number                                                                                -- Alias of stundr
---@field incapdr fun(self: awful_unit): number                                                                            -- Incapacitate DR multiplier 0..1
---@field idr fun(self: awful_unit): number                                                                                -- Alias of incapdr
---@field rootdr fun(self: awful_unit): number                                                                             -- Root DR multiplier 0..1
---@field rdr fun(self: awful_unit): number                                                                                -- Alias of rootdr
---@field silencedr fun(self: awful_unit): number                                                                          -- Silence DR multiplier 0..1
---@field ddr fun(self: awful_unit): number                                                                                -- Disorient DR multiplier 0..1

-- Distance / Position methods
---@class awful_unit
---@field DistanceTo fun(self: awful_unit, other: awful_unit): number                                                      -- Distance to another unit in yards
---@field distanceto fun(self: awful_unit, other: awful_unit): number                                                      -- Alias of DistanceTo
---@field distancefrom fun(self: awful_unit, other: awful_unit): number                                                    -- Alias of DistanceTo
---@field distance_from_position fun(self: awful_unit, pos: awful_vec3): number                                            -- Distance to a world position
---@field los fun(self: awful_unit): boolean                                                                               -- True if LOS to local player
---@field losOf fun(self: awful_unit, other: awful_unit): boolean                                                          -- True if LOS to another unit
---@field los_from_position fun(self: awful_unit, pos: awful_vec3): boolean                                                -- True if LOS from position to this unit
---@field inrange fun(self: awful_unit, spell_id: integer): boolean                                                        -- True if spell_id is in range
---@field facing fun(self: awful_unit, other: awful_unit, angle_degrees?: number): boolean                                 -- True if facing another unit
---@field facingtowards fun(self: awful_unit, other: awful_unit): boolean                                                  -- Alias of facing
---@field predictPosition fun(self: awful_unit, elapsed?: number): awful_vec3|nil                                          -- Predict position after elapsed seconds
---@field predictDistance fun(self: awful_unit, time: number, other?: awful_unit): number                                  -- Predict distance at future time
---@field predictDistanceLiteral fun(self: awful_unit, time: number, other?: awful_unit): number                           -- Literal predicted distance
---@field GetPosition fun(self: awful_unit): (number, number, number)                                                      -- Returns x, y, z as separate values
---@field get_role fun(self: awful_unit): string                                                                           -- Returns "HEALER", "TANK", "DAMAGER", etc.

-- Cooldown methods
---@class awful_unit
---@field cd fun(self: awful_unit, spell_id: integer): number                                                              -- Cooldown remaining in seconds for spell
---@field cooldown fun(self: awful_unit, spell_id: integer): number                                                        -- Alias of cd
---@field used fun(self: awful_unit, spell_id: integer|integer[], timeframe?: number): boolean                             -- True if spell was recently used
---@field recentlycast fun(self: awful_unit, spell_id: integer|integer[], timeframe?: number): boolean                     -- Alias of used
---@field lastcast fun(self: awful_unit): integer|nil                                                                      -- Last cast spell ID

-- Talent
---@class awful_unit
---@field hasTalent fun(self: awful_unit, spell_id: integer): boolean                                                      -- True if spell/talent is learned

-- Attackers
---@class awful_unit
---@field v2attackers fun(self: awful_unit, range?: number): (integer, integer, integer, integer)                          -- Returns (total, melee, ranged, count)

-- Visibility
---@class awful_unit
---@field canbeinterrupted fun(self: awful_unit): boolean                                                                  -- True if enemies nearby can interrupt

--------------------------------------------------------------------------------
-- awful_spell (created via awful.spell)
--------------------------------------------------------------------------------

-- Info
---@class awful_spell
---@field name fun(self: awful_spell): string                                                                              -- Spell name
---@field spellid fun(self: awful_spell): integer                                                                          -- Spell ID
---@field get_id fun(self: awful_spell): integer                                                                           -- Alias of spellid
---@field range fun(self: awful_spell): number                                                                             -- Spell max range in yards
---@field casttime fun(self: awful_spell): number                                                                          -- Cast time in milliseconds

-- Cooldown / Charges
---@class awful_spell
---@field cd fun(self: awful_spell): number                                                                                -- Cooldown remaining in seconds
---@field cooldown fun(self: awful_spell): number                                                                          -- Alias of cd
---@field cdduration fun(self: awful_spell): number                                                                        -- Full cooldown duration in seconds
---@field cdstart fun(self: awful_spell): number                                                                           -- When cooldown started (game time seconds)
---@field charges fun(self: awful_spell): integer                                                                          -- Current charges
---@field maxcharges fun(self: awful_spell): integer                                                                       -- Maximum charges
---@field nextchargecd fun(self: awful_spell): number                                                                      -- Next charge cooldown remaining in seconds

-- Availability
---@class awful_spell
---@field usable fun(self: awful_spell): boolean                                                                           -- True if spell is usable (resources, not on CD)
---@field known fun(self: awful_spell): boolean                                                                            -- True if spell is learned
---@field prevgcd fun(self: awful_spell): boolean                                                                          -- True if was previous GCD spell
---@field lastcast fun(self: awful_spell): boolean                                                                         -- Alias of prevgcd
---@field queued fun(self: awful_spell): boolean                                                                           -- True if currently queued
---@field isqueued fun(self: awful_spell): boolean                                                                         -- Alias of queued

-- GCD
---@class awful_spell
---@field gcdremains fun(self: awful_spell): number                                                                        -- GCD remaining in seconds
---@field gcd fun(self: awful_spell): number                                                                               -- GCD value for this spell

-- Cost
---@class awful_spell
---@field cost fun(self: awful_spell): awful_smart_cost                                                                    -- Spell resource cost (acts as number, also has .mana, .energy, etc.)

-- Targeting / Range
---@class awful_spell
---@field Castable fun(self: awful_spell, unit: awful_unit, skip_facing?: boolean, skip_range?: boolean): boolean          -- True if spell can be cast on unit (checks CD, range, LOS, facing, usable)
---@field in_range_from fun(self: awful_spell, pos: awful_vec3, target: userdata): boolean                                -- True if spell in range from position to target
---@field los_from fun(self: awful_spell, pos: awful_vec3, target: userdata): boolean                                     -- True if LOS from position to target

-- Recent usage
---@class awful_spell
---@field recentlyused fun(self: awful_spell, timeframe?: number): boolean                                                 -- True if used within timeframe seconds (default ~2s)
---@field usedrecently fun(self: awful_spell, timeframe?: number): boolean                                                 -- Alias of recentlyused
---@field recent fun(self: awful_spell, timeframe?: number): boolean                                                       -- Alias of recentlyused

-- Casting
---@class awful_spell
---@field Cast fun(self: awful_spell, target: awful_unit, priority?: integer, message?: string, allow_movement?: boolean): boolean          -- Queue spell cast on target
---@field CastAt fun(self: awful_spell, position: awful_vec3, priority?: integer, message?: string, allow_movement?: boolean): boolean      -- Queue spell cast at position
---@field Queue fun(self: awful_spell, target: awful_unit, priority?: integer, message?: string, allow_movement?: boolean): boolean         -- Alias of Cast
---@field CastFast fun(self: awful_spell, target: awful_unit, priority?: integer, message?: string, allow_movement?: boolean): boolean      -- Fast cast with throttle bypass
---@field AoECast fun(self: awful_spell, target: awful_unit, priority?: integer, message?: string, allow_movement?: boolean): boolean       -- AoE cast with hit prediction
---@field AoECastFast fun(self: awful_spell, target: awful_unit, priority?: integer, message?: string, allow_movement?: boolean): boolean   -- Fast AoE cast
---@field AoECastPosition fun(self: awful_spell, pos: awful_vec3, priority?: integer, message?: string, allow_movement?: boolean): boolean  -- AoE cast at specific position
---@field AoECastPositionFast fun(self: awful_spell, pos: awful_vec3, priority?: integer, message?: string, allow_movement?: boolean): boolean -- Fast AoE at position
---@field cancelqueue fun(self: awful_spell): boolean                                                                      -- Cancel queued spell
---@field cancel_buff fun(self: awful_spell): boolean                                                                      -- Cancel spell buff on player
---@field petcast fun(self: awful_spell, target?: awful_unit): boolean                                                     -- Pet cast on target
---@field petcastposition fun(self: awful_spell, position: awful_vec3): boolean                                            -- Pet cast at position

-- Callbacks
---@class awful_spell
---@field Callback fun(self: awful_spell, name?: string, fn?: fun(): boolean): boolean                                     -- Register or execute spell callback
---@field callback fun(self: awful_spell, name?: string, fn?: fun(): boolean): boolean                                     -- Alias of Callback
---@field HookCallback fun(self: awful_spell, callback: fun()): nil                                                        -- Register hook callback

-- Prediction constants
---@class awful_spell
---@field prediction { most_hits: string, accuracy: string }                                                               -- Prediction mode constants
---@field geometry { circle: string, cone: string, rectangle: string }                                                     -- Geometry type constants
---@field healing { enabled: boolean }                                                                                     -- Healing mode flag
---@field casting { include_player: boolean, exclude_player: boolean }                                                     -- Casting filter flags

--------------------------------------------------------------------------------
-- awful_smart_cost (returned by spell:cost())
-- Acts as a number via metamethods. Also has named resource fields.
--------------------------------------------------------------------------------

---@class awful_smart_cost
---@field mana number                     -- Mana cost
---@field energy number                   -- Energy cost
---@field rage number                     -- Rage cost
---@field focus number                    -- Focus cost
---@field runic_power number              -- Runic power cost
---@field combo_points number             -- Combo point cost
---@field holy_power number               -- Holy power cost
---@field soul_shards number              -- Soul shard cost
---@field chi number                      -- Chi cost
---@operator add(number): number
---@operator sub(number): number
---@operator mul(number): number
---@operator div(number): number

--------------------------------------------------------------------------------
-- awful_item (created via awful.item)
--------------------------------------------------------------------------------

---@class awful_item
---@field use fun(self: awful_item): boolean                                                                               -- Use item (self-target)
---@field usable fun(self: awful_item): boolean                                                                            -- Alias of use
---@field useOn fun(self: awful_item, target: awful_unit|userdata): boolean                                                -- Use item on target
---@field useFromSlot fun(self: awful_item, slot_id: integer): boolean                                                     -- Use item from inventory slot
---@field useAtPosition fun(self: awful_item, position: awful_vec3): boolean                                               -- Use item at world position
---@field cd fun(self: awful_item): number                                                                                 -- Item cooldown remaining in seconds
---@field cooldown fun(self: awful_item): number                                                                           -- Alias of cd
---@field equipped fun(self: awful_item): boolean                                                                          -- True if item is equipped
---@field inInventory fun(self: awful_item): boolean                                                                       -- True if item is in inventory
---@field count fun(self: awful_item): integer                                                                             -- Item count in inventory

--------------------------------------------------------------------------------
-- awful_collection (returned by awful.enemies, awful.allies, etc.)
-- Supports ipairs() iteration: for _, unit in ipairs(awful.enemies) do ... end
--------------------------------------------------------------------------------

---@class awful_collection
---@field count integer                                                          -- Number of units in collection
---@field lowest awful_unit                                                      -- Unit with lowest HP in collection
---@field first awful_unit                                                       -- First unit in collection
---@field alive awful_collection                                                 -- Sub-collection of alive units
---@field dead awful_collection                                                  -- Sub-collection of dead units
---@field enemy awful_collection                                                 -- Sub-collection of enemy units
---@field friend awful_collection                                                -- Sub-collection of friendly units
---@field exists awful_collection                                                -- Sub-collection of existing (valid) units
---@field attackable awful_collection                                            -- Sub-collection of attackable units
---@field los awful_collection                                                   -- Sub-collection of units with LOS
---@field sort_distance awful_collection                                         -- Collection sorted by distance to player

---@class awful_collection
---@field within fun(self: awful_collection, range: number): awful_collection                                              -- Filter to units within range
---@field loop fun(self: awful_collection, callback: fun(unit: awful_unit)): awful_collection                              -- Iterate all units
---@field forEach fun(self: awful_collection, callback: fun(unit: awful_unit)): nil                                        -- Alias of loop
---@field filter fun(self: awful_collection, predicate: fun(unit: awful_unit): boolean): awful_collection                  -- Filter by predicate
---@field find fun(self: awful_collection, predicate: fun(unit: awful_unit): boolean): awful_unit|nil                      -- Find first matching unit
---@field sort fun(self: awful_collection, func: fun(a: awful_unit, b: awful_unit): boolean): awful_collection             -- Sort collection
---@field cone fun(self: awful_collection, spell_id_or_obj: integer|awful_spell): awful_collection                         -- Cone-shaped spatial filter
---@field circle fun(self: awful_collection, spell_id_or_obj: integer|awful_spell): awful_collection                       -- Circle-shaped spatial filter
---@field rectangle fun(self: awful_collection, spell_id_or_obj: integer|awful_spell): awful_collection                    -- Rectangle-shaped spatial filter
---@field around fun(self: awful_collection, unit: awful_unit, range: number): awful_collection                            -- Units around specific unit

--------------------------------------------------------------------------------
-- awful_delay (returned by awful.delay)
--------------------------------------------------------------------------------

---@class awful_delay
---@field now fun(self: awful_delay): boolean                                    -- True if delay has elapsed
---@field get fun(self: awful_delay): number                                     -- Get remaining delay time
---@field after fun(self: awful_delay, callback: fun()): nil                     -- Execute callback after delay

--------------------------------------------------------------------------------
-- awful_context (available as awful.context)
--------------------------------------------------------------------------------

---@class awful_context
---@field set fun(self: awful_context, key: string, value: boolean|number|string|table): boolean|number|string|table       -- Set context value, returns it
---@field get fun(self: awful_context, key: string, default?: boolean|number|string|table): boolean|number|string|table    -- Get context value with optional default
---@field with fun(self: awful_context, key: string, value: boolean|number|string|table, func: fun()): nil                 -- Execute function with temporary context
---@field reset fun(self: awful_context): nil                                                                              -- Clear all context values

--------------------------------------------------------------------------------
-- awful_dr (available as awful.dr)
--------------------------------------------------------------------------------

---@class awful_dr_module
---@field dr_lists table<integer, string>                                        -- Spell ID -> DR category name mapping
---@field drs table<string, table<string, { diminished: number, reset: number }>> -- GUID -> { category -> DR data }
---@field enabled boolean                                                        -- Enable/disable DR tracking
---@field game_version string                                                    -- Detected game version string
---@field is_midnight boolean                                                    -- True if Midnight expansion
---@field is_tbc boolean                                                         -- True if TBC
---@field is_mop boolean                                                         -- True if MoP
---@field DR_DECAY number                                                        -- DR reset time in seconds (17 for Midnight, 18 for others)
---@field DR_IMMUNE_THRESHOLD number                                             -- Immunity threshold (2 for Midnight, 3 for others)
---@field get_categories fun(self: awful_dr_module): table<string, integer[]>                                              -- Get active DR categories for expansion
---@field get_dr fun(self: awful_dr_module, unit: userdata, drCat: string, get_wrapped_unit: fun(u: userdata): awful_unit): number -- Get DR value 0..1
---@field dr_remains fun(self: awful_dr_module, unit: userdata, drCat: string, get_wrapped_unit: fun(u: userdata): awful_unit): number -- Seconds until DR resets
---@field reset fun(self: awful_dr_module): nil                                                                            -- Reset all DR data

--------------------------------------------------------------------------------
-- awful_events (available as awful.events)
--------------------------------------------------------------------------------

---@class awful_events
---@field register fun(self: awful_events, event: string, spellId: integer, callback: fun(...)): fun()                    -- Register event handler, returns unregister function
---@field onSpellCast fun(self: awful_events, spellId: integer, callback: fun(...)): fun()                                -- Register spell cast handler, returns unregister

--------------------------------------------------------------------------------
-- awful_api (the main awful table returned by require)
--------------------------------------------------------------------------------

-- Utility functions
---@class awful_api
---@field time fun(): number                                                                                               -- Game time in seconds
---@field buffer fun(): number                                                                                             -- Network latency in seconds
---@field ping fun(): number                                                                                               -- Alias of buffer
---@field delay fun(min?: number, max?: number): awful_delay                                                               -- Create delay timer
---@field log fun(msg: string): nil                                                                                        -- Log message with [awful] prefix
---@field warn fun(msg: string): nil                                                                                       -- Log warning with [awful] prefix
---@field error fun(msg: string): nil                                                                                      -- Log error with [awful] prefix
---@field bin fun(condition: boolean): integer                                                                              -- Convert boolean to 0 or 1
---@field get_table fun(size?: integer): table                                                                             -- Get reusable table from pool
---@field release_table fun(tbl: table, expected_size?: integer): nil                                                      -- Return table to pool
---@field stopcast fun(): boolean                                                                                          -- Stop current cast/channel
---@field stopattack fun(): nil                                                                                            -- Stop auto-attacking
---@field settarget fun(unit: awful_unit|userdata): nil                                                                    -- Set player target
---@field face fun(unit_or_angle: awful_unit|userdata|number): nil                                                         -- Face unit or direction (radians)
---@field controlmovement fun(x: number, y: number): nil                                                                   -- Control player movement
---@field get_instance_id fun(): integer                                                                                   -- Get current instance ID
---@field get_map_id fun(): integer                                                                                        -- Get current map ID
---@field screensize fun(): (number, number)                                                                               -- Get screen width and height
---@field has_state_reset fun(): (boolean, string|nil)                                                                     -- Detect map/instance/arena changes

-- Context
---@class awful_api
---@field context awful_context                                                                                            -- Context system for cross-callback data

-- Callback registration
---@class awful_api
---@field on_update fun(fn: fun()): nil                                                                                    -- Register update callback (runs each frame)
---@field on_spell_cast fun(fn: fun(spell_id: integer, source_guid: string)): nil                                          -- Register spell cast callback
---@field pre_tick fun(fn: fun()): fun()                                                                                   -- Register pre-tick handler, returns unregister function
---@field events awful_events                                                                                              -- Event registration system

-- Unit creation
---@class awful_api
---@field Unit fun(raw_unit: userdata): awful_unit                                                                         -- Create unit wrapper from raw game object
---@field WrapUnit fun(raw_unit: userdata): awful_unit                                                                     -- Alias of Unit

-- Spell creation
---@class awful_api
---@field spell fun(spell_id: integer|integer[]): awful_spell                                                              -- Create spell object from ID or ID array
---@field define fun(spell_def: table): awful_spell                                                                        -- Create spell from definition table
---@field hookSpellCallbacks fun(spell: awful_spell): nil                                                                  -- Hook spell callbacks
---@field FakeCast fun(spell_id: integer, target: awful_unit): boolean                                                     -- Simulate a spell cast
---@field clear_spell_queue fun(): nil                                                                                     -- Clear the spell queue
---@field prepare_prediction_data fun(): nil                                                                               -- Prepare prediction data for current frame

-- Item creation
---@class awful_api
---@field item fun(id: integer): awful_item                                                                                -- Create item object from ID
---@field useInventorySlot fun(slot_id: integer): boolean                                                                  -- Use item from inventory slot

-- Drawing / Graphics
---@class awful_api
---@field traceline fun(start: awful_vec3|awful_unit, finish: awful_vec3|awful_unit, flags?: integer): table                -- Raycast between two points
---@field losLiteral fun(start: awful_vec3|awful_unit, finish: awful_vec3|awful_unit): table                                -- Literal LOS check
---@field drawcircle fun(position: awful_vec3|awful_unit, radius?: number, col?: userdata, thickness?: number, fade?: number): nil -- Draw 3D circle
---@field drawline fun(start: awful_vec3|awful_unit, finish: awful_vec3|awful_unit, col?: userdata, thickness?: number): nil       -- Draw 3D line
---@field drawtext fun(text: string, position: awful_vec3|awful_unit, size?: number, col?: userdata): nil                         -- Draw 3D text at world position
---@field drawtext2d fun(text: string, position: table, size?: number, col?: userdata): nil                                      -- Draw 2D text at screen position
---@field drawrect fun(start: table, width: number, height: number, col?: userdata, thickness?: number, rounding?: number): nil  -- Draw 2D rectangle outline
---@field drawrectfilled fun(start: table, width: number, height: number, col?: userdata, rounding?: number): nil                -- Draw filled 2D rectangle
---@field worldtoscreen fun(position: awful_vec3|awful_unit): table|nil                                                          -- Convert world position to screen coords
---@field isonscreen fun(position: awful_vec3|awful_unit): boolean                                                               -- True if position is visible on screen
---@field cursorposition fun(): awful_vec3                                                                                       -- Get cursor world position
---@field isMenuOpen fun(): boolean                                                                                              -- True if game menu is open

-- GCD functions
---@class awful_api
---@field gcd fun(): number                                                                                                -- GCD duration based on haste in seconds
---@field gcdRemains fun(): number                                                                                         -- GCD remaining in seconds
---@field gcdremains fun(): number                                                                                         -- Alias of gcdRemains

-- DR system
---@class awful_api
---@field dr awful_dr_module                                                                                               -- DR tracking module
---@field dr_lists table<integer, string>                                                                                  -- Spell ID -> DR category mapping

-- PvP
---@class awful_api
---@field is_healer_spec fun(raw_unit: userdata): boolean                                                                  -- Check if raw unit is healer spec
---@field class_names table<integer, string>                                                                               -- Class ID -> class name mapping
---@field get_battlefield_state fun(): integer                                                                             -- Get current battlefield state enum

-- Unit collections (iterable with ipairs)
---@class awful_api
---@field enemies awful_collection                                                                                         -- All enemy units
---@field allies awful_collection                                                                                          -- All allied units
---@field friends awful_collection                                                                                         -- Alias of allies
---@field pets awful_collection                                                                                            -- All pet units
---@field friendlypets awful_collection                                                                                    -- Friendly pet units
---@field enemypets awful_collection                                                                                       -- Enemy pet units
---@field totems awful_collection                                                                                          -- Totem objects
---@field group awful_collection                                                                                           -- Party/raid group members
---@field fgroup awful_collection                                                                                          -- Full group members
---@field fullgroup awful_collection                                                                                       -- Alias of fgroup
---@field units awful_collection                                                                                           -- All units
---@field objects awful_collection                                                                                         -- All objects
---@field arena awful_collection                                                                                           -- Arena enemy frames

-- Dynamic unit access (via metatable)
---@class awful_api
---@field player awful_unit                                                                                                -- Local player
---@field target awful_unit                                                                                                -- Current target
---@field focus awful_unit                                                                                                 -- Focus target
---@field mouseover awful_unit                                                                                             -- Mouseover unit
---@field pet awful_unit                                                                                                   -- Player's pet
---@field healer awful_unit                                                                                                -- Closest friendly healer
---@field enemyHealer awful_unit                                                                                           -- Closest enemy healer
---@field arena1 awful_unit                                                                                                -- Arena enemy 1
---@field arena2 awful_unit                                                                                                -- Arena enemy 2
---@field arena3 awful_unit                                                                                                -- Arena enemy 3
---@field party1 awful_unit                                                                                                -- Party member 1
---@field party2 awful_unit                                                                                                -- Party member 2
---@field party3 awful_unit                                                                                                -- Party member 3
---@field party4 awful_unit                                                                                                -- Party member 4
---@field party5 awful_unit                                                                                                -- Party member 5

-- Shared modules
---@class awful_api
---@field color table                                                                                                      -- Color utilities (require("common/color"))
---@field enums table                                                                                                      -- Engine enums (require("common/enums"))

-- Internal state (advanced usage)
---@class awful_api
---@field __active_casts table<string, table>                                                                              -- Active cast tracking by GUID
---@field __lockouts table<string, table>                                                                                  -- Spell lockout tracking by GUID
---@field table_pool table                                                                                                 -- Table pool reference
