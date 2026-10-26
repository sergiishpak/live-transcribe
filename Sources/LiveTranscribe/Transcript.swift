import Foundation
import NaturalLanguage

struct Transcript: Equatable, Sendable {
    private(set) var committed: String
    private(set) var partial: String

    init(committed: String = "", partial: String = "") {
        self.committed = committed
        self.partial = partial
    }

    var displayText: String { committed + partial }

    var sentences: [String] {
        let text = displayText
        guard !text.isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
            .map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    mutating func showPartial(_ text: String) {
        partial = text.isEmpty ? "" : (committed.isEmpty ? text : " " + text)
    }

    mutating func showPartialTranscript(_ text: String) {
        guard !text.isEmpty else { partial = ""; return }
        guard !committed.isEmpty, text.hasPrefix(committed) else {
            partial = committed.isEmpty ? text : " " + text
            return
        }
        let suffix = text.dropFirst(committed.count).trimmingCharacters(in: .whitespaces)
        partial = suffix.isEmpty ? "" : " " + suffix
    }

    mutating func commit(_ text: String) {
        committed = text
        partial = ""
    }

    mutating func commitSession(_ text: String) {
        guard !text.isEmpty else { partial = ""; return }
        committed = [committed, text].filter { !$0.isEmpty }.joined(separator: " ")
        partial = ""
    }

    mutating func commitPartial() -> Bool {
        guard !partial.isEmpty else { return false }
        committed += partial
        partial = ""
        return true
    }

    mutating func clear() {
        committed = ""
        partial = ""
    }
}
