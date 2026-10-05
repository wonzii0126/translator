import Foundation
import Security

struct TranslationOptions: Codable, Equatable {
    var sourceLanguage = "ko"
    var targetLanguage = "it"
    var tone: Tone = .casual

    static let sourceLanguages = [(code: "ko", name: "한국어"), (code: "en", name: "영어")]
    static let targetLanguages = [
        (code: "it", name: "이탈리아어"), (code: "en", name: "영어"),
        (code: "ko", name: "한국어"), (code: "ja", name: "일본어")
    ]

    enum Tone: String, Codable {
        case casual
        case formal
    }
}

protocol ConversationalTranslator {
    func translate(_ source: String, options: TranslationOptions) async throws -> String
}

struct TestConversationalTranslator: ConversationalTranslator {
    func translate(_ source: String, options: TranslationOptions) async throws -> String {
        let language = ["it": "Italian", "en": "English", "ko": "Korean", "ja": "Japanese"][options.targetLanguage] ?? options.targetLanguage
        return "[\(language) translation test · \(options.tone.rawValue)]"
    }
}

enum TranslationFailure: LocalizedError {
    case missingToken, unauthorized, limited, service, timeout, incomplete, tooLong
    case busy, providerAuthentication, modelUnavailable, blocked, outputLimit, notConfigured, invalidRequest
    var errorDescription: String? {
        switch self {
        case .missingToken: return "설정에서 접속 토큰을 등록하세요."
        case .unauthorized: return "접속 토큰이 맞지 않습니다. 다시 등록하세요."
        case .limited: return "무료 한도 또는 일시적 제한입니다. 나중에 시도하세요."
        case .service: return "번역 서버 오류입니다. 서버 설정을 확인하세요."
        case .timeout: return "번역 시간이 초과됐습니다."
        case .incomplete: return "완성된 번역 결과를 받지 못했습니다."
        case .tooLong: return "원문은 최대 1,000자까지 번역할 수 있습니다."
        case .busy: return "Google 번역 서비스가 일시적으로 바쁩니다. 잠시 후 다시 시도하세요."
        case .providerAuthentication: return "서버의 Gemini API Key 또는 권한을 확인하세요."
        case .modelUnavailable: return "선택한 번역 모델을 사용할 수 없습니다."
        case .blocked: return "Google이 이 문장의 번역 결과를 제공하지 않았습니다."
        case .outputLimit: return "번역 출력 한도에 도달했습니다. 문장을 짧게 나눠주세요."
        case .notConfigured: return "서버의 Secret 설정 두 개를 확인하세요."
        case .invalidRequest: return "번역 요청이 유효하지 않습니다. 원문·언어 설정을 확인하세요."
        }
    }
}

/// Uses the extension's own keychain; no shared access group is required.
enum TranslationCredentials {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "translator.backend",
         kSecAttrAccount as String: "client-token"]
    }
    static func load() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String) -> Bool {
        let data = Data(token.utf8)
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
    static func remove() -> Bool {
        let result = SecItemDelete(query as CFDictionary)
        return result == errSecSuccess || result == errSecItemNotFound
    }
}

struct BackendConversationalTranslator: ConversationalTranslator {
    static let endpoint = URL(string: "https://translator-backend.kmm010126.workers.dev/translate")!
    private struct Payload: Encodable {
        let text: String
        let sourceLanguage: String
        let targetLanguage: String
        let tone: String
    }
    private struct Result: Decodable { let translation: String }
    private struct ErrorResult: Decodable { let error: String }

    func translate(_ source: String, options: TranslationOptions) async throws -> String {
        guard source.unicodeScalars.count <= 1000 else { throw TranslationFailure.tooLong }
        guard let token = TranslationCredentials.load() else { throw TranslationFailure.missingToken }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Payload(text: source, sourceLanguage: options.sourceLanguage,
                                                         targetLanguage: options.targetLanguage, tone: options.tone.rawValue))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError where error.code == .timedOut { throw TranslationFailure.timeout }
        guard let http = response as? HTTPURLResponse else { throw TranslationFailure.service }
        if http.statusCode != 200, data.count <= 65536,
           let error = try? JSONDecoder().decode(ErrorResult.self, from: data) {
            switch error.error {
            case "translation_service_busy": throw TranslationFailure.busy
            case "provider_authentication_failed": throw TranslationFailure.providerAuthentication
            case "model_unavailable": throw TranslationFailure.modelUnavailable
            case "translation_blocked": throw TranslationFailure.blocked
            case "translation_output_limit": throw TranslationFailure.outputLimit
            case "translation_not_completed", "invalid_translation_response": throw TranslationFailure.incomplete
            case "server_not_configured": throw TranslationFailure.notConfigured
            case "invalid_body", "invalid_translation_request", "json_required": throw TranslationFailure.invalidRequest
            default: break
            }
        }
        switch http.statusCode {
        case 200: break
        case 401: throw TranslationFailure.unauthorized
        case 429: throw TranslationFailure.limited
        case 504: throw TranslationFailure.timeout
        default: throw TranslationFailure.service
        }
        guard data.count <= 65536, let result = try? JSONDecoder().decode(Result.self, from: data),
              !result.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              result.translation.count <= 8000 else { throw TranslationFailure.incomplete }
        return result.translation
    }

    // Never forward the personal access token to a redirected destination.
    private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }
}
