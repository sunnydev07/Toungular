# Toungular — product and technical design (v2)

Date: 2026-11-09
Version: 2 (revised after design review)
Status: **Draft v2 for approval. No app implementation authorized until approved.**

## What changed in v2

- Added a phased delivery plan with Phase 0 and Phase 1 exit criteria.
- Resolved or proposed defaults for backend, auth, speech pipeline, voice retention, content format, and measurement.
- Deferred referral/buddy streaks, achievements, voice conversation, full IELTS mocks, pronunciation scoring, and monetization to later phases.
- Added offline behavior, cost/abuse controls, compliance, non-functional requirements, analytics events, and a risk register.
- Removed the premature future-language abstraction; the v1 data model is English-only.

## Intent

Build Toungular as a new Android English-learning app that helps learners improve spoken fluency and usable vocabulary. The user asked for the feature breadth of Stimuler and defined success as learners becoming expert in the language, particularly in fluency and vocabulary. Toungular will be implemented from a clean project with its own identity, learning materials, services, and monetization configuration.

For product measurement, v2 treats “expert” as measurable improvement against a fixed assessment, not as a claim of expertise or certification.

## What the target investigation establishes

The acquired Stimuler 2.4.39 package is a Flutter app. Its public product descriptions and packaged sample assets point to speaking practice, fluency/vocabulary/pronunciation/grammar feedback, AI conversation and role-play, IELTS speaking mocks, lessons/roadmap, progress, and streak features. The package contains Firebase, billing, attribution, and payment SDK declarations and static API route strings, but that does not reveal live execution or private service behavior. There was no device or emulator available, so ad placements, exact screens, and runtime flows remain unobserved. See [static investigation notes](../../../reverse-engineering/stimuler-2.4.39-static-notes.md).

## Goals

- Deliver an Android-first, English-first app with the same broad learner-facing capability areas evidenced for Stimuler, delivered in phases rather than one build.
- Make fluency and vocabulary progress visible through a fixed baseline assessment, session feedback, review, and comparable follow-up summaries.
- Support spoken practice with recording/playback, speech transcription, transcript-based fluency/vocabulary/grammar feedback, and later pronunciation feedback, AI-guided conversation, role-play, and IELTS-style practice.
- Provide a structured curriculum across vocabulary, grammar, pronunciation, and integrated practice, with a daily learning path that adapts to learner results.
- Add learner profile/onboarding, practice history, reminders, streaks, progress insights, subscription handling, referral support, and an ad-supported free tier in later phases, without weakening the core loop.
- Keep Toungular operationally independent: original code, UI, copy, curriculum, backend, AI/provider configuration, analytics, ad account, and purchase verification.

## Non-goals and anti-goals

- Do not patch, repackage, or redistribute Stimuler’s APK or copy its source/assets/branding.
- Do not call, depend on, or attempt to reproduce Stimuler’s private endpoints, credentials, account systems, models, prompts, scoring implementation, or data.
- Do not claim that the exact Stimuler internals or ads have been reproduced. Only observable product behavior can be approximated; server algorithms and unobserved runtime details are unknown.
- Do not add learning languages beyond English in v1, and do not build a language/curriculum abstraction for hypothetical future languages.
- Do not build a content-management system in Phase 1; ship validated, versioned bundled content instead.
- Do not interrupt active speaking or recording sessions with ads.
- Do not fabricate transcripts, scores, or AI feedback when a provider is unavailable or unconfigured. Show a clear unavailable/retry state instead.
- Do not present model-generated pronunciation or fluency estimates as objective certification.

## Approaches considered

1. **Patch and rebrand the Stimuler APK.** Rejected because the request is to build from scratch, and the app’s proprietary backend, content, and account services are not available for reuse.
2. **Create a UI-only or narrow learning MVP.** Rejected because the user asked for broad feature parity, and this would omit core speaking, feedback, IELTS, progress, and monetization areas.
3. **Build a clean-room Toungular product for broad behavioral parity.** Selected based on the user’s request. Reuse only general product-level ideas inferred from public descriptions and package evidence; implement original interfaces, content, service logic, and integrations.

## Product shape

### Main learning loop

1. Onboarding captures proficiency, goals, available practice time, and optional IELTS intent; a short placement activity establishes a starting point.
2. A home/roadmap view presents a daily plan and progress in speaking, vocabulary, pronunciation, and grammar.
3. Learners complete short lessons, vocabulary retrieval/review, pronunciation drills, open-ended speaking prompts, role-play, or IELTS-style mock sections.
4. Speaking results show a transcript and actionable feedback, including vocabulary opportunities and fluency/pronunciation observations, with recording playback and a link to targeted follow-up practice.
5. Results update skill history and the next recommended lesson; streaks and reminders reinforce consistent practice.

### Major areas by phase

| Area | Phase | Notes |
|---|---|---|
| Onboarding, profile, sign-in | 1 | Google Sign-In + email OTP; microphone permission at first recording |
| Placement and fixed assessment | 1 | 2 speaking prompts + 20-item vocabulary check; repeatable protocol |
| Daily path and vocabulary review | 1 | Bundled lessons; simple spaced-review scheduler |
| Speaking studio | 1 | Record, playback, transcript, fluency/vocabulary/grammar feedback, history |
| Progress and streak basics | 1 | Session count, skill trend, basic streak |
| Grammar lessons | 2 | Original themed material and retrieval exercises |
| Text role-play and AI coach | 2 | Graceful unavailable state; no fake coach |
| IELTS-style timed speaking | 2 | Original prompts; “practice” wording, no affiliation |
| Pronunciation scoring | 2 | Provider spike and calibration before showing scores |
| Voice conversation, reminders, achievements | 2 | Voice chat after file-based feedback is reliable |
| Monetization: subscription, ads, referral | 3 | Play Billing + server verification + RTDN; consent-managed ads |

## Delivery plan

### Phase 0 — de-risk (days)

Tasks:
- Fix the local environment: add Flutter to PATH, accept Android SDK licenses, install an emulator/system image or connect a physical Android device.
- Confirm the implementation baseline and the open decisions below.
- Create the Flutter Android project, backend project, and a CI build.
- Run a provider spike: two managed STT providers on about 20 varied English samples, plus one LLM producing a fixed JSON feedback schema. Record latency, cost, and output quality.
- Build one vertical slice: record → upload → transcript (mock, then real) → feedback (mock, then real) → persist and show history.

Exit criteria:
- A debug APK builds in CI.
- On a device or emulator: record, play back, upload, see a transcript and feedback, relaunch, and see history.
- No provider secret exists in the app; all provider calls go through the backend.
- One STT provider and one LLM provider are selected and recorded with sample metrics.

### Phase 1 — core learning loop (weeks)

Scope: onboarding/profile, placement, daily path, vocabulary review, speaking studio, progress/streak basics, account deletion.

Explicitly out of Phase 1: ads, billing, referral, IELTS, role-play, voice chat, achievements, pronunciation scores, cross-device sync, CMS.

Acceptance criteria:
- A new user completes onboarding and placement (2 fixed prompts + 20-item vocabulary check) in under 10 minutes.
- The daily plan shows one lesson and a review queue built from seeded content (roughly 100–150 vocabulary items and 15–20 short lessons).
- A vocabulary result schedules the next review date through a single scheduler interface (simple SM-2 or FSRS).
- A speaking session records up to 90 seconds, plays back locally, uploads for processing, and shows a transcript plus rubric feedback with evidence and one next step per dimension.
- A failed or timed-out job shows a retry state and never a fabricated result.
- Deleting a session removes local audio and server transcript/feedback.
- Offline: lessons and review open from local cache; speaking shows a clear network requirement.
- Feedback p95 is under 20 seconds for a 60-second recording.
- Account deletion works end to end (in-app and a public web link).
- The analytics events below fire, and no audio or transcript content is sent to analytics.

### Phase 2 — practice breadth

- Grammar lessons, text role-play with turn-aware coaching, IELTS-style timed speaking sections, pronunciation scoring, reminders, achievements, and model-answer TTS.
- Every feature ships with seeded original content, an unavailable/retry state, and a content validation check.

### Phase 3 — monetization and habits

- Google Play Billing with server-side purchase verification and real-time developer notifications (RTDN), paywall, restore purchases, referral, and consent-managed ads.
- Provisional free limits: daily lesson and vocabulary review free; 3 AI speaking sessions per week free; subscription removes the AI session cap. Final tiers and prices remain open.
- Provisional ad placements: home and post-session history only; never during onboarding, recording, feedback, or a lesson. Frequency cap and consent handled by the ads provider’s consent flow.
- Exit criteria: test purchases verify server-side; entitlements survive renewal, cancellation, grace, and account hold; ads never appear in speaking; consent flows work in EEA/UK test mode.

## Technical direction

### Proposed baseline (confirm in Phase 0)

- **Client:** Flutter stable, Android-only build target. Feature-first structure; Riverpod for state, go_router for navigation, Drift for local cache; `record`/`just_audio` for audio; platform TTS for vocabulary playback. Flutter is chosen because it fits the team’s build capability and supports an Android-first launch, not because the target used it.
- **Backend:** Supabase (Postgres, Auth, Storage, Edge Functions) as the proposed default to avoid running separate infrastructure. All AI, speech, and purchase-verification calls happen in Edge Functions; no provider keys in the app. Alternative if an existing GCP deployment is preferred: Cloud Run + Postgres. Decide in Phase 0.
- **Auth:** Google Sign-In + email OTP. No phone/Truecaller sign-in in v1.
- **Content:** Bundled, versioned JSON validated in CI. Content changes ship with app releases in Phase 1; no CMS.
- **Speech and AI:** Server-side adapters only: `SpeechToText`, `FeedbackModel`, `PronunciationScorer` (Phase 2), `Tts` (platform first). Provider choice comes from the Phase 0 spike and stays replaceable.
- **Ads:** Adapter plus test configuration in development; production IDs only from a Toungular-owned account (Phase 3).
- **Purchases:** Play Billing with server-side verification and RTDN under Toungular’s account; do not reuse Stimuler’s RevenueCat or Razorpay identifiers (Phase 3).
- **Analytics:** Privacy-conscious event pipeline; pseudonymous user IDs; no raw audio, transcripts, or free-text answers in events.

### Data model (Phase 1)

`profiles`, `placement_results`, `lessons`, `exercises`, `vocab_items`, `review_states`, `sessions` (type, status, timestamps), `feedback`, `analytics_events`. Phase 3 adds `entitlements` and purchase records.

### API surface (Phase 1)

Authentication is handled by the backend auth provider. The app calls a small REST surface over HTTPS:

```
GET/PATCH /v1/profile
POST      /v1/placement
GET       /v1/plan/today
POST      /v1/reviews
POST      /v1/sessions
POST      /v1/sessions/{id}/recording   -> 202 processing job
GET       /v1/sessions/{id}             -> status, transcript, feedback
GET       /v1/sessions
DELETE    /v1/sessions/{id}
DELETE    /v1/account
POST      /v1/events
```

Audio upload uses a short-lived signed URL into a private bucket. Processing runs in a queued background worker, not in the request path, and is idempotent; the client polls session status in Phase 1. Streaming conversation is a Phase 2 concern.

### Voice data lifecycle

- Raw audio is recorded and stored in app-private local storage for playback.
- Uploaded audio is processed by STT/scoring and deleted server-side after feedback is generated, within 24 hours maximum.
- Transcript and feedback are retained until the learner deletes the session or account. The backend stores no raw audio long-term in v1.
- Providers must offer no-training/zero-retention terms; record the chosen terms in the provider agreement before production.
- Microphone permission is requested at the first recording with a plain-language reason; a visible recording indicator is shown; no background recording.
- Account deletion removes profile, sessions, transcripts, and feedback within 30 days, except records required for legal or financial compliance.

### Offline and failure behavior

- Lessons, vocabulary, and review state are cached locally; completed results queue and sync when online.
- Speaking requires network. Offline or provider-down states disable the action with a clear message.
- Async jobs retry with idempotency keys; the UI exposes processing, retry, and permanent-failure states.
- Provider outage disables the affected entry point; the app never substitutes a fake model response.

### Security, cost, and abuse controls

- Secrets stay server-side; row-level security on user data; TLS everywhere; signed, short-lived storage URLs.
- Per-user rate limits, daily AI session caps, maximum recording length, and global budget alerts.
- Moderate user text before LLM use; treat user content as data inside prompts and never execute instructions from it.
- Entitlements are verified server-side in Phase 3; the client never decides paid access.

## Success measures and measurement

Proposed measures remain: change in fluency and vocabulary rubric levels over time; successful active vocabulary recall after spaced intervals; speaking-practice completion and repeat cadence; and learner retention. These are proposed measurement definitions, not agreed numeric targets.

Instrumentation:
- Fixed assessment: the same 2 speaking prompts and 20-item vocabulary check at baseline, week 4, and week 8, scored with the same rubric under the same conditions. Do not change prompts between baseline and follow-up.
- Speaking feedback uses rubric levels for fluency, vocabulary, and grammar with evidence and one next step. Pronunciation is added in Phase 2.
- Show rubric levels as practice estimates, not certified scores.
- Learning-gain targets are set only after baseline calibration; do not promise a specific gain before data exists.

Minimal analytics events: `onboarding_completed`, `placement_completed`, `lesson_started`, `lesson_completed`, `review_completed`, `speaking_started`, `speaking_completed`, `feedback_viewed`, `session_deleted`, `account_deleted`, plus Phase 3 `paywall_viewed`, `subscription_started`, and `ad_impression`. Include pseudonymous user ID, session ID, skill, duration, provider latency, and error code only.

## Non-functional requirements

- Feedback p95 under 20 seconds for a 60-second recording in Phase 1; longer recordings may show a job progress state.
- Handle audio-focus loss, calls, and app backgrounding during recording: save or discard cleanly with a visible state, never a silent corrupt upload.
- Accessibility: TalkBack labels, 48dp minimum touch targets, transcript available for every audio clip.
- English UI only in v1, but user-facing strings are externalized.
- Crash-free session target: 99.5% or better before Phase 2.

## Compliance and release checklist

- Account deletion available in-app and through a public web link.
- Play Data Safety declaration covers audio, transcripts, analytics, and deletion.
- Ad consent (EEA/UK) and target-age decision; apply the Families policy only if the product targets children.
- New personal Play developer accounts have a closed-testing gate before production; start console setup early.
- Play Billing server verification and RTDN configured before charging users.
- IELTS is used descriptively as “IELTS-style practice,” with no official logos or implied affiliation; legal review before store listing.
- Toungular name, domain, and trademark checked before branding investment.
- All curriculum, images, and audio are original or licensed for commercial use.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Speech scoring quality, latency, and cost | Core promise fails or unit economics break | Phase 0 spike; transcript-first feedback; per-user caps; no pronunciation scores until calibrated |
| Content authoring is the long pole | Empty or repetitive app | Seed Phase 1 content early; JSON schema + CI validation |
| Provider coupling and outages | Features disappear or users see errors | Thin adapters; clear unavailable/retry states; no fake output |
| Voice data privacy | Trust, store rejection, legal exposure | Local audio, transient upload, 24-hour deletion, zero-retention terms |
| Play policy and billing timeline | Monetization delayed | Start Play Console, Data Safety, and RTDN setup during Phase 1 |
| No test device currently | Mic/audio/notification bugs reach users | Phase 0 environment fix is a hard gate |
| Scope creep | Breadth without a working loop | Phase gates and explicit out-of-scope lists |

## Constraints and assumptions

- Launch platform and learning language: Android and English.
- Product scope: broad learner-facing parity, delivered in phases; exact Stimuler private services and unobserved behavior are not recoverable from the package.
- Current workspace contains the APK artifacts and investigation notes, but no Toungular source project or configured backend/provider accounts.
- Current machine: Flutter 3.47.5 stable installed at `C:\Users\sunny\flutter` but not on PATH; Android SDK 36 present with licenses pending; no emulator/system image; no connected Android device. Phase 0 must fix this.
- UI visual direction and detailed screen layouts are left to the builder under the Toungular brand, using familiar learning patterns without copying target assets or screen compositions.

## Open decisions

| Decision | Proposed default | Needed by |
|---|---|---|
| Backend | Supabase; Cloud Run + Postgres as alternative | Phase 0 |
| Sign-in methods | Google Sign-In + email OTP | Phase 0 |
| STT and LLM providers | Chosen from Phase 0 spike | Phase 0 exit |
| Pronunciation scoring provider | Evaluate in Phase 2 | Phase 2 start |
| Subscription tiers, prices, free limits | 3 AI sessions/week free; finalize in Phase 3 | Phase 3 start |
| Ad network, placements, frequency | Home and post-session history; finalize in Phase 3 | Phase 3 start |
| Target age and Families policy | Decide before ads/analytics production use | Phase 3 |
| Toungular name/domain/trademark | Clear before branding and store listing | Phase 1 |

## Approval gate

- [ ] Product scope and phase order approved.
- [ ] Phase 1 acceptance criteria approved.
- [ ] Proposed technical baseline approved, or an alternative named.
- [ ] Voice-retention defaults approved.
- [ ] Open decisions and owners accepted.

On approval, Phase 0 may start. Phase 1 implementation begins only after Phase 0 exit criteria are met.
