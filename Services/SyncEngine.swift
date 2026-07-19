import Foundation
import CoreLocation

@MainActor
final class SyncEngine: ObservableObject {
    @Published private(set) var hazards: [MHMHazard] = []
    @Published private(set) var checkins: [MHMCheckin] = []
    @Published private(set) var journey: [MHMJourneyPoint] = []
    @Published var errorMessage: String?
    @Published var isSyncing = false

    // 5a. Giữ nguyên authStore
    private var authStore: AuthStore?
    private let api = APIClient()
    
    // Đã xoá lastSyncDate theo yêu cầu 5b (Backend không hỗ trợ since)

    func configure(authStore: AuthStore) async {
        self.authStore = authStore
        if authStore.isLoggedIn {
            await sync()
        }
    }

    // 5b & 5d. Sửa hàm sync, dùng nonce, xoá since, gọi song song, map hazards
    func sync() async {
        // Bỏ token -> dùng authStore?.nonce
        guard let nonce = authStore?.nonce, !nonce.isEmpty else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        
        do {
            // Gọi song song các request để tối ưu hiệu suất mạng
            async let checkinsTask = api.getCheckins(token: nonce)
            async let journeyTask = api.getJourney(token: nonce)
            async let hazardsTask = api.getHazards(token: nonce) // 5d. Lấy hazards từ GET /reports
            async let pingsTask = api.getPings(token: nonce)     // Tuỳ chọn
            
            // Đợi tất cả hoàn thành
            let (checkinsRaw, journeyRaw, hazardsRaw, _) = try await (checkinsTask, journeyTask, hazardsTask, pingsTask)
            
            // Map kết quả vào state
            checkinsRaw.forEach { upsertCheckin($0) }
            hazardsRaw.forEach { upsertHazard($0) }
            
            // Lấy array points từ envelope của endpoint /journey
            self.journey = journeyRaw.points
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 5c. Sửa field note thành description, dùng nonce
    func createCheckin(title: String, description: String?, coordinate: CLLocationCoordinate2D) async {
        // Truyền nonce thay token
        guard let nonce = authStore?.nonce, !nonce.isEmpty else { return }
        do {
            let created = try await api.createCheckin(
                token: nonce,
                request: MHMCreateCheckinRequest(
                    title: title,
                    description: description, // Dùng description thay vì note
                    lat: coordinate.latitude,
                    lng: coordinate.longitude
                )
            )
            upsertCheckin(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Đã xoá hàm merge(_ payload: MHMSyncPayload) vì payload này không còn tồn tại

    private func upsertHazard(_ hazard: MHMHazard) {
        hazards.removeAll { $0.id == hazard.id }
        hazards.append(hazard)
    }

    private func upsertCheckin(_ checkin: MHMCheckin) {
        checkins.removeAll { $0.id == checkin.id }
        checkins.append(checkin)
    }
}