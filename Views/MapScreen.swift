import SwiftUI
import MapKit
import CoreLocation

private enum MapSheet: Identifiable {
    case checkin
    case hazardPin
    case sos
    case menu
    case account
    case journey

    var id: String {
        switch self {
        case .checkin: return "checkin"
        case .hazardPin: return "hazardPin"
        case .sos: return "sos"
        case .menu: return "menu"
        case .account: return "account"
        case .journey: return "journey"
        }
    }
}

private struct HazardCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color

    func matches(_ hazard: MHMHazard) -> Bool {
        guard title != "Tất cả" else { return true }
        let haystack = [hazard.type, hazard.severity, hazard.title]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        let needle = title
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        return haystack.contains(needle)
            || needle.components(separatedBy: " / ").contains { haystack.contains($0) }
    }
}

private let hazardCategories: [HazardCategory] = [
    .init(title: "Tất cả", icon: "square.grid.2x2.fill", color: Color(mapHex: 0xF5A524)),
    .init(title: "Tai nạn giao thông", icon: "car.side.fill", color: Color(mapHex: 0xFF4D4D)),
    .init(title: "Tắc đường", icon: "road.lanes", color: Color(mapHex: 0xF97316)),
    .init(title: "Ngập lụt / Mưa lớn", icon: "cloud.heavyrain.fill", color: Color(mapHex: 0x2F80ED)),
    .init(title: "Sạt lở đất", icon: "mountain.2.fill", color: Color(mapHex: 0xA16207)),
    .init(title: "Bão / Gió lớn", icon: "wind", color: Color(mapHex: 0x64748B)),
    .init(title: "Cần cấp cứu / Cứu thương", icon: "cross.case.fill", color: Color(mapHex: 0xE11D48)),
    .init(title: "Hỏa hoạn", icon: "flame.fill", color: Color(mapHex: 0xEF4444)),
    .init(title: "SOS khẩn cấp", icon: "sos", color: Color(mapHex: 0xDC2626)),
    .init(title: "Cứu hộ xe", icon: "wrench.and.screwdriver.fill", color: Color(mapHex: 0xF59E0B)),
    .init(title: "Khác", icon: "mappin.and.ellipse", color: Color(mapHex: 0x8B5CF6))
]

struct MapScreen: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var syncEngine: SyncEngine
    @StateObject private var locationManager = LocationManager()
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542)
    @State private var activeSheet: MapSheet?
    @State private var selectedCategory = "Tất cả"

    private var filteredHazards: [MHMHazard] {
        guard let category = hazardCategories.first(where: { $0.title == selectedCategory }) else {
            return syncEngine.hazards
        }
        return syncEngine.hazards.filter(category.matches)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MHMMapView(
                    hazards: filteredHazards,
                    checkins: syncEngine.checkins,
                    userCoordinate: locationManager.coordinate,
                    centerCoordinate: $centerCoordinate
                )
                .ignoresSafeArea()

                mapLightWash

                VStack(spacing: 10) {
                    websiteHeader
                    searchPanel
                    Spacer()
                    pingStatusCard
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)

                VStack {
                    HStack {
                        Spacer()
                        rightWebsiteControls
                    }
                    .padding(.trailing, 10)
                    .padding(.top, 138)
                    Spacer()
                }

                if let message = syncEngine.errorMessage {
                    VStack {
                        errorBanner(message)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 112)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                locationManager.request()
                await syncEngine.sync()
            }
            .onChange(of: locationManager.coordinate?.latitude) { _ in
                if let coordinate = locationManager.coordinate {
                    centerCoordinate = coordinate
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .checkin:
                    CheckinSheet(coordinate: centerCoordinate)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                case .hazardPin:
                    HazardPinSheet(coordinate: centerCoordinate)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .sos:
                    SOSSheet(coordinate: locationManager.coordinate ?? centerCoordinate)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                case .menu:
                    MainMenuSheet(
                        selectedCategory: $selectedCategory,
                        openAccount: { activeSheet = .account },
                        openCheckin: { activeSheet = authStore.isLoggedIn ? .checkin : .account },
                        openJourney: { activeSheet = .journey }
                    )
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                case .account:
                    AccountSheet()
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                case .journey:
                    JourneySheet()
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private var mapLightWash: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.34),
                    Color.clear,
                    Color.white.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color(mapHex: 0xBFE7F3).opacity(0.18), Color.clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 260
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var websiteHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(mapHex: 0xFF5A1F))
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            Text("MAPS.TOCTRUONGBIKER.COM")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(0.35)
                .foregroundStyle(Color(mapHex: 0x1F2937))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            Button {
                activeSheet = .menu
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color(mapHex: 0x111827))
                    .frame(width: 38, height: 38)
                    .background(Color(mapHex: 0xF8FAFC), in: Circle())
            }
            .accessibilityLabel("Mở menu")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(height: 54)
        .background(Color.white.opacity(0.96), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 8)
    }

    private var searchPanel: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(mapHex: 0x64748B))

            Text("Tìm địa điểm, đường, quận...")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(mapHex: 0x6B7280))
                .lineLimit(1)

            Spacer(minLength: 8)

            Rectangle()
                .fill(Color(mapHex: 0xE5E7EB))
                .frame(width: 1, height: 30)

            Button {
                if let coordinate = locationManager.coordinate {
                    centerCoordinate = coordinate
                } else {
                    locationManager.request()
                }
            } label: {
                Image(systemName: "location.north.line.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color(mapHex: 0x2F80ED))
                    .frame(width: 34, height: 38)
            }
            .accessibilityLabel("Tìm đường hoặc định vị")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 54)
        .background(Color.white.opacity(0.96), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 8)
    }

    private var rightWebsiteControls: some View {
        VStack(spacing: 13) {
            Button {
                if let coordinate = locationManager.coordinate {
                    centerCoordinate = coordinate
                } else {
                    locationManager.request()
                }
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Color(mapHex: 0x2F80ED))
                    .frame(width: 54, height: 54)
                    .background(Color.white.opacity(0.96), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 7)
            }
            .accessibilityLabel("Vị trí của tôi")

            Button {
                activeSheet = .hazardPin
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 16, weight: .black))
                    Text("Ghim")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color(mapHex: 0xD97706))
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.97), in: Circle())
                .overlay(Circle().stroke(Color(mapHex: 0xFDE8C7), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 6)
            }
            .accessibilityLabel("Ghim cảnh báo")

            Button {
                activeSheet = .sos
            } label: {
                VStack(spacing: -2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .black))
                    Text("SOS")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(colors: [Color(mapHex: 0xFF3347), Color(mapHex: 0xD60000)], startPoint: .top, endPoint: .bottom),
                    in: Circle()
                )
                .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 1.5))
                .shadow(color: Color(mapHex: 0xD60000).opacity(0.38), radius: 18, x: 0, y: 8)
            }
            .accessibilityLabel("SOS khẩn cấp")
        }
    }

    private var pingStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color(mapHex: 0x10B981))
                    .frame(width: 10, height: 10)
                Text("0")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(mapHex: 0x00A980))
                Text("người đang ping")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(mapHex: 0x374151))
            }

            Text(authStore.isLoggedIn ? "Vị trí đang sẵn sàng để chia sẻ với cộng đồng." : "Bạn cần đăng nhập để chia sẻ vị trí trực tiếp.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(mapHex: 0x8A94A3))
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: 306, alignment: .leading)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.9), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(mapHex: 0xFBBF24))
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(12)
        .background(Color(mapHex: 0x7F1D1D).opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12)))
    }
}

private struct CategoryChip: View {
    let category: HazardCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: category.icon)
                    .font(.caption.weight(.black))
                Text(category.title)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(isSelected ? Color(mapHex: 0x07111F) : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? category.color : Color(mapHex: 0x0F172A).opacity(0.70), in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.white.opacity(0.0) : Color.white.opacity(0.12)))
            .shadow(color: isSelected ? category.color.opacity(0.35) : .clear, radius: 14, y: 7)
        }
    }
}

private struct StatPill: View {
    let value: String
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.black))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: -1) {
                Text(value)
                    .font(.headline.monospacedDigit().weight(.black))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ActionPill: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.10)))
        }
    }
}

private struct RoundIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18)))
                .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        }
    }
}

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.20), radius: 24, y: 12)
    }
}

struct HazardPinSheet: View {
    @Environment(\.dismiss) private var dismiss
    let coordinate: CLLocationCoordinate2D
    @State private var title = ""
    @State private var selectedType = hazardCategories[1].title
    @State private var severity = "Trung bình"
    @State private var note = ""

    private let severities = ["Nhẹ", "Trung bình", "Nghiêm trọng", "Khẩn cấp"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        icon: "pin.fill",
                        title: "Ghim cảnh báo",
                        subtitle: "Đặt ghim tại tâm bản đồ để cộng đồng biker né rủi ro.",
                        color: Color(mapHex: 0xF59E0B)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Loại cảnh báo")
                            .sheetLabel()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                            ForEach(hazardCategories.filter { $0.title != "Tất cả" }) { category in
                                Button {
                                    selectedType = category.title
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: category.icon)
                                            .foregroundStyle(category.color)
                                        Text(category.title)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(
                                        selectedType == category.title ? category.color.opacity(0.16) : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedType == category.title ? category.color : Color.clear, lineWidth: 1.5)
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nội dung")
                            .sheetLabel()
                        TextField("Tiêu đề ngắn gọn", text: $title)
                            .textFieldStyle(.roundedBorder)
                        Picker("Mức độ", selection: $severity) {
                            ForEach(severities, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        TextField("Mô tả thêm, hướng đi an toàn...", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.roundedBorder)
                    }

                    CoordinateCard(coordinate: coordinate)

                    Text("Starter hiện có API checkin; phần gửi ghim/SOS được thiết kế sẵn giao diện để nối endpoint WordPress khi backend bổ sung.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(18)
            }
            .navigationTitle("Ghim cảnh báo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu nháp") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

struct SOSSheet: View {
    @Environment(\.dismiss) private var dismiss
    let coordinate: CLLocationCoordinate2D
    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                SheetHero(
                    icon: "sos",
                    title: "SOS khẩn cấp",
                    subtitle: "Gửi vị trí hiện tại cho nhóm cứu hộ và chuẩn bị gọi khẩn cấp.",
                    color: Color(mapHex: 0xEF4444)
                )

                HStack(spacing: 12) {
                    SOSQuickAction(title: "Gọi 115", icon: "phone.fill", color: Color(mapHex: 0xEF4444), url: URL(string: "tel:115"))
                    SOSQuickAction(title: "Cứu hộ xe", icon: "wrench.and.screwdriver.fill", color: Color(mapHex: 0xF59E0B), url: nil)
                }

                TextField("Bạn cần hỗ trợ gì?", text: $note, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)

                CoordinateCard(coordinate: coordinate)

                Button {
                    dismiss()
                } label: {
                    Label("Gửi tín hiệu SOS", systemImage: "paperplane.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(
                            LinearGradient(colors: [Color(mapHex: 0xFF2D55), Color(mapHex: 0x991B1B)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                }

                Spacer()
            }
            .padding(18)
            .navigationTitle("SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

struct MainMenuSheet: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var syncEngine: SyncEngine
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: String
    let openAccount: () -> Void
    let openCheckin: () -> Void
    let openJourney: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(mapHex: 0xFF5A1F))
                            .frame(width: 54, height: 54)
                            .overlay(
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.white)
                                    .font(.title2.weight(.black))
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(authStore.user?.displayName ?? "Bạn chưa đăng nhập.")
                                .font(.headline.weight(.black))
                                .foregroundStyle(Color(mapHex: 0x111827))
                            Text(authStore.user?.email ?? "Đăng nhập để checkin, chia sẻ vị trí và đồng bộ hành trình.")
                                .font(.subheadline)
                                .foregroundStyle(Color(mapHex: 0x6B7280))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(mapHex: 0xF8FAFC), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(spacing: 10) {
                        MenuActionRow(title: "Tài khoản", subtitle: authStore.isLoggedIn ? "Xem profile và đăng xuất" : "Đăng nhập / đăng ký nhanh", icon: "person.crop.circle.fill", color: Color(mapHex: 0x2F80ED), action: openAccount)
                        MenuActionRow(title: "Checkin", subtitle: "Lưu điểm đã ghé và ghi chú cung đường", icon: "camera.fill", color: Color(mapHex: 0xF97316), action: openCheckin)
                        MenuActionRow(title: "Hành trình", subtitle: "Các cung đường bạn đã đi & khoảnh khắc", icon: "point.topleft.down.curvedto.point.bottomright.up", color: Color(mapHex: 0x10B981), action: openJourney)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Danh mục cảnh báo")
                            .sheetLabel()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                            ForEach(hazardCategories) { category in
                                Button {
                                    selectedCategory = category.title
                                } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: category.icon)
                                        Text(category.title)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(selectedCategory == category.title ? .white : Color(mapHex: 0x334155))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .background(selectedCategory == category.title ? category.color : Color(mapHex: 0xF1F5F9), in: Capsule())
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Button {
                        Task { await syncEngine.sync() }
                        dismiss()
                    } label: {
                        Label("Đồng bộ dữ liệu", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    if authStore.isLoggedIn {
                        Button(role: .destructive) {
                            authStore.logout()
                            dismiss()
                        } label: {
                            Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(18)
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

private struct MenuActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(Color(mapHex: 0x111827))
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(mapHex: 0x6B7280))
                        .lineLimit(2)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color(mapHex: 0x94A3B8))
            }
            .padding(13)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(mapHex: 0xE5E7EB), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct AccountSheet: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var syncEngine: SyncEngine
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        icon: authStore.isLoggedIn ? "person.crop.circle.fill" : "lock.fill",
                        title: authStore.isLoggedIn ? "Tài khoản biker" : "Đăng nhập",
                        subtitle: authStore.isLoggedIn ? "Thông tin đồng bộ từ website Maps Biker." : "Đăng nhập tài khoản website để checkin, chia sẻ vị trí trực tiếp và lưu hành trình.",
                        color: Color(mapHex: 0xFF5A1F)
                    )

                    if authStore.isLoggedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(authStore.user?.displayName ?? "Biker", systemImage: "person.fill")
                                .font(.headline.weight(.black))
                            Label(authStore.user?.email ?? "Email chưa đồng bộ", systemImage: "envelope.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))

                        Button(role: .destructive) {
                            authStore.logout()
                            dismiss()
                        } label: {
                            Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Email hoặc tên đăng nhập")
                                .sheetLabel()
                            TextField("Email hoặc username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)

                            Text("Mật khẩu")
                                .sheetLabel()
                            SecureField("Mật khẩu", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }

                        if let message = authStore.errorMessage {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(mapHex: 0xB91C1C))
                                .padding(12)
                                .background(Color(mapHex: 0xFEE2E2), in: RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            Task {
                                await authStore.login(username: username, password: password)
                                if authStore.isLoggedIn {
                                    await syncEngine.sync()
                                }
                            }
                        } label: {
                            HStack {
                                if authStore.isBusy {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                Text(authStore.isBusy ? "Đang đăng nhập..." : "Đăng nhập")
                                    .fontWeight(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(mapHex: 0xFF5A1F))
                        .disabled(username.isEmpty || password.isEmpty || authStore.isBusy)

                        Text("Đăng ký nhanh vẫn dùng luồng website; app đã chuẩn bị màn đăng nhập để đồng bộ token hiện có.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
            }
            .navigationTitle("Tài khoản")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

struct JourneySheet: View {
    @EnvironmentObject private var syncEngine: SyncEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        icon: "point.topleft.down.curvedto.point.bottomright.up",
                        title: "Hành trình",
                        subtitle: "Các cung đường bạn đã đi & khoảnh khắc kỉ niệm.",
                        color: Color(mapHex: 0x10B981)
                    )

                    if let tourURL = URL(string: "https://maps.toctruongbiker.com/tao-video-tour") {
                        Link(destination: tourURL) {
                            Label("Tạo Video Tour", systemImage: "video.fill")
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color(mapHex: 0x111827), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Chi tiết cung đường (A → B → C...)")
                            .sheetLabel()

                        if syncEngine.journey.isEmpty {
                            EmptyStateLine(text: "Chưa có cung đường nào. Hãy checkin điểm đầu tiên!")
                        } else {
                            ForEach(Array(syncEngine.journey.enumerated()), id: \.element.id) { index, point in
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.monospacedDigit().weight(.black))
                                        .foregroundStyle(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Color(mapHex: 0x10B981), in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(point.title)
                                            .font(.subheadline.weight(.bold))
                                        Text("\(point.lat, specifier: "%.5f"), \(point.lng, specifier: "%.5f")")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Khoảnh khắc đã ghé")
                            .sheetLabel()

                        if syncEngine.checkins.isEmpty {
                            EmptyStateLine(text: "Bạn chưa có điểm nào. Hãy checkin điểm đầu tiên!")
                        } else {
                            ForEach(syncEngine.checkins) { checkin in
                                HStack(spacing: 10) {
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(Color(mapHex: 0xF97316))
                                        .frame(width: 32, height: 32)
                                        .background(Color(mapHex: 0xF97316).opacity(0.12), in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(checkin.title)
                                            .font(.subheadline.weight(.bold))
                                        Text(checkin.description ?? "Không có ghi chú")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }
                .padding(18)
            }
            .navigationTitle("Hành trình")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

private struct EmptyStateLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SheetHero: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(color, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: color.opacity(0.32), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.black))
                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CoordinateCard: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tọa độ")
                .sheetLabel()
            HStack {
                Label("\(coordinate.latitude, specifier: "%.6f")", systemImage: "location.north.line.fill")
                Spacer()
                Label("\(coordinate.longitude, specifier: "%.6f")", systemImage: "location.north.fill")
            }
            .font(.caption.monospacedDigit().weight(.bold))
            .foregroundStyle(.secondary)
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct SOSQuickAction: View {
    let title: String
    let icon: String
    let color: Color
    let url: URL?

    var body: some View {
        Group {
            if let url {
                Link(destination: url) { content }
            } else {
                Button(action: {}) { content }
            }
        }
    }

    private var content: some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.black))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }
}

extension Text {
    func sheetLabel() -> some View {
        self
            .font(.caption.weight(.black))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private extension Color {
    init(mapHex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((mapHex >> 16) & 0xFF) / 255,
            green: Double((mapHex >> 8) & 0xFF) / 255,
            blue: Double(mapHex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
