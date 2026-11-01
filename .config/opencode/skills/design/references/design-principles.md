# How a professional designer approaches this

Read this before phase 2 and again before phase 3. It's the thinking that separates a design system from a pile of nice-looking screens.

## 1. Start from the problem, not the palette
For each screen, answer before drawing: who is here, what question do they have, what's the one primary action? Everything on the screen is ranked against that. If two things compete for "most important", the screen isn't designed yet. Write that one line as the screen's `data-purpose`.

## 2. Hierarchy with as few tools as possible
- Establish hierarchy with size and weight first, then position and spacing, then color last. If removing color makes the hierarchy collapse, it was never there.
- One primary button per view. Secondary actions are visually quieter. Destructive actions are never the primary style unless it's a confirmation.
- Group with spacing before using borders or cards. Every extra container is visual noise.

## 3. A small, strict system
- **Spacing:** 4px base grid; most layouts only need 4, 8, 12, 16, 24, 32, 48. Spacing inside a group is smaller than spacing between groups.
- **Type:** 6–8 named styles total (`display, headline, title, title-sm, body, body-sm, label, caption`). Two families at most: one for display, one for UI text, or a single family with weight contrast. Line height ~1.4–1.5 for body, tighter for headings. Tabular figures for numbers that align or change.
- **Color:** neutrals do most of the work. Roughly 60% neutral surfaces, 30% secondary surfaces and text, 10% accent. One primary hue; semantic colors (error, warning, success, info) are reserved for meaning and never used decoratively.
- **Shape:** one radius scale, used consistently: smaller radius for small elements, larger for containers. Nested radii: inner = outer − padding.
- **Elevation:** few levels, each with a meaning (resting card, raised menu, modal). In dark themes, elevation shows mostly through lighter surfaces, not shadows.

## 4. Dark theme is designed, not inverted
- Avoid pure black backgrounds unless OLED black is a deliberate choice; use a very dark neutral so elevation steps stay visible.
- Raised surfaces get lighter, not darker.
- Desaturate and lighten the primary so it doesn't vibrate on dark surfaces; check contrast again (the build does).
- Avoid pure white body text on dark; a slightly dimmed neutral reads better.

## 5. Platform-aware, still distinctive
The identity comes from color, type, shape, illustration, copy and spacing. Behavior comes from the platform: navigation patterns, back behavior, sheet vs. dialog, control sizes, system fonts where they matter. A custom app that ignores platform behavior feels broken; one that only uses defaults feels generic.

## 6. Avoid the generic AI look
These signal "template" and should only appear when there's a reason:
- Purple-to-blue gradients, glassmorphism, glowing shadows, gradient text.
- Inter/Roboto everywhere with no type personality. If you use a neutral sans, give the system character elsewhere.
- Emoji as icons. Mixed icon families. Icons on every single label.
- Everything in rounded cards with the same shadow. Centered everything.
- Fake data like "Lorem ipsum", "John Doe", "Item 1". Use realistic copy from the brief.
- Default-looking empty states ("No data").

## 7. Three directions that are actually different (phase 2)
Each option must differ from the others on at least these axes:
- **Palette and temperature:** e.g. warm paper neutrals with a deep green vs. cool grays with electric blue vs. high-contrast monochrome with one warm accent.
- **Type:** e.g. serif display + grotesk UI vs. geometric sans only vs. humanist sans with a mono for data.
- **Shape and density:** e.g. soft and roomy (large radii, 56px controls) vs. sharp and editorial (small radii, strong rules) vs. compact and utilitarian (dense lists, 40px controls on desktop).

Each option gets a name that captures it (not "Option 1"), 3 mood words, and a one-line rationale that ties it to the brief ("for teams who live in this app all day, so it stays calm and dense"). At least one option should be the safe, obviously-fitting choice and at least one should be bolder than the user would have asked for. That's how users find out what they actually want.

All three options must pass the contrast check before they are shown.

## 8. Consistency is a feature
- Screens are composed only from design-system components and tokens. A feature-specific piece (a Kanban column, a chart) can live in `app.css`, but it's still built from tokens.
- A component belongs in the design system when it's used on two or more screens or is a standard primitive (button, field, dialog, snackbar, list item). One-off pieces stay with their feature.
- Same thing, same look, same place, everywhere. If two screens solve the same problem differently, one of them is wrong.

## 9. Self-review before showing anything
Look at the screenshots and ask:
- Squint test: is the primary action the most prominent thing on every screen?
- Would a new user know what to do on each empty state?
- Do the long-content states still look intentional?
- Does dark mode look designed, or inverted?
- Is there anything that only works because the demo data is perfect?
- Did any hard-coded value sneak in? (The build lint catches colors, not spacing; check visually.)
