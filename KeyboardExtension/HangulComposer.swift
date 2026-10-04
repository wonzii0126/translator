import Foundation

/// Pure two-set Hangul composition. No document or network access.
struct HangulComposer {
    private(set) var keys: [Character] = []
    var text: String { Self.compose(keys) }
    mutating func append(_ key: Character) { keys.append(key) }
    mutating func deleteLast() { if !keys.isEmpty { keys.removeLast() } }
    mutating func reset() { keys.removeAll() }

    private static let initials = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let vowels = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    private static let finals = Array(" ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ")
    private static let vowelPairs: [String: Character] = [
        "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ", "ㅜㅓ": "ㅝ",
        "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ", "ㅡㅣ": "ㅢ"
    ]
    private static let finalPairs: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ",
        "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ",
        "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ"
    ]

    static func compose(_ keys: [Character]) -> String {
        var result = ""
        var index = 0
        while index < keys.count {
            let first = keys[index]
            guard let initial = initials.firstIndex(of: first),
                  index + 1 < keys.count,
                  var vowel = vowels.firstIndex(of: keys[index + 1]) else {
                // Also compose standalone compound vowels.
                if index + 1 < keys.count,
                   let joined = vowelPairs[String(first) + String(keys[index + 1])] {
                    result.append(joined)
                    index += 2
                } else {
                    result.append(first)
                    index += 1
                }
                continue
            }
            index += 2
            if index < keys.count,
               let joined = vowelPairs[String(vowels[vowel]) + String(keys[index])],
               let combined = vowels.firstIndex(of: joined) {
                vowel = combined
                index += 1
            }
            var final = 0
            if index < keys.count, let candidate = finals.firstIndex(of: keys[index]), candidate > 0 {
                let followedByVowel = index + 1 < keys.count && vowels.contains(keys[index + 1])
                if !followedByVowel {
                    final = candidate
                    index += 1
                    if index < keys.count,
                       let joined = finalPairs[String(finals[final]) + String(keys[index])],
                       let combined = finals.firstIndex(of: joined) {
                        let secondMovesToNext = index + 1 < keys.count && vowels.contains(keys[index + 1])
                        if !secondMovesToNext {
                            final = combined
                            index += 1
                        }
                    }
                }
            }
            let scalar = UnicodeScalar(0xAC00 + (initial * 21 + vowel) * 28 + final)!
            result.unicodeScalars.append(scalar)
        }
        return result
    }
}
