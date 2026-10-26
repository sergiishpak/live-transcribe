import AppKit
import SwiftUI

struct TranscriptTextView: NSViewRepresentable {
    let sentences: [String]
    @Binding var followLive: Bool

    func makeCoordinator() -> Coordinator { Coordinator(followLive: $followLive) }

    func makeNSView(context: Context) -> NSScrollView {
        let documentView = TranscriptDocumentView()
        documentView.orientation = .vertical
        documentView.alignment = .leading
        documentView.spacing = 8
        documentView.edgeInsets = NSEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        documentView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = LiveScrollView()
        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.didScrollAway = { context.coordinator.stopFollowing() }
        documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor).isActive = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let documentView = scrollView.documentView as? TranscriptDocumentView else { return }
        updateRows(in: documentView, with: sentences, coordinator: context.coordinator)
        if followLive {
            DispatchQueue.main.async { (scrollView as? LiveScrollView)?.scrollToEnd() }
        }
    }

    private func updateRows(in documentView: NSStackView, with sentences: [String], coordinator: Coordinator) {
        let rows = documentView.arrangedSubviews.compactMap { $0 as? SentenceRow }
        let sharedCount = zip(rows, sentences).prefix { $0.0.sentence == $0.1 }.count

        for row in rows.dropFirst(sharedCount).reversed() {
            documentView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        for sentence in sentences.dropFirst(sharedCount) {
            let row = SentenceRow(sentence: sentence, coordinator: coordinator)
            documentView.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: documentView.widthAnchor).isActive = true
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        private var followLive: Binding<Bool>

        init(followLive: Binding<Bool>) { self.followLive = followLive }

        func stopFollowing() { followLive.wrappedValue = false }

        func controlTextDidBeginEditing(_ obj: Notification) { stopFollowing() }

        @objc func copySentence(_ sender: NSButton) {
            guard let sentence = (sender as? CopyButton)?.sentence else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(sentence, forType: .string)
        }
    }
}

@MainActor
private final class TranscriptDocumentView: NSStackView {
    override var isFlipped: Bool { true }
}

@MainActor
private final class SentenceRow: NSView {
    let sentence: String

    init(sentence: String, coordinator: TranscriptTextView.Coordinator) {
        self.sentence = sentence
        super.init(frame: .zero)
        userInterfaceLayoutDirection = .leftToRight

        let textField = NSTextField(wrappingLabelWithString: sentence)
        textField.isSelectable = true
        textField.delegate = coordinator
        textField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textField.alignment = .left
        textField.baseWritingDirection = .leftToRight
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.translatesAutoresizingMaskIntoConstraints = false

        let copyButton = CopyButton(sentence: sentence)
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy sentence")
        copyButton.target = coordinator
        copyButton.action = #selector(TranscriptTextView.Coordinator.copySentence(_:))
        copyButton.bezelStyle = .texturedRounded
        copyButton.toolTip = "Copy sentence"
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textField)
        addSubview(copyButton)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            textField.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -8),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            copyButton.topAnchor.constraint(equalTo: topAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 34),
        ])
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@MainActor
private final class CopyButton: NSButton {
    let sentence: String

    init(sentence: String) {
        self.sentence = sentence
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@MainActor
private final class LiveScrollView: NSScrollView {
    var didScrollAway: (() -> Void)?
    private var isProgrammaticScroll = false

    func scrollToEnd() {
        guard let documentView else { return }
        layoutSubtreeIfNeeded()
        documentView.layoutSubtreeIfNeeded()

        isProgrammaticScroll = true
        defer { isProgrammaticScroll = false }
        let y = max(0, documentView.bounds.height - contentView.bounds.height)
        contentView.scroll(to: NSPoint(x: 0, y: y))
        reflectScrolledClipView(contentView)
    }

    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        guard !isProgrammaticScroll, isUserScrollEvent else { return }
        if clipView.bounds.maxY + 2 < (documentView?.bounds.maxY ?? 0) { didScrollAway?() }
    }

    private var isUserScrollEvent: Bool {
        switch NSApp.currentEvent?.type {
        case .scrollWheel, .leftMouseDown, .leftMouseDragged:
            true
        default:
            false
        }
    }
}
