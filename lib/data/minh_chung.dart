/// Dữ liệu Sổ minh chứng và phần chuẩn bị xuất (không phụ thuộc giao diện, có kiểm thử).
library;

const dsNhomMinhChung = [
  'Chuẩn nghề nghiệp',
  'Thi đua, khen thưởng',
  'Bồi dưỡng, tập huấn',
  'Hoạt động chuyên môn',
  'Kiểm định chất lượng',
  'Khác',
];

/// Một minh chứng: mã (nếu có), tiêu đề, nhóm, ngày, ghi chú và các ảnh kèm theo.
class MinhChung {
  String id;
  String nhom;
  String tieuDe;
  DateTime ngay;
  String ghiChu;

  /// Mã minh chứng theo hồ sơ (ví dụ H1-1.1-01 khi kiểm định, TC3 khi đánh giá chuẩn). Có thể để trống.
  String ma;

  /// Tên tệp ảnh trong thư mục minh_chung của app.
  List<String> anh;

  MinhChung({
    required this.id,
    required this.nhom,
    required this.tieuDe,
    required this.ngay,
    this.ghiChu = '',
    this.ma = '',
    List<String>? anh,
  }) : anh = anh ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'nhom': nhom,
        'tieu_de': tieuDe,
        'ngay': ngay.toIso8601String(),
        'ghi_chu': ghiChu,
        'ma': ma,
        'anh': anh,
      };

  factory MinhChung.fromJson(Map<String, dynamic> j) => MinhChung(
        id: j['id'] as String,
        nhom: j['nhom'] as String? ?? 'Khác',
        tieuDe: j['tieu_de'] as String? ?? '',
        ngay: DateTime.tryParse(j['ngay'] as String? ?? '') ?? DateTime.now(),
        ghiChu: j['ghi_chu'] as String? ?? '',
        ma: j['ma'] as String? ?? '',
        anh: (j['anh'] as List<dynamic>? ?? []).cast<String>(),
      );
}

/// Xếp minh chứng theo thứ tự nhóm, trong nhóm theo mã (nếu có) rồi theo ngày cũ trước: đúng thứ tự thường nộp.
List<MinhChung> xepDeNop(List<MinhChung> ds) {
  int viTri(String n) {
    final i = dsNhomMinhChung.indexOf(n);
    return i < 0 ? dsNhomMinhChung.length : i;
  }

  return [...ds]..sort((a, b) {
      final n = viTri(a.nhom).compareTo(viTri(b.nhom));
      if (n != 0) return n;
      if (a.ma.isNotEmpty && b.ma.isNotEmpty) {
        final m = a.ma.compareTo(b.ma);
        if (m != 0) return m;
      } else if (a.ma.isNotEmpty != b.ma.isNotEmpty) {
        return a.ma.isNotEmpty ? -1 : 1;
      }
      return a.ngay.compareTo(b.ngay);
    });
}

String boDauTenTep(String s) {
  const co = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  const khong = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = co.indexOf(c);
    b.write(i >= 0 ? khong[i] : c);
  }
  return b.toString();
}

/// Tên tệp cho từng minh chứng: số thứ tự, mã, tiêu đề; không dấu, không khoảng trắng,
/// vì nhiều hệ thống nộp hồ sơ (TEMIS, phần mềm kiểm định) báo lỗi với tên tệp có dấu hoặc ký tự lạ.
String tenTepMinhChung(int stt, MinhChung m, {String duoi = 'pdf'}) {
  String gon(String s) => boDauTenTep(s)
      .replaceAll(RegExp(r'[^A-Za-z0-9.\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[_.]+|[_.]+$'), '');
  final so = stt.toString().padLeft(2, '0');
  final ma = gon(m.ma);
  var td = gon(m.tieuDe);
  if (td.length > 60) td = td.substring(0, 60).replaceAll(RegExp(r'[_.\-]+$'), '');
  final phan = [so, if (ma.isNotEmpty) ma, if (td.isNotEmpty) td];
  return '${phan.join('_')}.$duoi';
}

String _ngay(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Bảng danh mục minh chứng (dòng đầu là tiêu đề cột) để đưa vào Excel hoặc điền vào hệ thống.
/// [ds] đã xếp sẵn theo thứ tự nộp; cột Tên tệp khớp tên các tệp PDF xuất kèm.
List<List<String>> bangDanhMuc(List<MinhChung> ds) => [
      ['STT', 'Mã minh chứng', 'Nhóm', 'Tên minh chứng', 'Ngày', 'Số, ký hiệu, nơi ban hành, ghi chú', 'Số ảnh', 'Tên tệp'],
      for (var i = 0; i < ds.length; i++)
        [
          '${i + 1}',
          ds[i].ma,
          ds[i].nhom,
          ds[i].tieuDe,
          _ngay(ds[i].ngay),
          ds[i].ghiChu,
          '${ds[i].anh.length}',
          tenTepMinhChung(i + 1, ds[i]),
        ],
    ];
