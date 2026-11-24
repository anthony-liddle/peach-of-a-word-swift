import Foundation
import Network
import PeachEngine

/// Where the app's flags go: `peachofaword.com/api/flag`, and only from a
/// Release build.
///
/// **No preview, simulator, Debug build or test ever sends a flag to the live
/// store** (the build prompt's rule). A Debug build has no `endpoint`, so its
/// flags go to a stand-in that answers as `-flagServer` says, or not at all:
/// - `took`: 202 for flags, 204 for take-backs, as the server does;
/// - `refused`: 400, a flag the server will never take;
/// - `busy`: 503, the store down or missing;
/// - `off`: 403, the kill switch;
/// - nothing: no answer, as with no connection.
/// Release builds ignore it. `FlagServerTests` holds this in the test bundle,
/// which is a Debug build.
///
/// **A flag carries nothing about the player, so the request doesn't
/// either:** an ephemeral session, with no cookies either way and no cache.
enum FlagServer {
    static let production = URL(string: "https://peachofaword.com/api/flag")!

    /// The live server in a Release build; none in any other.
    static var endpoint: URL? {
        #if DEBUG
        nil
        #else
        production
        #endif
    }

    /// The app's version as the flag sends it: "1.4 (125)".
    static func version(short: String, build: String) -> String { "\(short) (\(build))" }

    static var bundleVersion: String {
        let info = Bundle.main.infoDictionary
        return version(short: info?["CFBundleShortVersionString"] as? String ?? "0",
                       build: info?["CFBundleVersion"] as? String ?? "0")
    }

    static var sessionConfiguration: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        return config
    }

    static func urlRequest(_ request: FlagRequest, to url: URL) -> URLRequest {
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        r.httpMethod = request.method.rawValue
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = request.body
        return r
    }

    /// Sends to the live server: the status, or nil for no connection.
    static func live(_ url: URL) -> FlagTransport {
        let session = URLSession(configuration: sessionConfiguration)
        return { request in
            do {
                let (_, response) = try await session.data(for: urlRequest(request, to: url))
                return (response as? HTTPURLResponse)?.statusCode
            } catch {
                return nil
            }
        }
    }

    /// A Debug build's server, answering as `-flagServer` says.
    static func standIn(_ name: String?) -> FlagTransport {
        { request in
            switch name {
            case "took": request.method == .post ? 202 : 204
            case "refused": 400
            case "busy": 503
            case "off": 403
            default: nil
            }
        }
    }

    /// The transport this build uses.
    static var transport: FlagTransport {
        if let endpoint { return live(endpoint) }
        return standIn(UserDefaults.standard.string(forKey: "flagServer"))
    }
}

/// Whether the phone has a network, from `NWPathMonitor`, and a nudge to send
/// what's waiting when it comes back.
@MainActor
final class FlagNetwork {
    private let monitor = NWPathMonitor()
    private(set) var isOnline = true

    func start(onBack: @escaping @MainActor () -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasOnline = self.isOnline
                self.isOnline = online
                if online && !wasOnline { onBack() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "flag-network"))
    }
}
