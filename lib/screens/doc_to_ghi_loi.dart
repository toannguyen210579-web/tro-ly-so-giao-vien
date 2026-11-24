import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:video_player/video_player.dart';

import '../services/chon_tep.dart';
import '../services/giong_may.dart';
import '../services/tro_ly_api.dart';
import '../main.dart';
import 'cau_giup_viec.dart';
import '../services/chia_se.dart';

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

  /// Máy không có giọng đọc tiếng Việt thì app tự đọc bằng giọng Google qua máy chủ (cần mạng).
  bool _quaMang = false;
  int _luotDoc = 0; // mỗi lần bấm Đọc to là một lượt; đổi lượt thì vòng đọc cũ tự dừng
  VideoPlayerController? _loa;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _chuanBi();
  }

  /// iPhone, iPad: bộ đọc mặc định theo nút gạt im lặng, máy đang để im lặng thì đọc mà không ra tiếng
  /// (lỗi thầy cô báo 24/11/2026). Đặt loa ở chế độ phát (như nghe nhạc, xem video) để luôn nghe được.
  /// Gọi lại trước mỗi lần đọc vì phần Ghi lời nói dùng micro có thể đổi chế độ loa.
  Future<void> _datLoaIos() async {
    if (!Platform.isIOS) return;
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    } catch (_) {}
  }

  Future<void> _chuanBi() async {
    try {
      await _datLoaIos();
      await _tts.awaitSpeakCompletion(true);
      final co = await _tts.isLanguageAvailable('vi-VN');
      await _tts.setLanguage('vi-VN');
      if (co != true) _quaMang = true;
    } catch (_) {
      _quaMang = true;
    }
    // Máy không có giọng tiếng Việt: tải sẵn giọng cài sẵn ngay, để lúc bấm Đọc to là đọc được, không cần mạng
    if (_quaMang && !await GiongMay.sanSang()) unawaited(_taiGiong().then((_) {}, onError: (_) {}));
  }

  @override
  void dispose() {
    _dungLai = true;
    _tts.stop();
    _loa?.dispose();
    _chu.dispose();
    super.dispose();
  }

  Future<void> _doc() async {
    FocusManager.instance.primaryFocus?.unfocus(); // hạ bàn phím để thấy nút Dừng, tiến độ đọc
    final ds = tachCau(_chu.text);
    if (ds.isEmpty) {
      _bao('Thầy cô dán hoặc gõ văn bản cần đọc vào ô trên.');
      return;
    }
    setState(() {
      _dangDoc = true;
      _dungLai = false;
      _canhBao = null;
      _tongDoan = ds.length;
    });
    if (_quaMang) {
      await _docQuaMang(ds, 0);
      return;
    }
    final luot = ++_luotDoc;
    await _datLoaIos();
    await _tts.setSpeechRate(_tocDo);
    // Máy giả lập hoặc máy thiếu bộ đọc: lệnh đọc không phát tiếng và cũng không báo xong.
    // Sau 4 giây chưa thấy bắt đầu đọc thì app tự chuyển sang đọc qua mạng, thầy cô không phải làm gì.
    var daPhat = false;
    var chuyen = false;
    Future<void> chuyenQuaMang() async {
      if (chuyen || daPhat || _dungLai || luot != _luotDoc || !mounted) return;
      chuyen = true;
      _quaMang = true;
      _luotDoc++; // dừng vòng đọc bằng giọng máy
      await _tts.stop();
      if (!mounted) return;
      await _docQuaMang(ds, _doanDangDoc > 0 ? _doanDangDoc - 1 : 0);
    }

    _tts.setStartHandler(() => daPhat = true);
    // Có máy treo lệnh đọc, có máy trả về ngay mà không phát tiếng: cả hai trường hợp đều tự chuyển.
    Future.delayed(const Duration(seconds: 4), chuyenQuaMang);
    for (var i = 0; i < ds.length; i++) {
      if (_dungLai || !mounted || luot != _luotDoc) break;
      setState(() => _doanDangDoc = i + 1);
      await _tts.speak(ds[i]);
    }
    if (!daPhat && luot == _luotDoc) {
      await chuyenQuaMang();
      return;
    }
    if (mounted && !chuyen) setState(() => _dangDoc = false);
  }

  /// Đọc dự phòng khi máy không phát được giọng tiếng Việt:
  /// 1. giọng cài sẵn trong app (không cần mạng, không giới hạn), lần đầu app tự tải về khoảng 21 MB;
  /// 2. trong lúc chưa tải xong thì đọc bằng giọng Gemini qua mạng (lượt miễn phí ít);
  /// 3. Gemini hết lượt hoặc mất mạng thì chờ tải xong giọng cài sẵn rồi đọc tiếp.
  /// Khối đầu ngắn để có tiếng sớm; làm sẵn khối sau trong lúc đọc khối trước nên không bị ngắt quãng.
  Future<void> _docQuaMang(List<String> ds, int tu) async {
    final khoi = <(int, String)>[]; // (số đoạn đầu khối, chữ)
    var dem = '';
    var dau = tu;
    for (var i = tu; i < ds.length; i++) {
      final tran = khoi.isEmpty ? 120 : 600;
      if (dem.isNotEmpty && dem.length + ds[i].length + 1 > tran) {
        khoi.add((dau, dem));
        dem = '';
        dau = i;
      }
      dem = dem.isEmpty ? ds[i] : '$dem ${ds[i]}';
    }
    if (dem.isNotEmpty) khoi.add((dau, dem));
    final toc = _tocDo * 2; // thanh tốc độ 0,5 là vừa, ứng với tốc độ 1
    final thuMuc = await getTemporaryDirectory();
    var sau = _layAm(khoi.first.$2, 0, toc, thuMuc);
    for (var k = 0; k < khoi.length; k++) {
      if (_dungLai || !mounted) break;
      setState(() => _doanDangDoc = khoi[k].$1 + 1);
      final (f, tocPhat, loi) = await sau;
      if (k + 1 < khoi.length) sau = _layAm(khoi[k + 1].$2, k + 1, toc, thuMuc);
      if (_dungLai || !mounted) break;
      if (f == null) {
        setState(() => _canhBao = loi);
        break;
      }
      await _phat(f, toc: tocPhat);
    }
    if (mounted) setState(() => _dangDoc = false);
  }

  /// Lấy âm thanh cho một khối chữ. Trả về (tệp, tốc độ khi phát, lời báo lỗi).
  Future<(File?, double, String?)> _layAm(String chu, int k, double toc, Directory thuMuc) async {
    final duong = '${thuMuc.path}/doc_to_${_luotDoc}_$k';
    Future<(File?, double, String?)> docMay() async {
      try {
        return (await GiongMay.tao(chu, toc: toc, duongRa: '$duong.wav'), 1.0, null);
      } catch (_) {
        return (null, 1.0, 'Chưa đọc được đoạn này, thầy cô bấm Đọc to lại.');
      }
    }

    if (await GiongMay.sanSang()) return docMay();
    final tai = _taiGiong().then((_) => true, onError: (_) => false); // tải ngầm, lần sau đọc không cần mạng
    final (am, duoi, _) = await TroLyApi.docQuaMang(chu, toc: toc);
    if (am != null) {
      final f = File('$duong.$duoi');
      await f.writeAsBytes(am, flush: true);
      // Giọng Google Cloud đã đặt tốc độ trên máy chủ; giọng Gemini chỉnh tốc độ khi phát
      return (f, duoi == 'wav' ? toc : 1.0, null);
    }
    if (!await tai) {
      return (null, 1.0, 'Chưa tải được giọng đọc. Thầy cô bật mạng (nên dùng wifi) rồi bấm Đọc to lại, chỉ cần tải một lần.');
    }
    return docMay();
  }

  /// Tải giọng cài sẵn về máy (một lần), hiện tiến độ ở ô báo.
  Future<void> _taiGiong() => GiongMay.taiVe(tienDo: (x) {
        if (!mounted) return;
        setState(() => _canhBao = x >= 1
            ? null
            : 'Đang tải giọng đọc tiếng Việt về máy (một lần, khoảng ${GiongMay.coMB} MB): ${(x * 100).round()}%');
      });

  /// Phát một tệp âm thanh và chờ phát xong (hoặc thầy cô bấm Dừng).
  Future<void> _phat(File f, {double toc = 1}) async {
    final loa = VideoPlayerController.file(f);
    _loa = loa;
    try {
      await loa.initialize();
      final xong = Completer<void>();
      void nghe() {
        final v = loa.value;
        if (v.hasError || _dungLai || (v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying)) {
          if (!xong.isCompleted) xong.complete();
        }
      }
      loa.addListener(nghe);
      if (toc != 1) await loa.setPlaybackSpeed(toc.clamp(0.5, 2.0).toDouble());
      await loa.play();
      final dai = loa.value.duration * (1 / (toc <= 0 ? 1 : toc));
      await xong.future.timeout(dai + const Duration(seconds: 5), onTimeout: () {});
      loa.removeListener(nghe);
    } catch (_) {
      // tệp hỏng thì bỏ qua khối này
    } finally {
      _loa = null;
      await loa.dispose();
    }
  }

  Future<void> _dung() async {
    _dungLai = true;
    await _tts.stop();
    await _loa?.pause();
    if (mounted) setState(() => _dangDoc = false);
  }

  Future<void> _moTep() async {
    try {
      final t = await chonTep(duoiChu);
      if (t?.chu == null) return;
      setState(() => _chu.text = t!.chu!);
    } on FormatException catch (e) {
      _bao(e.message);
    } catch (_) {
      _bao('Chưa mở được tệp, thầy cô thử lại.');
    }
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_canhBao != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(10)),
            child: Text(_canhBao!, style: const TextStyle(fontSize: 13)),
          ),
        // Nút Đọc to đặt trên ô chữ: bàn phím iPhone mở lên vẫn thấy nút (lỗi thầy cô báo 24/11/2026)
        _dangDoc
            ? FilledButton.icon(
                onPressed: _dung,
                icon: const Icon(Icons.stop),
                label: Text('Dừng (đoạn $_doanDangDoc/$_tongDoan)'),
              )
            : FilledButton.icon(onPressed: _doc, icon: const Icon(Icons.play_arrow), label: const Text('Đọc to')),
        const SizedBox(height: 12),
        TextField(
          controller: _chu,
          minLines: 8,
          maxLines: 20,
          decoration: InputDecoration(
            labelText: 'Văn bản cần đọc',
            hintText: 'Dán công văn, bài đọc, đề bài… vào đây',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            suffixIcon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(tooltip: 'Dán', icon: const Icon(Icons.content_paste), onPressed: _dan),
                IconButton(tooltip: 'Mở tệp Word', icon: const Icon(Icons.upload_file), onPressed: _moTep),
              ],
            ),
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
        const SizedBox(height: 10),
        const Text(
          'Dán hoặc gõ chữ vào ô trên rồi bấm Đọc to. '
          'Dùng giọng đọc có sẵn của điện thoại, đọc được cả khi không có mạng và khi máy đang để chế độ im lặng. '
          'Máy chưa có giọng tiếng Việt thì app tự dùng giọng đọc cài sẵn (tải về một lần, sau đó không cần mạng).',
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

  void _loiNghe(SpeechRecognitionError e) {
    if (!mounted) return;
    if (e.errorMsg.contains('permission')) {
      setState(() => _canhBao = 'App chưa được dùng micro. Thầy cô cấp quyền micro trong Cài đặt.');
    }
  }

  Future<void> _chuanBi() async {
    try {
      final ok = await _stt.initialize(onStatus: _trangThai, onError: _loiNghe);
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
    // Bộ nhận giọng dùng chung cả app (nút micro ở Nhắn phụ huynh…): gắn lại bộ nghe của màn này trước khi nghe
    _stt.statusListener = _trangThai;
    _stt.errorListener = _loiNghe;
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
                      guiChu(_chu.text, context: context);
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
