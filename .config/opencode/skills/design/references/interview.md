# Design interview checklist

**The rule:** ask a question only if the answer changes what a screen looks like, which screens or states exist, or which visual direction is right. Backend, data storage, architecture, APIs and libraries are out of scope. If the user starts specifying those, note what's visible to the user and move on.

**Never fill gaps with assumptions.** If a screen's content, a state, or the mood is unclear and the answer isn't in the conversation, the repo, or existing docs, ask. A designer who invents the data model of a screen produces a design nobody can use.

**How to ask:** `AskUserQuestion`, up to 4 questions per call, 2–4 options each, recommended option first with "(Recommended)" and a one-line reason. Batch questions by area. Use `multiSelect` for scope and lists. Plain text only for open questions (the product description, references the user likes). Each question must stand on its own, because the user may only see the dialog.

**Pushback is part of the job.** If an answer will lead to a worse design (a dialog for every error, five accent colors, light theme only for an app used at night), say so in the question's option descriptions and offer the alternative. The user decides.

Record every answer in `brief.md` as it's given.

## A. Product context
- What is the product, in one or two sentences? Who uses it, and in what situation (on the go one-handed, at a desk for hours, glancing between tasks, shared screen in a meeting)?
- How often and how long is a typical session? (Shapes density and how much the UI should guide.)
- Audience: age range, tech comfort, domain expertise. Any accessibility needs beyond AA (low vision, older users, motor impairments)?
- Platforms and form factors: Android, iOS, web, desktop. Phone only, phone + tablet, responsive web with which breakpoints? Orientation? → becomes `viewports` in the viewer.
- Implementation target if known (Compose, SwiftUI, React…). Only to know which platform conventions apply.

## B. Features and screens (the most important block)
For each in-scope feature:
- Which screens does it have (list, detail, create/edit, settings, sheets)? How does the user get there?
- For each screen: what's the single most important thing the user does or learns here (the primary action/question)?
- What data is shown, field by field? For each field: type, typical value, realistic maximum (length, number range, currency, units), optional or required.
- Which actions exist? Which are destructive, and are they reversible?
- What loads asynchronously, what can fail, is there a cache/offline behavior?
- Search, filter, sort, pagination?
- Anything real-time or collaborative (presence, live updates, conflicts)?
- Permissions the feature needs (camera, location, notifications)?

Global: navigation model (tabs, drawer, sidebar, single stack), auth/sign-in, onboarding, settings, notifications.

Use existing docs first: a `docs/breakdown/` from the project-breakdown skill, a README, PRDs, or an existing app in the repo. Confirm what you found instead of re-asking it.

## C. Brand and mood
- Existing brand assets that are fixed: logo, brand colors, fonts, illustration style? Which are negotiable?
- 3–5 adjectives for how the app should feel, and 2–3 it must **not** feel like.
- Reference apps or sites the user likes, and what exactly they like about each (color, density, type, motion, tone). Screenshots or URLs are welcome.
- Competitors to stand apart from.
- Density preference: airy and calm vs. information-dense.
- Visual personality range the user is open to (e.g. soft and friendly, sharp and editorial, technical and utilitarian, bold and expressive).

## D. Themes
- Light, dark, or both? If both: default (follow system is the recommendation)?
- If the user hasn't said: ask, and recommend both with system default unless the context says otherwise (e.g. a kiosk app).
- Any special theme like high contrast or OLED black?

## E. Content and voice
- Language(s) of the UI. Locale for dates, numbers, currency.
- Voice and tone: formal/informal, "you" vs. "we", playful or neutral? Example of a sentence the user would like to see in the app.
- Realistic sample data domain (names, products, amounts) so the designs use believable copy.

## F. Constraints
- Existing design system or component library to extend instead of replacing?
- Platform convention strictness: the default is a custom visual identity on top of platform-correct navigation and component behavior (Material 3 on Android, HIG on iOS, web conventions). Confirm if the user wants stricter native or fully custom.
- Accessibility target if different from WCAG 2.2 AA.

## Approval gate
End phase 1 by showing, in a short message:
1. The brief in 5–8 lines (product, users, platforms/viewports, themes, mood words, constraints).
2. The screen inventory: feature → screens, each with its primary action.

Wait for explicit confirmation. Changes go into `brief.md` before phase 2 starts.
