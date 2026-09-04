import SwiftUI

enum Motion {
    static let numberTween: Animation = .easeOut(duration: 0.24)
    static let colorFade: Animation = .easeInOut(duration: 0.4)
    static let presetSwipe: Animation = .spring(response: 0.32, dampingFraction: 0.8)
    static let siblingSlide: Animation = .spring(response: 0.32, dampingFraction: 0.8)
    static let alertPulse: Animation = .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
    static let editTiltDegrees: Double = 0.5
}
