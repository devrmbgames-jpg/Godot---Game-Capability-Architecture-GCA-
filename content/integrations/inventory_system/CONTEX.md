# Context: `content/integrations/inventory_system/`

## Purpose
Idempotent Inventory System bridge for inventory queries, item actions, equipment-owned effects, and ability grants.

## Rules
- Inventory plugin owns item/inventory data; GCA owns gameplay handles and bindings.
- Equip/unequip applies and removes only item-owned handles.
- Stable item instance IDs prevent duplicate bindings after restore.
- Item use consumes inventory only according to the successful gameplay result policy.
