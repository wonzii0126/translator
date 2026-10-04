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
        instructions.text = "Translator Keyboard\n\n설정 → 일반 → 키보드 → 키보드 → 새로운 키보드 추가에서 Translator를 선택하세요.\n\n전체 접근은 필요하지 않습니다. 아래 입력창 또는 메신저에서 지구본 버튼으로 키보드를 전환하세요. 원문 끝에서 Translate를 누르세요. 전송은 직접 합니다."
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
