# StorageFix 3.1

A native macOS workspace for reviewing storage before making changes.

Active development follows [PRODUCT-ROADMAP.md](PRODUCT-ROADMAP.md): staged product work and beta validation precede publication.
Requires macOS 14 or later.

- **Quick Review:** read-only folder/app/cache scans, with a separate optional duplicate-content comparison that is off by default. Disk capacity follows the chosen folder’s volume; recent activity is expandable.
- **Review report:** a dated snapshot of each scan’s scope, count, size and errors, with shortcuts to each area and native text export. Overlapping inventories are kept separate; reports do not claim a combined reclaimable total. Reports stay in memory until another review or folder choice; export to retain them.
- **Cleanup:** allow-listed caches, filters, sorting, reviewed selections, progress,
  explicit confirmation and per-category outcomes. Cleanup permanently removes files.
- **Duplicates:** complete content matching, explicit copy selection, preferred kept
  copy, Finder reveal, changed-file checks and reversible Trash removal.
- **Large & old files:** cancellable scanning, size/type/modified-date/path filters,
  largest-first results, explicit selection and reviewed Trash removal.
- **Storage map:** selectable treemap/ring/two-level sunburst and linked ranked list, cached drill-down, breadcrumbs, search/sort, keyboard selection and native Quick Look. Coverage details separate logical/allocated/unknown sizes, hard links, cloud placeholders and exclusions. Hidden/package inspection is optional and read-only.
- **Review Queue:** one explicit selection across map, files and duplicates, with kept-copy protection, immutable confirmation, file revalidation and per-item Trash outcomes. Text/JSON/CSV outcome exports default to omitting paths and identifying errors.
- **Applications:** installed app sizes, search, Finder reveal, App Store Updates
  shortcut and reviewed bundle-only Trash removal; running/system apps protected.
- **Safety checklist:** macOS settings shortcuts and a persistent personal checklist.
  It does not inspect security configuration or detect malware.

Native sidebar, quiet cards and a teal/charcoal palette support light and dark
appearance. The review-first journey is inspired by MacPaw's public Smart Care
and Space Lens guides; this is our own design, not a CleanMyMac clone.

## Run and test

Open `dist/StorageFix.dmg`, drag StorageFix to Applications, and launch it.
The universal build runs on Apple Silicon and Intel. The default local package is
ad hoc signed; Developer ID signing and notarization require your credentials.
See `Packaging/Quick-Start.txt` for a disposable-file test journey and permissions.

```sh
swift test --scratch-path .build-verified
Scripts/package-app.sh
```

The test suite uses Swift Testing with back-ticked Given/when/then function names.
It covers matching completeness, overlapping roots, changed originals, symlink
replacement, last-copy protection, hard links, model state, cache isolation,
partial failures, report pipe-buffer handling, and native light/dark renders.
No real personal files or caches are cleaned by the test suite. Set
`STORAGEFIX_VERIFY_TRASH=1` to exercise actual Finder Trash/restore on uniquely
named disposable fixtures created by the tests.

## Scan comparisons

After scanning in Storage Map or Quick Review, open Scan Comparison (Command-9).
Use Current Scan as Baseline, optionally save its JSON file, rescan the same folder,
then compare. Open Baseline loads a saved snapshot. Snapshots contain file names,
sizes, dates and coverage metadata; keep them private. They never grant access or
authorize removal. Comparison describes observed metadata changes, not proven
file deletions or recovered storage. Duplicate review also offers Quick Look and
an advisory newest-date hint; every selection and kept-copy choice stays explicit.

## Sandboxed Store edition

`Scripts/package-store.sh` compiles with `APP_STORE` and signs with App Sandbox
plus user-selected read/write only. Folder scans require a native folder choice.
Quick Review measures the chosen folder and optionally compares duplicate contents; applications are a read-only inventory
of a separately selected folder. Broad cache cleanup and app uninstalling are
excluded from the Store edition. No shell cleanup script ships in that bundle.
The default output in `dist/AppStore/` is a locally signed test DMG, not an
App Store upload. Signing/profile/metadata and Apple review remain separate.
See `AppStore-Readiness.md` and `Packaging/AppStore/Submission-Checklist.md` for current submission blockers, prepared metadata/screenshots, verification and signing steps.

## Script

```sh
Scripts/storage-fix.sh --scan
Scripts/storage-fix.sh --scan --format json
Scripts/storage-fix.sh --clean xcode-derived-data swiftpm-cache
```

Optional Other Application Caches excludes named cache categories, preventing
size double counting and removal of unselected named categories.
Cleanup rejects symbolic-link redirection in target ancestors.

## Distribution signing

```sh
SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
NOTARY_PROFILE="storagefix-notary" \
Scripts/package-app.sh
```

The script builds both architectures, verifies the signature, and creates a DMG
with an Applications shortcut and Read Me. With the signing variables it also
applies Developer ID signing, submits the DMG for notarization and staples it.
