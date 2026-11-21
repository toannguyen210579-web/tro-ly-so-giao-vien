// Kiến thức nền về chế độ, chính sách nhà giáo, nạp vào Hỏi Trợ lý khi câu hỏi đi qua Claude.
// Mô hình AI chưa biết các văn bản năm 2026, nên phải nạp sẵn (người dùng chốt 20/11/2026).
// Nội dung đã đối chiếu văn bản gốc khi làm clip kênh Việt Nam Tiêu Điểm và lịch trả lời bình luận (15–20/11/2026).
// Có văn bản mới thì sửa tệp này, cập nhật ngày ở dòng KIEN_THUC_NGAY.
export const KIEN_THUC_NGAY = "21/11/2026";

export const KIEN_THUC = `
KIẾN THỨC NỀN VỀ CHẾ ĐỘ NHÀ GIÁO (cập nhật ${KIEN_THUC_NGAY}; ưu tiên dùng phần này hơn hiểu biết cũ của bạn).
Cách dùng: câu hỏi thuộc phần này thì trả lời theo đúng phần này và ghi rõ tên văn bản (ví dụ "Nghị định 182/2026/NĐ-CP"). Không dùng các mức cũ (ví dụ phụ cấp ưu đãi 30%, 35% theo quy định trước năm 2026) như mức hiện hành; nếu nhắc mức cũ thì nói rõ là mức cũ. Câu hỏi ngoài phần này hoặc cần văn bản mới hơn ngày cập nhật thì nói rõ cần kiểm tra văn bản gốc; không đoán số liệu, số hiệu văn bản. Ví dụ tính tiền là ví dụ minh họa, nói rõ còn tùy hệ số, nơi công tác.

1. Lương cơ sở: 2.530.000 đồng/tháng từ ngày 1/7/2026 (trước đó 2.340.000 đồng). Lương = hệ số × lương cơ sở.

2. Phụ cấp ưu đãi theo nghề: Nghị định 182/2026/NĐ-CP ngày 22/5/2026, hiệu lực từ 7/7/2026, nhưng các mức mới được tính từ 1/1/2026; phần chênh lệch từ 1/1/2026 đến trước khi trả mức mới được truy lĩnh. Áp dụng cho nhà giáo, cán bộ quản lý và nhân sự hỗ trợ giáo dục ở cơ sở giáo dục công lập.
- Giáo viên mầm non, tiểu học: 45% (mức cũ 35%); dạy ở xã khu vực I, khu vực II vùng đồng bào dân tộc thiểu số và miền núi: 60%.
- Giáo viên THCS, THPT: 40% (mức cũ 30%); ở các xã nói trên: 45%.
- Cao nhất 80%: trường phổ thông dân tộc nội trú, trường chuyên, vùng đặc biệt khó khăn (theo các trường hợp tại Điều 3 Nghị định 182/2026/NĐ-CP).
- Nhân sự hỗ trợ giáo dục (nhân viên trường học) lần đầu được hưởng: 20%.
- Không tính hưởng: thời gian nghỉ thai sản, nghỉ không lương từ 1 tháng trở lên, đi công tác hoặc học tập ở nước ngoài hưởng 40% lương, bị đình chỉ công tác, tạm giữ, tạm giam.
- Cách tính: mức % × (lương theo hệ số + phụ cấp chức vụ + phụ cấp thâm niên vượt khung nếu có). Ví dụ giáo viên tiểu học hệ số 3,33, mức 45%: khoảng 3,79 triệu đồng/tháng.

3. Phụ cấp thâm niên nhà giáo: dạy đủ 5 năm được 5%, mỗi năm sau thêm 1% (ví dụ dạy 10 năm: 10%).

4. Phụ cấp thâm niên vượt khung: theo Thông tư 04/2005/TT-BNV (đã sửa đổi năm 2021). Đã xếp bậc lương cuối; viên chức loại A giữ bậc cuối đủ 36 tháng (loại B, C đủ 24 tháng) thì được 5% mức lương bậc cuối; từ năm sau mỗi năm thêm 1% nếu hoàn thành nhiệm vụ và không bị kỷ luật. Trả cùng kỳ lương, có tính đóng bảo hiểm xã hội.

5. Thưởng định kỳ hằng năm (thưởng Tết): Nghị định 161/2026/NĐ-CP, hiệu lực từ 1/7/2026. Quỹ thưởng bằng 10% quỹ tiền lương theo hệ số cả năm (không tính phụ cấp); viên chức và người hợp đồng hưởng lương theo bảng lương nhà nước đều được xét; tiền thưởng chia theo kết quả xếp loại, không nhất thiết theo hệ số lương; mỗi đơn vị tự ban hành và công khai quy chế thưởng, nên mỗi trường một mức; tiền không dùng hết nộp lại ngân sách.

6. Chính sách tiền lương riêng cho nhà giáo (hệ số lương đặc thù): Bộ GDĐT từng đề xuất trong dự thảo nghị định hệ số đặc thù 1,25 cho giáo viên mầm non và 1,15 cho các nhà giáo khác; Bộ Nội vụ góp ý không quy định hệ số đặc thù. Đến ${KIEN_THUC_NGAY} CHƯA có nghị định ban hành; theo giải trình của Bộ Nội vụ tại Quốc hội (9/2026), tiền lương nhà giáo đặt trong tổng thể cải cách chính sách tiền lương; trước mắt đã có Nghị định 182/2026/NĐ-CP về phụ cấp. Thư Bộ trưởng Bộ GDĐT nhân 20/11/2026 thừa nhận một số chế độ chưa thực hiện đầy đủ, kịp thời. Không nói giáo viên đang hưởng hệ số đặc thù.

7. Thông tư 93/2026/TT-BGDĐT ngày 30/10/2026 (hiệu lực 30/10/2026): sửa đổi các Thông tư 23, 28, 31/2026/TT-BGDĐT; KHÔNG phải văn bản thăng hạng. Xử lý 3 nhóm (khoản 6, 7, 8 Điều 15 Thông tư 31/2026/TT-BGDĐT):
- Khoản 6: người được bổ nhiệm ngay hạng cao (hạng II cũ; THPT là hạng I) trong giai đoạn 03/11/2015–20/3/2021 sau tuyển dụng, hết tập sự hoặc sau khi có bằng cao hơn, chưa qua thi/xét thăng hạng, thì được bổ nhiệm lại. Tiểu học, THCS vào hạng II mới (hệ số 4,00–6,38) nếu: đủ 9 năm giảng dạy có đóng BHXH bắt buộc (không kể tập sự); đạt chuẩn theo Thông tư 30/2026/TT-BGDĐT; năm học 2024–2025 và 2025–2026 làm đủ 2 nhóm nhiệm vụ từ cấp trường trở lên; hoàn thành tốt nhiệm vụ trở lên cả 2 năm. Không đủ thì hạng III, giữ nguyên hệ số. Mầm non nhóm này vào hạng II mới (hệ số 2,34–4,98). Không áp dụng với người được bổ nhiệm hạng cao theo chính sách thu hút, đặc thù của địa phương; người đã trúng thi/xét thăng hạng thì giữ kết quả thăng hạng. Khoản 6 không có truy lĩnh.
- Khoản 7: từ 20/3/2021 đến trước 30/10/2026, người đã giữ hạng I, II hoặc tương đương, đủ điều kiện nhưng bị bổ nhiệm hạng thấp hơn vì khống chế cơ cấu hạng, thì được bổ nhiệm lại, không phụ thuộc cơ cấu; lương hạng mới tính từ ngày ban hành quyết định cũ nên được truy lĩnh.
- Khoản 8: người tuyển dụng trước 09/4/2026, không thuộc khoản 6, 7, đã đủ điều kiện theo các Thông tư 01, 02, 03, 04/2021/TT-BGDĐT và 08/2023/TT-BGDĐT nhưng chưa được bổ nhiệm, thì được bổ nhiệm hạng tương ứng, không phụ thuộc cơ cấu, không truy lĩnh.
- Thủ tục: hiệu trưởng rà soát, lập danh sách, đề xuất (không phải chờ hướng dẫn); Chủ tịch UBND cấp xã quyết định với mầm non, tiểu học, THCS; Giám đốc Sở GDĐT với THPT; phải xong trước 31/12/2026. Giáo viên nên làm đơn gửi hiệu trưởng, kèm quyết định bổ nhiệm, xếp lương cũ.

8. Hệ số lương theo hạng (Thông tư 31/2026/TT-BGDĐT): mầm non hạng III A0 (2,10–4,89), hạng II A1 (2,34–4,98), hạng I A2.2 (4,00–6,38); tiểu học, THCS, THPT hạng III A1 (2,34–4,98), hạng II A2.2 (4,00–6,38), hạng I A2.1 (4,40–6,78). Chuyển sang thang cao hơn: xếp vào hệ số bằng hoặc cao hơn gần nhất; sau đó đủ 3 năm nâng một bậc.

9. Thăng hạng: người chưa từng giữ hạng II không thuộc Thông tư 93/2026, phải qua xét thăng hạng; đợt chuyển tiếp theo Nghị định 93/2026/NĐ-CP chỉ với đề án, kế hoạch được duyệt trước 30/6/2026, thực hiện đến hết 31/12/2026, trường phải còn chỉ tiêu. Tiểu học, THCS giữ hạng III đủ 9 năm (không kể tập sự) để lên hạng II; mầm non 3 năm. Người tuyển dụng trước 14/4/2026 không bắt buộc có chứng chỉ bồi dưỡng chuẩn nghề nghiệp mới; chứng chỉ chức danh nghề nghiệp cũ được công nhận tương đương (Điều 16 Thông tư 30/2026/TT-BGDĐT).

10. Nghỉ hưu: theo Luật Nhà giáo (hiệu lực 1/1/2026), giáo viên mầm non được nghỉ hưu sớm tối đa 5 năm, cần đủ 15 năm đóng BHXH bắt buộc, không bị trừ tỷ lệ lương hưu; năm 2026 sớm nhất nữ 52 tuổi, nam 56 tuổi 6 tháng.

11. Bảo hiểm thất nghiệp (Luật Việc làm 2025, từ 1/1/2026): chỉ hưởng khi chấm dứt hợp đồng đúng pháp luật, đã đóng đủ 12 tháng trong 24 tháng trước khi nghỉ, nộp hồ sơ trong 3 tháng; người đủ điều kiện hưởng lương hưu không được hưởng; không rút khi đang làm việc.

12. Quản lý trường học từ 01/7/2025 (chính quyền địa phương hai cấp): không còn cấp huyện, không còn Phòng Giáo dục và Đào tạo. Trường mầm non, tiểu học, THCS thuộc Ủy ban nhân dân xã, phường (Chủ tịch UBND cấp xã quyết định các việc trước đây của Trưởng phòng GDĐT, UBND cấp huyện); trường THPT thuộc Sở Giáo dục và Đào tạo. Sở GDĐT hướng dẫn chuyên môn, nghiệp vụ cho mọi cấp. Không khuyên thầy cô gửi việc lên "Phòng GDĐT".

13. Đánh giá học sinh: tiểu học theo Thông tư 27/2020/TT-BGDĐT, THCS, THPT theo Thông tư 22/2021/TT-BGDĐT, cả hai sửa đổi bởi Thông tư 89/2026/TT-BGDĐT ngày 16/10/2026, hiệu lực 01/12/2026. Mức đánh giá và cách tính điểm trung bình môn không đổi. Điểm mới: Học bạ số thay học bạ giấy (giáo viên môn ký số kết quả môn mình, giáo viên chủ nhiệm ký số sau); Sở GDĐT ra đề kiểm tra định kỳ chung cuối học kỳ I, cuối năm cho lớp 5 và cuối học kỳ I, II cho lớp 9, lớp 12 ở một số môn tính điểm do Sở chọn; được kiểm tra định kỳ trên máy tính khi đủ điều kiện; học sinh khuyết tật đánh giá theo kế hoạch giáo dục cá nhân, dựa trên tiến bộ của chính em, môn được miễn ghi "Miễn" trong Học bạ số; học sinh chấp hành xong kỷ luật được đánh giá lại rèn luyện; rèn luyện cả năm Chưa đạt nhưng rèn luyện hè đạt từ mức Đạt thì được kiểm tra lại các môn; lớp 9, lớp 12 kiểm tra lại trong hè bố trí linh hoạt, không ảnh hưởng tuyển sinh; không khảo sát, kiểm tra lại học sinh đã hoàn thành chương trình tiểu học khi vào lớp 6.
`;
