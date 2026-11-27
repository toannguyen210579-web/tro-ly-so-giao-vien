import { KIEN_THUC } from "./kien_thuc.js";
import { TIN } from "./tin.js";
import { canTim, timTrenMang, kemKetQua, vietMienPhi } from "./mien_phi.js";
import { khoaDung, napVanBan, timKienThuc, dsVanBan, xuatVanBan } from "./kien_thuc_db.js";
// Máy chủ trung gian cho app "Trợ lý số Giáo viên".
// App gọi POST /v1/ai, Worker gọi Claude (Haiku), đếm lượt theo từng máy mỗi ngày.
//
// Gắn trên Cloudflare:
//   - D1 database, tên biến DB (bảng tạo bằng schema.sql)
//   - Secret ANTHROPIC_API_KEY  (người dùng tự dán, không để trong mã)
//   - Biến AI_ENABLED = "1"     (đặt "0" để tạm khóa mọi nút AI)
//   - Secret APP_KEY            (tùy chọn, chuỗi dùng chung với app)
//
// Đường dẫn:
//   GET  /health                      kiểm tra máy chủ
//   GET  /v1/quota?device_id=...      số lượt còn lại hôm nay
//   POST /v1/ai                       { device_id, mode: "hoi"|"nhanxet"|"tinnhan", input }
//   GET  /v1/admob-ssv?...            AdMob gọi về sau khi xem hết quảng cáo nhận thưởng
//
// Chặn một máy lạm dụng: INSERT INTO flags(k, v) VALUES ('block:<mã máy>', 'ly do');
// Gói Pro: flags 'pro:<mã máy>' với v = thời điểm hết hạn (mili giây), do phần kiểm tra
// giao dịch mua tạo ra (chưa làm ở bản đầu).

const MODEL = "claude-haiku-5-5";
const MAX_INPUT = 2000;      // ký tự tối đa mỗi lần gửi
const MAX_TOKENS = 800;      // độ dài câu trả lời tối đa
// Riêng từng chế độ (chế độ không có ở đây dùng mức chung ở trên)
// trinhchieu: giáo án dài (cả tệp Word) gửi một lần để AI dựng đủ các hoạt động
const MAX_IN = { bienban: 12000, detuongtu: 4000, dich: 6000, danhgia: 4000, trinhchieu: 30000 };
const MAX_OUT = { hoi: 2000, nhanxet: 2000, tinnhan: 1200, giaide: 4000, detuongtu: 3000, bienban: 3000, chep_chu: 4000, dich: 4000, danhgia: 1200, trinhchieu: 7000 };
// chế độ được gửi ảnh (tối đa 4 ảnh), tệp PDF. chep_chu: Biên bản lấy ghi chép từ ảnh, PDF; dich: Dịch tài liệu (26/11/2026);
// trinhchieu: Tạo bài trình chiếu từ giáo án chụp ảnh hoặc tệp PDF (26/11/2026)
const IMG_MODES = ["giaide", "detuongtu", "hoi", "chep_chu", "dich", "trinhchieu"];
// Chế độ chạy bằng Gemini (gói miễn phí) khi câu hỏi không có thông tin cá nhân; lỗi hoặc hết hạn mức thì dùng Claude.
// Nhận xét học sinh, tin nhắn phụ huynh, biên bản họp luôn dùng Claude.
const GEMINI_MODES = ["hoi", "giaide", "detuongtu"];
// Thử lần lượt; gói miễn phí đôi lúc báo quá tải (503/429). "gemini-flash-latest" quá tải thường xuyên nên không dùng.
const GEMINI_MODELS = ["gemini-flash-lite-latest", "gemini-3.1-flash-lite"];

// Lượt mỗi máy mỗi ngày. Bản thử nghiệm để nhiều lượt.
// Dự kiến khi phát hành: miễn phí hoi 10, nhanxet 20, tinnhan 10; Pro có trần 100 mỗi loại.
const LIMITS = {
  // dich: mỗi lượt là một trang (app chia chữ thành đoạn khoảng 2.500 ký tự, mỗi ảnh hoặc trang PDF là một lượt)
  // trinhchieu: mỗi lượt là cả một bài trình chiếu (câu trả lời dài)
  free: { hoi: 100, nhanxet: 100, tinnhan: 100, giaide: 10, detuongtu: 10, bienban: 20, chep_chu: 30, dich: 20, danhgia: 20, trinhchieu: 5 },
  pro: { hoi: 100, nhanxet: 100, tinnhan: 100, giaide: 50, detuongtu: 50, bienban: 100, chep_chu: 100, dich: 100, danhgia: 50, trinhchieu: 30 },
};
const IP_LIMIT = 1000;       // trần mỗi địa chỉ mạng mỗi ngày (cả trường dùng chung wifi)
const BONUS_PER_AD = 5;      // xem một quảng cáo nhận thưởng được thêm 5 lượt
const MAX_ADS_PER_DAY = 10;  // tối đa 10 quảng cáo nhận thưởng mỗi ngày
const ADMOB_KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const TTS_MAX_CHARS = 1000;    // ký tự mỗi lần đọc (app chia nhỏ, đoạn đầu ngắn để đọc sớm)
const TTS_DAY_CHARS = 30000;   // ký tự mỗi máy mỗi ngày (khoảng 15 trang), Google miễn phí 4 triệu ký tự/tháng
const TTS_VOICE = "vi-VN-Wavenet-A";
// Gemini đọc thành tiếng, giọng Kore. Gói miễn phí mỗi mô hình chỉ 3 lượt/phút, 10 lượt/ngày, tính chung cả dự án
// (xem trên AI Studio 24/11/2026); hết lượt mô hình này thì chuyển sang mô hình khác.
// Không dùng gemini-3.1-flash-tts-preview: để dành 10 lượt/ngày của mô hình này cho lồng tiếng clip
// Việt Nam Tiêu Điểm (cùng khóa, cùng dự án). Người dùng chốt 24/11/2026.
const TTS_GEMINI_MODELS = ["gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts", "gemini-2.5-flash-preview-tts"];
const TTS_GEMINI_VOICE = "Kore";
const TTS_NGHI_PHUT_MS = 60 * 1000; // hết lượt theo phút (hoặc không rõ loại) thì nghỉ mô hình đó 60 giây
const KEEP_MS = 3 * 86400 * 1000; // bộ đếm giữ 3 ngày rồi xóa

const CHUNG =
  "Bạn là Trợ lý số Giáo viên, trả lời bằng tiếng Việt, ngắn gọn, đúng mực, dễ hiểu. Gọi người dùng là thầy cô, xưng tôi. " +
  "Không bịa số liệu, số hiệu văn bản; không chắc thì nói rõ là cần kiểm tra văn bản gốc. " +
  "Từ 01/7/2025 không còn Phòng Giáo dục và Đào tạo, không còn cấp huyện: trường mầm non, tiểu học, THCS thuộc Ủy ban nhân dân xã, phường; trường THPT thuộc Sở Giáo dục và Đào tạo. Không nhắc Phòng GDĐT là nơi nhận, nơi duyệt. " +
  "Nếu câu hỏi có mã học sinh (HS01, HS02...) thì gọi học sinh bằng đúng mã đó. " +
  "Không nhắc người dùng về việc dùng mã, giữ bí mật hay quyền riêng tư; không hỏi tên thật của học sinh. " +
  "Câu hỏi ngắn hoặc chưa rõ ý thì đoán ý gần nhất và trả lời luôn, kèm một câu hỏi lại ngắn nếu cần. " +
  "Người dùng hay gõ vội trên điện thoại: sai chính tả, thiếu dấu, viết tắt (cip, clíp = clip; ko = không; gv = giáo viên; " +
  "hs = học sinh; vntđ = Việt Nam Tiêu Điểm; áp, ấp, ap khi nói về điện thoại, phần mềm = app); " +
  "nói bằng giọng thì máy chép có thể sai chữ. Hiểu theo nghĩa hợp ngữ cảnh nhất, không giảng giải về chữ gõ sai. " +
  "\"Việt Nam Tiêu Điểm\" là kênh clip tin giáo dục ngắn trên Facebook đi cùng app này; các clip xem ở mục Tin tức của app. " +
  "Khi có danh sách clip gửi kèm thì trả lời dựa vào danh sách đó.";

// Giới thiệu app cho Hỏi Trợ lý: danh sách tiện ích theo thứ tự trong app (lib/data/tien_ich.dart). Thêm, đổi tiện ích
// thì sửa ở đây (phép thử test/tro_ly_biet_tien_ich_test.dart báo khi thiếu). Chỉ ghi tiện ích đã có trong bản app
// thầy cô đang dùng, không ghi tiện ích chưa phát hành. Thêm 26/11/2026: trước đó Trợ lý trả lời chung chung khi
// thầy cô hỏi app có gì, không chỉ được tiện ích nào làm việc thầy cô cần.
const GIOI_THIEU_APP =
  " Về chính app Trợ lý số Giáo viên mà thầy cô đang dùng: miễn phí, không cần tạo tài khoản, dữ liệu lớp học, điểm, biên bản lưu ngay trên điện thoại. " +
  "Trang chủ có ô Hỏi AI và hai nhóm tiện ích Hành chính, Chuyên môn (bấm Khác hoặc Tất cả để xem đủ); gõ tên tiện ích vào ô Hỏi AI ở Trang chủ là mở thẳng. " +
  "Thanh dưới cùng có Hỏi Trợ lý, Tin tức (tin giáo dục, clip của kênh Việt Nam Tiêu Điểm), Trang chủ, Tệp của tôi (các tệp app đã tạo), Tài khoản. " +
  "Nhóm Hành chính: Họp, biên bản (ghi trong lúc họp, nói để ghi, chụp trang ghi chép; app trình bày thành biên bản Word, PDF); " +
  "Đánh giá, xếp loại (tự chấm điểm tháng, quý theo Nghị định 233/2026, cộng điểm cả năm, xuất phiếu xếp loại viên chức); " +
  "Sổ minh chứng (chụp lưu giấy khen, giấy chứng nhận theo nhóm, đến kỳ nộp hồ sơ xuất PDF, zip, danh mục Excel); " +
  "Công tác Đảng (nhắc lịch họp chi bộ, tính đảng phí, mở trang Dịch vụ công của Đảng, ứng dụng Sổ tay đảng viên, hỏi về công tác Đảng); " +
  "Quét PDF (chụp giấy tờ, app làm phẳng trang, gộp thành PDF); Ảnh thẻ (tách nền xanh, trắng, in 3x4, 4x6); " +
  "Giọng nói ⇄ Văn bản (máy đọc to văn bản, nói thành chữ); Ảnh sang Word (ảnh văn bản thành tệp Word sửa được); " +
  "Lịch, nhắc hạn (ghi việc, nhắc trước hạn nộp); Tính lương (lương, phụ cấp, ngày nâng bậc). " +
  "Nhóm Chuyên môn: Nhận xét học sinh (theo Thông tư 22, 27 sửa đổi bởi Thông tư 89/2026, cả lớp, điểm trung bình môn, xuất Excel); " +
  "Chấm trắc nghiệm (đáp án nhiều mã đề, app chấm, thống kê câu sai); Nhắn phụ huynh (tin mẫu, AI soạn, gửi Zalo); " +
  "Giơ thẻ (in thẻ cho cả lớp, chụp một tấm biết em nào chọn đáp án nào); " +
  "Giải đề, soạn đáp án (chụp đề, lời giải từng bước, thang điểm, đề tương tự); " +
  "Tạo bài trình chiếu (chọn tệp giáo án Word, PDF hoặc chụp giáo án, app dựng bài trình chiếu theo các hoạt động của giáo án, ra tệp PowerPoint, PDF); Ô chữ (ô chữ mỗi ngày, tự tạo ô chữ ôn bài); " +
  "Dịch tài liệu (dán chữ, chụp trang sách, tệp PDF, Word; song ngữ; ra Word, PDF); Công cụ trên lớp (điểm danh, gọi tên, chia nhóm, đồng hồ, thử thách cả lớp). " +
  "Ngay trong ô Hỏi AI, Trợ lý soạn được giáo án (kế hoạch bài dạy) theo khung của từng cấp học: thầy cô gõ môn, lớp, tên bài, số tiết, bộ sách " +
  "(ví dụ: Soạn giáo án Ngữ văn 6 bài Thánh Gióng, 2 tiết, Kết nối tri thức); soạn xong có thể dán giáo án vào tiện ích Tạo bài trình chiếu. " +
  "Việc thầy cô hỏi làm được bằng một tiện ích trên thì trả lời ngắn rồi chỉ đúng tên tiện ích và nhóm để mở " +
  "(ví dụ: Thầy cô mở tiện ích Chấm trắc nghiệm ở nhóm Chuyên môn trên Trang chủ). " +
  "Được hỏi app là gì, có gì thì kể ngắn theo hai nhóm, mỗi nhóm vài tiện ích tiêu biểu, rồi hỏi thầy cô cần làm việc gì. " +
  "Không nhận app làm được việc không có trong danh sách này.";

const SYSTEM = {
  hoi:
    CHUNG +
    GIOI_THIEU_APP +
    " Trả lời mọi câu hỏi của người dùng một cách hữu ích. " +
    "Không dùng LaTeX, không dùng ký hiệu $ bao công thức; viết phép tính bằng ký hiệu thường (5% + 2% = 7%, x², √). " +
    "Ngày giờ hiện tại đã cho ở cuối hướng dẫn này, dùng nó khi được hỏi ngày, giờ, thứ, đếm ngày. " +
    "Câu hỏi có kèm kết quả tìm trên mạng thì trả lời dựa vào đó và ghi nguồn. " +
    "Không có kết quả tìm kèm theo thì bạn không có dữ liệu thời gian thực: hỏi giá cả, tỷ giá, thời tiết, tin tức hôm nay " +
    "thì nói rõ là không có số liệu mới và gợi ý nơi tra cứu, không đoán số.",
  nhanxet:
    CHUNG +
    " Nhiệm vụ: viết nhận xét học sinh cho giáo viên từ các ý giáo viên đưa vào. " +
    "Lời văn tích cực, cụ thể, có điểm mạnh và điều cần cố gắng, phù hợp quy định đánh giá học sinh hiện hành: " +
    "Thông tư 27/2020/TT-BGDĐT (tiểu học), Thông tư 22/2021/TT-BGDĐT (THCS, THPT), cả hai sửa đổi bởi Thông tư 89/2026/TT-BGDĐT (hiệu lực 01/12/2026). " +
    "Học sinh khuyết tật: nhận xét theo kế hoạch giáo dục cá nhân, dựa trên sự tiến bộ của chính em, động viên sự cố gắng vượt khó, không so sánh với bạn khác. " +
    "Nhận xét dùng được để đưa vào Học bạ số. " +
    "Chỉ trả về đoạn nhận xét, không thêm lời giải thích.",
  tinnhan:
    CHUNG +
    " Nhiệm vụ: soạn tin nhắn giáo viên gửi phụ huynh từ các ý giáo viên đưa vào. " +
    "Lời lẽ lịch sự, tôn trọng, rõ việc, ngắn (dưới 120 chữ). Chỉ trả về nội dung tin nhắn, không dùng markdown. " +
    "Giữ nguyên từng chữ các chỗ trống trong ngoặc vuông giáo viên đưa ra, như [tên học sinh], [họ tên], [lớp]; " +
    "không đổi thành [mã học sinh] hay chữ khác.",
  giaide:
    CHUNG +
    " Nhiệm vụ: làm đáp án và hướng dẫn chấm từ đề bài (ảnh hoặc chữ), theo chương trình GDPT 2018. " +
    "Chỗ ảnh mờ, không đọc chắc thì ghi '(không đọc rõ)', không đoán. Với từng câu: chép lại đề ngắn gọn, " +
    "lời giải từng bước theo cách học sinh lớp đó được học, đáp số; bài tự luận thêm gợi ý thang điểm. " +
    "Kiểm tra lại phép tính. Viết công thức bằng ký hiệu thường (x², √, ≤, π), không dùng LaTeX, không dùng markdown. " +
    "Nếu đề có câu trắc nghiệm, cuối bài thêm đúng một dòng: 'ĐÁP ÁN TRẮC NGHIỆM: 1A 2C 3B …'.",
  detuongtu:
    CHUNG +
    " Nhiệm vụ: ra đề tương tự từ đề mẫu (ảnh hoặc chữ). Giữ dạng bài, mức độ, kiến thức từng câu; " +
    "đổi số liệu, ngữ cảnh, bảo đảm có đáp án đúng. Trả về đề mới đánh số như đề mẫu, sau đó phần 'ĐÁP ÁN' ngắn gọn. " +
    "Không dùng LaTeX, không dùng markdown. Có câu trắc nghiệm thì cuối bài thêm đúng một dòng: 'ĐÁP ÁN TRẮC NGHIỆM: 1A 2C 3B …'.",
  bienban:
    CHUNG +
    " Nhiệm vụ: viết lại ghi chép cuộc họp trong nhà trường thành nội dung biên bản. Văn phong hành chính, khách quan, " +
    "ngôi thứ ba, đúng ý từng người phát biểu, không thêm ý, số liệu, tên người không có trong ghi chép. " +
    "Trả về đúng hai phần: dòng 'NỘI DUNG:' rồi các đoạn diễn biến; dòng 'KẾT LUẬN:' rồi kết luận, phân công, thời hạn " +
    "(không có kết luận thì tóm tắt việc đã thống nhất). Không dùng markdown.",
  // Biên bản: chép chữ từ ảnh chụp sổ ghi chép, tệp PDF (thầy cô đồng ý gửi trong app trước khi gửi). Luôn đi Claude.
  chep_chu:
    "Bạn chép lại chữ trong ảnh, tệp PDF cho giáo viên Việt Nam (ghi chép cuộc họp, biên bản viết tay hoặc in). " +
    "Chép đúng nguyên văn, đủ, theo thứ tự đọc; mỗi ý, mỗi dòng ghi chép thành một dòng; giữ tên người, số liệu, giờ. " +
    "Không thêm, không bớt, không tóm tắt, không sửa ý, không sửa lỗi chính tả của người viết trừ khi chữ viết tay khó đọc. " +
    "Chữ không đọc rõ ghi [không rõ]. Ảnh không có chữ thì trả về đúng câu: Không thấy chữ trong ảnh. " +
    "Không dùng markdown, không giải thích, chỉ trả về phần chữ.",
  // Dịch tài liệu: dòng đầu của yêu cầu do app ghi (ngôn ngữ đích, kiểu dịch, song ngữ). Luôn đi Claude.
  dich:
    "Bạn dịch tài liệu cho giáo viên Việt Nam. Dòng đầu của yêu cầu cho biết ngôn ngữ đích, kiểu dịch, có song ngữ hay không; " +
    "phần sau dòng '---' (hoặc ảnh, tệp kèm theo) là nội dung cần dịch. " +
    "Dịch đầy đủ, đúng nghĩa, không bỏ sót, không tóm tắt, không thêm lời bình; giữ nguyên số liệu, tên riêng, công thức, số hiệu văn bản. " +
    "Thuật ngữ giáo dục dịch theo cách dùng phổ biến của ngành giáo dục Việt Nam (ví dụ Ministry of Education and Training là Bộ Giáo dục và Đào tạo). " +
    "Kiểu Sát nghĩa: bám câu chữ gốc, văn phong trang trọng. Kiểu Dễ hiểu: câu ngắn, từ ngữ đơn giản để học sinh đọc, vẫn đủ ý. " +
    "Giữ bố cục: mỗi đoạn gốc thành đúng một đoạn dịch, các đoạn cách nhau bằng một dòng trống, giữ thứ tự, đánh số, gạch đầu dòng. " +
    "Nội dung đã ở đúng ngôn ngữ đích thì chép lại nguyên văn. " +
    "Với ảnh, tệp PDF: yêu cầu song ngữ thì trả về hai phần, dòng 'NGUYÊN VĂN:' rồi chép đúng chữ trong ảnh, dòng 'BẢN DỊCH:' rồi bản dịch; " +
    "không song ngữ thì chỉ trả về bản dịch. Chữ không đọc rõ ghi [không rõ]. " +
    "Không dùng markdown (không dùng **, #), không giải thích, chỉ trả về nội dung.",
  // Đánh giá, xếp loại (26/11/2026): viết nháp mục Ưu điểm, Hạn chế của Phiếu xếp loại chất lượng viên chức (Phụ lục II NĐ 233/2026)
  danhgia:
    CHUNG +
    " Nhiệm vụ: viết nháp hai mục 'Ưu điểm' và 'Hạn chế' trong Phiếu xếp loại chất lượng viên chức theo mẫu Phụ lục II Nghị định số 233/2026/NĐ-CP, " +
    "dựa đúng vào danh sách việc được giao và mức hoàn thành giáo viên gửi kèm (khối lượng, chất lượng, tiến độ, điểm từng kỳ, ghi chú). " +
    "Viết ở ngôi thứ nhất kiểu văn bản tự đánh giá (không xưng tôi, viết thẳng việc), câu ngắn, cụ thể, nêu tên việc thật trong danh sách; " +
    "không bịa thành tích, số liệu, danh hiệu không có trong danh sách. Ưu điểm 3 đến 5 ý, Hạn chế 1 đến 3 ý; " +
    "việc trễ hạn, chưa đạt, làm chưa đủ thì đưa vào Hạn chế kèm hướng khắc phục ngắn; không có việc nào chưa tốt thì nêu hạn chế chung, nhẹ, có thật với nghề giáo. " +
    "Trả về đúng dạng: dòng 'ƯU ĐIỂM:' rồi mỗi ý một dòng bắt đầu bằng '- '; dòng 'HẠN CHẾ:' rồi mỗi ý một dòng bắt đầu bằng '- '. Không dùng markdown, không thêm lời giải thích.",
  // Tạo bài trình chiếu (26/11/2026): đọc giáo án (kế hoạch bài dạy), dựng dàn trang chiếu theo đúng các hoạt động của giáo án;
  // app tự dựng tệp PowerPoint, PDF từ JSON trả về (lib/data/trinh_chieu.dart đọc JSON này)
  trinhchieu:
    "Bạn giúp giáo viên Việt Nam làm bài trình chiếu (trang chiếu cho học sinh xem trên lớp) từ giáo án (kế hoạch bài dạy). " +
    "Dòng đầu của yêu cầu cho biết cấp học và số trang chiếu mong muốn; phần sau dòng '---' (hoặc ảnh, tệp kèm theo) là giáo án. " +
    "Dựng các trang theo đúng trình tự hoạt động của giáo án và khung kế hoạch bài dạy của cấp học: " +
    "THCS, THPT theo Phụ lục IV Công văn 5512/BGDĐT-GDTrH: Hoạt động 1 Mở đầu (xác định vấn đề), Hoạt động 2 Hình thành kiến thức mới " +
    "(giáo án chia nhiều mục thì mỗi mục một hoặc vài trang), Hoạt động 3 Luyện tập, Hoạt động 4 Vận dụng; " +
    "Tiểu học theo Công văn 2345/BGDĐT-GDTH: Khởi động (mở đầu), Khám phá (hình thành kiến thức mới), Luyện tập, thực hành, Vận dụng, trải nghiệm; " +
    "Mầm non: Gây hứng thú, Hoạt động chính, Kết thúc, chữ thật ít, câu thật ngắn. " +
    "Giáo án ghi tên hoạt động khác thì dùng đúng tên trong giáo án. " +
    "Nội dung lấy từ giáo án: câu hỏi, nhiệm vụ, kiến thức, ví dụ, bài tập thầy cô đã soạn; giữ đúng số liệu, công thức, tên riêng; " +
    "không thêm kiến thức ngoài giáo án. Giáo án chỉ có tên bài, chưa có nội dung thì dựng khung cơ bản theo các hoạt động trên " +
    "và ghi ở ghi_chu trang bìa: 'Nội dung do AI gợi ý từ tên bài, thầy cô đối chiếu sách giáo khoa.' " +
    "Trang đầu là bìa (loai bia): tieu_de là tên bài, y gồm môn, lớp (và tên giáo viên nếu giáo án có ghi). " +
    "Trang thứ hai là mục tiêu (loai muc_tieu) viết cho học sinh đọc, tieu_de 'Học xong bài này, em sẽ' (Mầm non, Tiểu học viết đơn giản hơn); " +
    "trang cuối là tổng kết, dặn dò (loai tong_ket) nếu giáo án có. " +
    "Trang có câu hỏi, bài tập (loai cau_hoi): ghi đề lên trang, đáp án, gợi ý chấm ghi vào ghi_chu, không ghi đáp án lên trang. " +
    "Trên trang chỉ ghi chữ học sinh cần đọc: tieu_de ngắn (dưới 60 ký tự), y tối đa 6 ý, mỗi ý dưới 90 ký tự. " +
    "Việc của giáo viên (chia nhóm, thời gian, cách tổ chức, đáp án, lưu ý) ghi vào ghi_chu, mỗi ý một dòng. " +
    "hoat_dong là nhãn nhỏ trên tiêu đề, ví dụ 'Hoạt động 1 · Mở đầu'; trang bìa để trống. " +
    "Giáo án có hoạt động năng lực số (dùng thiết bị số, phần mềm) thì giữ hoạt động đó. " +
    "Số trang gần đúng số mong muốn (hơn kém 2 trang), kể cả bìa. Công thức viết bằng chữ thường (a/b, x², √2), không dùng LaTeX, không dùng markdown. " +
    "Chỉ trả về đúng một đối tượng JSON, không thêm chữ nào khác, dạng: " +
    '{"tieu_de":"tên bài","mon":"môn","lop":"lớp","trang":[{"loai":"bia|muc_tieu|hoat_dong|cau_hoi|tong_ket","hoat_dong":"nhãn hoạt động",' +
    '"tieu_de":"tiêu đề trang","y":["ý 1","ý 2"],"ghi_chu":"lời dặn cho giáo viên"}]}',
};

// Câu mặc định gửi kèm ảnh, tệp khi thầy cô không gõ gì
const CAU_MAC_DINH = {
  hoi: "Giải thích nội dung trong tệp.",
  chep_chu: "Chép lại chữ trong ảnh, tệp.",
  dich: "Dịch sang: Tiếng Việt. Kiểu: Sát nghĩa. Song ngữ: không.",
  trinhchieu: "Cấp học: THCS. Số trang chiếu: khoảng 12.",
};

// ---- Soạn giáo án trong Hỏi Trợ lý (người dùng chốt 27/11/2026) ----
// Thầy cô gõ vào ô "Hỏi AI…" nhờ soạn giáo án: máy chủ nhận ra, đi thẳng Claude với hướng dẫn soạn theo khung
// kế hoạch bài dạy của từng cấp học, câu trả lời dài hơn câu hỏi thường. Thiếu môn, lớp, tên bài thì AI hỏi lại.
// Không làm tiện ích riêng; soạn xong thầy cô dán giáo án vào tiện ích Tạo bài trình chiếu để làm bài chiếu.
const GA_MAX_OUT = 10000;     // tiếng Việt khoảng 1,1 ký tự mỗi token: giáo án 2 tiết khoảng 2.000 chữ là 8.500 token, Haiku viết hết khoảng 40 giây (app chờ 60 giây)
const GA_MAX_IN = 12000;      // dán kèm giáo án cũ, nội dung bài để soạn lại
const GA_LIMIT = { free: 10, pro: 30 }; // số giáo án soạn xong mỗi máy mỗi ngày (câu hỏi lại không tính)
const GA_DAI = 2500;          // câu trả lời từ chừng này ký tự và có khung giáo án mới tính là một giáo án
const boDau = (s) => s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/đ/g, "d").replace(/Đ/g, "D").toLowerCase();
// So khớp trên chữ đã bỏ dấu, nên "giáo án", "giao an", "gíao án", "GIÁO ÁN" đều nhận
const GA_RE = /\bgiao an\b|\bkhbd\b|ke hoach bai (day|hoc)|ke hoach (to chuc )?hoat dong (hoc|giao duc|choi|cho tre|lam quen|kham pha|phat trien)|thiet ke bai (day|hoc|giang)|soan giang|lesson plan|\bgiao an (mam non|tieu hoc|thcs|thpt)|(phu luc (iv|4) (cong van |cv )?5512)|(phu luc (3|iii) (cong van |cv )?2345)/;
// "soạn bài", "soạn tiết" chỉ tính khi có dấu hiệu bài học (lớp, tiết, sách, môn)
const GA_SOAN_RE = /\bsoan (bai|tiet|tiep tiet)\b/;
const GA_BAI_HOC_RE = /\blop \d|\btiet \d|\bsgk\b|sach giao khoa|ket noi tri thuc|chan troi sang tao|canh dieu|bo sach|\bmon (toan|van|ngu van|tieng|khoa|lich su|dia|vat ly|hoa|sinh|tin|cong nghe|gdcd|giao duc|am nhac|my thuat|hoat dong|the duc)|\bmam non\b|\bmau giao\b|\bnha tre\b|\btre \d/;
// Bài trình chiếu, phát biểu, bài viết... không phải giáo án: để Hỏi Trợ lý trả lời như thường (chỉ tiện ích Tạo bài trình chiếu)
const GA_KHONG_RE = /trinh chieu|powerpoint|\bppt\b|\bslide|giao an dien tu|phat bieu|dien van|tham luan|bai bao|bai tho|\bthu (moi|cam on|chuc)/;
// Câu trả lời trước của Trợ lý là giáo án hoặc câu hỏi lại để soạn giáo án: câu tiếp theo (vd "Ngữ văn 6, Thánh Gióng, 2 tiết",
// "viết tiếp", "thêm trò chơi khởi động") vẫn thuộc việc soạn giáo án
const GA_DAU_RE = /de soan giao an|ke hoach bai day|tien trinh day hoc|cac hoat dong day hoc chu yeu|giao an do ai soan/;
// Khung có trong giáo án đã soạn (để đếm số giáo án mỗi ngày)
const GA_KHUNG_RE = /ke hoach bai day|ke hoach hoat dong|tien trinh day hoc|cac hoat dong day hoc chu yeu/;

function laSoanGiaoAn(input, hist = []) {
  const t = boDau(input);
  if (GA_KHONG_RE.test(t)) return false;
  if (GA_RE.test(t) || (GA_SOAN_RE.test(t) && GA_BAI_HOC_RE.test(t))) return true;
  const truoc = hist[hist.length - 1];
  if (!truoc) return false;
  const tq = boDau(truoc.q);
  const gaTruoc = (GA_RE.test(tq) && !GA_KHONG_RE.test(tq)) || GA_DAU_RE.test(boDau(truoc.a));
  // Đang soạn giáo án mà thầy cô chuyển sang hỏi chế độ, thủ tục... thì trả lời như câu hỏi thường
  // (câu có dấu hiệu bài học như "lớp 6, 2 tiết" vẫn là trả lời cho câu hỏi lại của Trợ lý)
  const l = input.toLowerCase();
  return gaTruoc && (GA_BAI_HOC_RE.test(t) || (!CHE_DO_RE.test(l) && !KHAC_RE.test(l)));
}

const SOAN_GA =
  " Nhiệm vụ lúc này: soạn giáo án (kế hoạch bài dạy) cho thầy cô theo Chương trình giáo dục phổ thông 2018 (Mầm non theo Chương trình giáo dục mầm non). " +
  "Cần đủ ba thông tin: môn học (Mầm non: lĩnh vực hoặc hoạt động), lớp (Mầm non: độ tuổi hoặc nhóm lớp), tên bài (hoặc chủ đề). " +
  "Thiếu một trong ba thì chưa soạn, trả lời ngắn, mở đầu đúng câu 'Để soạn giáo án, thầy cô cho tôi biết thêm:' rồi nêu thông tin còn thiếu, " +
  "hỏi thêm số tiết và bộ sách (Kết nối tri thức với cuộc sống, Chân trời sáng tạo, Cánh diều...), kèm một câu gõ mẫu như " +
  "'Ngữ văn 6, bài Thánh Gióng, 2 tiết, Kết nối tri thức' (Mầm non không hỏi số tiết, bộ sách; mẫu như 'Mầm non 4-5 tuổi, làm quen chữ cái o, ô, ơ'). " +
  "Đủ ba thông tin thì soạn luôn, không hỏi thêm: chưa có số tiết thì lấy 1 tiết (bài đọc hiểu văn bản dài lấy 2 tiết); chưa có bộ sách thì soạn theo yêu cầu cần đạt của chương trình môn học; " +
  "chỉ khi có điều tự chọn như vậy mới ghi một dòng in nghiêng ngay dưới phần đầu (thông tin thầy cô đã cho thì không ghi là tự chọn). " +
  "Bài từ 3 tiết trở lên: soạn hai tiết đầu, cuối phần đó ghi 'Thầy cô gõ \"soạn tiếp tiết 3\" để soạn phần còn lại.' " +
  "Thầy cô gửi kèm ảnh, tệp trang sách hoặc giáo án cũ thì bám đúng nội dung đó. Thầy cô có yêu cầu riêng (trò chơi, làm việc nhóm, phiếu học tập, tích hợp...) thì làm theo.\n" +
  "Khung trình bày theo cấp học:\n" +
  "- THCS, THPT: theo Phụ lục IV Công văn 5512/BGDĐT-GDTrH ngày 18/12/2020. Phần đầu: Trường, Tổ, Họ và tên giáo viên (để dấu chấm cho thầy cô điền); " +
  "tiêu đề KẾ HOẠCH BÀI DẠY; tên bài dạy; Môn học/Hoạt động giáo dục, lớp; Thời gian thực hiện (số tiết). " +
  "I. Mục tiêu: 1. Về kiến thức; 2. Về năng lực (năng lực chung, năng lực đặc thù); 3. Về phẩm chất; nêu cụ thể học sinh làm được gì theo yêu cầu cần đạt. " +
  "II. Thiết bị dạy học và học liệu. III. Tiến trình dạy học: Hoạt động 1: Mở đầu (xác định vấn đề, nhiệm vụ học tập); " +
  "Hoạt động 2: Hình thành kiến thức mới (chia 2.1, 2.2... theo các nội dung của bài); Hoạt động 3: Luyện tập; Hoạt động 4: Vận dụng. " +
  "Mỗi hoạt động ghi tên kèm thời gian và đủ bốn mục a) Mục tiêu, b) Nội dung, c) Sản phẩm, d) Tổ chức thực hiện; " +
  "d) theo bốn bước: Chuyển giao nhiệm vụ; Thực hiện nhiệm vụ; Báo cáo, thảo luận; Kết luận, nhận định. " +
  "Mô tả việc giáo viên và học sinh làm (giao nhiệm vụ, quan sát, hướng dẫn, nhận xét; đọc, viết, thảo luận, trình bày), không viết lời thoại. " +
  "c) Sản phẩm ghi cụ thể kết quả, đáp án mong đợi. Bài nhiều tiết thì ghi rõ tiết nào gồm hoạt động nào.\n" +
  "- Tiểu học: theo Phụ lục 3 Công văn 2345/BGDĐT-GDTH ngày 07/6/2021. Phần đầu: tiêu đề KẾ HOẠCH BÀI DẠY; Môn học/Hoạt động giáo dục, lớp; " +
  "Tên bài học; Số tiết; Thời gian thực hiện (để dấu chấm). I. Yêu cầu cần đạt (học sinh làm được gì, vận dụng được gì; phẩm chất, năng lực được hình thành). " +
  "II. Đồ dùng dạy học (của giáo viên, của học sinh). III. Các hoạt động dạy học chủ yếu: 1. Hoạt động Mở đầu (khởi động, kết nối); " +
  "2. Hoạt động Hình thành kiến thức mới (trải nghiệm, khám phá, phân tích); 3. Hoạt động Luyện tập, thực hành; 4. Hoạt động Vận dụng, trải nghiệm (nếu có); " +
  "mỗi hoạt động ghi thời gian, một dòng mục tiêu, rồi từng bước ghi 'Giáo viên:' và 'Học sinh:' (không chia a) b) c) d), đó là khung THCS, THPT). IV. Điều chỉnh sau bài dạy (để dòng chấm cho thầy cô ghi).\n" +
  "- Mầm non: không có tiết, không có bộ sách; thời gian một hoạt động học khoảng 10–15 phút (nhà trẻ), 15–20 phút (3–4 tuổi), 20–25 phút (4–5 tuổi), 25–30 phút (5–6 tuổi); " +
  "việc vừa sức độ tuổi (tập tô chữ dành cho trẻ 5–6 tuổi). Phần đầu tiêu đề KẾ HOẠCH HOẠT ĐỘNG; tên hoạt động, lĩnh vực, độ tuổi, thời gian; I. Mục đích, yêu cầu (kiến thức, kỹ năng, thái độ); " +
  "II. Chuẩn bị (đồ dùng của cô, của trẻ, địa điểm); III. Tiến hành: 1. Ổn định, gây hứng thú; 2. Nội dung chính (chia các hoạt động nhỏ, học bằng chơi, có trò chơi); 3. Kết thúc. Câu ngắn, dễ làm theo.\n" +
  "Câu hỏi, bài tập ghi đủ đề và đáp án; tự kiểm lại phép tính; đáp án phải khớp đúng câu hỏi. " +
  "Năng lực số (Thông tư 02/2025/TT-BGDĐT): chỉ khi thầy cô yêu cầu tích hợp năng lực số thì mới ghi mục này và ghi rõ năng lực số phát triển ở hoạt động nào. " +
  "Không bịa nội dung sách giáo khoa: không chép dài văn bản, ngữ liệu trong sách; không ghi số trang, số thứ tự bài tập trong sách khi không chắc; " +
  "câu hỏi, trò chơi về tác phẩm, bài đọc chỉ dùng chi tiết chắc chắn có trong tác phẩm, không chắc thì hỏi khái quát; " +
  "chỗ cần đối chiếu thì ghi '(đối chiếu sách giáo khoa)'. " +
  "Trình bày cho màn hình điện thoại: tiêu đề lớn dùng ##, tên hoạt động dùng ###, ý dùng gạch đầu dòng, chữ đậm cho a) b) c) d); không dùng bảng, không dùng LaTeX. " +
  "Viết đủ mà gọn để vừa một lần trả lời: 1 tiết khoảng 900 đến 1.100 chữ, 2 tiết khoảng 1.600 đến 2.000 chữ, không quá 2.100 chữ; " +
  "mỗi bước tổ chức thực hiện một đến hai câu, không nhắc lại ý đã ghi ở mục khác. " +
  "Cuối giáo án thêm đúng hai dòng: 'Giáo án do AI soạn, thầy cô đọc lại, chỉnh sửa cho hợp với lớp mình trước khi dùng.' và " +
  "'Muốn làm bài trình chiếu: chọn tất cả, sao chép giáo án này rồi dán vào ô Hoặc dán nội dung giáo án của tiện ích Tạo bài trình chiếu (nhóm Chuyên môn).' " +
  "Thầy cô nhờ sửa, thêm một phần của giáo án vừa soạn thì chỉ viết lại phần đó; nhờ viết tiếp thì viết tiếp từ chỗ dừng, không viết lại từ đầu. " +
  "Thầy cô chỉ hỏi về quy định, cách làm giáo án (không nhờ soạn) thì trả lời ngắn như câu hỏi thường.";

// Ngày giờ Việt Nam gắn vào cuối hướng dẫn hệ thống để AI trả lời đúng câu hỏi về ngày tháng
function ngayGioVN(now = new Date()) {
  const vn = new Date(now.getTime() + 7 * 3600 * 1000);
  const thu = ["Chủ nhật", "Thứ hai", "Thứ ba", "Thứ tư", "Thứ năm", "Thứ sáu", "Thứ bảy"][vn.getUTCDay()];
  const h = (n) => String(n).padStart(2, "0");
  return " Hiện tại ở Việt Nam là " + thu + ", ngày " + h(vn.getUTCDate()) + "/" + h(vn.getUTCMonth() + 1) +
    "/" + vn.getUTCFullYear() + ", " + h(vn.getUTCHours()) + " giờ " + h(vn.getUTCMinutes()) + ".";
}
function sysOf(mode, now = new Date()) {
  return SYSTEM[mode] + ngayGioVN(now);
}
function sysGiaoAn(now = new Date()) {
  return CHUNG + SOAN_GA + ngayGioVN(now);
}

// Hỏi về kênh Việt Nam Tiêu Điểm: máy chủ tự kèm danh sách clip (mọi bản app đều dùng được) và dặn trả lời đúng câu hỏi
const HOI_KENH = /ti[eê]u\s*đi[eể]m|vntđ|vntd|(clip|cip|video|tin|kênh)\s+(của|trong|trên)\s+app/i;
function kemTinKenh(mode, input) {
  if (mode !== "hoi" || !HOI_KENH.test(input) || input.includes("Các clip gần đây")) return input;
  const ds = TIN.filter((t) => !t.nguon).slice(0, 15).map((t) => "- " + t.ngay.slice(8, 10) + "/" + t.ngay.slice(5, 7) + ': "' + t.tit + '" ' + t.tom_tat.slice(0, 160));
  return input + "\n\n(Thông tin kèm theo để trả lời, không nhắc lại phần này: \"Việt Nam Tiêu Điểm\" là kênh clip tin giáo dục ngắn " +
    "đi cùng app, xem trong mục Tin tức của app. Trả lời đúng điều được hỏi: hỏi clip nào hay thì chọn hẳn một clip cụ thể, " +
    "ghi đúng nguyên văn tít trong ngoặc kép và nêu lý do ngắn, có thể gợi ý thêm một clip; không né, không trả lời chung chung. " +
    "Các clip gần đây, mới nhất trước:\n" + ds.join("\n") + ")";
}

// Các lượt hỏi đáp trước trong cùng cuộc trò chuyện (chỉ Hỏi Trợ lý), tối đa 4 lượt, mỗi phần tối đa 2.000 ký tự
// Câu hỏi về lương, phụ cấp, chế độ, chính sách của thầy cô đi thẳng Claude (người dùng chốt 20/11/2026):
// Gemini bản nhẹ trả lời "không có dữ liệu" về Nghị định 182/2026 khi thử 20/11.
const CHE_DO_RE = new RegExp(
  [
    "lương", "luong", "phụ cấp", "phu cap", "chế độ", "che do", "chính sách", "chinh sach",
    "thâm niên", "tham nien", "ưu đãi", "uu dai", "truy lĩnh", "truy linh", "hệ số", "he so",
    "bậc", "nâng bậc", "nang bac", "hạng", "thăng hạng", "thang hang", "xếp lương", "xep luong",
    "bổ nhiệm", "bo nhiem", "chức danh", "chuc danh", "thưởng", "thuong tet", "nghỉ hưu", "nghi huu",
    "hưu trí", "huu tri", "bảo hiểm", "bao hiem", "bhxh", "bhyt", "thai sản", "thai san",
    "nghị định", "nghi dinh", "thông tư", "thong tu", "luật nhà giáo", "luat nha giao", "nghị quyết", "nghi quyet",
    "định mức", "dinh muc", "tiết dạy", "tiet day", "dạy thêm giờ", "vượt giờ", "vuot gio", "kiêm nhiệm", "kiem nhiem",
    "tuyển dụng", "tuyen dung", "biên chế", "bien che", "hợp đồng", "hop dong", "thôi việc", "thoi viec",
    "kỷ luật", "ky luat", "học phí", "hoc phi", "trợ cấp", "tro cap", "hỗ trợ", "ho tro",
    "dạy thêm", "day them", "học thêm", "hoc them", "nghỉ hè", "nghi he", "nghỉ phép", "nghi phep",
    "chủ nhiệm", "chu nhiem", "giảm tiết", "giam tiet", "điều lệ", "dieu le", "chuẩn nghề nghiệp", "chuan nghe nghiep",
    "thuyên chuyển", "thuyen chuyen", "điều động", "dieu dong", "thi đua", "thi dua", "khen thưởng", "khen thuong",
    "giờ dạy", "gio day", "tập sự", "tap su", "nghỉ ốm", "nghi om",
    "tuyển sinh", "tuyen sinh", "vào lớp 10", "vao lop 10", "vào lớp 6", "vao lop 6", "thi tốt nghiệp", "thi tot nghiep",
    "tốt nghiệp thpt", "tot nghiep thpt", "xét tốt nghiệp", "xet tot nghiep", "quy chế thi", "quy che thi", "quy chế tuyển", "quy che tuyen",
    "miễn thi", "mien thi", "đặc cách", "dac cach", "điểm ưu tiên", "diem uu tien", "cộng điểm", "cong diem",
    "điểm khuyến khích", "diem khuyen khich", "phúc khảo", "phuc khao", "bảo lưu điểm", "bao luu diem",
    "bao nhiêu tiết", "bao nhieu tiet", "số tiết", "so tiet", "tiết một tuần", "tiết mỗi tuần", "tiết/tuần", "tiet/tuan",
    "tổng phụ trách", "tong phu trach", "tổ trưởng", "to truong", "nhiệm vụ của giáo viên", "quyền của giáo viên",
    "thỉnh giảng", "thinh giang", "mã số chức danh", "ma so chuc danh", "bằng tốt nghiệp", "bang tot nghiep",
  ].map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|"),
  "i",
);
// Các loại câu khác cũng đi Claude (người dùng chốt 20/11/2026): thủ tục, hồ sơ, văn bản hành chính;
// tình huống nhạy cảm với học sinh; đánh giá, xếp loại theo Thông tư 22, 27; pháp luật nói chung.
const KHAC_RE = new RegExp(
  [
    "thủ tục", "thu tuc", "hồ sơ", "ho so", "tờ trình", "to trinh", "công văn", "cong van", "đơn xin", "don xin",
    "đơn đề nghị", "don de nghi", "đơn kiến nghị", "khiếu nại", "khieu nai", "biên bản", "quyết định", "quyet dinh",
    "bạo lực", "bao luc", "đánh nhau", "danh nhau", "bắt nạt", "bat nat", "xâm hại", "xam hai", "quấy rối", "quay roi",
    "tự tử", "tu tu", "tự sát", "tự hại", "tu hai", "tự làm đau", "trầm cảm", "tram cam", "rạch tay", "bỏ nhà", "bo nha",
    "ma túy", "ma tuy", "mang thai", "có thai", "phụ huynh dọa", "phụ huynh đánh", "phụ huynh chửi",
    "thông tư 22", "thong tu 22", "thông tư 27", "thong tu 27", "xếp loại", "xep loai", "học bạ", "hoc ba",
    "đánh giá học sinh", "danh gia hoc sinh", "khen thưởng học sinh", "lên lớp", "len lop", "ở lại lớp", "o lai lop", "rèn luyện hè",
    "pháp luật", "phap luat", "luật ", "luat ", "đất đai", "dat dai", "sổ đỏ", "so do", "thừa kế", "thua ke", "ly hôn", "ly hon",
    "vi phạm giao thông", "phạt nguội", "phat nguoi", "xử phạt", "xu phat", "tòa án", "toa an", "công an", "cong an", "lừa đảo", "lua dao",
  ].map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|"),
  "i",
);

function laCauCheDo(input, hist) {
  const t = [input, ...hist.slice(-2).map((h) => h.q)].join("\n").toLowerCase();
  return CHE_DO_RE.test(t) || KHAC_RE.test(t);
}

function historyOf(body, mode) {
  if (mode !== "hoi" || !Array.isArray(body.history)) return [];
  return body.history
    .filter((t) => t && typeof t.q === "string" && typeof t.a === "string" && t.q.trim() && t.a.trim())
    .slice(-4)
    .map((t) => ({ q: t.q.trim().slice(0, 2000), a: catTraLoi(t.a.trim()) }));
}
// Câu trả lời dài giữ 2.000 ký tự. Riêng giáo án giữ phần đầu và phần cuối, để "viết tiếp" biết đã dừng ở đâu.
function catTraLoi(a) {
  if (a.length <= 2000) return a;
  if (!GA_DAU_RE.test(boDau(a.slice(0, 1500)))) return a.slice(0, 2000);
  return a.slice(0, 500) + "\n…\n" + a.slice(-1500);
}

// Đóng gói âm thanh PCM 16 bit (Gemini trả về dạng thô) thành tệp WAV để điện thoại phát được
function pcmToWavB64(b64, rate = 24000) {
  const pcm = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const h = new DataView(new ArrayBuffer(44));
  const s = (o, t) => [...t].forEach((c, i) => h.setUint8(o + i, c.charCodeAt(0)));
  s(0, "RIFF"); h.setUint32(4, 36 + pcm.length, true); s(8, "WAVE"); s(12, "fmt ");
  h.setUint32(16, 16, true); h.setUint16(20, 1, true); h.setUint16(22, 1, true);
  h.setUint32(24, rate, true); h.setUint32(28, rate * 2, true); h.setUint16(32, 2, true); h.setUint16(34, 16, true);
  s(36, "data"); h.setUint32(40, pcm.length, true);
  const all = new Uint8Array(44 + pcm.length);
  all.set(new Uint8Array(h.buffer), 0); all.set(pcm, 44);
  let bin = "";
  for (let i = 0; i < all.length; i += 0x8000) bin += String.fromCharCode(...all.subarray(i, i + 0x8000));
  return btoa(bin);
}

// ---- Ghi nhớ mô hình Gemini đọc thành tiếng đã hết lượt ----
// Lưu trong bảng flags: k = 'tts_het:<mô hình>', v = thời điểm (mili giây) được gọi lại.
// Nhờ vậy khi đã hết lượt, máy chủ trả lời ngay, không gọi Google vô ích, app chuyển thẳng sang giọng cài sẵn.

// Lượt theo ngày của Gemini đặt lại lúc 0 giờ giờ Thái Bình Dương (15 giờ Việt Nam mùa đông, 14 giờ mùa hè).
// Ngày đổi giờ mùa hè có thể lệch tối đa 1 giờ: gọi sớm thì Google báo hết lượt và máy chủ ghi nhớ lại, không sao.
function gioDatLaiGemini(now = Date.now()) {
  try {
    const p = Object.fromEntries(
      new Intl.DateTimeFormat("en-US", {
        timeZone: "America/Los_Angeles", hourCycle: "h23", hour: "2-digit", minute: "2-digit", second: "2-digit",
      }).formatToParts(new Date(now)).map((x) => [x.type, x.value])
    );
    const daQua = ((Number(p.hour) * 60 + Number(p.minute)) * 60 + Number(p.second)) * 1000 + (now % 1000);
    return now - daQua + 86400 * 1000 + 60 * 1000; // thêm 1 phút cho chắc
  } catch {
    return now + 3600 * 1000;
  }
}

// Đọc lời báo 429 của Gemini: hết lượt theo ngày thì nghỉ đến giờ đặt lại; theo phút thì nghỉ theo
// thời gian Google gợi ý (retryDelay, tối đa 2 phút); không rõ loại thì nghỉ 60 giây.
function nghiDen(baoLoi, now = Date.now()) {
  const s = JSON.stringify(baoLoi || {});
  if (/PerDay|per_day|requests_per_day|per_model_per_day/i.test(s)) return gioDatLaiGemini(now);
  const giay = parseFloat((s.match(/"retryDelay"\s*:\s*"([\d.]+)s"/) || [])[1] || "");
  if (giay > 0) return now + Math.min(120, Math.max(5, giay)) * 1000;
  return now + TTS_NGHI_PHUT_MS;
}

async function ttsNghi(db) {
  try {
    const r = await db.prepare("SELECT k, v FROM flags WHERE k LIKE 'tts_het:%'").all();
    const out = {};
    for (const row of (r && r.results) || []) out[String(row.k).slice(8)] = Number(row.v) || 0;
    return out;
  } catch {
    return {};
  }
}

async function ghiNghi(db, model, den) {
  try {
    await db
      .prepare("INSERT INTO flags (k, v) VALUES (?1, ?2) ON CONFLICT(k) DO UPDATE SET v = ?2")
      .bind("tts_het:" + model, String(den))
      .run();
  } catch {
    // ghi không được thì lần sau gọi Google lại, chỉ chậm hơn một chút
  }
}

function hetLuotChung(nghi, now = Date.now()) {
  const som = Math.min(...TTS_GEMINI_MODELS.map((m) => nghi[m] || now));
  const msg = som - now > 10 * 60 * 1000
    ? "Giọng đọc qua mạng tạm hết lượt miễn phí trong ngày, sau " + gioVN(new Date(som)).slice(0, 6) + " thầy cô dùng lại được."
    : "Giọng đọc qua mạng tạm hết lượt miễn phí, thầy cô thử lại sau ít phút.";
  return { err: "het_luot_chung", msg, status: "nghi" };
}

async function ttsGemini(env, text, db) {
  let last = { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: "" };
  const nghi = await ttsNghi(db);
  const con = TTS_GEMINI_MODELS.filter((m) => !((nghi[m] || 0) > Date.now()));
  if (!con.length) return hetLuotChung(nghi); // mọi mô hình đang nghỉ: trả lời ngay
  for (const model of con) {
    let r;
    try {
      r = await env.GEMINI.fetch("https://gemini/", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          model,
          timeout: 40000,
          body: {
            contents: [{ parts: [{ text }] }],
            generationConfig: {
              responseModalities: ["AUDIO"],
              speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: TTS_GEMINI_VOICE } } },
            },
          },
        }),
      });
    } catch {
      last = { err: "loi_mang", msg: "Chưa đọc được, thầy cô thử lại.", status: "mang" };
      continue;
    }
    if (!r.ok) {
      if (r.status === 429) {
        const den = nghiDen(await r.json().catch(() => null));
        await ghiNghi(db, model, den);
        nghi[model] = den;
        last = { ...hetLuotChung(nghi), status: model + ":429:" + (den - Date.now() > 10 * 60 * 1000 ? "ngay" : "phut") };
      } else {
        last = { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: model + ":" + r.status };
      }
      continue; // mỗi mô hình có hạn mức riêng, thử mô hình kế tiếp
    }
    const j = await r.json();
    const p = ((((j.candidates || [])[0] || {}).content || {}).parts || []).find((x) => x.inlineData);
    if (!p) { last = { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: model + ":rong" }; continue; }
    const mime = String(p.inlineData.mimeType || "").toLowerCase();
    if (mime.includes("wav")) return { audio: p.inlineData.data, mime: "audio/wav", by: "gemini", model };
    const rate = parseInt((mime.match(/rate=(\d+)/) || [])[1] || "24000", 10);
    return { audio: pcmToWavB64(p.inlineData.data, rate), mime: "audio/wav", by: "gemini", model };
  }
  return last;
}

async function ttsGoogle(env, text, rateIn) {
  const rate = Math.min(2, Math.max(0.5, Number(rateIn) || 1));
  let r;
  try {
    r = await fetch("https://texttospeech.googleapis.com/v1/text:synthesize?key=" + encodeURIComponent(env.GOOGLE_TTS_KEY), {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        input: { text },
        voice: { languageCode: "vi-VN", name: TTS_VOICE },
        audioConfig: { audioEncoding: "MP3", speakingRate: rate },
      }),
    });
  } catch {
    return { err: "loi_mang", msg: "Chưa đọc được, thầy cô thử lại.", status: "mang" };
  }
  if (!r.ok) return { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: "google:" + r.status };
  const audio = (await r.json()).audioContent;
  if (!audio) return { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: "google:rong" };
  return { audio, mime: "audio/mpeg", by: "google" };
}

function gioVN(now = new Date()) {
  const v = new Date(now.getTime() + 7 * 3600 * 1000);
  const h = (n) => String(n).padStart(2, "0");
  return h(v.getUTCHours()) + " giờ " + h(v.getUTCMinutes()) + " ngày " + h(v.getUTCDate()) + "/" + h(v.getUTCMonth() + 1) + "/" + v.getUTCFullYear();
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type, X-App-Key, X-Kt-Key",
      "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
    },
  });
}

function err(code, message, status) {
  return json({ ok: false, error: code, message }, status);
}

// Ngày theo giờ Việt Nam (UTC+7), dạng 2026-11-18
function vnDate() {
  return new Date(Date.now() + 7 * 3600 * 1000).toISOString().slice(0, 10);
}

function okDevice(d) {
  return /^[A-Za-z0-9_-]{8,64}$/.test(d);
}

// ---- Bộ đếm trong D1 ----
async function getN(db, k) {
  const row = await db.prepare("SELECT n FROM counters WHERE k = ?").bind(k).first();
  return row ? row.n : 0;
}

// Cộng d vào bộ đếm, trả về giá trị mới (một câu lệnh, không bị đếm sai khi bấm dồn dập)
async function addN(db, k, d) {
  const row = await db
    .prepare(
      "INSERT INTO counters (k, n, exp) VALUES (?1, ?2, ?3) " +
        "ON CONFLICT(k) DO UPDATE SET n = n + ?2 RETURNING n"
    )
    .bind(k, d, Date.now() + KEEP_MS)
    .first();
  return row.n;
}

async function getFlag(db, k) {
  const row = await db.prepare("SELECT v FROM flags WHERE k = ?").bind(k).first();
  return row ? row.v : null;
}

async function tierOf(db, device) {
  const until = parseInt((await getFlag(db, "pro:" + device)) || "0", 10);
  return until > Date.now() ? "pro" : "free";
}

async function cleanup(db) {
  await db.prepare("DELETE FROM counters WHERE exp < ?").bind(Date.now()).run();
  await db.prepare("DELETE FROM reports WHERE exp < ?").bind(Date.now()).run();
}

// ---- Kiểm tra chữ ký AdMob (server-side verification) ----
function b64ToBytes(s) {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

// Chữ ký AdMob dạng DER, WebCrypto cần dạng r||s 64 byte
function derToRaw(der) {
  let i = 2;
  if (der[1] & 0x80) i = 2 + (der[1] & 0x7f);
  const part = () => {
    i++; // 0x02
    const len = der[i++];
    let v = der.slice(i, i + len);
    i += len;
    while (v.length > 32 && v[0] === 0) v = v.slice(1);
    const p = new Uint8Array(32);
    p.set(v, 32 - v.length);
    return p;
  };
  const r = part();
  const s = part();
  const raw = new Uint8Array(64);
  raw.set(r, 0);
  raw.set(s, 32);
  return raw;
}

async function verifyAdmob(url, fetchKeys) {
  const q = url.search.slice(1);
  const at = q.indexOf("&signature=");
  if (at < 0) return false;
  const message = q.slice(0, at);
  const sig = url.searchParams.get("signature");
  const keyId = url.searchParams.get("key_id");
  if (!sig || !keyId) return false;
  const keys = await fetchKeys();
  const k = (keys.keys || []).find((x) => String(x.keyId) === String(keyId));
  if (!k) return false;
  const pub = await crypto.subtle.importKey(
    "spki", b64ToBytes(k.base64), { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  return crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" }, pub, derToRaw(b64ToBytes(sig)), new TextEncoder().encode(message));
}

async function quota(db, device, day) {
  const tier = await tierOf(db, device);
  const left = {};
  for (const m of Object.keys(SYSTEM)) {
    left[m] = Math.max(0, LIMITS[tier][m] - (await getN(db, "d:" + day + ":" + m + ":" + device)));
  }
  return {
    tier,
    left,
    bonus: await getN(db, "b:" + day + ":" + device),
    ads_left: Math.max(0, MAX_ADS_PER_DAY - (await getN(db, "a:" + day + ":" + device))),
  };
}

// Nhận loại ảnh theo các byte đầu (app cũ gửi ảnh PNG từ Thư viện ảnh nguyên dạng; khai sai loại
// thì Claude từ chối, thầy cô gặp lỗi 24/11/2026). Trả null khi không phải JPEG, PNG, GIF, WebP.
function loaiAnh(b64) {
  let s = "";
  try {
    s = atob(String(b64).slice(0, 24).replace(/[^A-Za-z0-9+/]/g, ""));
  } catch {
    return null;
  }
  const b = (i) => s.charCodeAt(i);
  if (b(0) === 0xff && b(1) === 0xd8 && b(2) === 0xff) return "image/jpeg";
  if (s.startsWith("\x89PNG")) return "image/png";
  if (s.startsWith("GIF8")) return "image/gif";
  if (s.startsWith("RIFF") && s.slice(8, 12) === "WEBP") return "image/webp";
  return null;
}

// Lỗi Claude trả về: báo thầy cô đúng lý do, chỉ nói "đang bận" khi dịch vụ bận thật.
// Không ghi nội dung câu hỏi vào nhật ký, chỉ ghi loại lỗi.
function loiClaude(status, chiTiet) {
  const loai = String((chiTiet && chiTiet.error && chiTiet.error.type) || "");
  const loi = String((chiTiet && chiTiet.error && chiTiet.error.message) || "").toLowerCase();
  if (status === 429 || status === 529 || status >= 500) {
    return { err: "ai_ban", msg: "Dịch vụ AI đang bận, thầy cô thử lại sau ít phút." };
  }
  if (status === 401 || status === 403) {
    return { err: "sai_khoa_ai", msg: "Trợ lý đang tạm dừng để nhà phát triển xử lý cấu hình, thầy cô thử lại sau." };
  }
  if (status === 413 || /too large|exceeds|maximum/.test(loi)) {
    return { err: "qua_lon", msg: "Ảnh hoặc tệp lớn quá, AI không nhận. Thầy cô chọn ảnh nhỏ hơn hoặc gửi ít trang hơn." };
  }
  if (/credit|balance|billing|spend|usage limit/.test(loi)) {
    return { err: "het_han_muc", msg: "Trợ lý đã dùng hết hạn mức chi phí, nhà phát triển đang xử lý. Thầy cô thử lại sau." };
  }
  if (/image|media type|media_type|document|pdf/.test(loi)) {
    return { err: "tep_loi", msg: "AI chưa đọc được ảnh hoặc tệp này. Thầy cô chụp lại hoặc chọn ảnh, tệp khác." };
  }
  return { err: "loi_ai", msg: "Trợ lý gặp lỗi khi xử lý câu hỏi (mã " + status + (loai ? ", " + loai : "") + "), thầy cô thử lại." };
}

async function callClaude(env, mode, content, hist = [], trich = "", tuy = {}) {
  // Hỏi Trợ lý qua Claude luôn kèm kiến thức nền về chế độ nhà giáo (mô hình chưa biết văn bản năm 2026)
  // và các điều văn bản gốc tìm được trong kho (trich). tuy.system, tuy.maxTokens: soạn giáo án dùng hướng dẫn, độ dài riêng.
  const system = tuy.system || (mode === "hoi" ? sysOf(mode) + "\n" + KIEN_THUC + trich : sysOf(mode));
  let r;
  try {
    r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: tuy.maxTokens || MAX_OUT[mode] || MAX_TOKENS,
        system,
        messages: [
          ...hist.flatMap((t) => [{ role: "user", content: t.q }, { role: "assistant", content: t.a }]),
          { role: "user", content },
        ],
      }),
    });
  } catch {
    return { err: "loi_mang", msg: "Không kết nối được dịch vụ AI, thầy cô thử lại sau." };
  }
  if (!r.ok) {
    // 400 sai dữ liệu (ảnh, tệp) hoặc hết hạn mức chi tiêu, 401 sai khóa, 413 quá lớn, 429 quá tải, 529 dịch vụ bận
    let chiTiet = null;
    try { chiTiet = await r.json(); } catch {}
    const l = loiClaude(r.status, chiTiet);
    const loai = String((chiTiet && chiTiet.error && chiTiet.error.type) || "");
    console.log(JSON.stringify({ ev: "ai_error", status: r.status, loai, ma: l.err, mode }));
    return { ...l, status: r.status };
  }
  const data = await r.json();
  const text = (data.content || []).filter((c) => c.type === "text").map((c) => c.text).join("").trim();
  if (!text) {
    console.log(JSON.stringify({ ev: "ai_empty", mode, stop: data.stop_reason }));
    return { err: "loi_ai", msg: "AI chưa trả lời được, thầy cô thử lại.", status: "rong:" + data.stop_reason };
  }
  return { text, by: "claude", usage: data.usage || {}, stop: data.stop_reason };
}

// Giải đề, ra đề tương tự: lời giải dài, cho Gemini viết lâu hơn (máy chủ phụ cắt ở 15 giây nếu không ghi).
const CHE_DO_DAI = ["giaide", "detuongtu"];
const GEMINI_CHO_DAI_MS = 35000;

async function callGemini(env, mode, input, imgs, hist = []) {
  let last = null;
  for (const model of GEMINI_MODELS) {
    last = await callGeminiOnce(env, mode, input, imgs, model, hist);
    if (!last.err || !/^(429|503|504)/.test(String(last.status))) return last;
    // Bài dài đã chờ hết giờ: không chờ thêm mô hình thứ hai, chuyển ngay sang các AI miễn phí chạy song song
    if (CHE_DO_DAI.includes(mode) && /^504/.test(String(last.status))) return last;
  }
  return last;
}

async function callGeminiOnce(env, mode, input, imgs, model, hist = []) {
  const parts = [
    ...imgs.map((a) => ({ inline_data: { mime_type: loaiAnh(a) || "image/jpeg", data: a } })),
    { text: input || (mode === "hoi" ? "Giải thích nội dung trong ảnh." : "Giải đề trong ảnh.") },
  ];
  let r;
  try {
    r = await env.GEMINI.fetch("https://gemini/", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        model,
        ...(CHE_DO_DAI.includes(mode) ? { timeout: GEMINI_CHO_DAI_MS } : {}),
        body: {
          systemInstruction: { parts: [{ text: sysOf(mode) }] },
          contents: [
            ...hist.flatMap((t) => [{ role: "user", parts: [{ text: t.q }] }, { role: "model", parts: [{ text: t.a }] }]),
            { role: "user", parts },
          ],
          // Mô hình có bước suy nghĩ cũng tính vào giới hạn, nên để rộng
          generationConfig: { maxOutputTokens: 8192 },
        },
      }),
    });
  } catch {
    return { err: "loi_mang", status: 0 };
  }
  if (!r.ok) {
    let why = "";
    try { const e = (await r.json()).error || {}; why = (e.status || "") + " " + String(e.message || "").slice(0, 120); } catch {}
    return { err: "loi_ai", status: r.status + (why ? ":" + why : "") };
  }
  const data = await r.json();
  const c = (data.candidates || [])[0] || {};
  const text = ((c.content || {}).parts || []).filter((p) => p.text && !p.thought).map((p) => p.text).join("").trim();
  if (!text) return { err: "loi_ai", status: "rong:" + (c.finishReason || "") };
  const u = data.usageMetadata || {};
  return { text, by: "gemini", usage: { input_tokens: u.promptTokenCount, output_tokens: u.candidatesTokenCount } };
}

export default {
  async fetch(request, env, ctx, deps = {}) {
    const fetchKeys = deps.fetchKeys || (() => fetch(ADMOB_KEYS_URL).then((r) => r.json()));
    const url = new URL(request.url);
    const db = env.DB;
    // Nhận cả tên biến ANTHROPIC_API (đã tạo trên Cloudflare) lẫn ANTHROPIC_API_KEY
    env = { ...env, ANTHROPIC_API_KEY: env.ANTHROPIC_API_KEY || env.ANTHROPIC_API };
    if (request.method === "OPTIONS") return json({ ok: true });
    if (url.pathname === "/health") {
      // tts_nghi: mô hình đọc thành tiếng đang tạm nghỉ vì hết lượt, kèm giờ Việt Nam được dùng lại
      const nghi = db ? await ttsNghi(db) : {};
      const tts_nghi = {};
      for (const m of TTS_GEMINI_MODELS) if ((nghi[m] || 0) > Date.now()) tts_nghi[m] = gioVN(new Date(nghi[m]));
      return json({
        ok: true,
        ai_enabled: env.AI_ENABLED !== "0",
        has_key: Boolean(env.ANTHROPIC_API_KEY),
        has_db: Boolean(db),
        tts_mo_hinh: TTS_GEMINI_MODELS,
        tts_nghi,
      });
    }
    if (PAGES[url.pathname]) return page(url.pathname);
    if (url.pathname === "/tin" && request.method === "GET") {
      return new Response(JSON.stringify(TIN), {
        headers: { "content-type": "application/json; charset=utf-8", "cache-control": "public, max-age=300" },
      });
    }
    if (!db) return err("chua_cau_hinh", "Máy chủ chưa được cấu hình xong.", 503);
    const day = vnDate();

    // AdMob gọi về: cộng lượt thưởng
    if (url.pathname === "/v1/admob-ssv") {
      const device = url.searchParams.get("user_id") || "";
      const tx = url.searchParams.get("transaction_id") || "";
      if (!okDevice(device) || !tx) return err("sai_du_lieu", "Thiếu mã máy hoặc mã giao dịch.", 400);
      let valid = false;
      try {
        valid = await verifyAdmob(url, fetchKeys);
      } catch {
        valid = false;
      }
      if (!valid) return err("sai_chu_ky", "Chữ ký không hợp lệ.", 403);
      if ((await addN(db, "tx:" + tx, 1)) > 1) return json({ ok: true, duplicate: true });
      const ads = await addN(db, "a:" + day + ":" + device, 1);
      if (ads > MAX_ADS_PER_DAY) return json({ ok: true, capped: true });
      const bonus = await addN(db, "b:" + day + ":" + device, BONUS_PER_AD);
      console.log(JSON.stringify({ ev: "ad_reward", day, device, bonus }));
      return json({ ok: true, bonus });
    }

    if (env.APP_KEY && request.headers.get("X-App-Key") !== env.APP_KEY) {
      return err("sai_khoa_app", "App không hợp lệ.", 401);
    }

    if (url.pathname === "/v1/quota" && request.method === "GET") {
      const device = url.searchParams.get("device_id") || "";
      if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
      return json({ ok: true, ...(await quota(db, device, day)) });
    }

    // Xóa dữ liệu của tôi: xóa bộ đếm lượt, lượt thưởng và nội dung đã báo cáo của máy này
    // (giữ thông tin gói Pro đã mua và danh sách chặn)
    if (url.pathname === "/v1/delete" && request.method === "POST") {
      let b;
      try {
        b = await request.json();
      } catch {
        return err("sai_du_lieu", "Dữ liệu gửi lên không đúng định dạng.", 400);
      }
      const device = String(b.device_id || "");
      if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
      await db.prepare("DELETE FROM counters WHERE k LIKE ?").bind("%:" + device).run();
      await db.prepare("DELETE FROM reports WHERE device = ?").bind(device).run();
      console.log(JSON.stringify({ ev: "delete", device }));
      return json({ ok: true, message: "Đã xóa dữ liệu của máy này trên máy chủ." });
    }

    // Báo cáo nội dung AI: lưu 90 ngày để xem xét, mỗi máy tối đa 20 báo cáo mỗi ngày
    if (url.pathname === "/v1/report" && request.method === "POST") {
      let b;
      try {
        b = await request.json();
      } catch {
        return err("sai_du_lieu", "Dữ liệu gửi lên không đúng định dạng.", 400);
      }
      const device = String(b.device_id || "");
      if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
      if ((await addN(db, "r:" + day + ":" + device, 1)) > 20) {
        return err("qua_nhieu", "Hôm nay thầy cô đã gửi nhiều báo cáo, xin cảm ơn.", 429);
      }
      const now = Date.now();
      await db
        .prepare("INSERT INTO reports (device, mode, input, output, reason, created, exp) VALUES (?, ?, ?, ?, ?, ?, ?)")
        .bind(device, String(b.mode || "").slice(0, 20), String(b.input || "").slice(0, MAX_INPUT),
          String(b.output || "").slice(0, 4000), String(b.reason || "").slice(0, 500), now, now + 90 * 86400 * 1000)
        .run();
      return json({ ok: true, message: "Cảm ơn thầy cô, chúng tôi sẽ xem xét." });
    }

    // Đọc to qua máy chủ, dùng khi điện thoại không có bộ đọc tiếng Việt.
    // Mặc định dùng Gemini đọc thành tiếng (gói miễn phí, chung khóa Gemini); có khóa Google Cloud thì dùng Google Cloud.
    if (url.pathname === "/v1/tts" && request.method === "POST") {
      let b;
      try { b = await request.json(); } catch { return err("sai_du_lieu", "Dữ liệu gửi lên không đúng định dạng.", 400); }
      const device = String(b.device_id || "").slice(0, 64);
      const text = String(b.text || "").trim();
      if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
      if (!text) return err("trong", "Chưa có chữ để đọc.", 400);
      if (text.length > TTS_MAX_CHARS) return err("qua_dai", "Mỗi lần đọc tối đa " + TTS_MAX_CHARS + " ký tự.", 400);
      if (!env.GOOGLE_TTS_KEY && !env.GEMINI) return err("chua_bat", "Giọng đọc qua mạng chưa được bật.", 503);
      const key = "t:" + day + ":" + device;
      if ((await getN(db, key)) + text.length > TTS_DAY_CHARS) {
        return err("het_luot", "Hôm nay máy này đã nghe đọc nhiều quá, mai dùng tiếp nhé.", 429);
      }
      const res = env.GOOGLE_TTS_KEY ? await ttsGoogle(env, text, b.rate) : await ttsGemini(env, text, db);
      if (res.err) {
        console.log(JSON.stringify({ ev: "tts_error", status: res.status }));
        return err(res.err, res.msg, res.err === "het_luot_chung" ? 429 : 502);
      }
      await addN(db, key, text.length);
      return json({ ok: true, audio: res.audio, mime: res.mime, by: res.by, ...(res.model ? { mo_hinh: res.model } : {}) });
    }

    // Kho văn bản: nạp, xem danh sách, xuất (cần khóa quản trị)
    if (url.pathname.startsWith("/v1/kt/")) {
      if (!(await khoaDung(request.headers.get("X-Kt-Key")))) return err("khong_quyen", "Sai khóa quản trị.", 403);
      if (url.pathname === "/v1/kt/nap" && request.method === "POST") {
        let vb;
        try {
          vb = await request.json();
        } catch {
          return err("sai_du_lieu", "Dữ liệu không đúng.", 400);
        }
        if (!vb.so || !vb.text || String(vb.text).length < 200) return err("sai_du_lieu", "Thiếu số hiệu hoặc nội dung.", 400);
        const n = await napVanBan(db, vb);
        return json({ ok: true, so: vb.so, so_doan: n, ky_tu: String(vb.text).length });
      }
      if (url.pathname === "/v1/kt/ds") return json({ ok: true, ds: await dsVanBan(db) });
      if (url.pathname === "/v1/kt/xuat") return json({ ok: true, text: await xuatVanBan(db, url.searchParams.get("so") || "") });
      if (url.pathname === "/v1/kt/tim") return json({ ok: true, trich: await timKienThuc(db, url.searchParams.get("q") || "") });
      return err("khong_tim_thay", "Đường dẫn không đúng.", 404);
    }

    if (url.pathname !== "/v1/ai" || request.method !== "POST") {
      return err("khong_tim_thay", "Đường dẫn không đúng.", 404);
    }
    if (env.AI_ENABLED === "0") {
      return err("tam_khoa", "Tính năng AI đang tạm dừng, thầy cô vui lòng thử lại sau.", 503);
    }
    if (!env.ANTHROPIC_API_KEY) {
      return err("chua_cau_hinh", "Máy chủ chưa được cấu hình xong.", 503);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return err("sai_du_lieu", "Dữ liệu gửi lên không đúng định dạng.", 400);
    }
    const mode = String(body.mode || "");
    const input = kemTinKenh(mode, String(body.input || "").trim());
    const device = String(body.device_id || "").slice(0, 64);
    if (!SYSTEM[mode]) return err("sai_che_do", "Chế độ không hợp lệ.", 400);
    if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
    const imgs = Array.isArray(body.images) ? body.images.filter((a) => typeof a === "string" && a) : [];
    if (imgs.length && !IMG_MODES.includes(mode)) return err("sai_du_lieu", "Chế độ này không nhận ảnh.", 400);
    if (imgs.length > 4 || imgs.some((a) => a.length > 2000000)) return err("anh_lon", "Tối đa 4 ảnh, mỗi ảnh dưới 1,5 MB.", 400);
    if (imgs.some((a) => !loaiAnh(a))) {
      return err("anh_la", "Ảnh này ở định dạng AI chưa đọc được. Thầy cô chụp màn hình ảnh đó rồi gửi lại.", 400);
    }
    const pdfs = Array.isArray(body.pdfs) ? body.pdfs.filter((a) => typeof a === "string" && a) : [];
    if (pdfs.length && !IMG_MODES.includes(mode)) return err("sai_du_lieu", "Chế độ này không nhận tệp PDF.", 400);
    if (pdfs.length > 1 || pdfs.some((a) => a.length > 6000000)) return err("pdf_lon", "Mỗi lần gửi một tệp PDF, dưới 4 MB.", 400);
    if (!input && !imgs.length && !pdfs.length) return err("trong", "Thầy cô chưa nhập nội dung.", 400);
    const hist = historyOf(body, mode);
    // Nhờ soạn giáo án trong Hỏi Trợ lý (27/11/2026): đi Claude, hướng dẫn và độ dài riêng
    const laGA = mode === "hoi" && laSoanGiaoAn(input, hist);
    const maxIn = laGA ? GA_MAX_IN : MAX_IN[mode] || MAX_INPUT;
    if (input.length > maxIn) {
      return err("qua_dai", "Nội dung dài quá, tối đa " + maxIn + " ký tự.", 400);
    }
    const content = imgs.length || pdfs.length
      ? [...pdfs.map((a) => ({ type: "document", source: { type: "base64", media_type: "application/pdf", data: a } })),
        ...imgs.map((a) => ({ type: "image", source: { type: "base64", media_type: loaiAnh(a), data: a } })),
        { type: "text", text: input || CAU_MAC_DINH[mode] || "Giải đề trong tệp." }]
      : input;
    if (await getFlag(db, "block:" + device)) {
      return err("bi_chan", "Máy này đã bị tạm dừng dùng AI. Thầy cô liên hệ hỗ trợ trong app.", 403);
    }

    // Đếm lượt: dùng lượt trong ngày trước, hết thì dùng lượt thưởng
    const ip = request.headers.get("CF-Connecting-IP") || "khong-ro";
    const tier = await tierOf(db, device);
    const limit = LIMITS[tier][mode];
    const devKey = "d:" + day + ":" + mode + ":" + device;
    const bonusKey = "b:" + day + ":" + device;
    const used = await getN(db, devKey);
    const bonus = used >= limit ? await getN(db, bonusKey) : 0;
    if (used >= limit && bonus <= 0) {
      // App chưa gắn quảng cáo: chỉ mời xem quảng cáo khi đã bật QUANG_CAO = "1" (sửa 26/11/2026,
      // trước đó máy chủ mời xem quảng cáo trong khi app không có quảng cáo nào)
      const ads = await getN(db, "a:" + day + ":" + device);
      const more = env.QUANG_CAO === "1" && ads < MAX_ADS_PER_DAY && tier === "free"
        ? ". Thầy cô có thể xem một quảng cáo ngắn để nhận thêm " + BONUS_PER_AD + " lượt."
        : ", mai dùng tiếp nhé.";
      return err("het_luot", "Hôm nay thầy cô đã dùng hết " + limit + " lượt" + more, 429);
    }
    const gaKey = "d:" + day + ":giaoan:" + device;
    if (laGA && (await getN(db, gaKey)) >= GA_LIMIT[tier]) {
      return err("het_luot_ga", "Hôm nay thầy cô đã soạn đủ " + GA_LIMIT[tier] + " giáo án, mai soạn tiếp nhé. Các câu hỏi khác vẫn hỏi được.", 429);
    }
    if ((await addN(db, "ip:" + day + ":" + ip, 1)) > IP_LIMIT) {
      return err("qua_nhieu", "Mạng này đã gửi quá nhiều yêu cầu hôm nay.", 429);
    }

    // Câu có thông tin cá nhân (app đánh dấu private) luôn đi qua Claude
    const priv = body.private === true;
    let res = null;
    let gem = null; // lý do Gemini không trả lời (để chẩn đoán, không chứa dữ liệu người dùng)
    // Ảnh gửi Gemini gói miễn phí hay bị treo lâu (thử ngày 19/11), nên câu có ảnh đi thẳng Claude
    const cheDo = mode === "hoi" && laCauCheDo(input, hist);
    // Câu cần thông tin mới (giá cả, tin tức, lịch, văn bản mới...): tìm trên mạng qua các cổng miễn phí
    let tim = null;
    if (mode === "hoi" && !laGA && !imgs.length && !pdfs.length && env.GEMINI && canTim(input) && !input.includes("Các clip gần đây")) {
      try { tim = await timTrenMang(env, input); } catch {}
    }
    const vao = kemKetQua(input, tim, gioVN());
    const noiDung = imgs.length || pdfs.length ? content : vao;
    if (!priv && !cheDo && !laGA && !imgs.length && !pdfs.length && GEMINI_MODES.includes(mode) && env.GEMINI) {
      res = await callGemini(env, mode, vao, imgs, hist);
      if (res.err) {
        gem = String(res.status);
        console.log(JSON.stringify({ ev: "gemini_fallback", status: res.status, device, mode }));
        // Gemini bận hoặc hết lượt: các AI miễn phí khác viết thay, đều bận mới dùng Claude
        const mp = await vietMienPhi(env, sysOf(mode), vao, hist, MAX_OUT[mode] || MAX_TOKENS);
        if (!mp.err) res = mp;
        else gem += " | " + mp.status;
      }
    }
    let trich = "";
    if ((!res || res.err) && mode === "hoi" && !laGA) {
      trich = await timKienThuc(db, [input, ...hist.slice(-1).map((h) => h.q)].join("\n"));
    }
    if (!res || res.err) {
      res = await callClaude(env, mode, noiDung, hist, trich, laGA ? { system: sysGiaoAn(), maxTokens: GA_MAX_OUT } : {});
    }
    if (res.err) return json({ ok: false, error: res.err, message: res.msg, gem, claude: String(res.status || "") }, 502);
    let text = res.text;
    if (laGA && res.stop === "max_tokens") {
      text += "\n\n(Giáo án dài, đến đây đã hết độ dài một lần trả lời. Thầy cô gõ \"viết tiếp\" để Trợ lý viết phần còn lại.)";
    }
    // Chỉ tính là một giáo án khi đã soạn ra giáo án (câu hỏi lại môn, lớp, tên bài không tính)
    const daSoan = laGA && text.length >= GA_DAI && GA_KHUNG_RE.test(boDau(text.slice(0, 1500)));
    if (daSoan) await addN(db, gaKey, 1);
    const data = { usage: res.usage };

    // Trừ lượt sau khi AI đã trả kết quả
    let usedNow = used;
    let leftBonus = bonus;
    if (used >= limit) {
      leftBonus = await addN(db, bonusKey, -1);
    } else {
      usedNow = await addN(db, devKey, 1);
    }
    // Thỉnh thoảng dọn bộ đếm cũ
    if (Math.random() < 0.01 && ctx && ctx.waitUntil) ctx.waitUntil(cleanup(db));
    // Nhật ký (xem trong Observability > Logs) để phát hiện máy dùng bất thường
    const u = data.usage || {};
    console.log(JSON.stringify({ ev: "ai", day, device, mode, tier, ip, by: res.by, priv, cheDo, ga: laGA ? (daSoan ? "soan" : "hoi_lai") : null, tim: tim ? tim.cong + (tim.luu ? "(luu)" : "") : null, kt: trich.length, in: u.input_tokens, out: u.output_tokens }));
    return json({
      ok: true,
      text,
      by: res.by,
      ...(laGA ? { giao_an: true } : {}),
      ...(gem ? { gem } : {}),
      ...(tim ? { tim: tim.cong } : {}),
      remaining: Math.max(0, limit - usedNow),
      bonus: Math.max(0, leftBonus),
    });
  },
};

// ---- Trang công khai: Điều khoản sử dụng, Chính sách quyền riêng tư ----
function esc(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function inline(s) {
  return esc(s)
    .replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
}

// Đổi markdown đơn giản (tiêu đề, đoạn, danh sách, bảng) thành HTML
function mdToHtml(md) {
  const out = [];
  const lines = md.split("\n");
  let i = 0;
  while (i < lines.length) {
    const l = lines[i];
    if (!l.trim()) { i++; continue; }
    if (l.startsWith("## ")) { out.push("<h2>" + inline(l.slice(3)) + "</h2>"); i++; continue; }
    if (l.startsWith("| ")) {
      const rows = [];
      while (i < lines.length && lines[i].startsWith("|")) { rows.push(lines[i]); i++; }
      const cells = (r) => r.slice(1, -1).split(" | ").map((c) => c.trim());
      let h = "<table><tr>" + cells(rows[0]).map((c) => "<th>" + inline(c) + "</th>").join("") + "</tr>";
      for (const r of rows.slice(2)) h += "<tr>" + cells(r).map((c) => "<td>" + inline(c) + "</td>").join("") + "</tr>";
      out.push(h + "</table>");
      continue;
    }
    if (/^(- |\d+\. )/.test(l)) {
      const ordered = /^\d+\. /.test(l);
      let h = ordered ? "<ol>" : "<ul>";
      while (i < lines.length && /^(- |\d+\. |    - )/.test(lines[i])) {
        if (lines[i].startsWith("    - ")) {
          let sub = "<ul>";
          while (i < lines.length && lines[i].startsWith("    - ")) { sub += "<li>" + inline(lines[i].slice(6)) + "</li>"; i++; }
          h = h.replace(/<\/li>$/, sub + "</ul></li>");
          continue;
        }
        h += "<li>" + inline(lines[i].replace(/^(- |\d+\. )/, "")) + "</li>";
        i++;
      }
      out.push(h + (ordered ? "</ol>" : "</ul>"));
      continue;
    }
    out.push("<p>" + inline(l) + "</p>");
    i++;
  }
  return out.join("\n");
}

function page(path) {
  const p = PAGES[path];
  const html = "<!doctype html><html lang=\"vi\"><head><meta charset=\"utf-8\">" +
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>" + p.title + "</title><style>" +
    "body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:760px;margin:0 auto;padding:24px 16px;line-height:1.6;color:#1f2933;background:#fff}" +
    "h1{font-size:1.6em;color:#0b4f8a}h2{font-size:1.2em;margin-top:1.6em;color:#0b4f8a}" +
    "table{border-collapse:collapse;width:100%;font-size:.9em}th,td{border:1px solid #d5dde5;padding:6px 8px;text-align:left;vertical-align:top}th{background:#eef4fa}" +
    "a{color:#0b6bcb}.meta{color:#5b6b7a;font-size:.9em}</style></head><body>" +
    "<h1>" + p.title + "</h1><p class=\"meta\">Cập nhật: " + p.updated + "</p>" + mdToHtml(p.md) + "</body></html>";
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" } });
}

const PAGES = {
  "/dieu-khoan": {
    title: "Điều khoản sử dụng – Trợ lý số Giáo viên - Một chạm",
    updated: "19/11/2026",
    md: String.raw`## 1. Giới thiệu và chấp nhận điều khoản
- "Trợ lý số Giáo viên - Một chạm" (gọi tắt là "Ứng dụng") là ứng dụng hỗ trợ công việc hành chính và chuyên môn của giáo viên, do ông Nguyễn Văn Toàn (gọi là "chúng tôi") cung cấp.
- Khi cài đặt hoặc sử dụng Ứng dụng, thầy cô đồng ý với Điều khoản sử dụng này và [Chính sách quyền riêng tư](/quyen-rieng-tu). Nếu không đồng ý, thầy cô vui lòng ngừng sử dụng và gỡ Ứng dụng.
- Ứng dụng được phân phối qua Google Play và App Store. Ngoài Điều khoản này, thầy cô còn chịu điều khoản của Google hoặc Apple khi tải, thanh toán và sử dụng.
## 2. Điều kiện sử dụng
- Ứng dụng dành cho giáo viên, cán bộ quản lý và người làm công tác giáo dục từ đủ 18 tuổi. Học sinh không phải là người dùng của Ứng dụng.
- Bản đầu không cần đăng ký tài khoản. Ứng dụng tạo một mã máy ngẫu nhiên để đếm lượt dùng tính năng AI; mã này không chứa tên, số điện thoại hay email.
- Gỡ Ứng dụng hoặc xóa dữ liệu Ứng dụng có thể làm mất các tệp lưu trên máy và lượt thưởng chưa dùng. Khi gói Pro được áp dụng, gói đã mua được khôi phục bằng nút "Khôi phục gói đã mua" trong trang Tài khoản, với cùng tài khoản Google hoặc Apple.
## 3. Tính năng AI và lượt sử dụng
- Các tính năng AI gồm: Hỏi Trợ lý (hỏi bằng chữ hoặc chụp ảnh), Nhờ AI viết nhận xét, Nhờ AI soạn tin, Giải đề, Ra đề tương tự, Nhờ AI sắp xếp biên bản. Hỏi Trợ lý trả lời câu hỏi thuộc nhiều chủ đề nhưng không có dữ liệu theo thời gian thực (giá cả, tỷ giá, tin tức trong ngày); thầy cô cần tự kiểm tra lại thông tin quan trọng.
- **Mỗi lượt** là một lần bấm nút và nhận được kết quả: một câu trả lời, một đoạn nhận xét cho một học sinh, hoặc một tin nhắn. Bấm "Viết lại" được tính thêm một lượt. Lần bấm bị lỗi (mất mạng, AI bận) không bị trừ lượt.
- Số lượt miễn phí mỗi ngày của Giải đề, nhận xét, tin nhắn hiển thị trong Ứng dụng; Hỏi Trợ lý không hiện số câu nhưng có giới hạn cao để chống lạm dụng. Lượt được tính lại từ 0 giờ theo giờ Việt Nam. Chúng tôi có thể điều chỉnh số lượt này và sẽ thông báo trong Ứng dụng.
- **Xem quảng cáo nhận lượt:** chưa áp dụng ở bản hiện tại. Khi mở, xem hết một quảng cáo nhận thưởng được thêm 5 lượt, tối đa 10 quảng cáo mỗi ngày. Lượt thưởng dùng trong ngày, không cộng dồn sang ngày sau, không đổi thành tiền.
- **Nội dung do AI tạo ra có thể sai hoặc chưa phù hợp.** Thầy cô luôn đọc, kiểm tra và sửa trước khi dùng, nhất là nhận xét học sinh, tin nhắn phụ huynh và thông tin về chế độ, văn bản. Nội dung AI không thay thế văn bản chính thức hay ý kiến của cơ quan có thẩm quyền.
- **Báo cáo nội dung:** gặp nội dung AI sai, xúc phạm hoặc không phù hợp, thầy cô bấm nút "Báo cáo" ngay dưới câu trả lời; chúng tôi xem xét và điều chỉnh.
- Tính năng AI có thể tạm dừng khi bảo trì, khi nhà cung cấp AI gặp sự cố hoặc khi vượt giới hạn chi phí của hệ thống. Các tiện ích chạy không cần mạng vẫn dùng bình thường.

Ứng dụng hiện được cung cấp miễn phí, không có quảng cáo và không có tính năng trả phí. Trong các phiên bản sau, nhà phát triển có thể bổ sung quảng cáo hoặc gói trả phí; khi đó ứng dụng sẽ thông báo trước ít nhất 7 ngày và Điều khoản này sẽ được cập nhật. Các tính năng cơ bản đang miễn phí vẫn tiếp tục được cung cấp miễn phí.
## 4. Gói Pro
Gói Pro chưa áp dụng. Giá và quyền lợi sẽ được công bố khi mở gói; mục này áp dụng từ thời điểm đó.
- **Quyền lợi:** nhiều lượt AI hơn gói miễn phí, tối đa số lượt mỗi tính năng mỗi ngày công bố khi mở gói. Giới hạn lượt mỗi ngày nhằm giữ dịch vụ ổn định và ngăn lạm dụng.
- **Giá:** công bố khi mở gói. Giá chính thức là giá hiển thị trên Google Play hoặc App Store tại thời điểm mua, đã gồm các khoản thuế do kho ứng dụng áp dụng.
- **Thanh toán:** thầy cô trả tiền qua tài khoản Google Play hoặc Apple. Chúng tôi không thu tiền trực tiếp và không lưu thông tin thẻ hay tài khoản ngân hàng của thầy cô.
- **Tự động gia hạn:** gói tự gia hạn và trừ tiền khi hết kỳ, trừ khi thầy cô hủy trước thời điểm gia hạn theo quy định của kho (với App Store: ít nhất 24 giờ trước khi hết kỳ).
- **Hủy gói:**
    - Android: Google Play → ảnh đại diện → Thanh toán và gói đăng ký → Gói đăng ký → Trợ lý số Giáo viên → Hủy.
    - iPhone: Cài đặt → tên tài khoản Apple → Đăng ký → Trợ lý số Giáo viên → Hủy.
    - Gỡ Ứng dụng không tự hủy gói. Sau khi hủy, quyền lợi Pro vẫn còn đến hết kỳ đã trả.
- **Thay đổi giá:** nếu tăng giá, chúng tôi báo trước qua Ứng dụng và kho ứng dụng; giá mới chỉ áp dụng từ kỳ gia hạn sau khi thầy cô được thông báo theo quy định của kho.
## 5. Hoàn tiền
Tiền mua gói Pro do Google hoặc Apple thu, nên việc hoàn tiền trước hết theo chính sách của kho nơi thầy cô mua.
| Nơi mua | Cách yêu cầu hoàn tiền | Chúng tôi hỗ trợ |
| --- | --- | --- |
| Google Play | Trong 48 giờ sau khi mua: yêu cầu ngay trên Google Play. Quá 48 giờ: liên hệ chúng tôi | Chúng tôi có thể hoàn tiền qua Google Play Console trong các trường hợp dưới đây |
| App Store | Yêu cầu tại reportaproblem.apple.com; Apple xem xét và quyết định | Nhà phát triển không tự hoàn tiền được; chúng tôi xác nhận lỗi để thầy cô gửi Apple |
- **Chúng tôi đề nghị hoàn tiền kỳ đã trả** khi: bị trừ tiền hai lần cho cùng một kỳ; hoặc tính năng AI của gói Pro không dùng được liên tục quá 3 ngày do lỗi từ phía chúng tôi.
- **Không hoàn tiền** phần thời gian còn lại khi thầy cô tự hủy giữa kỳ (quyền lợi vẫn dùng đến hết kỳ), trừ khi kho ứng dụng hoặc pháp luật quy định khác.
- Khi liên hệ về hoàn tiền, thầy cô gửi mã đơn hàng trong email biên nhận của Google hoặc Apple và mô tả lỗi. Chúng tôi trả lời trong 3 ngày làm việc.
## 6. Quy tắc sử dụng
Thầy cô không được:
- Dùng Ứng dụng, kể cả tính năng AI, để tạo nội dung vi phạm pháp luật Việt Nam, xúc phạm, phân biệt đối xử, hoặc xâm phạm quyền của người khác.
- Nhập tên thật kèm thông tin nhạy cảm của học sinh, phụ huynh vào ô gửi AI, khi Ứng dụng đã cung cấp cách dùng mã thay tên.
- Tìm cách vượt giới hạn lượt (đổi mã máy hàng loạt, giả lượt xem quảng cáo, dùng công cụ tự động), hoặc khai thác máy chủ của Ứng dụng cho mục đích khác.
- Sao chép, bán lại, dịch ngược hoặc phát hành lại Ứng dụng.
Khi phát hiện vi phạm, chúng tôi có thể tạm dừng hoặc chặn tính năng AI trên máy đó mà không hoàn lại lượt đã dùng. Thầy cô cho rằng bị chặn nhầm thì liên hệ theo mục 8 để được xem xét.
## 7. Dữ liệu và quảng cáo
- Việc thu thập, xử lý dữ liệu cá nhân được nêu chi tiết trong [Chính sách quyền riêng tư](/quyen-rieng-tu), theo pháp luật Việt Nam về bảo vệ dữ liệu cá nhân.
- Tệp quét, ảnh thẻ, nhận xét, tin nhắn thầy cô tạo được lưu trên máy của thầy cô, trừ khi thầy cô chọn gửi lên AI.
- Khi dùng tính năng AI, nội dung thầy cô nhập được gửi qua máy chủ của chúng tôi tới nhà cung cấp AI để tạo câu trả lời. Câu hỏi bằng chữ không có thông tin cá nhân trong Hỏi Trợ lý, Giải đề, Ra đề tương tự được gửi tới Google (Gemini), nội dung này có thể được Google dùng để cải thiện dịch vụ; câu hỏi kèm ảnh, câu hỏi có tên học sinh, số điện thoại, email và các tính năng Nhận xét học sinh, Nhắn phụ huynh, sắp xếp biên bản được gửi tới Anthropic (Claude). Tên học sinh trong danh sách lớp được thay bằng mã trước khi gửi. Máy chủ chỉ lưu mã máy, địa chỉ mạng, số lượt và nhật ký kỹ thuật ngắn hạn, không lưu nội dung câu hỏi (trừ nội dung thầy cô bấm Báo cáo).
- Bản hiện tại không có quảng cáo. Nếu sau này bổ sung, quảng cáo do Google AdMob cung cấp và được thông báo trước theo mục 3. Thầy cô có thể điều chỉnh quảng cáo cá nhân hóa trong cài đặt của máy. Nội dung quảng cáo thuộc trách nhiệm của bên quảng cáo.
## 8. Trách nhiệm, thay đổi và liên hệ
- **Giới hạn trách nhiệm:** Ứng dụng được cung cấp theo hiện trạng. Trong phạm vi pháp luật cho phép, chúng tôi không chịu trách nhiệm về thiệt hại phát sinh từ việc dùng nội dung AI mà không kiểm tra, về dữ liệu mất do gỡ Ứng dụng hay hỏng máy. Trách nhiệm bồi hoàn của chúng tôi, nếu có, không vượt quá số tiền thầy cô đã trả cho gói Pro trong 3 tháng gần nhất.
- **Thay đổi dịch vụ:** chúng tôi có thể thêm, sửa hoặc ngừng một tiện ích, đổi nhà cung cấp AI. Nếu ngừng hẳn gói Pro, chúng tôi báo trước ít nhất 30 ngày và ngừng gia hạn.
- **Thay đổi Điều khoản:** bản mới được thông báo trong Ứng dụng và có hiệu lực từ ngày ghi trên bản đó. Thầy cô tiếp tục dùng nghĩa là đồng ý với bản mới.
- **Luật áp dụng:** Điều khoản này theo pháp luật Việt Nam. Tranh chấp ưu tiên giải quyết bằng thương lượng; không thành thì đưa ra cơ quan có thẩm quyền tại Việt Nam.
- **Liên hệ:** Nguyễn Văn Toàn · email hotro.trolysogv@gmail.com · trong Ứng dụng: Tài khoản → Hỗ trợ.`,
  },
  "/quyen-rieng-tu": {
    title: "Chính sách quyền riêng tư – Trợ lý số Giáo viên - Một chạm",
    updated: "21/11/2026",
    md: String.raw`## 1. Tóm tắt
- Ứng dụng "Trợ lý số Giáo viên - Một chạm" do ông Nguyễn Văn Toàn (gọi là "chúng tôi") cung cấp và chịu trách nhiệm xử lý dữ liệu nêu trong chính sách này.
- **Chúng tôi thu:** một mã máy ngẫu nhiên, địa chỉ mạng (IP) và số lượt dùng AI để giới hạn lượt và chống lạm dụng; nội dung thầy cô chủ động gửi cho AI, chỉ để tạo câu trả lời.
- **Chúng tôi không:** bán dữ liệu; lưu nội dung câu hỏi trên máy chủ; tải tệp quét, ảnh, ghi âm của thầy cô lên máy chủ khi thầy cô không dùng AI.
- Chính sách này áp dụng theo pháp luật Việt Nam về bảo vệ dữ liệu cá nhân và đi cùng [Điều khoản sử dụng](/dieu-khoan).
## 2. Dữ liệu thu thập và mục đích
| Dữ liệu | Mục đích | Nơi lưu | Thời gian lưu |
| --- | --- | --- | --- |
| Tệp quét PDF, ảnh thẻ, nhận xét, tin nhắn, ghi âm, lịch công tác | Các tiện ích của Ứng dụng | Trên máy của thầy cô | Đến khi thầy cô xóa hoặc gỡ Ứng dụng |
| Mã máy ngẫu nhiên (do Ứng dụng tạo, không gắn với tên hay số điện thoại) | Đếm lượt AI, chống lạm dụng (và ghi nhận gói Pro khi gói được áp dụng) | Trên máy và máy chủ | Bộ đếm lượt tự xóa sau 3 ngày; thông tin gói Pro lưu đến khi gói hết hạn |
| Địa chỉ mạng (IP) | Giới hạn số lượt mỗi mạng, chống lạm dụng | Máy chủ | Tự xóa sau 3 ngày |
| Nội dung thầy cô gửi cho AI (kể cả ảnh đề bài khi dùng Giải đề, ghi chép họp khi nhờ AI sắp xếp biên bản) và câu trả lời | Tạo câu trả lời, nhận xét, tin nhắn | Chỉ chuyển qua máy chủ, không lưu; nhà cung cấp AI xử lý theo mục 3 | Không lưu trên máy chủ của chúng tôi |
| Nhật ký kỹ thuật: thời điểm, mã máy, IP, loại tính năng, số ký tự (token) | Phát hiện lỗi, lạm dụng | Máy chủ | Tối đa 7 ngày |
| Nội dung thầy cô bấm "Báo cáo" | Xem xét và cải thiện câu trả lời AI | Máy chủ | Tối đa 90 ngày |
| Thư thầy cô gửi đến email hỗ trợ | Trả lời, hỗ trợ, hoàn tiền | Hộp thư hotro.trolysogv@gmail.com | Đến khi xử lý xong và tối đa 2 năm |
Chúng tôi chỉ dùng dữ liệu cho các mục đích trên. Thầy cô đồng ý khi dùng tính năng tương ứng và có thể rút lại đồng ý bằng cách ngừng dùng tính năng đó.
## 3. Bên thứ ba nhận dữ liệu
Chúng tôi không bán dữ liệu của thầy cô. Dữ liệu chỉ đến các bên dưới đây, để Ứng dụng hoạt động; các bên này có thể xử lý dữ liệu ngoài Việt Nam.
| Bên nhận | Nhận gì | Để làm gì | Chính sách của họ |
| --- | --- | --- | --- |
| Google (dịch vụ AI Gemini) | Câu hỏi bằng chữ không có thông tin cá nhân trong Hỏi Trợ lý, Giải đề, Ra đề tương tự; không kèm mã máy hay IP của thầy cô | Tạo câu trả lời; Google có thể dùng nội dung này để cải thiện dịch vụ | [ai.google.dev/gemini-api/terms](https://ai.google.dev/gemini-api/terms) |
| Các dịch vụ AI miễn phí dự phòng: Cloudflare Workers AI, Groq, Mistral AI, Z.ai, Hugging Face, Cerebras | Như dòng Gemini: câu hỏi bằng chữ không có thông tin cá nhân, chỉ khi Gemini bận hoặc hết lượt; không kèm mã máy hay IP | Tạo câu trả lời thay Gemini | Chính sách của từng nhà cung cấp trên trang chủ của họ |
| Dịch vụ tìm kiếm trên mạng: TinyFish, LangSearch, Exa, Tavily, Firecrawl | Câu hỏi bằng chữ cần thông tin mới (giá cả, tin tức, văn bản mới) trong Hỏi Trợ lý, sau khi app đã thay tên học sinh bằng mã và che số điện thoại, email, số giấy tờ; không kèm mã máy hay IP | Tìm thông tin mới để trả lời | Chính sách của từng nhà cung cấp trên trang chủ của họ |
| Anthropic (dịch vụ AI Claude) | Câu hỏi kèm ảnh, câu hỏi có tên học sinh, số điện thoại, email; nội dung Nhận xét học sinh, Nhắn phụ huynh, sắp xếp biên bản. Tên học sinh trong danh sách lớp đã thay bằng mã; không kèm mã máy hay IP | Tạo câu trả lời | [anthropic.com/legal/privacy](https://www.anthropic.com/legal/privacy) |
| Cloudflare (máy chủ) | Mã máy, IP, bộ đếm lượt, nhật ký kỹ thuật | Vận hành máy chủ của Ứng dụng | [cloudflare.com/privacypolicy](https://www.cloudflare.com/privacypolicy/) |
| Google AdMob (quảng cáo, chưa dùng ở bản hiện tại) | Mã quảng cáo của máy, IP, thông tin thiết bị, tương tác với quảng cáo; mã máy khi xem quảng cáo nhận thưởng | Hiện quảng cáo, xác nhận lượt thưởng | [policies.google.com/privacy](https://policies.google.com/privacy) |
| Google Play, Apple App Store | Thông tin mua gói Pro khi gói được áp dụng (chúng tôi không nhận số thẻ) | Thanh toán, gia hạn, hoàn tiền | [policies.google.com/privacy](https://policies.google.com/privacy), [apple.com/legal/privacy](https://www.apple.com/legal/privacy/) |
- Bản hiện tại không có quảng cáo và không thu dữ liệu quảng cáo. Khi bổ sung quảng cáo, Ứng dụng sẽ thông báo trước và cập nhật chính sách này.
- Chúng tôi chỉ cung cấp dữ liệu cho cơ quan nhà nước khi có yêu cầu hợp pháp theo quy định của pháp luật Việt Nam.
## 4. Dữ liệu học sinh và phụ huynh
- Ứng dụng dành cho giáo viên. Thông tin học sinh, phụ huynh (tên, điểm, nhận xét, số điện thoại) do thầy cô nhập và được lưu trên máy của thầy cô.
- Trước khi gửi lên AI, Ứng dụng thay tên học sinh có trong danh sách lớp bằng mã (ví dụ "HS07"); trong Nhận xét học sinh, tên thật được ghép lại trên máy sau khi nhận câu trả lời. Câu hỏi có dấu hiệu chứa tên người, số điện thoại, email được gửi tới Claude thay vì Gemini. Số điện thoại phụ huynh không được gửi lên AI.
- Thầy cô không nhập vào ô gửi AI các thông tin nhạy cảm của học sinh, phụ huynh (sức khỏe, hoàn cảnh gia đình, số định danh). Thầy cô và nhà trường chịu trách nhiệm về việc thu thập, sử dụng thông tin học sinh theo quy định của ngành.
- Phần Họp (ghi âm, biên bản) mặc định xử lý ngay trên máy; chỉ gửi lên AI khi thầy cô bấm đồng ý cho từng lần.
## 5. Quyền truy cập trên máy
Ứng dụng chỉ xin quyền khi thầy cô mở tiện ích cần đến; từ chối thì chỉ tiện ích đó không dùng được.
| Quyền | Dùng cho |
| --- | --- |
| Máy ảnh | Quét giấy tờ, chụp ảnh thẻ, chấm trắc nghiệm |
| Micro | Ghi âm cuộc họp, đọc giọng nói thành văn bản, nói vào ô Trợ lý |
| Ảnh và tệp | Chọn ảnh, lưu tệp PDF, Word, ảnh thẻ |
| Thông báo | Nhắc việc sắp đến hạn trong Lịch công tác |
| Mạng | Tính năng AI, tin cho thầy cô |
Ứng dụng không xin quyền vị trí, danh bạ hay tin nhắn.
## 6. Quyền của thầy cô và cách xóa dữ liệu
Theo pháp luật về bảo vệ dữ liệu cá nhân, thầy cô có quyền biết, xem, yêu cầu sửa, xóa dữ liệu của mình, rút lại đồng ý và khiếu nại.
1. **Xóa dữ liệu trên máy:** xóa tệp trong mục Tệp của tôi, hoặc gỡ Ứng dụng.
2. **Xóa dữ liệu trên máy chủ:** trong Ứng dụng vào Tài khoản → Xóa dữ liệu của tôi, hoặc gửi email đến hotro.trolysogv@gmail.com kèm mã máy (xem trong Tài khoản). Chúng tôi xóa trong 7 ngày làm việc. Bộ đếm lượt và nhật ký cũng tự xóa sau 3–7 ngày dù thầy cô không yêu cầu.
3. **Xem, sửa dữ liệu hoặc khiếu nại:** gửi email; chúng tôi trả lời trong 7 ngày làm việc.
4. **Rút lại đồng ý:** ngừng dùng tính năng AI, tắt quyền truy cập trong cài đặt máy, hoặc gỡ Ứng dụng.
Xóa dữ liệu không tự hủy gói Pro; thầy cô hủy gói trên Google Play hoặc App Store.
## 7. Bảo mật, trẻ em, thay đổi và liên hệ
- **Bảo mật:** dữ liệu giữa Ứng dụng và máy chủ được mã hóa khi truyền (HTTPS); khóa truy cập dịch vụ AI chỉ nằm trên máy chủ, không nằm trong Ứng dụng. Khi xảy ra sự cố lộ dữ liệu, chúng tôi thông báo cho người dùng và cơ quan có thẩm quyền theo quy định.
- **Trẻ em:** Ứng dụng dành cho người từ đủ 18 tuổi, không dành cho học sinh và không cố ý thu dữ liệu trực tiếp từ trẻ em.
- **Thay đổi chính sách:** bản mới được thông báo trong Ứng dụng, ghi ngày cập nhật ở đầu trang. Thay đổi lớn (thu thêm loại dữ liệu mới) sẽ xin đồng ý lại.
- **Liên hệ:** Nguyễn Văn Toàn · email hotro.trolysogv@gmail.com · trong Ứng dụng: Tài khoản → Hỗ trợ.`,
  },
  "/ho-tro": {
    title: "Hỗ trợ – Trợ lý số Giáo viên - Một chạm",
    updated: "18/11/2026",
    md: String.raw`## Liên hệ
- Email: **hotro.trolysogv@gmail.com**. Chúng tôi trả lời trong vòng 3 ngày làm việc.
- Khi báo lỗi, thầy cô ghi kèm **mã máy** (Tài khoản → Mã máy, bấm để chép), tên điện thoại và mô tả việc đang làm.
## Câu hỏi thường gặp
- **Mỗi ngày được bao nhiêu lượt AI?** Hỏi Trợ lý thoải mái (có giới hạn chống lạm dụng), Nhờ AI viết nhận xét 100 lượt, Nhờ AI soạn tin 100 lượt, Giải đề 10 lượt, Ra đề tương tự 10 lượt, Nhờ AI sắp xếp biên bản 20 lượt. Lượt được làm mới lúc 0 giờ (giờ Việt Nam).
- **AI trả lời sai thì sao?** Thầy cô bấm **Báo cáo** dưới câu trả lời. AI có thể nhầm, thầy cô kiểm tra lại thông tin quan trọng trước khi dùng.
- **Dữ liệu học sinh có bị gửi đi không?** Danh sách học sinh, điểm, biên bản, ảnh lưu trên điện thoại. Khi bấm nút AI, tên học sinh được thay bằng mã HS01, HS02.
- **Xóa dữ liệu thế nào?** Tài khoản → Xóa dữ liệu của tôi trên máy chủ. Dữ liệu trên điện thoại xóa khi gỡ Ứng dụng.
- **Đổi điện thoại có mất dữ liệu không?** Có. Bản này chưa có sao lưu, thầy cô xuất PDF, Excel những gì cần giữ trước khi đổi máy.
## Văn bản liên quan
- [Điều khoản sử dụng](/dieu-khoan)
- [Chính sách quyền riêng tư](/quyen-rieng-tu)`,
  },
};
