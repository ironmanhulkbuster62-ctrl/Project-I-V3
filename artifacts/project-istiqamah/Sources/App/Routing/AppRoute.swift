import Combine
import Foundation

struct AppRoute: Equatable {
    let blockID: UUID?
    let dateKey: String?
    let action: String?

    init(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pathID = url.pathComponents.last.flatMap(UUID.init(uuidString:))
        let taskID = components?.queryItems?.first(where: { $0.name == "taskId" })?.value
            .flatMap(UUID.init(uuidString:))
        blockID = pathID ?? taskID
        dateKey = components?.queryItems?.first(where: { $0.name == "date" })?.value
        action = components?.queryItems?.first(where: { $0.name == "action" })?.value
    }

    init(blockID: UUID?, dateKey: String?, action: String?) {
        self.blockID = blockID
        self.dateKey = dateKey
        self.action = action
    }
}

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    @Published var route: AppRoute?

    func open(_ url: URL) {
        route = AppRoute(url: url)
    }

    func open(blockID: UUID?, dateKey: String?, action: String?) {
        route = AppRoute(blockID: blockID, dateKey: dateKey, action: action)
    }
}
