import UIKit

enum JarvisDesignSystem {
    enum Color {
        static let void = UIColor(red: 0.003, green: 0.006, blue: 0.009, alpha: 1)
        static let surface = UIColor(red: 0.020, green: 0.030, blue: 0.036, alpha: 1)
        static let glass = UIColor(red: 0.030, green: 0.045, blue: 0.052, alpha: 0.92)
        static let line = UIColor(red: 0.18, green: 0.28, blue: 0.32, alpha: 1)
        static let cyan = UIColor(red: 0.36, green: 0.92, blue: 1.0, alpha: 1)
        static let cyanSoft = UIColor(red: 0.18, green: 0.62, blue: 0.76, alpha: 1)
        static let inspection = UIColor(red: 0.70, green: 0.77, blue: 1.0, alpha: 1)
        static let speaking = UIColor(red: 0.40, green: 0.92, blue: 0.70, alpha: 1)
        static let attention = UIColor(red: 0.95, green: 0.68, blue: 0.30, alpha: 1)
    }

    enum Radius {
        static let commandBar: CGFloat = 20
        static let pill: CGFloat = 16
        static let panel: CGFloat = 12
    }

    enum Size {
        static let helpButton: CGFloat = 36
        static let meshWidth: CGFloat = 54
        static let meshHeight: CGFloat = 32
        static let commandBarHeight: CGFloat = 62
        static let sendWidth: CGFloat = 74
        static let sendHeight: CGFloat = 44
    }

    enum Spacing {
        static let edge: CGFloat = 18
        static let commandEdge: CGFloat = 16
        static let compactTitleTop: CGFloat = 10
        static let normalTitleTop: CGFloat = 20
    }

    enum Motion {
        static let quick: TimeInterval = 0.18
        static let settle: TimeInterval = 0.35
        static let scanSweep: TimeInterval = 1.4
        static let calmPulse: TimeInterval = 2.0
    }
}
