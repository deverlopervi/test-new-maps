import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var syncEngine: SyncEngine
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let apiClient = APIClient()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Mule Hazard Map")
                    .font(.title).bold()
                
                VStack(spacing: 12) {
                    TextField("Tên đăng nhập hoặc Email", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Mật khẩu", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Button(action: login) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Đăng nhập")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading || username.isEmpty || password.isEmpty)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Đăng nhập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
            }
        }
    }
    
    private func login() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiClient.login(username: username, password: password)
                // Cấu hình lưu trữ trực tiếp từ model response phẳng (flat data)
                await authStore.saveSession(
                    nonce: response.nonce,
                    displayName: response.displayName,
                    email: response.email ?? ""
                )
                await syncEngine.sync()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
