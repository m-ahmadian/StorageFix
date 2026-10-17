# Milestone 4 — shared safe review queue

Implementation delivered October 17, 2026. Native disposable-file checks pass. Distribution-signed sandbox, permission and volume tests remain required before closing the release gate.

## Implementation

A single app-owned `ReviewQueueProtocol` instance serves map, file review and duplicate comparison. The separate `ReviewQueueFeature` target owns its MVVM interface. Feature modules use Core protocols and do not import each other. The app composition root constructs the policy, actor-backed filesystem operations, queue, presenter and view models. Duplicate scope changes no longer construct a service inside the view model.

Adding to the queue never moves a file. Production file/duplicate review actions add explicit selections to this shared queue; only its separate confirmation executes them. Map folders are explored to choose individual files: the queue does not recursively expand directory selections. The queue counts an exact path once, combines its origins and rejects conflicting versions and ancestor/descendant selections. A bounded queue limit produces explicit rejections. Parent lookup uses an index rather than scanning all existing paths for every insertion.

Known duplicate kept-copy constraints apply across sources, including files queued before duplicate discovery. Later scope scans retain relevant constraints for existing entries. Kept-copy changes never silently change queued selections: a newly conflicting entry becomes blocked. Typed digest/member identities avoid delimiter collisions in filenames.

Hidden paths, packages, applications, any folder named Library, protected system locations (including case variants), shared hard links and missing identity/timestamp data are excluded. Cancelled, read-only and hidden/package inspection inventories cannot authorize queue additions. Live preflight also checks regular-file type, current access, package ancestors, symlinks, dataless state, size, identity, link count and modification time.

Confirmation captures a revision of the exact queue. Edits in another window invalidate it. The batch is immutable while executing; registration/add/remove/clear and repeated execution cannot change an active operation. All files and affected known duplicate sets are checked before the first mutation. Immediately before each native Trash call, the filesystem actor rechecks the candidate and affected kept-copy contents/versions without an intervening actor suspension. File hashing uses a no-follow descriptor and checks its version before and after reading.

The public native Trash API is not an atomic multi-file filesystem transaction. Per-file outcomes distinguish moved, failed, blocked and cancelled. A cancellation arriving after a successful native move is still reported as moved. Unmoved entries require fresh review; scan authorizations are discarded after a run. Known completed moves are removed from retained duplicate constraints so they do not create impossible retry requirements. Source inventories and old dashboard reports are invalidated after an operation. There is no permanent deletion, Trash-emptying action or promised one-click restore.

## Verification

- Full direct suite: 79 core, 77 feature and 16 cleanup test functions reported successfully. Six optional tests were skipped in the default run, including native Trash fixtures and listing screenshot generation.
- A separate enabled `QueueTrashIntegrationTests` run passed: a uniquely named disposable duplicate copy moved through the real queue into native Trash; the kept copy remained intact; the copy was restored programmatically and its contents matched. This is an unsandboxed test-runner check, not proof of Store sandbox operation or Finder UI Put Back.
- Policy tests cover cross-feature deduplication, frozen confirmation, changed versions, protected/hidden/package/shared entries, ancestor collisions in both orders, kept-copy changes and discovery, retained protections across scopes, preflight failure with zero mutations, partial outcomes, capacity, concurrent edits and cancellation.
- Native read-only validation fixtures cover identity/timestamp changes, replacement, symlinks, hard links and a changed kept copy. Only generated disposable fixture paths are used.
- View-model tests cover success/failure/loading, stale confirmations and cross-feature invalidation. Native light/dark renders cover the queue, blocked results and sunburst; preview buttons may be disabled in fixtures without a native presenter.

## Remaining release validation

Run the distribution-signed sandbox app with native folder grants, denial/revocation, real external/read-only/disconnected volumes, repeated previews, multi-window interactions, VoiceOver and representative users. Exercise long paths and large queues; measured performance is still milestone 6 work. Concurrent changes by other processes can race filesystem APIs; no global atomic-snapshot or rollback guarantee is claimed.

Store configuration check: the complete edition-aware suite reports 80 core, 77 feature and 16 cleanup functions successfully. Direct-only process tests are disabled in the Store configuration, which explicitly verifies that shell cleanup is unavailable and app removal is refused. Local universal direct/Store app bundles and DMGs were rebuilt; the Store package verifier passed. No upload or publication was performed.
