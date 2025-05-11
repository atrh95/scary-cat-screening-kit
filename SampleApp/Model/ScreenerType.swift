import Foundation

enum ScreenerType: String, CaseIterable, Identifiable {
    case ovr = "One-vs-Rest"
    case multiClass = "Multi-Class"

    var id: String { rawValue }
}
