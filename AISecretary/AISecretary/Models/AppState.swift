import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var apiKey: String {
        didSet {
            KeychainHelper.save(key: "claude_api_key", value: apiKey)
        }
    }
    @Published var isAPIKeySet: Bool = false
    @Published var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: "user_name")
        }
    }

    init() {
        self.apiKey = KeychainHelper.load(key: "claude_api_key") ?? ""
        self.userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        self.isAPIKeySet = !apiKey.isEmpty
    }

    func updateAPIKey(_ key: String) {
        apiKey = key
        isAPIKeySet = !key.isEmpty
    }
}
