import Foundation
import SwiftData
import CoreLocation

@Model
final class Trip {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var distanceMeters: Double
    var routeCoordinatesData: Data
    var mood: String
    var note: String

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        distanceMeters: Double,
        routeCoordinatesData: Data = Data(),
        mood: String,
        note: String,
        routeCoordinates: [CLLocationCoordinate2D] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.distanceMeters = distanceMeters
        self.routeCoordinatesData = routeCoordinatesData.isEmpty ? Self.encodeCoordinates(routeCoordinates) : routeCoordinatesData
        self.mood = mood
        self.note = note
    }
}

extension Trip {
    var routeCoordinates: [CLLocationCoordinate2D] {
        get { Self.decodeCoordinates(routeCoordinatesData) }
        set { routeCoordinatesData = Self.encodeCoordinates(newValue) }
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    private static func encodeCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> Data {
        let pairs = coordinates.map { CoordinatePair(latitude: $0.latitude, longitude: $0.longitude) }
        return (try? JSONEncoder().encode(pairs)) ?? Data()
    }

    private static func decodeCoordinates(_ data: Data) -> [CLLocationCoordinate2D] {
        guard let pairs = try? JSONDecoder().decode([CoordinatePair].self, from: data) else { return [] }
        return pairs.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

private struct CoordinatePair: Codable {
    let latitude: Double
    let longitude: Double
}
