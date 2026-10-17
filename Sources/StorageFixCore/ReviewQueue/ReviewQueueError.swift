import Foundation

public enum ReviewQueueError: Error, LocalizedError {
    case busy, reviewChanged, unreviewed, inspectionOnly, keptCopy, overlap, conflictingVersion, rescanRequired, capacity
    case protectedPath, sharedLink, unavailableMetadata, changed(String), inaccessible(String)
    public var errorDescription: String? {
        switch self {
        case .reviewChanged: "The queue changed after confirmation opened. Review the current entries and confirm again."
        case .busy: "Wait for the current queue operation to finish."
        case .unreviewed: "Scan this scope again before adding this file."
        case .inspectionOnly: "This scan is for inspection only. Use a fresh standard scan on a writable volume."
        case .keptCopy: "This file is a kept duplicate copy. Keep another verified copy or remove this item from the queue."
        case .overlap: "An ancestor or descendant path is already queued. Choose individual regular files."
        case .conflictingVersion: "A different version of this path is already queued. Remove it and scan again."
        case .rescanRequired: "Scan again, remove this entry, and add the reviewed file again before retrying."
        case .capacity: "The review queue limit has been reached. Finish or clear this queue before adding more files."
        case .protectedPath: "Hidden/package/application paths, folders named Library and protected system paths are excluded from the review queue."
        case .sharedLink: "Shared hard links are inspection-only. Manage them in Finder."
        case .unavailableMetadata: "File identity or modification time is unavailable. Scan again; otherwise inspect in Finder."
        case .changed(let path): "This file changed since review: \(path). Scan again before moving it."
        case .inaccessible(let path): "This file or its parent is unavailable or read-only: \(path). Check access, then scan again."
        }
    }
}
