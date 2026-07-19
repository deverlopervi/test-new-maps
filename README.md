# Mule Hazard Map iOS (Maps Biker)

SwiftUI app đồng bộ dữ liệu website Mule Hazard Map qua REST API + hiển thị bản đồ MapKit.

## Build tự động trên GitHub Actions (không cần Mac)

Repo có sẵn workflow `.github/workflows/ios-build.yml`. Chỉ cần push code lên GitHub:

1. Push toàn bộ code (kể cả `project.yml`, `Config/Config.xcconfig`, `Resources/`, `.github/`).
2. Vào tab **Actions** → workflow **Build iOS App** sẽ chạy trên `macos-14` runner.
3. Tải file `.app` (đóng gói zip) ở mục **Artifacts** của workflow run.

### (Tùy chọn) Secret cho CI

**Settings → Secrets and variables → Actions → New repository secret**:

- `MHM_API_BASE_URL` — vd `https://your-domain.com/wp-json/mhm/v1`
- `GOONG_API_KEY` — key Goong Maps

Nếu không set, CI vẫn build được bằng giá trị mặc định trong `Config/Config.xcconfig`.

> Workflow build **unsigned cho iOS Simulator**. Muốn có IPA cài iPhone thật / lên TestFlight cần cert + provisioning profile (xem mục cuối).

## Build local trên Mac

```bash
brew install xcodegen        # nếu chưa có
./scripts/build.sh           # generate .xcodeproj + build
open MuleHazardMap.xcodeproj # chạy Simulator hoặc thiết bị thật
```

## Cấu trúc project

```
MuleHazardMapIOS/
├── App/            # entry point, AppConfig
├── Models/         # data models
├── Services/       # API, Auth, Sync, Goong, Keychain
├── Views/          # SwiftUI + MapKit views
├── Resources/
│   ├── Assets.xcassets     # AppIcon, AccentColor
│   └── LaunchScreen.storyboard
├── Config/
│   ├── Config.xcconfig     # bundle id + env keys
│   └── Info.plist          # backup
├── project.yml     # XcodeGen spec
├── scripts/build.sh
└── .github/workflows/ios-build.yml
```

## API website đang gọi

- `POST /mobile/login`
- `GET /mobile/sync?since=...`
- `POST /checkins`

Base URL ví dụ: `https://domain.com/wp-json/mhm/v1`.

## Build IPA & TestFlight

Yêu cầu Apple Developer Program (99 USD/năm):

1. Sửa `DEVELOPMENT_TEAM` trong `project.yml` sang Team ID.
2. Đổi `PRODUCT_BUNDLE_IDENTIFIER` trong `Config/Config.xcconfig` sang bundle id đã đăng ký.
3. Trên Mac (Xcode + Apple ID): `xcodegen generate` → chọn signing team → Archive → upload TestFlight.

## File build bổ sung

| File | Vai trò |
|---|---|
| `project.yml` | XcodeGen sinh `MuleHazardMap.xcodeproj` |
| `Config/Config.xcconfig` | Bundle id + env keys thật |
| `Resources/Assets.xcassets/` | AppIcon + AccentColor (bắt buộc) |
| `Resources/LaunchScreen.storyboard` | Splash screen (bắt buộc) |
| `.github/workflows/ios-build.yml` | CI build unsigned trên macOS runner |
| `scripts/build.sh` | Build nhanh trên Mac |
