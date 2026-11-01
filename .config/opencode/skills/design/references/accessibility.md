# Accessibility rules

Target: WCAG 2.2 Level AA, unless the brief says otherwise (AAA, or an audience with specific needs). These rules are part of the design, not a later check, because most failures are baked into the palette and component sizes.

## Contrast (checked by the build, never by eye)

| What | Minimum | Pair `use` in tokens.json |
|---|---|---|
| Body text, labels, placeholder text that carries meaning | 4.5:1 | `text` |
| Large text: ≥ 24px regular or ≥ 18.66px bold | 3:1 | `large-text` |
| UI component boundaries the user needs to see (text field border, checkbox outline, switch track), icons that carry meaning, focus indicator, chart lines | 3:1 against adjacent color | `ui` |
| Disabled controls, pure decoration, logos | exempt | `decorative` (or omit) |

- `design_tools.py check` and `build` compute every pair that matters. Builtin pairs cover `on-X`/`X`, text on all surfaces, primary/error as text, outline and focus ring on all surfaces. Add any extra pair a component uses (e.g. a tag color on a card) to the `contrast` list in tokens.json. If the build fails, change the tokens; never weaken the pair list.
- Placeholder text that only shows an example can be decorative, but if it's the only label it must pass 4.5:1. Better: always use a visible label.
- Exempt doesn't mean invisible: disabled controls still need to be recognizable as controls.
- Text on images or gradients: put a scrim behind it and treat the darkest/lightest point as the background.

## Touch targets

- Minimum interactive size: 48×48 dp on Android, 44×44 pt on iOS, 44×44 px on web touch layouts. WCAG 2.2 (2.5.8) only requires 24×24 CSS px, which is too small for comfortable mobile use; treat 24px as the hard floor for dense desktop UI only.
- The visual element can be smaller (a 24px icon) if its hit area isn't. Use `--size-touch` for hit areas and `--size-control` for control heights.
- At least 8px between adjacent targets so a slightly-off tap doesn't hit the neighbor.
- Show the target size in the design system notes for icon buttons, chips, list rows and nav items.

## Focus states

- Every interactive component has a visible focus state, shown on the design system page as its own state (`.is-focus`).
- Default: 2px ring in `--color-focus-ring`, 2px offset, ≥ 3:1 against the background it sits on (checked via the builtin pairs).
- Focus must not be hidden behind sticky headers, bottom bars or snackbars (2.4.11 Focus Not Obscured). Account for sticky elements with `scroll-margin`.
- Focus style differs from hover and selected, so keyboard users can tell where they are.

## Defaults built into the components

These come free with the starter components; keep them when restyling:

- Real `<button>`, `<input>`, `<a>` elements, labels tied to inputs, `aria-invalid` + `aria-describedby` on field errors, `role="status"` for snackbars and offline callouts, `role="alertdialog"` for T6.
- Errors and statuses always pair color with an icon and text (the error framework requires it).
- `prefers-reduced-motion` turns off animations.
- Body text at least 16px on mobile; line length 45–75 characters on wide layouts.
