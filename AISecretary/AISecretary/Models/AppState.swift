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

    init() {
        self.apiKey = KeychainHelper.load(key: "claude_api_key") ?? ""
        self.userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        self.isAPIKeySet = !apiKey.isEmpty
        self.defaultLocation = UserDefaults.standard.string(forKey: "default_location") ?? ""
        self.eveningReminderEnabled = UserDefaults.standard.bool(forKey: "evening_reminder_enabled")
        self.eveningReminderHour = UserDefaults.standard.object(forKey: "evening_reminder_hour") as? Int ?? 21

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
}
