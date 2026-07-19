import Foundation

@MainActor
final class AuthStore: ObservableObject {
    // Đổi @Published private(set) var token: String? -> nonce: String?
    @Published private(set) var nonce: String?
    @Published private(set) var user: MHMUser?
    @Published var errorMessage: String?
    @Published var isBusy = false

    // Đổi tokenKey thành nonceKey
    private let nonceKey = "mhm.mobile.auth.nonce"
    private let api = APIClient()

    // Kiểm tra đăng nhập qua nonce thay vì token
    var isLoggedIn: Bool { nonce?.isEmpty == false }

    init() {
        // Load nonce từ Keychain lúc khởi tạo ứng dụng
        nonce = KeychainStore.shared.get(nonceKey)
    }

    func login(username: String, password: String) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let response = try await api.login(username: username, password: password)
            
            // Gán nonce từ flat response
            nonce = response.nonce
            
            // Dựng MHMUser từ các field phẳng của response
            user = MHMUser(
                id: response.id,
                displayName: response.displayName,
                email: response.email,
                avatar: response.avatar
            )
            
            // Lưu nonce vào Keychain
            KeychainStore.shared.set(response.nonce, for: nonceKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        
        // 1. Gọi API POST /auth/logout để hủy session phía WordPress backend
        do {
            // Hàm send của APIClient yêu cầu truyền struct Encodable cho body, truyền Optional<String>.none nếu không cần body
            let _: EmptyResponse? = try? await api.send(path: "auth/logout", method: "POST", nonce: nonce, body: Optional<String>.none)
        }
        
        // 2. Clear cookie của WordPress để đảm bảo đăng xuất hoàn toàn khỏi hệ thống
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        
        // 3. Xóa thông tin trạng thái ở local store
        nonce = nil
        user = nil
        KeychainStore.shared.delete(nonceKey)
    }
}

// Struct phụ trợ dùng để decode cho các API không trả về data (hoặc trả về object rỗng {})
struct EmptyResponse: Codable {}