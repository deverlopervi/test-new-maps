import Foundation
import CoreLocation

// MARK: - 3b. MHMUser
struct MHMUser: Codable, Identifiable, Equatable {
    let id: Int
    let displayName: String
    let email: String?
    let avatar: URL? // Thêm trường optional avatar để dùng với cả response /me

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case avatar
    }
}

// MARK: - MHMCoordinate
struct MHMCoordinate: Codable, Equatable {
    let lat: Double
    let lng: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - MHMHazard
struct MHMHazard: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let type: String?
    let severity: String?
    let coordinate: MHMCoordinate
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, type, severity, coordinate
        case updatedAt = "updated_at"
    }
}

// MARK: - 3c. MHMCheckin
struct MHMCheckin: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String? // Đổi note -> description
    let lat: Double          // Đưa lat ra gốc
    let lng: Double          // Đưa lng ra gốc
    let address: String?     // Thêm optional address
    let source: String?      // Thêm optional source
    let reportId: Int?       // Thêm optional report_id
    let category: String?    // Thêm optional category
    let timestamp: Int?      // Thêm optional timestamp (unix Int)
    let created: Date?       // Thêm optional created (ISO date), loại bỏ updated_at
    let media: [MHMMedia]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case lat
        case lng
        case address
        case source
        case reportId = "report_id"
        case category
        case timestamp
        case created
        case media
    }
}

// MARK: - MHMMedia
struct MHMMedia: Codable, Identifiable, Equatable {
    let id: Int
    let url: URL?
    let thumb: URL?
}

// MARK: - 3d. MHMJourneyPoint
struct MHMJourneyPoint: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let lat: Double
    let lng: Double
    let timestamp: Int?
    let created: Date?
}

// MARK: - 3a. MHMLoginResponse
struct MHMLoginResponse: Codable {
    let loggedIn: Bool
    let id: Int
    let displayName: String
    let email: String?
    let address: String?
    let phone: String?
    let interests: String?
    let avatarId: Int?
    let avatar: URL?
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case loggedIn = "logged_in"
        case id
        case displayName = "display_name"
        case email
        case address
        case phone
        case interests
        case avatarId = "avatar_id"
        case avatar
        case nonce
    }
}

// MARK: - 3f. MHMCreateCheckinRequest
struct MHMCreateCheckinRequest: Codable {
    let title: String
    let description: String? // Đổi note -> description cho khớp backend
    let lat: Double
    let lng: Double
}