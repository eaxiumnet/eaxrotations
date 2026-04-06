# Quests | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/quests

## Overview

The core.quests module provides functions for interacting with quest dialogs, the quest log, gossip frames, trainer services, and item information. These functions cover the full lifecycle of quest management from accepting quests at NPCs to tracking and completing them.

## Quest Dialog Functions

### core.quests.accept_quest

Syntax

```
core.quests.accept_quest() -> nil
```

Description
Accepts the current quest dialog. Call this when the quest detail frame is shown after selecting a quest from an NPC.

### core.quests.complete_quest

Syntax

```
core.quests.complete_quest() -> nil
```

Description
Completes the current quest dialog. Use this when turning in a quest that has no reward choices, or after selecting a reward with get_quest_reward.

### core.quests.get_quest_reward

Syntax

```
core.quests.get_quest_reward(choice: integer) -> nil
```

Parameters

choice: integer - The index of the reward choice to select.

Description
Selects a reward choice and completes the quest. Use this for quests that offer multiple reward options.

### core.quests.get_gossip_options

Syntax

```
core.quests.get_gossip_options() -> table
```

Returns

table: An array of gossip options available from the NPC.

Description
Returns the list of gossip options available from the currently open gossip frame.

### core.quests.select_gossip_option

Syntax

```
core.quests.select_gossip_option(id: integer) -> nil
```

Parameters

id: integer - The gossip option ID to select.

Description
Selects a gossip option from the NPC dialog.

### core.quests.close_gossip

Syntax

```
core.quests.close_gossip() -> nil
```

Description
Closes the gossip frame.

### core.quests.is_gossip_frame_shown

Syntax

```
core.quests.is_gossip_frame_shown() -> boolean
```

Returns

boolean: true if the gossip frame is currently open.

Description
Checks whether the gossip frame is currently displayed.

## Quest Log Functions

### core.quests.get_num_quest_log_entries

Syntax

```
core.quests.get_num_quest_log_entries() -> integer
```

Returns

integer: The number of quest log entries (including headers).

Description
Returns the total number of entries in the quest log. This includes both zone headers and quest entries.

### core.quests.get_quest_log_title

Syntax

```
core.quests.get_quest_log_title(index: integer) -> table
```

Parameters

index: integer - The quest log entry index.

Returns

table: A table containing quest log entry details.

| Field | Type | Description |
|-------|------|-------------|
| title | string | The title of the quest or header |
| level | integer | The quest level |
| quest_id | integer | The unique quest ID |
| is_header | boolean | Whether this entry is a zone header |
| is_complete | boolean | Whether the quest is complete |

Description
Returns detailed information about a quest log entry. Use is_header to distinguish zone headers from actual quests.

Example Usage

```lua
local num_entries = core.quests.get_num_quest_log_entries()
for i = 1, num_entries do
    local info = core.quests.get_quest_log_title(i)
    if not info.is_header then
        local status = info.is_complete and "COMPLETE" or "In Progress"
        core.log(string.format("[%d] %s (Lv %d) - %s", info.quest_id, info.title, info.level, status))
    end
end
```

### core.quests.is_quest_flagged_completed

Syntax

```
core.quests.is_quest_flagged_completed(quest_id: integer) -> boolean
```

Parameters

quest_id: integer - The quest ID to check.

Returns

boolean: true if the quest was ever completed by this character.

Description
Checks whether a quest has been completed at any point in the past. This queries the server's completion history, not the current quest log.

### core.quests.is_on_quest

Syntax

```
core.quests.is_on_quest(quest_id: integer) -> boolean
```

Parameters

quest_id: integer - The quest ID to check.

Returns

boolean: true if the quest is currently in the quest log.

Description
Checks whether a specific quest is currently active in the player's quest log.

## Trainer Functions

### core.quests.get_num_trainer_services

Syntax

```
core.quests.get_num_trainer_services() -> integer
```

Returns

integer: The number of services available from the trainer.

Description
Returns the number of training services available from the currently open trainer window.

### core.quests.get_trainer_service_info

Syntax

```
core.quests.get_trainer_service_info(index: integer) -> table
```

Parameters

index: integer - The index of the trainer service.

Returns

table: A table containing the trainer service details.

Description
Returns detailed information about a specific trainer service at the given index.

### core.quests.buy_trainer_service

Syntax

```
core.quests.buy_trainer_service(index: integer) -> nil
```

Parameters

index: integer - The index of the trainer service to purchase.

Description
Purchases a trainer service at the given index.

## Complete Examples

### Auto-Accept and Turn In Quests at NPC

```lua
local function handle_npc_quests()
    -- Check if gossip frame is open
    if not core.quests.is_gossip_frame_shown() then
        return
    end
    
    -- First, turn in any completable active quests
    local active = core.quests.get_gossip_active_quests()
    for _, quest in ipairs(active) do
        core.quests.select_gossip_active_quest(quest.quest_id)
        core.quests.complete_quest()
        return -- Process one at a time
    end
    
    -- Then, accept any available quests
    local available = core.quests.get_gossip_available_quests()
    for _, quest in ipairs(available) do
        core.quests.select_gossip_available_quest(quest.quest_id)
        core.quests.accept_quest()
        return -- Process one at a time
    end
end
```

### Quest Progress Tracker

```lua
local function print_quest_progress()
    local num_entries = core.quests.get_num_quest_log_entries()
    for i = 1, num_entries do
        local info = core.quests.get_quest_log_title(i)
        if not info.is_header then
            core.log(string.format("[%d] %s", info.quest_id, info.title))
            local num_objectives = core.quests.get_num_quest_leader_boards(i)
            for j = 1, num_objectives do
                local text = core.quests.get_quest_log_leader_board(j, i)
                core.log("    " .. text)
            end
        end
    end
end
```
