import Foundation

/// Mirrors UITextAutocapitalizationType without importing UIKit into Core.
enum AutoCapitalization: Sendable {
    case none, words, sentences, allCharacters

    /// Whether the next letter typed after `before` should start with Shift on.
    func shouldCapitalize(before: String?) -> Bool {
        let before = before ?? ""
        switch self {
        case .none: return false
        case .allCharacters: return true
        case .words: return before.last.map { $0.isWhitespace } ?? true
        case .sentences:
            guard let last = before.last else { return true }
            if last.isNewline { return true }
            guard last.isWhitespace else { return false }
            // Closing quotes and brackets may follow the sentence mark: “Так.” Далі
            let trimmed = before.reversed().drop { $0.isWhitespace && !$0.isNewline }
            if trimmed.isEmpty || trimmed.first?.isNewline == true { return true }
            let mark = trimmed.drop { "\"'”’»)]".contains($0) }.first
            return mark.map { ".!?".contains($0) } ?? false
        }
    }
}


/// Capitalization of English's first-person pronoun, independent of sentence
/// capitalization. Applies to text committed by typing, gliding, suggestions,
/// and expansions, but not to the interior of ordinary words ("inside").
/// The caller is responsible for avoiding literal fields such as web addresses.
enum EnglishPronoun {
    private static let apostrophes: Set<Character> = ["'", "’", "ʼ"]
    private static let contractions = ["ll", "ve", "re", "m", "d", "s"]

    private static func boundary(_ letter: Character?) -> Bool {
        guard let letter else { return true }
        return !letter.isLetter && !letter.isNumber && letter != "_"
    }

    /// A preceding lowercase 'i' should become 'I' just before typing a
    /// delimiter or apostrophe. Hosts may suppress document context; callers
    /// must verify that the trailing 'i' is actually present before replacing.
    static func finishesPriorI(before: String, incoming: String) -> Bool {
        guard before.last == "i", let next = incoming.first else { return false }
        let left = before.dropLast().last
        guard boundary(left) else { return false }
        return boundary(next) || apostrophes.contains(next)
    }

    /// Normalizes complete input fragments including "i'll", "i'd", "i'm",
    /// "i’ve" and an isolated "i". One incomplete typed 'i' is left alone
    /// until a subsequent character tells us whether it begins "inside".
    static func normalized(_ fragment: String, before context: String = "",
                           completeWord: Bool = false) -> String {
        let characters = Array(fragment)
        guard !characters.isEmpty else { return fragment }
        var result = characters
        for index in characters.indices where characters[index] == "i" {
            let prior = index > 0 ? characters[index - 1] : context.last
            guard boundary(prior) else { continue }
            let next = index + 1
            if next == characters.count {
                if completeWord { result[index] = "I" }
                continue
            }
            let nextChar = characters[next]
            if apostrophes.contains(nextChar) {
                let tail = String(characters.dropFirst(next + 1)).lowercased()
                let matches = contractions.contains { suffix in
                    tail.hasPrefix(suffix) &&
                    (tail.count == suffix.count ||
                     boundary(Array(tail)[suffix.count]))
                }
                if matches { result[index] = "I" }
            } else if boundary(nextChar) {
                result[index] = "I"
            }
        }
        return String(result)
    }
}
