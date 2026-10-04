import UIKit

final class KeyboardViewController: UIInputViewController {
    private let translator: any ConversationalTranslator = TestConversationalTranslator()
    private var options = TranslationOptions()
    private let status = UILabel()
    private var globe: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray5
        status.font = .systemFont(ofSize: 12)
        status.textAlignment = .center
        status.numberOfLines = 2
        status.text = "KO → IT · casual · 테스트 번역"
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(status)
        stack.addArrangedSubview(row([button("오늘 뭐 했어?", action: #selector(insertExample)), button("Translate", action: #selector(translate))]))
        for letters in ["qwertyuiop", "asdfghjkl", "zxcvbnm"] {
            stack.addArrangedSubview(row(letters.map { button(String($0), action: #selector(insertLetter(_:))) }))
        }
        globe = button("🌐", action: nil)
        globe.accessibilityLabel = "다음 키보드"
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        stack.addArrangedSubview(row([globe, button("space", action: #selector(insertSpace)), button("↵", action: #selector(insertNewline)), button("⌫", action: #selector(deleteCharacter))]))
        view.addSubview(stack)
        let height = view.heightAnchor.constraint(equalToConstant: 300)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            height,
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6)
        ])
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        globe?.isHidden = !needsInputModeSwitchKey
    }

    private func row(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.spacing = 4
        row.distribution = .fillEqually
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        return row
    }

    private func button(_ title: String, action: Selector?) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 6
        if let action = action { button.addTarget(self, action: action, for: .touchUpInside) }
        return button
    }

    @objc private func insertLetter(_ sender: UIButton) {
        if let text = sender.title(for: .normal) { textDocumentProxy.insertText(text) }
    }
    @objc private func insertExample() { textDocumentProxy.insertText("오늘 뭐 했어?") }
    @objc private func insertSpace() { textDocumentProxy.insertText(" ") }
    @objc private func insertNewline() { textDocumentProxy.insertText("\n") }
    @objc private func deleteCharacter() { textDocumentProxy.deleteBackward() }

    @objc private func translate() {
        // Only the active input field's limited context is available, not chat history.
        let proxy = textDocumentProxy
        guard proxy.selectedText?.isEmpty != false,
              proxy.documentContextAfterInput?.isEmpty != false else {
            status.text = "선택을 해제하고 원문 끝에 커서를 놓으세요."
            return
        }
        guard let source = proxy.documentContextBeforeInput,
              !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status.text = "먼저 원문을 입력하세요."
            return
        }
        let result = translator.translate(source, options: options)
        proxy.insertText((source.hasSuffix("\n") ? "" : "\n") + result)
        status.text = "테스트 번역문 추가됨 · 전송은 직접 누르세요."
    }
}
