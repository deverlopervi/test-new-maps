import Foundation
import CoreLocation

struct GoongPlaceSuggestion: Identifiable, Decodable {
    var id: String { placeId }
    let description: String
    let placeId: String

    enum CodingKeys: String, CodingKey {
        case description
        case placeId = "place_id"
    }
}

struct GoongGeocodedPlace: Decodable {
    let lat: Double
    let lng: Double
}

final class GoongClient {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String = AppConfig.goongAPIKey, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func autocomplete(_ text: String) async throws -> [GoongPlaceSuggestion] {
        guard !apiKey.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var components = URLComponents(string: "https://rsapi.goong.io/Place/AutoComplete")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "input", value: text)
        ]
        let (data, _) = try await session.data(from: components.url!)
        let root = try JSONDecoder().decode(AutocompleteRoot.self, from: data)
        return root.predictions
    }

    func detail(placeId: String) async throws -> CLLocationCoordinate2D? {
        guard !apiKey.isEmpty else { return nil }
        var components = URLComponents(string: "https://rsapi.goong.io/Place/Detail")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "place_id", value: placeId)
        ]
        let (data, _) = try await session.data(from: components.url!)
        let root = try JSONDecoder().decode(DetailRoot.self, from: data)
        guard let location = root.result?.geometry.location else { return nil }
        return CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng)
    }

    private struct AutocompleteRoot: Decodable {
        let predictions: [GoongPlaceSuggestion]
    }

    private struct DetailRoot: Decodable {
        let result: DetailResult?
    }

    private struct DetailResult: Decodable {
        let geometry: Geometry
    }

    private struct Geometry: Decodable {
        let location: GoongGeocodedPlace
    }
}
