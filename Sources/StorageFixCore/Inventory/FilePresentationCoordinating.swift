import Foundation

@MainActor public protocol FilePresentationCoordinating: AnyObject {
    func preview(_ url: URL)
    func reveal(_ url: URL)
}
