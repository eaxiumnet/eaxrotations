# Auction House | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/auction-house

## Overview

The core.auction_house module provides functions for interacting with the World of Warcraft auction house. This includes scanning and replicating auction data, searching for items, managing owned auctions, posting new listings, purchasing items, and querying auction state.

## Scanning / Replication Functions

### core.auction_house.replicate_items

Syntax

```
core.auction_house.replicate_items() -> nil
```

Description
Initiates a full replication of all auction house items. This is a server-side scan that populates the replicate item cache.

### core.auction_house.get_num_replicate_items

Syntax

```
core.auction_house.get_num_replicate_items() -> integer
```

Returns

integer: The number of items available from the last replication scan.

Description
Returns the number of items returned by the most recent replicate_items call.

### core.auction_house.batch_get_replicate_items

Syntax

```
core.auction_house.batch_get_replicate_items() -> table
```

Returns

table: An array of replicated item data.

Description
Returns all replicated items in a single batch call. This is more efficient than iterating with get_replicate_item_info for large result sets.

Example Usage

```lua
core.auction_house.replicate_items()
local items = core.auction_house.batch_get_replicate_items()
core.log("Total auctions scanned: " .. #items)
```

## Search Functions

### core.auction_house.send_search_query

Syntax

```
core.auction_house.send_search_query() -> nil
```

Description
Sends a search query to the auction house based on the currently configured search parameters.

### core.auction_house.get_num_commodity_search_results

Syntax

```
core.auction_house.get_num_commodity_search_results() -> integer
```

Returns

integer: The number of commodity search results.

Description
Returns the number of results from the most recent commodity search.

### core.auction_house.get_commodity_search_result_info

Syntax

```
core.auction_house.get_commodity_search_result_info(index: integer) -> table
```

Parameters

index: integer - The result index.

Returns

table: A table containing commodity search result details.

Description
Returns information about a specific commodity search result, including unit price, quantity, and seller details.

### core.auction_house.has_full_commodity_search_results

Syntax

```
core.auction_house.has_full_commodity_search_results() -> boolean
```

Returns

boolean: true if all commodity search results have been received.

Description
Checks whether the full set of commodity search results has been received from the server.

## Owned Auction Functions

### core.auction_house.query_owned_auctions

Syntax

```
core.auction_house.query_owned_auctions() -> nil
```

Description
Queries the server for a list of all auctions owned by the player.

### core.auction_house.get_num_owned_auctions

Syntax

```
core.auction_house.get_num_owned_auctions() -> integer
```

Returns

integer: The number of owned auctions.

Description
Returns the number of auctions currently owned by the player.

### core.auction_house.get_owned_auction_info

Syntax

```
core.auction_house.get_owned_auction_info(index: integer) -> table
```

Parameters

index: integer - The index of the owned auction.

Returns

table: A table containing owned auction details.

Description
Returns information about a specific owned auction, including item details, current bid, buyout, and time remaining.

## Posting Functions

### core.auction_house.post_commodity

Syntax

```
core.auction_house.post_commodity(bag: integer, slot: integer, duration: integer, quantity: integer, unit_price: integer) -> nil
```

Parameters

bag: integer - The bag index containing the item.
slot: integer - The slot index within the bag.
duration: integer - The auction duration (1 = 12h, 2 = 24h, 3 = 48h).
quantity: integer - The number of items to post.
unit_price: integer - The price per unit in copper.

Description
Posts a commodity (stackable) item to the auction house at the specified unit price.

### core.auction_house.post_item

Syntax

```
core.auction_house.post_item(bag: integer, slot: integer, duration: integer, quantity: integer, bid: integer, buyout: integer) -> nil
```

Parameters

bag: integer - The bag index containing the item.
slot: integer - The slot index within the bag.
duration: integer - The auction duration (1 = 12h, 2 = 24h, 3 = 48h).
quantity: integer - The number of items to post (usually 1 for non-commodities).
bid: integer - The starting bid in copper.
buyout: integer - The buyout price in copper.

Description
Posts a non-commodity (equipment, unique) item to the auction house with a bid and buyout price.

## Purchasing Functions

### core.auction_house.place_bid

Syntax

```
core.auction_house.place_bid(auction_id: integer, bid_amount: integer) -> nil
```

Parameters

auction_id: integer - The auction ID to bid on.
bid_amount: integer - The bid amount in copper.

Description
Places a bid on a specific auction. The bid amount must meet or exceed the minimum bid.

### core.auction_house.start_commodities_purchase

Syntax

```
core.auction_house.start_commodities_purchase(item_id: integer, quantity: integer) -> nil
```

Parameters

item_id: integer - The item ID to purchase.
quantity: integer - The number of items to purchase.

Description
Initiates a commodity purchase. The server will calculate the total cost based on the cheapest available listings. Call confirm_commodities_purchase to finalize.

### core.auction_house.confirm_commodities_purchase

Syntax

```
core.auction_house.confirm_commodities_purchase() -> nil
```

Description
Confirms a commodity purchase that was initiated with start_commodities_purchase.

Example Usage

```lua
-- Purchase 200 of an herb (item ID 168586)
core.auction_house.start_commodities_purchase(168586, 200)
-- After verifying the price is acceptable
core.auction_house.confirm_commodities_purchase()
-- Or cancel if the price is too high
-- core.auction_house.cancel_commodities_purchase()
```

## Management Functions

### core.auction_house.cancel_auction

Syntax

```
core.auction_house.cancel_auction(auction_id: integer) -> nil
```

Parameters

auction_id: integer - The auction ID to cancel.

Description
Cancels an owned auction. The item will be returned via mail.

### core.auction_house.can_cancel_auction

Syntax

```
core.auction_house.can_cancel_auction(auction_id: integer) -> boolean
```

Parameters

auction_id: integer - The auction ID to check.

Returns

boolean: true if the auction can be cancelled.

Description
Checks whether a specific owned auction can be cancelled.

### core.auction_house.calculate_commodity_deposit

Syntax

```
core.auction_house.calculate_commodity_deposit(item_id: integer, duration: integer, quantity: integer) -> integer
```

Parameters

item_id: integer - The item ID.
duration: integer - The auction duration (1 = 12h, 2 = 24h, 3 = 48h).
quantity: integer - The quantity to post.

Returns

integer: The deposit cost in copper.

Description
Calculates the deposit cost for posting a commodity auction. The deposit is refunded when the item sells.

## State Functions

### core.auction_house.is_throttled_message_system_ready

Syntax

```
core.auction_house.is_throttled_message_system_ready() -> boolean
```

Returns

boolean: true if the throttled message system is ready to accept new requests.

Description
Checks whether the auction house throttle system is ready. The auction house rate-limits requests, so check this before sending queries.

### core.auction_house.is_auction_house_shown

Syntax

```
core.auction_house.is_auction_house_shown() -> boolean
```

Returns

boolean: true if the auction house frame is currently open.

Description
Checks whether the auction house UI is currently displayed.

## Complete Examples

### Auction House Price Scanner

```lua
local function scan_commodity_prices(item_id)
    if not core.auction_house.is_auction_house_shown() then
        core.log("Auction house is not open")
        return
    end
    
    if not core.auction_house.is_throttled_message_system_ready() then
        core.log("Auction house throttled, try again later")
        return
    end
    
    core.auction_house.send_search_query()
    
    -- After results arrive
    local num_results = core.auction_house.get_num_commodity_search_results()
    if num_results == 0 then
        core.log("No listings found")
        return
    end
    
    local cheapest = core.auction_house.get_commodity_search_result_info(1)
    core.log(string.format("Cheapest listing: %s copper/unit", tostring(cheapest)))
end
```

### Cancel Undercut Auctions

```lua
local function cancel_all_owned_auctions()
    core.auction_house.query_owned_auctions()
    local num = core.auction_house.get_num_owned_auctions()
    local cancelled = 0
    
    for i = 1, num do
        local info = core.auction_house.get_owned_auction_info(i)
        if core.auction_house.can_cancel_auction(info.auction_id) then
            local cost = core.auction_house.get_cancel_cost(info.auction_id)
            local gold = math.floor(cost / 10000)
            core.log(string.format("Cancelling auction %d (cancel cost: %dg)", info.auction_id, gold))
            core.auction_house.cancel_auction(info.auction_id)
            cancelled = cancelled + 1
        end
    end
    
    core.log(string.format("Cancelled %d/%d auctions", cancelled, num))
end
```
