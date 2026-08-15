# Game Capability Architecture (GCA)

Game Capability Architecture is a Godot 4.6 gameplay framework for building modular game objects from explicit capabilities instead of domain-specific inheritance trees.

The framework targets third-person action RPG projects and supports reusable composition for characters, AI agents, props, traps, doors, destructible objects, abilities, effects, attributes, meters, control sources, interactions, world services, persistence, and external integrations.

## Core principles

- Use Godot scenes and nodes as the composition model.
- Keep shared `Resource` definitions immutable at runtime.
- Store per-owner state in lightweight runtime objects or feature nodes.
- Depend on capabilities, tags, handles, queries, commands, and explicit ports rather than concrete owner classes.
- Let parents call child features directly; child features report upward through signals or local events.
- Do not use downward signals as commands or sibling-to-sibling `get_parent().foo()` calls.
- Queue child operations to preserve deterministic execution and prevent recursive gameplay chains.
- Keep third-party addons behind adapters in `content/integrations/`.

## Project layout

```text
content/
├── core/           # Framework contracts and universal runtime systems
├── gameplay/       # Game-specific definitions and examples
├── integrations/   # Anti-corruption adapters for external addons
└── testing/        # Contract, component, and integration fixtures

addons/
└── gca_data_studio/ # GCA-owned editor tooling

docs/               # Public API guides and architectural documentation
resources/          # Raw imported assets
shaders/            # Shader sources
```

Third-party addon sources under `addons/` are not part of the GCA public API unless explicitly wrapped by an adapter.

## Object composition

A gameplay object keeps its Godot-native root and adds one local kernel:

```text
ObjectRoot
├── Visual
├── Physics
└── GameObjectKernel
    ├── GameIdentity
    ├── GameTags
    ├── GameAttributes
    ├── GameMeters
    ├── GameEffects
    ├── GameAbilities
    └── other GameFeature components
```

`GameObjectKernel` discovers direct child features, validates capabilities, builds `GameObjectContext`, activates features in dependency order, routes local events and commands, and owns the local execution queue.

## Main systems

### Foundation

Provides object kernels, feature lifecycle, capability registration, object identity and handles, gameplay tags, command results, local events, execution contexts, operation queues, and diagnostics.

### Attributes, meters, effects, damage, and death

Attributes use the required formula:

```text
(base + add) * (1.0 + increase)
```

Current resources such as health, stamina, and integrity are meters. Effects own modifier and tag handles, support instant/duration/infinite lifetimes, and are processed by a centralized host. Damage targets the `damage.receiver` capability. Death is a gameplay state transition, not automatic node deletion.

### Abilities

Abilities are split into immutable definitions, owner-specific grants, and per-activation executions. Activation queries are side-effect free. Costs and cooldowns are committed through the ability component, and child abilities/effects use the execution queue.

### Control and interaction

Player input, AI, and scripted/cutscene control produce normalized intents through the same control endpoint. Movement is delegated to motor ports. Interaction targets expose runtime offers that are revalidated before execution.

### World and integrations

Scene-local world services resolve stable handles, spawn/despawn objects, perform targeting queries, provide simulation time, coordinate persistence, and isolate GOAP, Dialogue Manager, and Inventory System through adapters.

## Basic workflow

1. Add `GameObjectKernel` under a suitable Godot root node.
2. Add the required `GameFeature` children.
3. Configure immutable definitions in `.tres` resources.
4. Validate editor warnings before running the scene.
5. Resolve dependencies through capabilities during feature initialization.
6. Send gameplay changes through commands or typed public ports.
7. Observe completed facts through local events or signals.
8. Use handles to remove grants, modifiers, effects, tags, constraints, and reservations safely.
9. Use debug snapshots and execution root IDs when tracing behavior.

## Documentation

- `docs/STAGE_2_API.md` — attributes, meters, effects, damage, and death.
- `docs/STAGE_3_ABILITIES_API.md` — ability grants, activation, costs, cooldowns, and execution.
- Stage-specific guides describe later control, interaction, world, persistence, and integration APIs when present.
- Every GCA-owned source directory contains a `CONTEX.md` navigation file for AI tools and contributors.
- Public and virtual GDScript methods use Godot `##` documentation comments.

## Naming and code style

- Gameplay classes use the `Game` prefix.
- GDScript is strictly typed except where Godot APIs require `Variant`.
- Unused arguments begin with `_`.
- Signal slots begin with `_on_`.
- Scripts follow the project section order: constants, enums, on-ready, exports, private state, overrides, helpers, public methods, and slots.
- Scenes and resources use semantic prefixes such as `ui_`, `prop_`, `ent_`, `ability_`, `effect_`, and `attr_`.

## External addons

The project currently anticipates adapters for:

- GOAP Godot 4
- Dialogue Manager
- Inventory System

Core GCA code must not import plugin-specific classes. Plugin updates should normally affect only the matching adapter and its integration tests.

## Compatibility

- Godot Engine 4.6
- GDScript as the primary language
- C# only for isolated, justified integrations or profiler-backed hot paths
