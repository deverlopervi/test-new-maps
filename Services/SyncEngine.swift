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

    func sync() async {
        guard let nonce = authStore?.nonce, !nonce.isEmpty else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        
        do {
            // Sửa đổi tên tham số từ token: sang nonce:
            async let checkinsTask = api.getCheckins(nonce: nonce)
            async let journeyTask = api.getJourney(nonce: nonce)
            async let hazardsTask = api.getHazards(nonce: nonce) 
            async let pingsTask = api.getPings(nonce: nonce)     
            
            let (checkinsRaw, journeyRaw, hazardsRaw, _) = try await (checkinsTask, journeyTask, hazardsTask, pingsTask)
            
            checkinsRaw.forEach { upsertCheckin($0) }
            hazardsRaw.forEach { upsertHazard($0) }
            
            self.journey = journeyRaw.points
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createCheckin(title: String, description: String?, coordinate: CLLocationCoordinate2D) async {
        guard let nonce = authStore?.nonce, !nonce.isEmpty else { return }
        do {
            // Sửa đổi tên tham số từ token: sang nonce:
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
