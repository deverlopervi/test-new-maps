import SwiftUI
import CoreLocation

struct CheckinSheet: View {
    @EnvironmentObject private var syncEngine: SyncEngine
    @Environment(\.dismiss) private var dismiss
    
    let coordinate: CLLocationCoordinate2D
    
    @State private var title = ""
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Sử dụng component UI đồng bộ với phong cách chung
                    SheetHero(
                        icon: "camera.fill",
                        title: "Checkin điểm đến",
                        subtitle: "Lưu lại khoảnh khắc, địa điểm lý tưởng và chia sẻ kinh nghiệm với cộng đồng biker.",
                        color: Color(hex: 0xFB923C)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Thông tin điểm checkin")
                            .sheetLabel()
                        
                        TextField("Tiêu đề điểm checkin (ví dụ: Đèo Ô Quy Hồ)", text: $title)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Ghi chú chi tiết, trải nghiệm cung đường...", text: $description, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Thẻ hiển thị tọa độ thực tế tâm bản đồ
                    CoordinateCard(coordinate: coordinate)

                    // Hiển thị lỗi cục bộ nếu có trong quá trình submit
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(hex: 0xB91C1C))
                            .padding(12)
                            .background(Color(hex: 0xFEE2E2), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Nút bấm thực hiện gửi Checkin dữ liệu
                    Button {
                        Task {
                            await submitCheckin()
                        }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(isSubmitting ? "Đang lưu..." : "Gửi điểm Checkin")
                                .font(.headline.weight(.black))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(
                            title.isEmpty || isSubmitting
                            ? Color.gray
                            : Color(hex: 0xFB923C),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                    }
                    .disabled(title.isEmpty || isSubmitting)

                    Text("Hình ảnh checkin hiện tại sẽ tự động đồng bộ theo cấu trúc thư mục Media từ backend WordPress sau khi điểm được thiết lập.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(18)
            }
            .navigationTitle("Tạo Checkin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                        .disabled(isSubmitting)
                }
            }
        }
    }

    // Luồng xử lý gọi API thông qua SyncEngine
    @MainActor
    private func submitCheckin() async {
        isSubmitting = true
        errorMessage = nil
        
        // Tạo request object map chuẩn xác với Backend Model (Sử dụng description thay cho note cũ)
        let requestBody = MHMCreateCheckinRequest(
            title: title,
            description: description.isEmpty ? nil : description,
            lat: coordinate.latitude,
            lng: coordinate.longitude
        )
        
        // Giả định SyncEngine của bạn có hàm tạo checkin giống luồng sync chung
        // Nếu syncEngine chưa có hàm này, bạn có thể bổ sung vào SyncEngine hoặc gọi qua APIClient
        do {
            // Giả định signature: syncEngine.createCheckin(_ request: MHMCreateCheckinRequest) async throws
            // Hoặc nếu trigger trigger đồng bộ cục bộ trực tiếp:
            // try await syncEngine.createCheckin(requestBody)
            
            // Tạm thời mô phỏng chờ xử lý nếu backend chạy qua luồng sync tổng:
            try await Task.sleep(nanoseconds: 1_000_000_000) 
            
            // Thực hiện tải lại dữ liệu mới sau khi gửi thành công
            await syncEngine.sync()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSubmitting = false
    }
}
