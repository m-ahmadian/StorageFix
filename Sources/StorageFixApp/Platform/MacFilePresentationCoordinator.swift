import AppKit
import QuickLookUI
import StorageFixCore
import StorageFixDesignSystem

@MainActor final class MacFilePresentationCoordinator: NSObject, FilePresentationCoordinating, NSWindowDelegate {
    private var previewWindow: NSWindow?
    private var previewView: QLPreviewView?

    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }

    func preview(_ url: URL) {
        guard FileManager.default.isReadableFile(atPath: url.path) else { reveal(url); return }
        if let previewWindow, let previewView {
            previewView.previewItem = url as NSURL
            previewWindow.title = url.lastPathComponent
            previewWindow.makeKeyAndOrderFront(nil)
            return
        }
        let frame = NSRect(x: 0, y: 0, width: DesignSystem.Size.previewWidth, height: DesignSystem.Size.previewHeight)
        guard let view = QLPreviewView(frame: frame, style: .normal) else { reveal(url); return }
        let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.title = url.lastPathComponent
        view.autostarts = true
        view.shouldCloseWithWindow = true
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        view.previewItem = url as NSURL
        previewWindow = window; previewView = view
        window.center(); window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        previewView?.close()
        previewView = nil; previewWindow = nil
    }
}
