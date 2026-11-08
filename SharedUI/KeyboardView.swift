import UIKit

@MainActor
final class AccessibleKey: UIView {
    var activate: (() -> Void)?
    override func accessibilityActivate() -> Bool { activate?(); return true }
}

@MainActor
final class FeedbackButton: UIButton {
    var highlightChanged: (() -> Void)?
    override var isHighlighted: Bool {
        didSet { if oldValue != isHighlighted { highlightChanged?() } }
    }
}

/// Gestures the in-app preview checks off as someone tries them.
enum KeyboardGesture: String, CaseIterable, Sendable {
    case alternative, symbolSlide, spaceCursor, flick, glide
}

/// A single touch surface owns the complete grid, including the visual gutters.
@MainActor
final class KeyboardView: UIControl {
    var inputState = InputState() {
        didSet {
            if oldValue.page != inputState.page || oldValue.language != inputState.language { cancelTouches() }
            if oldValue.page != inputState.page || oldValue.language != inputState.language || oldValue.shift != inputState.shift { refresh() }
        }
    }
    var preferences = KeyboardPreferences() {
        didSet { if oldValue != preferences { cancelTouches(); setNeedsLayout() } }
    }
    var needsGlobe = true {
        didSet { if oldValue != needsGlobe { cancelTouches(); setNeedsLayout() } }
    }
    var returnTitle = "return" { didSet { if oldValue != returnTitle { refresh() } } }
    /// Exposed by the host's keyboard type: ".", "/." or "@." on the
    /// control row, immediately before the Go/Search/Return key.
    var contextualPunctuation: [String] = [] {
        didSet {
            if oldValue != contextualPunctuation { cancelTouches(); refresh() }
        }
    }
    var returnEnabled = true { didSet { if oldValue != returnEnabled { refresh() } } }
    var editingScratchpad = false { didSet { if oldValue != editingScratchpad { refresh() } } }
    /// Layout only: the portrait user preferences are never overwritten.
    var compactLandscape = false {
        didSet {
            guard oldValue != compactLandscape else { return }
            cancelTouches()
            invalidateIntrinsicContentSize()
            refresh()
        }
    }
    private var sizedPreferences: KeyboardPreferences {
        KeyScratchAdaptiveLayout.appearance(preferences, landscape: compactLandscape)
    }
    var layoutHeight: CGFloat { CGFloat(sizedPreferences.keyboardHeight) }
    var keyBackdropColor: UIColor { palette.background }
    /// Hosts turn this on only for languages and fields that can decode a trace.
    var glideEnabled = false { didSet { if !glideEnabled { for id in sessions.keys { sessions[id]?.trace = nil } } } }
    var onAction: ((KeyAction) -> Void)?
    var onCursor: ((Int) -> Void)?
    var onCursorVertical: ((Int) -> Void)?
    var onDismiss: (() -> Void)?
    /// Long-press the favorites star to cycle enabled languages.
    var onLanguageHold: (() -> Void)?
    var onGlide: (([CGPoint]) -> Void)?
    var onGesture: ((KeyboardGesture) -> Void)?
    let suggestionBar = SuggestionBar()
    let globeButton = FeedbackButton(type: .custom)
    private let dismissButton = FeedbackButton(type: .custom)
    private(set) var cells: [KeyCell] = []
    private var sessions: [ObjectIdentifier: TouchSession] = [:]
    // Hiding the opaque suggestion row here, not in layout: a hold changes no geometry,
    // so the popup would otherwise be drawn underneath the row.
    private var popup: (owner: ObjectIdentifier, values: [String], selected: Int)? {
        didSet { if (oldValue == nil) != (popup == nil) { updateChrome(); setNeedsLayout() } }
    }
    private var accessibleKeys: [AccessibleKey] = []
    private var layoutSize: CGSize = .zero
    private var releasedKeys: [KeyAction: TimeInterval] = [:]
    private var feedbackTimer: Timer?
    private var symbolSlide: (owner: ObjectIdentifier, page: KeyboardPage, began: TimeInterval, moved: Bool)?

    private var displayState: InputState {
        var state = inputState
        if let symbolSlide { state.page = symbolSlide.page }
        return state
    }

    private struct TouchSession {
        var cell: Int
        let original: KeyAction
        let start: CGPoint
        var began = ProcessInfo.processInfo.systemUptime
        var cursorSteps = 0
        var cursorRows = 0
        var cursorMode = false
        var focusHeld = false
        var timer: Timer?
        var startCell: Int
        var flick: String?
        /// Recorded while a glide is still possible; nil once it can't be one.
        var trace: [CGPoint]?
        var pathLength: CGFloat = 0
        var glide = false

        init(cell: Int, original: KeyAction, start: CGPoint) {
            self.cell = cell; self.original = original; self.start = start; startCell = cell
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isAccessibilityElement = false
        isOpaque = true
        backgroundColor = .systemGray5
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (view: KeyboardView, _: UITraitCollection) in
            view.setNeedsLayout()
            view.setNeedsDisplay()
        }
        accessibilityIdentifier = "keyboard-surface"
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.tintColor = palette.text
        globeButton.accessibilityLabel = "Next keyboard"
        globeButton.accessibilityIdentifier = "key-globe"
        globeButton.highlightChanged = { [weak self] in self?.nativeHighlightChanged(.globe) }
        addSubview(globeButton)
        dismissButton.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        dismissButton.tintColor = palette.secondary
        dismissButton.accessibilityLabel = "Dismiss keyboard"
        dismissButton.accessibilityIdentifier = "key-header-dismiss"
        dismissButton.highlightChanged = { [weak self] in self?.nativeHighlightChanged(.dismiss) }
        dismissButton.addAction(UIAction { [weak self] _ in self?.onDismiss?() }, for: .touchUpInside)
        addSubview(dismissButton)
        addSubview(suggestionBar)
        // Strip punctuation types like its key, so automatic spacing still applies.
        suggestionBar.onPunctuation = { [weak self] in self?.emit(.text($0), feedback: false) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: layoutHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Only physical geometry changes cancel a slide. Switching pages is part of it.
        if layoutSize != bounds.size { cancelTouches(); layoutSize = bounds.size }
        let sized = sizedPreferences
        cells = KeyboardGeometry.cells(width: bounds.width, state: displayState,
                                       preferences: sized, needsGlobe: needsGlobe,
                                       contextualPunctuation: contextualPunctuation)
        globeButton.isHidden = !needsGlobe
        globeButton.frame = cells.first(where: { $0.key.action == .globe })?.hitFrame ?? .zero
        suggestionBar.frame = CGRect(x: 0, y: sized.showHeader ? 38 : 0, width: bounds.width, height: sized.suggestionHeight)
        suggestionBar.style(palette)
        dismissButton.frame = CGRect(x: bounds.width - 44, y: 0, width: 44, height: 38)
        updateChrome()
        globeButton.tintColor = palette.text
        dismissButton.tintColor = palette.secondary
        backgroundColor = palette.background
        accessibilityValue = "\(preferences.theme.title), \(preferences.accent.title)"
        rebuildAccessibility()
        setNeedsDisplay()
    }

    private func refresh() {
        setNeedsLayout()
        setNeedsDisplay()
    }

    private func updateChrome() {
        suggestionBar.isHidden = !preferences.suggestionsEnabled || popup != nil
        dismissButton.isHidden = !sizedPreferences.showHeader || popup != nil
    }

    func cancelTouches() {
        for session in sessions.values { session.timer?.invalidate() }
        sessions.removeAll()
        symbolSlide = nil
        releasedKeys.removeAll()
        feedbackTimer?.invalidate()
        feedbackTimer = nil
        popup = nil
        setNeedsLayout()
        setNeedsDisplay()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { cancelTouches() }
    }

    private func title(_ action: KeyAction) -> String {
        switch action {
        case .text(let text): return displayState.shift == .off || displayState.page.isLayer ? text : text.shifted
        case .shift:
            guard displayState.page == .letters else { return KeyboardLayout.pageTitle(nextPage, preferences: preferences) }
            return displayState.shift == .locked ? "⇪" : "⇧"
        case .backspace: return "⌫"
        case .space: return "space"
        case .enter: return returnTitle
        case .language: return nextLanguage.badge
        case .favorites: return "★"
        case .page: return displayState.page == .letters ? "123" : "ABC"
        case .globe: return ""
        case .dismiss: return "⌄"
        case .layers: return KeyboardLayout.firstLayerPage(preferences).map { KeyboardLayout.pageTitle($0, preferences: preferences) } ?? ""
        case .command(let command): return command.symbol
        case .pair(let text, _): return text
        }
    }

    /// Where the #+= / 123 key leads from the current non-letter page.
    private var nextPage: KeyboardPage { KeyboardLayout.page(after: displayState.page, preferences: preferences) }

    private var nextLanguage: KeyboardLanguage { preferences.language(after: displayState.language) }

    private func accessibilityName(_ action: KeyAction) -> String {
        switch action {
        case .shift: return displayState.page == .letters ? "Shift" : KeyboardLayout.pageName(nextPage, preferences: preferences)
        case .backspace: return "Delete"
        case .space: return "Space"
        case .enter: return returnTitle.capitalized
        case .language: return "Switch to \(nextLanguage.title)"
        case .favorites: return "Favorite emoji and Unicode symbols. Hold for next language."
        case .page: return displayState.page == .letters ? "Numbers" : "Letters"
        case .dismiss: return "Dismiss keyboard"
        case .layers: return KeyboardLayout.firstLayerPage(preferences).map { KeyboardLayout.pageName($0, preferences: preferences) } ?? "Layers"
        case .command(let command): return command.title
        default: return title(action)
        }
    }

    private func rebuildAccessibility() {
        let accessibleCells = cells.filter { $0.key.action != .globe }
        if accessibleKeys.count != accessibleCells.count {
            accessibleKeys.forEach { $0.removeFromSuperview() }
            accessibleKeys = accessibleCells.map { _ in
                let element = AccessibleKey()
                element.isAccessibilityElement = true
                // Native views preserve screen coordinates across the keyboard's remote
                // view-service boundary. Touches still go to the single grid router.
                element.isUserInteractionEnabled = false
                addSubview(element)
                return element
            }
        }
        var elements: [Any] = accessibleCells.enumerated().map { index, cell in
            let element = accessibleKeys[index]
            element.frame = cell.hitFrame
            let name = cell.key.label ?? accessibilityName(cell.key.action)
            element.accessibilityLabel = name
            element.accessibilityIdentifier = "key-\(name)"
            element.accessibilityTraits = [.keyboardKey, .button]
            element.accessibilityValue = nil
            if cell.key.action == .enter && !returnEnabled { element.accessibilityTraits.insert(.notEnabled) }
            if cell.key.action == .shift && displayState.shift != .off {
                element.accessibilityValue = displayState.shift == .locked ? "Caps lock" : "On"
            }
            element.activate = { [weak self] in self?.emit(cell.key.action) }
            let flicks = FlickDirection.allCases.compactMap { cell.key.flicks[$0] }
            element.accessibilityCustomActions = (cell.key.alternatives + flicks).map { value in
                UIAccessibilityCustomAction(name: "Type \(title(.text(value)))") { [weak self] _ in
                    self?.emit(.text(value)); return true
                }
            }
            return element
        }
        if needsGlobe { elements.append(globeButton) }
        if sizedPreferences.showHeader { elements.append(dismissButton) }
        if preferences.suggestionsEnabled && popup == nil { elements.insert(suggestionBar, at: 0) }
        accessibilityElements = elements
    }

    private func emit(_ action: KeyAction, feedback: Bool = true) {
        guard action != .enter || returnEnabled else { return }
        onAction?(action)
        if feedback { flash(action) }
    }

    private func nativeHighlightChanged(_ action: KeyAction) {
        let button = action == .globe ? globeButton : dismissButton
        if !button.isHighlighted { flash(action) }
        setNeedsDisplay()
    }

    // A short color fade makes even quick taps visible, without moving key frames.
    // One timer services all releases; a new press always takes precedence over a fade.
    private func flash(_ action: KeyAction) {
        releasedKeys[action] = ProcessInfo.processInfo.systemUptime
        if feedbackTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let now = ProcessInfo.processInfo.systemUptime
                    self.releasedKeys = self.releasedKeys.filter { now - $0.value < 0.14 }
                    self.setNeedsDisplay()
                    if self.releasedKeys.isEmpty { self.feedbackTimer?.invalidate(); self.feedbackTimer = nil }
                }
            }
            feedbackTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        setNeedsDisplay()
    }

    private func feedbackOpacity(for action: KeyAction) -> CGFloat {
        guard let began = releasedKeys[action] else { return 0 }
        let elapsed = ProcessInfo.processInfo.systemUptime - began
        if UIAccessibility.isReduceMotionEnabled { return elapsed < 0.14 ? 1 : 0 }
        return max(0, 1 - elapsed / 0.14)
    }

    private var palette: KeyboardPalette {
        let increasedContrast = traitCollection.accessibilityContrast == .high
        let dark = traitCollection.userInterfaceStyle == .dark
        let keycaps = preferences.shownKeycaps
        var style: KeyboardPalette
        if let keycaps {
            style = KeyboardPalette(colors: .resolve(keycaps: keycaps, increasedContrast: increasedContrast),
                                    font: keycaps.font, shape: keycaps.shape)
        } else {
            style = KeyboardPalette(colors: .resolve(theme: preferences.theme, accent: preferences.accent,
                                                     systemDark: dark, increasedContrast: increasedContrast))
        }
        // Respect custom keycaps when the user explicitly chose them.
        style.iosAppearance = preferences.appleKeyAppearance && keycaps == nil
        style.darkAppearance = dark
        return style
    }

    /// Position accent choices next to the held key instead of requiring a
    /// long journey into the suggestion ribbon. Clamp inside the extension.
    private func heldAlternativesFrame(owner: ObjectIdentifier, count: Int) -> CGRect {
        let keyCenter: CGPoint
        let top: CGFloat
        if let index = sessions[owner]?.startCell, cells.indices.contains(index) {
            keyCenter = CGPoint(x: cells[index].visualFrame.midX, y: cells[index].visualFrame.midY)
            top = cells[index].visualFrame.minY
        } else {
            keyCenter = CGPoint(x: bounds.midX, y: 38)
            top = 38
        }
        let width = min(max(1, bounds.width - 8), CGFloat(count) * 38)
        let x = min(max(4, keyCenter.x - width / 2), max(4, bounds.width - width - 4))
        return CGRect(x: x, y: max(1, top - 37), width: width, height: 34)
    }

    override func draw(_ rect: CGRect) {
        let palette = palette
        palette.background.setFill()
        UIRectFill(bounds)
        var active = Set(sessions.values.map(\.cell))
        if globeButton.isHighlighted, let index = cells.firstIndex(where: { $0.key.action == .globe }) {
            active.insert(index)
        }
        for (index, cell) in cells.enumerated() {
            let action = cell.key.action
            let isText: Bool
            switch action {
            case .text, .pair, .space: isText = true
            default: isText = false
            }
            let selectedShift = action == .shift && displayState.page == .letters && inputState.shift != .off
            let pressed = active.contains(index) || selectedShift
            let frame = cell.visualFrame.insetBy(dx: 0.25, dy: 0.25)
            let radius = min(palette.iosAppearance ? 5 : 8, frame.width / 4)
            let accentKey = !palette.iosAppearance && action == .enter
                ? palette.colors.accentKey.map(UIColor.init(keyboardHex:)) : nil
            let primaryReturn = action == .enter && returnTitle != "return"
            // iOS gives contextual Go/Search/Send/Done keys blue faces
            // with white text, including when a custom keyboard is active.
            let fill = primaryReturn ? UIColor.systemBlue
                : (accentKey ?? (isText ? palette.key : palette.control))
            if palette.iosAppearance {
                let drop = UIBezierPath(roundedRect: frame.offsetBy(dx: 0, dy: 1.4),
                                        cornerRadius: radius)
                UIColor.black.withAlphaComponent(palette.darkAppearance ? 0.38 : 0.17).setFill()
                drop.fill()
            }
            var path = UIBezierPath(roundedRect: frame, cornerRadius: radius)
            var face = frame
            if palette.shape == .sculpted, frame.height > 12 {
                // A darker skirt under a slightly shorter top, like a keycap seen from above.
                fill.darkened(by: 0.22).setFill()
                path.fill()
                face.size.height -= 3
                path = UIBezierPath(roundedRect: face, cornerRadius: radius)
            }
            fill.setFill()
            path.fill()
            let highlight = pressed ? 1 : feedbackOpacity(for: action)
            palette.accent.withAlphaComponent(highlight * palette.highlightOpacity).setFill()
            path.fill()
            (pressed ? palette.accent : palette.border).setStroke()
            path.lineWidth = pressed ? max(1, palette.borderWidth) : palette.borderWidth
            path.stroke()

            let legend = accentKey != nil ? UIColor(keyboardHex: palette.colors.accentKeyText ?? palette.colors.text)
                : (isText ? palette.text : palette.controlText)
            let buttonInk: UIColor = primaryReturn ? .white : legend
            let color = action == .enter && !returnEnabled
                ? buttonInk.withAlphaComponent(0.48) : buttonInk
            if drawControl(action, in: face, color: color) { continue }
            let flicked = sessions.values.first { $0.startCell == index && $0.flick != nil }?.flick
            let label = flicked ?? cell.key.label ?? (action == .space && sessions.values.contains(where: \.cursorMode) ? "↔" : title(action))
            var size: CGFloat = label.count > 2 ? 13 : 19
            if case .text = action, cell.key.label == nil {
                size = min(sizedPreferences.letterSize, max(14, frame.width - 3))
            }
            drawText(label, in: face, font: palette.legend(ofSize: size, weight: isText ? .regular : .medium),
                     color: flicked == nil ? color : palette.accent)
            if preferences.showLongPressHints, case .text(let letter) = action,
               letter.first?.isLetter == true, let hint = cell.key.alternatives.first {
                let hintFrame = CGRect(x: frame.maxX - 13, y: frame.minY + 3, width: 10, height: 12)
                drawText(title(.text(hint)), in: hintFrame,
                         font: .systemFont(ofSize: 10, weight: .medium), color: palette.secondary)
            }
            if preferences.showLongPressHints, !cell.key.flicks.isEmpty {
                // An accent that doesn't stand out on the keycap, as in some colorways, gives way to the hint color.
                let flickColor = KeyboardColors.contrast(palette.colors.accent, palette.colors.key) >= 3 ? palette.accent : palette.secondary
                let font = UIFont.systemFont(ofSize: 10, weight: .semibold)
                // Down keeps the digit's top-left corner; the others sit on the edge they point to.
                for (direction, value) in cell.key.flicks {
                    let hint: CGRect
                    switch direction {
                    case .down: hint = CGRect(x: face.minX + 3, y: face.minY + 3, width: 12, height: 12)
                    case .up: hint = CGRect(x: face.midX - 8, y: face.minY + 2, width: 16, height: 12)
                    case .left: hint = CGRect(x: face.minX + 2, y: face.midY + 6, width: 12, height: 12)
                    case .right: hint = CGRect(x: face.maxX - 14, y: face.midY + 6, width: 12, height: 12)
                    }
                    drawText(value, in: hint, font: font, color: flickColor,
                             alignment: direction == .right ? .right : (direction == .up ? .center : .left))
                }
            }
        }
        for session in sessions.values where session.glide {
            guard let trace = session.trace, let first = trace.first else { continue }
            let trail = UIBezierPath()
            trail.move(to: first)
            trace.dropFirst().forEach(trail.addLine(to:))
            trail.lineWidth = 6
            trail.lineCapStyle = .round
            trail.lineJoinStyle = .round
            palette.accent.withAlphaComponent(0.55).setStroke()
            trail.stroke()
        }
        if let popup {
            let ribbon = heldAlternativesFrame(owner: popup.owner, count: popup.values.count)
            for (index, value) in popup.values.enumerated() {
                let frame = CGRect(x: ribbon.minX + CGFloat(index) * ribbon.width / CGFloat(popup.values.count),
                                   y: ribbon.minY, width: ribbon.width / CGFloat(popup.values.count),
                                   height: ribbon.height)
                let path = UIBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 0), cornerRadius: 8)
                palette.key.setFill(); path.fill()
                if index == popup.selected {
                    palette.accent.withAlphaComponent(palette.highlightOpacity).setFill(); path.fill()
                }
                (index == popup.selected ? palette.accent : palette.border).setStroke()
                path.lineWidth = max(1, palette.borderWidth); path.stroke()
                let pointSize = min(21, max(12, frame.width * 0.65))
                drawText(title(.text(value)), in: frame, font: palette.legend(ofSize: pointSize, weight: .regular), color: palette.text)
            }
        } else if sizedPreferences.showHeader {
            palette.accent.withAlphaComponent((dismissButton.isHighlighted ? 1 : feedbackOpacity(for: .dismiss)) * palette.highlightOpacity).setFill()
            UIBezierPath(roundedRect: dismissButton.frame.insetBy(dx: 2, dy: 2), cornerRadius: 8).fill()
            let text = sessions.values.contains(where: \.cursorMode) ? "Slide to move cursor" : "Key Scratch · \(inputState.language.badge)"
            drawText(text, in: CGRect(x: 10, y: 0, width: bounds.width - 64, height: 38),
                     font: .monospacedSystemFont(ofSize: 10, weight: .medium), color: palette.secondary, alignment: .left)
        }
    }

    private func drawControl(_ action: KeyAction, in frame: CGRect, color: UIColor) -> Bool {
        switch action {
        case .shift where displayState.page == .letters:
            let name = inputState.shift == .locked ? "capslock.fill" : (inputState.shift == .once ? "shift.fill" : "shift")
            drawSymbol(name, in: frame, size: 21, color: color)
        case .backspace:
            drawSymbol("delete.left", in: frame, size: 23, color: color)
        case .enter:
            // Default iOS key uses the word "return". In URL/search/email
            // fields iOS likewise uses a word-only Go/Search/Send action:
            // no arrow glyph above the text.
            let text = returnTitle
            let available = max(1, frame.width - 6)
            let size = min(15, max(9, available / max(3.5, CGFloat(text.count) * 0.62)))
            drawText(text, in: frame.insetBy(dx: 3, dy: 0),
                     font: palette.legend(ofSize: size, weight: .medium), color: color)
        case .language:
            drawSymbol("arrow.left.arrow.right", in: frame.offsetBy(dx: 0, dy: -8), size: 16, color: color)
            drawText(nextLanguage.badge,
                     in: CGRect(x: frame.minX, y: frame.midY + 5, width: frame.width, height: 13),
                     font: .systemFont(ofSize: 10, weight: .semibold), color: color)
        case .dismiss:
            drawSymbol("keyboard.chevron.compact.down", in: frame, size: 21, color: color)
        case .favorites:
            // Draw the contextual "Notes" or "App" label via normal key text.
            return false
        case .globe: break // Native button keeps Apple's tap-and-hold behavior.
        default: return false
        }
        return true
    }

    private func drawSymbol(_ name: String, in frame: CGRect, size: CGFloat, color: UIColor) {
        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        guard let image = UIImage(systemName: name, withConfiguration: configuration)?.withTintColor(color, renderingMode: .alwaysOriginal) else { return }
        let scale = min(1, (frame.width - 6) / image.size.width, (frame.height - 6) / image.size.height)
        let width = image.size.width * scale
        let height = image.size.height * scale
        image.draw(in: CGRect(x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height))
    }

    private func drawText(_ string: String, in frame: CGRect, font: UIFont, color: UIColor,
                          alignment: NSTextAlignment = .center) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let y = frame.midY - font.lineHeight / 2
        (string as NSString).draw(in: CGRect(x: frame.minX, y: y, width: frame.width, height: font.lineHeight + 2),
                                 withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        layoutIfNeeded()
        for touch in touches {
            let point = touch.location(in: self)
            guard let index = KeyboardGeometry.hit(at: point, cells: cells) else { continue }
            let id = ObjectIdentifier(touch)
            let key = cells[index].key
            // One finger owns the temporary page; other fingers must not change it.
            guard symbolSlide == nil else { continue }
            if key.action == .page && inputState.page == .letters {
                cancelTouches()
                symbolSlide = (id, .numbers, touch.timestamp, false)
                refresh()
                layoutIfNeeded()
                let pageIndex = cells.firstIndex { $0.key.action == .page } ?? -1
                sessions[id] = TouchSession(cell: pageIndex, original: .page, start: point)
                continue
            }
            // A second finger means fast typing, never a glide.
            for other in sessions.keys where !(sessions[other]?.glide ?? false) { sessions[other]?.trace = nil }
            var session = TouchSession(cell: index, original: key.action, start: point)
            if glideEnabled, sessions.isEmpty, case .text(let value) = key.action, value.first?.isLetter == true {
                session.trace = [point]
            }
            sessions[id] = session
            if key.action == .backspace { emit(.backspace) }
            if key.action == .backspace || key.action == .space
                || key.action == .favorites || !key.alternatives.isEmpty {
                let delay = key.action == .backspace ? DeleteRepeat.initialDelay
                    : (key.action == .space ? 0.32 : 0.42)
                let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated { self?.beginHold(id: id, key: key) }
                }
                sessions[id]?.timer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
        }
        setNeedsDisplay()
    }

    private func beginHold(id: ObjectIdentifier, key: Key) {
        guard sessions[id] != nil else { return }
        if key.action == .backspace {
            repeatDelete(id: id)
        } else if key.action == .space {
            sessions[id]?.cursorMode = true
            setNeedsDisplay()
        } else if key.action == .favorites {
            // A language hold never toggles editing focus on release.
            sessions[id]?.focusHeld = true
            onLanguageHold?()
            setNeedsDisplay()
        } else if popup == nil {
            sessions[id]?.trace = nil
            guard case .text(let original) = key.action else { return }
            // Releasing without moving still types the original letter.
            // Swipe left or right across the floating strip to pick an accent.
            popup = (id, [original] + key.alternatives, 0)
            setNeedsDisplay()
        }
    }

    private func repeatDelete(id: ObjectIdentifier) {
        guard let session = sessions[id], session.original == .backspace,
              cells.indices.contains(session.cell), cells[session.cell].key.action == .backspace else { return }
        emit(.backspace)
        // Emitting can synchronously dismiss or reconfigure the keyboard.
        guard sessions[id] != nil else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - session.began
        let timer = Timer(timeInterval: DeleteRepeat.interval(heldFor: elapsed), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.repeatDelete(id: id) }
        }
        sessions[id]?.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard var session = sessions[id] else { continue }
            let point = touch.location(in: self)
            if var slide = symbolSlide, slide.owner == id {
                if hypot(point.x - session.start.x, point.y - session.start.y) >= 10 { slide.moved = true }
                let index = KeyboardGeometry.hit(at: point, cells: cells)
                if index != session.cell {
                    session.timer?.invalidate()
                    session.timer = nil
                    // Require a deliberate pause: passing over #+= en route to a
                    // symbol must not unexpectedly change the page under the finger.
                    if let index, cells[index].key.action == .shift {
                        let timer = Timer(timeInterval: 0.42, repeats: false) { [weak self] _ in
                            MainActor.assumeIsolated { self?.switchSlidePage(id: id) }
                        }
                        session.timer = timer
                        RunLoop.main.add(timer, forMode: .common)
                    }
                }
                symbolSlide = slide
                session.cell = index ?? -1
                sessions[id] = session
                continue
            }
            if var current = popup, current.owner == id {
                let ribbon = heldAlternativesFrame(owner: id, count: current.values.count)
                // Horizontal dragging works even if the finger remains near the
                // held key, rather than reaching the top of the keyboard.
                if abs(point.x - session.start.x) > 10 || ribbon.contains(point) {
                    let unit = ribbon.width / CGFloat(current.values.count)
                    current.selected = min(current.values.count - 1,
                                           max(0, Int((point.x - ribbon.minX) / unit)))
                    popup = current
                }
                continue
            }
            if session.original == .space {
                let dx = point.x - session.start.x
                let dy = point.y - session.start.y
                if hypot(dx, dy) >= 12 { session.cursorMode = true }
                if session.cursorMode {
                    session.timer?.invalidate()
                    session.timer = nil
                    let horizontal = Int(dx / 12)
                    let vertical = Int(dy / 20)
                    let xSteps = horizontal - session.cursorSteps
                    let yRows = vertical - session.cursorRows
                    if xSteps != 0 { onCursor?(xSteps) }
                    if yRows != 0 { onCursorVertical?(yRows) }
                    session.cursorSteps = horizontal
                    session.cursorRows = vertical
                    sessions[id] = session
                    continue
                }
            }
            let index = KeyboardGeometry.hit(at: point, cells: cells)
            if var trace = session.trace, let last = trace.last {
                let step = hypot(point.x - last.x, point.y - last.y)
                if step >= 2 {
                    trace.append(point)
                    session.pathLength += step
                    session.trace = trace.count > 600 ? stride(from: 0, to: trace.count, by: 2).map { trace[$0] } : trace
                }
            }
            if !session.glide, cells.indices.contains(session.startCell), !cells[session.startCell].key.flicks.isEmpty {
                if let (_, value) = KeyboardGeometry.flick(on: cells[session.startCell], from: session.start, to: point) {
                    session.timer?.invalidate()
                    session.timer = nil
                    session.flick = value
                    session.cell = session.startCell
                    sessions[id] = session
                    continue
                }
                session.flick = nil
            }
            if session.trace != nil, !session.glide, index != session.startCell,
               cells.indices.contains(session.startCell),
               session.pathLength >= max(36, cells[session.startCell].hitFrame.width * 1.1) {
                session.glide = true
                session.timer?.invalidate()
                session.timer = nil
            }
            if index != session.cell {
                session.timer?.invalidate()
                session.timer = nil
                session.cell = index ?? -1
            }
            sessions[id] = session
        }
        setNeedsDisplay()
    }

    private func switchSlidePage(id: ObjectIdentifier) {
        guard var slide = symbolSlide, slide.owner == id,
              let session = sessions[id], cells.indices.contains(session.cell),
              cells[session.cell].key.action == .shift else { return }
        slide.page = slide.page == .numbers ? .symbols : .numbers
        symbolSlide = slide
        refresh()
        layoutIfNeeded()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let session = sessions.removeValue(forKey: id) else { continue }
            session.timer?.invalidate()
            if let slide = symbolSlide, slide.owner == id {
                let point = touch.location(in: self)
                let index = KeyboardGeometry.hit(at: point, cells: cells)
                let action = index.map { cells[$0].key.action }
                let isTap = !slide.moved && touch.timestamp - slide.began < 0.42
                    && hypot(point.x - session.start.x, point.y - session.start.y) < 10
                    && bounds.contains(point)
                symbolSlide = nil
                refresh()
                layoutIfNeeded()
                if isTap { emit(.page) }
                else if let action, case .text = action { emit(action, feedback: false); onGesture?(.symbolSlide) }
                // Holds, outside releases, and non-text targets restore letters silently.
            } else if let current = popup, current.owner == id {
                let isInside = bounds.contains(touch.location(in: self))
                popup = nil
                if isInside { emit(.text(current.values[current.selected])); onGesture?(.alternative) }
            } else if session.glide, var trace = session.trace {
                trace.append(touch.location(in: self))
                onGlide?(trace)
                onGesture?(.glide)
            } else if let digit = session.flick {
                emit(.text(digit), feedback: false)
                flash(session.original)
                onGesture?(.flick)
            } else if session.cursorMode {
                onGesture?(.spaceCursor)
            } else if session.focusHeld {
                // Long press already switched language.
            } else if session.original != .backspace,
                      let index = KeyboardGeometry.hit(at: touch.location(in: self), cells: cells) {
                emit(cells[index].key.action)
            }
        }
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            sessions.removeValue(forKey: id)?.timer?.invalidate()
            if symbolSlide?.owner == id { symbolSlide = nil; refresh() }
            if popup?.owner == id { popup = nil }
        }
        setNeedsDisplay()
    }
}

private extension UIColor {
    /// The same color with less light, for a keycap's skirt.
    func darkened(by amount: CGFloat) -> UIColor {
        var (hue, saturation, brightness, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        return UIColor(hue: hue, saturation: saturation, brightness: brightness * (1 - amount), alpha: alpha)
    }
}

/// One compact in-keyboard palette. The companion app owns searchable catalog
/// management; this surface concentrates on fast insertion and selection wrapping.
@MainActor
final class FavoriteSymbolsPanel: UIView {
    var onPick: ((String) -> Void)?
    var onWrap: ((SelectionWrapper) -> Void)?
    var onClose: (() -> Void)?

    private enum Page: Int { case favorites, symbols, wrapping }
    private static let categories: [(name: String, characters: [String])] = [
        ("Typography", "… · • ‣ ‧ ′ ″ ‹ › « » “ ” ‘ ’ ‽ ¿ ¡ § ¶ † ‡ № © ® ™ ° ⁂".split(separator: " ").map(String.init)),
        ("Arrows", "← → ↑ ↓ ↔ ↕ ↖ ↗ ↘ ↙ ⇐ ⇒ ⇔ ⇑ ⇓ ↩ ↪ ↳ ↶ ↷ ⟵ ⟶ ⟷ ➜ ➝ ➞ ➤ ⤴ ⤵".split(separator: " ").map(String.init)),
        ("Mathematics", "± × ÷ ≠ ≈ ≡ ≤ ≥ ∞ √ ∛ ∑ ∏ ∫ ∂ ∇ ∆ π τ φ θ λ Ω ∈ ∉ ∅ ∩ ∪ ∴ ∵ ∝ ∠ ⊕ ⊗".split(separator: " ").map(String.init)),
        ("Writing", "☐ ☑ ☒ ✓ ✔ ✗ ✘ ★ ☆ ◆ ◇ ◉ ○ ● □ ■ ▸ ▹ ▪ ▫ ♡ ♥ ⚑ ☞ ☜ ☛ ☟".split(separator: " ").map(String.init)),
        ("Currency", "$ € £ ¥ ¢ ₹ ₩ ₽ ₴ ₿ ₺ ₫ ₪ ₦ ₱ ฿ ₡ ₵ ₸".split(separator: " ").map(String.init)),
        ("Music", "♩ ♪ ♫ ♬ ♭ ♮ ♯ 𝄞 𝄢 ♠ ♣ ♥ ♦ ⚀ ⚁ ⚂ ⚃ ⚄ ⚅".split(separator: " ").map(String.init)),
        ("Science", "° ℃ ℉ µ Å Ω Ω ℏ 𝛼 𝛽 𝛾 𝛿 𝜀 𝜇 𝜋 𝜎 𝜔 ♂ ♀ ⚥ ⚛ ⚗ ⌘ ⌥ ⌫ ⏎".split(separator: " ").map(String.init)),
        ("Emoji", "😀 😂 😅 🙂 🙃 😉 😍 🤔 🤨 😎 🥹 🥰 🫡 😬 👍 👎 👏 🙌 🙏 🫶 ❤️ 🩷 💙 💚 ✨ 🔥 🎉 ☕ 📌 💡 📝".split(separator: " ").map(String.init))
    ]

    private let heading = UILabel()
    private let done = UIButton(type: .system)
    private let modes = UISegmentedControl(items: ["★", "Ω", "Wrap"])
    private let hint = UILabel()
    private let categoryButton = UIButton(type: .system)
    private let scroller = UIScrollView()
    private let grid = UIStackView()
    private var page = Page.favorites
    private var categoryIndex = 0
    private var favorites: [String] = []
    private var recent: [String] = []
    private var wrappers: [SelectionWrapper] = []
    private var displayedColumns = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.separator.cgColor
        accessibilityIdentifier = "key-scratch-quick-palette"

        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.textColor = .label
        heading.translatesAutoresizingMaskIntoConstraints = false
        addSubview(heading)

        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        done.accessibilityLabel = "Close the character palette"
        done.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)
        done.translatesAutoresizingMaskIntoConstraints = false
        addSubview(done)

        modes.selectedSegmentIndex = 0
        modes.accessibilityLabel = "Character palette"
        modes.addTarget(self, action: #selector(changePage), for: .valueChanged)
        modes.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modes)

        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabel
        hint.adjustsFontSizeToFitWidth = true
        hint.minimumScaleFactor = 0.8
        hint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hint)

        categoryButton.contentHorizontalAlignment = .left
        categoryButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        categoryButton.showsMenuAsPrimaryAction = true
        categoryButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(categoryButton)

        scroller.showsVerticalScrollIndicator = true
        scroller.alwaysBounceVertical = false
        scroller.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroller)
        grid.axis = .vertical
        grid.distribution = .fill
        grid.spacing = 4
        grid.translatesAutoresizingMaskIntoConstraints = false
        scroller.addSubview(grid)

        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            heading.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            heading.heightAnchor.constraint(equalToConstant: 25),
            done.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7),
            done.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            done.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            done.heightAnchor.constraint(equalToConstant: 27),
            modes.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 2),
            modes.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            modes.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7),
            modes.heightAnchor.constraint(equalToConstant: 30),
            hint.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            hint.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            hint.topAnchor.constraint(equalTo: modes.bottomAnchor, constant: 1),
            hint.heightAnchor.constraint(equalToConstant: 23),
            categoryButton.leadingAnchor.constraint(equalTo: hint.leadingAnchor),
            categoryButton.trailingAnchor.constraint(equalTo: hint.trailingAnchor),
            categoryButton.topAnchor.constraint(equalTo: hint.topAnchor),
            categoryButton.heightAnchor.constraint(equalTo: 23),
            scroller.topAnchor.constraint(equalTo: hint.bottomAnchor),
            scroller.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            scroller.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            scroller.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            grid.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
            grid.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
            grid.widthAnchor.constraint(equalTo: scroller.frameLayoutGuide.widthAnchor)
        ])
        updatePage()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(favorites: [String], recent: [String], wrappers: [SelectionWrapper]) {
        self.favorites = favorites
        self.recent = recent
        self.wrappers = wrappers
        page = .favorites
        modes.selectedSegmentIndex = page.rawValue
        categoryIndex = 0
        updatePage()
    }

    @objc private func changePage() {
        guard let new = Page(rawValue: modes.selectedSegmentIndex) else { return }
        page = new
        updatePage()
    }

    private func updatePage() {
        heading.text = page == .favorites ? "Your characters"
            : page == .symbols ? "Symbol library" : "Surround text"
        hint.text = page == .favorites ? "Recent first · favorites below"
            : page == .wrapping ? "Selection, or insert a pair at the cursor" : ""
        hint.isHidden = page == .symbols
        categoryButton.isHidden = page != .symbols
        if page == .symbols {
            categoryButton.setTitle(Self.categories[categoryIndex].name + "  ▾", for: .normal)
            categoryButton.accessibilityLabel = "Symbol category: " + Self.categories[categoryIndex].name
            categoryButton.menu = UIMenu(children: Self.categories.enumerated().map { index, category in
                UIAction(title: category.name, state: index == categoryIndex ? .on : .off) { [weak self] _ in
                    self?.categoryIndex = index
                    self?.updatePage()
                }
            })
        }
        displayedColumns = 0
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let columns = page == .wrapping ? (bounds.width >= 210 ? 2 : 1)
            : max(3, min(8, Int(max(0, bounds.width - 10) / 46)))
        guard columns != displayedColumns else { return }
        displayedColumns = columns
        rebuild(columns: columns)
    }

    private func rebuild(columns: Int) {
        for child in grid.arrangedSubviews {
            grid.removeArrangedSubview(child)
            child.removeFromSuperview()
        }
        switch page {
        case .favorites:
            let pinned = favorites.filter { !recent.contains($0) }
            if !recent.isEmpty { addSection("Recently used", symbols: recent, columns: columns) }
            if !pinned.isEmpty { addSection("Favorites", symbols: pinned, columns: columns) }
            if recent.isEmpty && pinned.isEmpty { addEmpty("Add characters in Key Scratch settings.") }
        case .symbols:
            addSection(nil, symbols: Self.categories[categoryIndex].characters, columns: columns)
        case .wrapping:
            addWrappers(columns: columns)
        }
        scroller.setContentOffset(.zero, animated: false)
    }

    private func addSection(_ name: String?, symbols: [String], columns: Int) {
        if let name { addHeading(name) }
        for offset in stride(from: 0, to: symbols.count, by: columns) {
            let row = makeRow()
            for column in 0..<columns {
                let index = offset + column
                if index < symbols.count {
                    let value = symbols[index]
                    let button = makeButton()
                    button.setTitle(value, for: .normal)
                    button.titleLabel?.font = .systemFont(ofSize: 22)
                    button.accessibilityLabel = "Insert " + value
                    button.addAction(UIAction { [weak self] _ in self?.onPick?(value) }, for: .touchUpInside)
                    row.addArrangedSubview(button)
                } else {
                    row.addArrangedSubview(UIView())
                }
            }
            row.heightAnchor.constraint(equalToConstant: 42).isActive = true
            grid.addArrangedSubview(row)
        }
    }

    private func addWrappers(columns: Int) {
        let options = SelectionWrapper.builtIn + wrappers.filter(\.isUsable)
        for offset in stride(from: 0, to: options.count, by: columns) {
            let row = makeRow()
            for column in 0..<columns {
                let index = offset + column
                if index < options.count {
                    let pair = options[index]
                    let button = makeButton()
                    var style = UIButton.Configuration.plain()
                    style.title = pair.opening + " text " + pair.closing
                    style.subtitle = pair.name
                    style.titleAlignment = .center
                    style.baseForegroundColor = .label
                    button.configuration = style
                    button.accessibilityLabel = "Surround selection with " + pair.name
                    button.addAction(UIAction { [weak self] _ in self?.onWrap?(pair) }, for: .touchUpInside)
                    row.addArrangedSubview(button)
                } else {
                    row.addArrangedSubview(UIView())
                }
            }
            row.heightAnchor.constraint(equalToConstant: 47).isActive = true
            grid.addArrangedSubview(row)
        }
    }

    private func makeRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.distribution = .fillEqually
        return row
    }

    private func makeButton() -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .tertiarySystemGroupedBackground
        button.layer.cornerRadius = 8
        button.tintColor = .label
        return button
    }

    private func addHeading(_ title: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        label.heightAnchor.constraint(equalToConstant: 19).isActive = true
        grid.addArrangedSubview(label)
    }

    private func addEmpty(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 2
        grid.addArrangedSubview(label)
    }
}
