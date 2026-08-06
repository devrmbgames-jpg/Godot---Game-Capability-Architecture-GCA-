# Context: `content/integrations/dialogue_manager/`

## Purpose
Facade for Dialogue Manager sessions to query and command gameplay through explicit participant handles and GCA ports.

## Rules
- Dialogue scripts never receive component Nodes or mutate fields directly.
- Queries are read-only; commands propagate structured results.
- Participant lookup uses stable handles, not display names or NodePaths.
- Keep plugin version assumptions isolated here.
