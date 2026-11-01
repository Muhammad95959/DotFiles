# Error and feedback framework

Every message the app shows lands on exactly one surface. The surface depends on how serious the problem is, how long it lasts, how much of the UI it affects, and whether the user has to decide something. Using the wrong surface is the most common way designs feel amateur: a dialog for a harmless hiccup trains users to click it away, a snackbar for a lost connection is gone before anyone reads it.

## The six tiers

| Tier | Surface | Scope | Lifetime | Use for |
|---|---|---|---|---|
| T1 | **Field error** below the input | One input | Until fixed | Validation of one field: wrong format, required, out of range, already taken |
| T2 | **Form summary** callout at the top of a form | One form | Until resubmitted | Submit produced several field errors, or any error is off-screen. Lists each problem as a link to its field. Always shown together with the T1 errors. Use for forms longer than about one screen or with more than ~5 fields |
| T3 | **Snackbar** | Whole app, transient | 4–10 s, longer with an action | Low-stakes feedback about something that just happened: "Task completed · Undo", "Couldn't refresh · Retry". At most one action. Never stack snackbars |
| T4 | **Inline callout / banner** | One screen or section | While the condition lasts | Ongoing conditions: offline, sync paused, plan limit reached, data is stale, permission missing with a way to grant it. Can carry one action. Dismissible only when the condition doesn't affect what the user is doing |
| T5 | **Screen-level error** replaces the content area | One screen's content | Until retry succeeds | The screen's primary content can't load and there is nothing cached to show: 404, 403, server error, offline without cache. App chrome (navigation, top bar) stays so the user isn't trapped |
| T6 | **Blocking dialog** | Whole app, modal | Until the user decides | A decision is required before anything else makes sense: irreversible or costly destructive actions, discarding unsaved work, session expired with unsaved state, payment failed, sync conflict to resolve |

## Picking the tier

Walk this in order and stop at the first match:

1. Does the user have to decide something before they can continue, or is the action irreversible and costly? → **T6**
2. Is it tied to one input? → **T1** (plus **T2** if it came from a submit and the form is long or the error is off-screen)
3. Can the screen's main content not be shown at all? → **T5**
4. Is it a condition that lasts (state, not event)? → **T4**
5. Otherwise it's a transient event → **T3**

The same underlying failure can map to different tiers depending on context, which is the point. "Network request failed" is T5 on first load without cache, T4 when cached data is shown, T3 when a background refresh failed while fresh data is still on screen, and T1 when it's a username availability check.

## Destructive actions

- **Reversible** (archive, complete, remove from a list, delete into trash): do it immediately, then show a T3 snackbar with **Undo**. No confirmation dialog. Confirming every reversible action trains users to click "Yes" without reading, which defeats the dialog when it matters.
- **Irreversible or affects other people** (delete account, delete a shared project, cancel a paid subscription): T6 dialog. The title names the action and the object ("Delete 'Website relaunch'?"), the body states the consequence with numbers ("This deletes 38 tasks for everyone on the project"), the confirm button repeats the verb ("Delete project") in the destructive style, the safe option is the other button. For the most severe cases (account deletion), require typing the name.
- **Leaving with unsaved changes**: T6 with "Discard changes" / "Keep editing".

## Field validation timing

Validate a field when it loses focus, not while the user is typing it for the first time. Once a field shows an error, re-validate on every keystroke so the error disappears the moment it's fixed. On submit, validate everything, show all T1 errors, show T2 if the form is long, and move focus to the summary (or to the first invalid field on short forms). Never disable the submit button to signal invalid input; users can't tell why it's disabled. Let them press it and explain.

## Writing error copy

Every message answers three questions, in this order, in plain language:

1. **What happened** — from the user's point of view, not the system's.
2. **Why** — only if known and useful to the user.
3. **What to do now** — a concrete next step, ideally as the button label.

Rules:

- No error codes, stack traces or HTTP status in the main text. If support needs a code, put it in a small secondary line or a "Details" disclosure.
- No blame ("You entered an invalid email"). Describe the fix instead ("Enter an email like name@example.com").
- No "Oops", "Uh-oh", or jokes on errors that cost the user something.
- Buttons are verbs that say what happens: "Try again", "Delete project", "Sign in again". Never "OK" / "Yes" / "Cancel" alone on T6.
- Reassure about data when it matters: "Your tasks are safe."
- Field errors are specific to the field and the rule that failed, and stay short enough for one or two lines.

Examples per tier:

| Tier | Bad | Good |
|---|---|---|
| T1 | "Invalid input" | "Use at least 8 characters, including a number" |
| T2 | "Form contains errors" | "2 things need fixing before you can save: Title, Due date" (linked) |
| T3 | "Error 500" | "Couldn't refresh tasks · Retry" |
| T4 | "Network error" | "You're offline. Showing tasks from 09:41. Changes sync when you're back online." |
| T5 | "Something went wrong" | "Couldn't load your tasks. The server didn't respond. Your tasks are safe. [Try again]" |
| T6 | "Are you sure?" [Yes] [No] | "Delete 'Website relaunch'? This deletes 38 tasks for everyone on the project. You can't undo this." [Keep project] [Delete project] |

## Visual rules

- Each severity (error, warning, info, success) has its own container color pair **and** its own icon, so meaning doesn't depend on color.
- T1: the field border switches to the error color (2px), an error icon and the message replace the helper text. Link the message to the input with `aria-describedby` and set `aria-invalid`.
- T3 uses the inverse surface so it reads as "on top of" the app. It sits above the bottom navigation and FAB, never covers the primary action.
- T4 sits directly below the top bar, above the content it describes. Offline callouts are `role="status"`.
- T5 keeps the top bar and navigation, centers an icon or illustration, a title, one sentence, and one primary action.
- T6 uses `role="alertdialog"`, a scrim, and is not dismissible by tapping outside when data could be lost.
- Success feedback follows the same logic: small confirmations are T3, a finished multi-step flow can get a dedicated success screen, never a dialog that just says "Success".

## Loading feedback (same decision spirit)

- Initial load with a known layout: skeleton that mirrors the loaded layout. Unknown layout: centered spinner.
- Don't show any loading indicator for operations under ~300 ms; flicker reads as instability.
- Refresh with content on screen: thin linear progress at the top or the platform's pull-to-refresh indicator. Keep content visible.
- Action in progress: loading state inside the button that triggered it (keeps its width, becomes non-interactive). Don't block the whole screen.
- Long operations (> ~5 s): determinate progress with a label, and let the user leave the screen if the work continues in the background.
