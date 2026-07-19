import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                loginBackdrop

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer(minLength: 28)
                        brandHero
                        loginCard
                        communityStrip
                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var loginBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x07111F), Color(hex: 0x111827), Color(hex: 0x3B1D0A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: 0xF97316).opacity(0.26))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: 140, y: -260)

            Circle()
                .fill(Color(hex: 0x38BDF8).opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: -150, y: 270)

            GridPattern()
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
                .ignoresSafeArea()
        }
    }

    private var brandHero: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 98, height: 98)
                    .overlay(RoundedRectangle(cornerRadius: 34).stroke(Color.white.opacity(0.16)))

                Image(systemName: "motorcycle.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0xFBBF24), Color(hex: 0xFB5607)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: Color(hex: 0xFB5607).opacity(0.34), radius: 28, y: 16)

            VStack(spacing: 7) {
                Text("Maps Biker")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Bản đồ cảnh báo, checkin và cứu hộ dành cho cộng đồng motor.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
    }

    private var loginCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Đăng nhập tài khoản")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
                Text("Dùng tài khoản website để đồng bộ ghim, checkin và hành trình.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LoginField(
                icon: "person.fill",
                placeholder: "Username hoặc email",
                text: $username,
                isSecure: false
            )
            .focused($focusedField, equals: .username)
            .textContentType(.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            LoginField(
                icon: "lock.fill",
                placeholder: "Mật khẩu",
                text: $password,
                isSecure: true
            )
            .focused($focusedField, equals: .password)
            .textContentType(.password)

            if let message = authStore.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(hex: 0xFCA5A5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(hex: 0x7F1D1D).opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
            }

            Button {
                focusedField = nil
                Task { await authStore.login(username: username, password: password) }
            } label: {
                HStack(spacing: 10) {
                    if authStore.isBusy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    Text(authStore.isBusy ? "Đang đăng nhập..." : "Vào bản đồ")
                        .fontWeight(.black)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0xFFB703), Color(hex: 0xFB5607)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: Color(hex: 0xFB5607).opacity(0.36), radius: 18, y: 10)
            }
            .disabled(username.isEmpty || password.isEmpty || authStore.isBusy)
            .opacity(username.isEmpty || password.isEmpty ? 0.55 : 1)

            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                Text("Token lưu trong Keychain của iOS.")
                Spacer()
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.16)))
        .shadow(color: .black.opacity(0.30), radius: 28, y: 18)
    }

    private var communityStrip: some View {
        HStack(spacing: 10) {
            LoginMetric(value: "SOS", title: "khẩn cấp", color: Color(hex: 0xEF4444))
            LoginMetric(value: "Pin", title: "cảnh báo", color: Color(hex: 0xF59E0B))
            LoginMetric(value: "Ride", title: "hành trình", color: Color(hex: 0x38BDF8))
        }
    }
}

private struct LoginField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(hex: 0xFBBF24))
                .frame(width: 28)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .foregroundStyle(.white)
            .font(.body.weight(.semibold))
        }
        .padding(15)
        .background(Color(hex: 0x0F172A).opacity(0.58), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))
    }
}

private struct LoginMetric: View {
    let value: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10)))
    }
}

private struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 34
        var x: CGFloat = 0
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        return path
    }
}
