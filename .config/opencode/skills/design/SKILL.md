---
name: design
description: Design an app's UI the way a professional product designer would, for mobile apps, web apps and websites alike. Three phases. (1) Rigorously interviews only for design-relevant details (screens, data per screen, states, mood, brand, themes, viewports). (2) Proposes three distinct visual directions (palette, type, shape, icons) as one HTML comparison page and iterates until one is chosen or remixed. (3) Builds a clickable, self-contained HTML design file plus tokens.json: a design system page with WCAG 2.2 AA-checked color tokens, typography and every reusable component in all states, then one page per feature with every valid screen state (loading, empty, error, offline, long content, dialogs), light/dark themes and a tiered error-handling framework. Use whenever the user wants to design an app or website, create UI designs, mockups, a design system, a color scheme or style options, or says /design, even if they don't say "design system".
---

# Design

Turn an app idea into a professional, accessible UI design: a design system and every screen in every state, delivered as one interactive HTML file and a `tokens.json` that later implementation sessions build from.

This skill designs. It does not plan software: no architecture, APIs, data models beyond what a screen displays, or implementation. When those topics come up, keep only what's visible to the user.

## Files

All output goes to `docs/design/` in the current repo (or current directory). Layout, build commands, markup contract and publishing are in `references/build.md`. Read it before writing any HTML.

| Path | Purpose |
|---|---|
| `brief.md` | Interview answers, screen inventory, decisions, artifact URLs. Updated the moment a decision is made, so a cleared context can resume. Template: `assets/brief.template.md` |
| `options/round-N/` | Token files and comparison page for each round of directions |
| `tokens.json` | Final tokens of the chosen direction. Format: `references/tokens.md` |
| `src/` | Partials the build assembles |
| `design.html` | The deliverable, self-contained, opens from disk |

Tools: `scripts/design_tools.py` (`check` contrast, `build` + lint, `shot` screenshots). Starter assets in `assets/`: `viewer.css`, `viewer.js`, `components.css`, templates, and `tokens.example.json` as a complete working token file.

## Phase 0: Context

1. If `docs/design/brief.md` exists, read it and ask whether to **resume**, **revise**, or **start over**. Never overwrite silently.
2. Collect what already exists before asking anything: the user's message and any linked docs, `docs/breakdown/` (project-breakdown output has the feature list), README/specs, and an existing app in the repo (theme files, color/type definitions, components, screens). Use an Explore subagent for larger repos. An existing design system is extended, not replaced, unless the user says otherwise.
3. Create a task list with the phases so progress is visible.

## Phase 1: Interview

Goal: know every screen, what it shows, what can go wrong on it, and what the app should feel like. Follow `references/interview.md`: it has the checklist, the scope rule (ask only what changes the design), and how to ask (`AskUserQuestion`, batched, recommended option first).

Be rigorous. A vague answer like "a list of tasks" isn't enough: ask which fields a task shows, how long they get, what happens on tap, which actions exist and whether they're reversible. If you disagree with a choice because it will hurt the design or accessibility, say so in the question and offer the better option. The user decides.

Themes: if the user hasn't said light, dark, or both, ask. Viewports: ask which form factors matter.

Write each answer into `brief.md` as it comes in. End with the **approval gate** in `references/interview.md` (brief summary + screen inventory). Don't start phase 2 without confirmation.

## Phase 2: Directions

Read `references/design-principles.md` first, especially §6 (avoid the generic look) and §7 (what makes options distinct).

1. Create three directions (or the number the user asked for) as `options/round-N/option-<x>.tokens.json`. Each differs on palette/temperature, type, and shape/density, has a name, mood words and a one-line rationale tied to the brief. Respect fixed brand assets.
2. Validate: `design_tools.py check options/round-N/*.tokens.json`. Fix failing pairs by re-pointing roles to other ramp steps until everything passes. Never show a direction that fails.
3. Build the comparison page from `assets/options.template.html`: per option the signature screen in light and dark (pick the screen that best represents the app, usually home or the main list, with realistic copy), foundations via renderers, contrast table, and core components (buttons, text field incl. error, chip, switch, list item, card, callout, snackbar, dialog). Put per-option character beyond tokens (e.g. uppercase labels, rule lines) in `options.css`, scoped to `.opt-x`. End with the side-by-side section.
4. Build, screenshot both themes, self-review, publish the fragment (see `references/build.md`), and give the user the local path and the link.
5. Ask with `AskUserQuestion`: pick one, remix (e.g. "palette of A, type of C"), or new round (default 3, or the number given; say what you'll change based on their feedback). A remix becomes a new round with just the merged option for a quick confirmation. Log every round and the reason for the choice in `brief.md`.
6. Copy the chosen token file to `docs/design/tokens.json`.

## Phase 3: Full design

Read `references/error-framework.md`, `references/states.md` and `references/accessibility.md` before writing screens. They define which states each screen needs, how every error is presented, and the a11y rules every component must meet.

1. **Plan the states.** For each screen in the inventory, walk the state catalog and stress cases in `references/states.md`. Assign each error state its tier (T1–T6) using the decision order in the error framework. Write the resulting state list into `brief.md` under the screen inventory, and list the key flows that will be clickable. Show this plan to the user in a compact form and get a go-ahead; it's much cheaper to fix a missing state here than in HTML.
2. **Scaffold** `docs/design/src/` from `assets/` (index template, viewer files unchanged, `components.css`, empty `app.css`). Set `window.DESIGN` themes/viewports from the brief.
3. **Design system page** (`pages/system.html`, from `assets/pages/system.template.html`): foundations via renderers (they read tokens.json, so they can't drift), then every reusable component with all its states side by side (default, hover, focus, pressed, disabled, loading, error, selected, as applicable), each with a one-line usage rule and a11y note (target size, role). Restyle `components.css` to the chosen direction's character but keep class names. Add only components the app uses plus the core set; a component belongs here when it's reused or a standard primitive. End with the error framework section: one live specimen per tier with this app's real copy, plus the decision order.
4. **App shell page** (`pages/shell.html`): navigation for each viewport, top bar variants, and the global states (offline behavior, session expired, 404/403/500 for web, permission rationale, onboarding if in scope).
5. **Feature pages**, one per feature, following `assets/pages/feature.example.html`: every screen of the feature, every valid state, realistic copy, stress states, and the agreed flows wired with `data-goto` / `data-state-to` / `data-open` / `data-snackbar`. Screens only use design-system components and tokens; feature-unique pieces go in `app.css`, still token-only. For more than ~4 features, write them in parallel with one subagent per feature after the design system is done; brief each with `brief.md`, `tokens.json`, `components.css`, the feature example, and the three references from this phase.
6. **Build and verify** per `references/build.md`: the build must pass (contrast, no hard-coded colors, no undefined variables), then screenshot every page in both themes and each viewport and run the self-review in `design-principles.md` §9. Fix before showing anything.
7. **Publish** the fragment, save the URL in `brief.md`, and tell the user: the local file path, the link, what's on which page, and any deliberate judgment calls (e.g. "Delete is T6 here because it affects shared data").

## Iterating

Feedback comes in chat or as comments on the published artifact. For each request: update `brief.md` if it changes a decision, edit the relevant partial (or tokens.json for global changes; the contrast check reruns on build), rebuild, re-screenshot what changed, republish to the same URL. For comments, follow the comment workflow in `references/build.md`. If a change would break consistency (a one-off color, a fourth error style), point that out and suggest the system-level fix.

## Quality bar

The result should hold up in front of a senior product designer:
- Every screen has one clear primary action and a reason for its hierarchy.
- Every valid state exists, including the ugly ones (long names, 0 and 999+ items, missing images, offline).
- Every error is on the right surface with copy that says what happened and what to do.
- Every color pair passes WCAG 2.2 AA in every theme, proven by the build, not by eye. Touch targets and focus states are visible on the design system page.
- Dark theme looks designed, not inverted.
- Nothing looks like a template: real copy, a type pairing with intent, one icon family, restrained color.
