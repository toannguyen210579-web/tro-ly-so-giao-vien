import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/luu_tru.dart';
import '../services/doc_danh_sach.dart';
import '../services/van_phong_cu.dart';
import '../main.dart';
import '../services/tro_ly_api.dart';
import 'cau_giup_viec.dart';

// ---------------------------------------------------------------------------
// Dữ liệu
// ---------------------------------------------------------------------------

const khoaLop = 'nhan_xet_lop';

/// Mức đánh giá theo cấp học.
/// Tiểu học theo Thông tư 27/2020/TT-BGDĐT; THCS, THPT theo Thông tư 22/2021/TT-BGDĐT;
/// cả hai được sửa đổi bởi Thông tư 89/2026/TT-BGDĐT (hiệu lực 01/12/2026).
/// "Miễn": môn học, hoạt động học sinh khuyết tật được miễn theo kế hoạch giáo dục cá nhân, ghi "Miễn" trong Học bạ số
/// (Điều 8 Thông tư 27/2020 và Điều 11 Thông tư 22/2021, sửa đổi bởi Thông tư 89/2026).
const mucMien = 'Miễn';
const mucTieuHoc = ['Hoàn thành tốt', 'Hoàn thành', 'Chưa hoàn thành', mucMien];
const mucTrungHoc = ['Tốt', 'Khá', 'Đạt', 'Chưa đạt', mucMien];
const vanBanDanhGia = 'Thông tư 27/2020 (tiểu học), Thông tư 22/2021 (THCS, THPT), sửa đổi bởi Thông tư 89/2026/TT-BGDĐT, hiệu lực 01/12/2026';

class HocSinh {
  String ten;
  String muc;
  String nhanXet;
  String diemTx; // các điểm thường xuyên, cách nhau bằng dấu phẩy hoặc khoảng trắng
  String diemGk;
  String diemCk;

  /// Học sinh khuyết tật: đánh giá theo kế hoạch giáo dục cá nhân, dựa trên sự tiến bộ của chính em,
  /// không so sánh với bạn khác (Thông tư 89/2026/TT-BGDĐT).
  bool khuyetTat;

  HocSinh(this.ten,
      {this.muc = '', this.nhanXet = '', this.diemTx = '', this.diemGk = '', this.diemCk = '', this.khuyetTat = false});

  Map<String, dynamic> toJson() =>
      {'ten': ten, 'muc': muc, 'nx': nhanXet, 'tx': diemTx, 'gk': diemGk, 'ck': diemCk, if (khuyetTat) 'kt': true};

  factory HocSinh.fromJson(Map<String, dynamic> j) => HocSinh(
        j['ten'] as String? ?? '',
        muc: j['muc'] as String? ?? '',
        nhanXet: j['nx'] as String? ?? '',
        diemTx: j['tx'] as String? ?? '',
        diemGk: j['gk'] as String? ?? '',
        diemCk: j['ck'] as String? ?? '',
        khuyetTat: j['kt'] == true,
      );

  /// Điểm trung bình môn học kỳ theo Điều 9 Thông tư 22/2021/TT-BGDĐT:
  /// ĐTBmhk = (Tổng điểm thường xuyên + 2 x giữa kỳ + 3 x cuối kỳ) / (Số điểm thường xuyên + 5).
  /// Thiếu điểm thì trả về null.
  double? get diemTrungBinh {
    final tx = diemTx
        .split(RegExp(r'[,;\s]+'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => double.tryParse(s.replaceAll(',', '.')))
        .toList();
    final gk = double.tryParse(diemGk.replaceAll(',', '.'));
    final ck = double.tryParse(diemCk.replaceAll(',', '.'));
    if (tx.isEmpty || tx.any((d) => d == null) || gk == null || ck == null) return null;
    final tong = tx.fold<double>(0, (a, b) => a + b!);
    final tb = (tong + 2 * gk + 3 * ck) / (tx.length + 5);
    return (tb * 10).round() / 10;
  }
}

class Lop {
  String ten;
  String cap; // 'th' tiểu học, 'tr' trung học
  String mon;
  List<HocSinh> hocSinh;

  Lop(this.ten, this.cap, this.mon, this.hocSinh);

  List<String> get dsMuc => cap == 'th' ? mucTieuHoc : mucTrungHoc;
  String get tenCap => cap == 'th' ? 'Tiểu học · Thông tư 27, sửa đổi bởi Thông tư 89/2026' : 'THCS, THPT · Thông tư 22, sửa đổi bởi Thông tư 89/2026';

  Map<String, dynamic> toJson() =>
      {'ten': ten, 'cap': cap, 'mon': mon, 'hs': hocSinh.map((h) => h.toJson()).toList()};

  factory Lop.fromJson(Map<String, dynamic> j) => Lop(
        j['ten'] as String? ?? '',
        j['cap'] as String? ?? 'tr',
        j['mon'] as String? ?? '',
        ((j['hs'] as List<dynamic>?) ?? [])
            .map((e) => HocSinh.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

Future<List<Lop>> docLop() async => (await LuuTru.docDanhSach(khoaLop)).map(Lop.fromJson).toList();
Future<void> ghiLop(List<Lop> ds) => LuuTru.ghiDanhSach(khoaLop, ds.map((l) => l.toJson()).toList());

// ---------------------------------------------------------------------------
// Lời nhận xét mẫu (không cần mạng, không dùng AI)
// ---------------------------------------------------------------------------

const _mau = <String, List<String>>{
  'tot': [
    'Em học tập chăm chỉ, nắm vững kiến thức, vận dụng tốt vào bài làm.',
    'Em tiếp thu bài nhanh, tích cực phát biểu, hoàn thành tốt các nhiệm vụ học tập.',
    'Em có ý thức tự học tốt, trình bày bài rõ ràng, cẩn thận.',
    'Em chủ động trong học tập, biết hợp tác với bạn, kết quả tiến bộ rõ.',
  ],
  'kha': [
    'Em nắm được kiến thức cơ bản, cần cẩn thận hơn khi làm bài.',
    'Em có cố gắng trong học tập, cần mạnh dạn phát biểu xây dựng bài hơn.',
    'Em hoàn thành các nhiệm vụ học tập, cần rèn thêm kỹ năng trình bày.',
    'Em chăm chỉ, cần luyện tập thêm các dạng bài vận dụng.',
  ],
  'dat': [
    'Em đạt yêu cầu của môn học, cần dành thêm thời gian ôn bài ở nhà.',
    'Em có tiến bộ, cần tập trung hơn trong giờ học.',
    'Em nắm được phần kiến thức cơ bản, cần chăm chỉ luyện tập thêm.',
    'Em hoàn thành nhiệm vụ cơ bản, cần chủ động hỏi thầy cô khi chưa hiểu bài.',
  ],
  'chua': [
    'Em cần cố gắng nhiều hơn, chú ý nghe giảng và làm đủ bài tập.',
    'Em chưa nắm vững kiến thức cơ bản, cần được hỗ trợ thêm và ôn luyện thường xuyên.',
    'Em cần tập trung hơn trong học tập, gia đình phối hợp nhắc nhở em ôn bài.',
    'Em cần chăm chỉ hơn, hoàn thành đầy đủ bài tập được giao.',
  ],
};

String _nhomMuc(String muc) {
  switch (muc) {
    case 'Hoàn thành tốt':
    case 'Tốt':
      return 'tot';
    case 'Khá':
      return 'kha';
    case 'Hoàn thành':
    case 'Đạt':
      return 'dat';
    case mucMien:
      return 'mien';
    default:
      return 'chua';
  }
}

// ---------------------------------------------------------------------------
// Màn danh sách lớp
// ---------------------------------------------------------------------------

class NhanXetHocSinh extends StatefulWidget {
  const NhanXetHocSinh({super.key});

  @override
  State<NhanXetHocSinh> createState() => _NhanXetHocSinhState();
}

class _NhanXetHocSinhState extends State<NhanXetHocSinh> {
  List<Lop>? _ds;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final ds = await docLop();
    if (mounted) setState(() => _ds = ds);
  }

  Future<void> _themLop() async {
    final lop = await showDialog<Lop>(context: context, builder: (_) => const _HopThemLop());
    if (lop == null) return;
    final ds = [...?_ds, lop];
    await ghiLop(ds);
    setState(() => _ds = ds);
  }

  Future<void> _xoaLop(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa lớp này?'),
        content: Text('Lớp ${_ds![i].ten} và toàn bộ nhận xét sẽ bị xóa khỏi máy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    final ds = [..._ds!]..removeAt(i);
    await ghiLop(ds);
    setState(() => _ds = ds);
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    return Scaffold(
      appBar: AppBar(title: const Text('Nhận xét học sinh')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _themLop,
        icon: const Icon(Icons.add),
        label: const Text('Thêm lớp'),
      ),
      body: Column(
        children: [
          const CauGiupViec('nhan_xet', margin: EdgeInsets.fromLTRB(12, 4, 12, 0)),
          Expanded(
            child: ds == null
          ? const Center(child: CircularProgressIndicator())
          : ds.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Chưa có lớp nào. Bấm "Thêm lớp", dán danh sách tên học sinh (mỗi em một dòng) là bắt đầu được.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: ds.length,
                  itemBuilder: (_, i) {
                    final l = ds[i];
                    final xong = l.hocSinh.where((h) => h.nhanXet.trim().isNotEmpty).length;
                    return Card(
                      child: ListTile(
                        title: Text('Lớp ${l.ten}${l.mon.isEmpty ? '' : ' · ${l.mon}'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${l.tenCap}\nĐã nhận xét $xong/${l.hocSinh.length} em'),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Xóa lớp',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _xoaLop(i),
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => _ManLop(lop: l, luu: () => ghiLop(ds))),
                          );
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _HopThemLop extends StatefulWidget {
  const _HopThemLop();

  @override
  State<_HopThemLop> createState() => _HopThemLopState();
}

class _HopThemLopState extends State<_HopThemLop> {
  final _ten = TextEditingController();
  final _mon = TextEditingController();
  final _ds = TextEditingController();
  String _cap = 'tr';
  String? _baoTep;

  Future<void> _layTuTep() async {
    try {
      final kq = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv', 'txt']);
      final duong = kq?.files.single.path;
      if (duong == null) return;
      final ds = await docDanhSachHocSinh(duong);
      setState(() {
        if (ds.isEmpty) {
          _baoTep = 'Không tìm thấy cột họ tên trong tệp. Thầy cô kiểm tra tệp có cột "Họ và tên".';
        } else {
          _ds.text = ds.join('\n');
          _baoTep = 'Đã lấy ${ds.length} học sinh từ tệp. Thầy cô xem lại rồi bấm Tạo lớp.';
        }
      });
    } on LoiTepCu catch (e) {
      setState(() => _baoTep = e.message);
    } catch (_) {
      setState(() => _baoTep = 'Chưa đọc được tệp này. Thầy cô kiểm tra tệp có mở được bằng Excel không.');
    }
  }

  @override
  void dispose() {
    _ten.dispose();
    _mon.dispose();
    _ds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm lớp'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _ten, decoration: const InputDecoration(labelText: 'Tên lớp, ví dụ 6A')),
            TextField(controller: _mon, decoration: const InputDecoration(labelText: 'Môn học, ví dụ Toán')),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'th', label: Text('Tiểu học')),
                ButtonSegment(value: 'tr', label: Text('THCS, THPT')),
              ],
              selected: {_cap},
              onSelectionChanged: (s) => setState(() => _cap = s.first),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _layTuTep,
                icon: const Icon(Icons.upload_file),
                label: const Text('Lấy từ tệp Excel'),
              ),
            ),
            if (_baoTep != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_baoTep!, style: const TextStyle(fontSize: 13)),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _ds,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Danh sách học sinh',
                hintText: 'Mỗi em một dòng, hoặc bấm Lấy từ tệp Excel (tệp xuất từ vnEdu, SMAS).',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Thôi')),
        FilledButton(
          onPressed: () {
            final ten = _ten.text.trim();
            final hs = _ds.text
                .split('\n')
                .map((s) => s.replaceAll(RegExp(r'^\s*\d+[\.\)\t ]+'), '').trim())
                .where((s) => s.isNotEmpty)
                .map((s) => HocSinh(s))
                .toList();
            if (hs.isEmpty) {
              setState(() => _baoTep = 'Thầy cô dán danh sách tên học sinh (mỗi em một dòng) hoặc bấm Lấy từ tệp Excel.');
              return;
            }
            Navigator.pop(context, Lop(ten.isEmpty ? 'mới' : ten, _cap, _mon.text.trim(), hs));
          },
          child: const Text('Tạo lớp'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Màn một lớp
// ---------------------------------------------------------------------------

class _ManLop extends StatefulWidget {
  final Lop lop;
  final Future<void> Function() luu;
  const _ManLop({required this.lop, required this.luu});

  @override
  State<_ManLop> createState() => _ManLopState();
}

class _ManLopState extends State<_ManLop> {
  bool _dangChoAI = false;

  Lop get lop => widget.lop;

  Future<void> _luu() async {
    await widget.luu();
    if (mounted) setState(() {});
  }

  void _goiYMau() {
    final dem = <String, int>{};
    for (final h in lop.hocSinh) {
      if (h.muc.isEmpty || h.nhanXet.trim().isNotEmpty) continue;
      if (h.muc == mucMien) {
        h.nhanXet = mucMien;
        continue;
      }
      final n = _nhomMuc(h.muc);
      final i = dem[n] ?? 0;
      final ds = _mau[n]!;
      h.nhanXet = ds[i % ds.length];
      dem[n] = i + 1;
    }
    _luu();
  }

  /// Gửi lên AI chỉ mã học sinh (HS01, HS02...) và mức, không gửi tên thật.
  /// Chỉ viết cho em chưa có nhận xét, để không mất phần thầy cô đã sửa; em nào cũng có rồi thì viết lại cả lớp.
  Future<void> _nhoAI() async {
    // Môn được miễn: ghi "Miễn" như Học bạ số, không cần AI viết
    for (final h in lop.hocSinh) {
      if (h.muc == mucMien) h.nhanXet = mucMien;
    }
    final coMuc = [
      for (var i = 0; i < lop.hocSinh.length; i++)
        if (lop.hocSinh[i].muc.isNotEmpty && lop.hocSinh[i].muc != mucMien) i,
    ];
    if (coMuc.isEmpty) {
      _bao('Thầy cô chạm chọn mức cho học sinh trước, AI dựa vào mức để viết.');
      return;
    }
    final chuaCo = coMuc.where((i) => lop.hocSinh[i].nhanXet.trim().isEmpty).toList();
    final can = chuaCo.isNotEmpty ? chuaCo : coMuc;
    setState(() => _dangChoAI = true);
    // Mỗi lần gửi 6 em để câu trả lời không bị cắt; gửi 3 lần cùng lúc cho nhanh (lớp 40 em khoảng 10 giây).
    final dot = [for (var b = 0; b < can.length; b += 6) can.sublist(b, b + 6 > can.length ? can.length : b + 6)];
    String? loi;
    var xong = 0;
    for (var w = 0; w < dot.length; w += 3) {
      final nhom = dot.skip(w).take(3).toList();
      final kqs = await Future.wait([for (final d in nhom) TroLyApi.hoi(_cauHoiAI(d), loai: 'nhan_xet')]);
      for (final kq in kqs) {
        if (kq.traLoi == null) {
          loi ??= kq.loi;
          continue;
        }
        for (final dong in kq.traLoi!.split('\n')) {
          final m = RegExp(r'^\s*[-*]?\s*(?:\*\*)?HS(\d+)(?:\*\*)?\s*[:\-–.]\s*(.+)$').firstMatch(dong);
          if (m == null) continue;
          final i = int.parse(m.group(1)!) - 1;
          if (i >= 0 && i < lop.hocSinh.length && can.contains(i)) {
            lop.hocSinh[i].nhanXet = boDauMarkdown(m.group(2)!);
            xong++;
          }
        }
      }
      if (mounted) setState(() {});
    }
    await _luu();
    if (!mounted) return;
    setState(() => _dangChoAI = false);
    if (loi != null && xong == 0) {
      _bao(loi);
    } else if (xong < can.length) {
      _bao('AI đã viết $xong/${can.length} em. Thầy cô bấm lại để viết nốt các em còn thiếu.');
    } else {
      _bao('AI đã viết xong $xong em. Thầy cô đọc lại và sửa trước khi dùng.');
    }
  }

  String _cauHoiAI(List<int> dot) {
    final cauHoi = StringBuffer()
      ..writeln('Cấp học: ${lop.tenCap}. Môn: ${lop.mon.isEmpty ? 'chưa ghi' : lop.mon}.')
      ..writeln('Viết lời nhận xét ngắn (1–2 câu) cho từng học sinh theo mức sau.')
      ..writeln('Trả về mỗi học sinh đúng một dòng, dạng "HS01: lời nhận xét", không thêm tiêu đề hay giải thích.')
      ..writeln('Căn cứ: $vanBanDanhGia.');
    if (dot.any((i) => lop.hocSinh[i].khuyetTat)) {
      cauHoi.writeln('Em ghi "khuyết tật": nhận xét theo kế hoạch giáo dục cá nhân, dựa trên sự tiến bộ của chính em, '
          'động viên sự cố gắng vượt khó, không so sánh với bạn khác.');
    }
    for (final i in dot) {
      final h = lop.hocSinh[i];
      cauHoi.writeln('HS${(i + 1).toString().padLeft(2, '0')}: ${h.muc}${h.khuyetTat ? ' (khuyết tật)' : ''}');
    }
    return cauHoi.toString();
  }

  void _chepTatCa() {
    final b = StringBuffer();
    final coDiem = lop.cap == 'tr';
    b.writeln(['STT', 'Họ và tên', 'Mức', if (coDiem) 'ĐTB môn HK', 'Nhận xét'].join('\t'));
    for (var i = 0; i < lop.hocSinh.length; i++) {
      final h = lop.hocSinh[i];
      final tb = h.diemTrungBinh;
      b.writeln([
        '${i + 1}',
        h.ten,
        h.muc,
        if (coDiem) tb == null ? '' : tb.toStringAsFixed(1),
        h.nhanXet.replaceAll('\n', ' '),
      ].join('\t'));
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    _bao('Đã chép cả lớp. Mở Excel, bấm vào ô A1 rồi dán.');
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _suaHocSinh(HocSinh h) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SuaHocSinh(hs: h, coDiem: lop.cap == 'tr'),
    );
    await _luu();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lớp ${lop.ten}${lop.mon.isEmpty ? '' : ' · ${lop.mon}'}'),
        actions: [
          IconButton(tooltip: 'Chép cả lớp sang Excel', onPressed: _chepTatCa, icon: const Icon(Icons.copy_all)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _goiYMau, child: const Text('Điền nhận xét mẫu')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _dangChoAI ? null : _nhoAI,
                    icon: _dangChoAI
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Nhờ AI viết nhận xét'),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'Chỉ mã học sinh và mức được gửi cho AI, tên các em không rời khỏi máy.',
              style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: lop.hocSinh.length,
              itemBuilder: (_, i) {
                final h = lop.hocSinh[i];
                final tb = h.diemTrungBinh;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${i + 1}. ${h.ten}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            if (h.khuyetTat)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Tooltip(
                                  message: 'Học sinh khuyết tật: nhận xét theo kế hoạch giáo dục cá nhân',
                                  child: Icon(Icons.accessibility_new, size: 18, color: MauApp.xanhDam),
                                ),
                              ),
                            if (lop.cap == 'tr' && tb != null)
                              Text('ĐTB: ${tb.toStringAsFixed(1)}', style: const TextStyle(color: MauApp.xanhDam)),
                            IconButton(
                              tooltip: 'Sửa nhận xét, nhập điểm',
                              onPressed: () => _suaHocSinh(h),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final m in lop.dsMuc)
                              ChoiceChip(
                                label: Text(m, style: const TextStyle(fontSize: 12.5)),
                                selected: h.muc == m,
                                onSelected: (_) {
                                  h.muc = m;
                                  _luu();
                                },
                              ),
                          ],
                        ),
                        if (h.nhanXet.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(h.nhanXet, style: const TextStyle(fontSize: 13.5, height: 1.4)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SuaHocSinh extends StatefulWidget {
  final HocSinh hs;
  final bool coDiem;
  const _SuaHocSinh({required this.hs, required this.coDiem});

  @override
  State<_SuaHocSinh> createState() => _SuaHocSinhState();
}

class _SuaHocSinhState extends State<_SuaHocSinh> {
  late final _nx = TextEditingController(text: widget.hs.nhanXet);
  late final _tx = TextEditingController(text: widget.hs.diemTx);
  late final _gk = TextEditingController(text: widget.hs.diemGk);
  late final _ck = TextEditingController(text: widget.hs.diemCk);

  @override
  void dispose() {
    _nx.dispose();
    _tx.dispose();
    _gk.dispose();
    _ck.dispose();
    super.dispose();
  }

  void _capNhat() {
    widget.hs
      ..nhanXet = _nx.text.trim()
      ..diemTx = _tx.text
      ..diemGk = _gk.text
      ..diemCk = _ck.text;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tb = widget.hs.diemTrungBinh;
    // Cuộn được: bàn phím mở hoặc màn hình nhỏ thì nút Xong không bị che
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.hs.ten, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: widget.hs.khuyetTat,
            onChanged: (v) => setState(() => widget.hs.khuyetTat = v),
            title: const Text('Học sinh khuyết tật'),
            subtitle: const Text('Nhận xét theo kế hoạch giáo dục cá nhân, dựa trên sự tiến bộ của chính em. '
                'Môn được miễn thì chọn mức "Miễn".'),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _nx,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => _capNhat(),
            decoration: const InputDecoration(labelText: 'Nhận xét', border: OutlineInputBorder()),
          ),
          if (widget.coDiem) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _tx,
              onChanged: (_) => _capNhat(),
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(labelText: 'Điểm thường xuyên', hintText: 'Ví dụ: 8 7.5 9'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gk,
                    onChanged: (_) => _capNhat(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Giữa kỳ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ck,
                    onChanged: (_) => _capNhat(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cuối kỳ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tb == null ? 'Nhập đủ điểm để tính điểm trung bình môn học kỳ.' : 'Điểm trung bình môn học kỳ: ${tb.toStringAsFixed(1)}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: MauApp.xanhDam),
            ),
            const Text(
              'Cách tính theo Điều 9 Thông tư 22/2021/TT-BGDĐT (Thông tư 89/2026 không đổi cách tính).',
              style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
          ),
        ],
      ),
    );
  }
}
