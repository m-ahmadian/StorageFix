import Foundation

public enum DistributionMode: Sendable {
    case direct, appStore
    public static var current: DistributionMode {
        #if APP_STORE
        .appStore
        #else
        .direct
        #endif
    }
}

