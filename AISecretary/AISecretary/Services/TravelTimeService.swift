import Foundation
import MapKit

/// 移動時間を自動計算するサービス
/// MapKitを使用して、予定の場所間の移動時間を計算し、出発通知を提供
@MainActor
final class TravelTimeService: ObservableObject {
    @Published var isCalculating = false

    /// 場所名から座標を検索
    func geocode(location: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(location)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    /// 2つの場所間の移動時間を計算
    func calculateTravelTime(
        from origin: String,
        to destination: String,
        transportType: MKDirectionsTransportType = .automobile
    ) async -> TravelTimeResult? {
        isCalculating = true
        defer { isCalculating = false }

        guard let originCoord = await geocode(location: origin),
              let destCoord = await geocode(location: destination) else {
            return nil
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: originCoord))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destCoord))
        request.transportType = transportType

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()
            guard let route = response.routes.first else { return nil }

            return TravelTimeResult(
                travelTimeSeconds: route.expectedTravelTime,
                distanceMeters: route.distance,
                transportType: transportType
            )
        } catch {
            return nil
        }
    }

    /// スケジュール間の移動時間を計算し、出発通知を設定
    func calculateAndNotify(
        currentLocation: String,
        nextSchedule: ScheduleItem
    ) async -> TravelTimeResult? {
        guard !nextSchedule.location.isEmpty else { return nil }

        let origin = currentLocation.isEmpty ? "現在地" : currentLocation
        guard let result = await calculateTravelTime(
            from: origin,
            to: nextSchedule.location
        ) else { return nil }

        // 移動時間 + バッファ（10分）を考慮した出発時刻を計算
        let bufferMinutes: TimeInterval = 10 * 60
        let departureTime = nextSchedule.startDate.addingTimeInterval(
            -(result.travelTimeSeconds + bufferMinutes)
        )

        if departureTime > Date() {
            NotificationService.shared.scheduleNotification(
                id: "travel-\(nextSchedule.id)",
                title: "そろそろ出発の時間です",
                body: "「\(nextSchedule.title)」まで約\(result.travelTimeMinutes)分。\(nextSchedule.location)への移動を始めましょう。",
                date: departureTime
            )
        }

        return result
    }

    /// 今日のスケジュールに対して移動時間を一括計算
    func calculateTravelTimesForToday(
        schedules: [ScheduleItem]
    ) async -> [UUID: TravelTimeResult] {
        var results: [UUID: TravelTimeResult] = [:]
        let sortedSchedules = schedules
            .filter { $0.startDate.isToday && !$0.location.isEmpty }
            .sorted { $0.startDate < $1.startDate }

        var previousLocation = ""
        for schedule in sortedSchedules {
            if !previousLocation.isEmpty {
                if let result = await calculateTravelTime(
                    from: previousLocation,
                    to: schedule.location
                ) {
                    results[schedule.id] = result
                }
            }
            previousLocation = schedule.location
        }

        return results
    }
}

/// 移動時間の計算結果
struct TravelTimeResult {
    let travelTimeSeconds: TimeInterval
    let distanceMeters: Double
    let transportType: MKDirectionsTransportType

    var travelTimeMinutes: Int {
        Int(ceil(travelTimeSeconds / 60))
    }

    var distanceText: String {
        if distanceMeters >= 1000 {
            return String(format: "%.1f km", distanceMeters / 1000)
        } else {
            return "\(Int(distanceMeters)) m"
        }
    }

    var transportIcon: String {
        switch transportType {
        case .automobile: "car.fill"
        case .walking: "figure.walk"
        case .transit: "tram.fill"
        default: "car.fill"
        }
    }

    var summary: String {
        "約\(travelTimeMinutes)分（\(distanceText)）"
    }
}
