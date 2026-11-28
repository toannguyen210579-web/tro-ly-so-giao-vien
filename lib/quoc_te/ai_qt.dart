import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../services/chia_se.dart';
import '../services/tro_ly_api.dart';
import 'ngon_ngu.dart';
import 'quoc_te.dart';

/// Các công cụ AI của bản quốc tế: mã gửi máy chủ (chế độ `qt`), biểu tượng, màu.
/// Hướng dẫn cho AI nằm trên máy chủ (server/worker.js, QT_TOOLS); app chỉ gửi mã công cụ và ngôn ngữ.
const congCuAiQT = <(String, IconData, Color)>[
  ('quiz', Icons.quiz_outlined, Color(0xFF1F6FE5)),
  ('plan', Icons.event_note_outlined, Color(0xFF0B8A6A)),
  ('rewrite', Icons.text_fields, Color(0xFFEF6A23)),
  ('sheet', Icons.assignment_outlined, Color(0xFF8A4FD3)),
  ('rubric', Icons.table_rows_outlined, Color(0xFF00838F)),
  ('feedback', Icons.rate_review_outlined, Color(0xFFD42539)),
];

/// Gửi một yêu cầu AI lên máy chủ. Phép thử thay hàm này để không cần mạng.
Future<Map<String, dynamic>> Function(Map<String, dynamic> du) guiAiQT = _guiThat;

Future<Map<String, dynamic>> _guiThat(Map<String, dynamic> du) async {
  final res = await http
      .post(Uri.parse('$diaChiMayChu/v1/ai'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(du))
      .timeout(const Duration(seconds: 75));
  final j = jsonDecode(utf8.decode(res.bodyBytes));
  return j is Map<String, dynamic> ? j : <String, dynamic>{};
}

/// Danh sách công cụ AI.
class AiQT extends StatelessWidget {
  const AiQT({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(chu('aiTools'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final (ma, icon, mau) in congCuAiQT)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                key: ValueKey('ai_$ma'),
                leading: CircleAvatar(backgroundColor: mau.withValues(alpha: 0.14), child: Icon(icon, color: mau)),
                title: Text(chu('ai_$ma')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CongCuAiQT(ma: ma))),
              ),
            ),
          const SizedBox(height: 8),
          Text(chu('aiNote'), style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu, height: 1.35)),
        ],
      ),
    );
  }
}

/// Một công cụ AI: ô nhập, ô trình độ, nút tạo, kết quả kèm chép và gửi.
class CongCuAiQT extends StatefulWidget {
  final String ma;
  const CongCuAiQT({super.key, required this.ma});

  @override
  State<CongCuAiQT> createState() => _CongCuAiQTState();
}

class _CongCuAiQTState extends State<CongCuAiQT> {
  final _noiDung = TextEditingController();
  final _trinhDo = TextEditingController();
  bool _dangGui = false;
  String? _kq;
  String? _loi;
  int? _con;

  @override
  void dispose() {
    _noiDung.dispose();
    _trinhDo.dispose();
    super.dispose();
  }

  Future<void> _tao() async {
    final nd = _noiDung.text.trim();
    if (nd.isEmpty) {
      setState(() => _loi = chu('aiEmpty'));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    final td = _trinhDo.text.trim();
    Map<String, dynamic> j;
    try {
      j = await guiAiQT({
        'mode': 'qt',
        'tool': widget.ma,
        'lang': tenTieng[tieng.value] ?? 'English',
        'device_id': await TroLyApi.maMay(),
        'input': td.isEmpty ? nd : 'Age or level: $td\n\n$nd',
      });
    } catch (_) {
      j = <String, dynamic>{'error': 'loi_mang'};
    }
    if (!mounted) return;
    setState(() {
      _dangGui = false;
      if (j['ok'] == true && j['text'] is String) {
        _kq = j['text'] as String;
        _con = (j['remaining'] as num?)?.toInt();
      } else {
        final ma = '${j['error'] ?? ''}';
        _loi = ma.startsWith('het_luot') ? chu('aiErrLimit') : (ma == 'qua_dai' || ma == 'trong' ? chu('errTry') : chu('aiErrNet'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kq = _kq;
    return Scaffold(
      appBar: AppBar(title: Text(chu('ai_${widget.ma}'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            key: const ValueKey('ai_noi_dung'),
            controller: _noiDung,
            minLines: 4,
            maxLines: 10,
            maxLength: 7500,
            decoration: InputDecoration(labelText: chu('aiInput'), alignLabelWithHint: true, border: const OutlineInputBorder(), filled: true, fillColor: Colors.white),
          ),
          TextField(
            controller: _trinhDo,
            maxLength: 60,
            decoration: InputDecoration(labelText: chu('aiLevel'), border: const OutlineInputBorder(), filled: true, fillColor: Colors.white, counterText: ''),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('ai_tao'),
            onPressed: _dangGui ? null : _tao,
            icon: _dangGui
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(chu(_dangGui ? 'aiWorking' : 'generate')),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          if (_loi != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_loi!, key: const ValueKey('ai_loi'), style: const TextStyle(color: Color(0xFFA3241C), fontWeight: FontWeight.w700)),
            ),
          if (_con != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(chu('aiLeft', n: _con), style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu)),
            ),
          if (kq != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB9CCEF))),
              child: SelectableText(kq, key: const ValueKey('ai_ket_qua'), style: const TextStyle(fontSize: 15, height: 1.45)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: kq));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(chu('copied'))));
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(chu('copy')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Builder(
                  builder: (b) => FilledButton.tonalIcon(
                    onPressed: () => guiChu(kq, context: b),
                    icon: const Icon(Icons.ios_share),
                    label: Text(chu('share')),
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          Text(chu('aiNote'), style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu, height: 1.35)),
        ],
      ),
    );
  }
}
