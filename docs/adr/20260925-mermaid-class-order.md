---
id: 20260925-mermaid-class-order
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: []
---

# No composed classDefs; subgraph class waits for its edges

## Context

`bin/hostwarden-map` (#281) needs a role class (router, host,
storage) and a state class (stale, finding) on the same node, and a
frame class on a subgraph that later connects to an outside node.
The Mermaid version the diagram-render tool exercises breaks both
in ways a future cleanup would plausibly redo, so each is recorded
here rather than only fixed.

## Decision drivers

- Verified live with the diagram-render tool, not assumed from docs
- The broken forms read as the more natural, cleaner code
- Nothing else in the diagram depends on either broken form staying

## Considered options

### Full classDef per role×state, class line deferred — chosen

Every role carries its own `-stale` and `-finding` classDef variant;
`class` never lists two names, and a subgraph's `class` line waits
until every edge touching it is written, never sitting next to its
own `end`. More lines than either alternative below, but every one
renders as written.

### `class nodeId role,state`

One `class` statement per node instead of one per role×state
combination. Mermaid writes the two names joined by a literal comma
into the SVG's own `class` attribute, `role,state`, which matches
neither `.role` nor `.state` as a CSS selector: the node silently
falls back to Mermaid's default colours instead of erroring. Lost
because nothing signals the failure at render time.

### `class` next to the subgraph's own `end`

Reads better and matches where every other node's `class` line
sits, right after it is drawn. Mermaid drops a subgraph's `class`
statement entirely once a later edge connects that subgraph to a
node outside it, verified live both with and without the reorder.
Lost for the same reason: no error, just a subgraph that silently
keeps its default colour.

## Decision

Every role carries its own `-stale` and `-finding` classDef variant;
`class` never lists two names, and a subgraph's `class` line waits
until every edge touching it is written.

## Consequences

More classDef lines than composition would need, but each renders
correctly instead of silently falling back to Mermaid's default
colours. A cleanup that composes classes, or that moves a
subgraph's `class` line next to its `end` for readability,
reintroduces both bugs; `bin/hostwarden-map` carries the constraint
in its own header comment and `CLASSDEFS` block, and this record is
where the two rejected forms are on file for the next attempt.

## Confirmation

A future Mermaid version could fix either bug outright. Nothing in
the script would tell us: the composed and reordered forms would
just start working, and only trying them again would show it.

