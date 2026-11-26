import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/tin_kenh.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import '../services/chia_se.dart';
import 'thanh_duoi.dart';

const tenKenh = 'Việt Nam Tiêu Điểm';

Widget anhTin(TinKenh t, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
  Widget loi(BuildContext _, Object __, StackTrace? ___) =>
      Container(width: width, height: height, color: const Color(0xFFDCE6F5), child: const Icon(Icons.image_outlined));
  return t.anhDongGoi
      ? Image.asset(t.duongDanAnh, fit: fit, width: width, height: height, errorBuilder: loi)
      : Image.network(t.duongDanAnh, fit: fit, width: width, height: height, errorBuilder: loi);
}

/// Mở clip trên Facebook. Clip chưa có đường dẫn riêng thì mở trang Facebook của kênh (thầy cô chốt 26/11/2026:
/// tin nào cũng có nút, bấm phải có phản hồi).
Future<void> moFacebook(BuildContext context, TinKenh t) async {
  final link = t.linkFacebook ?? trangKenhFacebook;
  final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa mở được Facebook.')));
  }
}

void chiaSeTin(TinKenh t) {
  final lk = t.laTinBao ? t.link : (t.linkFacebook ?? trangKenhFacebook);
  final link = lk == null ? '' : '\n$lk';
  guiChu('${t.tit}\n${t.tomTat}$link\n(Theo ${t.nguon ?? tenKenh})');
}

/// Mở bài gốc trên trang báo
Future<void> moBaiGoc(BuildContext context, TinKenh t) async {
  final link = t.link;
  if (link == null) return;
  final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa mở được trang báo.')));
  }
}

/// Dòng "Tin mới" gọn trên trang chủ: tít tin mới nhất, bấm vào mở trang Tin.
class DongTinMoi extends StatefulWidget {
  const DongTinMoi({super.key});

  @override
  State<DongTinMoi> createState() => _DongTinMoiState();
}

class _DongTinMoiState extends State<DongTinMoi> {
  TinKenh? _moi;

  @override
  void initState() {
    super.initState();
    NguonTin.tai().then((ds) {
      if (mounted && ds.isNotEmpty) setState(() => _moi = ds.first);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final t = _moi;
    if (t == null) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManTin())),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: anhTin(t, width: 56, height: 72)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TIN MỚI',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFD7261E))),
                    const SizedBox(height: 3),
                    Text(t.tit, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trang Tin (nút riêng ở thanh dưới): các tin, clip của kênh, mới nhất trước.
class ManTin extends StatefulWidget {
  const ManTin({super.key});

  @override
  State<ManTin> createState() => _ManTinState();
}

class _ManTinState extends State<ManTin> {
  List<TinKenh>? _ds;
  Set<String> _thich = {};

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    try {
      final ds = await NguonTin.tai();
      final th = await NguonTin.daThich();
      if (mounted) {
        setState(() {
          _ds = ds;
          _thich = th;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _ds = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    return Scaffold(
      appBar: AppBar(title: const Text('Tin tức')),
      bottomNavigationBar: const ThanhDuoi(chon: nutTin),
      body: ds == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _tai,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: ds.isEmpty ? 1 : ds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  if (ds.isEmpty) {
                    return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('Chưa có tin nào.')));
                  }
                  final t = ds[i];
                  return TheTin(
                    tin: t,
                    thich: _thich.contains(t.id),
                    boThich: () async {
                      final moi = !_thich.contains(t.id);
                      setState(() => moi ? _thich.add(t.id) : _thich.remove(t.id));
                      await NguonTin.datThich(t.id, moi);
                    },
                  );
                },
              ),
            ),
    );
  }
}

/// Thẻ tin kiểu bài đăng: logo kênh, tít, tóm tắt, ảnh bìa, các nút.
class TheTin extends StatefulWidget {
  final TinKenh tin;
  final bool thich;
  final VoidCallback boThich;
  const TheTin({super.key, required this.tin, required this.thich, required this.boThich});

  @override
  State<TheTin> createState() => _TheTinState();
}

class _TheTinState extends State<TheTin> {
  bool _moRong = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tin;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (t.laTinBao)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(color: Color(0xFFE8F0FE), shape: BoxShape.circle),
                    child: const Icon(Icons.newspaper_rounded, color: MauApp.xanhTroi, size: 20),
                  )
                else
                  ClipOval(child: Image.asset('assets/tin/logo_vntd.png', width: 34, height: 34, fit: BoxFit.cover)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(t.nguon ?? tenKenh,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('  ·  ${ngayVN(t.ngay)}', style: const TextStyle(color: MauApp.chuPhu, fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 10),
            Text(t.tit, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.25)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _moRong = !_moRong),
              child: Text(
                t.tomTat,
                maxLines: _moRong ? null : 3,
                overflow: _moRong ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(height: 1.4),
              ),
            ),
            if (!_moRong)
              GestureDetector(
                onTap: () => setState(() => _moRong = true),
                child: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('Xem thêm', style: TextStyle(color: MauApp.chuPhu, fontWeight: FontWeight.w600)),
                ),
              ),
            if (t.laTinBao && t.anhBia.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => moBaiGoc(context, t),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(aspectRatio: 16 / 9, child: anhTin(t)),
                ),
              ),
            ],
            if (!t.laTinBao) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => t.video != null
                  ? Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManXemClip(ds: [t])))
                  : moFacebook(context, t),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(aspectRatio: 9 / 12, child: anhTin(t)),
                    // Clip luôn có nút phát: có video thì phát trong app, không thì mở Facebook (clip hoặc trang kênh)
                    Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                      ),
                  ],
                ),
              ),
            ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  tooltip: 'Thích',
                  onPressed: widget.boThich,
                  icon: Icon(widget.thich ? Icons.favorite : Icons.favorite_border,
                      color: widget.thich ? const Color(0xFFD7261E) : null),
                ),
                IconButton(tooltip: 'Chia sẻ', onPressed: () => chiaSeTin(t), icon: const Icon(Icons.share_outlined)),
                const Spacer(),
                if (t.laTinBao)
                  FilledButton.icon(
                    onPressed: t.link == null ? null : () => moBaiGoc(context, t),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Đọc bài gốc'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => moFacebook(context, t),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Xem trên Facebook'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Xem clip ngay trong app: vuốt dọc sang clip khác như thước phim.
class ManXemClip extends StatefulWidget {
  final List<TinKenh> ds;
  final int batDau;
  const ManXemClip({super.key, required this.ds, this.batDau = 0});

  @override
  State<ManXemClip> createState() => _ManXemClipState();
}

class _ManXemClipState extends State<ManXemClip> {
  late final PageController _trang = PageController(initialPage: widget.batDau);

  @override
  void dispose() {
    _trang.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          title: const Text(tenKenh)),
      body: PageView.builder(
        controller: _trang,
        scrollDirection: Axis.vertical,
        itemCount: widget.ds.length,
        itemBuilder: (_, i) => _MotClip(tin: widget.ds[i]),
      ),
    );
  }
}

class _MotClip extends StatefulWidget {
  final TinKenh tin;
  const _MotClip({required this.tin});

  @override
  State<_MotClip> createState() => _MotClipState();
}

class _MotClipState extends State<_MotClip> {
  VideoPlayerController? _vp;
  bool _loi = false;

  @override
  void initState() {
    super.initState();
    final v = widget.tin.video;
    if (v != null) {
      _vp = VideoPlayerController.networkUrl(Uri.parse(v))
        ..setLooping(true)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _vp!.play();
          }
        }).catchError((_) {
          if (mounted) setState(() => _loi = true);
        });
    }
  }

  @override
  void dispose() {
    _vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tin;
    final vp = _vp;
    final sanSang = vp != null && vp.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (sanSang)
          GestureDetector(
            onTap: () {
              vp.value.isPlaying ? vp.pause() : vp.play();
              setState(() {});
            },
            child: Center(child: AspectRatio(aspectRatio: vp.value.aspectRatio, child: VideoPlayer(vp))),
          )
        else
          Center(child: anhTin(t, fit: BoxFit.contain)),
        if (vp != null && !sanSang && !_loi) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (sanSang && !vp.value.isPlaying)
          const Center(child: Icon(Icons.play_arrow, color: Colors.white70, size: 80)),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vp == null || _loi)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      _loi ? 'Chưa phát được clip, thầy cô kiểm tra mạng.' : 'Clip sẽ phát được ngay trong app khi kênh tải tệp lên.',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                Text(t.tit, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(t.tomTat, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => chiaSeTin(t),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        side: const BorderSide(color: Colors.white54),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Chia sẻ'),
                    ),
                    FilledButton.icon(
                      onPressed: () => moFacebook(context, t),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                      icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                      label: const Text('Thích, bình luận trên Facebook'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
