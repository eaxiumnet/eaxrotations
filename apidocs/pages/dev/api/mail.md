# Mail | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/mail

## Overview

The core.mail module provides functions for interacting with the in-game mail system. This includes checking the inbox, reading mail, taking attachments and money, sending mail, and managing inbox items.

## Inbox Functions

### core.mail.check_inbox

Syntax

```
core.mail.check_inbox() -> nil
```

Description
Checks the inbox for new mail. Call this to refresh the inbox state from the server.

### core.mail.get_num_inbox_items

Syntax

```
core.mail.get_num_inbox_items() -> integer
```

Returns

integer: The number of items currently in the inbox.

Description
Returns the number of mail items in the inbox.

### core.mail.get_inbox_header_info

Syntax

```
core.mail.get_inbox_header_info(index: integer) -> mail_header_info
```

Parameters

index: integer - The inbox item index.

Returns

mail_header_info: A table containing the mail header details.

| Property | Type | Description |
|----------|------|-------------|
| package_icon | string | Icon path for the package attachment |
| stationery_icon | string | Icon path for the mail stationery |
| sender | string | The name of the sender |
| subject | string | The mail subject line |
| money | number | Amount of money attached (in copper) |
| cod_amount | number | Cash-on-delivery amount (in copper) |
| days_left | number | Days remaining before the mail expires |
| item_count | integer | Number of item attachments |
| was_read | boolean | Whether the mail has been read |
| was_returned | boolean | Whether the mail was returned to sender |
| text_created | boolean | Whether the mail body text has been created |
| can_reply | boolean | Whether the mail can be replied to |
| is_gm | boolean | Whether the mail is from a Game Master |

Description
Returns the header information for a mail item at the specified inbox index.

### core.mail.take_inbox_item

Syntax

```
core.mail.take_inbox_item(index: integer, item_index: integer) -> nil
```

Parameters

index: integer - The inbox item index.
item_index: integer - The attachment index to take.

Description
Takes a specific item attachment from a mail and places it in the player's inventory.

### core.mail.take_inbox_money

Syntax

```
core.mail.take_inbox_money(index: integer) -> nil
```

Parameters

index: integer - The inbox item index.

Description
Takes the money attached to a mail at the specified inbox index.

### core.mail.auto_loot_mail_item

Syntax

```
core.mail.auto_loot_mail_item(index: integer) -> nil
```

Parameters

index: integer - The inbox item index.

Description
Automatically loots all item attachments and money from a mail at the specified inbox index.

### core.mail.delete_inbox_item

Syntax

```
core.mail.delete_inbox_item(index: integer) -> nil
```

Parameters

index: integer - The inbox item index.

Description
Deletes a mail from the inbox. The mail must have no remaining attachments or money.

### core.mail.inbox_item_can_delete

Syntax

```
core.mail.inbox_item_can_delete(index: integer) -> boolean
```

Parameters

index: integer - The inbox item index.

Returns

boolean: true if the mail can be deleted.

Description
Checks whether a mail at the specified inbox index can be deleted.

## Sending Functions

### core.mail.send_mail

Syntax

```
core.mail.send_mail(recipient: string, subject?: string, body?: string) -> nil
```

Parameters

recipient: string - The character name to send mail to.
subject: string (optional) - The mail subject line.
body: string (optional) - The mail body text.

Description
Sends a mail to the specified recipient. Attach money before calling this using set_send_mail_money. Items can be attached via the game's drag-and-drop interface before sending.

Example Usage

```lua
core.mail.set_send_mail_money(500000) -- 50 gold in copper
core.mail.send_mail("Arthas", "Weekly Gold", "Here is your share from this week's raids.")
```

### core.mail.set_send_mail_money

Syntax

```
core.mail.set_send_mail_money(money: integer) -> nil
```

Parameters

money: integer - The amount of money to attach in copper.

Description
Sets the amount of money to attach to the outgoing mail. Call this before send_mail. The amount is specified in copper (1 gold = 10000 copper).

## Utility Functions

### core.mail.has_new_mail

Syntax

```
core.mail.has_new_mail() -> boolean
```

Returns

boolean: true if there is new unread mail.

Description
Checks whether the player has new unread mail. This can be checked without opening the mailbox.

## Complete Examples

### Mail Processing Workflow

```lua
local function process_all_mail()
    -- Refresh the inbox
    core.mail.check_inbox()
    local num_mail = core.mail.get_num_inbox_items()
    if num_mail == 0 then
        core.log("Inbox is empty")
        return
    end
    
    core.log(string.format("Processing %d mail items...", num_mail))
    
    -- Process mail from last to first (indices shift when items are removed)
    for i = num_mail, 1, -1 do
        local header = core.mail.get_inbox_header_info(i)
        core.log(string.format("[%d] From: %s - %s", i, header.sender, header.subject))
        
        -- Take money if present
        if header.money > 0 then
            local gold = math.floor(header.money / 10000)
            local silver = math.floor((header.money % 10000) / 100)
            core.log(string.format("  Collecting %dg %ds", gold, silver))
            core.mail.take_inbox_money(i)
        end
        
        -- Take all item attachments
        if header.item_count > 0 then
            core.log(string.format("  Looting %d attachments", header.item_count))
            core.mail.auto_loot_mail_item(i)
        end
        
        -- Delete the mail if possible
        if core.mail.inbox_item_can_delete(i) then
            core.mail.delete_inbox_item(i)
            core.log("  Deleted")
        end
    end
    
    core.log("Mail processing complete")
end
```

### Send Gold to Alt Character

```lua
local function send_gold_to_alt(alt_name, gold_amount)
    local copper = gold_amount * 10000
    local postage = core.mail.get_send_mail_price()
    core.log(string.format("Sending %dg to %s (postage: %d copper)", gold_amount, alt_name, postage))
    
    core.mail.set_send_mail_money(copper)
    core.mail.send_mail(alt_name, "Gold Transfer", "Automated gold transfer.")
end

-- Usage
send_gold_to_alt("MyAltChar", 500)
```
