import UIKit

public protocol ScaryCatScreenerProcotol {
    func screen(
        images: [UIImage],
        probabilityThreshold: Float,
        enableLogging: Bool
    ) async throws -> [UIImage]
} 
