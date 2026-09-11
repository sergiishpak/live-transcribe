import AppKit
import SwiftUI

struct TranscriptTextView: NSViewRepresentable {
    let text: String
    @Binding var followLive: Bool

    func makeCoordinator() -> Coordinator { Coordinator(followLive: $followLive) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.usesFindBar = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.delegate = context.coordinator

        let scrollView = LiveScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.didScrollAway = { context.coordinator.stopFollowing() }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        let selection = textView.selectedRange()
        textView.string = text
        if selection.location != NSNotFound { textView.setSelectedRange(selection) }
        if followLive && selection.length == 0 { textView.scrollToEndOfDocument(nil) }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private var followLive: Binding<Bool>

        init(followLive: Binding<Bool>) { self.followLive = followLive }

        func stopFollowing() { followLive.wrappedValue = false }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if textView.selectedRange().length > 0 { followLive.wrappedValue = false }
        }
    }
}

@MainActor
private final class LiveScrollView: NSScrollView {
    var didScrollAway: (() -> Void)?

    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        if clipView.bounds.maxY + 2 < (documentView?.bounds.maxY ?? 0) { didScrollAway?() }
    }
}
