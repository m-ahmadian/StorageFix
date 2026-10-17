# StorageFix contributor instructions

This is the private StorageFix source repository. The initial application release is free: do not add ads, paid tiers, trial timers, subscriptions or automatic billing without a new owner decision. Follow PRODUCT-ROADMAP.md and preserve honest release gates.

## Architecture and code

- Use Swift 6.2+, async/await and strict concurrency. View models are @MainActor.
- Every major feature is its own SwiftPM target and follows MVVM with View/, ViewModel/, Model/ and optional Components/ folders.
- Views contain rendering and local UI state; view models contain presentation logic; models are pure data. Business rules and filesystem work belong behind Core protocols.
- Inject dependencies through initializers. Never create services in view models. No singleton services, static mutable state, forced unwraps or direct networking in views/view models.
- Do not import one feature from another. Shared infrastructure belongs in Core, DesignSystem or Shared. Workspace and the app composition root coordinate features through injected dependencies.
- Use DesignSystem tokens/styles for colors, spacing, fonts, radii and buttons; extend the system when needed. Reuse shared components before adding new ones.
- Keep files under 300 lines and functions under 40 lines. Use access control, named constants, clear error mapping and one responsibility per type.
- Keep navigation in the view model/router. Use State for local UI state, StateObject for lifecycle ownership and ObservedObject for injected view models.
- Networking, if introduced, uses protocol-backed services and DTO-to-domain mapping.

## Safety and verification

- A scan, preview, suggestion, imported snapshot or queue addition never authorizes removal. Preserve explicit immutable review and live revalidation before Trash.
- Never infer recovered space from logical bytes or move-to-Trash results. Distinguish incomplete coverage and unknown metadata.
- Keep Store restrictions: chosen-folder access, no shell cleanup, no application removal or permanent file deletion.
- Test view-model success, failure and loading with mock dependencies. Add meaningful regression tests for changed behavior and run relevant tests in both direct and APP_STORE configurations.
- Never exercise destructive checks on personal data. Native Trash tests use opt-in uniquely named disposable fixtures only.
- Do not claim human usability, VoiceOver, signed-sandbox, external-volume, old-OS or Intel-runtime gates have passed without recorded evidence.

## Repository and release

- Canonical workspace: /Users/mehrdad/Desktop/Swift Code/AppStore/StorageFix. Do not move it as a workaround for stale IDE paths.
- Keep source private. Exclude build products, credentials, signing keys, profiles, local IDE state and personal datasets.
- Each commit contains one feature or improvement; avoid mixing refactors with features. Use feat(scope):, fix(scope): or refactor(scope): naming (docs/test/perf for their respective scoped changes).
- Do not upload or publish an app until the owner approves the exact build and listing after release gates pass.
