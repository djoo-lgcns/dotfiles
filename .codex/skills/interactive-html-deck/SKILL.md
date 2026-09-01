---
name: interactive-html-deck
description: Create or extend polished animated single-file HTML presentation decks for technical explanations, team sharing, project updates, architecture stories, PR/issue walkthroughs, RFCs, before/after comparisons, and benefit narratives. Use when the user asks for a moving/interactive HTML deck, browser-based presentation, Confluence-embeddable presentation, or asks to add slides to an existing HTML deck while preserving its visual language and story flow.
---

# Interactive HTML Deck

Create presentation-quality browser decks as self-contained HTML files. Favor clarity, story, and controlled motion over decorative complexity.

## Workflow

1. Understand the story before coding.
   - Identify the audience, the change/problem, and the decision or takeaway.
   - For technical change stories, default to: context -> problem -> mechanism -> behavior -> follow-up -> benefits.
   - Distinguish merged/current behavior from proposed/future behavior. Never present a candidate design as already implemented.

2. Ground factual claims.
   - If the request references public PRs, issues, RFCs, releases, or current documentation, browse or use the relevant connector before writing the deck.
   - If the request references provided files, read those files first.
   - Keep citations in accompanying prose when needed; the deck itself may use concise source labels/links rather than dense citation text unless the user requests citations inside slides.

3. Create or edit the HTML.
   - For a new deck, start from `assets/base-template.html` and adapt it substantially to the content.
   - For an existing deck, preserve its layout system, typography, controls, transitions, and color tokens unless the user requests a redesign.
   - Keep the deliverable as one `.html` file with embedded CSS and JavaScript.
   - Do not require npm, a build step, external fonts, CDN libraries, or external runtime assets unless explicitly requested.

4. Apply the visual system in `references/design-system.md`.
   - Build one primary message per slide.
   - Use diagrams, comparisons, cards, flows, and terminals only when they explain the message.
   - Motion must reveal causality, sequence, or state change. Avoid animation that exists only as decoration.

5. Apply the narrative patterns in `references/story-architecture.md`.
   - Prefer “before -> after -> why it matters” for benefit slides.
   - Prefer “observe -> enforce -> optimize” when showing a detector followed by recovery/enforcement work.
   - Explicitly label proposal/candidate/RFC material.

6. Make it presentation-operable.
   - Support ArrowLeft/ArrowRight, Space, PageUp/PageDown.
   - Support `R` to reset to the first slide.
   - Support touch swipe.
   - Show progress.
   - Make the layout responsive.
   - Implement `?embed=1` so iframe use can hide chrome/hints without changing the deck content.

7. Verify before delivery.
   - Run `python scripts/verify_deck.py <output.html>`.
   - Fix all ERROR items.
   - Review WARN items and fix them when relevant.
   - If a browser renderer is available, visually inspect at least the first, one middle, and final slide at desktop size. Do not claim visual QA if no renderer was used.

## Content rules

- Use concise Korean or English matching the user's language.
- Write slide titles as claims, not generic section labels.
- Keep body copy short enough to scan from a distance.
- Use exact distinctions such as detection vs enforcement, ordering vs dependency, implemented vs proposed.
- When comparing versions, phrase benefits as newly enabled capabilities and operational effects, not vague adjectives.
- For future work, use “expected benefit”, “candidate design”, or “if merged” language.
- Avoid falsely implying that all downstream work must rerun if the actual proposal is about calculating a minimal affected set.

## Editing existing decks

When the user asks to add or change a small number of slides:

- Modify the existing file rather than rebuilding the entire deck.
- Preserve existing slide order unless the requested change requires movement.
- Update page counts consistently.
- Keep existing navigation and embed behavior intact.
- Add only the requested slides/content unless a small consistency fix is necessary.
- Deliver a new output filename rather than overwriting the user's only copy when feasible.

## Deliverable

Return the generated `.html` file as the primary artifact. Mention the main controls briefly. If Confluence embedding is relevant, mention that the file must be served from an iframe-accessible HTTPS URL and that `?embed=1` is available.
