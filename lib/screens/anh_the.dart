import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';

/// Ảnh thẻ: tách nền ngay trên máy (ML Kit), thay nền xanh hoặc trắng,
/// cắt cỡ 3x4 hoặc 4x6, xếp tờ in 10x15 cm. Không gửi ảnh đi đâu.
class AnhThe extends StatefulWidget {
  const AnhThe({super.key});

  @override
  State<AnhThe> createState() => _AnhTheState();
}

const _nenXanh = 0xFF4A8FE7;
const _nenTrang = 0xFFFFFFFF;

class _AnhTheState extends State<AnhThe> {
  String? _anhGoc; // đường dẫn ảnh đã xoay đúng chiều, thu nhỏ
  SegmentationMask? _mask;
  int _nen = _nenXanh;
  String _co = '3x4';
  Uint8List? _anhThe;
  Uint8List? _toIn;
  bool _dangXuLy = false;

  Future<void> _chonAnh(ImageSource nguon) async {
    final x = await ImagePicker().pickImage(source: nguon, maxWidth: 2000, preferredCameraDevice: CameraDevice.front);
    if (x == null) return;
    setState(() {
      _dangXuLy = true;
      _anhThe = null;
      _toIn = null;
    });
    try {
      // Xoay ảnh đúng chiều và thu nhỏ trước khi tách nền.
      final bytes = await x.readAsBytes();
      final chuan = await compute(_chuanHoa, bytes);
      final tam = await getTemporaryDirectory();
      final f = File('${tam.path}/anh_the_goc.jpg');
      await f.writeAsBytes(chuan);

      final seg = SelfieSegmenter(mode: SegmenterMode.single, enableRawSizeMask: false);
      final mask = await seg.processImage(InputImage.fromFilePath(f.path));
      await seg.close();
      if (mask == null) throw Exception('khong tach duoc');

      _anhGoc = f.path;
      _mask = mask;
      await _ve();
    } catch (_) {
      if (mounted) {
        setState(() => _dangXuLy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa tách được nền. Thầy cô chụp lại, đứng trước nền đơn giản, đủ sáng.')),
        );
      }
    }
  }

  Future<void> _ve() async {
    final goc = _anhGoc;
    final m = _mask;
    if (goc == null || m == null) return;
    setState(() => _dangXuLy = true);
    final kq = await compute(_ghepAnh, {
      'anh': await File(goc).readAsBytes(),
      'mask': Float64List.fromList(m.confidences),
      'mw': m.width,
      'mh': m.height,
      'nen': _nen,
      'co': _co,
    });
    if (!mounted) return;
    setState(() {
      _anhThe = kq['anh'];
      _toIn = kq['to'];
      _dangXuLy = false;
    });
  }

  Future<void> _luuVaGui() async {
    final a = _anhThe, t = _toIn;
    if (a == null || t == null) return;
    final goc = await getApplicationDocumentsDirectory();
    final d = Directory('${goc.path}/anh_the');
    if (!await d.exists()) await d.create(recursive: true);
    final s = DateTime.now().millisecondsSinceEpoch;
    final f1 = File('${d.path}/AnhThe_${_co}_$s.jpg')..writeAsBytesSync(a);
    final f2 = File('${d.path}/ToIn_10x15_${_co}_$s.jpg')..writeAsBytesSync(t);
    await Share.shareXFiles([XFile(f1.path), XFile(f2.path)]);
  }

  @override
  Widget build(BuildContext context) {
    final soAnh = _co == '3x4' ? 8 : 3;
    return Scaffold(
      appBar: AppBar(title: const Text('Ảnh thẻ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _dangXuLy ? null : () => _chonAnh(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chụp ảnh'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _dangXuLy ? null : () => _chonAnh(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Ảnh có sẵn'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Chụp chính diện, đủ sáng, đứng trước nền đơn giản. Ảnh được xử lý ngay trên máy.',
            style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          const SizedBox(height: 16),
          const Text('Màu nền', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: _nenXanh, label: Text('Xanh')),
              ButtonSegment(value: _nenTrang, label: Text('Trắng')),
            ],
            selected: {_nen},
            onSelectionChanged: (s) {
              setState(() => _nen = s.first);
              _ve();
            },
          ),
          const SizedBox(height: 12),
          const Text('Cỡ ảnh', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '3x4', label: Text('3 x 4 cm')),
              ButtonSegment(value: '4x6', label: Text('4 x 6 cm')),
            ],
            selected: {_co},
            onSelectionChanged: (s) {
              setState(() => _co = s.first);
              _ve();
            },
          ),
          const SizedBox(height: 16),
          if (_dangXuLy) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!_dangXuLy && _anhThe != null) ...[
            Center(child: Image.memory(_anhThe!, height: 220)),
            const SizedBox(height: 16),
            Text('Tờ in 10 x 15 cm · $soAnh ảnh', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Image.memory(_toIn!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _luuVaGui,
              icon: const Icon(Icons.save_alt),
              label: const Text('Lưu và gửi đi in'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lưu ý: ảnh tự chụp có thể không được chấp nhận cho căn cước, hộ chiếu, bằng lái. '
              'Thầy cô kiểm tra yêu cầu của nơi nộp hồ sơ.',
              style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Xử lý ảnh (chạy ở luồng riêng để app không bị đứng)
// ---------------------------------------------------------------------------

Uint8List _chuanHoa(Uint8List bytes) {
  var im = img.decodeImage(bytes)!;
  im = img.bakeOrientation(im);
  const toiDa = 1400;
  if (im.width > toiDa || im.height > toiDa) {
    im = im.width >= im.height ? img.copyResize(im, width: toiDa) : img.copyResize(im, height: toiDa);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 92));
}

Map<String, Uint8List> _ghepAnh(Map<String, Object> vao) {
  final goc = img.decodeImage(vao['anh'] as Uint8List)!;
  final mask = vao['mask'] as Float64List;
  final mw = vao['mw'] as int, mh = vao['mh'] as int;
  final nen = vao['nen'] as int;
  final co = vao['co'] as String;
  final nr = (nen >> 16) & 0xFF, ng = (nen >> 8) & 0xFF, nb = nen & 0xFF;

  final w = goc.width, h = goc.height;
  double doTinCay(int x, int y) => mask[(y * mh ~/ h) * mw + (x * mw ~/ w)];

  // Ghép người lên nền mới, và tìm đỉnh đầu, tâm ngang của người.
  final ra = img.Image(width: w, height: h);
  var dinh = h;
  var tongX = 0, demX = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final a = doTinCay(x, y);
      final p = goc.getPixel(x, y);
      final r = (p.r * a + nr * (1 - a)).round();
      final g = (p.g * a + ng * (1 - a)).round();
      final b = (p.b * a + nb * (1 - a)).round();
      ra.setPixelRgb(x, y, r, g, b);
      if (a > 0.5) {
        if (y < dinh) dinh = y;
        tongX += x;
        demX++;
      }
    }
  }
  final tamX = demX == 0 ? w ~/ 2 : tongX ~/ demX;
  if (dinh == h) dinh = 0;

  // Cắt theo tỉ lệ 3:4 hoặc 4:6, chừa khoảng trống trên đầu.
  final tiLe = co == '3x4' ? 3 / 4 : 4 / 6;
  var cw = w, ch = (w / tiLe).round();
  if (ch > h) {
    ch = h;
    cw = (h * tiLe).round();
  }
  final x0 = (tamX - cw ~/ 2).clamp(0, w - cw).toInt();
  final y0 = (dinh - (ch * 0.1).round()).clamp(0, h - ch).toInt();
  final cat = img.copyCrop(ra, x: x0, y: y0, width: cw, height: ch);

  // Cỡ in ở 300 dpi: 3x4 cm = 354x472 điểm ảnh, 4x6 cm = 472x709.
  final pw = co == '3x4' ? 354 : 472;
  final ph = co == '3x4' ? 472 : 709;
  final anh = img.copyResize(cat, width: pw, height: ph, interpolation: img.Interpolation.average);

  // Tờ in 15x10 cm (nằm ngang) ở 300 dpi = 1772x1181 điểm ảnh.
  const tw = 1772, th = 1181, khe = 24;
  final to = img.Image(width: tw, height: th);
  img.fill(to, color: img.ColorRgb8(255, 255, 255));
  final cot = (tw + khe) ~/ (pw + khe);
  final hang = (th + khe) ~/ (ph + khe);
  final rongLuoi = cot * pw + (cot - 1) * khe;
  final caoLuoi = hang * ph + (hang - 1) * khe;
  final lx = (tw - rongLuoi) ~/ 2, ly = (th - caoLuoi) ~/ 2;
  for (var i = 0; i < hang; i++) {
    for (var j = 0; j < cot; j++) {
      final x = lx + j * (pw + khe), y = ly + i * (ph + khe);
      img.compositeImage(to, anh, dstX: x, dstY: y);
      img.drawRect(to, x1: x - 1, y1: y - 1, x2: x + pw, y2: y + ph, color: img.ColorRgb8(200, 200, 200));
    }
  }

  return {
    'anh': Uint8List.fromList(img.encodeJpg(anh, quality: 95)),
    'to': Uint8List.fromList(img.encodeJpg(to, quality: 95)),
  };
}
