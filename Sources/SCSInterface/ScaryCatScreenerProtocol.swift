import UIKit

public protocol ScaryCatScreenerProtocol {
    func screen(
        images: [UIImage],
        probabilityThreshold: Float,
        enableLogging: Bool
    ) async throws -> [UIImage]
}
