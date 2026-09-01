# Story Architecture

## Technical change / PR story

Use this default sequence when appropriate:

1. Title: the tension/question, not the implementation name alone.
2. Problem: what the previous system could not distinguish or guarantee.
3. Failure/propagation scenario: make the hidden risk concrete.
4. Mechanism: the new evidence/model/engine behavior.
5. Runtime behavior: how the system reacts now.
6. Before/after: show observable behavioral difference.
7. Takeaway: one sentence describing the capability created.
8. Follow-up: what remains unsolved and why it deserves separate work.
9. Candidate design: clearly mark as proposed.
10. Benefit: translate implementation into user/team/system value.

## Detector -> enforcement follow-up

When one change detects invalidity and a later change handles it, use this ladder:

- Observe: know that prior output is no longer trustworthy.
- Explain: know why / which evidence changed.
- Enforce: prevent unsafe normal routing when policy requires it.
- Recover: identify the correct revalidation/re-execution point.
- Optimize: reduce recovery to the minimal affected subgraph.

Do not collapse these into one capability.

## Benefit slides

For “what benefit did version B create over version A?” use four lenses:

- Previous limitation.
- Newly enabled capability.
- Operational or quality effect.
- Compatibility/cost/system effect.

Example wording pattern:

- Before: “Only completion history was known.”
- After: “Current validity can be evaluated separately.”
- Effect: “Less reliance on opportunistic model inference.”
- Adoption: “Legacy workflows continue fail-open.”

For future issues, use conditional language:

- “If merged, this would enable…”
- “Expected operational effect…”
- “Candidate typed-edge model…”

## Proposal boundary slide

When a deck mixes merged work and a follow-up proposal, add a boundary slide or explicit statement:

- Merged work: implemented behavior.
- Follow-up issue: policy/design under discussion.
- Candidate details: one possible implementation, not a claim about current behavior.
