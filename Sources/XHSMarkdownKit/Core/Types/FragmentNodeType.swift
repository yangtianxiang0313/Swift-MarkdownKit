import Foundation

public struct FragmentNodeType: Hashable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
