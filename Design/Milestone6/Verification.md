# Milestone 6 — local performance baseline and navigation cache

Started October 17, 2026. This is a local engineering baseline, not completion of the performance/release gate or a competitor speed comparison.

Reference environment: MacBookPro18,3, Apple M1 Pro, 16 GiB RAM, eight reported processors; macOS 27.0.1 (26A434), release Swift test build. The Mac was running ordinary background applications and Spotlight. Caches were not flushed. These are warm/repeated fixture observations, not controlled cold-disk or production-app measurements. Fixture creation and deletion are excluded from scan timings.

The opt-in `LocalPerformanceBaselineTests` creates unique temporary 4-byte files, validates inventory count/logical totals, measures three metadata runs, then thirty navigation samples and one cooperative cancellation per dataset. It deletes only its generated fixture tree. The 10k fixture is flat; 100k uses 100 folders × 1000 files. Navigation samples return to root on the flat fixture, and enter/back on the nested fixture. No contents are hashed. The process peak includes the test host, SwiftUI/frameworks, fixture creation and both datasets; it cannot establish production app memory use or isolate each dataset's peak.

| Metric | 10k files | 100k files |
| --- | ---: | ---: |
| Metadata median / slowest, after change | 2.03 / 2.08 s | 21.88 / 22.30 s |
| First useful progress, slowest of three | 100.16 ms | 100.22 ms |
| Cancellation acknowledgement, one run | 0.67 ms | 0.56 ms |
| Navigation p95, before | 206.91 ms | 1842.59 ms |
| Navigation p95, after | 14.86 ms | 1.75 ms |
| Navigation slowest, after | 15.02 ms | 1791.03 ms |

The first uncached visit remains slow on the 100k fixture. Repeated navigation now meets the provisional p95 target on these fixtures; this is not a claim that every interaction meets it. The measured process peak increased from 275 MiB to 303 MiB, so the provisional 250 MB memory goal is not met/proven. Profiling and memory/first-visit work remain necessary.

A sampled stack identified repeated `StorageMap.items`/Foundation URL construction on the main actor during folder navigation. The fix adds a bounded 16-folder recency cache, clears it whenever inventory/scope changes, and uses path-string operations rather than constructing file URLs for every grouping/name. It does not reuse a previous scan as removal authority. A regression verifies revisits and invalidation when inventory/scope changes. Captured reports: `BeforeNavigationCache.json` and `LocalBaseline.json`.

To reproduce, run a release test with `STORAGEFIX_BENCHMARK=1`, `STORAGEFIX_BENCHMARK_OUTPUT` set to a chosen JSON path, and filter `LocalPerformanceBaselineTests`. Default test runs skip this fixture to avoid creating 110,000 files routinely.

Remaining: move first-visit projection work away from the main actor or pre-index safely, profile production-app allocations, measure per-dataset memory deltas, repeat under controlled conditions, deep/large-flat/duplicate-heavy fixtures, hashing benchmarks, physical external/read-only/disconnected volumes, blocked OS calls, and signed sandbox interactions. No bounded latency is promised while macOS blocks a filesystem call.

## Prepared hierarchy — October 17 follow-up

`IndexedBaseline.json` records the next identical fixture run. The metadata service now prepares an immutable immediate-child hierarchy on its detached worker before publishing a completed inventory. The map and sunburst use those prepared lists, so a first folder visit no longer regroups the full inventory on the main actor. The index is shared by value with the inventory, clears on scope/inventory changes, contains no filesystem authority and preserves chart/list totals. Cancelled scans keep their useful partial metadata; index preparation checks cancellation. Legacy array-only fixtures retain the bounded fallback cache.

| New service result | 10k files | 100k files |
| --- | ---: | ---: |
| First navigation sample | 7.67 ms | 0.92 ms |
| Navigation p95 | 8.89 ms | 0.91 ms |
| Navigation slowest | 8.92 ms | 0.92 ms |
| Scan plus index, median | 2.39 s | 28.09 s |
| Cancellation acknowledgement | 0.63 ms | 0.62 ms |

Peak resident memory for the entire test process was 216.63 MiB, down from 303 MiB. Both the first/repeated navigation samples and the process-memory target now pass on these local fixtures. The new service timing includes background index preparation; earlier `metadataMilliseconds` figures did not. These are still ordinary-background-activity measurements; no separate enumeration/index-duration or production-app allocation claim is made. Physical external/cloud volumes, deep/large-flat/duplicate-heavy cases, hashing, controlled repeats and distribution-signed runtime validation remain open. The earlier “first uncached visit remains slow” and memory failure describe the previous cache-only implementation.

## Duplicate pre-filter and additional fixtures — October 17

Same-size files over 32 KiB are first split by a 16 KiB head plus 16 KiB tail SHA-256. Different samples prove different contents, so only colliding files are fully hashed; groups are still keyed by the full-content digest and Trash revalidation is unchanged. Regression tests cover files that differ only in the middle, at the head or tail, and small files that skip sampling.

`ShapeBenchmarkTests` (opt-in, `STORAGEFIX_BENCHMARK=1`, output via `STORAGEFIX_SHAPES_OUTPUT`) adds a 60-level deep tree, a 50,000-file flat folder and a 200 × 10 duplicate-heavy set with three hashing runs. A manual `workflow_dispatch` CI job runs both benchmark suites on a GitHub macOS runner and prints JSON as annotations. No results are recorded yet; runner numbers will not substitute for the reference-Mac baseline.

## GitHub runner baselines — October 17

`RunnerBaseline-2026-10-17.json` and `RunnerShapes-2026-10-17.json` come from the opt-in CI job on a GitHub macOS runner (Apple M2 Pro virtual, 5 CPUs, 14 GiB, macOS 26.6.2, release build, warm caches, both suites in one test process). They are not the reference-Mac baseline.

| Fixture | Scan median | Navigation p95 | Other |
| --- | ---: | ---: | --- |
| 10k flat | 1.60 s (first run 6.32 s) | 7.5 ms | cancellation 1.1 ms, first progress ≤ 100.1 ms |
| 100k (100 × 1000) | 16.07 s | 0.9 ms | cancellation 1.1 ms |
| 60-level deep, 1,200 files | 0.26 s | 0.04 ms per level | — |
| 50k flat | 9.46 s | 35.8 ms (initial map build) | — |
| 200 × 10 duplicates, 256 KiB | 0.30 s | — | full duplicate pass median 0.88 s |

Navigation, first-progress and cancellation targets hold on the runner. Peak resident memory for the whole test process was 734 MiB with both suites (about 163,000 generated files) in one process, so the 250 MB target is **not** demonstrated here; the earlier 217 MiB figure covered only the 10k/100k suite on the reference Mac. Per-dataset memory profiling of the production app remains open.
