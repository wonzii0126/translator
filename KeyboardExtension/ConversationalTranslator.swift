// A backend implementation can replace this local stub without changing the UI.
// No network client or shared container is needed for the prototype.
struct TranslationOptions {
    var sourceLanguage = "ko"
    var targetLanguage = "it"
    var tone: Tone = .casual

    static let sourceLanguages = [(code: "ko", name: "한국어"), (code: "en", name: "영어")]
    static let targetLanguages = [
        (code: "it", name: "이탈리아어"), (code: "en", name: "영어"),
        (code: "ko", name: "한국어"), (code: "ja", name: "일본어")
    ]

    enum Tone: String {
        case casual
        case formal
    }
}

protocol ConversationalTranslator {
    func translate(_ source: String, options: TranslationOptions) -> String
}

struct TestConversationalTranslator: ConversationalTranslator {
    func translate(_ source: String, options: TranslationOptions) -> String {
        let language = ["it": "Italian", "en": "English", "ko": "Korean", "ja": "Japanese"][options.targetLanguage] ?? options.targetLanguage
        return "[\(language) translation test · \(options.tone.rawValue)]"
    }
}
