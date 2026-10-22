import UIKit

/// First-pass local scratchpad. The existing Ortholinear typing surface stays intact.
/// Notes are kept in the keyboard extension's own sandbox; no Full Access required.
final class ScratchpadView: UIView {
    private let textView = UITextView()
    private let storeKey = "key-scratch.local-note.v1"
    var onInsert: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 0.5

        let toolbar = UIStackView()
        toolbar.axis = .horizontal
        toolbar.spacing = 2
        toolbar.distribution = .fillEqually
        for (title, action) in [("Paste", #selector(pasteClipboard)),
                                ("Copy", #selector(copyNote)),
                                ("Insert", #selector(insertNote)),
                                ("Clear", #selector(clearNote))] {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 9, weight: .semibold)
            button.addTarget(self, action: action, for: .touchUpInside)
            toolbar.addArrangedSubview(button)
        }

        textView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
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
            toolbar.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func pasteClipboard() {
        guard let incoming = UIPasteboard.general.string, !incoming.isEmpty else { return }
        textView.text = textView.text.isEmpty ? incoming : textView.text + "\n" + incoming
        save()
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

    @objc private func clearNote() {
        textView.text = ""
        save()
    }

    private func save() { UserDefaults.standard.set(textView.text, forKey: storeKey) }
}
