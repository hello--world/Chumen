import AppKit
import STTextView
import SwiftUI

struct YAMLTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = STTextView.scrollableTextView()
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = scrollView.documentView as! STTextView
        textView.identifier = NSUserInterfaceItemIdentifier("ChumenYAMLCodeEditor")
        textView.textDelegate = context.coordinator
        textView.font = Coordinator.editorFont
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.typingAttributes = Coordinator.baseAttributes
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isHorizontallyResizable = true
        textView.showsLineNumbers = true
        textView.highlightSelectedLine = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.gutterView?.font = Coordinator.gutterFont
        textView.gutterView?.textColor = .secondaryLabelColor
        textView.gutterView?.drawSeparator = true

        context.coordinator.applyExternalText(text, to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? STTextView else { return }
        guard context.coordinator.shouldApplyExternalText(text, to: textView) else { return }
        context.coordinator.applyExternalText(text, to: textView)
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency STTextViewDelegate {
        static let editorFont = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        static let gutterFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize - 1, weight: .regular)

        @Binding private var text: String
        private var isApplyingExternalText = false
        private var isApplyingHighlight = false
        private var pendingTextSyncTask: Task<Void, Never>?
        private var pendingHighlightTask: Task<Void, Never>?
        private var lastAppliedExternalSignature: TextSignature?
        private var lastHighlightedSignature: TextSignature?
        private var skipNextPublishedTextViewUpdate = false

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChangeText(_ notification: Notification) {
            guard !isApplyingExternalText,
                  !isApplyingHighlight,
                  let textView = notification.object as? STTextView else {
                return
            }

            let length = textLength(in: textView)
            if length <= Self.immediateBindingSyncLimit {
                publishTextViewText(textView)
            } else {
                scheduleTextSync(from: textView)
            }
            scheduleHighlight(from: textView, immediate: length <= Self.immediateBindingSyncLimit)
        }

        func shouldApplyExternalText(_ text: String, to textView: STTextView) -> Bool {
            if skipNextPublishedTextViewUpdate {
                skipNextPublishedTextViewUpdate = false
                lastAppliedExternalSignature = TextSignature(text)
                return false
            }

            let signature = TextSignature(text)
            guard signature != lastAppliedExternalSignature else { return false }

            if signature.length <= Self.fullStringCompareLimit {
                return textView.text != text
            }

            return true
        }

        func applyExternalText(_ text: String, to textView: STTextView) {
            pendingTextSyncTask?.cancel()
            isApplyingExternalText = true
            textView.text = text
            lastAppliedExternalSignature = TextSignature(text)
            isApplyingExternalText = false
            scheduleHighlight(for: text, in: textView, immediate: text.utf16.count <= Self.immediateBindingSyncLimit)
        }

        deinit {
            pendingTextSyncTask?.cancel()
            pendingHighlightTask?.cancel()
        }

        static let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: editorFont,
            .foregroundColor: NSColor.labelColor
        ]
        private static let keyFont = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        private static let immediateBindingSyncLimit = 700_000
        private static let fullStringCompareLimit = 700_000
        private static let largeTextSyncDelay: UInt64 = 450_000_000
        private static let largeHighlightDelay: UInt64 = 550_000_000

        private func scheduleTextSync(from textView: STTextView) {
            pendingTextSyncTask?.cancel()
            pendingTextSyncTask = Task { @MainActor [weak textView, weak self] in
                try? await Task.sleep(nanoseconds: Self.largeTextSyncDelay)
                guard let self, let textView, !Task.isCancelled else { return }
                self.publishTextViewText(textView)
            }
        }

        private func publishTextViewText(_ textView: STTextView) {
            let current = textView.text ?? ""
            skipNextPublishedTextViewUpdate = true
            lastAppliedExternalSignature = TextSignature(current)
            text = current
        }

        private func scheduleHighlight(from textView: STTextView, immediate: Bool) {
            scheduleHighlight(for: textView.text ?? "", in: textView, immediate: immediate)
        }

        private func scheduleHighlight(for text: String, in textView: STTextView, immediate: Bool) {
            let signature = TextSignature(text)
            guard signature != lastHighlightedSignature else { return }

            pendingHighlightTask?.cancel()
            pendingHighlightTask = Task { @MainActor [weak textView, weak self] in
                if !immediate {
                    try? await Task.sleep(nanoseconds: Self.largeHighlightDelay)
                }
                guard let self, let textView, !Task.isCancelled else { return }
                let plan = await Task.detached(priority: .utility) {
                    YAMLSyntaxHighlighter.highlightPlan(for: text)
                }.value
                guard !Task.isCancelled else { return }
                self.applyHighlightPlan(plan, to: textView)
            }
        }

        private func applyHighlightPlan(_ plan: YAMLHighlightPlan, to textView: STTextView) {
            guard TextSignature(textView.text ?? "") == plan.signature else { return }
            guard let textStorage = (textView.textContentManager as? NSTextContentStorage)?.textStorage else { return }

            let fullRange = NSRange(location: 0, length: plan.length)
            let undoManager = textView.undoManager
            isApplyingHighlight = true
            undoManager?.disableUndoRegistration()
            defer {
                undoManager?.enableUndoRegistration()
                isApplyingHighlight = false
            }
            textStorage.beginEditing()
            textStorage.setAttributes(Self.baseAttributes, range: fullRange)
            for span in plan.spans {
                var attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: Self.color(for: span.role)
                ]
                if span.role.usesSemiboldFont {
                    attributes[.font] = Self.keyFont
                }
                textStorage.addAttributes(attributes, range: NSRange(location: span.location, length: span.length))
            }
            textStorage.endEditing()
            textView.typingAttributes = Self.baseAttributes
            lastHighlightedSignature = plan.signature
        }

        private static func color(for role: YAMLHighlightRole) -> NSColor {
            switch role {
            case .comment:
                return .tertiaryLabelColor
            case .key:
                return .systemBlue
            case .listMarker:
                return .secondaryLabelColor
            case .keyword:
                return .systemPurple
            case .string:
                return .systemGreen
            case .number:
                return .systemOrange
            case .boolean:
                return .systemPink
            case .url:
                return .systemTeal
            }
        }

        private func textLength(in textView: STTextView) -> Int {
            let contentManager = textView.textContentManager
            return NSRange(contentManager.documentRange, in: contentManager).length
        }
    }
}

private struct TextSignature: Equatable, Sendable {
    let length: Int
    let first: UInt16
    let last: UInt16

    init(_ text: String) {
        let utf16 = text.utf16
        self.length = utf16.count
        self.first = utf16.first ?? 0
        self.last = utf16.last ?? 0
    }
}

private enum YAMLHighlightRole: Sendable {
    case comment
    case key
    case listMarker
    case keyword
    case string
    case number
    case boolean
    case url

    var usesSemiboldFont: Bool {
        switch self {
        case .key, .keyword:
            return true
        case .comment, .listMarker, .string, .number, .boolean, .url:
            return false
        }
    }
}

private struct YAMLHighlightSpan: Sendable {
    let location: Int
    let length: Int
    let role: YAMLHighlightRole
}

private struct YAMLHighlightPlan: Sendable {
    let signature: TextSignature
    let length: Int
    let spans: [YAMLHighlightSpan]
}

private enum YAMLSyntaxHighlighter {
    static func highlightPlan(for text: String) -> YAMLHighlightPlan {
        let nsText = text as NSString
        var spans: [YAMLHighlightSpan] = []
        spans.reserveCapacity(min(nsText.length / 18, 80_000))

        nsText.enumerateSubstrings(
            in: NSRange(location: 0, length: nsText.length),
            options: [.byLines, .substringNotRequired]
        ) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange) as NSString
            highlightLine(line, lineStart: lineRange.location, spans: &spans)
        }

        return YAMLHighlightPlan(
            signature: TextSignature(text),
            length: nsText.length,
            spans: spans
        )
    }

    private static func highlightLine(_ line: NSString, lineStart: Int, spans: inout [YAMLHighlightSpan]) {
        let length = line.length
        guard length > 0 else { return }

        let commentLocation = line.range(of: "#").location
        let contentEnd = commentLocation == NSNotFound ? length : commentLocation
        if commentLocation != NSNotFound {
            appendSpan(lineStart + commentLocation, length - commentLocation, .comment, to: &spans)
        }

        var cursor = firstNonWhitespace(in: line, before: contentEnd)
        guard cursor < contentEnd else { return }

        if character(line, at: cursor) == 45 {
            appendSpan(lineStart + cursor, 1, .listMarker, to: &spans)
            cursor += 1
            while cursor < contentEnd, isWhitespace(character(line, at: cursor)) {
                cursor += 1
            }
        }

        if let colon = firstColon(in: line, from: cursor, before: contentEnd),
           isYAMLKey(line, range: NSRange(location: cursor, length: colon - cursor)) {
            appendSpan(lineStart + cursor, colon - cursor, .key, to: &spans)
            highlightScalarValue(in: line, lineStart: lineStart, from: colon + 1, before: contentEnd, spans: &spans)
            return
        }

        highlightCommaSeparatedListLine(in: line, lineStart: lineStart, from: cursor, before: contentEnd, spans: &spans)
    }

    private static func highlightScalarValue(
        in line: NSString,
        lineStart: Int,
        from valueStart: Int,
        before contentEnd: Int,
        spans: inout [YAMLHighlightSpan]
    ) {
        var start = valueStart
        while start < contentEnd, isWhitespace(character(line, at: start)) {
            start += 1
        }
        guard start < contentEnd else { return }

        let valueRange = NSRange(location: start, length: contentEnd - start)
        let value = line.substring(with: valueRange).trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }

        let role: YAMLHighlightRole
        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            role = .url
        } else if value == "true" || value == "false" || value == "yes" || value == "no" || value == "on" || value == "off" {
            role = .boolean
        } else if Double(value) != nil {
            role = .number
        } else if value.hasPrefix("\"") || value.hasPrefix("'") {
            role = .string
        } else {
            role = .string
        }
        appendSpan(lineStart + start, contentEnd - start, role, to: &spans)
    }

    private static func highlightCommaSeparatedListLine(
        in line: NSString,
        lineStart: Int,
        from start: Int,
        before contentEnd: Int,
        spans: inout [YAMLHighlightSpan]
    ) {
        guard start < contentEnd else { return }
        let contentRange = NSRange(location: start, length: contentEnd - start)
        let comma = line.range(of: ",", options: [], range: contentRange).location
        guard comma != NSNotFound, comma > start else { return }
        appendSpan(lineStart + start, comma - start, .keyword, to: &spans)
    }

    private static func firstNonWhitespace(in line: NSString, before end: Int) -> Int {
        var index = 0
        while index < end, isWhitespace(character(line, at: index)) {
            index += 1
        }
        return index
    }

    private static func firstColon(in line: NSString, from start: Int, before end: Int) -> Int? {
        var index = start
        while index < end {
            if character(line, at: index) == 58 {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func isYAMLKey(_ line: NSString, range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        let raw = line.substring(with: range).trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty, raw.count <= 80 else { return false }
        return raw.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" || scalar == "."
        }
    }

    private static func appendSpan(
        _ location: Int,
        _ length: Int,
        _ role: YAMLHighlightRole,
        to spans: inout [YAMLHighlightSpan]
    ) {
        guard length > 0 else { return }
        spans.append(YAMLHighlightSpan(location: location, length: length, role: role))
    }

    private static func character(_ line: NSString, at index: Int) -> unichar {
        line.character(at: index)
    }

    private static func isWhitespace(_ char: unichar) -> Bool {
        char == 32 || char == 9
    }
}
