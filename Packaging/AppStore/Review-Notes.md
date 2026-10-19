# App Review notes — draft

StorageFix is a native macOS utility. No login, subscription, server, or reviewer account is needed. Requires macOS 14 or later.

## Folder access and review

1. Launch StorageFix. Quick Review shows Scan My Mac. Clicking it opens the native open panel already on the Home folder; click Allow. The app stores a security-scoped bookmark for Home so it does not ask again (app menu > Forget Cache Access removes it), then reviews caches first and the Downloads folder.
2. Open Cleanup to see every category, its folder, item list and warning. Caches are deleted permanently after a confirmation sheet; old installers, leftovers of deleted apps, Xcode Archives and AI models are moved to Trash. Please test with disposable data. Choose Folder… reviews any other folder for the session.
3. After completion, open View Report. Counts and logical sizes are separate inventories and may overlap. Export Report opens the native save dialog and saves a text snapshot.
4. Open Duplicates. If the chosen folder contains identical copies, compare their paths, choose a kept copy, select another copy and open the review sheet. Cancel exits without changing files. Confirming explicitly moves selected copies to Finder Trash.
5. Open Large & Old Files. The default minimum is 100 MB; select 10 MB+ to include smaller samples. A folder without files over the chosen threshold correctly shows no matches. Selections hidden by filters remain listed in the removal review.
6. Storage Map uses the file inventory. Explore folders and use Back or Root without rescanning.
7. Applications has a separate native folder choice. Select an Applications folder and scan. Inventory is read-only; no application-removal control is provided in this edition.
8. Safety Check is a personal checklist. Its shortcuts open System Settings; it does not scan for malware or automatically inspect/change settings.
9. Help > Privacy Policy opens the bundled policy. Clear History clears stored activity summaries. Only the Home permission is remembered; other folder access is session-only.

## Store boundaries

The app uses App Sandbox and user-selected file read/write only. No Full Disk Access, privileged helper, background agent, login item, external updater, shell cleanup script or network service is included. App uninstalling is excluded from this edition. Cache cleanup is implemented natively in Swift: the user chooses their Home folder in an open panel, the app measures only allow-listed rebuildable caches (for example Xcode DerivedData, package-manager caches, ~/Library/Logs and other apps' ~/Library/Caches folders, excluding com.apple.*), shows every folder and warning, and permanently deletes the selected cache contents only after confirmation. Categories are skipped while their owning app is running. File contents and hashes stay on-device. Exported reports are explicitly saved by the user and may contain folder paths and scan errors.

Trash actions are optional and require a review. Please use disposable files if testing removal. Scans are read-only. Logical file sizes can differ from physical disk space, and moving a file to Trash does not immediately free that space.

Before pasting these notes into App Store Connect, provide the actual review contact and approve the final signed build. No account credentials are required for app use.
