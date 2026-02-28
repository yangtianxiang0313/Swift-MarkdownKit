import Foundation

public protocol StreamableContent {
    func reveal(upTo length: Int)
}
