import Foundation

enum AppConfig {
    static var apiBaseURL: URL {
        let raw = Bundle.main.object(forInfoDictionaryKey: "MHM_API_BASE_URL") as? String
        let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return URL(string: value).filterValidURL ?? URL(string: "https://example.com/wp-json/mhm/v1")!
    }

    static var goongAPIKey: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GOONG_API_KEY") as? String
        return raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private extension Optional where Wrapped == URL {
    var filterValidURL: URL? {
        guard let url = self, let scheme = url.scheme, ["http", "https"].contains(scheme) else { return nil }
        return url
    }
}
