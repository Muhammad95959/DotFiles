# Screen states and stress cases

A screen isn't designed until every state it can actually be in is designed. Walk the catalog below for each screen, keep the states that are valid for it, and skip the rest. Don't pad: a settings screen with only local data has no loading state. Every kept state gets its own `.v-state` with a `data-trigger` (what causes it) and, for errors, a `data-note` naming the tier from `error-framework.md`.

## Catalog

**Data-backed screens (lists, dashboards, detail views)**
- Loading (first load, no cache): skeleton or spinner, see the loading rules in the error framework
- Loaded (the normal state, with realistic data)
- Empty, first use: nothing exists yet. Explains the value and offers the first action. Optional illustration
- Empty, no results: search or filter matched nothing. Different copy, offers to clear the filter. No illustration needed
- Empty, cleared: user finished everything (inbox zero). Can be a small positive moment
- Refreshing: content stays, thin progress indicator
- Loading more / end of list (paginated or infinite lists)
- Partial failure: one section failed, the rest loaded. Inline error in that section only
- Error, nothing to show: T5
- Offline with cached data: T4 callout + content, actions that need network disabled with a reason or queued with a pending marker
- Offline without cache: T5 variant
- Stale data: T4 with last-updated time, if the data is time-sensitive

**Forms and editors**
- Pristine (empty or prefilled)
- Field errors after blur: T1
- Submit with errors: T1 + T2 on long forms
- Submitting: button loading, fields read-only
- Submit failed (server): T3 if retry is safe and nothing is lost, T4 if it persists, T6 if a decision is needed (e.g. conflict)
- Success: usually navigate back + T3 confirmation
- Unsaved changes on leave: T6

**Actions inside a screen**
- Reversible destructive action done: T3 with Undo
- Irreversible destructive action: T6 confirmation
- Selection / multi-select / edit mode, if the screen has one
- Permission rationale before a system prompt (camera, notifications, location), and the "permission denied" state with a path to settings

**Global states (go on the "App shell & global states" page)**
- Navigation shell itself: tab bar / rail / sidebar, top bar variants
- Signed out, session expired (T6 if unsaved work, otherwise redirect with T4 on the sign-in screen)
- Offline banner behavior across screens
- Web: 404, 403 / no access, 500, maintenance
- Forced update / unsupported version, if relevant
- First-run onboarding, if in scope

## Stress cases

Design these as states on every screen where the data can occur. They catch the layouts that only work with perfect demo data.

**Long text and big numbers**
- Names and titles at 2–3× typical length. Decide per place: truncate to one line with ellipsis (lists, cards, nav), clamp to two lines (card titles), or wrap fully (detail views, headings). Truncated text must be fully readable somewhere (detail view or tooltip on web)
- Long words without spaces: emails, URLs, IDs (`overflow-wrap: anywhere`)
- Numbers with 7+ digits, negative values, currency with decimals, percentages > 100. Use tabular figures (`.num`) where numbers align or update. Decide abbreviation rules (1.2M) and where the full number appears
- Dates in the furthest-out format the app will show

**Count extremes**
- 0 items (an empty state), 1 item (singular copy, layout doesn't look broken), many items (scrolling)
- Scrolling: what stays fixed (top bar, sticky section headers, bottom nav, FAB), what scrolls. Content must not hide behind the FAB or bottom nav at the end of the list
- Badges and counters: 1, 9, 99+, and how a 4-digit count is capped
- Chips or tags that overflow one line: wrap, scroll horizontally, or "+3"

**Missing or broken media**
- No avatar: initials on a colored background, generic icon if no name
- Image failed to load: placeholder with the same aspect ratio, never a broken-image icon
- Optional fields missing: the layout closes the gap instead of leaving an empty label

## How to present states

- First tab is always the most common state (usually Loaded), so a reviewer sees the real design first.
- Order the rest by user journey: Loading → Loaded → Empty → errors → stress cases → dialogs/overlays.
- Label states for humans ("Offline (cached)", not "state_offline_2").
- Static overlays (a dialog that is part of a state) get `data-overlay data-static`. Overlays opened by a click in the prototype flow get `data-overlay hidden`.
