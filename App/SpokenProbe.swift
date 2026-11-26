#if DEBUG
import SwiftUI
import UIKit

/// `-exposeSpokenMarks 1`: how many hearts, stars and sparkles VoiceOver could
/// land on right now, counted every quarter second into a line a test reads.
///
/// **XCUITest's own tree can't say this.** It lists elements marked hidden as
/// well, so a falling confetti piece is in it with or without
/// `accessibilityHidden` (`HiddenFromVoiceOver`). This walks the window
/// through UIKit's accessibility containers, the way VoiceOver does, skipping
/// whatever is hidden, so a piece is counted only if VoiceOver could reach it.
struct SpokenProbe: View {
    @State private var count = 0

    var body: some View {
        Text("marks=\(count)")
            .font(.caption2)
            .accessibilityIdentifier("DebugSpokenMarks")
            .task {
                while !Task.isCancelled {
                    count = Self.reachableMarks()
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
    }

    private static let marks: Set<String> = ["\u{2665}", "\u{2605}", "\u{2726}"]

    @MainActor
    static func reachableMarks() -> Int {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        var labels: [String] = []
        for window in windows { walk(window, into: &labels) }
        return labels.filter { marks.contains($0) }.count
    }

    @MainActor
    private static func walk(_ object: NSObject, into labels: inout [String]) {
        if object.accessibilityElementsHidden { return }
        if let view = object as? UIView, view.isHidden { return }
        if object.isAccessibilityElement {
            labels.append(object.accessibilityLabel ?? "")
            return
        }
        if let elements = object.accessibilityElements as? [NSObject], !elements.isEmpty {
            for element in elements { walk(element, into: &labels) }
            return
        }
        let count = object.accessibilityElementCount()
        if count != NSNotFound, count > 0 {
            for index in 0..<count {
                if let element = object.accessibilityElement(at: index) as? NSObject {
                    walk(element, into: &labels)
                }
            }
            return
        }
        if let view = object as? UIView {
            for subview in view.subviews { walk(subview, into: &labels) }
        }
    }
}
#endif
