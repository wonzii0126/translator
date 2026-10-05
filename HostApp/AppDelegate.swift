import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = HostViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class HostViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let instructions = UILabel()
        instructions.numberOfLines = 0
        instructions.font = .systemFont(ofSize: 16)
        instructions.text = "Translator Keyboard\n\n설정 → 일반 → 키보드 → 키보드 → Translator에서 전체 접근을 허용하세요.\n\n개인 CLIENT_TOKEN을 복사한 뒤 키보드의 접속 설정 → 복사한 CLIENT_TOKEN 등록을 선택하세요. Gemini API Key는 넣지 마세요.\n\nTranslate를 누를 때 커서 앞의 제공된 원문이 번역 서버와 Google로 전송됩니다. 긴 입력은 일부만 제공될 수 있습니다. 무료 Gemini는 데이터를 제품 개선에 사용할 수 있으므로 민감하지 않은 예문으로 테스트하세요. 메시지 전송은 직접 합니다."
        let input = UITextView()
        input.font = .systemFont(ofSize: 20)
        input.backgroundColor = .secondarySystemBackground
        input.layer.cornerRadius = 12
        input.accessibilityLabel = "키보드 테스트 입력창"
        let stack = UIStackView(arrangedSubviews: [instructions, input])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            input.heightAnchor.constraint(equalToConstant: 180)
        ])
    }
}
