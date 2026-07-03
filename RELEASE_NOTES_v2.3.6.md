## EAX Rotations v2.3.6 — Stash Recovery Features

### New Features

- **Warlock Affliction — Imp Machine Gun Detection**: The rotation now tracks when your Imp is actively casting Firebolt (`pet_casting_firebolt`) and whether your pet is an Imp (`pet_type_imp`). This enables smarter pet management decisions — you can see at a glance if your Imp is doing its job.

- **Druid Cat — BiteTrick Strategy**: New `BiteTrick` strategy that fires Ferocious Bite at exactly 5 combo points when energy is low (≤39). This optimizes bite timing to avoid wasting energy before the next tick — a subtle but meaningful DPS gain for advanced feral players.

- **Druid Cat — Form Detection Diagnostics**: When debug logging is enabled, the rotation logs which form-detection APIs are available and working on your client. Useful for troubleshooting when cat form detection seems off.

### What to Expect

- **Warlocks**: Better pet awareness. The rotation knows when your Imp is casting.
- **Druid Cats**: Slightly better Ferocious Bite timing at 5 CP. The BiteTrick fires before energy ticks to maximize efficiency.
- **Everyone**: No changes. These are targeted improvements for specific specs.

---
*Note: These features were cherry-picked from abandoned development stashes and cleanly re-implemented on the current stable codebase. No merge conflicts, no reverted fixes.*
*Verified: 219 rotation tests pass. All spell IDs verified against WoW 2.5.5.68101 client DBC.*
