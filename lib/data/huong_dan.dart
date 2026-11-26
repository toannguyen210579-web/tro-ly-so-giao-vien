/// Hướng dẫn sử dụng từng tiện ích. Mỗi tiện ích gồm nhiều mục, mỗi mục nhiều bước.
/// Tên nút trong hướng dẫn ghi đúng như trên màn hình để thầy cô dễ tìm.
class MucHuongDan {
  final String tieuDe;
  final List<String> buoc;
  const MucHuongDan(this.tieuDe, this.buoc);
}

const _riengTu = MucHuongDan('Dữ liệu của thầy cô', [
  'Mọi dữ liệu lưu ngay trên điện thoại, không cần tạo tài khoản.',
  'Gỡ app là mất dữ liệu: việc quan trọng thì xuất tệp, gửi Zalo hoặc email cho mình để giữ.',
]);

const huongDan = <String, List<MucHuongDan>>{
  'hop': [
    MucHuongDan('Tạo biên bản', [
      'Bấm "Biên bản mới", chọn loại họp: họp tổ chuyên môn, hội đồng sư phạm, phụ huynh học sinh, sinh hoạt lớp hoặc họp khác.',
      'Giờ bắt đầu app tự ghi, bấm vào để sửa nếu cần.',
      'Mục "Thông tin đơn vị" (cơ quan cấp trên, tên trường, địa danh) chỉ cần ghi một lần, app tự nhớ cho lần sau. Trường mầm non, tiểu học, THCS ghi cơ quan cấp trên là UBND xã, phường; trường THPT ghi Sở GD&ĐT.',
    ]),
    MucHuongDan('Ghi diễn biến trong lúc họp', [
      'Gõ vào ô "Diễn biến, ý kiến", mỗi ý kiến một dòng.',
      'Bấm "Nói để ghi" để nói, app chuyển lời nói thành chữ.',
      'Bấm "Chèn giờ" để đánh dấu thời điểm từng ý kiến.',
      'Ghi chép viết tay trong sổ: bấm "Chụp ảnh ghi chép", chụp từng trang (chụp được nhiều trang). AI chép lại chữ vào ô Ghi chép.',
      'Đã có ảnh, tệp PDF hoặc tệp Word: bấm "Lấy từ tệp", chọn ảnh có sẵn, tệp PDF (cả PDF quét) hoặc tệp Word.',
      'Lần đầu gửi ảnh, tệp PDF lên AI, app hỏi thầy cô đồng ý. Đọc lại phần chữ AI chép, sửa chỗ sai trước khi lưu.',
    ]),
    MucHuongDan('Nhờ AI trình bày', [
      'Bấm "Nhờ AI sắp xếp thành biên bản", đọc thông báo rồi bấm "Đồng ý gửi".',
      'AI sắp xếp ghi chép thành biên bản đúng thể thức. Thầy cô đọc lại, sửa trước khi lưu.',
    ]),
    MucHuongDan('Lưu và xuất', [
      'Bấm "Lưu biên bản": app lưu biên bản và tạo luôn tệp Word (sửa tiếp được) và tệp PDF (để in, gửi).',
      'Hộp "Đã lưu biên bản" hiện ngay: bấm "Mở xem" để xem tệp, "Lưu vào máy" để chọn nơi lưu, "Gửi" để gửi Zalo, email.',
      'Cần lấy lại tệp: bấm nút tải xuống cạnh biên bản trong danh sách, hoặc mở biên bản rồi bấm nút tải xuống ở góc trên.',
      'Xóa biên bản: biên bản bị xóa khỏi máy, không lấy lại được.',
    ]),
    _riengTu,
  ],
  'dang': [
    MucHuongDan('Dịch vụ công của Đảng', [
      'Bấm "Dịch vụ công của Đảng" để mở Nền tảng chuyển đổi số cho đảng viên: thu nộp đảng phí (nộp cho mình hoặc nộp hộ đảng viên khác), chuyển sinh hoạt đảng chính thức, chuyển sinh hoạt đảng tạm thời.',
      'Đăng nhập bằng VNeID. Trợ lý số không hỏi và không lưu thông tin đăng nhập.',
    ]),
    MucHuongDan('Sổ tay đảng viên iCPV - Book', [
      'Bấm "Sổ tay đảng viên iCPV - Book" để mở ứng dụng chính thức trong App Store hoặc CH Play; đã cài thì bấm "Mở".',
      'Đăng nhập iCPV - Book bằng số định danh cá nhân và mật khẩu đảng viên, hoặc bằng VNeID. Trợ lý số không lưu và không hỏi các thông tin này.',
    ]),
    MucHuongDan('Lịch nhắc họp chi bộ', [
      'Bấm "Lịch nhắc họp chi bộ", chọn ngày họp hằng tháng và giờ họp, rồi bấm "Bật nhắc họp chi bộ".',
      'App tạo sẵn 12 buổi họp tới trong Lịch công tác; điện thoại nhắc trước một ngày, kể cả khi app đang đóng.',
      'Đổi ngày giờ thì bấm "Cập nhật lịch nhắc"; không cần nữa thì bấm "Tắt nhắc".',
    ]),
    MucHuongDan('Tính đảng phí', [
      'Bấm "Tính đảng phí", chọn nhóm: đang đóng BHXH bắt buộc, nghỉ ốm đau thai sản, hưu trí, học sinh sinh viên, chưa đến tuổi nghỉ hưu, đủ tuổi nghỉ hưu chưa hưởng lương hưu.',
      'Nhập tiền lương làm căn cứ đóng BHXH tháng trước (hoặc trợ cấp, lương hưu); nhóm tính theo lương tối thiểu thì chọn vùng.',
      'Người có công, hưởng trợ cấp bệnh binh, mất sức lao động, bảo trợ xã hội hằng tháng thì bật ô giảm 50%.',
      'Bấm "Nộp đảng phí trực tuyến" để mở Nền tảng chuyển đổi số cho đảng viên (dichvucong.dcs.vn), đăng nhập bằng VNeID, chọn "Thu nộp đảng phí" rồi thanh toán qua ngân hàng.',
      'Mức tính theo Quy định số 01-QĐ/TW ngày 03/02/2026 của Bộ Chính trị, hiệu lực từ 01/02/2026.',
    ]),
    MucHuongDan('Bảo mật', [
      'Nội dung nhập chỉ lưu trên điện thoại, không gửi lên máy chủ.',
      'Không nhập tài liệu có độ mật vào app.',
    ]),
  ],
  'quet': [
    MucHuongDan('Quét giấy tờ', [
      'Bấm "Quét giấy tờ", đưa máy ảnh vào trang giấy. App tự tìm mép giấy, làm phẳng trang.',
      'Lần đầu app hỏi quyền máy ảnh, thầy cô bấm Cho phép.',
      'Nhiều trang thì bấm "Quét thêm trang".',
    ]),
    MucHuongDan('Sắp xếp trang', [
      'Giữ và kéo một trang để đổi thứ tự.',
      'Bấm "Bỏ trang này" để bỏ trang chụp hỏng.',
    ]),
    MucHuongDan('Tạo PDF', [
      'Bấm "Gộp thành PDF và gửi", chọn Zalo, email hoặc lưu vào máy.',
      'Các tệp đã tạo nằm ở mục "Tệp PDF đã lưu", bấm vào để gửi lại.',
    ]),
    MucHuongDan('Mẹo chụp rõ', [
      'Đặt giấy trên nền tối màu, đủ sáng, không để bóng tay đè lên chữ.',
    ]),
  ],
  'minh_chung': [
    MucHuongDan('Thêm minh chứng', [
      'Bấm "Thêm minh chứng", rồi "Chụp ảnh" hoặc "Chọn ảnh". Một minh chứng có thể gồm nhiều ảnh (nhiều trang).',
      'Ghi tiêu đề, ví dụ "Giấy khen giáo viên dạy giỏi cấp trường", chọn nhóm, ngày.',
      'Ô "Mã minh chứng" ghi theo mã của hồ sơ thi đua, kiểm định (ví dụ H1-1.1-01), không bắt buộc.',
      'Ghi chú số, ngày quyết định nếu có, rồi bấm "Lưu".',
    ]),
    MucHuongDan('Tìm minh chứng', [
      'Chạm các nhóm ở đầu danh sách để lọc theo nhóm.',
    ]),
    MucHuongDan('Xuất để nộp hồ sơ', [
      'Bấm "Xuất để nộp hồ sơ" (hoặc biểu tượng chia sẻ ở góc trên). Đang lọc một nhóm thì chỉ xuất nhóm đó.',
      '"Để tải lên hệ thống": mỗi minh chứng một tệp PDF, tên không dấu có số thứ tự (01_..., 02_...), kèm danh mục Excel.',
      '"Gói nén .zip": các tệp trên gộp thành một tệp để gửi Zalo, email, mở trên máy tính.',
      '"Một tệp PDF gộp": tất cả minh chứng trong một tệp, xếp theo nhóm, để in hoặc nộp bản giấy.',
      '"Danh mục Excel": bảng số thứ tự, mã, tên, ngày, ghi chú, tên tệp, chép sang danh mục của hệ thống.',
    ]),
    _riengTu,
  ],
  'anh_the': [
    MucHuongDan('Chụp ảnh', [
      'Bấm "Chụp ảnh" hoặc "Ảnh có sẵn".',
      'Đứng trước nền đơn giản, đủ sáng, nhìn thẳng. App tự tách người khỏi nền.',
    ]),
    MucHuongDan('Chọn nền và cỡ', [
      '"Màu nền": Xanh hoặc Trắng.',
      '"Cỡ ảnh": 3 x 4 cm hoặc 4 x 6 cm. App xếp nhiều ảnh lên một tờ in 10 x 15 cm.',
    ]),
    MucHuongDan('In ảnh', [
      'Bấm "Lưu và gửi đi in", gửi Zalo cho tiệm in hoặc lưu vào máy.',
      'Dặn tiệm in đúng khổ 10 x 15 cm, không phóng to thu nhỏ để ảnh đúng kích thước.',
    ]),
  ],
  'doc_to': [
    MucHuongDan('Văn bản thành giọng nói', [
      'Dán hoặc gõ văn bản vào ô, hoặc mở một tệp.',
      'Chọn "Tốc độ" đọc, bấm "Đọc to". Văn bản dài được đọc từng đoạn.',
      'Bấm "Dừng" để dừng đọc.',
    ]),
    MucHuongDan('Giọng nói thành văn bản', [
      'Bấm "Nói để ghi", nói rõ ràng. Lần đầu app hỏi quyền micro, thầy cô bấm Cho phép.',
      'Chữ hiện trong ô, sửa trực tiếp được.',
    ]),
    MucHuongDan('Dùng chữ đã có', [
      '"Chép" để dán sang Word, Zalo; "Gửi đi" để gửi thẳng.',
      '"Chèn vào biên bản" để đưa chữ vào biên bản đang làm.',
    ]),
  ],
  'sang_word': [
    MucHuongDan('Lấy chữ từ ảnh', [
      'Bấm "Chụp văn bản" hoặc "Chọn ảnh".',
      'App nhận chữ ngay trên máy. Chụp gần, đủ sáng, giấy phẳng để nhận chữ chính xác.',
    ]),
    MucHuongDan('Sửa và xuất', [
      'Chữ nhận được hiện trong ô, sửa trực tiếp được.',
      'Bấm "Xuất Word" để có tệp Word, hoặc "Chép" để dán nơi khác.',
    ]),
  ],
  'lich': [
    MucHuongDan('Thêm việc', [
      'Bấm "Thêm việc", ghi việc cần làm, chọn ngày giờ hạn.',
      'Mục "Nhắc": trước 1 giờ, 1 ngày, 3 ngày hoặc 1 tuần. Đến lúc đó điện thoại báo.',
      'Ghi chú nếu cần rồi bấm "Lưu". Lần đầu app hỏi quyền thông báo, thầy cô bấm Cho phép.',
    ]),
    MucHuongDan('Theo dõi', [
      'Việc sắp đến hạn hiện ở trang chủ và trong danh sách, có ghi còn bao lâu.',
      'Đánh dấu việc đã xong. Bật "Hiện cả việc đã xong" để xem lại.',
      'Chạm vào việc để sửa, hoặc xóa.',
    ]),
  ],
  'luong': [
    MucHuongDan('Nhập thông tin', [
      'Chọn "Cấp dạy", "Hạng", "Bậc lương".',
      'Chọn ngày "Bắt đầu dạy (có BHXH)" để app tính thâm niên, và ngày "Hưởng bậc hiện tại từ" để tính ngày nâng bậc.',
      '"Phụ cấp ưu đãi theo nghề" chọn theo vùng, cấp dạy của trường.',
      'Mục "Phụ cấp khác": chức vụ (ví dụ tổ trưởng 0,2), chênh lệch bảo lưu, thâm niên vượt khung, khu vực.',
    ]),
    MucHuongDan('Kết quả', [
      'App tính lương tháng, từng khoản phụ cấp, ngày nâng bậc lần tới.',
      'Bấm "Nhắc ngày nâng bậc vào Lịch" để được báo trước.',
      '"Chép kết quả" để gửi hoặc lưu lại.',
      'Mục "Căn cứ" ghi văn bản áp dụng và ngày cập nhật. Số liệu để tham khảo, đối chiếu với bảng lương của trường.',
    ]),
  ],
  'nhan_xet': [
    MucHuongDan('Tạo lớp', [
      'Bấm "Thêm lớp", ghi tên lớp, môn, chọn "Tiểu học" hoặc "THCS, THPT".',
      'Danh sách học sinh: mỗi em một dòng, hoặc bấm "Lấy từ tệp Excel" (tệp xuất từ vnEdu, SMAS).',
      'Bấm "Tạo lớp".',
    ]),
    MucHuongDan('Chọn mức đánh giá', [
      'Tiểu học: Hoàn thành tốt, Hoàn thành, Chưa hoàn thành. THCS, THPT: Tốt, Khá, Đạt, Chưa đạt.',
      'Mức "Miễn" dùng cho môn học sinh được miễn (học sinh khuyết tật).',
      'Chạm chọn mức cho từng em trước khi nhờ AI viết.',
    ]),
    MucHuongDan('Viết nhận xét', [
      '"Điền nhận xét mẫu": điền nhanh câu mẫu theo mức.',
      '"Nhờ AI viết nhận xét": AI viết riêng cho từng em dựa vào mức. Tên học sinh không gửi đi, AI chỉ thấy mã HS01, HS02…',
      'Đọc lại, sửa trước khi dùng. Chạm "Sửa nhận xét, nhập điểm" để sửa từng em.',
    ]),
    MucHuongDan('Học sinh khuyết tật', [
      'Trong ô sửa của em đó, bật "Học sinh khuyết tật".',
      'Nhận xét theo kế hoạch giáo dục cá nhân, dựa trên sự tiến bộ của chính em, không so sánh với bạn khác (Thông tư 89/2026/TT-BGDĐT).',
    ]),
    MucHuongDan('Điểm trung bình môn (THCS, THPT)', [
      'Nhập điểm thường xuyên (cách nhau bằng khoảng trắng), giữa kỳ, cuối kỳ. App tự tính ĐTB.',
      'Cách tính không đổi theo Thông tư 89/2026.',
    ]),
    MucHuongDan('Đưa vào phần mềm của trường', [
      'Bấm "Chép cả lớp sang Excel", mở Excel, bấm vào ô A1 rồi dán.',
    ]),
    MucHuongDan('Căn cứ', [
      'Thông tư 27/2020 (tiểu học), Thông tư 22/2021 (THCS, THPT), sửa đổi bởi Thông tư 89/2026/TT-BGDĐT, hiệu lực 01/12/2026: Học bạ số, học sinh khuyết tật được đánh giá theo kế hoạch giáo dục cá nhân.',
    ]),
  ],
  'cham_tn': [
    MucHuongDan('Tạo bài kiểm tra', [
      'Bấm "Bài kiểm tra mới", ghi tên bài, số câu (1 đến 200), bấm "Tạo".',
      'Thẻ "Đáp án": nhập đáp án cho từng mã đề. Nhiều mã đề thì bấm "Thêm mã đề".',
      'Có đề trong Giải đề thì bấm "Đưa đáp án sang Chấm trắc nghiệm" ở đó, không phải nhập lại.',
    ]),
    MucHuongDan('Chấm bài', [
      'Thẻ "Chấm bài", bấm "Chấm bài mới", ghi tên học sinh, chọn mã đề.',
      'Gõ nhanh cả dãy (ví dụ ABCDA BBCDA… hoặc 1234…, câu bỏ trống gõ dấu -), hoặc chạm chọn từng câu.',
      'App chấm ngay, hiện số câu đúng và điểm.',
    ]),
    MucHuongDan('Bảng điểm, thống kê', [
      '"Chép sang Excel" để dán thẳng vào Excel, "Gửi tệp" để gửi.',
      'Thẻ "Thống kê": số bài theo từng khoảng điểm, các câu nhiều em làm sai để chữa bài.',
    ]),
  ],
  'nhan_ph': [
    MucHuongDan('Soạn tin', [
      'Chọn loại tin: mời họp phụ huynh, học sinh nghỉ học, kết quả học tập, khen ngợi, nhắc nộp khoản, nghỉ lễ đổi lịch, trao đổi khác.',
      'Gõ tên học sinh (vài chữ để chọn), lớp, họ tên thầy cô (app nhớ cho lần sau). Tên học sinh không gửi cho AI.',
      'Muốn lời lẽ riêng thì gõ ý vào ô "Ý thầy cô muốn nói", bấm "Nhờ AI soạn tin".',
    ]),
    MucHuongDan('Gửi tin', [
      'Sửa trực tiếp trong ô tin nhắn.',
      'Bấm "Gửi qua Zalo…" hoặc "Chép tin" để dán vào nhóm lớp.',
    ]),
  ],
  'tao_de': [
    MucHuongDan('Đưa đề vào', [
      'Chọn môn, lớp.',
      '"Chụp đề" hoặc "Chọn ảnh" (tối đa 4 ảnh mỗi lần), "Tải tệp" (PDF, Word), hoặc gõ, dán đề vào ô.',
      'Ô "Yêu cầu thêm" (không bắt buộc): ví dụ chỉ giải câu 3, 4; thang điểm 10; ra 5 câu tương tự.',
    ]),
    MucHuongDan('Giải và ra đề', [
      '"Giải, soạn đáp án": lời giải từng bước, đáp án, thang điểm.',
      '"Ra đề tương tự": đề mới cùng dạng, cùng mức độ.',
      'Kết quả sửa được. Thầy cô kiểm tra lại trước khi dùng.',
    ]),
    MucHuongDan('Dùng kết quả', [
      '"Chép" để dán vào Word, "Lưu Word" để có tệp, "Gửi đi" để gửi.',
      'Đề trắc nghiệm: bấm "Đưa đáp án sang Chấm trắc nghiệm" để tạo bài chấm có sẵn đáp án.',
    ]),
  ],
  'o_chu': [
    MucHuongDan('Ô chữ mỗi ngày', [
      'Thẻ cam "Ô chữ hôm nay" ở đầu màn: mỗi ngày một ô chữ mới theo chủ đề, bấm "Giải ngay".',
      'Chạm số thứ tự của hàng để xem câu hỏi, gõ đáp án (có dấu hay không dấu, viết số hay viết chữ đều được), bấm "Trả lời".',
      'Bí quá thì bấm "Xem đáp án" hàng đó. Đoán ra từ khóa hàng dọc sớm thì bấm "Đoán từ khóa hàng dọc" là xong luôn.',
      'Xong thì bấm "Chia sẻ kết quả" (không lộ đáp án) hoặc "Lưu để chiếu lên lớp" để dùng ô chữ đó trên lớp.',
      'Giải liền nhiều ngày sẽ có chuỗi ngày 🔥. Thoát ra giữa chừng, vào lại vẫn giải tiếp được.',
    ]),
    MucHuongDan('Tạo ô chữ', [
      'Bấm "Ô chữ mới", ghi tên ô chữ và từ khóa hàng dọc.',
      'Mỗi hàng ngang: câu hỏi và đáp án; đáp án mỗi hàng nên chứa một chữ của từ khóa để app xếp thành hàng dọc. Bấm "Thêm hàng ngang" để thêm.',
      '"Xem trước" để kiểm tra, rồi "Lưu ô chữ".',
    ]),
    MucHuongDan('Chơi trên lớp', [
      'Bấm "Chơi", chiếu điện thoại lên màn hình lớp.',
      'Học sinh trả lời đúng thì chạm hàng đó, bấm "Mở đáp án hàng này".',
      'Đoán được từ khóa thì bấm "Mở từ khóa". "Chơi lại" để bắt đầu lại.',
    ]),
  ],
  'gio_the': [
    MucHuongDan('In thẻ', [
      'Chọn lớp (lấy danh sách từ Nhận xét học sinh) hoặc "Không theo lớp" rồi chọn số thẻ.',
      'Bấm "In bộ thẻ" (2 thẻ một trang A4). Mỗi em một thẻ có số riêng, in một lần dùng mãi.',
    ]),
    MucHuongDan('Hỏi cả lớp', [
      'Nêu câu hỏi, học sinh xoay thẻ để chữ A, B, C hoặc D lên trên rồi giơ thẻ.',
      'Bấm "Chụp cả lớp" (hoặc "Ảnh có sẵn"). App đọc tất cả thẻ trong ảnh, hiện "Đã nhận …/… em".',
      'Còn thiếu em nào thì chụp thêm, kết quả được cộng dồn.',
      'Chọn "Đáp án đúng" để biết em nào đúng, tỉ lệ đúng cả lớp. Bấm "Câu mới" cho câu kế tiếp.',
    ]),
    MucHuongDan('Kết quả', [
      '"Xuất Excel" hoặc "Chép bảng" để lưu kết quả các câu đã làm.',
      'Đọc sai một em thì chạm vào em đó để chọn lại hoặc bỏ kết quả.',
      'Menu góc trên: "Hiệu chỉnh chiều máy ảnh" (một em giơ thẻ chữ A lên trên, chụp), "Xóa kết quả đã lưu".',
    ]),
  ],
  'cong_cu': [
    MucHuongDan('Chọn lớp', [
      'Chọn lớp ở đầu màn hình (lấy danh sách từ Nhận xét học sinh).',
    ]),
    MucHuongDan('Gọi tên', [
      'Thẻ "Gọi tên": bấm để gọi ngẫu nhiên một em.',
      'Bật "Không gọi lại em đã được gọi" để lần lượt cả lớp đều được gọi.',
    ]),
    MucHuongDan('Chia nhóm', [
      'Thẻ "Chia nhóm": chọn số nhóm, app chia ngẫu nhiên. "Gửi danh sách nhóm" để gửi Zalo.',
    ]),
    MucHuongDan('Điểm danh', [
      'Thẻ "Điểm danh": chạm vào tên để đổi có mặt, vắng. "Chép" hoặc "Gửi" kết quả.',
    ]),
    MucHuongDan('Đồng hồ', [
      'Thẻ "Đồng hồ": chọn số phút, bấm chạy. Hết giờ điện thoại báo. "Đặt lại" để chạy lại.',
    ]),
    MucHuongDan('Thử thách cả lớp', [
      'Thẻ "Thử thách": có sẵn bộ câu hỏi mẫu để chơi thử. "Bộ câu hỏi mới" để dán câu hỏi từ Word, Zalo; "Nhờ AI soạn" để AI soạn theo chủ đề, thầy cô đọc lại rồi lưu.',
      'Chọn thời gian mỗi câu, bấm "Chơi", chiếu điện thoại lên màn hình lớp. Bấm "Bắt đầu tính giờ", học sinh ghi đáp án lên bảng con.',
      'Hết giờ bấm "Xem đáp án", chạm tên các em trả lời sai để loại, rồi "Câu tiếp theo". Cả lớp cùng sai thì app không loại ai.',
      'Nút "Cứu trợ" cho các em đã bị loại vào chơi lại. Kết thúc bấm "Gửi kết quả" để gửi nhóm Zalo lớp.',
    ]),
  ],
  'dich': [
    MucHuongDan('Đưa nội dung cần dịch', [
      'Dán hoặc gõ chữ vào ô "Chữ cần dịch".',
      'Hoặc bấm "Chụp ảnh" để chụp trang sách, tài liệu (chụp được nhiều trang), "Ảnh có sẵn" để chọn ảnh trong máy.',
      'Hoặc bấm "Tệp PDF, Word": tệp Word thì chữ hiện vào ô; tệp PDF (cả PDF quét) thì mỗi trang dịch thành một trang.',
    ]),
    MucHuongDan('Chọn cách dịch', [
      'Chọn ngôn ngữ đích: Tiếng Việt, Anh, Trung, Nhật, Hàn, Pháp. Ngôn ngữ gốc app tự nhận.',
      '"Sát nghĩa": bám câu chữ, văn phong trang trọng, dùng cho văn bản, tài liệu. "Dễ hiểu": câu ngắn, từ đơn giản để học sinh đọc.',
      'Bật "Song ngữ" để bản gốc và bản dịch đặt cạnh nhau từng đoạn, tiện soạn bài tiếng Anh.',
    ]),
    MucHuongDan('Lưu và gửi', [
      'Bấm "Lưu bản dịch": app tạo tệp Word và PDF, hộp "Đã lưu" có Mở xem, Lưu vào máy, Gửi Zalo, email.',
      'Bản dịch có chữ Trung, Nhật, Hàn thì chỉ xuất tệp Word (tệp PDF chưa hiện được các chữ này).',
    ]),
    MucHuongDan('Lưu ý', [
      'Mỗi trang chữ (khoảng 2.500 ký tự), mỗi ảnh hoặc trang PDF tính một lượt; mỗi ngày dịch được 20 trang.',
      'Mất mạng: đoạn chữ ngắn Anh ⇄ Việt vẫn dịch được ngay trên máy (ghi "Dịch bởi Google"), cần tải gói ngôn ngữ một lần khi có wifi.',
      'App chưa dịch tiếng dân tộc thiểu số: AI dịch các tiếng này còn kém, gửi phụ huynh bản dịch sai thì hại hơn có lợi.',
      'AI có thể nhầm. Thầy cô đọc lại bản dịch trước khi dùng; bấm "Báo cáo" khi thấy dịch sai.',
    ]),
  ],
  'danh_gia': [
    MucHuongDan('Căn cứ', [
      'Làm theo Nghị định số 233/2026/NĐ-CP (hiệu lực 01/7/2026, thay Nghị định 90/2020): tiêu chí chung tối đa 30 điểm, kết quả thực hiện nhiệm vụ tối đa 70 điểm (số lượng, chất lượng, tiến độ).',
      'Mức xếp loại: Hoàn thành xuất sắc từ 90 điểm; Hoàn thành tốt từ 70 đến dưới 90; Hoàn thành từ 50 đến dưới 70; dưới 50 là Không hoàn thành.',
      'Điểm từng phần do quy chế đánh giá của trường quy định. Vào thẻ "Quy chế" sửa cho khớp quy chế trường mình trước khi chấm.',
    ]),
    MucHuongDan('Chấm điểm từng tháng', [
      'Ở thẻ "Các kỳ", bấm vào tháng (hoặc quý) cần chấm.',
      'Phần A: app để sẵn điểm tối đa từng nhóm tiêu chí chung, bấm dấu trừ ở nhóm còn chưa đạt.',
      'Phần B: bấm "Thêm việc" hoặc "Lấy việc từ Lịch nhắc hạn" để có danh sách việc được giao trong kỳ. Mỗi việc chọn khối lượng, chất lượng, tiến độ; app tự tính điểm.',
      'Trường đã chấm, xác nhận điểm tháng thì ghi vào ô "Điểm trường xác nhận"; app dùng điểm này để tính năm.',
      'Bấm "Lưu kỳ này".',
    ]),
    MucHuongDan('Cuối năm làm phiếu', [
      'Thẻ "Các kỳ" luôn hiện điểm bình quân, mức dự kiến và số điểm các kỳ còn lại cần đạt.',
      'Sang thẻ "Phiếu năm": ghi cơ quan cấp trên (UBND xã, phường với trường mầm non, tiểu học, THCS; Sở GD&ĐT với trường THPT), tên trường, họ tên, chức danh.',
      'Bấm "Nhờ AI viết nháp" để AI viết Ưu điểm, Hạn chế từ các việc đã chấm (không gửi họ tên lên AI). Đọc lại, sửa cho đúng.',
      'Đánh dấu các trường hợp riêng nếu có (chưa đủ 06 tháng làm việc, bị kỷ luật, bị kết luận suy thoái).',
      'Bấm "Lưu phiếu (Word và PDF)": app tạo phiếu đúng mẫu Phụ lục II, hộp "Đã lưu" có Mở xem, Lưu vào máy, Gửi.',
    ]),
    MucHuongDan('Lưu ý', [
      'Mức xếp loại chính thức do Hiệu trưởng (hoặc cấp có thẩm quyền) quyết định sau họp nhận xét.',
      'Số người Hoàn thành xuất sắc không quá 20% số người Hoàn thành tốt của trường (25% nếu trường được công nhận Hoàn thành xuất sắc).',
      'Trường chưa ban hành quy chế theo Nghị định 233/2026 thì cuối năm 2026 vẫn đánh giá theo quy chế cũ (Điều 20).',
    ]),
    _riengTu,
  ],
  'hoi': [
    // Mở bằng nút ? ở góc trên màn Hỏi Trợ lý (chốt 24/11/2026). Chỉ nêu ưu thế có thật, không ghi "vượt trội", "tốt nhất".
    MucHuongDan('Điểm mạnh của Trợ lý', [
      'Hỏi chế độ, quy định ngành giáo dục năm 2026: Trợ lý tra văn bản gốc trong kho (Luật Nhà giáo, các thông tư về xếp lương, chuẩn nghề nghiệp, Điều lệ trường…) rồi mới trả lời, có dẫn điều, khoản để thầy cô đối chiếu.',
      'Tên học sinh trong câu hỏi được thay bằng mã HS01, HS02… trước khi gửi AI.',
      'Hỏi xong làm luôn trong app: viết nhận xét học sinh, soạn tin phụ huynh, sắp xếp biên bản họp, tính lương.',
    ]),
    MucHuongDan('Cách dùng', [
      'Gõ câu hỏi vào ô "Hỏi AI…" rồi bấm nút gửi, hoặc bấm micro để nói thay gõ.',
      'Bấm nút + để chụp ảnh, chọn ảnh có sẵn (chụp đề để hỏi cách giải) hoặc gửi tệp PDF, Word để hỏi về nội dung.',
      'Hỏi tiếp ngay dưới câu trả lời, Trợ lý nhớ các câu trước trong cùng cuộc trò chuyện, không phải nhắc lại.',
      'Hỏi được cả dạy học, chuyên môn và chuyện thường ngày.',
    ]),
    MucHuongDan('Lưu ý', [
      'Kho văn bản đang được bổ sung hằng ngày. Văn bản chưa có trong kho thì Trợ lý nói rõ phần nào còn thiếu.',
      'Từ 01/7/2025 không còn Phòng GD&ĐT: trường mầm non, tiểu học, THCS thuộc UBND xã, phường; trường THPT thuộc Sở GD&ĐT.',
      'AI có thể nhầm. Việc hệ trọng (lương, chế độ, kỷ luật), thầy cô đối chiếu văn bản gốc trước khi làm theo.',
      'Câu trả lời sai, không phù hợp thì bấm "Báo cáo" để nhóm làm app sửa.',
      'Mỗi ngày có số câu hỏi miễn phí; dùng hết thì hôm sau dùng tiếp.',
    ]),
  ],
};
