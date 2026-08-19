# Kiki interface system

Kiki uses [Beautiful UI](https://www.beautifului.dev/) as its visual and interaction reference, adapted to native AppKit semantics. Beautiful UI is the acceptance target for density, hierarchy, component geometry, focus, tables, forms, navigation, loading, and human-in-the-loop actions. Apple platform behavior remains authoritative for keyboard, accessibility, menus, windows, and native control semantics.

## Direction

- Audience: people who want dependable local voice tools without learning audio software.
- Job: make the next safe action obvious and keep local processing state unambiguous.
- Tone: restrained technical utility with a warm sage Kiki signature.
- Hierarchy: task, current state, next action, supporting detail.
- Signature: quiet near-neutral surfaces, sage focus/status accents, and the Kiki portrait used sparingly.

## Foundations

All shared values live in `KikiVisualStyle.swift`. Leaf screens must use those primitives instead of inventing one-off geometry.

### Spacing

Use the 4, 8, 12, 16, 24, 32 point scale. Intra-group spacing must be smaller than inter-group spacing. Align cards, headings, fields, actions, and table columns to shared edges.

### Type

- Page title: 26–31 pt, bold.
- Section title: 16–18 pt, semibold.
- Control and table text: 12.5–13 pt.
- Supporting text: 11.5–12.5 pt; never use tiny type as decoration.
- Metadata: 10.5–11 pt only when it is nonessential and high contrast.

### Geometry

- Primary controls: 40 pt high, 8 pt radius.
- Compact controls: 34 pt high, 8 pt radius.
- Navigation rows: 40 pt single-line; 48 pt only when a subtitle materially improves comprehension.
- Table rows: 36 pt with content vertically centered.
- Cards/data surfaces: 10 pt radius, one hairline border, no stacked borders.
- Selection: quiet tinted fill plus a visible focus/selection edge; never place text against the top or bottom of the highlight.

### Surfaces and color

- Use one near-neutral dark ramp for canvas, sidebar, surface, elevated surface, border, and divider.
- Sage is reserved for focus, readiness, selected indicators, and primary action emphasis.
- Danger uses system red only for destructive actions.
- Prefer spacing and a single hairline over gradients, inner strokes, and decorative shadows.

## Components

### Tables

- Use `configureKikiTable`, `KikiTableRowView`, and `kikiTableCell`.
- Do not return a raw `NSTextField` as a table cell; it will not maintain optical vertical centering when AppKit stretches it.
- Use 10 pt horizontal cell insets, one-line truncation, tooltips for clipped content, and a 36 pt row.
- Selection must cover the row consistently and must not change text geometry.

### Buttons and actions

- Equal-rank peers share height, radius, and width.
- Primary actions use sage; secondary actions use the elevated neutral surface.
- Destructive actions are explicit, red, and separated from the primary path when space permits.
- Disabled controls remain legible but visibly inactive.

### Navigation

- Current location uses a quiet elevated surface, not a large block of accent color.
- Icons share one SF Symbols family and optical size.
- Keyboard focus is visible independently of selection.

### Cards and panels

- Cards are flat by default. Shadows are reserved for genuinely floating overlays.
- Avoid nested borders. A data surface owns its one outer edge; its scroll view stays visually transparent.
- Do not put every group in a card when spacing alone establishes hierarchy.

### AI and local processing states

- Distinguish downloading, loading, recording, transcribing, generating, completed, failed, and cancelled.
- Show progress when measurable and a precise active-state label when it is not.
- Suggestions remain reversible until the user approves them. Scope is visible before approval.

## Release visual gate

Before shipping any interface change:

1. Render every affected route at its minimum, default, and large window size.
2. Check normal, selected, focused, disabled, empty, loading, success, error, and destructive states that exist.
3. Verify table-cell vertical centering, peer-button geometry, shared edges, card nesting, and scroll ownership.
4. Traverse with keyboard and inspect the Accessibility tree.
5. Recheck the installed updater-delivered app; source and preview screenshots are not release proof.

