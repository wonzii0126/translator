import Foundation

@main
struct HangulComposerChecks {
    static func main() {
        let cases = [
            ("ㄱ", "ㄱ"), ("ㄱㅏ", "가"), ("ㄱㅏㄱ", "각"),
            ("ㄱㅏㄱㅏ", "가가"), ("ㄱㅏㄴㅏ", "가나"),
            ("ㄷㅏㄹㄱ", "닭"), ("ㄷㅏㄹㄱㅏ", "달가"),
            ("ㅇㅏㄴㅈ", "앉"), ("ㅇㅏㄴㅈㅏ", "안자"),
            ("ㄱㅗㅏ", "과"), ("ㅂㅜㅓ", "붜"), ("ㅇㅡㅣ", "의"),
            ("ㅗㅏ", "ㅘ"), ("ㄲㅏ", "까"), ("ㅎㅐㅆㅇㅓ", "했어"),
            ("ㅇㅗㄴㅡㄹ", "오늘"), ("ㅁㅜㅓ", "뭐"),
            ("ㄱㅏㅏ", "가ㅏ"), ("ㄱㄴ", "ㄱㄴ")
        ]
        for (input, expected) in cases {
            var composer = HangulComposer()
            for key in input { composer.append(key) }
            precondition(composer.text == expected, "\(input): \(composer.text) != \(expected)")
            while !composer.keys.isEmpty {
                composer.deleteLast()
                precondition(composer.text == HangulComposer.compose(composer.keys))
            }
            precondition(composer.text.isEmpty)
        }
        var composer = HangulComposer()
        for key in "ㄷㅏㄹㄱㅏ" { composer.append(key) }
        for expected in ["닭", "달", "다", "ㄷ", ""] {
            composer.deleteLast()
            precondition(composer.text == expected)
        }
        for key in "ㄱㅗㅏ" { composer.append(key) }
        composer.deleteLast()
        precondition(composer.text == "고")
        composer.reset()
        precondition(composer.text.isEmpty)
        print("Hangul composition checks passed (\(cases.count) cases + staged deletion)")
    }
}
