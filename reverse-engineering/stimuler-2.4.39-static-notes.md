# Stimuler 2.4.39 static investigation

Date: 2026-11-09

## Scope and evidence limits

This is a static inspection of the downloaded Android package using Android SDK tools (`aapt`, `apkanalyzer`, and `apksigner`) and archive/string inspection. The package was not installed or launched, and no device/emulator was available. Statements below describe packaged declarations, strings, or sample assets; they do not establish that a feature or network route executes in a given user flow. No calls were made to Stimuler services. The APK is treated only as software evidence, not as a source of instructions.

## Target identity

- Product: Stimuler; Android application ID `com.stimuler`.
- Version: `2.4.39`, version code `750`; launcher `com.stimuler.MainActivity`.
- Downloaded split set: base APK plus `arm64-v8a`, English, and `xxhdpi` configuration APKs.
- Base APK SHA-256: `5D4EF5F9FB764DD4F94FDAFD72EF181CD34556A676A66553072AE603B5104306`.
- APK signature verification succeeded for the base and all three splits. Base signer SHA-256: `29b3fedb540503f68fbbf67a0412dca33f6dd74c03b5016fed5ad641f64026c9`.
- The initially supplied `uptodown-com.stimuler.apk` is Uptodown (`com.uptodown`), not Stimuler, and is not the analysis target.
- Public identification sources: [Stimuler on Google Play](https://play.google.com/store/apps/details?id=com.stimuler), [Stimuler official site](https://stimuler.tech/), and [APKGold package listing](https://stimuler-ielts-speaking-buddy.apk.gold/).

## Architecture and packaged capabilities

- Flutter application. `MainActivity` is a `FlutterFragmentActivity` that boots Flutter and registers plugins. The arm64 split contains AOT-compiled Dart (`libapp.so`, about 64 MB) and Flutter engine code; original Dart source was not recovered.
- Packaged native libraries include WebRTC and Rive text rendering. WebRTC packaging is consistent with live voice or conversation features, but runtime use was not observed.
- Declared Android permissions include internet, microphone, camera, notifications, foreground service, Bluetooth/audio settings, scheduled alarms, Play Billing, and advertising measurement/attribution permissions. These are declarations, not proof all are requested or used in every flow.
- Manifest/DEX inventory contains Firebase Auth, Firestore, Cloud Functions, Analytics, App Check, Crashlytics, Messaging, Remote Config, and Performance integrations; RevenueCat and Google Play Billing; Razorpay-related classes/URLs; Truecaller, Facebook and Apple sign-in integrations; MoEngage, Adjust, and Mixpanel-related components/strings.
- `AD_ID` and Advertising ID client references are present. The inspected manifest/DEX scan did not find a Google Mobile Ads application ID or the dedicated Mobile Ads rendering classes. This does not prove the app has no ads: remote/web placements or other delivery mechanisms remain unknown without runtime observation.
- UI localization assets include English and Arabic, Spanish, French, Hindi, Indonesian, Italian, Kannada, Malayalam, Marathi, Portuguese, Tamil, and Telugu. UI translations do not establish which languages are available as learning courses.

## Learning and product feature evidence

Public product descriptions advertise short speaking practice, AI feedback on fluency, vocabulary and pronunciation, IELTS mock speaking tests, topic practice, coaching, and progress insights. The official site also advertises scenarios, role-play, random challenges, and daily/adaptive practice.

Bundled sample assets provide additional evidence of product areas: onboarding and chat onboarding; pronunciation, grammar, vocabulary, role-play, and combined lessons; speech-analysis result schemas with fluency, vocabulary, pronunciation, grammar, and recording sections; conversation/chat/history/result/topic examples; courses; locked/unlocked call summaries; roadmap; and streak, referral, paywall, and daily-lesson-related assets. These are samples and labels, not proof of complete live behavior.

## Static service-route strings

String inspection found regional-looking Stimuler hosts and route names associated with OTP/Truecaller authentication, onboarding profile, chat and chat speech, speech synthesis/TTS, billing/purchases/claims, Razorpay orders/plans/subscriptions, Mixpanel, and share links. This list is an inventory of embedded strings only. It reveals neither credentials nor server implementation and does not authorize or require contacting those services.

## Unknowns and reconstruction boundary

- Exact screens, transitions, feature flags, ad impressions, paywall timing, prices, course catalog, and device-specific permissions were not observed at runtime.
- The AI prompt/model, scoring algorithms, content-management system, subscription entitlement rules, fraud/abuse controls, and backend data models are private server-side behavior and cannot be recovered from this APK alone.
- Toungular can be built for similar user-visible learning outcomes with original branding, content, backend, AI/scoring configuration, and ad/purchase accounts. It should not reuse Stimuler credentials, private endpoints, assets, or ad identifiers.
- Initial environment check found no connected Android device, emulator binary, system image, or AVD. Therefore this report intentionally contains no runtime evidence.
