import UIKit

final class KeyboardViewController: UIInputViewController {
    private let translator: any ConversationalTranslator = TestConversationalTranslator()
    private var options = TranslationOptions()
    private let status = UILabel()
    private var globe: UIButton!
    private var composer = HangulComposer()
    private var composingDocument: UUID?
    private var isKorean = true
    private var shifted = false
    private var letterButtons: [UIButton] = []
    private var shiftButton: UIButton!
    private var languageButton: UIButton!

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
            let buttons = letters.map { letter -> UIButton in
                let key = button(String(letter), action: #selector(insertLetter(_:)))
                key.accessibilityIdentifier = String(letter)
                letterButtons.append(key)
                return key
            }
            stack.addArrangedSubview(row(buttons))
        }
        shiftButton = button("⇧", action: #selector(toggleShift))
        languageButton = button("한/영", action: #selector(toggleLanguage))
        globe = button("🌐", action: nil)
        globe.accessibilityLabel = "다음 키보드"
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        stack.addArrangedSubview(row([globe, languageButton, shiftButton, button("space", action: #selector(insertSpace)), button("↵", action: #selector(insertNewline)), button("⌫", action: #selector(deleteCharacter))]))
        stack.addArrangedSubview(row(["1", "2", "3", "?", "!", ".", ","].map { button($0, action: #selector(insertLiteral(_:))) }))
        updateKeys()
        view.addSubview(stack)
        let height = view.heightAnchor.constraint(equalToConstant: 340)
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
        guard let text = sender.title(for: .normal), let key = text.first else { return }
        if isKorean {
            validateComposition()
            if composer.keys.count >= 64 { commitComposition() }
            let previous = composer.text
            composer.append(key)
            replaceComposition(previous: previous)
        } else {
            commitComposition()
            textDocumentProxy.insertText(text)
        }
        shifted = false
        updateKeys()
    }
    @objc private func insertExample() { insertCommitted("오늘 뭐 했어?") }
    @objc private func insertSpace() { insertCommitted(" ") }
    @objc private func insertNewline() { insertCommitted("\n") }
    @objc private func insertLiteral(_ sender: UIButton) {
        if let text = sender.title(for: .normal) { insertCommitted(text) }
    }
    @objc private func deleteCharacter() {
        validateComposition()
        if composer.keys.isEmpty { textDocumentProxy.deleteBackward(); return }
        let previous = composer.text
        composer.deleteLast()
        replaceComposition(previous: previous)
    }

    @objc private func toggleLanguage() {
        commitComposition()
        isKorean.toggle()
        shifted = false
        updateKeys()
    }
    @objc private func toggleShift() { shifted.toggle(); updateKeys() }

    private func updateKeys() {
        let normal = Array("ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔㅁㄴㅇㄹㅎㅗㅓㅏㅣㅋㅌㅊㅍㅠㅜㅡ")
        let upper = Array("ㅃㅉㄸㄲㅆㅛㅕㅑㅒㅖㅁㄴㅇㄹㅎㅗㅓㅏㅣㅋㅌㅊㅍㅠㅜㅡ")
        for (index, button) in letterButtons.enumerated() {
            let latin = button.accessibilityIdentifier ?? ""
            button.setTitle(isKorean ? String((shifted ? upper : normal)[index]) : (shifted ? latin.uppercased() : latin), for: .normal)
        }
        shiftButton?.backgroundColor = shifted ? .systemGray3 : .secondarySystemBackground
        languageButton?.setTitle(isKorean ? "ABC" : "한글", for: .normal)
    }

    private func insertCommitted(_ text: String) {
        commitComposition()
        textDocumentProxy.insertText(text)
    }
    private func commitComposition() {
        composer.reset()
        composingDocument = nil
    }
    private func validateComposition() {
        guard !composer.keys.isEmpty else { return }
        let proxy = textDocumentProxy
        guard composingDocument == proxy.documentIdentifier,
              proxy.selectedText?.isEmpty != false,
              proxy.documentContextBeforeInput?.hasSuffix(composer.text) == true else {
            commitComposition()
            return
        }
    }
    private func replaceComposition(previous: String) {
        let next = composer.text
        let oldCharacters = Array(previous)
        let newCharacters = Array(next)
        let common = zip(oldCharacters, newCharacters).prefix { $0.0 == $0.1 }.count
        for _ in common..<oldCharacters.count { textDocumentProxy.deleteBackward() }
        let insertion = String(newCharacters.dropFirst(common))
        if !insertion.isEmpty { textDocumentProxy.insertText(insertion) }
        composingDocument = textDocumentProxy.documentIdentifier
    }
    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        commitComposition()
    }
    override func viewWillDisappear(_ animated: Bool) {
        commitComposition()
        super.viewWillDisappear(animated)
    }

    @objc private func translate() {
        commitComposition()
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
