# StorageFix product roadmap

Agreed direction: compete on a clear, accurate and safe storage-review journey. Publish only after the release gates below pass. This roadmap supersedes the earlier “submission next” assumption. Work proceeds one milestone at a time, with an implementation, tests and reviewable evidence at each checkpoint. Initial release will be free. Build quality and validate real user interest before considering monetization. Do not add ads, a paywall, a timed trial or automatic charges to this initial release. A future paid tier, one-time upgrade or subscription requires a separate decision based on feedback and ongoing value; $4.99/month is an idea, not an approved price or billing implementation.

## Competitive target and boundaries

DaisyDisk's documented strengths include an interactive disk map, fast metadata scans, Quick Look, external/network-volume support and hard-link/APFS-clone accounting. Its vendor publishes speed claims; we have not independently benchmarked them. It also already promises local processing and no tracking, so privacy alone is not a unique advantage.

StorageFix now has treemap/ring/two-level sunburst exploration, exact-content duplicate comparison, a shared file review queue and exportable per-file operation outcomes. Its map now offers explicit hidden/package inspection, counts hard links once, includes empty files in the list, and distinguishes logical sizes from reported allocated metadata. Shared APFS blocks are not measured precisely. User-chosen folder access remains required in the Store build. External-volume/provider claims remain gated by real environment tests.

Our intended advantages are an integrated duplicate-to-cleanup journey, understandable scan coverage, a shared review queue, useful before/after reports and accessible navigation. These are hypotheses to validate, not claims that we already outperform DaisyDisk. The initial App Store product targets user-authorized folders and volumes. Administrator scans, snapshot deletion and remote cloud-provider integrations require separate feasibility/security/privacy work and are not initial release promises.

Source review: October 15, 2026. Compare equivalent folder scope, permissions, size definitions and cache state. Never compare our metadata-only scan with a competitor's content-comparison pass.

## 1. Trustworthy map foundation — completed October 15, 2026

Deliver:
- Account for every inventoried byte in the chart: top five items plus a labelled remainder.
- Give chart segments textual size/percentage labels and a screen-reader summary.
- Cache the displayed map projection when the inventory or navigation changes, rather than regrouping all files on each view evaluation.
- Inject the map's read-only scanning dependency; test success, failure, loading, cancellation, scope reset and navigation.

Completion gate: chart segment totals equal the ranked list total at root and nested folders for empty, small and >5-item fixtures; no off-scope paths contribute; all existing removal protections remain green. This establishes internal consistency only, not full disk or physical-storage accounting.

## 2. Scan engine and honest coverage — implemented; field validation pending

Deliver:
- Shared injected inventory engine and session-scoped access service with no global mutable scope store; scan sessions, bounded progress updates, cancellation and explicit coverage statistics.
- Distinguish scanned, inaccessible, excluded, changed/disappeared and cloud-placeholder entries; retain useful partial results with warnings.
- Separate “logical size”, “allocated bytes where available” and “unknown”; never label allocated totals as guaranteed recoverable space.
- Include package/hidden-file metadata through explicit review options without making those items automatically removable.
- Account for hard links once by stable identity and mark shared storage. Establish what macOS can report about full/partial APFS clones before making precision claims.
- Keep metadata scans from hydrating cloud placeholders or reading contents. Duplicate hashing must be a separate, explicit stage.
- Show disk capacity for the chosen scope's volume, including external volumes, with accurate unavailable/read-only states.

Completion gate: deterministic fixture totals and coverage reasons; disappearing/unreadable entries preserve useful results; symlink boundaries hold; cancelled sessions cannot replace newer results; placeholder fixtures cause no content reads. Run real APFS/external-volume cases before declaring support.

## 3. Fast visual exploration — implementation delivered; validation open

Deliver:
- An original interactive hierarchical map (prototype sunburst/treemap options, then choose through usability checks).
- Linked chart/list selection, hover details, breadcrumb navigation, search, sortable size columns and keyboard controls.
- Quick Look via an injected presentation coordinator, with a Finder fallback.
- Clear scan progress/partial/empty/error states and resumable review context within the current session.
- Design-system tokens, VoiceOver labels, useful focus order, Reduce Motion, readable light/dark themes and long-path handling.

Completion gate: five representative users can find a large nested file and return to the root without assistance; chart/list selection stays consistent; all actions are possible using keyboard and VoiceOver. Measure cached navigation latency against the performance gate below.

## 4. One safe review queue — implementation delivered; sandbox validation open

Deliver:
- Shared domain-level queue accessed through protocols by map, files and duplicates; no direct feature imports.
- Add/remove/preview queue entries and inspect full paths, size definitions and removal reasons.
- Deduplicate paths and ancestor/descendant selections; make kept-copy, read-only, package and protected-location policies explicit.
- Revalidate identity/size/timestamps/access before mutations; content-sensitive duplicate protection remains in the domain service.
- Report per-item Trash outcomes, partial failures and refresh requirements. Provide Finder restore guidance; claim one-click restore only if a reliable tested restore mechanism exists.

Completion gate: no operation can remove the last kept duplicate or an unreviewed/changed item; queue changes never silently add files; actual sandboxed Trash-and-restore tests pass on disposable files. No automatic emptying of Trash or permanent removal in the Store product.

## 5. Differentiation through comparison and reporting — snapshots, previews and outcome exports delivered; validation open

Deliver:
- Better duplicate review: useful previews, kept-copy choices and explicit selection suggestions that never authorize removal.
- User-controlled saved scan snapshots and rescan comparison for supported scopes; explain changed permissions and incomplete comparisons.
- Reports that separate inventoried, selected, moved-to-Trash and measured free-space change; avoid adding overlapping categories.
- Human-readable exports and structured CSV/JSON exports with privacy-aware preview of included paths.
- A simple guided journey: choose scope → understand results → inspect candidates → review queue → verify outcome.

Completion gate: users can explain why an item is a candidate and what changed after an action; snapshot/report fixtures reconcile exactly; cancellation/failure never produces a success/reclaimed-space claim. Update privacy declarations when persistence changes.

## 6. Performance and resilience — baseline and revisit optimization delivered; further work open

Record a baseline before optimizing. Benchmark the same fixed datasets on a documented reference Mac: 10k and 100k files, deep folders, large flat folders, duplicate-heavy content, external/read-only volumes and cancellation. Separate metadata enumeration from hashing. Report median and slowest of at least three runs, peak memory, time to first useful progress, total duration and cached navigation latency.

Provisional engineering targets, subject to the recorded baseline: visible progress within one second on local fixtures; cached navigation p95 below 100 ms; cooperative cancellation acknowledgement below one second when filesystem calls return normally; peak memory below 250 MB on the 100k-file metadata fixture. Do not promise a bounded response while an OS/network filesystem call is blocked. Avoid repeated hashing, bound concurrency, and keep large projections off the main actor where measured necessary.

Completion gate: targets pass or are explicitly revised with evidence; no main-thread stalls in representative interactions; permissions, disconnects and cancellation do not hang/crash or mutate unrelated data. A speed advantage over DaisyDisk can be claimed only after a legitimate equivalent-scope comparison using an available licensed/trial build.

## 7. Beta, competitive review and release decision

- At least ten target Mac users test the signed sandboxed product. At least eight complete the core choose/explore/review journey without help; record failures and fix recurring problems.
- No unresolved known data-loss, last-copy, permission-boundary or misleading-size defects. Automated safety regressions pass, plus real disposable-file sandbox tests.
- Test macOS 14 and current macOS; validate Intel runtime if we advertise Intel support. Verify keyboard, VoiceOver, long paths, light/dark appearance, report saving/cancellation and unavailable-volume recovery.
- Re-run the competitor task comparison and document where we lead, match or still lag. “Great competitor” means a validated core workflow and supported claims, not a feature-count assertion.
- Launch the initial product free after the quality/release gates pass. Assess interest through opt-in feedback, repeat use in beta and available App Store reporting; do not silently add tracking. Consider future optional paid features only after evidence of demand and a separate pricing decision. Implement StoreKit/restore tests only if that decision is made; no initial trial, subscription, ads or paywall.
- Finish Apple Developer membership, App ID/App Store Connect registration, distribution signing/profile, public support/privacy pages and owner-approved metadata/screenshots.
- Validate the signed upload with Apple's tools and TestFlight before approving a submission. No publishing until the owner approves the specific build and listing after these gates pass.

## Tracking

| Milestone | State | Evidence |
| --- | --- | --- |
| 1. Map foundation | Completed | `Design/Milestone1/Verification.md`; regression/Store checks and light/dark renders passed |
| 2. Scan engine/coverage | Implemented; environment checks pending | `Design/Milestone2/Verification.md`; local APFS/fixtures pass; physical external/cloud-provider tests pending |
| 3. Visual exploration | Implementation delivered; validation pending | `Design/Milestone3/Verification.md`; treemap/ring/sunburst, linked selection and preview routing; usability/VoiceOver/native sandbox preview pending |
| 4. Shared review queue | Implementation delivered; sandbox validation pending | `Design/Milestone4/Verification.md`; cross-feature policy, immutable confirmation, per-item outcomes; real disposable native Trash/restore passed |
| 5. Comparison/reports | Implemented slices; validation open | `Design/Milestone5/Verification.md`; snapshots/comparison, duplicate previews and hints, redacted text/JSON/CSV outcomes; free-space measurement and guided journey validation pending |
| 6. Performance/resilience | Baseline and revisit fix delivered; further work open | `Design/Milestone6/Verification.md`; repeat navigation meets local p95 target; first-visit stalls, memory, broader datasets and environment tests pending |
| 7. Beta/release decision | Planned | All previous gates and publisher setup required |

References:
- https://daisydiskapp.com/specs
- https://daisydiskapp.com/guide/hard-links
- https://daisydiskapp.com/guide/4/en/Editions/
- https://developer.apple.com/app-store/review/guidelines/
