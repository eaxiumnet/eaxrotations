# Delves | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/delves

## Overview

API for interacting with The War Within Delves system - enter, complete, and leave delves.

## Delve Functions

### core.delves.enter

Syntax

```
core.delves.enter(delve_id: number): boolean
```

Parameters
delve_id: number - The delve ID to enter.

Returns

boolean - True if delve entry was initiated.

Description
Enters a delve instance by ID.

### core.delves.leave

Syntax

```
core.delves.leave(): boolean
```

Returns

boolean - True if leaving was initiated.

Description
Leaves the current delve.

### core.delves.is_in_delve

Syntax

```
core.delves.is_in_delve(): boolean
```

Returns

boolean - True if currently in a delve.

Description
Checks if the player is currently inside a delve.

### core.delves.get_current_delve

Syntax

```
core.delves.get_current_delve(): table
```

Returns

table - Current delve information.

Description
Gets information about the current delve.

### core.delves.get_available_delves

Syntax

```
core.delves.get_available_delves(): table
```

Returns

table - Array of available delve IDs.

Description
Gets all available delve IDs for the player.

### core.delves.get_delve_info

Syntax

```
core.delves.get_delve_info(delve_id: number): table
```

Parameters
delve_id: number - The delve ID.

Returns

table - Delve information including rewards.

Description
Gets detailed information about a specific delve.

### core.delves.complete

Syntax

```
core.delves.complete(): boolean
```

Returns

boolean - True if delve was completed.

Description
Completes the current delve (claims rewards).

### core.delves.teleport_out

Syntax

```
core.delves.teleport_out(): boolean
```

Returns

boolean - True if teleport was initiated.

Description
Teleports out of the current delve to the entrance.

### core.delves.is_story_complete

Syntax

```
core.delves.is_story_complete(delve_id: number): boolean
```

Parameters
delve_id: number - The delve ID.

Returns

boolean - True if delve story is complete.

Description
Checks if the delve story has been completed.

### core.delves.get_rewards

Syntax

```
core.delves.get_rewards(delve_id: number): table
```

Parameters
delve_id: number - The delve ID.

Returns

table - Array of potential rewards.

Description
Gets the rewards available from a delve.
