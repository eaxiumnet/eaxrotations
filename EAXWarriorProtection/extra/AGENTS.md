# EAXPROTECTION KNOWLEDGE BASE

**Generated:** 2026-03-13

## OVERVIEW

Minimal Protection Warrior rotation plugin for TBC (Project Sylvanas).

## STRUCTURE

```
EAXProtection/
├── main.lua      # Plugin entry
└── README.md     # Rotation docs
```

## ENTRY POINT

- `main.lua` - Plugin logic (Sylvannas runtime)

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Rotation logic | `main.lua` |
| Ability priorities | `README.md` |

## CONVENTIONS

- Sylvannas plugin (not standalone addon)
- Registers callbacks for combat events

## ANTI-PATTERNS

- **Don't** use without Sylvannas runtime
