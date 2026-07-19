import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "API URL không hợp lệ."
        case .invalidResponse: return "Phản hồi API không hợp lệ."
        case .unauthorized: return "Tài khoản hoặc phiên làm việc không hợp lệ."
        case .server(let message): return message
        }
    }
}

// MARK: - API Response Models
// Ghi chú: MHMLoginResponse đã được chuyển ra file MHMModels.swift để dùng chung toàn hệ thống.

// Định nghĩa bổ sung các model phục vụ cho việc bóc tách hàm sync cũ[cite: 13]
struct MeResponse: Codable {
    let id: Int
    let displayName: String
    let email: String
    let avatar: String?
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case avatar
        case nonce
    }
}

struct JourneyResponse: Codable {
    let user: JourneyUser?
    let stats: JourneyStats?
    let points: [MHMJourneyPoint]
}

struct JourneyUser: Codable {
    let id: Int
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct JourneyStats: Codable {
    let totalDistance: Double
    let totalTime: Double
    
    enum CodingKeys: String, CodingKey {
        case totalDistance = "total_distance"
        case totalTime = "total_time"
    }
}

struct PingResponse: Codable {
    let pings: [MHMPing]
    let server: String
    let ttl: Int
}

// MARK: - API Client Implementation[cite: 13]

final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
        
        // URLSession cấu hình giữ cookie tự động qua HTTPCookieStorage.shared phục vụ WordPress Session Cookie Auth[cite: 13]
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        self.session = URLSession(configuration: configuration)
        
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: value) { return date }
            let iso2 = ISO8601DateFormatter()
            if let date = iso2.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        encoder.dateEncodingStrategy = .iso8601
    }

    // 2a. Hàm đăng nhập trỏ về auth/login và sửa body key thành "login"[cite: 13]
    func login(username: String, password: String) async throws -> MHMLoginResponse {
        let body = ["login": username, "password": password]
        return try await send(path: "auth/login", method: "POST", nonce: nil, body: body)
    }

    // 2b. Thay thế hàm mobile/sync bằng các hàm lấy dữ liệu đơn lẻ từ backend độc lập[cite: 13]
    func getMe(nonce: String) async throws -> MeResponse {
        return try await send(path: "me", method: "GET", nonce: nonce, body: Optional<String>.none)
    }

    func getCheckins(nonce: String) async throws -> [MHMCheckin] {
        // Trả về mảng phẳng trực tiếp từ endpoint /checkins[cite: 13]
        return try await send(path: "checkins", method: "GET", nonce: nonce, body: Optional<String>.none)
    }

    func getJourney(nonce: String) async throws -> JourneyResponse {
        return try await send(path: "journey", method: "GET", nonce: nonce, body: Optional<String>.none)
    }

    func getPings(nonce: String) async throws -> PingResponse {
        return try await send(path: "pings", method: "GET", nonce: nonce, body: Optional<String>.none)
    }
    
    func getHazards(nonce: String?) async throws -> [MHMHazard] {
        // Ánh xạ hazard từ endpoint /reports của backend WordPress[cite: 13]
        return try await send(path: "reports", method: "GET", nonce: nonce, body: Optional<String>.none)
    }

    // 2d. Hàm tạo checkin giữ nguyên path /checkins, sử dụng struct request mới đồng bộ field 'description' thay cho 'note'[cite: 13]
    func createCheckin(nonce: String, request: MHMCreateCheckinRequest) async throws -> MHMCheckin {
        return try await send(path: "checkins", method: "POST", nonce: nonce, body: request)
    }

    // 2c. Hàm send đa hình: Thay thế hoàn toàn Bearer Token bằng X-WP-Nonce Header[cite: 13]
    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        nonce: String?, // Đổi tên tham số từ token sang nonce đúng ngữ nghĩa dữ liệu[cite: 13]
        query: [URLQueryItem] = [],
        body: Body?
    ) async throws -> Response {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Thêm header xác thực nonce của WordPress (Loại bỏ Authorization: Bearer hoàn toàn)[cite: 13]
        if let nonce, !nonce.isEmpty {
            request.setValue(nonce, forHTTPHeaderField: "X-WP-Nonce")
        }
        
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw APIError.unauthorized }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Server error (\(http.statusCode))"
            throw APIError.server(message)
        }
        
        return try decoder.decode(Response.self, from: data)
    }
}
