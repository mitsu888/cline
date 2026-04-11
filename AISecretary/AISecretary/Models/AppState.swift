import Foundation
import Combine
import MapKit

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

    // マネージャーモード設定
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
    @Published var preferredTransport: TransportMode {
        didSet {
            UserDefaults.standard.set(preferredTransport.rawValue, forKey: "preferred_transport")
        }
    }

    init() {
        self.apiKey = KeychainHelper.load(key: "claude_api_key") ?? ""
        self.userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        self.isAPIKeySet = !apiKey.isEmpty
        self.defaultLocation = UserDefaults.standard.string(forKey: "default_location") ?? ""
        self.eveningReminderEnabled = UserDefaults.standard.bool(forKey: "evening_reminder_enabled")
        self.eveningReminderHour = UserDefaults.standard.object(forKey: "evening_reminder_hour") as? Int ?? 21
        self.managerModeEnabled = UserDefaults.standard.bool(forKey: "manager_mode_enabled")
        self.prepTimeMinutes = UserDefaults.standard.object(forKey: "prep_time_minutes") as? Int ?? 15
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
}

/// 交通手段の設定
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

    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .automobile: .automobile
        case .transit: .transit
        case .walking: .walking
        }
    }
}
