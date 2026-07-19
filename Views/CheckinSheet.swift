import SwiftUI
import CoreLocation

struct CheckinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncEngine: SyncEngine
    let coordinate: CLLocationCoordinate2D

    @State private var title = ""
    @State private var note = ""
    @State private var mood = "Đang chạy"

    private let moods = ["Đang chạy", "Cafe", "Đổ xăng", "Nghỉ chân"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        icon: "camera.fill",
                        title: "Checkin cung đường",
                        subtitle: "Lưu điểm dừng, ghi chú nhanh và chia sẻ trạng thái với cộng đồng.",
                        color: Color(hex: 0xF97316)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Trạng thái")
                            .sheetLabel()
                        Picker("Trạng thái", selection: $mood) {
                            ForEach(moods, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nội dung checkin")
                            .sheetLabel()
                        TextField("Tên địa điểm hoặc điểm dừng", text: $title)
                            .textFieldStyle(.roundedBorder)
                        TextField("Ghi chú cho biker khác...", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: {}) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Thêm ảnh sau")
                            Spacer()
                            Text("Coming soon")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(14)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }

                    CoordinateCard(coordinate: coordinate)
                }
                .padding(18)
            }
            .navigationTitle("Tạo checkin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đăng") {
                        Task {
                            // Refactor: Đổi parameter truyền vào từ 'note' thành 'description' để khớp với API Request mới
                            await syncEngine.createCheckin(
                                title: title.isEmpty ? mood : title,
                                description: note.isEmpty ? nil : "[\(mood)] \(note)", // Đã là description
                                coordinate: coordinate
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.black)
                }
            }
        }
    }
}
