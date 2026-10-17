# Milestone 3 — visual exploration implementation

Initial delivery October 15; implementation extended October 17, 2026. Core interactions are implemented and tested. This milestone remains open until native preview/accessibility/usability/performance gates pass.

## Implemented

- A deterministic binary treemap prototype and a two-level sunburst prototype alongside the ring reference. Both use the same five largest items plus an aggregate remainder; areas/angles reflect whole-folder logical bytes. Navigation explores successive cached folder levels. Sunburst child arcs open their parent folder and select the corresponding cached child in the list. There is no usability-backed final design selection.
- One selection state links segments, legend and ranked list. Selecting a smaller list item highlights the aggregate containing it. “Other items” prompts selection from the list rather than pretending to identify one file.
- Breadcrumbs, cached back/root navigation, list search, largest/smallest/name sorting, arrow selection and Return/Space actions in the focused exploration controls. Command-Y routes Quick Look. Search explicitly filters the list while preserving whole-folder chart proportions.
- Injected native Quick Look/Finder coordinator. Platform windows and AppKit calls live at the app boundary, not in the view model. Unavailable preview construction/readability falls back to Finder. Existing “Show in Finder” actions use the same coordinator.
- Side-by-side map/list layout, collapsible bounded coverage details, full-path inspection, semantic fonts/design tokens and selection accessibility traits. No new motion requires a Reduce Motion alternative.

## Verification

The full direct Swift regression suite passed (50 core, 57 feature, 16 cleanup functions reported; four optional tests skipped). The Store configuration passed 24 focused core and 57 feature functions. Local universal direct and Store bundles/DMGs were rebuilt; the Store package verifier passed. These are ad hoc local packages, not App Store submission artifacts.

Tests cover normalized treemap areas/proportions, bounds, non-overlap, deterministic layouts for 0–12 items, zero-size file behavior, chart/remainder/list selection, invalid angles/paths, search/sort preserving chart totals, breadcrumb boundaries, navigation without rescanning, and injected preview/Finder routing.

Native minimum-size light/dark renders cover partial coverage, selected treemap/ring, dashboard and existing review flows. Hosting-view frame bounds are checked. These are rendered fixture interfaces, not evidence of an interactive signed-build session. Fixture preview buttons can be disabled because those render fixtures intentionally have no platform presenter.

## Required before closing the stage

1. Exercise the actual Quick Look window, repeated previews, close/reopen and Finder fallback in the signed sandbox, with permission denial/revocation and inaccessible files.
2. Operate every path using keyboard and VoiceOver; inspect long names, tiny areas and both appearances on actual displays.
3. Compare the implemented treemap and two-level sunburst prototypes before selecting a final design. Treemap is the current provisional default, not a validated superiority claim.
4. Run five representative users through finding a large nested file and returning to root. Record completion/errors and fix recurring problems.
5. Measure cached navigation and large-list responsiveness using the milestone 6 datasets. Do not infer latency from small unit tests.

The shared safe review queue is now implemented; see `../Milestone4/Verification.md`. Sunburst angle conservation, zero-byte behavior and cached child navigation have dedicated tests. Current full-suite evidence is recorded with milestone 4. No ads, paywall, upload or publication was added.
