# Druid Implementation Notes

S+ pass local-code cross-reference checklist. Use this file when translating research into EAX Project Sylvanas rotation behavior.

## Required Local Checks

- Compare current EAX spec implementation against the S+ addendum in each spec `Research.md`.
- Search Flux docs/code for class-specific priority, burst, defensive, or state-machine patterns.
- Search Sonah class modules for practical toggles, PvP handling, swing timers, and UI patterns.
- Search SlyRotate for compact priority ordering and event tracking patterns.
- Keep TBC guardrails: do not import WotLK/Cata spells or mechanics.

## Class-Specific Watchpoints

- Forms and form-cancel safety
- Powershifting and energy tick handling
- Bear/Cat separation
- HoT rolling and dispels
