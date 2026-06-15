import CoreGraphics

public struct DisplayCandidate: Equatable, Sendable {
    public let localizedName: String
    public let width: CGFloat
    public let height: CGFloat

    public init(localizedName: String, width: CGFloat, height: CGFloat) {
        self.localizedName = localizedName
        self.width = width
        self.height = height
    }
}

public enum DisplayMatching {
    public static let xeneonResolutions: [(width: CGFloat, height: CGFloat)] = [
        (2560, 720),
        (1280, 800),
    ]

    public static func matchesXeneonResolution(width: CGFloat, height: CGFloat) -> Bool {
        xeneonResolutions.contains { $0.width == width && $0.height == height }
    }

    /// Higher scores win. Resolution-only matches are intentionally excluded.
    public static func matchScore(for candidate: DisplayCandidate) -> Int {
        let name = candidate.localizedName.lowercased()
        let matchesResolution = matchesXeneonResolution(
            width: candidate.width,
            height: candidate.height
        )

        if name.contains("xeneon edge") && matchesResolution { return 100 }
        if name.contains("xeneon") && matchesResolution { return 90 }
        if name.contains("xeneon") { return 80 }
        return 0
    }

    public static func bestMatch(
        among candidates: [DisplayCandidate],
        preferredName: String?
    ) -> DisplayCandidate? {
        if let preferredName,
           let preferred = candidates.first(where: { $0.localizedName == preferredName }) {
            return preferred
        }

        return candidates
            .map { ($0, matchScore(for: $0)) }
            .filter { $0.1 >= 80 }
            .max { $0.1 < $1.1 }?
            .0
    }
}