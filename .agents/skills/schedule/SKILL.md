---
name: schedule
description: Orders scheduler. Reads .noodle/mise.json, writes .noodle/orders-next.json. Schedules work orders based on backlog state, plan phases, session history, and task type schedules.
schedule: "When orders are empty, after backlog changes, or when session history suggests re-evaluation"
---

# Schedule

Read `.noodle/mise.json`, write `.noodle/orders-next.json`.
The loop atomically promotes `orders-next.json` into `orders.json` — never write `orders.json` directly.
Use `noodle schema mise` and `noodle schema orders` as the schema source of truth.

Operate fully autonomously. Never ask the user to choose or pause for confirmation.

## Project Context

This is a Godot 4 mobile game project (Android + iOS). Three domain skills are available and should be referenced in `extra_prompt` for execute stages:

- `godot-best-practices` — Godot 4.x coding standards, scene organization, signals, resources
- `godot-gdscript-patterns` — GDScript architecture patterns, optimization
- `godot-ui` — Godot UI system, Control nodes, themes, responsive layouts

When writing execute stage `extra_prompt`, remind agents to load the relevant Godot domain skills.

## One Plan at a Time

Cardinal scheduling rule. Pick the highest-priority plan with remaining phases and schedule all of them. Do not spread work across multiple plans — finishing one plan end-to-end produces shippable results; advancing many plans one phase each produces nothing usable. If the current plan is blocked, idle (empty orders) rather than context-switching to a different plan. Exception: shared infra orders can run alongside a plan's phases.

## Orders Model

Output is `{orders: [...]}` where each order is a **pipeline of stages** executed sequentially. Group related work into stages within one order rather than separate orders.

### Stages

Each stage has a `do` field (task key, must match a registered task type) and runs one at a time within the order. The loop advances to the next stage when the current one completes.

A typical order pipeline: execute, then quality (if added later), then reflect (if added later) — all as stages of one order.

## Task Types

Read `task_types` from mise to discover every schedulable task type and its `schedule` hint. Any registered task type can be a stage within an order. Use `do` on each stage to bind it to a task type.

### Execute Tasks

Schedule execute tasks from the `backlog` array in mise. Use the backlog item ID (as a string) as the order `id`.

**Items with plans:** When a backlog item has a `plan` field, read the plan overview and phase files. Schedule one order with a stage per remaining unfinished phase. Populate `order.plan` with the plan path(s). Use `extra_prompt` on each stage to inject plan context.

**Items without plans:** Assess complexity. If straightforward, schedule as a simple execute task using the backlog item's title and description as the prompt. If complex, schedule a plan-first order: a `prompt`-only stage that invokes `/plan`, followed by review. No execute stages — planning output is a design document. The plan skill will write phased plans; on the next cycle, the item will have a `plan` field and can be scheduled normally.

**Shared infrastructure:** When multiple plans depend on common infrastructure, propose a standalone infra order before the plan's phases. Use a descriptive slug ID (e.g., `"infra-shared-types"`).

**Nothing to schedule:** Write `{"orders":[]}`. This signals scheduling ran but found nothing — prevents hot-loop re-spawns.

## Recent Events

The mise brief includes a `recent_events` array. These are context for scheduling decisions, not commands. Use judgment — a single stage failure is normal; three consecutive failures of the same order suggests a deeper problem.

## Scheduling Heuristics

- **Cheapest mode**: Prefer the lowest-cost provider/model that can handle the task.
- **Explicit rationale**: Every order must cite which rule drove its placement.
- **Timebox failures**: If an item has failed 2+ times in `recent_history`, deschedule or split it.

## Model Routing

Use `routing.defaults` from `.noodle.toml` as the baseline. For this project:

| Task type | Model |
|-----------|-------|
| Small/mechanical tasks | claude-sonnet-4-6 |
| Implementation, execution | claude-opus-4-6 |
| Judgment, strategy, planning, review | claude-opus-4-6 |

## Runtime Routing

Always set `"runtime": "process"` on all stages.

## Output

Write valid JSON to `.noodle/orders-next.json` matching `noodle schema orders`.
