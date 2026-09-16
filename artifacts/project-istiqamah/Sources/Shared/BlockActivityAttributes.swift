import ActivityKit
import Foundation

struct BlockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let blockName: String
        let startDate: Date
        let endDate: Date
        let timeLabel: String
    }

    let blockID: UUID
    let dateKey: String

    var deepLink: URL? {
        var components = URLComponents()
        components.scheme = "project-istiqamah"
        components.host = "block"
        components.path = "/\(blockID.uuidString)"
        components.queryItems = [
            URLQueryItem(name: "date", value: dateKey),
            URLQueryItem(name: "action", value: "complete")
        ]
        return components.url
    }
}
