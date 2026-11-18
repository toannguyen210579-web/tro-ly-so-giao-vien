# Trợ lý số Giáo viên: hướng dẫn chạy thử trên máy Mac (bản khung, 17/11/2026)

Bộ mã này gồm **khung app và 4 tiện ích bản đầu**:
- **Nhận xét học sinh:** tạo lớp bằng cách dán danh sách tên; chọn mức theo Thông tư 27 hoặc Thông tư 22; điền nhận xét mẫu hoặc **Nhờ AI viết nhận xét** (chỉ gửi mã HS01, HS02… và mức, không gửi tên); nhập điểm để tính điểm trung bình môn học kỳ; chép cả lớp sang Excel.
- **Nhắn phụ huynh:** 6 mẫu tin, **Nhờ AI soạn tin**, điền tên học sinh ngay trên máy, chép hoặc gửi qua Zalo.
- **Quét PDF:** quét nhiều trang, tự nhận mép giấy, đổi thứ tự, gộp thành PDF, gửi đi.
- **Ảnh thẻ:** chụp hoặc chọn ảnh, tách nền ngay trên máy, nền xanh hoặc trắng, cỡ 3x4 (tờ in 8 ảnh) hoặc 4x6 (tờ in 3 ảnh), khổ giấy ảnh 10x15 cm.

Phần khung gồm:
- Trang chủ: ô "Thầy cô cần làm gì?", nhóm Hành chính, nhóm Chuyên môn, thẻ hạn, mục tin.
- Màn "Tất cả tiện ích".
- Màn **Hỏi Trợ lý** có nút **Báo cáo**.
- Mã máy chủ trung gian (thư mục `server`).

Khi chưa nối máy chủ, Hỏi Trợ lý chạy **chế độ thử**: trả lời mẫu, không tốn tiền. Các tiện ích chưa làm xong sẽ mở màn "Sắp có".

## 1. Cài công cụ (làm một lần)
1. **Xcode:** mở App Store trên Mac, tìm "Xcode", bấm Cài. Cài xong mở Xcode một lần để đồng ý điều khoản.
2. **Flutter:** làm theo hướng dẫn chính thức cho macOS tại https://docs.flutter.dev/get-started/install/macos. Cài xong, mở Terminal và gõ `flutter doctor` để kiểm tra.
3. **Android Studio** (để ra bản Android): tải tại https://developer.android.com/studio. Mở lên một lần để nó tự cài bộ Android SDK.

## 2. Tạo dự án và chép mã vào
Mở Terminal, chạy lần lượt:

```
cd ~/Desktop
flutter create --org vn.vietnamtieudiem --project-name tro_ly_so_giao_vien tro_ly_so_giao_vien
```

Sau đó chép **thư mục `lib` và tệp `pubspec.yaml`** trong gói này vào thư mục `~/Desktop/tro_ly_so_giao_vien`, chọn **thay thế** khi được hỏi. Rồi chạy:

```
cd ~/Desktop/tro_ly_so_giao_vien
flutter pub get
```

## 2b. Khai báo quyền dùng máy ảnh, ảnh (bắt buộc cho Quét PDF và Ảnh thẻ)
**iPhone:** mở tệp `ios/Runner/Info.plist`, thêm vào trước dòng `</dict>` cuối cùng:
```
<key>NSCameraUsageDescription</key>
<string>Dùng máy ảnh để quét giấy tờ và chụp ảnh thẻ.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Chọn ảnh có sẵn để làm ảnh thẻ.</string>
```
Mở tệp `ios/Podfile`, sửa dòng `# platform :ios, ...` thành `platform :ios, '15.5'` (bỏ dấu # ở đầu).

**Android:** mở `android/app/build.gradle` (hoặc `build.gradle.kts`), tìm `minSdk` và đặt là `21` nếu đang thấp hơn.

## 3. Chạy thử
- **Trên máy iPhone giả lập:** `open -a Simulator`, rồi `flutter run`.
- **Trên iPhone thật:** cắm cáp vào Mac, rồi `flutter run`. Lần đầu Xcode sẽ hỏi tài khoản Apple để ký app.
- **Ra tệp cài Android (APK):** `flutter build apk`. Tệp nằm ở `build/app/outputs/flutter-apk/app-release.apk`. Gửi tệp đó sang điện thoại Android để cài.

Lưu ý: **Ảnh thẻ và Quét PDF cần máy thật** (iPhone hoặc Android thật), máy giả lập không có máy ảnh và không chạy được phần tách nền.

Gặp lỗi ở bước nào, thầy cô chụp màn hình Terminal gửi Claude.

## 4. Nối AI thật (làm sau, khi khung app đã chạy)
1. Tạo tài khoản Cloudflare (miễn phí).
2. Trong Terminal, vào thư mục `server` của gói này và chạy:
   ```
   npx wrangler login
   npx wrangler kv namespace create LUOT
   ```
   Lệnh thứ hai in ra một ID. Chép ID đó vào tệp `wrangler.toml`, thay chỗ `THAY_BANG_ID_KHO_LUOT`.
3. Đặt khóa API:
   - Chạy `npx wrangler secret put ANTHROPIC_API_KEY`.
   - Dán khóa API tạo ở Claude Console (mục Get API key) vào **Terminal**.
   - **Không dán khóa vào khung chat.**
4. Chạy `npx wrangler deploy`. Lệnh in ra một địa chỉ dạng `https://tro-ly-so-giao-vien.<tên>.workers.dev`.
5. Mở `lib/services/tro_ly_api.dart`, điền địa chỉ đó vào `diaChiMayChu`, rồi chạy lại app.

Giới hạn hiện đặt trong `server/worker.js`:
- Hỏi Trợ lý: 5 câu mỗi máy mỗi ngày.
- Viết nhận xét: 30 lượt.
- Soạn tin phụ huynh: 20 lượt.

Hết 100 USD tặng kèm thì máy chủ báo "Trợ lý đang tạm nghỉ" và không trừ lượt của thầy cô.
