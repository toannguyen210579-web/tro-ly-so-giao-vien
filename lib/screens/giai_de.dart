import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../data/cham_diem.dart';
import '../data/luu_tru.dart';
import '../main.dart';
import '../services/tro_ly_api.dart';
import 'cau_giup_viec.dart';

const _dsMon = ['Toán', 'Ngữ văn', 'Tiếng Anh', 'KHTN', 'Vật lí', 'Hóa học', 'Sinh học', 'Lịch sử và Địa lí', 'Tin học', 'GDCD', 'Khác'];

/// Giải đề, soạn đáp án: chụp đề, AI làm lời giải, đáp án, thang điểm; hoặc ra đề tương tự.
class GiaiDe extends StatefulWidget {
  const GiaiDe({super.key});

  @override
  State<GiaiDe> createState() => _GiaiDeState();
}

class _GiaiDeState extends State<GiaiDe> {
  final _anh = <XFile>[];
  final _deChu = TextEditingController();
  final _yeuCau = TextEditingController();
  final _ketQua = TextEditingController();
  String _mon = _dsMon.first;
  String _lop = '';
  bool _dangCho = false;
  String _loaiVuaLam = '';

  @override
  void dispose() {
    _deChu.dispose();
    _yeuCau.dispose();
    _ketQua.dispose();
    super.dispose();
  }

  Future<void> _themAnh(ImageSource nguon) async {
    if (_anh.length >= 4) {
      _bao('Mỗi lần gửi tối đa 4 ảnh.');
      return;
    }
    final picker = ImagePicker();
    try {
      if (nguon == ImageSource.camera) {
        final x = await picker.pickImage(source: nguon, maxWidth: 1568, maxHeight: 1568, imageQuality: 80);
        if (x != null) setState(() => _anh.add(x));
      } else {
        final ds = await picker.pickMultiImage(maxWidth: 1568, maxHeight: 1568, imageQuality: 80);
        setState(() => _anh.addAll(ds.take(4 - _anh.length)));
      }
    } catch (_) {
      _bao('Chưa lấy được ảnh. Thầy cô cho app quyền dùng máy ảnh, ảnh trong Cài đặt.');
    }
  }

  Future<void> _gui(String loai) async {
    if (_anh.isEmpty && _deChu.text.trim().isEmpty) {
      _bao('Thầy cô chụp ảnh đề hoặc gõ đề vào ô bên dưới.');
      return;
    }
    if (diaChiMayChu.isEmpty) {
      _bao('Máy chủ AI chưa được nối nên tiện ích này chưa chạy được.');
      return;
    }
    setState(() => _dangCho = true);
    final anh = <String>[];
    for (final a in _anh) {
      anh.add(base64Encode(await File(a.path).readAsBytes()));
    }
    final b = StringBuffer('Môn: $_mon.');
    if (_lop.isNotEmpty) b.write(' Lớp: $_lop.');
    if (_deChu.text.trim().isNotEmpty) b.write('\nĐề (giáo viên gõ):\n${_deChu.text.trim()}');
    if (_yeuCau.text.trim().isNotEmpty) b.write('\nYêu cầu thêm của giáo viên: ${_yeuCau.text.trim()}');
    final kq = await TroLyApi.hoi(b.toString(), loai: loai, anh: anh);
    if (!mounted) return;
    setState(() => _dangCho = false);
    if (kq.traLoi == null) {
      _bao(kq.loi ?? 'Chưa làm được, thầy cô thử lại.');
      return;
    }
    setState(() {
      _ketQua.text = kq.traLoi!;
      _loaiVuaLam = loai;
    });
    if (kq.conLai != null) _bao('Còn ${kq.conLai} lượt hôm nay.');
  }

  Future<void> _sangChamTracNghiem() async {
    final dapAn = layDapAnTuLoiGiai(_ketQua.text);
    if (dapAn == null) {
      _bao('Không thấy dòng "ĐÁP ÁN TRẮC NGHIỆM" trong kết quả.');
      return;
    }
    final ten = TextEditingController(text: '$_mon${_lop.isEmpty ? '' : ' $_lop'} - ${_loaiVuaLam == 'de_tuong_tu' ? 'đề tương tự' : 'đề chụp'}');
    final ma = TextEditingController(text: '001');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tạo bài chấm trắc nghiệm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${dapAn.length} câu: $dapAn', style: const TextStyle(fontFamily: 'monospace')),
            TextField(controller: ten, decoration: const InputDecoration(labelText: 'Tên bài')),
            TextField(controller: ma, decoration: const InputDecoration(labelText: 'Mã đề')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tạo')),
        ],
      ),
    );
    if (ok != true) return;
    final ds = await LuuTru.docDanhSach(khoaChamTracNghiem);
    final de = DeThi(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      ten: ten.text.trim().isEmpty ? 'Bài từ Giải đề' : ten.text.trim(),
      soCau: dapAn.length,
      dapAn: {ma.text.trim().isEmpty ? '001' : ma.text.trim(): dapAn},
    );
    ds.insert(0, de.toJson());
    await LuuTru.ghiDanhSach(khoaChamTracNghiem, ds);
    _bao('Đã tạo bài "${de.ten}" trong Chấm trắc nghiệm. Thầy cô kiểm tra lại đáp án trước khi chấm.');
  }

  void _bao(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giải đề, soạn đáp án')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const CauGiupViec('tao_de'),
          const Text(
            'Chụp đề hoặc trang sách, AI làm lời giải từng bước, đáp án và gợi ý thang điểm; '
            'hoặc ra đề tương tự để ôn tập. Thầy cô kiểm tra lại trước khi dùng.',
            style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _mon,
                  decoration: const InputDecoration(labelText: 'Môn', border: OutlineInputBorder()),
                  items: [for (final m in _dsMon) DropdownMenuItem(value: m, child: Text(m))],
                  onChanged: (v) => setState(() => _mon = v ?? _mon),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _lop = v.trim(),
                  decoration: const InputDecoration(labelText: 'Lớp', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _themAnh(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chụp đề'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _themAnh(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Chọn ảnh'),
                ),
              ),
            ],
          ),
          if (_anh.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _anh.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(_anh[i].path), width: 90, height: 120, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          tooltip: 'Bỏ ảnh',
                          onPressed: () => setState(() => _anh.removeAt(i)),
                          icon: const Icon(Icons.cancel, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _deChu,
            minLines: 2,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Hoặc gõ, dán đề vào đây',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _yeuCau,
            decoration: const InputDecoration(
              labelText: 'Yêu cầu thêm (không bắt buộc)',
              hintText: 'Ví dụ: chỉ giải câu 3, 4; thang điểm 10; ra 5 câu tương tự',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_dangCho)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _gui('giai_de'),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Giải, soạn đáp án'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _gui('de_tuong_tu'),
                    icon: const Icon(Icons.content_copy_outlined, size: 18),
                    label: const Text('Ra đề tương tự'),
                  ),
                ),
              ],
            ),
          if (_ketQua.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'Bản do AI làm, có thể sai, nhất là hình vẽ và bài nhiều bước. Thầy cô đọc lại, sửa trực tiếp trước khi dùng.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ketQua,
              minLines: 10,
              maxLines: 40,
              decoration: const InputDecoration(labelText: 'Kết quả (sửa được)', border: OutlineInputBorder(), alignLabelWithHint: true),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _ketQua.text));
                    _bao('Đã chép, dán vào Word được.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Chép'),
                ),
                OutlinedButton.icon(onPressed: () => Share.share(_ketQua.text), icon: const Icon(Icons.send), label: const Text('Gửi đi')),
                if (layDapAnTuLoiGiai(_ketQua.text) != null)
                  FilledButton.tonalIcon(
                    onPressed: _sangChamTracNghiem,
                    icon: const Icon(Icons.checklist_outlined),
                    label: const Text('Đưa đáp án sang Chấm trắc nghiệm'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
