import Foundation
import CoreLocation

@MainActor
final class SyncEngine: ObservableObject {
    @Published private(set) var hazards: [MHMHazard] = []
    @Published private(set) var checkins: [MHMCheckin] = []
    @Published private(set) var journey: [MHMJourneyPoint] = []
    @Published var errorMessage: String?
    @Published var isSyncing = false

    private var authStore: AuthStore?
    private let api = APIClient()

    func configure(authStore: AuthStore) async {
        self.authStore = authStore
        if authStore.isLoggedIn {
            await sync()
        }
    }

    // Sửa lỗi gọi hàm API với tham số nonce thay vì token
    func sync() async {
        guard let nonce = authStore?.nonce, !nonce.isEmpty else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        
        do {
            // SỬA TẠI ĐÂY: Đổi 'token: nonce' thành 'nonce: nonce' khớp với APIClient mới
            async let checkinsTask = api.getCheckins(nonce: nonce)
            async let journeyTask = api.getJourney(nonce: nonce)
            async let hazardsTask = api.getHazards(nonce: nonce)
            async let pingsTask = api.getPings(nonce: nonce)
            
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

    // Sửa lỗi gọi hàm createCheckin
    func createCheckin(title: String, description: String?, coordinate: CLLocationCoordinate2D) async {
        guard let nonce = authStore?.nonce, !nonce.isEmpty else { return }
        do {
            // SỬA TẠI ĐÂY: Đổi tham số đầu tiên từ 'token: nonce' thành 'nonce: nonce'
            let created = try await api.createCheckin(
                nonce: nonce,
                request: MHMCreateCheckinRequest(
                    title: title,
                    description: description,
                    lat: coordinate.latitude,
                    lng: coordinate.longitude
                )
            )
            upsertCheckin(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsertHazard(_ hazard: MHMHazard) {
        hazards.removeAll { $0.id == hazard.id }
        hazards.append(hazard)
    }

    private func upsertCheckin(_ checkin: MHMCheckin) {
        checkins.removeAll { $0.id == checkin.id }
        checkins.append(checkin)
    }
}
