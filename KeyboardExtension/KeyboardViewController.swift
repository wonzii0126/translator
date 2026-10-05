import UIKit

final class KeyboardViewController: UIInputViewController {
    private let translator: any ConversationalTranslator = BackendConversationalTranslator()
    private var translationTask: Task<Void, Never>?
    private var inputRevision = 0
    private var translateButton: UIButton!
    private var connectionButton: UIButton!
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
    private let keyRows = UIStackView()
    private var isNumbers = false
    private var alternateSymbols = false
    private var sourceButton: UIButton!
    private var targetButton: UIButton!
    private var toneButton: UIButton!
    private var numberButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray5
        status.font = .systemFont(ofSize: 12)
        status.textAlignment = .center
        status.numberOfLines = 1
        status.adjustsFontSizeToFitWidth = true
        restoreOptions()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        sourceButton = button("", action: nil)
        targetButton = button("", action: nil)
        toneButton = button("", action: nil)
        translateButton = button("Translate", action: #selector(translate))
        translateButton.backgroundColor = .systemBlue
        translateButton.setTitleColor(.white, for: .normal)
        let toolbar = row([sourceButton, targetButton, toneButton, translateButton])
        toolbar.heightAnchor.constraint(equalToConstant: 34).isActive = true
        stack.addArrangedSubview(toolbar)
        connectionButton = button("접속 설정 ▾", action: nil)
        connectionButton.titleLabel?.font = .systemFont(ofSize: 12)
        connectionButton.menu = UIMenu(title: "개인 번역 서버", children: [
            UIAction(title: "복사한 CLIENT_TOKEN 등록") { [weak self] _ in self?.registerToken() },
            UIAction(title: "저장한 토큰 삭제", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.inputRevision += 1
                self.translationTask?.cancel()
                self.status.text = TranslationCredentials.remove() ? "접속 토큰 삭제됨" : "토큰 삭제 실패"
            }
        ])
        connectionButton.showsMenuAsPrimaryAction = true
        connectionButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(connectionButton)
        stack.addArrangedSubview(status)
        status.heightAnchor.constraint(equalToConstant: 18).isActive = true
        keyRows.axis = .vertical
        keyRows.spacing = 8
        stack.addArrangedSubview(keyRows)
        rebuildKeys()
        updateMenus()
        view.addSubview(stack)
        let height = view.heightAnchor.constraint(equalToConstant: 330)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            height,
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6)
        ])
    }

    private func rebuildKeys() {
        for row in keyRows.arrangedSubviews { keyRows.removeArrangedSubview(row); row.removeFromSuperview() }
        letterButtons.removeAll()
        let layouts = isNumbers
            ? (alternateSymbols ? ["[]{}#%^*+=", "_\\|~<>€£¥", ".,?!'\";"] : ["1234567890", "-/:;()$&@", ".,?!'\";"])
            : ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        for (index, letters) in layouts.enumerated() {
            let buttons = letters.map { letter -> UIButton in
                let key = button(String(letter), action: isNumbers ? #selector(insertLiteral(_:)) : #selector(insertLetter(_:)))
                key.accessibilityIdentifier = String(letter)
                if !isNumbers { letterButtons.append(key) }
                return key
            }
            if index == 2 {
                shiftButton = button(isNumbers ? "#+=" : "⇧", action: #selector(toggleShift))
                shiftButton.accessibilityLabel = isNumbers ? "기호 페이지 전환" : "Shift"
                let delete = button("⌫", action: #selector(deleteCharacter))
                delete.accessibilityLabel = "삭제"
                keyRows.addArrangedSubview(weightedRow([shiftButton] + buttons + [delete], weights: [1.4] + Array(repeating: 1, count: buttons.count) + [1.4]))
            } else {
                let keys = row(buttons)
                keys.heightAnchor.constraint(equalToConstant: 42).isActive = true
                if index == 1 {
                    // Center the nine-key row with a half-key inset on either side.
                    let container = UIView()
                    keys.translatesAutoresizingMaskIntoConstraints = false
                    container.addSubview(keys)
                    NSLayoutConstraint.activate([
                        keys.topAnchor.constraint(equalTo: container.topAnchor),
                        keys.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                        keys.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                        keys.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.9)
                    ])
                    keyRows.addArrangedSubview(container)
                } else { keyRows.addArrangedSubview(keys) }
            }
        }
        languageButton = button("한/영", action: #selector(toggleLanguage))
        languageButton.accessibilityLabel = "한영 자판 전환"
        numberButton = button(isNumbers ? (isKorean ? "가나다" : "ABC") : "123", action: #selector(toggleNumbers))
        globe = button("🌐", action: nil)
        globe.accessibilityLabel = "다음 키보드"
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        globe.isHidden = !needsInputModeSwitchKey
        let space = button(isKorean ? "스페이스" : "space", action: #selector(insertSpace))
        let newline = button("↵", action: #selector(insertNewline))
        newline.accessibilityLabel = "줄바꿈"
        let bottom = weightedRow([numberButton, languageButton, space, newline], weights: [1.2, 1.1, 4.5, 1.7])
        keyRows.addArrangedSubview(bottom)
        // Keep the globe in a separate narrow area only when iOS requires it.
        bottom.insertArrangedSubview(globe, at: 1)
        let globeWidth = globe.widthAnchor.constraint(equalTo: numberButton.widthAnchor)
        globeWidth.priority = .defaultHigh
        globeWidth.isActive = true
        updateKeys()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        globe?.isHidden = !needsInputModeSwitchKey
    }

    private func row(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.spacing = 4
        row.distribution = .fillEqually
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        return row
    }

    private func weightedRow(_ buttons: [UIButton], weights: [CGFloat]) -> UIStackView {
        let row = self.row(buttons)
        row.distribution = .fill
        for index in 1..<buttons.count {
            buttons[index].widthAnchor.constraint(equalTo: buttons[0].widthAnchor, multiplier: weights[index] / weights[0]).isActive = true
        }
        row.heightAnchor.constraint(equalToConstant: 42).isActive = true
        return row
    }

    private func button(_ title: String, action: Selector?) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.65
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 6
        if let action = action { button.addTarget(self, action: action, for: .touchUpInside) }
        return button
    }

    @objc private func insertLetter(_ sender: UIButton) {
        inputRevision += 1
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
    @objc private func insertSpace() { insertCommitted(" ") }
    @objc private func insertNewline() { insertCommitted("\n") }
    @objc private func insertLiteral(_ sender: UIButton) {
        if let text = sender.title(for: .normal) { insertCommitted(text) }
    }
    @objc private func deleteCharacter() {
        inputRevision += 1
        validateComposition()
        if composer.keys.isEmpty { textDocumentProxy.deleteBackward(); return }
        let previous = composer.text
        composer.deleteLast()
        replaceComposition(previous: previous)
    }

    @objc private func toggleLanguage() {
        commitComposition()
        isKorean.toggle()
        isNumbers = false
        shifted = false
        rebuildKeys()
        options.sourceLanguage = isKorean ? "ko" : "en"
        saveOptions()
    }
    @objc private func toggleNumbers() {
        commitComposition()
        isNumbers.toggle()
        alternateSymbols = false
        shifted = false
        rebuildKeys()
    }
    @objc private func toggleShift() {
        if isNumbers { alternateSymbols.toggle(); rebuildKeys() }
        else { shifted.toggle(); updateKeys() }
    }

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

    private func restoreOptions() {
        let defaults = UserDefaults.standard
        if let source = defaults.string(forKey: "sourceLanguage"),
           TranslationOptions.sourceLanguages.contains(where: { $0.code == source }) {
            options.sourceLanguage = source
        }
        if let target = defaults.string(forKey: "targetLanguage"),
           TranslationOptions.targetLanguages.contains(where: { $0.code == target }) {
            options.targetLanguage = target
        }
        if let raw = defaults.string(forKey: "translationTone"), let tone = TranslationOptions.Tone(rawValue: raw) {
            options.tone = tone
        }
        isKorean = options.sourceLanguage == "ko"
    }

    private func saveOptions() {
        inputRevision += 1
        // Extension-local preferences: no App Group or Full Access required.
        let defaults = UserDefaults.standard
        defaults.set(options.sourceLanguage, forKey: "sourceLanguage")
        defaults.set(options.targetLanguage, forKey: "targetLanguage")
        defaults.set(options.tone.rawValue, forKey: "translationTone")
        updateMenus()
    }

    private func updateMenus() {
        sourceButton.setTitle("\(options.sourceLanguage.uppercased()) ▾", for: .normal)
        sourceButton.accessibilityLabel = "원문 언어"
        sourceButton.menu = UIMenu(title: "원문 언어", children: TranslationOptions.sourceLanguages.map { language in
            UIAction(title: language.name, state: language.code == options.sourceLanguage ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.commitComposition()
                self.options.sourceLanguage = language.code
                self.isKorean = language.code == "ko"
                self.isNumbers = false
                self.shifted = false
                self.rebuildKeys()
                self.saveOptions()
            }
        })
        targetButton.setTitle("→ \(options.targetLanguage.uppercased()) ▾", for: .normal)
        targetButton.accessibilityLabel = "번역 언어"
        targetButton.menu = UIMenu(title: "번역 언어", children: TranslationOptions.targetLanguages.map { language in
            UIAction(title: language.name, state: language.code == options.targetLanguage ? .on : .off) { [weak self] _ in
                self?.commitComposition()
                self?.options.targetLanguage = language.code
                self?.saveOptions()
            }
        })
        toneButton.setTitle(options.tone == .casual ? "일상체 ▾" : "정중체 ▾", for: .normal)
        toneButton.accessibilityLabel = "번역 말투"
        toneButton.menu = UIMenu(title: "번역 말투", children: [TranslationOptions.Tone.casual, .formal].map { tone in
            UIAction(title: tone == .casual ? "일상체 (casual)" : "정중체 (formal)", state: tone == options.tone ? .on : .off) { [weak self] _ in
                self?.commitComposition()
                self?.options.tone = tone
                self?.saveOptions()
            }
        })
        for button in [sourceButton, targetButton, toneButton] { button?.showsMenuAsPrimaryAction = true }
        status.text = "Translate 시 커서 앞 원문을 Google로 전송합니다."
    }

    private func insertCommitted(_ text: String) {
        inputRevision += 1
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
        inputRevision += 1
        super.textWillChange(textInput)
        commitComposition()
    }
    override func viewWillDisappear(_ animated: Bool) {
        inputRevision += 1
        translationTask?.cancel()
        commitComposition()
        super.viewWillDisappear(animated)
    }

    @objc private func translate() {
        guard translationTask == nil else { return }
        commitComposition()
        guard hasFullAccess else {
            status.text = "설정 → 키보드 → Translator → 전체 접근 허용을 켜세요."
            return
        }
        guard TranslationCredentials.load() != nil else {
            status.text = "접속 설정에서 복사한 CLIENT_TOKEN을 등록하세요."
            return
        }
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
        let document = proxy.documentIdentifier
        let after = proxy.documentContextAfterInput
        let revision = inputRevision
        let selectedOptions = options
        translateButton.isEnabled = false
        translateButton.setTitle("번역 중…", for: .normal)
        status.text = "커서 앞 원문 번역 중 · 입력하면 결과 삽입을 취소합니다."
        translationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                self.translationTask = nil
                self.translateButton.isEnabled = true
                self.translateButton.setTitle("Translate", for: .normal)
            }
            do {
                let result = try await self.translator.translate(source, options: selectedOptions)
                try Task.checkCancellation()
                let current = self.textDocumentProxy
                guard self.hasFullAccess, self.inputRevision == revision, self.options == selectedOptions,
                      current.documentIdentifier == document, current.documentContextBeforeInput == source,
                      current.documentContextAfterInput == after, current.selectedText?.isEmpty != false else {
                    self.status.text = "입력이나 설정이 바뀌어 삽입 취소됨. 다시 Translate를 누르세요."
                    return
                }
                current.insertText((source.hasSuffix("\n") ? "" : "\n") + result)
                self.status.text = "번역문 추가됨 · 전송은 직접 누르세요."
            } catch {
                if Task.isCancelled { self.status.text = "번역 취소됨" }
                else if let failure = error as? TranslationFailure { self.status.text = failure.localizedDescription }
                else { self.status.text = "네트워크 연결을 확인하고 다시 시도하세요." }
            }
        }
    }

    private func registerToken() {
        guard hasFullAccess else { status.text = "토큰 등록과 번역에는 전체 접근 허용이 필요합니다."; return }
        // Read the clipboard only in response to this explicit menu action.
        guard let token = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              token.count >= 32, token.count <= 256,
              !token.contains(where: { $0.isWhitespace }), !token.hasPrefix("AIza") else {
            status.text = "Gemini 키가 아닌, 생성한 CLIENT_TOKEN을 복사하세요."
            return
        }
        inputRevision += 1
        translationTask?.cancel()
        status.text = TranslationCredentials.save(token) ? "접속 토큰 저장됨 · 이제 Translate를 누르세요." : "토큰 저장 실패. 설치·서명 설정을 확인하세요."
    }
}
