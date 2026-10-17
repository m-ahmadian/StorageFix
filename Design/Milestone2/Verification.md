# Milestone 2 — scan engine and honest coverage

Implementation delivered October 15, 2026. Local checks pass; external-volume and real cloud-provider validation remain open. The complete milestone gate has not been declared passed.

## Implementation

- One injected metadata engine serves the map and file browser. Duplicate comparison uses the same metadata scanner through a conservative array adapter, then runs its own explicit content-hashing stage. Quick Review leaves content comparison off until the user enables it.
- Scan results carry a session ID, options, files, coverage counters, bounded diagnostic samples, volume information and cancellation status. Progress reports observed entries/files at most once per 100 ms, plus start/final updates. It never invents a completion percentage.
- Per-entry access/disappearance/change errors retain useful results. Hidden entries, packages, symlinks, placeholders, unknown sizes/identities and additional hard links have explicit reasons. Counts describe observed entries, not descendants inside skipped folders.
- Logical bytes and reported allocated metadata are separate; unknown allocated values remain unknown. Hard links use device/inode identity and count once. Shared links cannot authorize file-browser Trash. Empty files remain listed.
- APFS `mayShareFileContent` is a hint, not unique physical-block accounting. Both a clone and its original remain logical files. We do not subtract purported clone savings or claim precise recoverable bytes for full/partial clones.
- Native metadata checks recognize iCloud download status and Darwin `SF_DATALESS`. A dataless check precedes detailed metadata fetching; enumeration prefetches only basic type flags. The metadata engine has no content-open/read/download API. Root packages also require explicit inspection consent.
- Folder access is an injected app-session object, with balanced stop calls when closed/deallocated. There is no static mutable scope registry or persistent bookmark. The app composition root creates services; feature view models receive protocols.
- Capacity follows the selected review scope's volume. Read-only/unknown volume states are explicit; read-only and cancelled inventories cannot authorize selection/removal. Inspection options never grant deletion authority for hidden/package contents.
- Legacy array-only sources explicitly report coverage as unavailable and filter off-scope entries. Destructive duplicate workflows fail closed when metadata reports read errors.

## Evidence

The full direct Swift suite passed: 50 core, 57 feature and 16 cleanup test functions reported. Three opt-in Finder Trash tests and the opt-in Store listing screenshot generator were skipped. The Store compilation/configuration run passed 24 focused core and 57 feature functions. This does not run those tests inside a distribution-signed sandbox.

New deterministic tests cover partial totals, every principal exclusion/error reason, allocation unknowns, cancellation retaining results, bounded diagnostic samples, session progress identity, monotonic/stale-update rejection, scope filtering, optional content comparison, read-only volumes and denied removal authorization.

Disposable local filesystem tests verify hard-link accounting, empty files, hidden files, symlink boundaries, root-package consent, volume metadata and a native `clonefile` pair with distinct identities. The clone test verifies logical representation and honest labels; it does not establish unique-block precision. Personal files were not removed.

Native light/dark coverage renders are in this directory. Final explorer layout renders are in `../Milestone3/`.

## Still required

- Real physical external/removable and network volumes, disconnects and permission revocation.
- Real iCloud and third-party File Provider placeholders, checking provider-specific behavior and absence of unwanted downloads.
- Partial APFS clones, sparse/compressed files and broader filesystems. Current UI explicitly avoids unique physical/recoverable-byte claims.
- Distribution-signed sandbox folder selection/access release, denied access and disposable Trash/restore.
- Timed cancellation/memory/progress baselines belong to milestone 6; deterministic correctness tests are not performance evidence.

API evidence: local Xcode 27 SDK `NSURL.h` (`NSURLMayShareFileContentKey`, `NSURLFileContentIdentifierKey`) and `sys/stat.h` (`SF_DATALESS`); [Apple URLResourceValues documentation](https://developer.apple.com/documentation/foundation/urlresourcevalues).
