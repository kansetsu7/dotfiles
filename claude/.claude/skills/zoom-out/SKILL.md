---
name: zoom-out
description: Interrogate the FRAME of a change before or around building it — the real problem, the real premise, the whole blast radius, and (only when the change selects a tool/library/approach) the decision criterion. Reviews a related ADR if one exists and offers a criterion-first rewrite. Sibling to own-it — own-it drills DOWN into a mechanism's depth; zoom-out steps UP to the frame. Use at design time, when choosing an approach, when writing or reviewing an ADR, or whenever the user senses they're "too in the weeds", "only focused on the local part", wants a higher point of view, or asks to zoom-out / sanity-check the whole solution. Runs on business-only changes too, not just tool selection.
---

# Zoom Out

A rigorous analysis on the wrong frame produces a confident wrong answer. The
frame — the problem you think you're solving, the inputs you assume, the axis
you optimize — is **inherited by default** and stays invisible until someone
one level up questions it. This skill makes the frame explicit and pressure-
tests it *before* you commit to a solution or record it in an ADR.

`own-it` asks "do I understand what I built deeply enough?" — depth, downward.
`zoom-out` asks "am I even solving the right problem, on the right axis,
against the real inputs?" — altitude, upward. Run this one earlier.

## 0. Target + mode

Get the change under discussion (a plan, an approach, a diff, an ADR/MR).
Then detect the mode — it decides which lenses run:

- **Does this change SELECT something** — a library, framework, tool, pattern,
  or one design approach over alternatives? → run the **universal spine (§1)**
  *and* the **selection lenses (§2)**.
- **Is it business/domain logic** with no option-selection (a calculation, a
  rule, a workflow change)? → run the **universal spine (§1)** only, and skip
  §2. Do not manufacture a selection that isn't there.

Read enough of the surrounding solution to judge scope and premise — not just
the diff. The whole point is to look outside the diff.

## 1. Universal spine — runs on every change

**Restate the problem one level up before anything else.** "Pick a form lib"
→ "cover our validation needs sustainably." "Fix this page's total" → "make
the total consistent everywhere it's derived." Everything below checks the
change against the *restated* goal, not the local task.

1. **Root vs symptom** — Am I fixing the cause or patching a local symptom?
   (Fixing one page's number vs the shared calculation both pages call, so
   index and show can't disagree.) If the fix is at the symptom, name the
   root and decide deliberately whether to stop short.
2. **Whole blast radius** — Where else does this logic live or reach? Walk it:
   - other jurisdictions / `site_code`s running the same path,
   - other call sites and other entry points (same rule reached from a job vs
     a controller vs an API),
   - downstream consumers (reports, commission, refunds, exports).
   The diff touches one spot; the *solution* must be coherent everywhere the
   logic reaches. List the places that also need to change or be checked.
3. **Real premise vs convenient premise** — Did I evaluate/build against what
   production actually sends and stores — real formats, real edge cases, real
   scale — or a stand-in I chose because it was easy? (Multipart untyped
   strings vs JSON typed values → a different coercion problem. `nil`
   `created_at` on a brand-new record. Empty/duplicate/boundary rows.) If the
   premise was convenient, redo the evaluation against the real one.
4. **One level up (owner's frame)** — Who inherits this decision or outcome,
   and what do *they* optimize for? Business owner, CTO, future maintainer.
   They usually carry a cost you don't see day-to-day (long-term
   maintenance, cross-entity consistency, audit), which is *why* their
   criterion differs. Pre-empt it: "If I showed this to the person who owns
   it for the next three years, what axis or objection would they add?"
5. **Second-order effects / invariants** — What breaks *because* this is now
   true? Which system invariants must still hold after the change (no
   double-charge, two views consistent, downstream totals intact)? Name the
   ones this change could quietly violate.

## 2. Selection lenses — only when the change picks a tool/approach (§0)

6. **Criterion vs proxy** — What am I actually optimizing, and is my
   comparison axis the real driver or just the *countable* one? Feature count
   is countable; extensibility / cost-of-change is the driver. Test: rank the
   options by the stated axis, then ask "would I choose the winner to *live
   with for two years*?" If not, the axis is a proxy — find the real one.
7. **Snapshot vs derivative** — Am I comparing static properties when a
   dynamic one dominates? The killer question: **"what happens when we need
   something this option doesn't do?"** Cheap-to-extend beats feature-rich-
   but-rigid, because extensibility governs every future state while a feature
   list is one snapshot. (Tag-based validation that's hard to extend fails
   this even if it's feature-complete today.) A missing feature under a cheap-
   extension model is acceptable; a rigid architecture is not.

## 3. ADR pass

- **A related ADR exists** → check that it records the **decision criterion**
  and **each rejected option's fatal flaw on that criterion** — not a feature
  matrix that implies "we picked the one with the most checkmarks." If it
  reads as a feature scorecard, offer a criterion-first rewrite: lead with the
  real driver (e.g. extensibility), state each alternative's disqualifier
  (e.g. tag-based validation is hard to maintain and extend), and note which
  feature gaps are acceptable and why (cheap to extend).
- **No ADR, but the change embeds a real decision** (a policy choice, a
  rejected alternative, a non-obvious trade-off) → flag that it warrants one
  and hand off to `doc-suggestions` for the full Diátaxis treatment rather
  than drafting it here.
- **No decision worth recording** → say so; don't invent an ADR.

## 4. Output

Concise, and grounded in the actual change:
1. **Reframed problem** — the goal restated one level up.
2. **Frame findings** — for each lens that fired, what's solid vs what's a
   symptom/convenient-premise/proxy. Be specific; a vague "looks fine" is
   worthless here.
3. **Coverage gaps** — the concrete places the solution must also reach
   (other `site_code`s, call sites, downstream) that the diff misses.
4. **The owner's objection** to pre-empt (from §1.4), in one line.
5. **Selection verdict** (if §2 ran) — the criterion-first comparison and
   whether it reorders the ranking.
6. **ADR suggestion** (from §3).

## Mindset (state briefly, don't lecture)

- The frame is inherited unless you interrogate it. Senior/staff/CTO judgment
  most often adds value at the frame, not the analysis — which is why a review
  can accept every line of your reasoning and still redirect the whole thing.
- "More features" is a snapshot; "easy to extend" is a derivative that governs
  all future snapshots. Prefer the derivative. Same for premises: the real
  production load beats the convenient stand-in, always.
- Zooming out is cheap and early; a wrong frame is expensive and late. Spend
  the ten minutes before you commit, not after the ADR ships.
