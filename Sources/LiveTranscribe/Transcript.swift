import Foundation

struct Transcript: Equatable, Sendable {
    private(set) var committed: String
    private(set) var partial: String

    init(committed: String = "", partial: String = "") {
        self.committed = committed
        self.partial = partial
    }

    var displayText: String { committed + partial }

    mutating func showPartial(_ text: String) {
        partial = text.isEmpty ? "" : (committed.isEmpty ? text : " " + text)
    }

    mutating func commit(_ text: String) {
        committed = text
        partial = ""
    }

    mutating func clear() {
        committed = ""
        partial = ""
    }
}
