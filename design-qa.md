# StorageFix 3.1 verification

Verified on October 6, 2026, on an Apple silicon Mac. Final result: automated behavior checks and the native journeys below passed. No claim of exhaustive coverage or App Store approval.

## Behavior fixes

A real cache scan could hang and cancellation left its subprocess running. Cleanup now uses an owned process group, drains output through temporary files, stops descendants on cancellation, and reports a recoverable scan timeout. Quick Review completes useful file, duplicate and application inventories before scanning caches. Standalone cache scans have Cancel; permanent cleanup has no mid-operation UI cancellation.

Duplicate and cache removal reviews show all selected paths and category warnings. Duplicate review includes selections hidden by filters and protects the kept copy. Multiline text wraps instead of clipping. Files that gain hard links after scanning are rejected. Cancelled scans no longer create misleading cleanup history. Clear History clears visible and persisted records.

The sandbox edition requires a native folder chooser before scanning; chosen-folder access lasts only for the session. It has no shell cleanup, global cache access or application removal. Its app inventory is explicitly read-only. First launch says Review Folder and explains the required choice. Sidebar captions are larger and brighter; decorative sidebar symbols no longer advertise incorrect selection state.

## Automated verification

75 Swift Testing tests in 12 suites passed, including native light/dark/minimum-size renders. Tests use back-ticked Given, when, then names. The requested testing skill was searched for but was unavailable; the existing Swift Testing framework was used directly.

Coverage includes SHA256 duplicate matching, kept-copy protection, selection across filters, changed-content and changed-bundle preflight, symlink and hard-link protections, running/system app removal guards, folder scope changes, Quick Review partial errors, map navigation and shared inventories, Store scope guards and read-only inventory, history persistence/clear, process cancellation/descendant termination and scan timeout.

STORAGEFIX_VERIFY_TRASH=1 additionally performed actual Finder Trash-and-restore operations on UUID-scoped disposable regular files, matching duplicate copies and a stopped fixture app bundle. The retained duplicate and separate documents survived. Permanent cache cleanup was exercised only in an isolated temporary home, never on personal caches.

The APP_STORE build was also compiled and its four StoreReadinessTests passed. The universal Store release compiles out shell subprocess operations and ships no cleanup script.

## Native click-through evidence

- Quick Review: real cache scan cancellation promptly restored navigation.
- Duplicates: native folder choice, one matching set, unselected initial state, Keep This clears selection, full-path review, Cancel.
- Files: threshold filtering, search, selections retained when hidden, full selected-path review, Cancel.
- Storage map: correct disposable-folder totals, drill down, Back, Root and disabled Back at root.
- Applications: chosen fixture folder, name/version/bundle/path/size inventory, search and empty results, bundle-only removal review, Cancel.
- Safety: checklist persistence, reset and actual Privacy & Security settings shortcut. No macOS permissions changed.
- App Store Updates: official Updates page opened.
- Help: bundled privacy policy opened and dismissed.
- Signed sandbox preview: first-launch review disabled until native folder choice; authorized file/duplicate review completed, map inventory shared. Separately chosen app folder scanned successfully with Show only and no removal action.
- Final packaged 3.1 direct app launched, matched the fixture duplicates and showed the full selected path and complete wrapped warnings in its new review sheet. The final sandbox package also launched with Review Folder disabled before a folder choice.

Live evidence is in Design/Live. Native destructive confirmation buttons were cancelled. Actual Trash behavior was verified separately by the disposable integration checks above. No personal files, caches or applications were removed.

## Visual comparison

CleanMyMac was researched using the provided App Store screenshot and MacPaw Smart Care, Space Lens and Large & Old Files guides. The paid application was not installed. Design/reference-comparison.png combines its reviewed Smart Care marketing preview and our reviewed fixture dashboard; it was opened for inspection. Different viewports and independent design mean exact geometry matching is not claimed.

Native renders in Design/Renders were inspected at full resolution for smaller controls and paths. Typography uses SF system fonts with a clear hierarchy. Spacing uses consistent rounded cards and a persistent sidebar; the minimum-size dashboard scrolls. Colors use charcoal, teal and adaptive neutral surfaces. Light and dark states were reviewed. Native SF Symbols and app icons replace the reference's purple gradients and 3D objects; no competitor artwork or branding was copied. Copy describes actual behavior: modified-date age, logical map sizes, bundle-only direct removal and a personal safety checklist. No malware detection or automatic optimization is claimed.

## Distribution checks and limits

Version 3.1 build 11, universal arm64/x86_64 release. DMGs contain the app, Applications shortcut, instructions and nested disposable Testing Samples. Ad hoc signatures pass strict all-architecture verification; packaged executable, guide, privacy manifest and policy are compared with build/source inputs. The Store package includes only app-sandbox and user-selected read/write entitlements.

Intel hardware was not available for runtime testing. Real user-cache cleanup, every third-party app layout, TCC-denied and revoked-folder scenarios, Store receipt/provisioning and TestFlight are not verified. Both DMGs are local test builds, ad hoc signed and not notarized. There are no configured distribution signing identities. Apple review, signed upload and public publishing metadata remain separate release work, deferred while the user focuses on behavior.

References: https://macpaw.com/support/cleanmymac/knowledgebase/smart-care ; https://macpaw.com/support/cleanmymac/knowledgebase/space-lens-results ; https://macpaw.com/support/cleanmymac/knowledgebase/large-and-old
