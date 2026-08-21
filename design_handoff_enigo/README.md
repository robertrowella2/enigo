# Handoff: Enigo — text-first connection app (iOS + Android)

## Overview
Enigo matches two people on compatibility answers and lets them build a relationship purely through conversation. No photos, no browsing, no swiping. Identity unlocks progressively as both people show up: **username (from the start) → interests → bio → location → photo ("graduation")**. Thresholds are hidden from users. Positioning: *a mystery worth waiting for.*

This bundle covers the whole product surface: 25 screens from pre-signup onboarding through the eleven compatibility questions, the match reveal, the live chat with its unlock mechanic, the soft-exit and report flows, and the Pro / profile / settings / account screens.

## About the Design Files
The files here are **design references created in HTML** — a working prototype of intended look and behavior, not production code to lift. `Enigo.dc.html` runs on a small in-house HTML runtime (`support.js`) that is irrelevant to your build; ignore it.

Your task is to **recreate these designs natively** — SwiftUI for iOS, Jetpack Compose for Android — using each platform's real material system. The prototype deliberately approximates what the OS gives you for free:

- iOS: translucent chrome is `backdrop-filter` in the prototype; use **real Liquid Glass materials**.
- Android: solid tonal surfaces; use **Material 3 tonal elevation and dynamic color**, seeded from the brand navy/gold rather than the wallpaper.

Do not build one cross-platform styling layer. The brand tokens are shared; the chrome, dialogs, navigation, and motion are not.

## Fidelity
**High-fidelity.** Colors, type, spacing, radii, copy, and interaction behavior are all final-intent. Recreate faithfully. Where a value below conflicts with the HTML, this document wins.

## Platform + theme model
The prototype has a `platform` (iOS/Android) and `theme` (Follow system / Dark / Light) switch for review purposes only. **Ship neither.** Platform is the build target; theme follows the OS.

Both themes are first-class, not inversions:

| | Dark (default) | Light |
| --- | --- | --- |
| Background | navy `#0B1D3A` | ivory `#EFE9D8` |
| Dominant / headings | gold `#D4AF37` | navy `#0B1D3A` |
| Primary button | gold fill, navy label | navy fill, ivory label |
| Accent (selected states) | `#D4AF37` | `#A8861C` (deepened for contrast on cream) |
| Body text | warm gold-tint `#E8D9A8` | navy `#0B1D3A` |
| Danger | `#E4A08C` | `#9E3A1C` |

Light mode is **not** pure white anywhere, and gold recedes to accents only.

---

## Design Tokens

### Color
```
navy-900   #0B1D3A   dark bg, light-mode text/buttons
navy-950   #08152B   dark-mode page surround
navy-800   #0F2547   dark-mode sheet base
gold-500   #D4AF37   dark-mode dominant, accents
gold-700   #A8861C   light-mode accent
warm-200   #E8D9A8   dark-mode body text
ivory-100  #EFE9D8   light bg
ivory-300  #DED5BD   light-mode page surround
danger-dk  #E4A08C
danger-lt  #9E3A1C
```
Every non-solid surface is an alpha of the theme's foreground or gold, not a new hex. The recurring set: `0.03 / 0.05 / 0.06 / 0.07` fills, `0.09–0.14` hairlines, `0.32–0.62` muted text. Selected states: gold at `0.12` fill, `0.55` border.

### Typography
- **Fraunces** (serif) — all headings, and *all tap-to-select answer options*, so questionnaire screens read as one uniform typographic block. Weights 400/500/600.
- **Inter** — body copy, UI labels, small-caps eyebrows, chat messages.

| Role | Size / line-height | Family | Notes |
| --- | --- | --- | --- |
| Screen title | 31px / 1.14, w600, `-0.025em` | Fraunces | 29px on dense screens |
| Question text | 28px / 1.18, w600, `-0.02em` | Fraunces | |
| Match username | 34px / w600 | Fraunces | |
| Answer option | 17px / 1.32 | Fraunces | |
| Chip label | 14.5–15px | Fraunces | |
| Body | 14.5px / 1.6 | Inter | at 0.62 alpha |
| Chat message | 15px / 1.5 | Inter | |
| Eyebrow | 10–11px, `letter-spacing 0.16em`, uppercase | Inter | at 0.4 alpha |
| Meta / caption | 11.5–12.5px / 1.6 | Inter | 0.38–0.5 alpha |

### Shape, spacing, motion
- Radii: **14px** buttons, chips, list rows (per brand: flat, no elevation/shadow anywhere); 16px inputs and message bubbles; 18px cards; 22px photo well; 26px bottom sheet top corners; 99px pills/toggles; 50% avatars.
- Screen padding: 28px horizontal on flows, 22px on list screens. Vertical stack gap 20px, tight groups 8–10px.
- Top padding is platform-dependent: iOS 76px/70px/58px (safe area + glass header), Android 26px/22px/14px (frame supplies its own app bar).
- Motion: `enRise` 320–500ms ease (sheets, celebrations), `enBreathe` 3.4–3.6s infinite (searching pulses, typing dots), `enShimmer` 1.2s (text cursors). No spring, no bounce — the app is unhurried.
- Min hit target 44px; the send button is 46×46.

---

## Screens

Grouped as they appear in the prototype's left-hand index.

### 1. Onboarding
**Intro (4 swipeable slides)** — shown *before* signup. Placeholder art block 210px tall, then Fraunces 33px title, body, dot indicators (active dot widens to 22px), primary CTA, and "I already have an account". Slides: no photos/no swiping → matched on answers not faces → things unlock as you show up → it's slow on purpose. Last slide's CTA becomes "Create an account".

**Phone** — country code + number, one field focused. Copy states the number is for login *and* age verification and is never shown to matches. 18+ only.

**Verify** — six digit boxes, active box gold-bordered, resend countdown.

**Photo (step 1 of 3)** — 196px dashed-border upload well. Copy: "Add a photo nobody sees yet". A gold-tinted reassurance strip reads "Hidden until graduation. Always." In the prototype the picker accepts a real file and shows `SEALED · filename` — nothing is uploaded.

**Interests (step 2 of 3)** — 80 tags across outdoors, food, music, reading, making, games, quieter things. Multi-select Fraunces chips, minimum three; the CTA reads "Pick n more" (disabled styling) until satisfied, and a live "n chosen" counter sits above the grid.

**Bio (step 3 of 3)** — the only free-text field in the entire product. 240 char cap, Fraunces 16px, counter plus "Unlocks after your interests do".

### 2. Identity & safety
**Gender** — Woman / Man / Nonbinary / "I'll describe it myself"; the last reveals a free-text field.

**Matched with (1 of 3)** and **Shown to (2 of 3)** — two symmetric multi-selects (Men / Women / Nonbinary people / Anyone). These are a **hard filter: a match requires both sides' preferences to overlap.** The framing deliberately avoids asking anyone to assert an unverifiable orientation label.

**LGBTQ+ (3 of 3)** — "Is Enigo an LGBTQ+ space for you?" Four options: match me inside the community / it matters but I'm open either way / not what I'm looking for / rather not say. **Optional** — the CTA reads "Skip this one" until answered. The footnote changes with the selection to state exactly what the answer does: a filter, a lean, or nothing. Never shown on a profile; nobody is told what was picked.

**Location** — permission toggle plus radius chips (25 / 50 / 100 km / Anywhere). Matches are **ranked closest-first**, but location remains a *sealed field* until it unlocks in conversation — these two facts must not be conflated in copy. Rough area only, never an address, never live location. If nobody fits the radius, widen the circle before lowering the compatibility bar.

**Intent** — A close friend / Open to wherever it goes / Not sure yet, just curious.

**The eleven questions** — all single-select, tap-to-advance (240ms), no typing anywhere. Back arrow, 11-segment progress bar, "n of 11". Categories in order: values ×2, conflict ×2, responsiveness ×2, openness, conversation ×2, rhythm, patience. Grounded in relationship research on values alignment, responsiveness, and escalating reciprocal self-disclosure. The closing question asks how the slow pacing sits with them. Full copy is in the prototype's `QUESTIONS` array — treat it as final.

**Notification permission** — plain-language: new messages and unlock moments *only*; never streaks, never "someone's waiting". Then the real OS prompt, styled per platform (iOS alert / M3 dialog with right-aligned text buttons).

### 3. Match & chat
**Searching** — two concentric breathing rings around a gold diamond. "Looking for one good match", explicitly "this can take a day or two". Copy varies on whether location was granted.

**Match reveal** — striped placeholder avatar with initial, `@username` at 34px, and "That's everything you get for now. No photo, no name, no city." A "WHY YOU TWO" card names the shared answer that produced the match, with a footnote that she's the closest strong match inside the chosen radius. Actions: "Start the conversation" / "Not right now".

**Chat** — header shows username and **this-match** message count (never a global counter), plus a "Known" button. First-time hint: "You know each other's usernames. Everything else arrives in its own time." Own messages gold-tinted right-aligned, hers foreground-alpha left-aligned, both 16px radius. Three-dot breathing typing indicator. Composer + 46px send button; Enter sends. "Long-press a message to flag it" opens the report flow.

**Known (bottom sheet)** — the five fields in unlock order, each either revealed or "Not yet". Closes with: "Both of you have to keep showing up for the next one. We don't say how close it is — that's the point." Also holds Report and "This isn't quite it".

**Unlock celebration** — full-screen scrim, breathing ring, badge, "SOMETHING UNLOCKED", the revealed value in Fraunces, and a note. One field at a time, **no progress number, ever**. Graduation is the photo.

**This isn't quite it (soft exit)** — states plainly that the other person won't be notified: no notification, no last-seen. Optional reason chips. Shows remaining free rematches.

**Report** — categories: harassment or threats / inappropriate content / fake profile / asking for money / something else. Optional detail. Reachable from the thread or a flagged message. **Reporting always ends the match immediately and permanently excludes that pair from rematching.** "A human reads every report."

### 4. Pro & account
**Connections dashboard** — up to three simultaneous, sorted closest-first with distance per row, each showing a four-stage unlock strip (INTERESTS / BIO / PLACE / PHOTO). "Start a new connection" is a dashed CTA on iOS, a FAB-style action on Android.

**Paywall** — Pro $8/month: three conversations at once, unlimited fresh starts, shared-interest matching (bio-keyword overlap boost, Pro-only). Secondary: one-time **$2 boost** for a single extra rematch after the free tier's 3 declines. "Cancel any time."

**Own profile** — username prominent as the default identity, first-name display as a toggle, interests / bio / location / photo rows, "Retake the eleven questions".

**Settings** — Identity, Matching (LGBTQ+ preference, location, radius, "Order: closest first"), Notifications (messages On, unlocks On, "Everything else — Off, always"), Account.

**Subscription** — active-plan card, manage in store, restore purchases, cancel. Cancelling keeps existing connections until they end naturally — nothing is cut off mid-conversation.

**Sign-in help** — no passwords exist; a code is texted to the signup number. Support never asks for a photo of a face.

**Delete account** — irreversible, offers data export first, matches see the conversation close without a reason.

---

## The core mechanic — implement server-side

This is the product. Get it wrong and the whole premise collapses.

1. **Per-person counters, never pooled.** Each side of a match has its own progress. A chatty partner cannot carry a quiet one. A field unlocks only when **both** counters clear that field's threshold — i.e. `min(a, b) >= threshold`.
2. **Character-weighted messages.** Only messages meeting a minimum length advance a counter (the prototype uses 40 characters as a stand-in). Ship a minimum *average* character count per message so filler can't be farmed. Tune the real thresholds against live data; the prototype's demo values (3/6/9/12 heavy messages) are for demonstration only, with a "Realistic" preset at 12/30/55/90.
3. **Thresholds are never exposed.** No counts, no percentages, no "2 more messages" — not in UI, not in API responses. The client must not be able to compute proximity to an unlock.
4. **Unlock order is fixed:** interests → bio → location → photo.
5. **Photo access must be enforced server-side.** Media URLs stay unissued until both counters clear the graduation threshold. A client-side `hidden` flag is trivially bypassable and would leak the one thing the product is built on. Same for bio and location payloads.
6. **Contact-info exchange is always an explicit mutual action.** Never automatic, never a side effect of graduation.
7. **Preference overlap is a hard filter** evaluated before compatibility scoring; distance ranks *within* the eligible set.

## State
Prototype state, as a guide to the real model:

- Onboarding: `interests[]`, `bio`, `photo`, `gender` (+ self-described string), `matchWith[]`, `shownTo[]`, `community`, `locGranted`, `radius`, `intent`, `answers{1..11}`
- Match: `username`, `unlocked[]`, and the two hidden counters
- Chat: `messages[]`, per-person heavy-message counts, cumulative characters
- Account: `showFirstName`, subscription tier, rematches remaining, blocked list

The prototype persists all of this to `localStorage` under `enigo.demo.v1` purely so a demo survives reload. **Nothing real is stored anywhere in this bundle** — every username, message, bio, and photo in it is mock content living in the file. The photo picker reads a filename and discards the file.

Real build needs: phone-auth identity, a message store with per-person counters, and access-controlled media storage.

## The AI partner is a demo device
In the prototype, the match ("@wrenandfog") replies via a live model call with a system prompt keeping her in character and refusing to reveal her name, city, or appearance ahead of unlock. **This exists so the mechanic can be experienced solo — it is not a product feature.** In production the other side is a human. If you ever *do* want a warm-start persona, that is a separate product decision with its own disclosure obligations.

## Copy & tone
Warm, a little mysterious, unhurried — the opposite of a swipe-fast app. Patience and intentionality, never urgency. No emoji anywhere. No streak mechanics, no re-engagement nudges, no "someone is waiting". Soft-exit is "This isn't quite it", never "reject" or "unmatch". Copy in the prototype is final-intent; lift it verbatim unless legal requires otherwise.

## Assets needed
Everything visual is a placeholder awaiting real material:
- Four intro-slide illustrations or photographs (`NO FACES`, `ELEVEN ANSWERS`, `SEALED ENVELOPE`, `SLOW LIGHT`)
- Avatar treatment for pre-graduation state — currently a diagonal-striped block with an initial
- App icon, and the diamond mark used as the logo and as bullet accents
- Fraunces + Inter via Google Fonts; bundle them natively

## Not yet designed
Terms of service / privacy policy screens, the referral/invite mechanic, and the admin/ops surface for the matching algorithm.

## Files
- `screens/` — reference PNGs of twelve key screens (iOS dark, iOS light, Android) with an index; see `screens/README.md`. Representative, not exhaustive — the prototype is the full inventory.
- `Enigo.dc.html` — the complete prototype: all 25 screens, both platforms, both themes. Copy, tokens, and the eleven questions live in its logic class.
- `ios-frame.jsx`, `android-frame.jsx` — device chrome for presentation only; do not port.
- `support.js` — prototype runtime. Ignore entirely.
