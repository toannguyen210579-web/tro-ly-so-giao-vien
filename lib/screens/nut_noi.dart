import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Nút micro đặt cạnh ô chữ: bấm rồi nói, lời nói thành chữ điền thẳng vào ô [dich]; bấm lần nữa để dừng.
/// Thầy cô không phải gõ (yêu cầu 24/11/2026 cho Nhắn phụ huynh). Dùng bộ nhận giọng có sẵn của máy.
class NutNoi extends StatefulWidget {
  final TextEditingController dich;
  final double co;
  const NutNoi({super.key, required this.dich, this.co = 46});

  @override
  State<NutNoi> createState() => _NutNoiState();
}

class _NutNoiState extends State<NutNoi> {
  // Bộ nhận giọng là một đối tượng dùng chung cả app: mỗi lần nghe tự gắn lại bộ nghe trạng thái của nút này
  final _stt = SpeechToText();
  bool _dangNghe = false;
  String _goc = ''; // chữ có sẵn trong ô trước khi nói
  String? _ma; // mã tiếng Việt của bộ nhận giọng

  void _trangThai(String s) {
    if ((s == 'done' || s == 'notListening') && mounted && _dangNghe) setState(() => _dangNghe = false);
  }

  void _loi(SpeechRecognitionError e) {
    if (!mounted) return;
    setState(() => _dangNghe = false);
    if (e.errorMsg.contains('permission')) {
      _bao('App chưa được dùng micro. Thầy cô vào Cài đặt của máy › Trợ lý số GV, bật Micro và Nhận dạng lời nói.');
    } else if (e.errorMsg.contains('no_match') || e.errorMsg.contains('speech_timeout')) {
      _bao('Chưa nghe rõ, thầy cô bấm micro rồi nói lại gần máy hơn.');
    }
  }

  void _bao(String s) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s)));

  Future<void> _bam() async {
    if (_dangNghe) {
      await _stt.stop();
      if (mounted) setState(() => _dangNghe = false);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    var ok = false;
    try {
      ok = await _stt.initialize(onStatus: _trangThai, onError: _loi);
    } catch (_) {}
    if (!mounted) return;
    if (!ok) {
      _bao('Máy chưa cho app dùng micro hoặc nhận giọng nói. Thầy cô vào Cài đặt của máy › Trợ lý số GV để bật.');
      return;
    }
    _stt.statusListener = _trangThai;
    _stt.errorListener = _loi;
    if (_ma == null) {
      try {
        final vi = (await _stt.locales()).where((l) => l.localeId.toLowerCase().startsWith('vi'));
        _ma = vi.isEmpty ? null : vi.first.localeId;
      } catch (_) {}
    }
    _goc = widget.dich.text.trimRight();
    setState(() => _dangNghe = true);
    try {
      await _stt.listen(
        onResult: _ketQua,
        localeId: _ma,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 5),
        listenOptions: SpeechListenOptions(partialResults: true, listenMode: ListenMode.dictation, cancelOnError: true),
      );
    } catch (_) {
      if (mounted) setState(() => _dangNghe = false);
      _bao('Chưa bật được micro, thầy cô thử lại.');
    }
  }

  void _ketQua(SpeechRecognitionResult r) {
    final t = r.recognizedWords.trim();
    if (t.isNotEmpty) {
      widget.dich.text = _goc.isEmpty ? t : '$_goc $t';
      widget.dich.selection = TextSelection.collapsed(offset: widget.dich.text.length);
    }
    if (r.finalResult) {
      _goc = widget.dich.text.trimRight();
      if (mounted) setState(() => _dangNghe = false);
    }
  }

  @override
  void dispose() {
    if (_dangNghe) _stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _dangNghe ? 'Đang nghe, bấm để dừng' : 'Bấm rồi nói',
      child: Material(
        color: _dangNghe ? const Color(0xFFD7261E) : const Color(0xFF1F6FE5),
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x882C6EE8),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _bam,
          child: SizedBox(
            width: widget.co,
            height: widget.co,
            child: Icon(_dangNghe ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: widget.co * 0.55),
          ),
        ),
      ),
    );
  }
}
