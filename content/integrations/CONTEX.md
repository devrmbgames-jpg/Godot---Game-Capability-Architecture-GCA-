# Context: `content/integrations/`

## Purpose
Anti-corruption adapters translating third-party plugin concepts into stable GCA capabilities, commands, queries, intents, events, and handles.

## Rules
- Core never imports adapter or plugin classes.
- Plugin-specific errors map to stable Game result codes.
- Pin and compatibility-test plugin versions separately.
- Keep adapter state reconcilable and idempotent across save/load.
