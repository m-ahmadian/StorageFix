import Foundation

/// Folders whose files must never be offered as duplicates or look-alike photos: app data in ~/Library, and
/// dependency or build folders that tools recreate and that break projects when individual files go missing.
public enum ReviewExclusions {
    static let folderNames: Set<String> = ["Library", "node_modules", ".build", "DerivedData", "Pods", "Carthage",
                                           ".venv", "venv", "site-packages", ".gradle", ".cargo", ".npm", ".git", ".Trash"]

    public static func excludes(_ path: String) -> Bool {
        path.split(separator: "/").dropLast().contains { folderNames.contains(String($0)) }
    }
}
