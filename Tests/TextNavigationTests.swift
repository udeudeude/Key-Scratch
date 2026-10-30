import XCTest
@testable import OrtholinearCore

final class TextNavigationTests: XCTestCase {
    private func edit(_ command: KeyCommand, _ text: String) -> TextEdit? {
        let parts = text.components(separatedBy: "|")
        return TextNavigation.edit(for: command, before: parts[0], after: parts[1])
    }

    func testCursorStepsCrossWholeCharacters() {
        XCTAssertEqual(TextNavigation.offset(steps: -1, before: "ok👍🏽", after: ""), -4)
        XCTAssertEqual(TextNavigation.offset(steps: -2, before: "ok👍🏽", after: ""), -5)
        XCTAssertEqual(TextNavigation.offset(steps: 1, before: "", after: "e\u{301}x"), 2)
        XCTAssertEqual(TextNavigation.offset(steps: 2, before: "", after: "ab"), 2)
        XCTAssertEqual(TextNavigation.offset(steps: -3, before: "a", after: ""), -3)
        XCTAssertEqual(TextNavigation.offset(steps: 0, before: "abc", after: "def"), 0)
        XCTAssertEqual(TextNavigation.offset(steps: 3, before: "", after: "a"), 3)
        XCTAssertEqual(TextNavigation.offset(steps: -2, before: "", after: ""), -2)
        XCTAssertEqual(TextNavigation.offset(steps: 2, before: "", after: ""), 2)
    }

    func testMovesByCharacterWordAndLine() {
        XCTAssertEqual(edit(.left, "ab|c"), .move(-1))
        XCTAssertEqual(edit(.left, "a👍🏽|c"), .move(-4), "One emoji with a skin tone is four UTF-16 units")
        XCTAssertEqual(edit(.right, "ab|ґc"), .move(1))
        XCTAssertNil(edit(.left, "|abc"))
        XCTAssertNil(edit(.right, "abc|"))

        XCTAssertEqual(edit(.wordLeft, "hello world|"), .move(-5))
        XCTAssertEqual(edit(.wordLeft, "hello world  |"), .move(-7), "Spaces, then the word")
        XCTAssertEqual(edit(.wordLeft, "it’s fine, ok|"), .move(-2))
        XCTAssertEqual(edit(.wordLeft, "it’s|"), .move(-4), "Apostrophes stay inside words")
        XCTAssertEqual(edit(.wordLeft, "call(arg|"), .move(-3))
        XCTAssertEqual(edit(.wordLeft, "call(|"), .move(-1), "A run of punctuation is its own stop")
        XCTAssertEqual(edit(.wordRight, "|привіт світ"), .move(6))
        XCTAssertEqual(edit(.wordRight, "| світ"), .move(5))
        XCTAssertEqual(edit(.wordLeft, "line one\n|"), .move(-1), "A line break is one stop")
        XCTAssertEqual(edit(.wordLeft, "one\n  |"), .move(-2))

        XCTAssertEqual(edit(.lineStart, "first\nsecond line|end"), .move(-11))
        XCTAssertEqual(edit(.lineEnd, "x|yz\nmore"), .move(2))
        XCTAssertNil(edit(.lineStart, "first\n|"))
        XCTAssertNil(edit(.lineEnd, "x|\nmore"))
    }

    func testDeletesWholeWordsAndLines() {
        XCTAssertEqual(edit(.deleteWord, "hello world|"), .deleteBackward(5))
        XCTAssertEqual(edit(.deleteWord, "hello world |"), .deleteBackward(6))
        XCTAssertEqual(edit(.deleteWord, "привіт 👍🏽|"), .deleteBackward(1), "Counted in characters, as deleteBackward removes them")
        XCTAssertEqual(edit(.deleteToLineStart, "a\nbc d|"), .deleteBackward(4))
        XCTAssertNil(edit(.deleteWord, "|text"))
    }

    func testLayerKeysBecomeCommandsPairsOrText() {
        XCTAssertEqual(CustomKey("", command: .wordLeft).layerKey.action, .command(.wordLeft))
        XCTAssertNil(CustomKey("", command: .wordLeft).layerKey.label, "Drawn as its symbol, announced by name")
        XCTAssertEqual(CustomKey("()", cursorBack: 1).layerKey.action, .pair("()", cursorBack: 1))
        XCTAssertEqual(CustomKey("π", alternatives: ["Π"]).layerKey.action, .text("π"))

        let fine = CustomLayer(name: "Nav", rows: [[CustomKey("", command: .left)], [CustomKey("<b></b>", cursorBack: 4)], [CustomKey("x")]])
        XCTAssertEqual(fine.problems, [], "A command key needs no text")
        let wrong = CustomLayer(name: "Nav", rows: [[CustomKey("")], [CustomKey("()", cursorBack: 3)], [CustomKey("x")]])
        XCTAssertEqual(wrong.problems, [.emptyKey, .cursorOutside("()")])

        let decoded = try? JSONDecoder().decode(CustomKey.self, from: Data(#"{"output":"","command":"teleport","cursorBack":-2}"#.utf8))
        XCTAssertNil(decoded?.command, "Unknown commands are dropped, not fatal")
        XCTAssertEqual(decoded?.cursorBack, 0)
    }
    func testSpaceTrackpadMovesAcrossHardLineBreaks() {
        XCTAssertEqual(TextNavigation.verticalOffset(rows: -1, before: "hello\nabc", after: ""), -6)
        XCTAssertEqual(TextNavigation.verticalOffset(rows: 1, before: "hello\nabc", after: "\n123456"), 4)
        XCTAssertNil(TextNavigation.verticalOffset(rows: -1, before: "only one line", after: ""))
        XCTAssertNil(TextNavigation.verticalOffset(rows: 1, before: "only one", after: " line"))
        XCTAssertEqual(TextNavigation.verticalOffset(rows: 1, before: "a\nlast", after: "\nx"), 2,
                       "The next shorter line clamps the column")
    }

    func testIPhonePlacementDoesNotMoveDeleteOrReturnOnPageChanges() {
        var preferences = KeyboardPreferences()
        preferences.iphoneKeyPositions = true
        var input = InputState()
        input.language = .english
        for page in [KeyboardPage.letters, .numbers, .symbols] {
            input.page = page
            let rows = KeyboardLayout.rows(state: input, needsGlobe: true, preferences: preferences)
            XCTAssertEqual(rows[2].first?.action, .shift)
            XCTAssertEqual(rows[2].last?.action, .backspace)
            XCTAssertEqual(rows[3].last?.action, .enter)
            XCTAssertEqual(rows[3].first?.action, .page)
        }
    }

    func testEnglishIPhoneRowsHaveNativeQwertyPositions() {
        var preferences = KeyboardPreferences()
        preferences.iphoneKeyPositions = true
        preferences.showApostrophe = true // The iPhone layout overrides extra letter-row keys.
        let rows = KeyboardLayout.letterKeys(.english, preferences: preferences)
        XCTAssertEqual(rows.map(\.count), [10, 9, 7])
        XCTAssertEqual(rows[1].first?.action, .text("a"))
        XCTAssertEqual(rows[2].last?.action, .text("m"))
        XCTAssertTrue(rows[1].allSatisfy { $0.action != .text("'") })
        let geometry = KeyboardGeometry.cells(width: 320, state: {
            var input = InputState(); input.language = .english; return input
        }(), preferences: preferences, needsGlobe: true)
        let a = geometry.first { $0.key.action == .text("a") }
        let q = geometry.first { $0.key.action == .text("q") }
        XCTAssertGreaterThan(a?.hitFrame.minX ?? 0, q?.hitFrame.minX ?? 0,
                             "The second row is inset by half a key")
    }

    func testEnglishAccentOptionsAreAvailableByHoldingLetters() {
        let preferences = KeyboardPreferences()
        let rows = KeyboardLayout.letterKeys(.english, preferences: preferences)
        let a = rows.flatMap { $0 }.first { $0.action == .text("a") }
        let e = rows.flatMap { $0 }.first { $0.action == .text("e") }
        XCTAssertTrue(a?.alternatives.contains("æ") == true)
        XCTAssertTrue(a?.alternatives.contains("á") == true)
        XCTAssertTrue(e?.alternatives.contains("é") == true)
    }
    func testFocusToggleReplacesLanguageKeyInSplitModes() {
        let p = KeyboardPreferences()
        XCTAssertEqual(p.defaultLanguage, .english)
        XCTAssertEqual(p.languages, [.english])
        for mode in [KeyScratchMode.split, .legacy, .quiet, .narrow] {
            var options = p
            options.keyScratchMode = mode
            let rows = KeyboardLayout.rows(state: InputState(), needsGlobe: true, preferences: options)
            XCTAssertEqual(rows[3].filter { $0.action == .noteFocus }.count, 1)
            XCTAssertFalse(rows[3].contains { $0.action == .language })
            XCTAssertEqual(rows[3].last?.action, .enter)
        }
        var reference = p
        reference.keyScratchMode = .reference
        let rows = KeyboardLayout.rows(state: InputState(), needsGlobe: true, preferences: reference)
        XCTAssertFalse(rows[3].contains { $0.action == .noteFocus },
                       "Blue reference has no notes panel and should not offer an inert focus key")
    }

    func testLanguageOrderRemainsUserControlled() {
        var options = KeyboardPreferences()
        options.languages = [.english, .ukrainian, .german]
        XCTAssertEqual(options.validated.languages, [.english, .ukrainian, .german])
        XCTAssertEqual(options.language(after: .english), .ukrainian)
        XCTAssertEqual(options.language(after: .german), .english)
    }

    func testStaggeredMiddleRowRetainsFullWidthTouchCoverage() {
        var state = InputState()
        state.language = .english
        var p = KeyboardPreferences()
        p.iphoneKeyPositions = true
        for width in [165.0, 240.0, 393.0] {
            let cells = KeyboardGeometry.cells(width: width, state: state,
                                               preferences: p, needsGlobe: true)
            guard let first = cells.first(where: { $0.key.action == .text("a") }),
                  let last = cells.first(where: { $0.key.action == .text("l") }) else {
                return XCTFail("Missing middle-row letter")
            }
            XCTAssertGreaterThan(first.visualFrame.minX, 0)
            XCTAssertLessThan(last.visualFrame.maxX, width)
            XCTAssertEqual(first.hitFrame.minX, 0)
            XCTAssertEqual(last.hitFrame.maxX, width, accuracy: 0.001)
        }
    }

    func testSpaceReturnsToLettersFromNumbersAndSymbolsOnly() {
        var state = InputState()
        for page in [KeyboardPage.numbers, .symbols] {
            state.page = page
            state.returnToLettersAfterSpace()
            XCTAssertEqual(state.page, .letters, "Space from \(page) returns to letters")
        }
        state.page = .letters
        state.returnToLettersAfterSpace()
        XCTAssertEqual(state.page, .letters)

        // User-defined layers deliberately preserve their page across Space.
        let custom = UUID()
        state.page = .layer(custom)
        state.returnToLettersAfterSpace()
        XCTAssertEqual(state.page, .layer(custom))
    }

    func testNewKeySpacingAndHiddenHintsPersistThroughSaveAndMigration() throws {
        let defaults = KeyboardPreferences()
        XCTAssertEqual(defaults.rowSpacing, 8)
        XCTAssertEqual(defaults.columnSpacing, 3)
        XCTAssertFalse(defaults.showLongPressHints)
        XCTAssertEqual(try JSONDecoder().decode(
            KeyboardPreferences.self, from: JSONEncoder().encode(defaults)), defaults)

        let oldDefaults = Data(
            #"{"schemaVersion":7,"rowSpacing":2,"columnSpacing":2,"showLongPressHints":true}"#.utf8)
        let migrated = try JSONDecoder().decode(KeyboardPreferences.self, from: oldDefaults)
        XCTAssertEqual(migrated.rowSpacing, 8)
        XCTAssertEqual(migrated.columnSpacing, 3)
        XCTAssertFalse(migrated.showLongPressHints)

        let deliberate = Data(
            #"{"schemaVersion":7,"rowSpacing":5,"columnSpacing":6,"showLongPressHints":true}"#.utf8)
        let custom = try JSONDecoder().decode(KeyboardPreferences.self, from: deliberate)
        XCTAssertEqual(custom.rowSpacing, 5)
        XCTAssertEqual(custom.columnSpacing, 6)
        XCTAssertFalse(custom.showLongPressHints)
    }

    func testLandscapeKeyboardTakesRightEdgeAndLeavesMostWidthForNotes() {
        let base = KeyboardPreferences()
        for width in [600.0, 665.0, 896.0] {
            let keyboard = KeyScratchAdaptiveLayout.keyboardWidth(
                availableWidth: width, landscape: true,
                portraitNoteFraction: base.keyScratchNoteWidth)
            let notes = width - keyboard
            XCTAssertGreaterThanOrEqual(keyboard, 390)
            XCTAssertLessThanOrEqual(keyboard, 430)
            XCTAssertGreaterThan(notes, 0)
            XCTAssertEqual(notes + keyboard, width, accuracy: 0.001)
        }
        let portrait = KeyScratchAdaptiveLayout.keyboardWidth(
            availableWidth: 414, landscape: false, portraitNoteFraction: 0.30)
        XCTAssertEqual(portrait, 414 * 0.70, accuracy: 0.001)
    }

    func testLandscapeShrinksKeyHeightsWithoutChangingPortraitPreferences() {
        var base = KeyboardPreferences()
        base.keyHeight = 68
        base.controlHeight = 52
        base.rowSpacing = 8
        base.letterSize = 26
        base.digitAccess = .numberRow
        let compact = KeyScratchAdaptiveLayout.appearance(base, landscape: true)
        XCTAssertEqual(compact.keyHeight, 40)
        XCTAssertEqual(compact.controlHeight, 36)
        XCTAssertEqual(compact.rowSpacing, 4)
        XCTAssertEqual(compact.letterSize, 21)
        XCTAssertEqual(compact.digitAccess, .flick)
        XCTAssertLessThan(compact.keyboardHeight, base.keyboardHeight)
        XCTAssertEqual(KeyScratchAdaptiveLayout.appearance(base, landscape: false), base)
        XCTAssertEqual(base.keyHeight, 68)
        XCTAssertEqual(base.rowSpacing, 8)
    }

}
