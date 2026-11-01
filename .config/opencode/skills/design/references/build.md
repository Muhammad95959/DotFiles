# Building the HTML: files, markup contract, verification, publishing

## Folder layout

```
docs/design/
  brief.md                      interview answers, decisions, artifact URLs (resume point)
  tokens.json                   final tokens of the chosen direction (phase 3)
  options/round-N/
    option-a.tokens.json …      one per option in that round
    src/                        index.html (from options.template.html), viewer.*, components.css, options.css
    options.html                built, open locally
    .artifact/options.html      built fragment, publish this one
  src/
    index.html                  from assets/index.template.html
    viewer.css, viewer.js       copied from assets/ unchanged
    components.css              from assets/components.css, restyled to the direction
    app.css                     feature-specific pieces, tokens only
    pages/system.html           design system page
    pages/shell.html            app shell & global states (404, offline, session expired, navigation)
    pages/<feature>.html        one per feature
  design.html                   built, self-contained, open locally by double-click
  .artifact/design.html         built fragment, publish this one
```

Sources are split into partials so each page stays small enough to edit precisely and features can be written in parallel. The build inlines everything into one self-contained file.

## Build

```bash
T=~/.claude/skills/design/scripts/design_tools.py
python3 $T build docs/design/src/index.html docs/design/design.html
```

Directives in source files:
- `<!-- include: path -->` inlines a file (paths relative to the including file).
- `<!-- tokens: ../tokens.json [scope=.opt-a] [id=opt-a] -->` injects the token CSS, font and icon loaders, and a JSON blob the viewer renders foundations from. Without `scope` the tokens apply to the whole page and follow the theme toggle; with `scope` they apply inside that selector (options page).

The build fails, writing nothing, when:
- any contrast pair misses AA,
- a source file outside `viewer.*` has a hard-coded color (`#hex`, `rgb()`, `hsl()`, `oklch()`…) in CSS, a `style` attribute, or an SVG `fill`/`stroke` attribute. Escape hatch for a deliberate exception: put `lint-ok` on the same line, and say why in the brief,
- an SVG presentation attribute uses `var()` (`fill="var(--x)"` silently doesn't work; use `style="fill:var(--x)"`),
- a CSS variable is used without being defined (catches token typos),
- the page doesn't start with `<title>`.

## Markup contract (what viewer.js understands)

Config, in `index.html`:
```html
<script>window.DESIGN = { app: "Tasky", mode: "design", themes: ["light","dark"], viewports: ["phone","desktop"] };</script>
```
`themes` and `viewports` come from the brief. Available viewports: `phone` (390×844), `tablet` (820×1180), `desktop` (1280×800). Frames wider than the window are zoomed to fit.

Pages and screens:
```html
<section class="v-page" data-page="tasks" data-title="Tasks" data-group="Features">
  <h1>Tasks</h1><p class="v-lead">…</p>
  <article class="v-screen" data-screen="list" data-title="Task list" data-purpose="Primary action: add a task.">
    <div class="v-state" data-state="loaded" data-label="Loaded" data-trigger="Tasks fetched">
      <div class="app"> …screen markup… </div>
    </div>
    <div class="v-state" data-state="offline" data-label="Offline (cached)" data-trigger="…" data-note="T4 …"> … </div>
  </article>
</section>
```
The viewer builds the sidebar (grouped by `data-group`), state tabs, the device frame, and the note line under it. Each state's root is `<div class="app">`, which applies background, text color and body type.

Deep links: `#page/screen/state?theme=dark&viewport=phone`. Use them for screenshots and when telling the user where to look.

Prototype interactions (use them for the key flows agreed in the brief):
- `data-goto="page/screen/state"` navigates to another screen and state.
- `data-state-to="state"` switches the current screen's state (e.g. submit → submitting).
- `data-open="#id"` shows a hidden overlay inside the same frame; `data-close` hides the closest `[data-overlay]`; Escape closes overlays unless `data-dismissible="false"`.
- `data-snackbar="#id"` shows a hidden snackbar in the same frame for `data-duration` ms (default 5000).

Layout per viewport: frames are CSS containers, so use `@container (min-width: 700px) { … }` in `app.css`/`components.css` for responsive changes. When the structure differs per viewport (bottom nav on phone, sidebar on desktop), render both and mark them with `data-only="phone"` / `data-only="desktop tablet"`.

Icons: `<i data-icon="name"></i>`, resolved to the direction's icon set. Illustrations: inline `<svg>` with colors via `style="fill:var(--color-…)"` or classes, always `aria-hidden="true"` when decorative.

Foundation renderers (design system page and options page; content is generated from tokens, don't hand-write swatches):
`<div data-render="primitives|roles|contrast|type|space|radius|elevation|icons"></div>`. `type` takes `data-sample="…"`, `icons` takes `data-names="a,b,c"`. On the options page each option section carries `data-tokens="opt-a"` so renderers and icons inside it use that option's tokens.

Theme panels: `data-theme-panel="light|dark"` on any element forces that theme inside it (side-by-side light/dark frames on the options page).

## Verifying (before every hand-off to the user)

1. Build must pass.
2. Screenshot what changed, in both themes and every viewport in the brief, and look at them:
   ```bash
   python3 $T shot docs/design/design.html '#ds?theme=light' /tmp/…/ds-light.png --height 2400
   python3 $T shot docs/design/design.html '#tasks/list/stress?theme=dark&viewport=phone' /tmp/…/list-dark.png --height 1300
   ```
   Put screenshots in the session's scratchpad directory, not the repo. Use `Read` on the PNGs. Check: clipping, overflow, text over the FAB, wrong colors in dark, missing icons (empty boxes = wrong icon name for the set), fonts falling back.
3. Run the self-review questions in `design-principles.md` §9.

For many screens, spread the review over a subagent per feature that screenshots all states and reports problems, instead of reading dozens of images in the main context.

## Publishing

Publish the built **fragment** (`.artifact/design.html`, `.artifact/options.html`), never the standalone file: the Artifact tool wraps pages in its own `<!doctype html>` skeleton. Follow the Artifact tool's own rules (it may require a quickstart or the artifact-design skill first; this skill's layout stays authoritative for page structure).

- First publish: pass `icon` ("palette" works) and a one-sentence `description`. Save the returned URL in `brief.md`.
- Republish after changes: same `file_path`, which keeps the URL. In a new conversation, pass the saved `url` (and read the artifact first, as the tool requires).
- Feedback through comments: when asked, read them with `action: "comments"`, fix in `src/`, rebuild, republish, reply briefly on each activated thread and resolve it. Threads not sent to Claude stay open; tell the user which.
