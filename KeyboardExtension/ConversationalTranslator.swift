// A backend implementation can replace this local stub without changing the UI.
// No network client or shared container is needed for the prototype.
struct TranslationOptions {
    var sourceLanguage = "ko"
    var targetLanguage = "it"
    var tone: Tone = .casual

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
        return "[Italian translation test]"
    }
}
