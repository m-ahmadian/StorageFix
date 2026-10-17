public enum MapSort: String, CaseIterable, Identifiable {
    case largest = "Largest first", smallest = "Smallest first", name = "Name"
    public var id: Self { self }
}

public enum MapStyle: String, CaseIterable, Identifiable {
    case ring = "Ring", treemap = "Treemap", sunburst = "Sunburst"
    public var id: Self { self }
}

public struct MapBreadcrumb: Identifiable, Equatable {
    public let path: String
    public let name: String
    public var id: String { path }
}
