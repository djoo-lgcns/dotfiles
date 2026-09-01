# Design System

## Visual direction

Default to a restrained dark technical-presentation aesthetic:

- Near-black navy background.
- Soft elevated panels rather than flat gray boxes.
- Off-white primary text and blue-gray secondary text.
- One cool accent for structure, one warm accent for caution/revalidation, one red accent for stale/error, one green accent for success.
- Large typography with strong hierarchy and generous margins.
- Rounded panels, thin borders, subtle glow only for active state.

Do not hardcode the exact colors if the existing deck already has a visual language. Preserve existing tokens when editing.

## Slide composition

Each slide should have:

1. Small eyebrow/context label.
2. One claim-like H2/title.
3. One dominant explanatory composition.
4. Optional statement/takeaway band.
5. Footer with section/page position.

Recommended compositions:

- Comparison: 2 large panels with `≠`, `→`, or a narrow bridge between them.
- Process: nodes connected by animated lines.
- Architecture: evidence/input -> engine -> outputs.
- Before/after: two terminals, cards, or state columns.
- Benefit: four cards: previous limitation, new capability, operational effect, migration/system effect.
- Candidate design: labeled edge types plus compact metadata chips.
- Impact scope: changed root + skipped nodes + affected nodes.

## Typography

Use system fonts only by default:

`Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`

Suggested ranges:

- Hero H1: 44-88 px via `clamp()`.
- Slide H2: 34-64 px via `clamp()`.
- Body: 17-20 px.
- Card body: 15-17 px.
- Eyebrow/meta: 11-14 px.

Avoid putting more than about 45-60 words of prose on a standard slide unless the user explicitly wants detail.

## Motion

Use CSS transitions/keyframes for explanatory motion:

- Slide transition: opacity + small horizontal shift + tiny scale.
- Connector pulse: signal flow through dependencies.
- State glow: stale/affected/revalidation state.
- Terminal lines: staggered reveal.
- Avoid continuous movement on every element.
- Respect readability: animation should settle quickly or repeat slowly.

Do not use animated backgrounds that compete with content.

## Navigation and embed behavior

Required baseline:

- Previous/next buttons.
- Arrow keys, Space, PageUp/PageDown.
- `R` resets.
- Touch swipe.
- Bottom progress bar.
- `?embed=1` adds a class on `<html>` and hides overlay chrome/hints.

Do not hide the deck's core navigation semantics in embed mode: keyboard/touch should still work.

## Responsive behavior

At narrower widths:

- Collapse multi-column grids to one column.
- Convert horizontal comparison arrows to vertical orientation.
- Reduce side padding.
- Allow flow nodes to wrap.
- Keep minimum readable font sizes.
