# Hồ sơ đưa app lên Google Play và App Store (bản 0.4.0, soạn 22/11/2026, sửa mục ảnh 24/11/2026, thêm Dịch tài liệu, Biên bản chụp ảnh, Tạo bài trình chiếu 26/11/2026)

Bản trong kho mã của tài liệu Project `claude/ho-so-len-kho-ung-dung.md` (chép vào ngày 26/11/2026, thay bản 0.3.0 cũ). Workflow `gan_ban_app_store.yml` (ô mo_ta = co) lấy mô tả đầy đủ và từ khóa App Store ở mục A của tệp này, nên giữ nguyên tiêu đề "### Mô tả đầy đủ" (mô tả nằm trong khối ```) và "### Từ khóa App Store" (từ khóa ở dòng đầu sau tiêu đề).

## Tình trạng
- Google Play Console: chờ Google duyệt giấy tờ, chưa xác minh điện thoại Android, chưa xác minh số điện thoại (kiểm tra lần cuối 22/11/2026). Nút "Tạo ứng dụng" còn khóa.
- App Store Connect: trang phiên bản 0.4.0 đủ thông tin, bản 0.4.0 (9) đã gắn (26/11/2026), chưa gửi duyệt. Chi tiết: tài liệu Project `claude/tien-do-app-store.md`.

## A. Thông tin chung hai kho

| Mục | Nội dung |
| --- | --- |
| Tên app (30/30 ký tự) | Trợ lý số Giáo viên - Một chạm |
| Tên dưới biểu tượng | Trợ lý số GV |
| Mã gói Android | vn.vietnamtieudiem.tro_ly_so_giao_vien |
| Bundle ID iPhone | vn.vietnamtieudiem.troLySoGiaoVien |
| Nhà phát triển | Google Play: Nguyễn Văn Toàn - Trợ lý số GV. App Store tài khoản cá nhân hiện tên pháp lý của chủ tài khoản |
| Email hỗ trợ | hotro.trolysogv@gmail.com |
| Chính sách quyền riêng tư | https://tro-ly-gv.toannguyen210579.workers.dev/quyen-rieng-tu |
| Trang hỗ trợ | https://tro-ly-gv.toannguyen210579.workers.dev/ho-tro |
| Điều khoản sử dụng | https://tro-ly-gv.toannguyen210579.workers.dev/dieu-khoan |
| Danh mục | Giáo dục (App Store: phụ là Năng suất) |
| Giá | Miễn phí |
| Quảng cáo / mua trong app | Không / Không |
| Quốc gia | Việt Nam |
| Ngôn ngữ | Tiếng Việt (vi-VN) |
| Đối tượng | Giáo viên, từ đủ 18 tuổi (khớp Điều khoản sử dụng) |

### Mô tả ngắn Google Play (77/80 ký tự)
Trợ lý giáo viên: chấm trắc nghiệm, nhận xét, quét PDF, ảnh thẻ, biên bản họp

### Phụ đề App Store (29/30 ký tự)
Bớt sổ sách, thêm giờ dạy học

### Văn bản quảng bá App Store (155/170 ký tự, sửa lúc nào cũng được, không cần duyệt)
Bớt sổ sách, thêm giờ cho học trò. Chấm trắc nghiệm, nhận xét theo Thông tư 22, 27, quét PDF, biên bản họp, tính lương, nhắc họp chi bộ: mỗi việc một chạm.

### Từ khóa App Store
nhận xét,trắc nghiệm,chấm bài,biên bản,quét pdf,ảnh thẻ,minh chứng,trình chiếu,lương,đảng phí,chi bộ

(100/100 ký tự; bỏ chữ "giáo viên" vì đã có trong tên.)

### Mô tả đầy đủ
Dùng chung hai kho, tối đa 4.000 ký tự. So với bản 0.3.0: thêm dòng Công tác Đảng, mục Tin tức, đoạn LƯU Ý (22/11/2026); thêm Dịch tài liệu, Đánh giá xếp loại, Biên bản chụp ảnh ghi chép và ra Word, PDF, lưu tệp tại chỗ, Tạo bài trình chiếu (26/11/2026; từ khóa "thông tư 22" đổi thành "trình chiếu" vì đủ 100 ký tự). Đoạn LƯU Ý là bắt buộc theo chính sách "Tuyên bố gây hiểu lầm" của Google Play: app có thông tin về chế độ, văn bản nhà nước thì mô tả phải nói rõ app không thuộc cơ quan nhà nước và dẫn nguồn chính thức.

```
Bớt sổ sách, thêm giờ cho học trò. Thầy cô lo dạy, việc vặt để Trợ lý lo.

Trợ lý số Giáo viên gom các việc giấy tờ, chuyên môn hằng ngày của thầy cô vào một app, mỗi việc một chạm. Không cần tạo tài khoản. Dữ liệu lớp học, điểm, biên bản, minh chứng lưu ngay trên điện thoại.

VIỆC HÀNH CHÍNH
• Họp, biên bản: ghi nhanh trong lúc họp, nói để ghi, chụp ảnh trang ghi chép hoặc lấy từ tệp PDF, Word; app trình bày thành biên bản Word, PDF đúng thể thức.
• Quét PDF: chụp giấy tờ, app tự làm phẳng trang, gộp nhiều trang thành một tệp PDF gửi Zalo.
• Sổ minh chứng: chụp lưu giấy khen, giấy chứng nhận theo nhóm; đến kỳ nộp hồ sơ xuất mỗi minh chứng một tệp PDF đặt tên sẵn, gói .zip, PDF gộp hoặc danh mục Excel.
• Ảnh thẻ: tự tách nền xanh hoặc trắng, xếp ảnh 3x4, 4x6 lên tờ in 10x15.
• Giọng nói ⇄ Văn bản: dán văn bản để máy đọc thành tiếng, bấm micro để lời nói thành chữ.
• Ảnh sang Word: chụp văn bản, app nhận chữ thành tệp Word sửa được.
• Lịch, nhắc hạn: ghi việc, điện thoại nhắc trước hạn nộp.
• Tính lương: nhập hạng, bậc, năm công tác; app tính lương, phụ cấp, ngày nâng bậc.
• Đánh giá, xếp loại: tự chấm điểm tháng, quý theo Nghị định 233/2026, app cộng điểm cả năm, cho biết các kỳ còn lại cần đạt bao nhiêu, xuất phiếu xếp loại viên chức Word, PDF.
• Công tác Đảng: nhắc lịch họp chi bộ hằng tháng, tính đảng phí theo Quy định 01-QĐ/TW năm 2026, mở nhanh trang Dịch vụ công của Đảng và ứng dụng Sổ tay đảng viên, hỏi đáp về Điều lệ Đảng, sinh hoạt chi bộ, thủ tục đảng viên.

VIỆC CHUYÊN MÔN
• Nhận xét học sinh: theo Thông tư 27/2020 (tiểu học), Thông tư 22/2021 (THCS, THPT), sửa đổi bởi Thông tư 89/2026; có mức Miễn, học sinh khuyết tật; tính điểm trung bình môn; chép hoặc lưu tệp Excel cả lớp.
• Chấm trắc nghiệm: nhập đáp án nhiều mã đề, gõ nhanh hoặc chạm chọn bài làm, app chấm ngay, thống kê câu nhiều em sai.
• Giải đề, soạn đáp án: chụp đề, AI làm lời giải từng bước, đáp án, thang điểm, ra đề tương tự.
• Tạo bài trình chiếu: chọn tệp giáo án Word, PDF hoặc chụp giáo án, AI dựng bài trình chiếu theo đúng các hoạt động của bài, đáp án và lời dặn nằm ở ghi chú giáo viên; xem, sửa từng trang rồi lưu tệp PowerPoint, PDF.
• Dịch tài liệu: dán chữ, chụp trang sách, chọn tệp PDF, Word để dịch sang tiếng Việt, tiếng Anh, tiếng Trung, tiếng Nhật, tiếng Hàn, tiếng Pháp; chọn dịch sát nghĩa hoặc dễ hiểu, có bản song ngữ, ra tệp Word, PDF.
• Nhắn phụ huynh: tin mẫu lịch sự, AI soạn theo ý thầy cô, gửi qua Zalo.
• Ô chữ: tạo ô chữ ôn bài, chiếu lên lớp.
• Giơ thẻ: in thẻ cho cả lớp, chụp một tấm là biết em nào chọn đáp án nào.
• Công cụ trên lớp: gọi tên ngẫu nhiên, chia nhóm, điểm danh, đồng hồ.

Tiện ích nào tạo tệp đều có nút Mở xem, Gửi, Lưu vào máy ngay tại chỗ; các tệp đã tạo xem lại trong mục Tệp của tôi.

HỎI TRỢ LÝ
Hỏi nhanh chế độ, văn bản, chuyên môn và chuyện thường ngày; chụp bài tập để hỏi cách giải. Trợ lý tra kho văn bản quy định chuyên môn từ tiểu học đến THPT và có ghi nguồn để thầy cô đối chiếu.

TIN TỨC
Tin giáo dục, chế độ chính sách cho thầy cô, mỗi tin có tóm tắt ngắn, ghi nguồn và liên kết bài gốc; kèm clip ngắn giải thích chế độ.

RIÊNG TƯ
Tên học sinh được thay bằng mã trước khi gửi cho AI; số điện thoại, email được che. App không bán dữ liệu, không có quảng cáo.

LƯU Ý
Trợ lý số Giáo viên do cá nhân phát triển, không phải ứng dụng của cơ quan nhà nước, tổ chức Đảng hay ngành giáo dục. Mức lương, đảng phí và nội dung văn bản trong app dựa trên văn bản đã công bố; thầy cô đối chiếu tại nguồn chính thức: Hệ thống văn bản của Chính phủ (https://vanban.chinhphu.vn), Bộ Giáo dục và Đào tạo (https://moet.gov.vn), Báo điện tử Đảng Cộng sản Việt Nam (https://dangcongsan.vn).
Nội dung do AI tạo có thể sai. Thầy cô đọc lại, sửa trước khi dùng.
Mỗi tiện ích có nút "Hướng dẫn sử dụng" ghi từng bước.
```

## B. Google Play: điền theo thứ tự trên Play Console

### B1. Tạo ứng dụng (khi nút mở khóa)
- Tên: Trợ lý số Giáo viên - Một chạm. Ngôn ngữ mặc định: Tiếng Việt – vi-VN. Ứng dụng hay trò chơi: Ứng dụng. Miễn phí hay có phí: Miễn phí.
- Hai ô cam kết (Chính sách chương trình dành cho nhà phát triển; Luật xuất khẩu của Hoa Kỳ): người dùng đã đồng ý ngày 22/11/2026 cho Claude tự đánh dấu khi tạo app. Các bước đồng ý điều khoản khác vẫn phải hỏi trước.

### B2. Nội dung ứng dụng (mục "Chính sách và chương trình" → "Nội dung ứng dụng")

| Mục | Trả lời |
| --- | --- |
| Chính sách quyền riêng tư | https://tro-ly-gv.toannguyen210579.workers.dev/quyen-rieng-tu |
| Quyền truy cập ứng dụng | Mọi chức năng đều dùng được, không cần quyền truy cập đặc biệt (không có đăng nhập) |
| Quảng cáo | Không, ứng dụng không chứa quảng cáo |
| Phân loại nội dung | Xem B3 |
| Đối tượng mục tiêu | Chỉ chọn nhóm 18 tuổi trở lên. Thu hút trẻ em: Không |
| Ứng dụng tin tức | Không (app giáo dục; mục Tin tức chỉ là phần phụ) |
| Ứng dụng truy vết, tình trạng COVID-19 | Không |
| An toàn dữ liệu | Xem B4 |
| Ứng dụng của chính phủ | Không (không do cơ quan nhà nước phát triển hay ủy quyền) |
| Tính năng tài chính | Ứng dụng không có tính năng tài chính (tính lương, tính đảng phí chỉ là máy tính; nút nộp đảng phí mở trang Dịch vụ công của Đảng) |
| Sức khỏe | Không có tính năng sức khỏe |
| Mã nhận dạng quảng cáo | Không dùng (app không có thư viện quảng cáo, Firebase). Nếu khi tải AAB Play Console báo có quyền AD_ID thì dừng lại kiểm tra |

### B3. Phân loại nội dung (bảng hỏi IARC)
- Email liên hệ: hotro.trolysogv@gmail.com. Danh mục: Tham khảo, tin tức hoặc giáo dục.
- Bạo lực, nỗi sợ, tình dục, ngôn từ thô tục, chất kích thích, cờ bạc, nội dung phản cảm: Không.
- Người dùng tương tác, trao đổi nội dung với nhau: Không. Chia sẻ vị trí: Không. Mua hàng kỹ thuật số: Không. Trình duyệt web, công cụ tìm kiếm không giới hạn: Không.
- Nội dung do AI tạo sinh (nếu bảng hỏi có câu này): Có; người dùng báo cáo bằng nút Báo cáo dưới mỗi câu trả lời.

### B4. An toàn dữ liệu
- Có thu thập hoặc chia sẻ dữ liệu bắt buộc phải khai: Có. Mã hóa khi truyền: Có (HTTPS). Người dùng yêu cầu xóa dữ liệu được: Có (Tài khoản → Xóa dữ liệu của tôi trên máy chủ, hoặc gửi email kèm mã máy).
- Chia sẻ cho bên thứ ba: Không. Google (Gemini), Anthropic (Claude), các dịch vụ AI, tìm kiếm khác và Cloudflare chỉ xử lý thay app, theo định nghĩa của Google là "nhà cung cấp dịch vụ", không tính là chia sẻ. Dịch trên máy (ML Kit của Google, dùng khi mất mạng) chạy hẳn trên điện thoại, không gửi chữ đi.

| Loại dữ liệu | Bắt buộc / tùy chọn | Mục đích | Xử lý tạm thời |
| --- | --- | --- | --- |
| Mã thiết bị hoặc mã khác (mã máy ngẫu nhiên app tự tạo; kèm địa chỉ IP dùng giới hạn lượt) | Bắt buộc khi dùng AI | Chức năng ứng dụng; Chống gian lận, bảo mật và tuân thủ | Không (bộ đếm tự xóa sau 3 ngày) |
| Nội dung khác do người dùng tạo (câu hỏi, ghi chép họp, ý nhắn phụ huynh, văn bản nhờ đọc thành tiếng, chữ cần dịch, nội dung tự đánh giá nhờ AI viết nháp, giáo án để tạo bài trình chiếu gửi lên máy chủ) | Tùy chọn | Chức năng ứng dụng | Có, trừ nội dung thầy cô bấm Báo cáo (lưu tối đa 90 ngày) |
| Ảnh (ảnh đề khi Giải đề, ảnh khi hỏi Trợ lý, ảnh trang ghi chép ở Biên bản, ảnh trang cần dịch, ảnh giáo án khi tạo bài trình chiếu) | Tùy chọn | Chức năng ứng dụng | Có |

Không khai: vị trí, danh bạ, tin nhắn, tài chính, sức khỏe, âm thanh (lời nói đổi thành chữ bằng bộ nhận giọng của điện thoại, app không gửi âm thanh lên máy chủ).

### B5. Thông tin trong cửa hàng chính
- Tên, mô tả ngắn, mô tả đầy đủ: lấy ở mục A.
- Biểu tượng 512×512: `cua-hang/anh/bieu_tuong_512.png`. Google ghi yêu cầu PNG 32 bit có kênh alpha, tệp trong kho là 24 bit; nếu Play Console không nhận thì đổi sang 32 bit.
- Ảnh nổi bật 1024×500: `cua-hang/anh/anh_noi_bat_1024x500.png` (còn trang chủ bản 0.3.0).
- Ảnh màn hình điện thoại: 8 ảnh `cua-hang/anh/man_hinh_01.png` đến `08.png` (1080×1920). Ảnh máy tính bảng, Chromebook: bỏ trống (không bắt buộc).
- Cách tải ảnh lên: trình duyệt của app không có nút gửi tệp. Cách đã chạy được trên App Store Connect ngày 24/11: chạy JavaScript trên trang, lấy ảnh từ raw.githubusercontent.com của kho mã (kho công khai), gán vào ô chọn tệp bằng DataTransfer và phát sự kiện change (chi tiết ở `claude/tien-do-app-store.md`).

### B6. Cài đặt cửa hàng
- Danh mục: Giáo dục. Thẻ: chọn trong danh sách Google gợi ý các thẻ về giáo dục, năng suất.
- Email: hotro.trolysogv@gmail.com. Trang web: trang hỗ trợ ở mục A. Số điện thoại: để trống.

### B7. Thử nghiệm kín
- Tạo kênh thử nghiệm kín, quốc gia Việt Nam. Người thử: danh sách email Gmail, ít nhất 12 người, mỗi người bấm tham gia qua đường liên kết thử nghiệm và giữ app ít nhất 14 ngày liên tục.
- Bản phát hành: AAB mới nhất ở lượt chạy kiem_tra (artifact tro-ly-so-gv-google-play-aab). Ký app: để Google quản lý (Play App Signing, mặc định); khóa thử nghiệm trong kho chỉ làm khóa tải lên, trước khi phát hành chính thức đổi khóa tải lên riêng.
- Ghi chú phát hành (vi-VN): "Bản thử nghiệm đầu tiên của Trợ lý số Giáo viên - Một chạm: các tiện ích hành chính, chuyên môn (biên bản họp, quét PDF, sổ minh chứng, ảnh thẻ, nhận xét theo Thông tư 22, 27, chấm trắc nghiệm, giải đề, dịch tài liệu), mục Công tác Đảng, Hỏi Trợ lý, Tin tức. Thầy cô dùng thử, gặp lỗi bấm Báo cáo hoặc gửi email hotro.trolysogv@gmail.com."
- Sau đủ 14 ngày: nộp đơn xin quyền phát hành chính thức, trả lời theo thực tế lúc đó.

## C. App Store (iPhone, iPad, máy Mac chip Apple)
- Đóng gói, ký, đẩy TestFlight bằng máy Mac của GitHub (job ios trong kiem_tra.yml, chạy tay) với khóa API trong secret ASC_KEY_P8. Gắn bản vào nhóm thử: testflight_noi_bo.yml; gắn bản vào trang phiên bản: gan_ban_app_store.yml. Chỉ gửi duyệt khi người dùng bảo.
- TARGETED_DEVICE_FAMILY = "1,2", iPad xoay đủ 4 chiều; ITSAppUsesNonExemptEncryption = NO.
- Ảnh: iPhone 6,3 inch 1206×2622 (`cua-hang/anh-iphone/`), iPad 13 inch 2064×2752 (`cua-hang/anh-ipad/`); tải lên bằng anh_app_store.yml.
- Quyền riêng tư của app: Theo dõi người dùng: Không. Dữ liệu liên kết với danh tính: Không. Dữ liệu không liên kết với danh tính: Mã thiết bị (đếm lượt, Chức năng app); Nội dung người dùng khác (nội dung thầy cô bấm Báo cáo, lưu tối đa 90 ngày). Nội dung chỉ xử lý tức thời rồi bỏ (câu hỏi, ảnh, chữ cần dịch gửi AI) không tính là "thu thập".
- Bản quyền, thông tin người duyệt, phát hành thủ công: đã điền trên App Store Connect.

Ghi chú cho người duyệt:
```
Trợ lý số Giáo viên is a free toolkit for Vietnamese school teachers. No account or login is required; every feature is available right after install.
AI features (Ask Assistant, student comments, exam solving, parent messages, meeting minutes, document translation, draft self-assessment remarks, lesson slides built from a lesson plan) are processed through our server (Cloudflare Worker) using Google Gemini and Anthropic Claude. Student names are replaced with codes before sending. Every AI answer has a "Báo cáo" (Report) button. Server-side data can be deleted in Tài khoản > Xóa dữ liệu của tôi trên máy chủ.
The "Công tác Đảng" section offers a meeting reminder, a membership-fee calculator and links that open official public websites/apps. The app is not affiliated with any government or party organization.
The "Tin tức" section shows short self-written summaries with links to the original news sources.
```
