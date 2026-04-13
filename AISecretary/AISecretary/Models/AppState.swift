import Foundation
import Combine

final class AppState: ObservableObject {
    // --- API設定（旧: 直接APIキー / 新: リレーサーバー） ---
    @Published var apiKey: String {
        didSet {
            KeychainHelper.save(key: "claude_api_key", value: apiKey)
        }
    }
    @Published var isAPIKeySet: Bool = false

    /// リレーサーバーのURL（例: https://your-server.com）
    @Published var relayServerURL: String {
        didSet {
            UserDefaults.standard.set(relayServerURL, forKey: "relay_server_url")
        }
    }

    /// リレーサーバーの認証トークン
    @Published var relayAuthToken: String {
        didSet {
            KeychainHelper.save(key: "relay_auth_token", value: relayAuthToken)
        }
    }

    /// リレーサーバーが設定済みかどうか
    var isRelayConfigured: Bool {
        !relayServerURL.isEmpty && !relayAuthToken.isEmpty
    }

    // --- ユーザー設定 ---
    @Published var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: "user_name")
        }
    }
    @Published var energyProfile: EnergyProfile {
        didSet {
            if let data = try? JSONEncoder().encode(energyProfile) {
                UserDefaults.standard.set(data, forKey: "energy_profile")
            }
        }
    }
    @Published var defaultLocation: String {
        didSet {
            UserDefaults.standard.set(defaultLocation, forKey: "default_location")
        }
    }
    @Published var eveningReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(eveningReminderEnabled, forKey: "evening_reminder_enabled")
        }
    }
    @Published var eveningReminderHour: Int {
        didSet {
            UserDefaults.standard.set(eveningReminderHour, forKey: "evening_reminder_hour")
        }
    }

    // --- マネージャーモード設定 ---
    @Published var managerModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(managerModeEnabled, forKey: "manager_mode_enabled")
        }
    }
    @Published var prepTimeMinutes: Int {
        didSet {
            UserDefaults.standard.set(prepTimeMinutes, forKey: "prep_time_minutes")
        }
    }

    /// デフォルト移動時間（分）- 場所別プリセットに未登録の場合に使用
    @Published var defaultTravelMinutes: Int {
        didSet {
            UserDefaults.standard.set(defaultTravelMinutes, forKey: "default_travel_minutes")
        }
    }

    /// 移動手段（表示用のみ。GPS版のルート計算には使用しない）
    @Published var preferredTransport: TransportMode {
        didSet {
            UserDefaults.standard.set(preferredTransport.rawValue, forKey: "preferred_transport")
        }
    }

    init() {
        self.apiKey = KeychainHelper.load(key: "claude_api_key") ?? ""
        self.userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        self.isAPIKeySet = !apiKey.isEmpty
        self.relayServerURL = UserDefaults.standard.string(forKey: "relay_server_url") ?? ""
        self.relayAuthToken = KeychainHelper.load(key: "relay_auth_token") ?? ""
        self.defaultLocation = UserDefaults.standard.string(forKey: "default_location") ?? ""
        self.eveningReminderEnabled = UserDefaults.standard.bool(forKey: "evening_reminder_enabled")
        self.eveningReminderHour = UserDefaults.standard.object(forKey: "evening_reminder_hour") as? Int ?? 21
        self.managerModeEnabled = UserDefaults.standard.bool(forKey: "manager_mode_enabled")
        self.prepTimeMinutes = UserDefaults.standard.object(forKey: "prep_time_minutes") as? Int ?? 15
        self.defaultTravelMinutes = UserDefaults.standard.object(forKey: "default_travel_minutes") as? Int ?? 30
        let transportRaw = UserDefaults.standard.integer(forKey: "preferred_transport")
        self.preferredTransport = TransportMode(rawValue: transportRaw) ?? .automobile

        if let data = UserDefaults.standard.data(forKey: "energy_profile"),
           let profile = try? JSONDecoder().decode(EnergyProfile.self, from: data) {
            self.energyProfile = profile
        } else {
            self.energyProfile = EnergyProfile()
        }
    }

    func updateAPIKey(_ key: String) {
        apiKey = key
        isAPIKeySet = !key.isEmpty
    }

    func updateRelayConfig(url: String, token: String) {
        relayServerURL = url
        relayAuthToken = token
    }
}

/// 交通手段の設定（表示用ラベル）
enum TransportMode: Int, CaseIterable {
    case automobile = 0
    case transit = 1
    case walking = 2

    var label: String {
        switch self {
        case .automobile: "車"
        case .transit: "電車・バス"
        case .walking: "徒歩"
        }
    }

    var icon: String {
        switch self {
        case .automobile: "car.fill"
        case .transit: "tram.fill"
        case .walking: "figure.walk"
        }
    }
}
