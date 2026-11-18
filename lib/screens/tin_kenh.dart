import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/tin_kenh.dart';
import '../main.dart';
import '../services/tep_pdf.dart';

const tenKenh = 'Việt Nam Tiêu Điểm';

Widget anhTin(TinKenh t, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
  Widget loi(BuildContext _, Object __, StackTrace? ___) =>
      Container(width: width, height: height, color: const Color(0xFFDCE6F5), child: const Icon(Icons.image_outlined));
  return t.anhDongGoi
      ? Image.asset(t.duongDanAnh, fit: fit, width: width, height: height, errorBuilder: loi)
      : Image.network(t.duongDanAnh, fit: fit, width: width, height: height, errorBuilder: loi);
}

Future<void> moFacebook(BuildContext context, TinKenh t) async {
  final link = t.linkFacebook;
  if (link == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bài đăng này chưa có đường dẫn Facebook, kênh sẽ cập nhật sau.')),
    );
    return;
  }
  final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa mở được Facebook.')));
  }
}

void chiaSeTin(TinKenh t) {
  final link = t.linkFacebook == null ? '' : '\n${t.linkFacebook}';
  Share.share('${t.tit}\n${t.tomTat}$link\n(Theo $tenKenh)');
}

/// Mục "Tin cho thầy cô" trên trang chủ: thẻ tin mới nhất (nút Xem trên Facebook)
/// và dải "Clip đã đăng" phát ngay trong app.
class MucTinKenh extends StatefulWidget {
  const MucTinKenh({super.key});

  @override
  State<MucTinKenh> createState() => _MucTinKenhState();
}

class _MucTinKenhState extends State<MucTinKenh> {
  List<TinKenh> _ds = [];
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
    } catch (_) {}
  }

  Future<void> _boThich(TinKenh t) async {
    final moi = !_thich.contains(t.id);
    setState(() => moi ? _thich.add(t.id) : _thich.remove(t.id));
    await NguonTin.datThich(t.id, moi);
  }

  @override
  Widget build(BuildContext context) {
    if (_ds.isEmpty) return const SizedBox.shrink();
    final moi = _ds.first;
    final cu = _ds.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Tin cho thầy cô', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManTatCaTin(ds: _ds))),
              child: const Text('Tất cả'),
            ),
          ],
        ),
        TheTin(tin: moi, thich: _thich.contains(moi.id), boThich: () => _boThich(moi)),
        if (cu.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Clip đã đăng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cu.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _OClip(
                tin: cu[i],
                bam: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManXemClip(ds: cu, batDau: i))),
              ),
            ),
          ),
        ],
      ],
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
                ClipOval(child: Image.asset('assets/tin/logo_vntd.png', width: 34, height: 34, fit: BoxFit.cover)),
                const SizedBox(width: 8),
                const Text(tenKenh, style: TextStyle(fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => moFacebook(context, t),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(aspectRatio: 9 / 12, child: anhTin(t)),
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

class _OClip extends StatelessWidget {
  final TinKenh tin;
  final VoidCallback bam;
  const _OClip({required this.tin, required this.bam});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: bam,
      child: SizedBox(
        width: 124,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              anhTin(tin),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              const Positioned(top: 6, right: 6, child: Icon(Icons.play_circle_fill, color: Colors.white, size: 26)),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(tin.tit,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManTatCaTin extends StatefulWidget {
  final List<TinKenh> ds;
  const ManTatCaTin({super.key, required this.ds});

  @override
  State<ManTatCaTin> createState() => _ManTatCaTinState();
}

class _ManTatCaTinState extends State<ManTatCaTin> {
  Set<String> _thich = {};

  @override
  void initState() {
    super.initState();
    NguonTin.daThich().then((s) {
      if (mounted) setState(() => _thich = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tin cho thầy cô')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: widget.ds.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final t = widget.ds[i];
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
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: const Text(tenKenh)),
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
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
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
