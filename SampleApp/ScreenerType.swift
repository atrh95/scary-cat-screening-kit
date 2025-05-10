import Foundation

enum ScreenerType: String, CaseIterable, Identifiable {
    case multiClass = "Multi-Class"
    case ovr = "One-vs-Rest"

    var id: String { rawValue }
}
