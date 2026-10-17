import SwiftUI

public enum DesignSystem {
    public enum Colors {
        public static let background = adaptive(light: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.975, alpha: 1), dark: NSColor(calibratedRed: 0.085, green: 0.105, blue: 0.12, alpha: 1))
        public static let card = adaptive(light: .white, dark: NSColor(calibratedRed: 0.12, green: 0.145, blue: 0.16, alpha: 1))
        public static let groupHeader = Color.primary.opacity(0.04)
        public static let border = Color(nsColor: .separatorColor)
        public static let accent = Color(red: 0.10, green: 0.48, blue: 0.42)
        public static let sidebar = Color(red: 0.075, green: 0.12, blue: 0.14)
        public static let files = Color.blue
        public static let rose = Color.pink
        public static let storageMapRemainder = Color.secondary
        public static let storageMapPalette = [accent, lilac, amber, files, rose]
        public static func storageMapItem(at index: Int) -> Color {
            storageMapPalette.indices.contains(index) ? storageMapPalette[index] : storageMapRemainder
        }
        public static let lilac = Color(red: 0.47, green: 0.44, blue: 0.77)
        public static let amber = Color(red: 0.76, green: 0.43, blue: 0.19)
        private static func adaptive(light: NSColor, dark: NSColor) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light })
        }
        public static let accentSurface = accent.opacity(0.08)
        public static let accentBorder = accent.opacity(0.28)
        public static let primaryText = Color.primary
        public static let secondaryText = Color.secondary
        public static let warning = adaptive(
            light: NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.02, alpha: 1),
            dark: .systemOrange
        )
        public static let warningSurface = warning.opacity(0.08)
        public static let critical = adaptive(
            light: NSColor(calibratedRed: 0.72, green: 0.16, blue: 0.14, alpha: 1),
            dark: NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.38, alpha: 1)
        )
        public static let success = Color.green
    }

    public enum Brand {
        public static let symbol = "internaldrive"
        public static let sidebarSize: CGFloat = 38
        public static let sidebarRadius: CGFloat = 12
        public static let iconCanvas: CGFloat = 1024
        public static let iconTile: CGFloat = 824
        public static let iconSymbolSize: CGFloat = 520
        public static let iconRadius = iconTile * sidebarRadius / sidebarSize
        public static let foreground = Color.white
    }

    public enum Spacing {
        public static let none: CGFloat = 0
        public static let xSmall: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
        public static let xLarge: CGFloat = 32
    }

    public enum Radius {
        public static let chartSegment: CGFloat = 4
        public static let control: CGFloat = 8
        public static let card: CGFloat = 18
    }

    public enum Size {
        public static let reviewDiskWidth: CGFloat = 190
        public static let folderChangeLabel: CGFloat = 180
        public static let folderChangeValue: CGFloat = 96
        public static let reviewChart: CGFloat = 138
        public static let reviewProgressWidth: CGFloat = 280
        public static let coverageDetailsHeight: CGFloat = 160
        public static let mapSidebarMinWidth: CGFloat = 360
        public static let sunburstChart: CGFloat = 210
        public static let treemapWidth: CGFloat = 320
        public static let treemapHeight: CGFloat = 210
        public static let mapStylePickerWidth: CGFloat = 280
        public static let mapSelectionBorder: CGFloat = 2
        public static let previewWidth: CGFloat = 800
        public static let previewHeight: CGFloat = 600
        public static let storageMapChart: CGFloat = 170
        public static let storageMapProgressWidth: CGFloat = 300
        public static let legendMarker: CGFloat = 8
        public static let reportWidth: CGFloat = 640
        public static let reportHeight: CGFloat = 600
        public static let appIcon: CGFloat = 48
        public static let metricIcon: CGFloat = 28
        public static let rowIcon: CGFloat = 22
        public static let border: CGFloat = 1
        public static let actionButtonWidth: CGFloat = 150
        public static let minimumWindowWidth: CGFloat = 760
        public static let minimumWindowHeight: CGFloat = 640
    }

    public enum Chart {
        public static let fullTurn = 360.0
        public static let topOrigin = -90.0
        public static let sunburstHole = 0.28
        public static let sunburstMiddle = 0.64
        public static let sunburstOuter = 0.98
        public static let storageMapRingRatio = 0.70
        public static let ringRatio = 0.82
        public static let angularInset: CGFloat = 2
        public static let availableOpacity = 0.13
    }

    public enum Opacity {
        public static let mapOuter = 0.65
        public static let mapCell = 0.22
        public static let mapDimmed = 0.35
        public static let full = 1.0
        public static let pressed = 0.72
        public static let pillShadow = 0.18
    }
}
