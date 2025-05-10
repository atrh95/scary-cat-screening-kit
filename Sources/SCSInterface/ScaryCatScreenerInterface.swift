import UIKit

public protocol ScaryCatScreenerInterface {
    func screen(
        images: [UIImage],
        probabilityThreshold: Float,
        enableLogging: Bool
    ) async throws -> [UIImage]
} 