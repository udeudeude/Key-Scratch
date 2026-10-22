import UIKit

/// First-pass local scratchpad. The existing Ortholinear typing surface stays intact.
/// Notes are kept in the keyboard extension's own sandbox; no Full Access required.
final class ScratchpadView: UIView {
    private let textView = UITextView()
    private let storeKey = "key-scratch.local-note.v1"
    var onInsert: ((String) -> Void)?
    var onEditingChange: ((Bool) -> Void)?
    private(set) var isEditingNote = false
    private let editButton = UIButton(type: .system)

    func type(_ text: String) {
        guard isEditingNote else { return }
        let range = textView.selectedRange
        guard let stringRange = Range(range, in: textView.text) else { return }
        var updated = textView.text ?? ""
        updated.replaceSubrange(stringRange, with: text)
        textView.text = updated
        textView.selectedRange = NSRange(location: range.location + (text as NSString).length, length: 0)
        save()
    }

    func deleteBackward() {
        guard isEditingNote else { return }
        let selection = textView.selectedRange
        if selection.length > 0 {
            type("")
        } else if selection.location > 0 {
            let prior = (textView.text as NSString).rangeOfComposedCharacterSequence(at: selection.location - 1)
            textView.selectedRange = prior
            type("")
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 0.5

        let toolbar = UIStackView()
        toolbar.axis = .vertical
        toolbar.spacing = 1
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.distribution = .fillEqually
        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.distribution = .fillEqually
        toolbar.addArrangedSubview(topRow)
        toolbar.addArrangedSubview(bottomRow)
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 10, weight: .semibold)
        editButton.addTarget(self, action: #selector(toggleEditing), for: .touchUpInside)
        topRow.addArrangedSubview(editButton)
        for (title, action) in [("Paste", #selector(pasteClipboard)),
                                ("Copy", #selector(copyNote)),
                                ("Insert", #selector(insertNote))] {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 9, weight: .semibold)
            button.addTarget(self, action: action, for: .touchUpInside)
            if title == "Insert" { topRow.addArrangedSubview(button) }
            else { bottomRow.addArrangedSubview(button) }
        }

        let clearButton = UIButton(type: .system)
        clearButton.setTitle("Hold Clear", for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 9, weight: .semibold)
        clearButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(clearNoteOnHold(_:))))
        bottomRow.addArrangedSubview(clearButton)

        textView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        let caretTap = UITapGestureRecognizer(target: self, action: #selector(positionCaret(_:)))
        caretTap.cancelsTouchesInView = false
        textView.addGestureRecognizer(caretTap)
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        textView.text = UserDefaults.standard.string(forKey: storeKey) ?? ""
        textView.accessibilityLabel = "Saved scratchpad note"

        let stack = UIStackView(arrangedSubviews: [toolbar, textView])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func positionCaret(_ recognizer: UITapGestureRecognizer) {
        guard isEditingNote else { return }
        let point = recognizer.location(in: textView)
        if let position = textView.closestPosition(to: point) {
            textView.selectedTextRange = textView.textRange(from: position, to: position)
        }
    }

    @objc private func toggleEditing() {
        isEditingNote.toggle()
        editButton.setTitle(isEditingNote ? "Done" : "Edit", for: .normal)
        textView.tintColor = isEditingNote ? .systemBlue : .secondaryLabel
        onEditingChange?(isEditingNote)
    }

    @objc private func pasteClipboard() {
        guard let incoming = UIPasteboard.general.string, !incoming.isEmpty else { return }
        if isEditingNote { type(incoming) }
        else { textView.text = textView.text.isEmpty ? incoming : textView.text + "\n" + incoming; save() }
    }

    @objc private func copyNote() {
        guard !textView.text.isEmpty else { return }
        UIPasteboard.general.string = textView.selectedTextRange.flatMap {
            textView.text(in: $0)
        }.flatMap { $0.isEmpty ? nil : $0 } ?? textView.text
    }

    @objc private func insertNote() {
        guard !textView.text.isEmpty else { return }
        onInsert?(textView.text)
    }

    @objc private func clearNoteOnHold(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        textView.text = ""
        save()
    }

    private func save() { UserDefaults.standard.set(textView.text, forKey: storeKey) }
}
