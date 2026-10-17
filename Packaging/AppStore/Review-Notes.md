# App Review notes — draft

StorageFix is a native macOS utility. No login, subscription, server, or reviewer account is needed. Requires macOS 14 or later.

## Folder access and review

1. Launch StorageFix and open Quick Review. Review Folder stays disabled until a folder is chosen.
2. Choose a folder containing benign sample files with the native Choose Folder button. Only the chosen folder is inventoried; Quick Review runs file and duplicate scans.
3. After completion, open View Report. Counts and logical sizes are separate inventories and may overlap. Export Report opens the native save dialog and saves a text snapshot.
4. Open Duplicates. If the chosen folder contains identical copies, compare their paths, choose a kept copy, select another copy and open the review sheet. Cancel exits without changing files. Confirming explicitly moves selected copies to Finder Trash.
5. Open Large & Old Files. The default minimum is 100 MB; select 10 MB+ to include smaller samples. A folder without files over the chosen threshold correctly shows no matches. Selections hidden by filters remain listed in the removal review.
6. Storage Map uses the file inventory. Explore folders and use Back or Root without rescanning.
7. Applications has a separate native folder choice. Select an Applications folder and scan. Inventory is read-only; no application-removal control is provided in this edition.
8. Safety Check is a personal checklist. Its shortcuts open System Settings; it does not scan for malware or automatically inspect/change settings.
9. Help > Privacy Policy opens the bundled policy. Clear History clears stored activity summaries. Folder access is session-only; relaunch requires choosing folders again.

## Store boundaries

The app uses App Sandbox and user-selected file read/write only. No Full Disk Access, privileged helper, background agent, login item, external updater, shell cleanup script or network service is included. Broad cache cleanup and app uninstalling are excluded from this edition. File contents and hashes stay on-device. Exported reports are explicitly saved by the user and may contain folder paths and scan errors.

Trash actions are optional and require a review. Please use disposable files if testing removal. Scans are read-only. Logical file sizes can differ from physical disk space, and moving a file to Trash does not immediately free that space.

Before pasting these notes into App Store Connect, provide the actual review contact and approve the final signed build. No account credentials are required for app use.
