import ActivityKit

struct DriveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var duration: String
        var distance: String
    }

    var name: String
}
