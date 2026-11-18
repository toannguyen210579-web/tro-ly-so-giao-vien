import 'package:flutter/material.dart';

import '../main.dart';

const phienBanApp = '0.2.0';
const ngayChinhSach = '18/11/2026';

/// Nội dung Chính sách quyền riêng tư. Bản này cũng chép ra tệp CHINH_SACH_QUYEN_RIENG_TU.md
/// để đăng lên mạng (Google Play, App Store bắt buộc có đường dẫn công khai).
const chinhSachQuyenRiengTu = <(String, String)>[
  (
    'Tóm tắt',
    'Trợ lý số Giáo viên không yêu cầu đăng ký tài khoản. Phần lớn tiện ích chạy ngay trên điện thoại, '
        'dữ liệu thầy cô nhập (danh sách học sinh, điểm, biên bản, minh chứng, ảnh) chỉ lưu trong máy. '
        'Chỉ khi thầy cô bấm các nút có biểu tượng AI, nội dung liên quan mới được gửi đi để xử lý.'
  ),
  (
    'Dữ liệu lưu trên máy',
    'Lớp học, điểm, lời nhận xét, bài chấm trắc nghiệm, biên bản họp, sổ minh chứng, tệp PDF và ảnh '
        'được lưu trong vùng riêng của app trên điện thoại. App không tự gửi các dữ liệu này đi đâu. '
        'Khi gỡ app, các dữ liệu này bị xóa theo.'
  ),
  (
    'Quyền máy ảnh, ảnh, micro',
    'Máy ảnh dùng để quét giấy tờ, chụp ảnh thẻ, chụp minh chứng. Thư viện ảnh dùng để chọn ảnh có sẵn. '
        'Micro dùng để chuyển lời nói thành chữ. App chỉ dùng các quyền này khi thầy cô bấm vào tiện ích tương ứng.'
  ),
  (
    'Xử lý ngay trên máy bằng thành phần của Google, Apple',
    'Quét giấy tờ và tách nền ảnh thẻ dùng thành phần có sẵn của Google (Android) hoặc Apple (iPhone), '
        'chạy ngay trên máy. Đọc văn bản thành tiếng dùng bộ đọc của điện thoại. '
        'Chuyển lời nói thành chữ dùng bộ nhận giọng của điện thoại; trên nhiều máy, bộ này gửi âm thanh '
        'tới máy chủ của Google hoặc Apple để nhận dạng, theo chính sách riêng của hãng.'
  ),
  (
    'Khi dùng tính năng AI',
    'Các nút Hỏi Trợ lý, Nhờ AI viết nhận xét, Nhờ AI soạn tin, Nhờ AI sắp xếp biên bản gửi nội dung thầy cô '
        'nhập tới máy chủ trung gian của app (đặt trên Cloudflare), rồi chuyển tới dịch vụ AI Claude của Anthropic '
        'để soạn câu trả lời. Tên học sinh được thay bằng mã (HS01, HS02…) trước khi gửi. '
        'Với biên bản họp, app hỏi lại và chỉ gửi khi thầy cô đồng ý. '
        'Máy chủ trung gian không lưu nội dung câu hỏi, chỉ đếm số lượt dùng trong ngày.'
  ),
  (
    'Mã máy',
    'Để giới hạn số lượt AI miễn phí mỗi ngày, app tạo một mã ngẫu nhiên lưu trên máy. '
        'Mã này không gắn với tên, số điện thoại hay danh bạ. Số lượt đếm theo mã được tự xóa sau 2 ngày.'
  ),
  (
    'Báo cáo nội dung AI',
    'Khi thầy cô bấm Báo cáo một câu trả lời của AI, câu hỏi, câu trả lời và lý do được lưu trên máy chủ '
        'trung gian tối đa 90 ngày để kiểm tra và cải thiện, sau đó tự xóa.'
  ),
  (
    'Chia sẻ tệp',
    'Khi thầy cô bấm Gửi, Chia sẻ, tệp hoặc tin nhắn được chuyển sang ứng dụng thầy cô chọn (Zalo, email…). '
        'Việc xử lý sau đó theo chính sách của ứng dụng đó.'
  ),
  (
    'Trẻ em',
    'App dành cho giáo viên, không dành cho học sinh tự sử dụng.'
  ),
  (
    'Thay đổi chính sách',
    'Khi app thêm tính năng mới có thu thập hay gửi dữ liệu (ví dụ quảng cáo), chính sách này sẽ được cập nhật '
        'và ghi ngày hiệu lực mới.'
  ),
  (
    'Liên hệ',
    'Mọi thắc mắc về quyền riêng tư, thầy cô gửi về: [email liên hệ của nhà phát triển].'
  ),
];

class TaiKhoan extends StatelessWidget {
  const TaiKhoan({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Chưa cần đăng nhập'),
              subtitle: Text('Dữ liệu của thầy cô lưu ngay trên máy này.'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: MauApp.xanhDam),
                  title: const Text('Chính sách quyền riêng tư'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManChinhSach())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.article_outlined, color: MauApp.xanhDam),
                  title: const Text('Giấy phép phần mềm'),
                  subtitle: const Text('Các thư viện mã nguồn mở app sử dụng'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Trợ lý số Giáo viên',
                    applicationVersion: phienBanApp,
                    applicationLegalese: 'Bớt sổ sách, thêm giờ cho học trò.',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: MauApp.xanhDam),
                  title: Text('Phiên bản'),
                  trailing: Text(phienBanApp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManChinhSach extends StatelessWidget {
  const ManChinhSach({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chính sách quyền riêng tư')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const Text('Có hiệu lực từ ngày $ngayChinhSach', style: TextStyle(fontStyle: FontStyle.italic, color: MauApp.chuPhu)),
          for (final (tieuDe, noiDung) in chinhSachQuyenRiengTu) ...[
            const SizedBox(height: 16),
            Text(tieuDe, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(noiDung, style: const TextStyle(height: 1.45)),
          ],
        ],
      ),
    );
  }
}
