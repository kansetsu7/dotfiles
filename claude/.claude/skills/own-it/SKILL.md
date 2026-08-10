---
name: own-it
disable-model-invocation: true
description: Gauge how well the user actually understands a change they're delivering or reviewing, and enforce the depth its blast radius demands. Runs on a real target (current diff, a commit, or an MR under review). For security-class changes it also tests the threat model the change exists to counter — the attack, its preconditions, and which link the change cuts. Use before sending an MR, before approving someone else's, or whenever the user says they "understand it but couldn't describe the mechanism", feels unsure how deep to go, or asks to own-it / depth-check a change.
---

# Own It

Depth should track **blast radius and who's on the hook**, never diff size or
how confident the prose sounds. This skill runs that calculus against a
concrete change and finds the gaps by making the user *regenerate* the
mechanism, not merely recognize it.

The user is a tech lead who both delivers and reviews. Wear both hats.

## 0. Get the target

Ask which, if not obvious from context:
- **Deliver mode** — a change the user authored and is about to send
  (current working diff, staged diff, or a named commit/branch).
- **Review mode** — a change someone else authored that the user is
  reviewing (a commit, an MR/PR, a branch diff).

Read the actual diff. Read enough surrounding code to judge contracts and
callers — do not gauge understanding from the commit message alone; a great
message can be written (or AI-generated) without the understanding
transferring.

## 1. Threat model first (security-class changes only)

Skip this section when the change isn't defending against an adversary. Run it
for authn/authz, crypto, session handling, injection, CSRF/CORS, secrets, rate
limiting.

The attack lives **outside the diff**, so the Called/Chose pass below can never
surface it — a change can be correct line by line and still defend nothing.
Make the user regenerate the attack before you look at the code:

- **Walk it end-to-end** — attacker's setup → victim's action → what reaches
  your endpoint → what the attacker gains. Concrete actors and requests, not a
  category name. "CSRF" is a label; "attacker's page auto-submits a form to
  `/transfer` while the victim's session is live" is the mechanism.
- **Name the necessary preconditions** — every link that must hold for the
  attack to work *at all*. (Classic CSRF needs the browser to auto-attach
  ambient credentials, **and** needs the endpoint to accept a request the
  attacker's origin can cause the browser to issue.)
- **Point at the link this change cuts** — and why it can't be restored. A
  defense the user can't map to a specific precondition is cargo cult, however
  clean the code is.
- **Check the precondition actually holds here** — verify against the codebase,
  don't assume. If an endpoint authenticates by `Authorization` header rather
  than a cookie, classic CSRF can't reach it; a token there is dead weight, and
  worse, it can mask which endpoints *are* cookie-authenticated and unprotected.

Whatever the user can't regenerate here joins the study list, same as a code
gap. Route the *alternative controls* question — is there a cheaper or
complementary defense, what do other frameworks do — to `zoom-out` §2. That's
option-space, not depth.

## 2. Split every notable decision into two columns

- **Called** — library/framework primitives the change invokes
  (`hmac.New`, `pbkdf2.Key`, an ORM scope, a framework callback). The user
  owes only the **contract** (what it guarantees) and the **misuse modes** —
  never the internals. Do not manufacture doubt about these.
- **Chose** — decisions the author made: ordering, which primitive over which
  alternative, boundary/length/encoding choices, error-vs-panic, separator
  handling, what is and isn't checked. The user owes a **two-sentence defense**
  of each.

State the split back to the user as a short list. The insight to surface:
**in security/correctness-critical code, the bugs live in the Chose column —
they are composition bugs, not primitive bugs.** (Decrypt-before-verify is a
Chose bug; AES itself is fine.)

## 3. Assign a tier to each area (blast radius, not size)

1. **Re-derive & defend** — auth, crypto, money, data deletion/migration,
   anything the user authored in these domains, **and any shared primitive or
   pattern other people will copy**. Non-negotiable, and usually small enough
   to actually do in an evening.
2. **Know failure modes & radius** — ordinary code the user authored: how it
   fails, what it takes down with it.
3. **Contract & misuse only** — libraries called. Never the internals.
4. **Know it exists & where it lives** — everything else.

Call out when a change sits in tier 1 for *two* reasons at once (e.g. authored
crypto **and** a shared primitive the rest of a migration will build on) —
that removes any doubt about whether it's worth the time.

## 4. Regenerate, don't recognize — the self-test

Recognition (reading the diff and nodding) passes on code the user could never
have written. The real test is reproduction. Generate **4–8 questions grounded
in the specific code in front of you**, then **make the user answer before you
reveal anything** — one at a time, like an interview. Where they stall is the
study list.

Good question shapes (instantiate them from the actual diff):
- *Mechanism*: "Walk the bytes from wire input to the returned value."
- *Why-this-not-that*: "Why `hmac.Equal` and not `==`? Why `QueryUnescape`
  and not `PathUnescape`?"
- *Attacker/failure*: "This value reaches `X` unverified — what does an
  attacker actually do with that, and in how many requests?"
- *Invariant*: "This looks unsafe but works. What invariant makes it safe,
  and where is that invariant written down? What breaks it?"
- *Category*: "Is this function a security check or a decode step? What
  happens if a caller treats it as the other?"

In **review mode**, aim the same questions at the author's choices: can the
user reconstruct the mechanism well enough to defend the approval? Which Chose
items did the author leave undefended or undocumented?

For anything the user genuinely can't answer, prefer verifying it against the
codebase or a tiny throwaway experiment over hand-waving — confirm the
invariant, don't assert it. If a safe-by-accident invariant isn't stated in
the code, flag it: it should be a comment or a switch to the unconditionally
safe call.

## 5. Lead-hat pass (do this even in deliver mode)

The depth rules above are universal — every developer owes them on their own
code. What the lead role *adds* is accountability across people and time:

- **Shared/copyable surface** — is this a primitive, base class, or pattern
  others will reuse? If so it's tier 1 regardless of how it reads, because the
  radius includes code not yet written. Is this the pattern you want copied?
- **Disclosure** — is there an honest note of what was and wasn't verified?
  (See §6.) Modeling this yourself is a lead act: it makes it *cheap* for
  juniors to admit gaps instead of shipping them silently.
- **Tier calibration** — flag the fuzzy boundary calls (is this feature flag
  on a payment path tier 1?) so the *decision* is explicit, not accidental.

## 6. Output

Produce, concisely:
0. **Threat model** (if §1 ran) — the attack in the user's own words, its
   preconditions, the link this change cuts, and any endpoint where the
   precondition holds but the defense doesn't reach.
1. **Called / Chose** split.
2. **Tier per area**, with the tier-1 items named.
3. **Self-test results** — what the user answered solidly vs the study list
   (the questions they couldn't regenerate). Be honest; a soft pass here is
   worthless.
4. **Invariant/comment flags** — safe-by-accident spots that need a note or a
   safer call.
5. **A disclosure snippet** for the MR/approval, in the user's own honest
   voice, e.g.:
   > Ported from `lcl`; pinned to byte-parity against captured fixtures. I
   > have **not** independently audited the underlying scheme. Verify-then-
   > decrypt ordering and the `+`-free-payload invariant are the two choices
   > worth a reviewer's eyes.

## Mindset (state briefly, don't lecture)

- You will never understand everything, and it isn't the job. The job is
  knowing **which tier each thing is in** and being **honest in the MR** about
  it. The gap between a pro and an amateur here is disclosure, not knowledge.
- "I understand it but couldn't describe the mechanism" = recognition without
  regeneration = a real gap, not impostor syndrome. It's also two hours of
  study, not a career — say so.
- On security code, "the tests pass and the library is correct" proves nothing
  about whether you stopped the attack. Correct code aimed at a precondition
  that doesn't hold is still zero defense.
- Silently shipping tier-1 code you can't explain is the only actual failure.
  Admitting the gap out loud is the fix, and coming from the lead it sets the
  norm for everyone who reports to you.
