# tokens.json format

Single source of truth for a design direction. The build turns it into CSS variables, font/icon loaders, and the foundation sections of the design system page. Later implementation sessions turn it into Compose, SwiftUI or CSS themes. Full working example: `assets/tokens.example.json`.

## Structure

```jsonc
{
  "meta": { "name": "Calm Paper", "rationale": "…", "themes": ["light", "dark"] },  // themes: one or both
  "primitives": { "color": { "neutral": { "50": "#f7f7f5", … }, "teal": { … } } },
  "color": {                     // semantic roles per theme; values are "{ramp.step}" refs or hex
    "light": { "background": "{neutral.50}", … },
    "dark":  { … }
  },
  "contrast": [                  // extra pairs beyond the builtin ones
    { "fg": "on-surface-variant", "bg": ["surface-container-high"], "use": "text" }   // use: text | large-text | ui | decorative
  ],
  "font": {                      // roles referenced by "type"
    "display": { "family": "Fraunces", "fallback": "Georgia, serif", "google": "Fraunces:opsz,wght@9..144,500;9..144,600" },
    "body":    { "family": "Inter Tight", "fallback": "system-ui, sans-serif", "google": "Inter Tight:wght@400;500;600" }
  },
  "type": { "display": { "font": "display", "size": 40, "line": 48, "weight": 600, "tracking": -0.5 }, … },
  "space":  { "1": 4, "2": 8, "3": 12, "4": 16, "5": 20, "6": 24, "8": 32, … },
  "radius": { "sm": 6, "md": 10, "lg": 16, "xl": 24, "full": 9999 },
  "size":   { "control": 48, "touch": 48 },
  "elevation": { "light": { "1": "<box-shadow>", "2": "…", "3": "…" }, "dark": { … } },
  "icons":  { "set": "lucide", "version": "0.460.0", "stroke": 1.75 }
}
```

## Required keys

The starter components reference these, and the build fails on undefined CSS variables, so a token file without them won't build.

- **Color roles (every theme):** `background, on-background, surface, on-surface, on-surface-variant, surface-container, surface-container-high, outline, outline-variant, primary, on-primary, primary-container, on-primary-container, error, on-error, error-container, on-error-container, warning-container, on-warning-container, success-container, on-success-container, info-container, on-info-container, inverse-surface, on-inverse-surface, inverse-primary, focus-ring, scrim`. Add more roles freely (`secondary`, `tertiary`, chart colors, tag colors). Name text-on-X roles `on-X` so the checker pairs them automatically.
- **Type styles:** `display, headline, title, title-sm, body, body-sm, label, caption`.
- **Space:** `1, 2, 3, 4, 5, 6, 8`. **Radius:** `sm, md, lg, full` (`xl` optional). **Size:** `control, touch`. **Elevation:** `1, 2, 3` per theme.

## Rules

- Screens and components only use semantic roles (`var(--color-surface)`), never primitives. Primitives exist so roles stay consistent and so re-theming is a matter of re-pointing references.
- Hex only (`#rrggbb`, or `#rrggbbaa` for translucent foregrounds; the checker blends alpha over the background). Backgrounds must be opaque.
- Font families must be available on Google Fonts (the only stylesheet host the published artifact allows) or be system stacks. The `google` value is the `family=` parameter of the css2 API.
- Icon sets: `lucide` (loaded from jsDelivr, names like `trash-2`, `circle-alert`) or `material-symbols-outlined|rounded|sharp` (Google Fonts, names like `delete`, `error`). Pick one set per direction and use only that set's names.
- Generated CSS variables: `--color-<role>`, `--font-<role>`, `--type-<style>` (use as `font: var(--type-body)`) and `--type-<style>-tracking`, `--space-<k>`, `--radius-<k>`, `--size-<k>`, `--elevation-<k>`, `--icon-stroke`. Classes `.t-<style>` apply a type style.

## Validating

```bash
python3 ~/.claude/skills/design/scripts/design_tools.py check docs/design/tokens.json
```

Prints every failing pair with the ratio and the hex values. Fix by moving the role to a different ramp step (darker text, lighter background) rather than adding one-off colors.
