# StorageFix App Store readiness — October 19, 2026

Status: publication is deferred while the product roadmap is implemented. Earlier release-preparation assets are drafts and must be refreshed after feature work; the app is not yet signed or validated for submission. No upload or public publication has been performed.

The canonical project path is `/Users/mehrdad/Desktop/Swift Code/AppStore/StorageFix`. The Developer path is a compatibility link to that real directory.

The active milestone sequence and competitive release gates are in `PRODUCT-ROADMAP.md`.

## Completed locally

Roadmap stages 2 and 3 now add shared metadata sessions/coverage, session-owned folder access, logical/allocated/unknown accounting, optional content comparison, and an interactive treemap/ring explorer with linked selection, breadcrumbs, filters and injected Quick Look. See `Design/Milestone2/Verification.md` and `Design/Milestone3/Verification.md` for current evidence and remaining validation. The shared review queue now provides cross-feature kept-copy protection, frozen confirmation, file-version revalidation and per-file native Trash outcomes. Queue reports export redacted text/JSON/CSV; saved scan comparisons remain future work. See milestones 4/5 verification notes. Earlier listing screenshots are stale drafts.

The dashboard, user journey, navigation, dated reports/text export, stable inventory counts, readable notices and expandable activity history improvements are implemented. Automated regressions and native light/dark renders cover the changed paths; this is not a claim that every workflow or environment is verified.

The Store build uses App Sandbox, user-selected file read/write and an app-scoped bookmark. Scan My Mac asks once for the Home folder (remembered; Forget Cache Access removes it), then reviews caches and Downloads. Cleanup is native Swift and allow-listed: caches are deleted after confirmation; old installers, deleted-app leftovers, Xcode Archives and AI models go to Trash. Other folder access is session-only. Application inventory is read-only; application removal and the shell cleanup script are excluded from this edition. No network service, privileged helper or background agent is included.

The privacy policy now covers exported reports. The manifest declares no collected data/tracking and the audited reasons for preferences, displayed disk capacity and selected-folder timestamps. Store-specific listing copy, reviewer notes, public-page drafts and four screenshot candidates are prepared in `Packaging/AppStore/`.

The rebuilt universal local app and DMG are in `dist/AppStore/`. Package checks verify the signature, approved entitlements, required bundle resources, privacy declarations, supported architectures and absence of shell scripts/subprocess APIs. Strict submission mode rejects ad hoc signing, absent/expired/mismatched profiles and missing or mismatched installer signing. Signing entitlements are derived from the supplied explicit App ID profile. These local checks do not replace Apple's upload validation.

## Remaining blockers

- Only an Apple Development signing identity was found with keychain access. Mac App Store distribution application/installer identities and an explicit App ID Store profile must be configured.
- The owner confirmed that StorageFix is not registered in App Store Connect yet. Developer team, unused version/build, name availability and ownership still need confirmation. Current source is version 3.1, build 13, bundle ID `com.mehrdad.storagefix`.
- The owner confirmed there is no public website yet. Public support/privacy pages and real support/review contact details still need to be supplied. Draft page content is prepared but has not been published.
- Owner approval is required for pricing/territories, age-rating, privacy/export-compliance and applicable account/trader declarations. Metadata null fields remain intentionally unfilled.
- The distribution-signed app still needs installation/runtime validation, including native report saving, folder denial/revocation, external volumes and disposable-file Trash/restore in the sandbox. Current screenshots are native interface renders with synthetic sample content, not captures of a TestFlight-installed build.
- macOS 14 and Intel runtime have not been tested here. Both architectures compile, but that alone does not establish runtime compatibility.

Use `Packaging/AppStore/Submission-Checklist.md` for the concrete handoff, commands and final approval sequence. Do not submit the local ad hoc DMG to App Store Connect.

Apple references checked October 15, 2026:
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile

October 17 continuation: Scan Comparison now explicitly saves/opens JSON metadata baselines, flags incomplete comparisons and never grants removal authority. Duplicate review has injected Quick Look and advisory newest-date hints. The sidebar scrolls at the minimum window height. The local 10k/100k baseline and bounded navigation cache are documented in `Design/Milestone6/Verification.md`; first-visit latency and memory remain open. Revalidate listing screenshots/privacy/support against the final signed candidate before submission.

October 17 (later): measured before/after free space in Review Queue outcomes and reports, a guided five-step journey, a duplicate head/tail pre-filter and additional opt-in benchmark fixtures. Continuous integration now builds and tests the direct and APP_STORE configurations on macOS 26 for every push. Store listing copy in `Packaging/AppStore/Metadata.en-US.json` was refreshed to the current feature set and no longer claims Intel support until the Intel runtime is tested. Screenshots remain stale and must be re-rendered. Publisher, signing, public page and runtime blockers above are unchanged.

October 17 (CI correction): the first CI workflow piped build and test output through `tee` without `pipefail`, so runs reported success while every Xcode 26 toolchain on GitHub's runners (Swift 6.2 to 6.3.3) crashed in IRGen. The crash also occurs on the October 17 main before this work. It was caused by passing isolated view-model methods directly as `Binding` setters and `fileExporter` callbacks; explicit closures fix it. CI now fails on errors and reports real counts: 212 direct and 213 APP_STORE tests pass, with opt-in fixtures skipped. Interface renders and Store screenshot candidates are produced on every push and published to the `ci-renders-direct` and `ci-renders-app-store` branches. Screenshot candidates in `Packaging/AppStore/Screenshots/` were refreshed from that run (synthetic sample content, not a TestFlight build).

UI/UX pass after a Gemini 4 Argon design consultation: capacity ring shows used space with amber/red pressure states, the clean-review notice folds into the journey card, a Review Queue pill stays visible while inspecting, map list bars use their chart colours, duplicate paths emphasise the folders that differ, Scan Comparison shows the folders that changed most, the folder picker suggests choosing Home, and a near-zero free-space change after Trash is explained. Rejected from that review: persistent folder bookmarks (conflicts with session-only access) and screenshot copy claiming "real disk space recovered".

October 17 (cache cleanup): at the owner's request one-click cache cleanup returns to the Store edition as a native Swift engine (`Sources/StorageFixCore/NativeCleanup`). It needs a one-time Home folder grant per session, measures only allow-listed rebuildable caches, skips Apple system caches and symbolic links, blocks categories while their owner app runs, and permanently deletes the selected contents after the review sheet (owner decision: delete, not Trash). Quick Review includes caches once access is granted, and a "Review & Clean" card opens the confirmation in one click. The direct edition keeps the existing script-based cleanup. App Review risk to watch: cleaners are allowed, but the listing must not overstate results; the app reports measured free space only. Still to validate on a signed sandbox build: which ~/Library/Caches subfolders macOS lets a sandboxed app delete after a Home grant.

October 19: Store listing, review notes, support draft, privacy draft and quick start refreshed for Scan My Mac, the remembered Home permission and the new Trash-only categories (installers, deleted-app leftovers). Build 13. Screenshots are still stale, and the signing, App Store Connect, public page and runtime blockers above are unchanged.
