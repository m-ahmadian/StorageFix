# Milestone 1 — trustworthy map foundation

Completed October 15, 2026. Active plan: `PRODUCT-ROADMAP.md`.

The chart now represents the five largest direct items and one aggregate for every remaining inventoried item. Its sizes sum to the same total as the ranked list. The legend includes logical sizes, percentages and the remainder item count; the chart exposes a combined screen-reader description. Scope exclusions remain visible. These are logical inventory totals, not physical or recoverable disk-space totals.

Map presentation data is cached on inventory/navigation changes. Standalone map scanning uses an injected read-only protocol and worker service; the application composition root supplies it. File and map services share a read-only protocol boundary while retaining separate service instances. The map source follows View / ViewModel / Components layout.

Verification:
- Full Swift suite completed successfully: core 37, file-review 44 and cleanup 16 test functions. Three optional Finder Trash tests and the opt-in Store screenshot generator were skipped in the default run.
- APP_STORE configuration: 13 focused core and 43 feature tests passed. This is a compile/configuration check, not execution inside the app sandbox.
- Chart tests cover empty through twelve-item inventories, exact remainder accounting and a real item named “Other items”.
- View-model tests cover success, failure, loading, cancellation even when a dependency returns late, required folder consent, out-of-scope inventory, scope reset and navigation without additional scans.
- Read-only worker tests use disposable fixtures and cover success, unavailable folders and cancellation before enumeration.
- Both local universal app/DMG variants were rebuilt. The sandboxed package passed the Store verifier; these remain ad hoc signed local test builds.
- Native light/dark renders with nine root items and a remainder were inspected. They render at the minimum workspace content size. Actual VoiceOver operation and interactive click-through were not exercised in this milestone.

No personal files were removed. No App Store submission, ads or monetization changes were made. Large-volume performance, permission-partial results, allocated-size accounting, clone handling and interactive chart navigation are future roadmap work. We do not yet claim parity with or superiority over DaisyDisk.
