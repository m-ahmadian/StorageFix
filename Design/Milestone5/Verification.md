# Milestone 5 — snapshots, duplicate review and outcome reports

Implemented slices October 17, 2026. Native save/open, guided journey and field validation remain open.

## Scan Comparison

A separate MVVM feature receives live metadata from Storage Map or Quick Review through an app-owned Core protocol. Use Current Scan as Baseline captures a session-only baseline. Save Baseline explicitly exports JSON, and Open Baseline reads a previously saved document. No automatic scan database or bookmarks are written. Imported metadata cannot populate the live inventory or review queue and never grants filesystem access or removal authority.

The actor-backed service compares relative paths, logical sizes and modification times rounded to milliseconds. Changed contents with unchanged size/date are outside this metadata comparison; renames appear as newly/no longer observed paths. Observed totals reconcile, and the UI does not call missing entries deleted or logical changes recovered space. Folder paths and hidden/package settings must match. Warnings identify incomplete scans, cancellation, unavailable coverage, changed exclusion counts and differing volume names. The matching path cannot establish physical volume identity after a reconnect; this limit is always displayed.

Snapshot imports are limited to 64 MiB/100,000 entries, reject unsupported versions, negative/overflowing sizes, duplicate paths and malformed relative paths. Reading honors the selected document's security scope. Full paths and file metadata are disclosed before saving; no file contents, hashes or folder grants are included. A fresh scan invalidates stale comparisons and late background results; the chosen baseline survives until explicitly cleared or the app closes.

## Duplicate review

Kept copies and candidates have Quick Look through an injected coordinator. Modification dates help compare locations, and a unique newest-date hint suggests inspection without selecting files or changing the kept copy. Keep This remains explicit. Preview requests must refer to current reviewed group members. No suggestion adds to the queue or authorizes mutation. Native sandbox Quick Look still needs runtime validation.

## Outcome exports

Queue outcomes can be previewed and saved as text, JSON or CSV through a native save dialog. Reports identify the operation/date and separate selected logical bytes, moved logical bytes, and per-file moved/failed/blocked/cancelled outcomes. Free-space recovery is explicitly unmeasured. CSV supplies per-item logical sizes and statuses rather than repeated additive totals.

Full paths and identifying error messages are omitted by default. Turning on the explicit option includes them in the preview. Redacted exports replace both paths and original errors with generic item labels/status details. CSV quotes delimiters/newlines/quotes and protects spreadsheet formula prefixes. JSON is versioned. Large previews are shortened; saving retains the full report. Late report results are discarded after dismissal or operation changes.

## Verification and remaining work

Core tests cover round trips, totals, unchanged metadata, incomplete permissions/cancellation, scope/settings mismatches, malformed documents, duplicate/negative/overflowing entries and future versions. View-model tests cover success/failure/loading, new-scan races, clearing and live Map integration. Duplicate preview tests cover kept/candidate routing, unknown-path rejection and suggestions with no automatic selection. Export tests cover totals, redaction, CSV quoting/formula protection and formatter failures/dismissal races. The full direct suite reports 79 core, 77 feature and 16 cleanup functions successfully, with six optional tests skipped. Light/dark comparison and export renders were inspected; the privacy policy describes saved snapshots.

Still pending: signed sandbox save/open/cancel and Quick Look interaction, representative-user checks of the choose → explore → inspect → queue → verify journey, long-path/large-report interaction, and before/after measured free-space reporting. No recovered-space, cross-volume identity, content-comparison or deletion claim is inferred from snapshot differences. No ads/paywall or publication was introduced.
