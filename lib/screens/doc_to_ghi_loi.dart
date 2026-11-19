import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../main.dart';
import 'cau_giup_viec.dart';

/// Tách văn bản dài thành từng đoạn ngắn để bộ đọc của máy không bị cắt chữ.
List<String> tachCau(String s, {int toiDa = 300}) {
  final kq = <String>[];
  for (final doan in s.split(RegExp(r'\n+'))) {
    final t = doan.trim();
    if (t.isEmpty) continue;
    final cau = RegExp(r'[^.!?;:…]+[.!?;:…]*').allMatches(t).map((m) => m.group(0)!.trim()).where((c) => c.isNotEmpty);
    var dem = '';
    for (final c in cau) {
      if (dem.isNotEmpty && dem.length + c.length + 1 > toiDa) {
        kq.add(dem);
        dem = '';
      }
      dem = dem.isEmpty ? c : '$dem $c';
      while (dem.length > toiDa) {
        var cat = dem.lastIndexOf(' ', toiDa);
        if (cat <= 0) cat = toiDa;
        kq.add(dem.substring(0, cat).trim());
        dem = dem.substring(cat).trim();
      }
    }
    if (dem.isNotEmpty) kq.add(dem);
  }
  return kq;
}

/// Hai chiều: Đọc to (chữ thành tiếng) và Ghi lời nói (tiếng thành chữ).
/// Dùng bộ đọc và bộ nhận giọng có sẵn của điện thoại (Google trên Android, Apple trên iPhone).
class DocToGhiLoi extends StatelessWidget {
  /// Mở thẳng tab Ghi lời nói và trả chữ về màn trước (dùng cho biên bản họp).
  final bool chiGhiDeTraVe;
  const DocToGhiLoi({super.key, this.chiGhiDeTraVe = false});

  @override
  Widget build(BuildContext context) {
    if (chiGhiDeTraVe) {
      return Scaffold(appBar: AppBar(title: const Text('Nói để ghi')), body: const _GhiLoiNoi(traVe: true));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Giọng nói ⇄ Văn bản'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.volume_up_outlined), text: 'Văn bản → Giọng nói'),
            Tab(icon: Icon(Icons.mic_none), text: 'Giọng nói → Văn bản'),
          ]),
        ),
        body: const Column(
          children: [
            CauGiupViec('doc_to', margin: EdgeInsets.fromLTRB(16, 10, 16, 0)),
            Expanded(child: TabBarView(children: [_DocTo(), _GhiLoiNoi()])),
          ],
        ),
      ),
    );
  }
}

class _DocTo extends StatefulWidget {
  const _DocTo();

  @override
  State<_DocTo> createState() => _DocToState();
}

class _DocToState extends State<_DocTo> with AutomaticKeepAliveClientMixin {
  final _tts = FlutterTts();
  final _chu = TextEditingController();
  double _tocDo = 0.5;
  bool _dangDoc = false;
  bool _dungLai = false;
  int _doanDangDoc = 0;
  int _tongDoan = 0;
  String? _canhBao;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _chuanBi();
  }

  Future<void> _chuanBi() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      final co = await _tts.isLanguageAvailable('vi-VN');
      await _tts.setLanguage('vi-VN');
      if (co != true && mounted) {
        setState(() => _canhBao = 'Máy chưa có giọng đọc tiếng Việt. Thầy cô vào Cài đặt > Ngôn ngữ > '
            'Chuyển văn bản thành giọng nói, chọn Google và tải giọng Tiếng Việt.');
      }
    } catch (_) {
      if (mounted) setState(() => _canhBao = 'Máy này chưa có bộ đọc văn bản.');
    }
  }

  @override
  void dispose() {
    _dungLai = true;
    _tts.stop();
    _chu.dispose();
    super.dispose();
  }

  Future<void> _doc() async {
    final ds = tachCau(_chu.text);
    if (ds.isEmpty) {
      _bao('Thầy cô dán hoặc gõ văn bản cần đọc vào ô trên.');
      return;
    }
    setState(() {
      _dangDoc = true;
      _dungLai = false;
      _tongDoan = ds.length;
    });
    await _tts.setSpeechRate(_tocDo);
    // Máy giả lập hoặc máy thiếu bộ đọc: lệnh đọc không phát tiếng và cũng không báo xong.
    // Sau 5 giây chưa thấy bắt đầu đọc thì dừng và báo cho thầy cô.
    var daPhat = false;
    _tts.setStartHandler(() => daPhat = true);
    Future.delayed(const Duration(seconds: 5), () async {
      if (!daPhat && _dangDoc && mounted) {
        await _dung();
        if (!mounted) return;
        setState(() => _canhBao = 'Máy chưa phát được tiếng đọc. Thầy cô cài "Dịch vụ lời nói của Google" '
            '(Speech Services by Google) trên Play Store, rồi vào Cài đặt > Ngôn ngữ > Chuyển văn bản thành giọng nói, '
            'chọn Google và tải giọng Tiếng Việt. Máy giả lập như BlueStacks thường chưa có sẵn bộ đọc này.');
      }
    });
    for (var i = 0; i < ds.length; i++) {
      if (_dungLai || !mounted) break;
      setState(() => _doanDangDoc = i + 1);
      await _tts.speak(ds[i]);
    }
    if (mounted) setState(() => _dangDoc = false);
  }

  Future<void> _dung() async {
    _dungLai = true;
    await _tts.stop();
    if (mounted) setState(() => _dangDoc = false);
  }

  Future<void> _dan() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _chu.text = d!.text!);
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_canhBao != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(10)),
            child: Text(_canhBao!, style: const TextStyle(fontSize: 13)),
          ),
        TextField(
          controller: _chu,
          minLines: 8,
          maxLines: 20,
          decoration: InputDecoration(
            labelText: 'Văn bản cần đọc',
            hintText: 'Dán công văn, bài đọc, đề bài… vào đây',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            suffixIcon: IconButton(tooltip: 'Dán', icon: const Icon(Icons.content_paste), onPressed: _dan),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Tốc độ'),
            Expanded(
              child: Slider(
                value: _tocDo,
                min: 0.25,
                max: 0.8,
                divisions: 11,
                label: _tocDo < 0.45 ? 'Chậm' : (_tocDo > 0.55 ? 'Nhanh' : 'Vừa'),
                onChanged: (v) => setState(() => _tocDo = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _dangDoc
            ? FilledButton.icon(
                onPressed: _dung,
                icon: const Icon(Icons.stop),
                label: Text('Dừng (đoạn $_doanDangDoc/$_tongDoan)'),
              )
            : FilledButton.icon(onPressed: _doc, icon: const Icon(Icons.play_arrow), label: const Text('Đọc to')),
        const SizedBox(height: 10),
        const Text(
          'Dùng giọng đọc có sẵn của điện thoại, miễn phí, đọc được cả khi không có mạng.',
          style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
        ),
      ],
    );
  }
}

class _GhiLoiNoi extends StatefulWidget {
  final bool traVe;
  const _GhiLoiNoi({this.traVe = false});

  @override
  State<_GhiLoiNoi> createState() => _GhiLoiNoiState();
}

class _GhiLoiNoiState extends State<_GhiLoiNoi> with AutomaticKeepAliveClientMixin {
  final _stt = SpeechToText();
  final _chu = TextEditingController();
  bool _sanSang = false;
  bool _muonNghe = false;
  String _dangNghe = '';
  String? _maNgonNgu;
  String? _canhBao;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _chuanBi();
  }

  Future<void> _chuanBi() async {
    try {
      final ok = await _stt.initialize(onStatus: _trangThai, onError: (e) {
        if (!mounted) return;
        if (e.errorMsg.contains('permission')) {
          setState(() => _canhBao = 'App chưa được dùng micro. Thầy cô cấp quyền micro trong Cài đặt.');
        }
      });
      if (!ok) {
        if (mounted) setState(() => _canhBao = 'Máy này chưa nhận giọng nói được (thiếu micro hoặc bộ nhận giọng).');
        return;
      }
      final ds = await _stt.locales();
      final vi = ds.where((l) => l.localeId.toLowerCase().startsWith('vi')).toList();
      _maNgonNgu = vi.isNotEmpty ? vi.first.localeId : null;
      if (mounted) {
        setState(() {
          _sanSang = true;
          if (_maNgonNgu == null) {
            _canhBao = 'Máy chưa có gói nhận giọng tiếng Việt, app sẽ thử nhận bằng ngôn ngữ mặc định của máy.';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _canhBao = 'Máy này chưa nhận giọng nói được.');
    }
  }

  /// Bộ nhận giọng tự dừng sau vài giây im lặng: nếu thầy cô chưa bấm dừng thì nghe tiếp.
  void _trangThai(String s) {
    if ((s == 'done' || s == 'notListening') && _muonNghe && mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_muonNghe && mounted && !_stt.isListening) _nghe();
      });
    }
  }

  void _ketQua(SpeechRecognitionResult r) {
    if (!mounted) return;
    if (r.finalResult) {
      final t = r.recognizedWords.trim();
      if (t.isNotEmpty) {
        final cu = _chu.text.trimRight();
        final cau = t[0].toUpperCase() + t.substring(1);
        _chu.text = cu.isEmpty ? '$cau.' : '$cu $cau.';
      }
      setState(() => _dangNghe = '');
    } else {
      setState(() => _dangNghe = r.recognizedWords);
    }
  }

  Future<void> _nghe() async {
    await _stt.listen(
      onResult: _ketQua,
      localeId: _maNgonNgu,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(partialResults: true, listenMode: ListenMode.dictation, cancelOnError: false),
    );
    if (mounted) setState(() {});
  }

  Future<void> _bamMic() async {
    if (!_sanSang) {
      _bao(_canhBao ?? 'Đang chuẩn bị micro, thầy cô chờ một chút.');
      return;
    }
    if (_muonNghe) {
      _muonNghe = false;
      await _stt.stop();
    } else {
      _muonNghe = true;
      await _nghe();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _muonNghe = false;
    _stt.cancel();
    _chu.dispose();
    super.dispose();
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_canhBao != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(10)),
            child: Text(_canhBao!, style: const TextStyle(fontSize: 13)),
          ),
        Center(
          child: GestureDetector(
            onTap: _bamMic,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _muonNghe ? const Color(0xFFD7261E) : MauApp.xanhDam,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Icon(_muonNghe ? Icons.stop : Icons.mic, color: Colors.white, size: 44),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _muonNghe ? 'Đang nghe… bấm để dừng' : 'Bấm micro rồi nói',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (_dangNghe.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_dangNghe, textAlign: TextAlign.center, style: const TextStyle(color: MauApp.chuPhu, fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _chu,
          minLines: 8,
          maxLines: 20,
          decoration: const InputDecoration(
            labelText: 'Chữ đã ghi (sửa trực tiếp được)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.traVe)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_chu.text.trim()),
            icon: const Icon(Icons.check),
            label: const Text('Chèn vào biên bản'),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _chu.text));
                    _bao('Đã chép.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Chép'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (_chu.text.trim().isEmpty) {
                      _bao('Chưa có chữ nào để gửi.');
                    } else {
                      Share.share(_chu.text);
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Gửi đi'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        const Text(
          'Dùng bộ nhận giọng của điện thoại. Nhiều máy cần có mạng để nhận tiếng Việt chính xác. '
          'Nói rõ, cách micro khoảng một gang tay; mỗi lần ngừng nói, app tự thêm dấu chấm.',
          style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
        ),
      ],
    );
  }
}
